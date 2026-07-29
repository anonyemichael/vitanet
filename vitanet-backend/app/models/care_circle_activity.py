from datetime import datetime
from enum import Enum
from uuid import uuid4

from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Enum as SqlEnum
from sqlalchemy.dialects.postgresql import UUID

from app.database.base import Base


class ActivityType(str, Enum):
    CONTACT_ADDED = "contact_added"     # fires when an invite is accepted
    CONTACT_REJECTED = "contact_rejected"  # fires when an invite is rejected
    URGENT_ALERT = "urgent_alert"       # tied into health alerts later
    CHECK_IN = "check_in"               # tied into daily check-ins later


class CareCircleActivity(Base):
    __tablename__ = "care_circle_activities"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)

    # Blaiz — the account owner who will SEE this on his dashboard
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # which care circle member (e.g. Mary) this activity is about
    care_circle_id = Column(UUID(as_uuid=True), ForeignKey("care_circles.id"), nullable=False)

    activity_type = Column(SqlEnum(ActivityType, name="activity_type_enum"), nullable=False)

    title = Column(String, nullable=False)
    message = Column(String, nullable=False)

    is_read = Column(Boolean, nullable=False, default=False)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    def __repr__(self):
        return f"<CareCircleActivity id={self.id} type={self.activity_type!r}>"