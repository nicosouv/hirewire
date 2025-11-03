"""
User Profile API Endpoints
RGPD-compliant profile management
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.models.profile import UserProfile, DataExportRequest, ProfileAuditLog
from app.schemas.profile import (
    ProfileResponse,
    ProfileUpdate,
    ConsentRequest,
    ConsentResponse,
    DataExportResponse,
    AccountDeletionResponse,
)

router = APIRouter()


# Sensitive fields that require audit logging
SENSITIVE_FIELDS = [
    'salary_expectations_min',
    'salary_expectations_max',
    'current_salary',
    'data_processing_consent',
]


@router.get("/", response_model=ProfileResponse)
def get_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current user's profile.
    Creates an empty profile if it doesn't exist.
    """
    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()

    if not profile:
        # Create empty profile
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)
        db.commit()
        db.refresh(profile)

    return profile


@router.patch("/", response_model=ProfileResponse)
def update_profile(
    profile_data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update current user's profile.
    Logs sensitive field changes for RGPD compliance.
    """
    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()

    if not profile:
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)
        db.flush()  # Get profile ID before updating

    # Update fields and log sensitive changes
    update_data = profile_data.dict(exclude_unset=True)

    for field, value in update_data.items():
        old_value = getattr(profile, field, None)

        # Skip if value hasn't changed
        if old_value == value:
            continue

        # Log changes to sensitive fields
        if field in SENSITIVE_FIELDS:
            audit_entry = ProfileAuditLog(
                user_id=current_user.id,
                field_changed=field,
                old_value=str(old_value) if old_value is not None else None,
                new_value=str(value) if value is not None else None,
            )
            db.add(audit_entry)

        # Update field
        setattr(profile, field, value)

    profile.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(profile)

    return profile


@router.post("/consent", response_model=ConsentResponse)
def update_data_processing_consent(
    consent_data: ConsentRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update data processing consent (RGPD requirement).
    Required for AI-powered features.
    """
    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found. Please create a profile first."
        )

    # Log consent change
    old_consent = profile.data_processing_consent
    if old_consent != consent_data.consent:
        audit_entry = ProfileAuditLog(
            user_id=current_user.id,
            field_changed="data_processing_consent",
            old_value=str(old_consent),
            new_value=str(consent_data.consent),
        )
        db.add(audit_entry)

    # Update consent
    profile.data_processing_consent = consent_data.consent
    profile.data_processing_consent_date = datetime.utcnow()
    profile.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(profile)

    return ConsentResponse(
        message="Data processing consent updated successfully",
        consent=profile.data_processing_consent,
        consent_date=profile.data_processing_consent_date,
    )


@router.post("/export", response_model=DataExportResponse)
def request_data_export(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Request full data export (RGPD right to data portability).
    User will receive an email with download link when ready.
    """
    # Check if there's already a pending export request
    pending_request = db.query(DataExportRequest).filter(
        DataExportRequest.user_id == current_user.id,
        DataExportRequest.request_type == "export",
        DataExportRequest.status == "pending"
    ).first()

    if pending_request:
        return DataExportResponse(
            message="You already have a pending export request. Please wait for it to complete.",
            request_id=pending_request.id,
            status="pending"
        )

    # Create new export request
    export_request = DataExportRequest(
        user_id=current_user.id,
        request_type="export",
        status="pending"
    )
    db.add(export_request)
    db.commit()
    db.refresh(export_request)

    # TODO: Trigger async export job (Celery task)
    # from app.workers.export_worker import generate_user_data_export
    # generate_user_data_export.delay(current_user.id, export_request.id)

    return DataExportResponse(
        message="Data export requested successfully. You will receive an email when your export is ready.",
        request_id=export_request.id,
        status="pending"
    )


@router.delete("/", response_model=AccountDeletionResponse)
def request_account_deletion(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Request account deletion (RGPD right to be forgotten).
    Account will be deleted after 30-day grace period.
    User can cancel deletion within this period.
    """
    # Check if there's already a pending deletion request
    pending_request = db.query(DataExportRequest).filter(
        DataExportRequest.user_id == current_user.id,
        DataExportRequest.request_type == "delete",
        DataExportRequest.status == "pending"
    ).first()

    if pending_request:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already have a pending deletion request."
        )

    # Create deletion request
    deletion_request = DataExportRequest(
        user_id=current_user.id,
        request_type="delete",
        status="pending"
    )
    db.add(deletion_request)
    db.commit()
    db.refresh(deletion_request)

    # TODO: Schedule account deletion in 30 days (Celery task)
    # from app.workers.user_worker import schedule_account_deletion
    # schedule_account_deletion.delay(current_user.id, deletion_request.id)

    return AccountDeletionResponse(
        message="Account deletion requested. Your account will be permanently deleted in 30 days. You can cancel this request anytime before then.",
        request_id=deletion_request.id,
        grace_period_days=30
    )


@router.post("/deletion/{request_id}/cancel")
def cancel_account_deletion(
    request_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Cancel pending account deletion request.
    """
    deletion_request = db.query(DataExportRequest).filter(
        DataExportRequest.id == request_id,
        DataExportRequest.user_id == current_user.id,
        DataExportRequest.request_type == "delete",
        DataExportRequest.status == "pending"
    ).first()

    if not deletion_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Deletion request not found or already processed."
        )

    deletion_request.status = "cancelled"
    deletion_request.completed_at = datetime.utcnow()
    db.commit()

    return {"message": "Account deletion cancelled successfully."}


@router.get("/audit-log")
def get_audit_log(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get audit log of profile changes (RGPD transparency).
    Shows last 50 changes by default.
    """
    audit_entries = db.query(ProfileAuditLog).filter(
        ProfileAuditLog.user_id == current_user.id
    ).order_by(ProfileAuditLog.changed_at.desc()).limit(limit).all()

    return {
        "total": len(audit_entries),
        "entries": [
            {
                "field": entry.field_changed,
                "old_value": entry.old_value,
                "new_value": entry.new_value,
                "changed_at": entry.changed_at,
            }
            for entry in audit_entries
        ]
    }
