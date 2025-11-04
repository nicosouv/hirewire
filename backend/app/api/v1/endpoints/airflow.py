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


@router.post("/tasks/verify-gamification", response_model=Dict)
def verify_gamification_integrity(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_airflow_admin)
):
    """
    Verify gamification data integrity for all users.

    Checks performed:
    1. Counter consistency (applications_count, interviews_count, offers_count)
    2. Missing achievements (user should have unlocked but didn't)
    3. Incorrect points (total_points != sum of achievement points)
    4. Incorrect level (level calculation mismatch)

    Requires Airflow admin privileges.

    Returns:
        - total_users_checked: Number of users verified
        - errors_found: Total number of errors detected
        - users_with_errors: List of user IDs with errors
        - error_details: Detailed breakdown by error type
        - users_to_fix: List of users requiring recalculation
    """
    # Get all users with stats
    users_query = text("""
        SELECT
            u.id,
            u.email,
            COALESCE(us.total_points, 0) as total_points,
            COALESCE(us.level, 1) as level,
            COALESCE(us.applications_count, 0) as applications_count,
            COALESCE(us.interviews_count, 0) as interviews_count,
            COALESCE(us.offers_count, 0) as offers_count,
            COALESCE(us.achievements_count, 0) as achievements_count
        FROM hirewire.users u
        LEFT JOIN hirewire.user_stats us ON u.id = us.user_id
        ORDER BY u.id
    """)
    users = db.execute(users_query).fetchall()

    total_users = len(users)
    users_with_errors = []
    error_details = {
        "counter_errors": [],
        "missing_achievements": [],
        "point_errors": [],
        "level_errors": []
    }

    for user_row in users:
        user_id = user_row[0]
        user_email = user_row[1]
        stored_points = user_row[2]
        stored_level = user_row[3]
        stored_apps = user_row[4]
        stored_interviews = user_row[5]
        stored_offers = user_row[6]
        stored_achievements_count = user_row[7]

        user_errors = []

        # Check 1: Verify counter consistency
        actual_counts_query = text("""
            SELECT
                COUNT(DISTINCT ip.id) as actual_applications,
                COUNT(DISTINCT i.id) as actual_interviews,
                COUNT(DISTINCT CASE WHEN io.outcome IN ('offer', 'accepted') THEN io.id END) as actual_offers
            FROM hirewire.users u
            LEFT JOIN hirewire.interview_processes ip ON u.id = ip.user_id
            LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
            LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
            WHERE u.id = :user_id
        """)
        actual_counts = db.execute(actual_counts_query, {"user_id": user_id}).fetchone()
        actual_apps = actual_counts[0] or 0
        actual_interviews = actual_counts[1] or 0
        actual_offers = actual_counts[2] or 0

        if stored_apps != actual_apps or stored_interviews != actual_interviews or stored_offers != actual_offers:
            error_details["counter_errors"].append({
                "user_id": user_id,
                "email": user_email,
                "stored": {"apps": stored_apps, "interviews": stored_interviews, "offers": stored_offers},
                "actual": {"apps": actual_apps, "interviews": actual_interviews, "offers": actual_offers}
            })
            user_errors.append("counter_mismatch")

        # Check 2: Verify missing achievements
        missing_achievements_query = text("""
            SELECT
                a.id,
                a.code,
                a.name,
                a.points,
                a.criteria
            FROM hirewire.achievements a
            WHERE a.is_active = TRUE
            AND a.id NOT IN (
                SELECT achievement_id FROM hirewire.user_achievements WHERE user_id = :user_id
            )
            AND (
                (a.criteria->>'type' = 'count' AND a.criteria->>'metric' = 'applications'
                 AND (a.criteria->>'target')::INTEGER <= :actual_apps)
                OR
                (a.criteria->>'type' = 'count' AND a.criteria->>'metric' = 'interviews'
                 AND (a.criteria->>'target')::INTEGER <= :actual_interviews)
                OR
                (a.criteria->>'type' = 'count' AND a.criteria->>'metric' = 'offers'
                 AND (a.criteria->>'target')::INTEGER <= :actual_offers)
            )
        """)
        missing = db.execute(missing_achievements_query, {
            "user_id": user_id,
            "actual_apps": actual_apps,
            "actual_interviews": actual_interviews,
            "actual_offers": actual_offers
        }).fetchall()

        if missing:
            error_details["missing_achievements"].append({
                "user_id": user_id,
                "email": user_email,
                "missing_count": len(missing),
                "achievements": [
                    {"code": row[1], "name": row[2], "points": row[3]}
                    for row in missing
                ]
            })
            user_errors.append("missing_achievements")

        # Check 3: Verify total points
        actual_points_query = text("""
            SELECT COALESCE(SUM(a.points), 0)
            FROM hirewire.user_achievements ua
            JOIN hirewire.achievements a ON ua.achievement_id = a.id
            WHERE ua.user_id = :user_id
        """)
        actual_points = db.execute(actual_points_query, {"user_id": user_id}).scalar() or 0

        if stored_points != actual_points:
            error_details["point_errors"].append({
                "user_id": user_id,
                "email": user_email,
                "stored_points": stored_points,
                "actual_points": actual_points,
                "difference": stored_points - actual_points
            })
            user_errors.append("point_mismatch")

        # Check 4: Verify level calculation
        # Level = floor(sqrt(points / 100)) + 1
        import math
        expected_level = max(1, int(math.sqrt(actual_points / 100)) + 1)

        if stored_level != expected_level:
            error_details["level_errors"].append({
                "user_id": user_id,
                "email": user_email,
                "stored_level": stored_level,
                "expected_level": expected_level,
                "points": actual_points
            })
            user_errors.append("level_mismatch")

        if user_errors:
            users_with_errors.append({
                "user_id": user_id,
                "email": user_email,
                "error_types": user_errors
            })

    # Calculate totals
    total_errors = (
        len(error_details["counter_errors"]) +
        len(error_details["missing_achievements"]) +
        len(error_details["point_errors"]) +
        len(error_details["level_errors"])
    )

    # Extract unique user IDs to fix
    users_to_fix = list(set([u["user_id"] for u in users_with_errors]))

    return {
        "message": f"Gamification verification complete: {total_errors} errors found across {len(users_to_fix)} users",
        "total_users_checked": total_users,
        "users_with_errors_count": len(users_to_fix),
        "total_errors_found": total_errors,
        "error_summary": {
            "counter_errors": len(error_details["counter_errors"]),
            "missing_achievements": len(error_details["missing_achievements"]),
            "point_errors": len(error_details["point_errors"]),
            "level_errors": len(error_details["level_errors"])
        },
        "users_with_errors": users_with_errors,
        "error_details": error_details,
        "users_to_fix": users_to_fix
    }


