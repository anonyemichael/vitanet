# app/schemas/health_profile.py
from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.models.health_profile import ExerciseFrequency


class HealthProfileUpdate(BaseModel):
    smoking: Optional[bool] = None
    alcohol: Optional[bool] = None
    exercise_frequency: Optional[ExerciseFrequency] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    bio: Optional[str] = None


class HealthProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: UUID
    smoking: bool
    alcohol: bool
    exercise_frequency: ExerciseFrequency
    height_cm: Optional[float]
    weight_kg: Optional[float]
    bio: Optional[str]
    updated_at: datetime


class AllergyCreate(BaseModel):
    allergen: str


class AllergyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    allergen: str
    created_at: datetime