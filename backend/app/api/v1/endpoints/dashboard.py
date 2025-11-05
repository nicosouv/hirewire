"""
Dashboard API endpoints for statistics and analytics.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.session import get_db
from app.models.interview_process import InterviewProcess
from app.models.interview import Interview
from app.models.interview_outcome import InterviewOutcome
from app.models.company import Company
from app.models.job_position import JobPosition
from app.schemas.dashboard import (
    DashboardData,
    DashboardStats,
    ProcessByStatus,
    InterviewByType,
    CompanyStats,
)

router = APIRouter()


@router.get("/", response_model=DashboardData)
def get_dashboard_data(db: Session = Depends(get_db)):
    """Get complete dashboard data with statistics and analytics."""

    # Overall stats
    total_applications = db.query(func.count(InterviewProcess.id)).scalar() or 0
    active_processes = (
        db.query(func.count(InterviewProcess.id))
        .filter(
            InterviewProcess.status.notin_(
                ["rejected", "accepted", "withdrew", "ghosted"]
            )
        )
        .scalar()
        or 0
    )
    total_interviews = db.query(func.count(Interview.id)).scalar() or 0
    offers_received = (
        db.query(func.count(InterviewOutcome.id))
        .filter(InterviewOutcome.outcome.in_(["offer", "accepted"]))
        .scalar()
        or 0
    )

    # Calculate acceptance rate
    total_outcomes = db.query(func.count(InterviewOutcome.id)).scalar() or 0
    acceptance_rate = (
        (offers_received / total_outcomes * 100) if total_outcomes > 0 else 0.0
    )

    # Average process duration
    avg_process_duration_days = 0.0

    stats = DashboardStats(
        total_applications=total_applications,
        active_processes=active_processes,
        total_interviews=total_interviews,
        offers_received=offers_received,
        acceptance_rate=round(acceptance_rate, 2),
        avg_process_duration_days=round(avg_process_duration_days, 1),
    )

    # Processes by status
    processes_by_status = (
        db.query(
            InterviewProcess.status, func.count(InterviewProcess.id).label("count")
        )
        .group_by(InterviewProcess.status)
        .all()
    )

    processes_by_status_list = [
        ProcessByStatus(status=status, count=count)
        for status, count in processes_by_status
    ]

    # Interviews by type
    interviews_by_type = (
        db.query(Interview.interview_type, func.count(Interview.id).label("count"))
        .group_by(Interview.interview_type)
        .all()
    )

    interviews_by_type_list = [
        InterviewByType(interview_type=interview_type, count=count)
        for interview_type, count in interviews_by_type
    ]

    # Top companies - simplified
    top_companies_data = (
        db.query(Company.name)
        .join(JobPosition, Company.id == JobPosition.company_id)
        .join(InterviewProcess, JobPosition.id == InterviewProcess.job_position_id)
        .group_by(Company.name)
        .limit(10)
        .all()
    )

    top_companies_list = [
        CompanyStats(
            company_name=name, application_count=0, interview_count=0, offer_count=0
        )
        for (name,) in top_companies_data
    ]

    # Monthly activity for last 6 months
    monthly_activity_list = []

    # Recent activities
    recent_processes = (
        db.query(InterviewProcess)
        .order_by(InterviewProcess.updated_at.desc())
        .limit(10)
        .all()
    )

    recent_activities = [
        {
            "id": p.id,
            "type": "process",
            "status": p.status,
            "date": p.updated_at.isoformat(),
            "job_position_id": p.job_position_id,
        }
        for p in recent_processes
    ]

    return DashboardData(
        stats=stats,
        processes_by_status=processes_by_status_list,
        interviews_by_type=interviews_by_type_list,
        top_companies=top_companies_list,
        monthly_activity=monthly_activity_list,
        recent_activities=recent_activities,
    )


@router.get("/stats", response_model=DashboardStats)
def get_stats(db: Session = Depends(get_db)):
    """Get quick dashboard statistics."""
    total_applications = db.query(func.count(InterviewProcess.id)).scalar() or 0
    active_processes = (
        db.query(func.count(InterviewProcess.id))
        .filter(
            InterviewProcess.status.notin_(
                ["rejected", "accepted", "withdrew", "ghosted"]
            )
        )
        .scalar()
        or 0
    )
    total_interviews = db.query(func.count(Interview.id)).scalar() or 0
    offers_received = (
        db.query(func.count(InterviewOutcome.id))
        .filter(InterviewOutcome.outcome.in_(["offer", "accepted"]))
        .scalar()
        or 0
    )

    total_outcomes = db.query(func.count(InterviewOutcome.id)).scalar() or 0
    acceptance_rate = (
        (offers_received / total_outcomes * 100) if total_outcomes > 0 else 0.0
    )

    avg_process_duration_days = 0.0

    return DashboardStats(
        total_applications=total_applications,
        active_processes=active_processes,
        total_interviews=total_interviews,
        offers_received=offers_received,
        acceptance_rate=round(acceptance_rate, 2),
        avg_process_duration_days=round(avg_process_duration_days, 1),
    )
