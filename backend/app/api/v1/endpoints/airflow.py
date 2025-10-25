"""
Airflow-specific API endpoints for Nginx auth_request integration.
"""
from typing import Dict
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.security import get_current_user
from app.models.user import User
from app.db.session import get_db

router = APIRouter()


def require_airflow_admin(current_user: User = Depends(get_current_user)) -> User:
    """
    Dependency to ensure the user has Airflow admin privileges.
    """
    if not current_user.is_airflow_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Airflow admin privileges required"
        )
    return current_user


@router.get("/validate")
def validate_airflow_access(current_user: User = Depends(get_current_user)):
    """
    Validate if the current user has Airflow admin access.

    This endpoint is specifically designed for Nginx auth_request.
    - Returns 200 OK if user has is_airflow_admin = True
    - Returns 403 Forbidden if user does not have Airflow admin privileges
    - Returns 401 Unauthorized if token is invalid (handled by get_current_user)
    """
    if not current_user.is_airflow_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Airflow admin privileges required"
        )

    # Return 200 OK with minimal response for Nginx
    return Response(status_code=status.HTTP_200_OK, content="OK")


@router.post("/tasks/update-past-interviews", response_model=Dict)
def update_past_scheduled_interviews(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_airflow_admin)
):
    """
    Update interviews from 'scheduled' to 'completed' when their scheduled_date has passed.

    This endpoint is designed to be called by Airflow DAGs for automated maintenance tasks.
    Requires Airflow admin privileges.

    Returns:
        - updated_count: Number of interviews updated
        - interviews: List of updated interview details
        - stats: Current interview statistics
    """
    # Step 1: Check how many interviews need updating
    count_query = text("""
        SELECT COUNT(*)
        FROM hirewire.interviews
        WHERE scheduled_date < CURRENT_TIMESTAMP
          AND status = 'scheduled'
    """)
    count_to_update = db.execute(count_query).scalar()

    if count_to_update == 0:
        return {
            "message": "No past scheduled interviews to update",
            "updated_count": 0,
            "interviews": [],
            "stats": get_interview_stats(db)
        }

    # Step 2: Get details of interviews being updated
    details_query = text("""
        SELECT
            i.id,
            c.name as company_name,
            jp.title as position_title,
            i.interview_type,
            i.scheduled_date,
            EXTRACT(DAY FROM (CURRENT_TIMESTAMP - i.scheduled_date)) as days_past
        FROM hirewire.interviews i
        JOIN hirewire.interview_processes ip ON i.process_id = ip.id
        JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        WHERE i.scheduled_date < CURRENT_TIMESTAMP
          AND i.status = 'scheduled'
        ORDER BY i.scheduled_date
    """)
    interviews_to_update = db.execute(details_query).fetchall()

    # Step 3: Perform the update
    update_query = text("""
        UPDATE hirewire.interviews
        SET
            status = 'completed',
            updated_at = CURRENT_TIMESTAMP
        WHERE scheduled_date < CURRENT_TIMESTAMP
          AND status = 'scheduled'
    """)
    db.execute(update_query)
    db.commit()

    # Format response
    updated_interviews = [
        {
            "id": row[0],
            "company_name": row[1],
            "position_title": row[2],
            "interview_type": row[3],
            "scheduled_date": row[4].isoformat() if row[4] else None,
            "days_past": int(row[5]) if row[5] else 0
        }
        for row in interviews_to_update
    ]

    return {
        "message": f"Successfully updated {len(updated_interviews)} interviews to 'completed' status",
        "updated_count": len(updated_interviews),
        "interviews": updated_interviews,
        "stats": get_interview_stats(db)
    }


def get_interview_stats(db: Session) -> Dict:
    """Get current interview statistics."""
    stats_query = text("""
        SELECT
            COUNT(*) as total_interviews,
            COUNT(CASE WHEN status = 'scheduled' THEN 1 END) as scheduled,
            COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
            COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled
        FROM hirewire.interviews
    """)
    stats = db.execute(stats_query).fetchone()

    return {
        "total": stats[0] if stats else 0,
        "scheduled": stats[1] if stats else 0,
        "completed": stats[2] if stats else 0,
        "cancelled": stats[3] if stats else 0
    }


