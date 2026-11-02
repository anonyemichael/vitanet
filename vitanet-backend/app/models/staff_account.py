from enum import Enum

from sqlalchemy import Boolean, Column, String, DateTime, Enum as SQLEnum, ForeignKey
from sqlalchemy import Uuid as UUID
from sqlalchemy.sql import func

from app.database.base import Base


class StaffRole(str, Enum):
    DOCTOR = "doctor"
    NURSE = "nurse"
    ADMIN = "admin"


class StaffStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    SUSPENDED = "suspended"


class StaffAccount(Base):
    """Hospital portal access. The backend is the only source of truth for
    who is staff — the app cannot grant itself access."""

    __tablename__ = "staff_accounts"

    firebase_uid = Column(String(128), primary_key=True)
    email = Column(String(255), nullable=True, index=True)
    full_name = Column(String(150), nullable=False)
    role = Column(SQLEnum(StaffRole, name="staff_role_enum"), nullable=False)
    status = Column(
        SQLEnum(StaffStatus, name="staff_status_enum"),
        nullable=False,
        default=StaffStatus.PENDING,
    )
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=True, index=True)
    on_duty = Column(Boolean, nullable=False, default=False)
    facility = Column(String(200), nullable=True)
    department = Column(String(120), nullable=True)
    license_number = Column(String(80), nullable=True)
    reviewed_by = Column(String(128), nullable=True)
    review_note = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
