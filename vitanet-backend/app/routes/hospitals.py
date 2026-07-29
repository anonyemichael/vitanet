# app/routers/hospital.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.services import hospital_service, user_location_service

router = APIRouter(prefix="/hospitals", tags=["hospitals"])


@router.get("/nearby/{user_id}")
def nearby_hospitals(user_id: UUID, limit: int = 5, db: Session = Depends(get_db)):
    location = user_location_service.get_location(db, user_id)
    if not location:
        raise HTTPException(status_code=404, detail="No location on file for this user")
    return hospital_service.get_nearby_hospitals(db, location.latitude, location.longitude, limit)