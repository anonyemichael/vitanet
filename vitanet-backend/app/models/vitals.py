# app/models/vitals.py
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Enum as SqlEnum
from sqlalchemy.dialects.postgresql import UUID
from app.database.base import Base

    # app/models/vitals.py — add this to the same file
from sqlalchemy import ARRAY



class VitalType(str, enum.Enum):
    HEART_RATE = "heart_rate"
    BP_SYSTOLIC = "bp_systolic"
    BP_DIASTOLIC = "bp_diastolic"
    TEMPERATURE = "temperature"
    BLOOD_OXYGEN = "blood_oxygen"

# python -m app.scripts.seed_vitals <your-test-user-uuid>

class VitalReading(Base):
    __tablename__ = "vital_readings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    vital_type = Column(SqlEnum(VitalType), nullable=False)
    value = Column(Float, nullable=False)
    recorded_at = Column(DateTime, default=datetime.utcnow, index=True)
    source = Column(String, default="simulated")  # simulated | device | manual

class UserVitalSettings(Base):
    __tablename__ = "user_vital_settings"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    enabled_vitals = Column(ARRAY(String), nullable=False, default=list)