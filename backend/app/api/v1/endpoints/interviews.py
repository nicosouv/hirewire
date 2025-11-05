"""
Interview API endpoints with ProcessStatusService integration.
"""

from typing import List
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.db.session import get_db
from app.models.interview import Interview
from app.models.interview_process import InterviewProcess
from app.schemas.interview import InterviewCreate, InterviewUpdate, InterviewResponse
from app.services.process_status_service import ProcessStatusService

router = APIRouter()


@router.get("/", response_model=List[InterviewResponse])
def list_interviews(
    skip: int = 0,
    limit: int = 100,
    process_id: int = None,
    status: str = None,
    db: Session = Depends(get_db),
):
    """List all interviews with optional filtering."""
    query = db.query(Interview)
    if process_id:
        query = query.filter(Interview.process_id == process_id)
    if status:
        query = query.filter(Interview.status == status)
    interviews = (
        query.order_by(Interview.scheduled_date.desc()).offset(skip).limit(limit).all()
    )
    return interviews


@router.get("/{interview_id}", response_model=InterviewResponse)
def get_interview(interview_id: int, db: Session = Depends(get_db)):
    """Get a specific interview by ID."""
    interview = db.query(Interview).filter(Interview.id == interview_id).first()
    if not interview:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview with id {interview_id} not found",
        )
    return interview


@router.post("/", response_model=InterviewResponse, status_code=status.HTTP_201_CREATED)
def create_interview(interview: InterviewCreate, db: Session = Depends(get_db)):
    """Create a new interview and update process status accordingly."""
    # Verify process exists
    process = (
        db.query(InterviewProcess)
        .filter(InterviewProcess.id == interview.process_id)
        .first()
    )
    if not process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {interview.process_id} not found",
        )

    # Auto-calculate interview_round if not provided
    interview_data = interview.model_dump()
    if interview_data.get("interview_round") is None:
        # Get the max interview_round for this process
        max_round = (
            db.query(Interview.interview_round)
            .filter(Interview.process_id == interview.process_id)
            .order_by(Interview.interview_round.desc())
            .first()
        )

        interview_data["interview_round"] = (max_round[0] + 1) if max_round else 1

    db_interview = Interview(**interview_data)
    db.add(db_interview)
    db.commit()
    db.refresh(db_interview)

    # Update process status based on interview
    ProcessStatusService.update_process_status_from_interview(db, db_interview)

    # Check and unlock achievements
    if process:
        db.execute(
            text("SELECT * FROM hirewire.check_achievements(:user_id)"),
            {"user_id": process.user_id},
        )
        db.commit()

    return db_interview


@router.put("/{interview_id}", response_model=InterviewResponse)
def update_interview(
    interview_id: int, interview: InterviewUpdate, db: Session = Depends(get_db)
):
    """Update an interview and cascade status changes to process."""
    db_interview = db.query(Interview).filter(Interview.id == interview_id).first()
    if not db_interview:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview with id {interview_id} not found",
        )

    update_data = interview.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_interview, field, value)

    db.commit()
    db.refresh(db_interview)

    # Update process status based on interview changes
    ProcessStatusService.update_process_status_from_interview(db, db_interview)

    return db_interview


@router.patch("/{interview_id}/complete", response_model=InterviewResponse)
def mark_interview_completed(
    interview_id: int, actual_date: date = None, db: Session = Depends(get_db)
):
    """Mark a past scheduled interview as completed."""
    updated_interview = ProcessStatusService.update_past_interview_to_completed(
        db, interview_id, actual_date or date.today()
    )
    return updated_interview


@router.delete("/{interview_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_interview(interview_id: int, db: Session = Depends(get_db)):
    """Delete an interview."""
    db_interview = db.query(Interview).filter(Interview.id == interview_id).first()
    if not db_interview:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview with id {interview_id} not found",
        )

    db.delete(db_interview)
    db.commit()
    return None
