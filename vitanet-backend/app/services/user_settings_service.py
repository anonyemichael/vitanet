# app/services/user_settings_service.py
from uuid import UUID
from sqlalchemy.orm import Session
from app.models.user_settings import UserSettings
from app.schemas.user_settings import UserSettingsUpdate


def get_or_create_settings(db: Session, user_id: UUID) -> UserSettings:
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        settings = UserSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


def update_settings(db: Session, user_id: UUID, payload: UserSettingsUpdate) -> UserSettings:
    settings = get_or_create_settings(db, user_id)
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(settings, field, value)
    db.commit()
    db.refresh(settings)
    return settings