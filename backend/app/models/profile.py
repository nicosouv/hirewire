"""
User Profile Models
RGPD-compliant user profiles for AI personalization
"""

from datetime import datetime
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    TIMESTAMP,
    ForeignKey,
    ARRAY,
    Text,
    CheckConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class UserProfile(Base):
    """User professional profile for AI Interview Prep and personalization"""

    __tablename__ = "user_profiles"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("hirewire.users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # Professional info
    current_job_title = Column(String(255))
    target_job_title = Column(String(255))
    years_of_experience = Column(Integer)
    industries = Column(ARRAY(Text))

    # Skills & Education
    skills = Column(ARRAY(Text))
    education_level = Column(String(100))
    certifications = Column(ARRAY(Text))
    languages = Column(JSONB)  # [{"language": "English", "proficiency": "fluent"}, ...]

    # Work preferences
    work_authorization = Column(String(100))
    location_preferences = Column(JSONB)  # {"remote": true, "cities": ["SF", "NYC"]}

    # Salary (opt-in)
    salary_expectations_min = Column(Integer)
    salary_expectations_max = Column(Integer)
    current_salary = Column(Integer)

    # AI preferences
    preferred_interview_language = Column(String(50), default="English")
    ai_interview_prep_enabled = Column(Boolean, default=True)

    # Privacy settings
    profile_visibility = Column(String(50), default="private")
    data_processing_consent = Column(Boolean, default=False)
    data_processing_consent_date = Column(TIMESTAMP)

    # Resume
    resume_file_url = Column(Text)
    resume_uploaded_at = Column(TIMESTAMP)

    # Timestamps
    created_at = Column(TIMESTAMP, default=datetime.utcnow, nullable=False)
    updated_at = Column(
        TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    # Relationships
    user = relationship("User", back_populates="profile")

    # Constraints
    __table_args__ = (
        CheckConstraint(
            "years_of_experience >= 0 AND years_of_experience <= 50",
            name="check_years_experience",
        ),
        CheckConstraint("salary_expectations_min >= 0", name="check_salary_min"),
        CheckConstraint("salary_expectations_max >= 0", name="check_salary_max"),
        CheckConstraint("current_salary >= 0", name="check_current_salary"),
        CheckConstraint(
            "profile_visibility IN ('private', 'public')", name="check_visibility"
        ),
        {"schema": "hirewire"},
    )


class DataExportRequest(Base):
    """RGPD compliance: track data export and deletion requests"""

    __tablename__ = "data_export_requests"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("hirewire.users.id", ondelete="CASCADE"), nullable=False
    )
    request_type = Column(String(50), nullable=False)  # 'export' or 'delete'
    status = Column(
        String(50), default="pending", nullable=False
    )  # 'pending', 'completed', 'failed', 'cancelled'
    export_file_url = Column(Text)
    requested_at = Column(TIMESTAMP, default=datetime.utcnow, nullable=False)
    completed_at = Column(TIMESTAMP)

    # Relationships
    user = relationship("User", back_populates="data_export_requests")

    __table_args__ = (
        CheckConstraint(
            "request_type IN ('export', 'delete')", name="check_request_type"
        ),
        CheckConstraint(
            "status IN ('pending', 'completed', 'failed', 'cancelled')",
            name="check_status",
        ),
        {"schema": "hirewire"},
    )


class ProfileAuditLog(Base):
    """RGPD compliance: audit trail for sensitive profile changes"""

    __tablename__ = "profile_audit_log"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("hirewire.users.id", ondelete="CASCADE"), nullable=False
    )
    field_changed = Column(String(255), nullable=False)
    old_value = Column(Text)
    new_value = Column(Text)
    changed_at = Column(TIMESTAMP, default=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="profile_audit_logs")
