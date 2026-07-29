# app/models/health_profile.py
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Enum as SqlEnum, Boolean, Float
from sqlalchemy.dialects.postgresql import UUID
from app.database.base import Base


class ExerciseFrequency(str, enum.Enum):
    NEVER = "never"
    SOMETIMES = "sometimes"
    MOSTLY = "mostly"


class HealthProfile(Base):
    __tablename__ = "health_profiles"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    smoking = Column(Boolean, nullable=False, default=False)
    alcohol = Column(Boolean, nullable=False, default=False)
    exercise_frequency = Column(SqlEnum(ExerciseFrequency), nullable=False, default=ExerciseFrequency.SOMETIMES)
    height_cm = Column(Float, nullable=True)
    weight_kg = Column(Float, nullable=True)
    bio = Column(Text, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Allergy(Base):
    __tablename__ = "allergies"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    allergen = Column(String, nullable=False)  # e.g. "Penicillin", "Peanuts"
    created_at = Column(DateTime, default=datetime.utcnow)