from typing import Annotated
# app/routes/vitals.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.connection import get_db
from app.dependencies.security import CurrentUser, get_current_user, owned_user_id
from app.models.vitals import VitalType
from app.schemas.vitals import VitalReadingCreate, VitalReadingBatchCreate, VitalReadingOut, VitalTrendOut, VitalTrendPoint, UserVitalSettingsOut, UserVitalSettingsUpdate

from app.services import vitals_service, health_alert_service


router = APIRouter(prefix="/vitals", tags=["vitals"])

DEMO_USER_ID = UUID("00000000-0000-0000-0000-000000000001")


def _resolve_user_id(db: Session, identifier) -> UUID:
    # Ownership is already enforced by the owned_user_id dependency, which
    # resolves the path to the caller's own backend user id.
    return identifier if isinstance(identifier, UUID) else UUID(str(identifier))


@router.post("/{user_id}", response_model=VitalReadingOut)
def ingest_reading(user_id: Annotated[UUID, Depends(owned_user_id)], payload: VitalReadingCreate, db: Session = Depends(get_db)):
    uid = _resolve_user_id(db, user_id)
    reading = vitals_service.create_reading(db, uid, payload)
    health_alert_service.check_vital_for_alert(db, uid, reading.vital_type.value, reading.value, reading_id=reading.id)
    return reading


@router.post("/{user_id}/batch", response_model=list[VitalReadingOut])
def ingest_batch(user_id: Annotated[UUID, Depends(owned_user_id)],
    payload: VitalReadingBatchCreate,
    db: Session = Depends(get_db),
):
    """Stores the new readings and makes any health alert they call for. Telling the care circle about an urgent
    alert nobody answers is done by the alert sweeper (app/main.py), not here."""
    readings = vitals_service.create_readings_batch(db, user_id, payload)
    for reading in readings:
        health_alert_service.check_vital_for_alert(db, user_id, reading.vital_type.value, reading.value,
                                                   reading_id=reading.id)
    return readings


@router.get("/{user_id}/latest")
def get_latest_all(user_id: Annotated[UUID, Depends(owned_user_id)], db: Session = Depends(get_db)):
    uid = _resolve_user_id(db, user_id)
    latest = vitals_service.get_all_latest(db, uid)
    return {
        vt.value: (VitalReadingOut.model_validate(reading) if reading else None)
        for vt, reading in latest.items()
    }


@router.get("/{user_id}/trend/{vital_type}", response_model=VitalTrendOut)
def get_trend(user_id: Annotated[UUID, Depends(owned_user_id)], vital_type: VitalType, days: int = 7, db: Session = Depends(get_db)):
    uid = _resolve_user_id(db, user_id)
    readings = vitals_service.get_trend(db, uid, vital_type, days)
    if not readings:
        raise HTTPException(status_code=404, detail="No readings found for this vital type")
    points = [VitalTrendPoint(recorded_at=r.recorded_at, value=r.value) for r in readings]
    values = [r.value for r in readings]
    return VitalTrendOut(
        vital_type=vital_type,
        points=points,
        latest_value=values[-1],
        average_value=round(sum(values) / len(values), 2),
    )


@router.get("/{user_id}/settings", response_model=UserVitalSettingsOut)
def get_settings(user_id: Annotated[UUID, Depends(owned_user_id)], db: Session = Depends(get_db)):
    enabled = vitals_service.get_enabled_vitals(db, user_id)
    return UserVitalSettingsOut(user_id=user_id, enabled_vitals=enabled)


@router.put("/{user_id}/settings", response_model=UserVitalSettingsOut)
def update_settings(user_id: Annotated[UUID, Depends(owned_user_id)], payload: UserVitalSettingsUpdate, db: Session = Depends(get_db)):
    settings = vitals_service.set_enabled_vitals(db, user_id, payload)
    return UserVitalSettingsOut(user_id=settings.user_id, enabled_vitals=settings.enabled_vitals)