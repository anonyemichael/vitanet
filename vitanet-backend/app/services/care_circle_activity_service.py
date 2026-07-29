from uuid import UUID
from typing import List

from sqlalchemy.orm import Session

from app.models.care_circle_activity import CareCircleActivity, ActivityType


def create_activity(
    db: Session,
    user_id: UUID,
    care_circle_id: UUID,
    activity_type: ActivityType,
    title: str,
    message: str,
) -> CareCircleActivity:
    activity = CareCircleActivity(
        user_id=user_id,
        care_circle_id=care_circle_id,
        activity_type=activity_type,
        title=title,
        message=message,
    )
    db.add(activity)
    db.flush()
    return activity


def get_activity_for_user(db: Session, user_id: UUID, limit: int = 20) -> List[CareCircleActivity]:
    return (
        db.query(CareCircleActivity)
        .filter(CareCircleActivity.user_id == user_id)
        .order_by(CareCircleActivity.created_at.desc())
        .limit(limit)
        .all()
    )


def mark_activity_read(db: Session, activity_id: UUID) -> CareCircleActivity | None:
    activity = db.query(CareCircleActivity).filter(CareCircleActivity.id == activity_id).first()
    if not activity:
        return None
    activity.is_read = True
    db.commit()
    db.refresh(activity)
    return activity