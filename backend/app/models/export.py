from sqlalchemy import Column, Integer, String, Date, Text, ForeignKey, DateTime, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.db.base import Base


class ExportStatus(str, enum.Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class ExportFormat(str, enum.Enum):
    EXCEL = "excel"
    CSV = "csv"


class Export(Base):
    __tablename__ = "exports"
    __table_args__ = {"schema": "hirewire"}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("hirewire.users.id", ondelete="CASCADE"), nullable=False)

    # Export parameters
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    format = Column(String(10), nullable=False)
    recipient_email = Column(String(255), nullable=False)

    # Tracking
    status = Column(String(20), nullable=False, default="pending")
    airflow_dag_run_id = Column(String(255))
    file_path = Column(Text)
    error_message = Column(Text)

    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    completed_at = Column(DateTime)

    # Relationships
    user = relationship("User", back_populates="exports")
