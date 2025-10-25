"""
API v1 router.
Aggregates all API endpoints.
"""
from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth,
    airflow,
    users,
    companies,
    job_positions,
    interview_processes,
    interviews,
    outcomes,
    dashboard,
    exports
)

api_router = APIRouter()

# Authentication (no auth required)
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# Airflow integration (nginx auth_request)
api_router.include_router(airflow.router, prefix="/airflow", tags=["airflow"])

# Users management (admin only)
api_router.include_router(users.router, prefix="/users", tags=["users"])

# Main resources
api_router.include_router(companies.router, prefix="/companies", tags=["companies"])
api_router.include_router(job_positions.router, prefix="/job-positions", tags=["job-positions"])
api_router.include_router(interview_processes.router, prefix="/processes", tags=["processes"])
api_router.include_router(interviews.router, prefix="/interviews", tags=["interviews"])
api_router.include_router(outcomes.router, prefix="/outcomes", tags=["outcomes"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(exports.router, prefix="/exports", tags=["exports"])
