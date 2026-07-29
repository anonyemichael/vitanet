# app/schemas/user_settings.py
from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.enums import Language


class UserSettingsUpdate(BaseModel):
    language: Optional[Language] = None
    timezone: Optional[str] = None


class UserSettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: UUID
    language: Language
    timezone: str
    updated_at: datetime