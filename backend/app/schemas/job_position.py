"""
Job Position schemas for request/response validation.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class JobPositionBase(BaseModel):
    """Base schema for job position."""

    title: str = Field(..., min_length=1, max_length=255)
    company_id: int
    department: Optional[str] = Field(None, max_length=100)
    level: Optional[str] = Field(None, max_length=100)
    employment_type: Optional[str] = Field(None, max_length=100)
    remote_policy: Optional[str] = Field(None, max_length=100)
    salary_min: Optional[int] = Field(None, ge=0)
    salary_max: Optional[int] = Field(None, ge=0)
    currency: Optional[str] = Field(None, max_length=3)
    location: Optional[str] = Field(None, max_length=255)
    job_description: Optional[str] = None
    requirements: Optional[str] = None
    benefits: Optional[str] = None
    application_url: Optional[str] = Field(None, max_length=500)
    notes: Optional[str] = None


class JobPositionCreate(JobPositionBase):
    """Schema for creating a job position."""

    pass


class JobPositionUpdate(BaseModel):
    """Schema for updating a job position."""

    title: Optional[str] = Field(None, min_length=1, max_length=255)
    company_id: Optional[int] = None
    department: Optional[str] = Field(None, max_length=100)
    level: Optional[str] = Field(None, max_length=100)
    employment_type: Optional[str] = Field(None, max_length=100)
    remote_policy: Optional[str] = Field(None, max_length=100)
    salary_min: Optional[int] = Field(None, ge=0)
    salary_max: Optional[int] = Field(None, ge=0)
    currency: Optional[str] = Field(None, max_length=3)
    location: Optional[str] = Field(None, max_length=255)
    job_description: Optional[str] = None
    requirements: Optional[str] = None
    benefits: Optional[str] = None
    application_url: Optional[str] = Field(None, max_length=500)
    notes: Optional[str] = None


class JobPositionResponse(JobPositionBase):
    """Schema for job position response."""

    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
