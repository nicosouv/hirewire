"""
Dashboard schemas for statistics and analytics.
"""

from typing import List, Dict, Any
from pydantic import BaseModel


class DashboardStats(BaseModel):
    """Overall dashboard statistics."""

    total_applications: int
    active_processes: int
    total_interviews: int
    offers_received: int
    acceptance_rate: float
    avg_process_duration_days: float


class ProcessByStatus(BaseModel):
    """Processes grouped by status."""

    status: str
    count: int


class InterviewByType(BaseModel):
    """Interviews grouped by type."""

    interview_type: str
    count: int


class CompanyStats(BaseModel):
    """Statistics by company."""

    company_name: str
    application_count: int
    interview_count: int
    offer_count: int


class MonthlyActivity(BaseModel):
    """Monthly activity statistics."""

    month: str
    applications: int
    interviews: int


class DashboardData(BaseModel):
    """Complete dashboard data."""

    stats: DashboardStats
    processes_by_status: List[ProcessByStatus]
    interviews_by_type: List[InterviewByType]
    top_companies: List[CompanyStats]
    monthly_activity: List[MonthlyActivity]
    recent_activities: List[Dict[str, Any]]
