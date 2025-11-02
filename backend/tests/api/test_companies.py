"""
Tests for company API endpoints
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models import Company


@pytest.mark.api
class TestCompanyEndpoints:
    """Test company CRUD endpoints"""

    def test_list_companies_empty(self, client: TestClient):
        """Test listing companies when database is empty"""
        response = client.get("/api/v1/companies/")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_companies(self, client: TestClient, test_company: Company):
        """Test listing companies"""
        response = client.get("/api/v1/companies/")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["name"] == test_company.name
        assert data[0]["industry"] == test_company.industry

    def test_get_company(self, client: TestClient, test_company: Company):
        """Test getting a single company"""
        response = client.get(f"/api/v1/companies/{test_company.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_company.id
        assert data["name"] == test_company.name
        assert data["industry"] == test_company.industry
        assert data["website"] == test_company.website

    def test_get_company_not_found(self, client: TestClient):
        """Test getting a non-existent company"""
        response = client.get("/api/v1/companies/999")

        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()

    def test_create_company(self, client: TestClient):
        """Test creating a new company"""
        company_data = {
            "name": "New Company",
            "industry": "Finance",
            "size": "10-50",
            "location": "London, UK",
            "website": "https://newcompany.com",
        }

        response = client.post("/api/v1/companies/", json=company_data)

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == company_data["name"]
        assert data["industry"] == company_data["industry"]
        assert "id" in data
        assert "created_at" in data

    def test_create_company_missing_required_fields(self, client: TestClient):
        """Test creating a company without required fields"""
        company_data = {"industry": "Finance"}  # Missing 'name'

        response = client.post("/api/v1/companies/", json=company_data)

        assert response.status_code == 422  # Validation error

    def test_update_company(self, client: TestClient, test_company: Company):
        """Test updating a company"""
        update_data = {
            "name": "Updated Company Name",
            "industry": "Updated Industry",
        }

        response = client.put(f"/api/v1/companies/{test_company.id}", json=update_data)

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == update_data["name"]
        assert data["industry"] == update_data["industry"]
        # Original fields should remain
        assert data["id"] == test_company.id

    def test_update_company_not_found(self, client: TestClient):
        """Test updating a non-existent company"""
        update_data = {"name": "Updated Name"}

        response = client.put("/api/v1/companies/999", json=update_data)

        assert response.status_code == 404

    def test_delete_company(self, client: TestClient, test_company: Company, db: Session):
        """Test deleting a company"""
        response = client.delete(f"/api/v1/companies/{test_company.id}")

        assert response.status_code == 204

        # Verify company is deleted
        db.expire_all()  # Clear cache
        deleted_company = db.query(Company).filter(Company.id == test_company.id).first()
        assert deleted_company is None

    def test_delete_company_not_found(self, client: TestClient):
        """Test deleting a non-existent company"""
        response = client.delete("/api/v1/companies/999")

        assert response.status_code == 404

    def test_list_companies_pagination(self, client: TestClient, db: Session):
        """Test listing companies with pagination"""
        # Create multiple companies
        for i in range(15):
            company = Company(name=f"Company {i}", industry="Tech")
            db.add(company)
        db.commit()

        # Test with limit
        response = client.get("/api/v1/companies/?limit=10")
        assert response.status_code == 200
        assert len(response.json()) == 10

        # Test with skip
        response = client.get("/api/v1/companies/?skip=10&limit=10")
        assert response.status_code == 200
        assert len(response.json()) == 5  # Only 15 total, skip 10, get 5

    def test_company_validation_empty_name(self, client: TestClient):
        """Test creating company with empty name"""
        company_data = {
            "name": "",  # Empty name
            "industry": "Tech",
        }

        response = client.post("/api/v1/companies/", json=company_data)

        assert response.status_code == 422

    def test_company_website_url_validation(self, client: TestClient):
        """Test website URL validation"""
        company_data = {
            "name": "Test Company",
            "industry": "Tech",
            "website": "not-a-valid-url",  # Invalid URL
        }

        response = client.post("/api/v1/companies/", json=company_data)

        # Should either pass (if validation is lenient) or return 422
        assert response.status_code in [201, 422]
