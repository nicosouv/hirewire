"""
Interview schemas for request/response validation.
"""
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field


class InterviewBase(BaseModel):
    """Base schema for interview."""
    process_id: int
    interview_type: Optional[str] = Field(None, max_length=100)
    interview_round: int = Field(..., ge=1)
    scheduled_date: Optional[datetime] = None
    actual_date: Optional[datetime] = None
    duration_minutes: Optional[int] = Field(None, ge=0)
    interviewer_name: Optional[str] = Field(None, max_length=255)
    interviewer_role: Optional[str] = Field(None, max_length=255)
    status: str = Field(default="scheduled", max_length=50)
    feedback: Optional[str] = None
    rating: Optional[int] = Field(None, ge=1, le=5)
    technical_topics: Optional[str] = None


class InterviewCreate(InterviewBase):
    """Schema for creating an interview."""
    pass


class InterviewUpdate(BaseModel):
    """Schema for updating an interview."""
    process_id: Optional[int] = None
    interview_type: Optional[str] = Field(None, max_length=100)
    interview_round: Optional[int] = Field(None, ge=1)
    scheduled_date: Optional[datetime] = None
    actual_date: Optional[datetime] = None
    duration_minutes: Optional[int] = Field(None, ge=0)
    interviewer_name: Optional[str] = Field(None, max_length=255)
    interviewer_role: Optional[str] = Field(None, max_length=255)
    status: Optional[str] = Field(None, max_length=50)
    feedback: Optional[str] = None
    rating: Optional[int] = Field(None, ge=1, le=5)
    technical_topics: Optional[str] = None


class InterviewResponse(InterviewBase):
    """Schema for interview response."""
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
