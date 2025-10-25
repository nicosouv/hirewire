"""
Export schemas for request/response validation.
"""
from pydantic import BaseModel, EmailStr, field_validator
from datetime import date, datetime
from typing import Optional
from app.models.export import ExportStatus, ExportFormat


class ExportCreate(BaseModel):
    """Schema for creating a new export request."""
    start_date: date
    end_date: date
    format: ExportFormat
    recipient_email: EmailStr

    @field_validator('end_date')
    def validate_date_range(cls, v, info):
        if 'start_date' in info.data and v < info.data['start_date']:
            raise ValueError('end_date must be after start_date')
        return v


class ExportUpdate(BaseModel):
    """Schema for updating export status (used by Airflow)."""
    status: Optional[ExportStatus] = None
    airflow_dag_run_id: Optional[str] = None
    file_path: Optional[str] = None
    error_message: Optional[str] = None
    completed_at: Optional[datetime] = None


class ExportResponse(BaseModel):
    """Schema for export response."""
    id: int
    user_id: int
    start_date: date
    end_date: date
    format: ExportFormat
    recipient_email: str
    status: ExportStatus
    airflow_dag_run_id: Optional[str] = None
    file_path: Optional[str] = None
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True
