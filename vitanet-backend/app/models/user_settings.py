# app/models/user_settings.py
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from app.database.base import Base
from app.enums import Language


class UserSettings(Base):
    __tablename__ = "user_settings"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    language = Column(SQLEnum(Language, name="language_enum"), nullable=False, default=Language.ENGLISH)
    timezone = Column(String, nullable=False, default="Africa/Accra")
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)