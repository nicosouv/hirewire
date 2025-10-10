"""
Job Position SQLAlchemy model.
Maps to hirewire.job_positions table.
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Numeric, func
from sqlalchemy.orm import relationship
from app.db.base import Base


class JobPosition(Base):
    """Job Position model."""

    __tablename__ = "job_positions"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, ForeignKey("hirewire.companies.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    department = Column(String)
    level = Column(String)
    employment_type = Column(String)
    remote_policy = Column(String)
    salary_min = Column(Numeric)
    salary_max = Column(Numeric)
    currency = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    company = relationship("Company", back_populates="job_positions")
    interview_processes = relationship("InterviewProcess", back_populates="job_position", cascade="all, delete-orphan")
