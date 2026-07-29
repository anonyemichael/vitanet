# app/schemas/emergency_contact.py
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from app.schemas.validators import normalize_phone_number


class EmergencyContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    phone_number: str

    @field_validator("phone_number")
    @classmethod
    def normalize_phone(cls, v):
        normalized = normalize_phone_number(v)
        if not normalized:
            raise ValueError("Phone number is required")
        return normalized


class EmergencyContactResponse(BaseModel):
    id: int
    user_id: int
    name: str
    phone_number: str
    created_at: datetime

    class Config:
        from_attributes = True