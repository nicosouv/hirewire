"""
Interview Process API endpoints.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.interview_process import InterviewProcess
from app.schemas.interview_process import InterviewProcessCreate, InterviewProcessUpdate, InterviewProcessResponse

router = APIRouter()


@router.get("/", response_model=List[InterviewProcessResponse])
def list_interview_processes(
    skip: int = 0,
    limit: int = 100,
    job_position_id: int = None,
    status: str = None,
    db: Session = Depends(get_db)
):
    """List all interview processes with optional filtering."""
    query = db.query(InterviewProcess)
    if job_position_id:
        query = query.filter(InterviewProcess.job_position_id == job_position_id)
    if status:
        query = query.filter(InterviewProcess.status == status)
    processes = query.order_by(InterviewProcess.application_date.desc()).offset(skip).limit(limit).all()
    return processes


@router.get("/{process_id}", response_model=InterviewProcessResponse)
def get_interview_process(process_id: int, db: Session = Depends(get_db)):
    """Get a specific interview process by ID."""
    process = db.query(InterviewProcess).filter(InterviewProcess.id == process_id).first()
    if not process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {process_id} not found"
        )
    return process


@router.post("/", response_model=InterviewProcessResponse, status_code=status.HTTP_201_CREATED)
def create_interview_process(process: InterviewProcessCreate, db: Session = Depends(get_db)):
    """Create a new interview process."""
    db_process = InterviewProcess(**process.model_dump())
    db.add(db_process)
    db.commit()
    db.refresh(db_process)
    return db_process


@router.put("/{process_id}", response_model=InterviewProcessResponse)
def update_interview_process(
    process_id: int,
    process: InterviewProcessUpdate,
    db: Session = Depends(get_db)
):
    """Update an interview process."""
    db_process = db.query(InterviewProcess).filter(InterviewProcess.id == process_id).first()
    if not db_process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {process_id} not found"
        )

    update_data = process.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_process, field, value)

    db.commit()
    db.refresh(db_process)
    return db_process


@router.delete("/{process_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_interview_process(process_id: int, db: Session = Depends(get_db)):
    """Delete an interview process."""
    db_process = db.query(InterviewProcess).filter(InterviewProcess.id == process_id).first()
    if not db_process:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interview process with id {process_id} not found"
        )

    db.delete(db_process)
    db.commit()
    return None
