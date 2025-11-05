"""
Company SQLAlchemy model.
Maps to hirewire.companies table.
"""

from sqlalchemy import Column, Integer, String, DateTime, func
from sqlalchemy.orm import relationship
from app.db.base import Base


class Company(Base):
    """Company model."""

    __tablename__ = "companies"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    industry = Column(String)
    size = Column(String)
    location = Column(String)
    website = Column(String)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    job_positions = relationship(
        "JobPosition", back_populates="company", cascade="all, delete-orphan"
    )
