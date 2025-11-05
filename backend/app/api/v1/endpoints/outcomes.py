"""
Interview Outcome API endpoints with ProcessStatusService integration.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.interview_outcome import InterviewOutcome
from app.schemas.interview_outcome import (
    InterviewOutcomeCreate,
    InterviewOutcomeUpdate,
    InterviewOutcomeResponse,
)
from app.services.process_status_service import ProcessStatusService

router = APIRouter()


@router.get("/", response_model=List[InterviewOutcomeResponse])
def list_outcomes(
    skip: int = 0,
    limit: int = 100,
    process_id: int = None,
    outcome: str = None,
    db: Session = Depends(get_db),
):
    """List all interview outcomes with optional filtering."""
    query = db.query(InterviewOutcome)
    if process_id:
        query = query.filter(InterviewOutcome.process_id == process_id)
    if outcome:
        query = query.filter(InterviewOutcome.outcome == outcome)
    outcomes = (
        query.order_by(InterviewOutcome.outcome_date.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return outcomes


@router.get("/{outcome_id}", response_model=InterviewOutcomeResponse)
def get_outcome(outcome_id: int, db: Session = Depends(get_db)):
    """Get a specific outcome by ID."""
    outcome = (
        db.query(InterviewOutcome).filter(InterviewOutcome.id == outcome_id).first()
    )
    if not outcome:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Outcome with id {outcome_id} not found",
        )
    return outcome


@router.post(
    "/", response_model=InterviewOutcomeResponse, status_code=status.HTTP_201_CREATED
)
def create_outcome(outcome: InterviewOutcomeCreate, db: Session = Depends(get_db)):
    """Create a new interview outcome and update process status accordingly."""
    # Check if outcome already exists for this process
    existing = (
        db.query(InterviewOutcome)
        .filter(InterviewOutcome.process_id == outcome.process_id)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Outcome already exists for process {outcome.process_id}",
        )

    db_outcome = InterviewOutcome(**outcome.model_dump())
    db.add(db_outcome)
    db.commit()
    db.refresh(db_outcome)

    # Update process status based on outcome
    ProcessStatusService.update_process_status_from_outcome(db, db_outcome)

    return db_outcome


@router.put("/{outcome_id}", response_model=InterviewOutcomeResponse)
def update_outcome(
    outcome_id: int, outcome: InterviewOutcomeUpdate, db: Session = Depends(get_db)
):
    """Update an interview outcome and cascade status changes to process."""
    db_outcome = (
        db.query(InterviewOutcome).filter(InterviewOutcome.id == outcome_id).first()
    )
    if not db_outcome:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Outcome with id {outcome_id} not found",
        )

    update_data = outcome.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_outcome, field, value)

    db.commit()
    db.refresh(db_outcome)

    # Update process status based on outcome changes
    ProcessStatusService.update_process_status_from_outcome(db, db_outcome)

    return db_outcome


@router.delete("/{outcome_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_outcome(outcome_id: int, db: Session = Depends(get_db)):
    """Delete an interview outcome."""
    db_outcome = (
        db.query(InterviewOutcome).filter(InterviewOutcome.id == outcome_id).first()
    )
    if not db_outcome:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Outcome with id {outcome_id} not found",
        )

    db.delete(db_outcome)
    db.commit()
    return None