@router.post("/tasks/update-process-status", response_model=Dict)
def update_process_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_airflow_admin)
):
    """
    Automatically update process status based on interview activity.

    This endpoint intelligently updates process status based on:
    - Scheduled interviews (upcoming)
    - Completed interviews (progress tracking)
    - Interview patterns and timing

    Status transitions:
    - applied → screening (when screening interview scheduled)
    - applied/screening → interviewing (when technical interviews or 2+ completed)
    - interviewing → final_round (when final interview or 3+ completed)

    Requires Airflow admin privileges.

    Returns:
        - message: Summary message
        - updates: Detailed list of status changes
        - stats_before: Process status distribution before updates
        - stats_after: Process status distribution after updates
        - stale_processes: List of processes needing manual review
    """
    # Get status distribution before updates
    stats_before = get_process_stats(db)

    updates = []

    # Step 1: Update processes to 'screening' based on scheduled screening interviews
    screening_query = text("""
        UPDATE hirewire.interview_processes
        SET
            status = 'screening',
            updated_at = CURRENT_TIMESTAMP
        WHERE id IN (
            SELECT DISTINCT ip.id
            FROM hirewire.interview_processes ip
            JOIN hirewire.interviews i ON ip.id = i.process_id
            WHERE ip.status = 'applied'
              AND i.status = 'scheduled'
              AND i.interview_type IN ('phone_screening', 'hr_screening', 'recruiter_call', 'video_screening')
              AND i.scheduled_date >= CURRENT_TIMESTAMP - INTERVAL '1 day'
            AND ip.id NOT IN (
                SELECT DISTINCT process_id
                FROM hirewire.interview_outcomes
                WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
            )
        )
        RETURNING id
    """)
    screening_updated = db.execute(screening_query).fetchall()
    if screening_updated:
        updates.append({
            "transition": "applied → screening",
            "count": len(screening_updated),
            "process_ids": [row[0] for row in screening_updated]
        })

    # Step 2: Update processes to 'interviewing' based on technical/multiple interviews
    interviewing_query = text("""
        UPDATE hirewire.interview_processes
        SET
            status = 'interviewing',
            updated_at = CURRENT_TIMESTAMP
        WHERE id IN (
            SELECT DISTINCT ip.id
            FROM hirewire.interview_processes ip
            WHERE ip.status IN ('applied', 'screening')
            AND (
                -- Has technical interviews scheduled/completed
                EXISTS (
                    SELECT 1 FROM hirewire.interviews i
                    WHERE i.process_id = ip.id
                    AND i.interview_type IN ('technical_interview', 'coding_challenge', 'technical_video', 'system_design', 'pair_programming')
                    AND (i.status = 'scheduled' AND i.scheduled_date >= CURRENT_TIMESTAMP - INTERVAL '1 day' OR i.status = 'completed')
                )
                OR
                -- Has multiple completed interviews
                (
                    SELECT COUNT(*) FROM hirewire.interviews i
                    WHERE i.process_id = ip.id AND i.status = 'completed'
                ) >= 2
                OR
                -- Has scheduled interviews beyond screening
                EXISTS (
                    SELECT 1 FROM hirewire.interviews i
                    WHERE i.process_id = ip.id
                    AND i.status = 'scheduled'
                    AND i.interview_type NOT IN ('phone_screening', 'hr_screening', 'recruiter_call', 'video_screening')
                )
            )
            AND ip.id NOT IN (
                SELECT DISTINCT process_id
                FROM hirewire.interview_outcomes
                WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
            )
        )
        RETURNING id
    """)
    interviewing_updated = db.execute(interviewing_query).fetchall()
    if interviewing_updated:
        updates.append({
            "transition": "applied/screening → interviewing",
            "count": len(interviewing_updated),
            "process_ids": [row[0] for row in interviewing_updated]
        })

    # Step 3: Update processes to 'final_round' based on interview patterns
    final_round_query = text("""
        UPDATE hirewire.interview_processes
        SET
            status = 'final_round',
            updated_at = CURRENT_TIMESTAMP
        WHERE id IN (
            SELECT DISTINCT ip.id
            FROM hirewire.interview_processes ip
            WHERE ip.status = 'interviewing'
            AND (
                -- Has final/manager interviews scheduled
                EXISTS (
                    SELECT 1 FROM hirewire.interviews i
                    WHERE i.process_id = ip.id
                    AND i.interview_type IN ('final_interview', 'manager_interview', 'cultural_fit', 'executive_interview')
                    AND (i.status = 'scheduled' OR i.status = 'completed')
                )
                OR
                -- Has 3+ completed interviews
                (
                    SELECT COUNT(*) FROM hirewire.interviews i
                    WHERE i.process_id = ip.id AND i.status = 'completed'
                ) >= 3
            )
            AND ip.id NOT IN (
                SELECT DISTINCT process_id
                FROM hirewire.interview_outcomes
                WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
            )
        )
        RETURNING id
    """)
    final_round_updated = db.execute(final_round_query).fetchall()
    if final_round_updated:
        updates.append({
            "transition": "interviewing → final_round",
            "count": len(final_round_updated),
            "process_ids": [row[0] for row in final_round_updated]
        })

    # Commit all updates
    db.commit()

    # Get status distribution after updates
    stats_after = get_process_stats(db)

    # Identify stale processes that may need manual review
    stale_query = text("""
        SELECT
            c.name as company,
            jp.title as position,
            ip.id as process_id,
            ip.status,
            ip.application_date,
            CURRENT_DATE - ip.application_date as days_since_application,
            COUNT(i.id) as total_interviews,
            MAX(i.scheduled_date) as last_interview_date,
            CASE
                WHEN MAX(i.scheduled_date) IS NOT NULL THEN
                    CURRENT_DATE - MAX(i.scheduled_date)::DATE
                ELSE NULL
            END as days_since_last_interview
        FROM hirewire.interview_processes ip
        JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
        WHERE ip.id NOT IN (
            SELECT DISTINCT process_id
            FROM hirewire.interview_outcomes
            WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
        )
        AND (
            -- Applied for >14 days with no interviews
            (ip.status = 'applied' AND (CURRENT_DATE - ip.application_date) > 14)
            OR
            -- Screening/interviewing with no recent activity
            (ip.status IN ('screening', 'interviewing') AND
             (SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id) < CURRENT_DATE - INTERVAL '10 days')
        )
        GROUP BY ip.id, c.name, jp.title, ip.status, ip.application_date
        ORDER BY days_since_application DESC
        LIMIT 10
    """)
    stale_processes = db.execute(stale_query).fetchall()

    stale_list = [
        {
            "company": row[0],
            "position": row[1],
            "process_id": row[2],
            "status": row[3],
            "application_date": row[4].isoformat() if row[4] else None,
            "days_since_application": row[5],
            "total_interviews": row[6],
            "last_interview_date": row[7].isoformat() if row[7] else None,
            "days_since_last_interview": row[8]
        }
        for row in stale_processes
    ]

    # Calculate total updates
    total_updates = sum(update["count"] for update in updates)

    return {
        "message": f"Successfully updated {total_updates} process statuses based on interview activity",
        "total_updates": total_updates,
        "updates": updates,
        "stats_before": stats_before,
        "stats_after": stats_after,
        "stale_processes": stale_list,
        "stale_count": len(stale_list)
    }


