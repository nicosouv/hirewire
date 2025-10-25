"""
Export endpoints for generating and managing data exports.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import httpx
import os
from datetime import datetime

from app.db.session import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.export import Export, ExportStatus
from app.schemas.export import ExportCreate, ExportResponse, ExportUpdate

router = APIRouter()

# Airflow configuration
AIRFLOW_BASE_URL = os.getenv("AIRFLOW_BASE_URL", "http://airflow-webserver:8080")
AIRFLOW_USERNAME = os.getenv("AIRFLOW_USERNAME", "admin")
AIRFLOW_PASSWORD = os.getenv("AIRFLOW_PASSWORD", "admin")


@router.post("/", response_model=ExportResponse, status_code=status.HTTP_201_CREATED)
async def request_export(
    export_in: ExportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Request a new export. This will:
    1. Create an export record in the database
    2. Trigger the Airflow DAG to generate the export
    3. Return the export details

    The user will receive the export via email once it's ready.
    """
    # Create export record
    db_export = Export(
        user_id=current_user.id,
        start_date=export_in.start_date,
        end_date=export_in.end_date,
        format=export_in.format,
        recipient_email=export_in.recipient_email,
        status=ExportStatus.PENDING
    )
    db.add(db_export)
    db.commit()
    db.refresh(db_export)

    # Trigger Airflow DAG
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{AIRFLOW_BASE_URL}/api/v2/dags/generate_export_report/dagRuns",
                auth=(AIRFLOW_USERNAME, AIRFLOW_PASSWORD),
                json={
                    "conf": {
                        "export_id": db_export.id,
                        "user_id": current_user.id,
                        "start_date": export_in.start_date.isoformat(),
                        "end_date": export_in.end_date.isoformat(),
                        "format": export_in.format.value,
                        "recipient_email": export_in.recipient_email
                    }
                },
                timeout=10.0
            )

            if response.status_code == 200:
                dag_run_data = response.json()
                db_export.airflow_dag_run_id = dag_run_data.get("dag_run_id")
                db_export.status = ExportStatus.PROCESSING
                db.commit()
                db.refresh(db_export)
            else:
                # Failed to trigger DAG
                db_export.status = ExportStatus.FAILED
                db_export.error_message = f"Failed to trigger Airflow DAG: {response.text}"
                db.commit()
                db.refresh(db_export)

    except Exception as e:
        # Error triggering DAG
        db_export.status = ExportStatus.FAILED
        db_export.error_message = f"Error triggering Airflow DAG: {str(e)}"
        db.commit()
        db.refresh(db_export)

    return db_export


@router.get("/", response_model=List[ExportResponse])
def list_exports(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    List all exports for the current user.
    """
    exports = db.query(Export).filter(
        Export.user_id == current_user.id
    ).order_by(Export.created_at.desc()).offset(skip).limit(limit).all()

    return exports


@router.get("/{export_id}", response_model=ExportResponse)
def get_export(
    export_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific export by ID.
    """
    export = db.query(Export).filter(
        Export.id == export_id,
        Export.user_id == current_user.id
    ).first()

    if not export:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export not found"
        )

    return export


