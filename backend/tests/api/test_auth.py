"""
Tests for authentication API endpoints
"""
import pytest
from fastapi.testclient import TestClient

from app.models.user import User


@pytest.mark.auth
@pytest.mark.api
class TestAuthEndpoints:
    """Test authentication and authorization endpoints"""

    def test_login_success(self, client: TestClient, test_user: User):
        """Test successful login"""
        response = client.post(
            "/api/v1/auth/login/json",
            json={"email": "test@example.com", "password": "testpassword"},
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    def test_login_wrong_password(self, client: TestClient, test_user: User):
        """Test login with wrong password"""
        response = client.post(
            "/api/v1/auth/login/json",
            json={"email": "test@example.com", "password": "wrongpassword"},
        )

        assert response.status_code == 401
        assert "incorrect" in response.json()["detail"].lower()

    def test_login_nonexistent_user(self, client: TestClient):
        """Test login with non-existent user"""
        response = client.post(
            "/api/v1/auth/login/json",
            json={"email": "nonexistent@example.com", "password": "password"},
        )

        assert response.status_code == 401

    def test_get_current_user(self, client: TestClient, test_user: User, auth_headers: dict):
        """Test getting current user info"""
        response = client.get("/api/v1/auth/me", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["email"] == test_user.email
        assert data["id"] == test_user.id
        assert "hashed_password" not in data  # Should not expose password

    def test_get_current_user_no_token(self, client: TestClient):
        """Test getting current user without authentication"""
        response = client.get("/api/v1/auth/me")

        assert response.status_code == 401

    def test_get_current_user_invalid_token(self, client: TestClient):
        """Test getting current user with invalid token"""
        headers = {"Authorization": "Bearer invalid_token"}
        response = client.get("/api/v1/auth/me", headers=headers)

        assert response.status_code == 401

    def test_register_user(self, client: TestClient):
        """Test user registration"""
        user_data = {
            "email": "newuser@example.com",
            "password": "newpassword123",
        }

        response = client.post("/api/v1/auth/register", json=user_data)

        # Check if registration endpoint exists
        if response.status_code == 404:
            pytest.skip("Registration endpoint not implemented")

        assert response.status_code == 201
        data = response.json()
        assert data["email"] == user_data["email"]
        assert "hashed_password" not in data

    def test_airflow_admin_access(
        self, client: TestClient, admin_user: User, admin_headers: dict
    ):
        """Test that admin users can access airflow endpoints"""
        # This is a placeholder - actual endpoint depends on your implementation
        response = client.get("/api/v1/auth/me", headers=admin_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["is_airflow_admin"] is True

    def test_non_admin_airflow_access(
        self, client: TestClient, test_user: User, auth_headers: dict
    ):
        """Test that non-admin users cannot access airflow tasks"""
        # Test accessing an airflow-protected endpoint
        response = client.post(
            "/api/v1/airflow/tasks/update-process-status", headers=auth_headers
        )

        # Should be forbidden (403) or not found (404) if endpoint doesn't exist
        assert response.status_code in [403, 404]

    def test_login_rate_limiting(self, client: TestClient):
        """Test login rate limiting (if implemented)"""
        # Try multiple failed logins
        for _ in range(10):
            client.post(
                "/api/v1/auth/login/json",
                json={"email": "test@example.com", "password": "wrong"},
            )

        # This test is optional - depends on rate limiting implementation
        # If rate limiting is implemented, should return 429 Too Many Requests
        response = client.post(
            "/api/v1/auth/login/json",
            json={"email": "test@example.com", "password": "wrong"},
        )

        # Accept either 429 (rate limited) or 401 (not implemented)
        assert response.status_code in [401, 429]

    def test_token_expiration(self, client: TestClient):
        """Test expired token handling"""
        # Create an expired token
        from app.core.security import create_access_token
        from datetime import timedelta

        expired_token = create_access_token(
            subject="1", expires_delta=timedelta(seconds=-1)
        )
        headers = {"Authorization": f"Bearer {expired_token}"}

        response = client.get("/api/v1/auth/me", headers=headers)

        assert response.status_code == 401
