"""
Interview Outcome schemas for request/response validation.
"""
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field


class InterviewOutcomeBase(BaseModel):
    """Base schema for interview outcome."""
    process_id: int
    outcome: str = Field(..., max_length=50)
    outcome_date: date
    offer_salary: Optional[int] = Field(None, ge=0)
    offer_details: Optional[str] = None
    rejection_reason: Optional[str] = None
    feedback_received: Optional[str] = None
    notes: Optional[str] = None


class InterviewOutcomeCreate(InterviewOutcomeBase):
    """Schema for creating an interview outcome."""
    pass


class InterviewOutcomeUpdate(BaseModel):
    """Schema for updating an interview outcome."""
    process_id: Optional[int] = None
    outcome: Optional[str] = Field(None, max_length=50)
    outcome_date: Optional[date] = None
    offer_salary: Optional[int] = Field(None, ge=0)
    offer_details: Optional[str] = None
    rejection_reason: Optional[str] = None
    feedback_received: Optional[str] = None
    notes: Optional[str] = None


class InterviewOutcomeResponse(InterviewOutcomeBase):
    """Schema for interview outcome response."""
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