@router.get("/{export_id}/data")
async def get_export_data(
    export_id: int,
    db: Session = Depends(get_db)
):
    """
    Get export data for generating the file.
    This endpoint is called by Airflow DAG (internal call, no auth required).
    Returns all the necessary data for the export.
    """
    export = db.query(Export).filter(Export.id == export_id).first()

    if not export:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export not found"
        )

    # Import here to avoid circular imports
    from sqlalchemy import text

    # Query applications with interview counts
    applications_query = text("""
        SELECT
            p.id as process_id,
            c.name as company_name,
            jp.title as position_title,
            p.status,
            p.application_date,
            COUNT(DISTINCT i.id) as interview_count,
            MIN(i.scheduled_date) as first_interview_date,
            o.outcome_type,
            o.outcome_date
        FROM hirewire.interview_processes p
        JOIN hirewire.job_positions jp ON p.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        LEFT JOIN hirewire.interviews i ON p.id = i.process_id
        LEFT JOIN hirewire.interview_outcomes o ON p.id = o.process_id
        WHERE p.application_date BETWEEN :start_date AND :end_date
        GROUP BY p.id, c.name, jp.title, p.status, p.application_date, o.outcome_type, o.outcome_date
        ORDER BY p.application_date DESC
    """)

    applications = db.execute(
        applications_query,
        {"start_date": export.start_date, "end_date": export.end_date}
    ).fetchall()

    # Query interviews details
    interviews_query = text("""
        SELECT
            i.id,
            c.name as company_name,
            jp.title as position_title,
            i.interview_type,
            i.scheduled_date,
            i.duration_minutes,
            i.interviewer_name,
            i.interviewer_role,
            i.location,
            i.feedback
        FROM hirewire.interviews i
        JOIN hirewire.interview_processes p ON i.process_id = p.id
        JOIN hirewire.job_positions jp ON p.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        WHERE p.application_date BETWEEN :start_date AND :end_date
        ORDER BY i.scheduled_date DESC
    """)

    interviews = db.execute(
        interviews_query,
        {"start_date": export.start_date, "end_date": export.end_date}
    ).fetchall()

    # Query statistics
    stats_query = text("""
        SELECT
            COUNT(DISTINCT p.id) as total_applications,
            COUNT(DISTINCT CASE WHEN o.outcome_type = 'offer' THEN p.id END) as offers_received,
            COUNT(DISTINCT CASE WHEN o.outcome_type = 'rejected' THEN p.id END) as rejections,
            COUNT(DISTINCT i.id) as total_interviews,
            AVG(EXTRACT(DAY FROM (i.scheduled_date - p.application_date))) as avg_days_to_interview
        FROM hirewire.interview_processes p
        LEFT JOIN hirewire.interview_outcomes o ON p.id = o.process_id
        LEFT JOIN hirewire.interviews i ON p.id = i.process_id
        WHERE p.application_date BETWEEN :start_date AND :end_date
    """)

    stats = db.execute(
        stats_query,
        {"start_date": export.start_date, "end_date": export.end_date}
    ).fetchone()

    # Query company statistics
    company_stats_query = text("""
        SELECT
            c.name as company_name,
            COUNT(DISTINCT p.id) as applications,
            COUNT(DISTINCT i.id) as interviews,
            COUNT(DISTINCT CASE WHEN o.outcome_type = 'offer' THEN p.id END) as offers
        FROM hirewire.companies c
        JOIN hirewire.job_positions jp ON c.id = jp.company_id
        JOIN hirewire.interview_processes p ON jp.id = p.job_position_id
        LEFT JOIN hirewire.interviews i ON p.id = i.process_id
        LEFT JOIN hirewire.interview_outcomes o ON p.id = o.process_id
        WHERE p.application_date BETWEEN :start_date AND :end_date
        GROUP BY c.name
        ORDER BY applications DESC
    """)

    company_stats = db.execute(
        company_stats_query,
        {"start_date": export.start_date, "end_date": export.end_date}
    ).fetchall()

    return {
        "export": {
            "id": export.id,
            "start_date": export.start_date.isoformat(),
            "end_date": export.end_date.isoformat(),
            "format": export.format,
            "recipient_email": export.recipient_email
        },
        "applications": [dict(row._mapping) for row in applications],
        "interviews": [dict(row._mapping) for row in interviews],
        "statistics": dict(stats._mapping) if stats else {},
        "company_statistics": [dict(row._mapping) for row in company_stats]
    }


@router.patch("/{export_id}", response_model=ExportResponse)
def update_export_status(
    export_id: int,
    export_update: ExportUpdate,
    db: Session = Depends(get_db)
):
    """
    Update export status. This endpoint is called by Airflow DAG.
    No authentication required (internal call).
    """
    export = db.query(Export).filter(Export.id == export_id).first()

    if not export:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export not found"
        )

    # Update fields
    if export_update.status:
        export.status = export_update.status
    if export_update.airflow_dag_run_id:
        export.airflow_dag_run_id = export_update.airflow_dag_run_id
    if export_update.file_path:
        export.file_path = export_update.file_path
    if export_update.error_message:
        export.error_message = export_update.error_message
    if export_update.completed_at:
        export.completed_at = export_update.completed_at

    db.commit()
    db.refresh(export)

    return export
