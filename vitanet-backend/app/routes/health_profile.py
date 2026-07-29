# app/routers/health_profile.py
from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.health_profile import (
    HealthProfileOut, HealthProfileUpdate, AllergyCreate, AllergyOut
)
from app.services import health_profile_service

router = APIRouter(prefix="/health-profile", tags=["health-profile"])


@router.get("/{user_id}", response_model=HealthProfileOut)
def get_profile(user_id: UUID, db: Session = Depends(get_db)):
    return health_profile_service.get_or_create_profile(db, user_id)


@router.put("/{user_id}", response_model=HealthProfileOut)
def update_profile(user_id: UUID, payload: HealthProfileUpdate, db: Session = Depends(get_db)):
    return health_profile_service.update_profile(db, user_id, payload)


@router.post("/{user_id}/allergies", response_model=AllergyOut)
def create_allergy(user_id: UUID, payload: AllergyCreate, db: Session = Depends(get_db)):
    return health_profile_service.add_allergy(db, user_id, payload)


@router.get("/{user_id}/allergies", response_model=list[AllergyOut])
def list_allergies(user_id: UUID, db: Session = Depends(get_db)):
    return health_profile_service.get_allergies(db, user_id)