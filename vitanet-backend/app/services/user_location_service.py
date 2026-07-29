# app/services/user_location_service.py
from uuid import UUID
from sqlalchemy.orm import Session
from app.models.user_location import UserLocation
from app.schemas.user_location import UserLocationUpdate


def upsert_location(db: Session, user_id: UUID, payload: UserLocationUpdate) -> UserLocation:
    location = db.query(UserLocation).filter(UserLocation.user_id == user_id).first()
    if location:
        location.latitude = payload.latitude
        location.longitude = payload.longitude
    else:
        location = UserLocation(user_id=user_id, latitude=payload.latitude, longitude=payload.longitude)
        db.add(location)
    db.commit()
    db.refresh(location)
    return location


def get_location(db: Session, user_id: UUID) -> UserLocation | None:
    return db.query(UserLocation).filter(UserLocation.user_id == user_id).first()