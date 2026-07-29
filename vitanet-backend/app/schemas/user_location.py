# app/schemas/user_location.py
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class UserLocationUpdate(BaseModel):
    latitude: float
    longitude: float


class UserLocationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: UUID
    latitude: float
    longitude: float
    updated_at: datetime