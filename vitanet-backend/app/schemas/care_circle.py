from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models.care_circle import Relationship, CareCircleStatus


class CareCircleOut(BaseModel):
    id: UUID
    requester_id: UUID
    full_name: str
    contact_email: Optional[EmailStr] = None
    contact_phone: Optional[str] = None
    relationship: Relationship
    is_primary: bool
    status: CareCircleStatus
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CareCircleUpdate(BaseModel):
    full_name: Optional[str] = None
    contact_email: Optional[EmailStr] = None
    contact_phone: Optional[str] = None
    relationship: Optional[Relationship] = None
    is_primary: Optional[bool] = None