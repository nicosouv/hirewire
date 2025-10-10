"""
Interview schemas for request/response validation.
"""
from datetime import date, datetime, time
from typing import Optional
from pydantic import BaseModel, Field


class InterviewBase(BaseModel):
    """Base schema for interview."""
    process_id: int
    interview_type: str = Field(..., max_length=100)
    round_number: Optional[int] = Field(None, ge=1)
    scheduled_date: date
    scheduled_time: Optional[time] = None
    duration_minutes: Optional[int] = Field(None, ge=0)
    location: Optional[str] = Field(None, max_length=255)
    interviewer_name: Optional[str] = Field(None, max_length=255)
    interviewer_role: Optional[str] = Field(None, max_length=255)
    interview_format: Optional[str] = Field(None, max_length=100)
    status: str = Field(default="scheduled", max_length=50)
    actual_date: Optional[date] = None
    feedback: Optional[str] = None
    notes: Optional[str] = None


class InterviewCreate(InterviewBase):
    """Schema for creating an interview."""
    pass


class InterviewUpdate(BaseModel):
    """Schema for updating an interview."""
    process_id: Optional[int] = None
    interview_type: Optional[str] = Field(None, max_length=100)
    round_number: Optional[int] = Field(None, ge=1)
    scheduled_date: Optional[date] = None
    scheduled_time: Optional[time] = None
    duration_minutes: Optional[int] = Field(None, ge=0)
    location: Optional[str] = Field(None, max_length=255)
    interviewer_name: Optional[str] = Field(None, max_length=255)
    interviewer_role: Optional[str] = Field(None, max_length=255)
    interview_format: Optional[str] = Field(None, max_length=100)
    status: Optional[str] = Field(None, max_length=50)
    actual_date: Optional[date] = None
    feedback: Optional[str] = None
    notes: Optional[str] = None


class InterviewResponse(InterviewBase):
    """Schema for interview response."""
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
