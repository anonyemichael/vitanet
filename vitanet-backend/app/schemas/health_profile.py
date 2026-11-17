# app/schemas/health_profile.py
from uuid import UUID
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
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


class AllergyReplace(BaseModel):
    allergies: list[str]


class AllergyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    allergen: str
    created_at: datetime


class AppContact(BaseModel):
    name: str = Field(max_length=150)
    phone: Optional[str] = Field(default=None, max_length=30)
    email: Optional[str] = Field(default=None, max_length=255)
    relation: Optional[str] = Field(default=None, max_length=40)


class AppProfileSync(BaseModel):
    """The app's profile screen, as one message (lib/data/models/user_profile.dart)."""
    name: Optional[str] = Field(default=None, max_length=150)
    age: Optional[int] = Field(default=None, ge=0, le=130)
    sex: Optional[str] = Field(default=None, max_length=32)
    dob: Optional[str] = Field(default=None, max_length=40)
    conditions: List[str] = Field(default_factory=list, max_length=50)
    allergies: List[str] = Field(default_factory=list, max_length=50)
    medications: List[str] = Field(default_factory=list, max_length=50)
    family_history: List[str] = Field(default_factory=list, max_length=50)
    blood_type: Optional[str] = Field(default=None, max_length=8)
    height_cm: Optional[float] = Field(default=None, gt=0, lt=300)
    weight_kg: Optional[float] = Field(default=None, gt=0, lt=500)
    smoking: Optional[bool] = None
    alcohol: Optional[bool] = None
    exercise_frequency: Optional[str] = Field(default=None, max_length=20)   # "Never" | "Sometimes" | "Mostly"
    bio: Optional[str] = Field(default=None, max_length=2000)
    contacts: Optional[List[AppContact]] = Field(default=None, max_length=20)   # None = leave the care circle as is
    contacts_replace: bool = False   # True: contacts missing from the list are removed (the person edited the list)
