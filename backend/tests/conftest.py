"""
Pytest configuration and fixtures for backend tests
"""
import os
import pytest
from typing import Generator
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

from app.main import app
from app.db.session import get_db
from app.db.base import Base
from app.core.security import create_access_token
from app.models.user import User
from app.models import Company, JobPosition, InterviewProcess, Interview

# Test database configuration
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db() -> Generator[Session, None, None]:
    """
    Create a fresh database for each test.
    Uses in-memory SQLite for speed.
    """
    # Remove schema from all tables for SQLite compatibility
    # Also skip profile tables that use PostgreSQL-specific types (ARRAY)
    tables_to_create = []
    for table in Base.metadata.tables.values():
        table.schema = None
        # Skip tables with PostgreSQL-specific types (ARRAY, JSONB)
        skip_tables = [
            'user_profiles', 'data_export_requests', 'profile_audit_logs',  # ARRAY
            'achievements', 'user_achievements', 'user_stats', 'activity_logs', 'activity_log'  # JSONB
        ]
        if table.name not in skip_tables:
            tables_to_create.append(table)

    # Create tables (excluding profile tables with PostgreSQL ARRAY types)
    Base.metadata.create_all(bind=engine, tables=tables_to_create, checkfirst=True)

    # Create session
    session = TestingSessionLocal()

    try:
        yield session
    finally:
        session.close()
        # Drop all tables after test
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db: Session) -> Generator[TestClient, None, None]:
    """
    Create a test client with database dependency override.
    """
    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db: Session) -> User:
    """
    Create a test user in the database.
    """
    from app.core.security import get_password_hash

    user = User(
        email="test@example.com",
        hashed_password=get_password_hash("testpassword"),
        is_active=True,
        is_airflow_admin=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def admin_user(db: Session) -> User:
    """
    Create an admin user with Airflow access.
    """
    from app.core.security import get_password_hash

    user = User(
        email="admin@example.com",
        hashed_password=get_password_hash("adminpassword"),
        is_active=True,
        is_airflow_admin=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_token(test_user: User) -> str:
    """
    Generate a valid JWT token for the test user.
    """
    return create_access_token(subject=str(test_user.id))


@pytest.fixture
def admin_token(admin_user: User) -> str:
    """
    Generate a valid JWT token for the admin user.
    """
    return create_access_token(subject=str(admin_user.id))


@pytest.fixture
def auth_headers(auth_token: str) -> dict:
    """
    Headers with authentication token.
    """
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture
def admin_headers(admin_token: str) -> dict:
    """
    Headers with admin authentication token.
    """
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def test_company(db: Session) -> Company:
    """
    Create a test company.
    """
    company = Company(
        name="Test Company",
        industry="Technology",
        size="50-200",
        location="Paris, France",
        website="https://testcompany.com",
    )
    db.add(company)
    db.commit()
    db.refresh(company)
    return company


@pytest.fixture
def test_position(db: Session, test_company: Company) -> JobPosition:
    """
    Create a test job position.
    """
    position = JobPosition(
        company_id=test_company.id,
        title="Senior Software Engineer",
        department="Engineering",
        level="senior",
        employment_type="full_time",
        remote_policy="hybrid",
        salary_min=60000,
        salary_max=80000,
        currency="USD",
    )
    db.add(position)
    db.commit()
    db.refresh(position)
    return position


@pytest.fixture
def test_process(db: Session, test_position: JobPosition) -> InterviewProcess:
    """
    Create a test interview process.
    """
    from datetime import date

    process = InterviewProcess(
        job_position_id=test_position.id,
        application_date=date.today(),
        status="applied",
        source="LinkedIn",
    )
    db.add(process)
    db.commit()
    db.refresh(process)
    return process


@pytest.fixture
def test_interview(db: Session, test_process: InterviewProcess) -> Interview:
    """
    Create a test interview.
    """
    from datetime import date

    interview = Interview(
        process_id=test_process.id,
        interview_type="phone_screening",
        scheduled_date=date.today(),
        status="scheduled",
    )
    db.add(interview)
    db.commit()
    db.refresh(interview)
    return interview


@pytest.fixture(autouse=True)
def reset_env():
    """
    Reset environment variables before each test.
    """
    os.environ["TESTING"] = "1"
    yield
    os.environ.pop("TESTING", None)
