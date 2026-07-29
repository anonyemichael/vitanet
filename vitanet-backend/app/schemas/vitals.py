# app/schemas/vitals.py
from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.models.vitals import VitalType


class VitalReadingCreate(BaseModel):
    vital_type: VitalType
    value: float
    source: Optional[str] = "manual"
    recorded_at: Optional[datetime] = None


class VitalReadingBatchCreate(BaseModel):
    readings: list[VitalReadingCreate]


class VitalReadingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    vital_type: VitalType
    value: float
    recorded_at: datetime
    source: str


class VitalTrendPoint(BaseModel):
    recorded_at: datetime
    value: float


class VitalTrendOut(BaseModel):
    vital_type: VitalType
    points: list[VitalTrendPoint]
    latest_value: Optional[float] = None
    average_value: Optional[float] = None


class BloodPressureOut(BaseModel):
    """Combined view for display — pairs systolic + diastolic at matching timestamps."""
    recorded_at: datetime
    systolic: float
    diastolic: float

class UserVitalSettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: UUID
    enabled_vitals: list[VitalType]


class UserVitalSettingsUpdate(BaseModel):
    enabled_vitals: list[VitalType]
