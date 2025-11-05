"""
Interview Process API endpoints.
"""

from typing import List
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.db.session import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.interview_process import InterviewProcess
from app.models.interview_outcome import InterviewOutcome
from app.schemas.interview_process import (
    InterviewProcessCreate,
    InterviewProcessUpdate,
    InterviewProcessResponse,
)

router = APIRouter()


@router.get("/", response_model=List[InterviewProcessResponse])
def list_interview_processes(
    skip: int = 0,
    limit: int = 100,
    job_position_id: int = None,
    status: str = None,
    db: Session = Depends(get_db),
):
    """List all interview processes with optional filtering."""
    query = db.query(InterviewProcess)
    if job_position_id:
        query = query.filter(InterviewProcess.job_position_id == job_position_id)
    if status:
        query = query.filter(InterviewProcess.status == status)
    processes = (
        query.order_by(InterviewProcess.application_date.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return processes


@router.get("/{process_id}", response_model=InterviewProcessResponse)
def get_interview_process(process_id: int, db: Session = Depends(get_db)):
    """Get a specific interview process by ID."""
    process = (
        db.query(InterviewProcess).filter(InterviewProcess.id == process_id).first()
    )
    if not process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {process_id} not found",
        )
    return process


@router.post(
    "/", response_model=InterviewProcessResponse, status_code=status.HTTP_201_CREATED
)
def create_interview_process(
    process: InterviewProcessCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new interview process."""
    # Add user_id from authenticated user
    process_data = process.model_dump()
    process_data["user_id"] = current_user.id

    db_process = InterviewProcess(**process_data)
    db.add(db_process)
    db.commit()
    db.refresh(db_process)

    # Check and unlock achievements
    db.execute(
        text("SELECT * FROM hirewire.check_achievements(:user_id)"),
        {"user_id": current_user.id},
    )
    db.commit()

    return db_process


@router.put("/{process_id}", response_model=InterviewProcessResponse)
def update_interview_process(
    process_id: int, process: InterviewProcessUpdate, db: Session = Depends(get_db)
):
    """
    Update an interview process.

    Automatically creates an outcome when status changes to a final status:
    - rejected, refused, ghosted, withdrew → creates corresponding outcome
    - accepted → creates 'accepted' outcome
    """
    db_process = (
        db.query(InterviewProcess).filter(InterviewProcess.id == process_id).first()
    )
    if not db_process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {process_id} not found",
        )

    # Get the old status before updating
    old_status = db_process.status

    update_data = process.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_process, field, value)

    # Check if status changed to a final status
    new_status = db_process.status
    final_statuses = {
        "rejected": "rejected",
        "refused": "rejected",  # Map 'refused' to 'rejected' outcome
        "ghosted": "ghosted",
        "withdrew": "withdrew",
        "accepted": "accepted",
    }

    # If status changed to a final status, create outcome automatically
    if new_status in final_statuses and old_status != new_status:
        outcome_value = final_statuses[new_status]

        # Check if outcome already exists
        existing_outcome = (
            db.query(InterviewOutcome)
            .filter(InterviewOutcome.process_id == process_id)
            .first()
        )

        if not existing_outcome:
            # Create new outcome
            new_outcome = InterviewOutcome(
                process_id=process_id,
                outcome=outcome_value,
                outcome_date=date.today(),
                notes=f"Outcome créé automatiquement lors du changement de statut vers '{new_status}'",
            )
            db.add(new_outcome)
        else:
            # Update existing outcome
            existing_outcome.outcome = outcome_value
            existing_outcome.outcome_date = date.today()
            existing_outcome.notes = (
                existing_outcome.notes or ""
            ) + f"\nMis à jour automatiquement: {old_status} → {new_status}"

    db.commit()
    db.refresh(db_process)
    return db_process


@router.delete("/{process_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_interview_process(process_id: int, db: Session = Depends(get_db)):
    """Delete an interview process."""
    db_process = (
        db.query(InterviewProcess).filter(InterviewProcess.id == process_id).first()
    )
    if not db_process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {process_id} not found",
        )

    db.delete(db_process)
    db.commit()
    return None
