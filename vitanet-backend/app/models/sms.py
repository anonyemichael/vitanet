# app/models/sms.py
"""The SMS line's memory. Phone numbers are never stored: only a keyed hash of them (phone_key), so the conversation
can continue without keeping who sent it."""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, String, Text
from sqlalchemy import Uuid as UUID

from app.database.base import Base


class SmsMessage(Base):
    __tablename__ = "sms_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone_key = Column(String(64), nullable=False, index=True)
    role = Column(String(16), nullable=False)          # "user" | "assistant"
    text = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class SmsContact(Base):
    __tablename__ = "sms_contacts"

    phone_key = Column(String(64), primary_key=True)
    opted_out = Column(Boolean, nullable=False, default=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
