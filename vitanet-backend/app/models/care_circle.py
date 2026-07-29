from datetime import datetime
from enum import Enum
from uuid import uuid4

from sqlalchemy import Column, String, DateTime, ForeignKey, Boolean, Enum as SqlEnum
from sqlalchemy.dialects.postgresql import UUID

from app.database.base import Base


class CareCircleStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class Relationship(str, Enum):
    FAMILY = "family"
    FRIEND = "friend"
    PARTNER = "partner"
    DOCTOR = "doctor"
    OTHER = "other"


class CareCircle(Base):
    __tablename__ = "care_circles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)

    requester_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    full_name = Column(String, nullable=False)
    contact_email = Column(String, nullable=True)
    contact_phone = Column(String, nullable=True)

    relationship = Column(SqlEnum(Relationship), nullable=False)
    is_primary = Column(Boolean, nullable=False, default=False)

    status = Column(SqlEnum(CareCircleStatus), nullable=False, default=CareCircleStatus.PENDING)

    invite_token = Column(String, nullable=False, unique=True, default=lambda: str(uuid4()))

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)