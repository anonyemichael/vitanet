# app/models/emergency_contact.py
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.sql import func

from app.database.base import Base


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    name = Column(String(150), nullable=False)
    phone_number = Column(String(20), nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)