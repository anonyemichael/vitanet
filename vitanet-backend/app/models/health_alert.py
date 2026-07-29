# app/models/health_alert.py
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Enum as SqlEnum, Boolean
from sqlalchemy.dialects.postgresql import UUID
from app.database.base import Base


class AlertSeverity(str, enum.Enum):
    WATCH = "watch"
    URGENT = "urgent"


class AlertStatus(str, enum.Enum):
    PENDING = "pending"
    ACKNOWLEDGED = "acknowledged"
    ESCALATED = "escalated"


class HealthAlert(Base):
    __tablename__ = "health_alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    vital_type = Column(String, nullable=False)
    severity = Column(SqlEnum(AlertSeverity), nullable=False)
    status = Column(SqlEnum(AlertStatus), nullable=False, default=AlertStatus.PENDING)
    message = Column(Text, nullable=False)
    latest_value = Column(String, nullable=True)
    baseline_avg = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    acknowledged_at = Column(DateTime, nullable=True)
    escalated_at = Column(DateTime, nullable=True)