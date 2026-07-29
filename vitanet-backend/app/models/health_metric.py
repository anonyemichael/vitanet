# app/models/health_metric.py
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.sql import func

from app.database.base import Base
from app.enums import MetricType


class HealthMetric(Base):
    __tablename__ = "health_metrics"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_id = Column(Integer, ForeignKey("connected_devices.id"), nullable=True, index=True)

    metric_type = Column(SQLEnum(MetricType, name="metric_type_enum"), nullable=False, index=True)
    value = Column(Float, nullable=False)
    unit = Column(String(20), nullable=False)

    recorded_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)