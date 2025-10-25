"""
Job Position API endpoints.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.job_position import JobPosition
from app.schemas.job_position import JobPositionCreate, JobPositionUpdate, JobPositionResponse

router = APIRouter()


@router.get("/", response_model=List[JobPositionResponse])
def list_job_positions(
    skip: int = 0,
    limit: int = 100,
    company_id: int = None,
    db: Session = Depends(get_db)
):
    """List all job positions with optional filtering."""
    query = db.query(JobPosition)
    if company_id:
        query = query.filter(JobPosition.company_id == company_id)
    job_positions = query.offset(skip).limit(limit).all()
    return job_positions


@router.get("/{job_position_id}", response_model=JobPositionResponse)
def get_job_position(job_position_id: int, db: Session = Depends(get_db)):
    """Get a specific job position by ID."""
    job_position = db.query(JobPosition).filter(JobPosition.id == job_position_id).first()
    if not job_position:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job position with id {job_position_id} not found"
        )
    return job_position


@router.post("/", response_model=JobPositionResponse, status_code=status.HTTP_201_CREATED)
def create_job_position(job_position: JobPositionCreate, db: Session = Depends(get_db)):
    """Create a new job position."""
    # Convert schema to dict
    position_data = job_position.model_dump(exclude_unset=True)

    # Remove fields that don't exist in the database model
    position_data.pop('location', None)
    position_data.pop('job_description', None)
    position_data.pop('requirements', None)
    position_data.pop('benefits', None)
    position_data.pop('application_url', None)
    position_data.pop('notes', None)
    position_data.pop('salary_range', None)

    db_job_position = JobPosition(**position_data)
    db.add(db_job_position)
    db.commit()
    db.refresh(db_job_position)
    return db_job_position


@router.put("/{job_position_id}", response_model=JobPositionResponse)
def update_job_position(
    job_position_id: int,
    job_position: JobPositionUpdate,
    db: Session = Depends(get_db)
):
    """Update a job position."""
    db_job_position = db.query(JobPosition).filter(JobPosition.id == job_position_id).first()
    if not db_job_position:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job position with id {job_position_id} not found"
        )

    update_data = job_position.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_job_position, field, value)

    db.commit()
    db.refresh(db_job_position)
    return db_job_position


@router.delete("/{job_position_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_job_position(job_position_id: int, db: Session = Depends(get_db)):
    """Delete a job position."""
    db_job_position = db.query(JobPosition).filter(JobPosition.id == job_position_id).first()
    if not db_job_position:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job position with id {job_position_id} not found"
        )

    db.delete(db_job_position)
    db.commit()
    return None
