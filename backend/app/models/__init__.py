"""
Models package.
Export all models for easier imports.
"""
from app.models.company import Company
from app.models.job_position import JobPosition
from app.models.interview_process import InterviewProcess
from app.models.interview import Interview
from app.models.interview_outcome import InterviewOutcome

__all__ = [
    "Company",
    "JobPosition",
    "InterviewProcess",
    "Interview",
    "InterviewOutcome",
]
