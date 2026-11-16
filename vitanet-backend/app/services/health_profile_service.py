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


def replace_allergies(db: Session, user_id: UUID, allergens: list[str]) -> list[Allergy]:
    """Replace the user's allergy list as one transaction when a profile is saved."""
    db.query(Allergy).filter(Allergy.user_id == user_id).delete()
    unique_allergens = list(dict.fromkeys(item.strip() for item in allergens if item.strip()))
    records = [Allergy(user_id=user_id, allergen=allergen) for allergen in unique_allergens]
    db.add_all(records)
    db.commit()
    for record in records:
        db.refresh(record)
    return records


def _parse_dob(raw):
    from datetime import datetime
    raw = (raw or "").strip()
    for parse in (lambda s: datetime.fromisoformat(s), lambda s: datetime.strptime(s, "%B %d, %Y"),
                  lambda s: datetime.strptime(s, "%d/%m/%Y")):
        try:
            return parse(raw).date()
        except ValueError:
            continue
    return None


def _clean(items):
    return list(dict.fromkeys(i.strip() for i in items if i and i.strip()))


def sync_from_app(db: Session, user_id: UUID, p) -> HealthProfile:
    """Store the app's profile screen (AppProfileSync) so the assistant's tools and the hospital see it.
    Only what the person filled in is stored; nothing is guessed."""
    from app.models.health_profile import ExerciseFrequency
    from app.models.user import User

    profile = get_or_create_profile(db, user_id)
    profile.conditions = _clean(p.conditions)
    profile.medications = _clean(p.medications)
    profile.family_history = _clean(p.family_history)
    profile.blood_type = (p.blood_type or "").strip() or None
    profile.age_years = p.age
    profile.height_cm, profile.weight_kg = p.height_cm, p.weight_kg
    if p.bio is not None:
        profile.bio = p.bio.strip() or None
    if p.smoking is not None:
        profile.smoking = p.smoking
    if p.alcohol is not None:
        profile.alcohol = p.alcohol
    if p.exercise_frequency and p.exercise_frequency.lower() in {e.value for e in ExerciseFrequency}:
        profile.exercise_frequency = ExerciseFrequency(p.exercise_frequency.lower())

    user = db.get(User, user_id)
    if user is not None:
        if p.name and p.name.strip():
            user.full_name = p.name.strip()
        if p.sex:
            user.biological_sex = p.sex.strip().lower()
        dob = _parse_dob(p.dob)
        if dob:
            user.date_of_birth = dob
    db.commit()
    replace_allergies(db, user_id, p.allergies)
    db.refresh(profile)
    return profile
