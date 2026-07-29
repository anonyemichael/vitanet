# app/routers/user_settings.py
from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.user_settings import UserSettingsOut, UserSettingsUpdate
from app.services import user_settings_service

router = APIRouter(prefix="/users", tags=["user-settings"])


@router.get("/{user_id}/settings", response_model=UserSettingsOut)
def get_settings(user_id: UUID, db: Session = Depends(get_db)):
    return user_settings_service.get_or_create_settings(db, user_id)


@router.put("/{user_id}/settings", response_model=UserSettingsOut)
def update_settings(user_id: UUID, payload: UserSettingsUpdate, db: Session = Depends(get_db)):
    return user_settings_service.update_settings(db, user_id, payload)