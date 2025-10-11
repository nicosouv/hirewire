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
