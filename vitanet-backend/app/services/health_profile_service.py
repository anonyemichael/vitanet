# app/services/health_profile_service.py
from uuid import UUID
from sqlalchemy.orm import Session
from app.models.health_profile import HealthProfile, Allergy
from app.schemas.health_profile import HealthProfileUpdate, AllergyCreate


def get_or_create_profile(db: Session, user_id: UUID) -> HealthProfile:
    profile = db.query(HealthProfile).filter(HealthProfile.user_id == user_id).first()
    if not profile:
        profile = HealthProfile(user_id=user_id)
        db.add(profile)
        db.commit()
        db.refresh(profile)
    return profile


def update_profile(db: Session, user_id: UUID, payload: HealthProfileUpdate) -> HealthProfile:
    profile = get_or_create_profile(db, user_id)
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(profile, field, value)
    db.commit()
    db.refresh(profile)
    return profile


def add_allergy(db: Session, user_id: UUID, payload: AllergyCreate) -> Allergy:
    allergy = Allergy(user_id=user_id, allergen=payload.allergen)
    db.add(allergy)
    db.commit()
    db.refresh(allergy)
    return allergy


def get_allergies(db: Session, user_id: UUID) -> list[Allergy]:
    return db.query(Allergy).filter(Allergy.user_id == user_id).all()