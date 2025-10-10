"""
Interview Process SQLAlchemy model.
Maps to hirewire.interview_processes table.
"""
from sqlalchemy import Column, Integer, String, Date, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import relationship
from app.db.base import Base


class InterviewProcess(Base):
    """Interview Process model."""

    __tablename__ = "interview_processes"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("hirewire.users.id"), nullable=False, index=True)
    job_position_id = Column(Integer, ForeignKey("hirewire.job_positions.id"), nullable=False, index=True)
    application_date = Column(Date, nullable=False, index=True)
    status = Column(String, nullable=False, index=True)
    source = Column(String)
    notes = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    user = relationship("User", back_populates="interview_processes")
    job_position = relationship("JobPosition", back_populates="interview_processes")
    interviews = relationship("Interview", back_populates="process", cascade="all, delete-orphan")
    outcome = relationship("InterviewOutcome", back_populates="process", uselist=False, cascade="all, delete-orphan")
