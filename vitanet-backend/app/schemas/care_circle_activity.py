from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.care_circle_activity import ActivityType


class CareCircleActivityOut(BaseModel):
    id: UUID
    user_id: UUID
    care_circle_id: UUID
    activity_type: ActivityType
    title: str
    message: str
    is_read: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)