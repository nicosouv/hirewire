"""
Interview SQLAlchemy model.
Maps to hirewire.interviews table.
"""
from sqlalchemy import Column, Integer, String, Date, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import relationship
from app.db.base import Base


class Interview(Base):
    """Interview model."""

    __tablename__ = "interviews"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    process_id = Column(Integer, ForeignKey("hirewire.interview_processes.id"), nullable=False, index=True)
    interview_type = Column(String)
    interview_round = Column(Integer, nullable=False)
    scheduled_date = Column(Date)
    actual_date = Column(Date)
    duration_minutes = Column(Integer)
    interviewer_name = Column(String)
    interviewer_role = Column(String)
    status = Column(String, nullable=False, index=True)
    feedback = Column(Text)
    rating = Column(Integer)
    technical_topics = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    process = relationship("InterviewProcess", back_populates="interviews")
