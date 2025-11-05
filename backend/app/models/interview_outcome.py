"""
Interview Outcome SQLAlchemy model.
Maps to hirewire.interview_outcomes table.
"""

from sqlalchemy import (
    Column,
    Integer,
    String,
    Date,
    DateTime,
    ForeignKey,
    Text,
    Boolean,
    func,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class InterviewOutcome(Base):
    """Interview Outcome model."""

    __tablename__ = "interview_outcomes"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    process_id = Column(
        Integer,
        ForeignKey("hirewire.interview_processes.id"),
        nullable=False,
        unique=True,
        index=True,
    )
    outcome = Column(String, nullable=False, index=True)
    outcome_date = Column(Date, nullable=False)
    offer_salary = Column(Integer)
    offer_currency = Column(String)
    rejection_reason = Column(Text)
    feedback_received = Column(Boolean)
    would_reapply = Column(Boolean)
    overall_experience_rating = Column(Integer)
    notes = Column(Text)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    process = relationship("InterviewProcess", back_populates="outcome")
