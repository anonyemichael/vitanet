# app/routes/vitals.py
from uuid import UUID
import asyncio
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from app.database.connection import get_db
from app.models.vitals import VitalType
from app.schemas.vitals import VitalReadingCreate, VitalReadingBatchCreate, VitalReadingOut, VitalTrendOut, VitalTrendPoint, UserVitalSettingsOut, UserVitalSettingsUpdate

from app.services import vitals_service, health_alert_service


router = APIRouter(prefix="/vitals", tags=["vitals"])


@router.post("/{user_id}", response_model=VitalReadingOut)
def ingest_reading(user_id: UUID, payload: VitalReadingCreate, db: Session = Depends(get_db)):
    return vitals_service.create_reading(db, user_id, payload)


async def _delayed_escalation_check(alert_id: UUID):
    await asyncio.sleep(health_alert_service.ESCALATION_DELAY_SECONDS)
    from app.database.connection import SessionLocal
    db = SessionLocal()
    try:
        health_alert_service.escalate_if_unacknowledged(db, alert_id)
    finally:
        db.close()


@router.post("/{user_id}/batch", response_model=list[VitalReadingOut])
def ingest_batch(
    user_id: UUID,
    payload: VitalReadingBatchCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    readings = vitals_service.create_readings_batch(db, user_id, payload)

    for reading in readings:
        alert = health_alert_service.check_vital_for_alert(db, user_id, reading.vital_type.value, reading.value)
        if alert and alert.severity.value == "urgent":
            background_tasks.add_task(_delayed_escalation_check, alert.id)

    return readings


@router.get("/{user_id}/latest")
def get_latest_all(user_id: UUID, db: Session = Depends(get_db)):
    latest = vitals_service.get_all_latest(db, user_id)
    return {
        vt.value: (VitalReadingOut.model_validate(reading) if reading else None)
        for vt, reading in latest.items()
    }


@router.get("/{user_id}/trend/{vital_type}", response_model=VitalTrendOut)
def get_trend(user_id: UUID, vital_type: VitalType, days: int = 7, db: Session = Depends(get_db)):
    readings = vitals_service.get_trend(db, user_id, vital_type, days)
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
def get_settings(user_id: UUID, db: Session = Depends(get_db)):
    enabled = vitals_service.get_enabled_vitals(db, user_id)
    return UserVitalSettingsOut(user_id=user_id, enabled_vitals=enabled)


@router.put("/{user_id}/settings", response_model=UserVitalSettingsOut)
def update_settings(user_id: UUID, payload: UserVitalSettingsUpdate, db: Session = Depends(get_db)):
    settings = vitals_service.set_enabled_vitals(db, user_id, payload)
    return UserVitalSettingsOut(user_id=settings.user_id, enabled_vitals=settings.enabled_vitals)