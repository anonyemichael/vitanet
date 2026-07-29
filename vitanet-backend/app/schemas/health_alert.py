# app/schemas/health_alert.py
from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.models.health_alert import AlertSeverity, AlertStatus


class HealthAlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    vital_type: str
    severity: AlertSeverity
    status: AlertStatus
    message: str
    latest_value: Optional[str]
    baseline_avg: Optional[str]
    created_at: datetime
    acknowledged_at: Optional[datetime]
    escalated_at: Optional[datetime]