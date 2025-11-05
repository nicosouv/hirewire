"""
Interview Process schemas for request/response validation.
"""

from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field


class InterviewProcessBase(BaseModel):
    """Base schema for interview process."""

    job_position_id: int
    application_date: date
    status: str = Field(..., max_length=50)
    source: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = None


class InterviewProcessCreate(InterviewProcessBase):
    """Schema for creating an interview process."""

    pass


class InterviewProcessUpdate(BaseModel):
    """Schema for updating an interview process."""

    job_position_id: Optional[int] = None
    application_date: Optional[date] = None
    status: Optional[str] = Field(None, max_length=50)
    source: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = None


class InterviewProcessResponse(InterviewProcessBase):
    """Schema for interview process response."""

    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
