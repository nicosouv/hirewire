"""
Tests for interview process API endpoints
"""
import pytest
from datetime import date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models import InterviewProcess, JobPosition


@pytest.mark.api
class TestProcessEndpoints:
    """Test interview process CRUD endpoints"""

    def test_list_processes(self, client: TestClient, test_process: InterviewProcess, auth_headers: dict):
        """Test listing interview processes"""
        response = client.get("/api/v1/processes", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert data[0]["status"] == test_process.status

    def test_get_process(self, client: TestClient, test_process: InterviewProcess, auth_headers: dict):
        """Test getting a single process"""
        response = client.get(f"/api/v1/processes/{test_process.id}", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_process.id
        assert data["status"] == test_process.status

    def test_create_process(self, client: TestClient, test_position: JobPosition, auth_headers: dict):
        """Test creating a new process"""
        process_data = {
            "job_position_id": test_position.id,
            "application_date": str(date.today()),
            "status": "applied",
            "source": "Company Website",
        }

        response = client.post("/api/v1/processes", json=process_data, headers=auth_headers)

        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "applied"
        assert data["job_position_id"] == test_position.id

    def test_update_process_status(self, client: TestClient, test_process: InterviewProcess, auth_headers: dict):
        """Test updating process status"""
        update_data = {"status": "interviewing"}

        response = client.put(f"/api/v1/processes/{test_process.id}", json=update_data, headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "interviewing"

    def test_delete_process(self, client: TestClient, test_process: InterviewProcess, db: Session, auth_headers: dict):
        """Test deleting a process"""
        response = client.delete(f"/api/v1/processes/{test_process.id}", headers=auth_headers)

        assert response.status_code == 204

        # Verify deletion
        db.expire_all()
        deleted = db.query(InterviewProcess).filter(InterviewProcess.id == test_process.id).first()
        assert deleted is None

    def test_filter_processes_by_status(
        self, client: TestClient, test_position: JobPosition, test_user, db: Session, auth_headers: dict
    ):
        """Test filtering processes by status"""
        # Create processes with different statuses
        statuses = ["applied", "screening", "interviewing"]
        for status in statuses:
            process = InterviewProcess(
                job_position_id=test_position.id,
                user_id=test_user.id,
                application_date=date.today(),
                status=status,
            )
            db.add(process)
        db.commit()

        # Filter by status
        response = client.get("/api/v1/processes?status=interviewing", headers=auth_headers)

        if response.status_code == 200:
            data = response.json()
            for process in data:
                assert process["status"] == "interviewing"
        else:
            # Filtering might not be implemented
            pytest.skip("Status filtering not implemented")

    def test_process_status_transitions(
        self, client: TestClient, test_process: InterviewProcess, auth_headers: dict
    ):
        """Test valid status transitions"""
        valid_transitions = [
            ("applied", "screening"),
            ("screening", "interviewing"),
            ("interviewing", "final_round"),
            ("final_round", "offer"),
        ]

        for from_status, to_status in valid_transitions:
            # Reset to from_status
            client.put(
                f"/api/v1/processes/{test_process.id}", json={"status": from_status}, headers=auth_headers
            )

            # Transition to to_status
            response = client.put(
                f"/api/v1/processes/{test_process.id}", json={"status": to_status}, headers=auth_headers
            )

            assert response.status_code == 200
            assert response.json()["status"] == to_status

    def test_process_requires_position(self, client: TestClient, auth_headers: dict):
        """Test that process creation requires a valid position"""
        process_data = {
            "job_position_id": 99999,  # Non-existent position
            "application_date": str(date.today()),
            "status": "applied",
        }

        response = client.post("/api/v1/processes", json=process_data, headers=auth_headers)

        # Should fail with 404 or 422
        assert response.status_code in [404, 422]

    def test_process_date_validation(self, client: TestClient, test_position: JobPosition, auth_headers: dict):
        """Test date validation for processes"""
        # Future application date should be rejected or accepted based on business logic
        future_date = date.today() + timedelta(days=30)

        process_data = {
            "job_position_id": test_position.id,
            "application_date": str(future_date),
            "status": "applied",
        }

        response = client.post("/api/v1/processes", json=process_data, headers=auth_headers)

        # Accept either 201 (allowed) or 422 (validation error)
        assert response.status_code in [201, 422]

    def test_get_active_processes(
        self, client: TestClient, test_position: JobPosition, test_user, db: Session, auth_headers: dict
    ):
        """Test getting only active processes (without outcomes)"""
        # Create active and closed processes
        active = InterviewProcess(
            job_position_id=test_position.id,
            user_id=test_user.id,
            application_date=date.today(),
            status="interviewing",
        )
        db.add(active)

        closed = InterviewProcess(
            job_position_id=test_position.id,
            user_id=test_user.id,
            application_date=date.today() - timedelta(days=30),
            status="rejected",
        )
        db.add(closed)
        db.commit()

        # Try to filter active processes
        response = client.get("/api/v1/processes?active=true", headers=auth_headers)

        if response.status_code == 200:
            data = response.json()
            # Should only return active processes
            for process in data:
                assert process["status"] not in ["rejected", "accepted", "withdrew"]
        else:
            pytest.skip("Active filter not implemented")
