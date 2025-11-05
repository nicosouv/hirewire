"""
Database base class and imports.
Import all models here for Alembic to detect them.
"""

from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

# Import all models here for Alembic
# from app.models.company import Company
# from app.models.job_position import JobPosition
# from app.models.interview_process import InterviewProcess
# from app.models.interview import Interview
# from app.models.interview_outcome import InterviewOutcome
