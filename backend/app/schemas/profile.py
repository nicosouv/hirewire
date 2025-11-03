"""
User Profile Schemas (Pydantic)
Request/Response models for profile API endpoints
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List, Dict, Any
from datetime import datetime


class LanguageSchema(BaseModel):
    """Language proficiency schema"""
    language: str = Field(..., min_length=2, max_length=50)
    proficiency: str = Field(..., description="native, fluent, intermediate, basic")

    @validator('proficiency')
    def validate_proficiency(cls, v):
        valid_levels = ['native', 'fluent', 'intermediate', 'basic']
        if v not in valid_levels:
            raise ValueError(f'proficiency must be one of {valid_levels}')
        return v


class LocationPreferencesSchema(BaseModel):
    """Location preferences schema"""
    remote: bool = False
    hybrid: bool = False
    onsite: bool = False
    cities: List[str] = Field(default_factory=list)


class ProfileBase(BaseModel):
    """Base profile schema with common fields"""
    current_job_title: Optional[str] = Field(None, max_length=255)
    target_job_title: Optional[str] = Field(None, max_length=255)
    years_of_experience: Optional[int] = Field(None, ge=0, le=50)
    industries: Optional[List[str]] = None
    skills: Optional[List[str]] = None
    education_level: Optional[str] = Field(None, max_length=100)
    certifications: Optional[List[str]] = None
    languages: Optional[List[LanguageSchema]] = None
    work_authorization: Optional[str] = Field(None, max_length=100)
    location_preferences: Optional[LocationPreferencesSchema] = None
    salary_expectations_min: Optional[int] = Field(None, ge=0)
    salary_expectations_max: Optional[int] = Field(None, ge=0)
    current_salary: Optional[int] = Field(None, ge=0)
    preferred_interview_language: Optional[str] = Field("English", max_length=50)
    ai_interview_prep_enabled: Optional[bool] = True
    profile_visibility: Optional[str] = Field("private", pattern="^(private|public)$")

    @validator('salary_expectations_max')
    def validate_salary_range(cls, v, values):
        """Ensure max salary >= min salary"""
        if v is not None and 'salary_expectations_min' in values:
            min_salary = values.get('salary_expectations_min')
            if min_salary is not None and v < min_salary:
                raise ValueError('salary_expectations_max must be >= salary_expectations_min')
        return v


class ProfileCreate(ProfileBase):
    """Schema for creating a profile"""
    pass


class ProfileUpdate(ProfileBase):
    """Schema for updating a profile (all fields optional)"""
    pass


class ProfileResponse(ProfileBase):
    """Schema for profile API responses"""
    id: int
    user_id: int
    data_processing_consent: bool
    data_processing_consent_date: Optional[datetime]
    resume_file_url: Optional[str]
    resume_uploaded_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ConsentRequest(BaseModel):
    """Schema for data processing consent"""
    consent: bool = Field(..., description="True to give consent, False to revoke")


class ConsentResponse(BaseModel):
    """Response for consent update"""
    message: str
    consent: bool
    consent_date: Optional[datetime]


class DataExportResponse(BaseModel):
    """Response for data export request"""
    message: str
    request_id: int
    status: str = "pending"


class AccountDeletionResponse(BaseModel):
    """Response for account deletion request"""
    message: str
    request_id: int
    grace_period_days: int = 30


class ProfileSummary(BaseModel):
    """Lightweight profile summary for AI context"""
    current_job_title: Optional[str]
    target_job_title: Optional[str]
    years_of_experience: Optional[int]
    skills: Optional[List[str]]
    industries: Optional[List[str]]
    preferred_interview_language: str = "English"

    class Config:
        from_attributes = True