@router.post("/tasks/recalculate-gamification/{user_id}", response_model=Dict)
def recalculate_user_gamification(
    user_id: int,
    strategy: str = "incremental",  # 'full_reset' or 'incremental'
    db: Session = Depends(get_db),
    current_user: User = Depends(require_airflow_admin)
):
    """
    Recalculate gamification data for a specific user.

    Strategies:
    - 'incremental': Fix only detected issues (default)
    - 'full_reset': Delete all gamification data and recalculate from scratch

    Steps (full_reset):
    1. Delete all user achievements
    2. Delete or reset user stats
    3. Recalculate counters from raw data
    4. Unlock all eligible achievements
    5. Recalculate total points and level

    Steps (incremental):
    1. Update counters to match raw data
    2. Unlock missing achievements
    3. Recalculate total points
    4. Update level

    Requires Airflow admin privileges.

    Returns:
        - user_id: The user ID that was recalculated
        - strategy: Strategy used
        - before: Stats before recalculation
        - after: Stats after recalculation
        - changes: Detailed changes made
    """
    # Verify user exists
    user_check = db.execute(
        text("SELECT id, email FROM hirewire.users WHERE id = :user_id"),
        {"user_id": user_id}
    ).fetchone()

    if not user_check:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )

    user_email = user_check[1]

    # Get stats before
    before_stats_query = text("""
        SELECT
            COALESCE(total_points, 0) as total_points,
            COALESCE(level, 1) as level,
            COALESCE(applications_count, 0) as applications_count,
            COALESCE(interviews_count, 0) as interviews_count,
            COALESCE(offers_count, 0) as offers_count,
            COALESCE(achievements_count, 0) as achievements_count
        FROM hirewire.user_stats
        WHERE user_id = :user_id
    """)
    before_stats = db.execute(before_stats_query, {"user_id": user_id}).fetchone()

    before = {
        "total_points": before_stats[0] if before_stats else 0,
        "level": before_stats[1] if before_stats else 1,
        "applications_count": before_stats[2] if before_stats else 0,
        "interviews_count": before_stats[3] if before_stats else 0,
        "offers_count": before_stats[4] if before_stats else 0,
        "achievements_count": before_stats[5] if before_stats else 0
    }

    changes = []

    if strategy == "full_reset":
        # Step 1: Delete all user achievements
        delete_achievements = text("DELETE FROM hirewire.user_achievements WHERE user_id = :user_id")
        deleted_count = db.execute(delete_achievements, {"user_id": user_id}).rowcount
        changes.append(f"Deleted {deleted_count} achievements")

        # Step 2: Reset user stats (keep record but reset values)
        reset_stats = text("""
            INSERT INTO hirewire.user_stats (
                user_id, total_points, level, applications_count, interviews_count,
                offers_count, achievements_count, current_streak, longest_streak
            )
            VALUES (:user_id, 0, 1, 0, 0, 0, 0, 0, 0)
            ON CONFLICT (user_id) DO UPDATE SET
                total_points = 0,
                level = 1,
                applications_count = 0,
                interviews_count = 0,
                offers_count = 0,
                achievements_count = 0,
                current_streak = 0,
                longest_streak = 0,
                updated_at = CURRENT_TIMESTAMP
        """)
        db.execute(reset_stats, {"user_id": user_id})
        changes.append("Reset all stats to zero")

    # Step 3: Recalculate counters from raw data
    recalc_counters = text("""
        WITH counts AS (
            SELECT
                COUNT(DISTINCT ip.id) as apps,
                COUNT(DISTINCT i.id) as interviews,
                COUNT(DISTINCT CASE WHEN io.outcome IN ('offer', 'accepted') THEN io.id END) as offers
            FROM hirewire.users u
            LEFT JOIN hirewire.interview_processes ip ON u.id = ip.user_id
            LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
            LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
            WHERE u.id = :user_id
        )
        UPDATE hirewire.user_stats us
        SET
            applications_count = (SELECT apps FROM counts),
            interviews_count = (SELECT interviews FROM counts),
            offers_count = (SELECT offers FROM counts),
            updated_at = CURRENT_TIMESTAMP
        FROM counts
        WHERE us.user_id = :user_id
        RETURNING applications_count, interviews_count, offers_count
    """)
    new_counts = db.execute(recalc_counters, {"user_id": user_id}).fetchone()
    changes.append(f"Recalculated counters: apps={new_counts[0]}, interviews={new_counts[1]}, offers={new_counts[2]}")

    # Step 4: Unlock all eligible achievements
    unlock_result = db.execute(
        text("SELECT * FROM hirewire.check_achievements(:user_id)"),
        {"user_id": user_id}
    ).fetchall()

    if unlock_result:
        unlocked_codes = [row[1] for row in unlock_result]
        changes.append(f"Unlocked {len(unlocked_codes)} achievements: {', '.join(unlocked_codes)}")
    else:
        changes.append("No new achievements unlocked")

    # Step 5: Recalculate total points from achievements
    recalc_points = text("""
        WITH achievement_points AS (
            SELECT COALESCE(SUM(a.points), 0) as total
            FROM hirewire.user_achievements ua
            JOIN hirewire.achievements a ON ua.achievement_id = a.id
            WHERE ua.user_id = :user_id
        ),
        achievement_count AS (
            SELECT COUNT(*) as count
            FROM hirewire.user_achievements
            WHERE user_id = :user_id
        )
        UPDATE hirewire.user_stats us
        SET
            total_points = (SELECT total FROM achievement_points),
            achievements_count = (SELECT count FROM achievement_count),
            updated_at = CURRENT_TIMESTAMP
        WHERE us.user_id = :user_id
        RETURNING total_points, achievements_count
    """)
    new_points = db.execute(recalc_points, {"user_id": user_id}).fetchone()
    changes.append(f"Recalculated points: {new_points[0]} XP from {new_points[1]} achievements")

    # Step 6: Recalculate level
    import math
    new_level = max(1, int(math.sqrt(new_points[0] / 100)) + 1)

    update_level = text("""
        UPDATE hirewire.user_stats
        SET level = :new_level, updated_at = CURRENT_TIMESTAMP
        WHERE user_id = :user_id
    """)
    db.execute(update_level, {"user_id": user_id, "new_level": new_level})
    changes.append(f"Updated level to {new_level}")

    db.commit()

    # Get stats after
    after_stats = db.execute(before_stats_query, {"user_id": user_id}).fetchone()

    after = {
        "total_points": after_stats[0] if after_stats else 0,
        "level": after_stats[1] if after_stats else 1,
        "applications_count": after_stats[2] if after_stats else 0,
        "interviews_count": after_stats[3] if after_stats else 0,
        "offers_count": after_stats[4] if after_stats else 0,
        "achievements_count": after_stats[5] if after_stats else 0
    }

    return {
        "message": f"Successfully recalculated gamification data for user {user_id} ({user_email}) using {strategy} strategy",
        "user_id": user_id,
        "user_email": user_email,
        "strategy": strategy,
        "before": before,
        "after": after,
        "changes": changes,
        "changes_summary": {
            "points_change": after["total_points"] - before["total_points"],
            "level_change": after["level"] - before["level"],
            "achievements_change": after["achievements_count"] - before["achievements_count"]
        }
    }
