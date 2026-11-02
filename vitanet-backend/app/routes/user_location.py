from typing import Annotated
# app/routers/user_location.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.dependencies.security import CurrentUser, get_current_user, owned_user_id
from app.schemas.user_location import UserLocationUpdate, UserLocationOut
from app.services import user_location_service

router = APIRouter(prefix="/users", tags=["user-location"])


@router.put("/{user_id}/location", response_model=UserLocationOut)
def update_location(user_id: Annotated[UUID, Depends(owned_user_id)], payload: UserLocationUpdate, db: Session = Depends(get_db)):
    return user_location_service.upsert_location(db, user_id, payload)


@router.get("/{user_id}/location", response_model=UserLocationOut)
def get_location(user_id: Annotated[UUID, Depends(owned_user_id)], db: Session = Depends(get_db)):
    location = user_location_service.get_location(db, user_id)
    if not location:
        raise HTTPException(status_code=404, detail="No location on file for this user")
    return location