def get_process_stats(db: Session) -> Dict:
    """Get current process status distribution (excluding finalized processes)."""
    stats_query = text("""
        SELECT
            status,
            COUNT(*) as count
        FROM hirewire.interview_processes
        WHERE id NOT IN (
            SELECT DISTINCT process_id
            FROM hirewire.interview_outcomes
            WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
        )
        GROUP BY status
        ORDER BY count DESC
    """)
    stats = db.execute(stats_query).fetchall()

    # Convert to dict format
    status_counts = {row[0]: row[1] for row in stats}
    total = sum(status_counts.values())

    return {
        "total": total,
        "by_status": status_counts
    }


@router.post("/tasks/detect-ghosted-processes", response_model=Dict)
def detect_ghosted_processes(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_airflow_admin)
):
    """
    Auto-detect and mark ghosted processes based on inactivity patterns.

    Ghosting criteria:
    - No response after 60+ days with no interviews
    - Had interviews but no follow-up for 45+ days
    - Applied status for 30+ days with no interviews

    Automatically creates 'ghosted' outcomes for detected processes.

    Requires Airflow admin privileges.

    Returns:
        - message: Summary message
        - ghosted_count: Number of processes marked as ghosted
        - ghosted_processes: List of detected ghosted processes
        - stats_before: Process stats before detection
        - stats_after: Process stats after detection
    """
    # Get stats before
    stats_before = get_process_stats(db)

    # Step 1: Detect processes that should be marked as ghosted
    detect_query = text("""
        WITH process_activity AS (
            SELECT
                ip.id,
                ip.status,
                ip.application_date,
                c.name as company_name,
                jp.title as position_title,
                COUNT(i.id) as total_interviews,
                MAX(i.scheduled_date) as last_interview_date,
                CURRENT_DATE - ip.application_date as days_since_application,
                CASE
                    WHEN MAX(i.scheduled_date) IS NOT NULL
                    THEN CURRENT_DATE - MAX(i.scheduled_date)::DATE
                    ELSE NULL
                END as days_since_last_interview
            FROM hirewire.interview_processes ip
            JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
            JOIN hirewire.companies c ON jp.company_id = c.id
            LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
            WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
            AND ip.status NOT IN ('ghosted', 'rejected', 'accepted', 'offer', 'withdrew')
            GROUP BY ip.id, ip.status, ip.application_date, c.name, jp.title
        )
        SELECT
            id,
            company_name,
            position_title,
            status,
            application_date,
            total_interviews,
            last_interview_date,
            days_since_application,
            days_since_last_interview,
            CASE
                WHEN days_since_application > 60 AND total_interviews = 0
                    THEN 'No response after 60+ days'
                WHEN total_interviews > 0 AND days_since_last_interview > 45
                    THEN 'No follow-up for 45+ days after interviews'
                WHEN status = 'applied' AND days_since_application > 30 AND total_interviews = 0
                    THEN 'Applied for 30+ days with no interviews'
                ELSE 'Unknown'
            END as ghosting_reason
        FROM process_activity
        WHERE (
            -- No response after 60+ days with no interviews
            (days_since_application > 60 AND total_interviews = 0)
            OR
            -- Had interviews but no follow-up for 45+ days
            (total_interviews > 0 AND days_since_last_interview > 45)
            OR
            -- Applied status for 30+ days with no interviews
            (status = 'applied' AND days_since_application > 30 AND total_interviews = 0)
        )
        ORDER BY days_since_application DESC
    """)

    ghosted_candidates = db.execute(detect_query).fetchall()

    if not ghosted_candidates:
        return {
            "message": "No ghosted processes detected",
            "ghosted_count": 0,
            "ghosted_processes": [],
            "stats_before": stats_before,
            "stats_after": stats_before
        }

    # Step 2: Mark processes as ghosted
    process_ids = [row[0] for row in ghosted_candidates]

    update_query = text("""
        UPDATE hirewire.interview_processes
        SET
            status = 'ghosted',
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ANY(:process_ids)
        RETURNING id
    """)

    updated = db.execute(update_query, {"process_ids": process_ids}).fetchall()

    # Step 3: Create ghosted outcomes
    for row in ghosted_candidates:
        process_id = row[0]
        ghosting_reason = row[9]

        # Check if outcome already exists
        existing_outcome = db.execute(
            text("SELECT id FROM hirewire.interview_outcomes WHERE process_id = :process_id"),
            {"process_id": process_id}
        ).fetchone()

        if not existing_outcome:
            outcome_query = text("""
                INSERT INTO hirewire.interview_outcomes (process_id, outcome, outcome_date, notes, created_at, updated_at)
                VALUES (:process_id, 'ghosted', CURRENT_DATE, :notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
            db.execute(outcome_query, {
                "process_id": process_id,
                "notes": f"Auto-detected ghosting: {ghosting_reason}"
            })

    db.commit()

    # Get stats after
    stats_after = get_process_stats(db)

    # Format response
    ghosted_list = [
        {
            "process_id": row[0],
            "company": row[1],
            "position": row[2],
            "status": row[3],
            "application_date": row[4].isoformat() if row[4] else None,
            "total_interviews": row[5],
            "last_interview_date": row[6].isoformat() if row[6] else None,
            "days_since_application": row[7],
            "days_since_last_interview": row[8] if row[8] else None,
            "ghosting_reason": row[9]
        }
        for row in ghosted_candidates
    ]

    return {
        "message": f"Successfully detected and marked {len(ghosted_list)} ghosted processes",
        "ghosted_count": len(ghosted_list),
        "ghosted_processes": ghosted_list,
        "stats_before": stats_before,
        "stats_after": stats_after
    }
