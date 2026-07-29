# app/services/vitals_service.py
from uuid import UUID
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from app.models.vitals import VitalReading, VitalType,UserVitalSettings
from app.schemas.vitals import VitalReadingCreate, VitalReadingBatchCreate, BloodPressureOut,UserVitalSettingsUpdate
# app/services/vitals_service.py — add these

ALL_VITAL_TYPES = [vt.value for vt in VitalType]




def create_reading(db: Session, user_id: UUID, payload: VitalReadingCreate) -> VitalReading:
    reading = VitalReading(
        user_id=user_id,
        vital_type=payload.vital_type,
        value=payload.value,
        source=payload.source or "manual",
        recorded_at=payload.recorded_at or datetime.utcnow(),
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)
    return reading


def create_readings_batch(db: Session, user_id: UUID, payload: VitalReadingBatchCreate) -> list[VitalReading]:
    """Creates all readings in the batch as a single transaction, sharing one timestamp
    so paired vitals (e.g. BP systolic/diastolic) always match exactly."""
    shared_ts = datetime.utcnow()

    readings = [
        VitalReading(
            user_id=user_id,
            vital_type=r.vital_type,
            value=r.value,
            source=r.source or "manual",
            recorded_at=r.recorded_at or shared_ts,
        )
        for r in payload.readings
    ]
    db.add_all(readings)
    db.commit()
    for reading in readings:
        db.refresh(reading)
    return readings


def get_latest_reading(db: Session, user_id: UUID, vital_type: VitalType) -> VitalReading | None:
    return (
        db.query(VitalReading)
        .filter(VitalReading.user_id == user_id, VitalReading.vital_type == vital_type)
        .order_by(VitalReading.recorded_at.desc())
        .first()
    )


def get_trend(db: Session, user_id: UUID, vital_type: VitalType, days: int = 7) -> list[VitalReading]:
    since = datetime.utcnow() - timedelta(days=days)
    return (
        db.query(VitalReading)
        .filter(
            VitalReading.user_id == user_id,
            VitalReading.vital_type == vital_type,
            VitalReading.recorded_at >= since,
        )
        .order_by(VitalReading.recorded_at.asc())
        .all()
    )


def get_all_latest(db: Session, user_id: UUID) -> dict[VitalType, VitalReading | None]:
    """Latest reading for each vital type — feeds the dashboard cards."""
    return {vt: get_latest_reading(db, user_id, vt) for vt in VitalType}


def get_blood_pressure_series(db: Session, user_id: UUID, days: int = 7, tolerance_seconds: int = 5) -> list[BloodPressureOut]:
    """Pairs systolic + diastolic readings by matching timestamp (within a small
    tolerance window, for robustness against tiny clock drift) for '118/76' display."""
    systolic = get_trend(db, user_id, VitalType.BP_SYSTOLIC, days)
    diastolic = get_trend(db, user_id, VitalType.BP_DIASTOLIC, days)

    paired = []
    used_diastolic_ids = set()

    for s in systolic:
        best_match = None
        best_diff = None
        for d in diastolic:
            if d.id in used_diastolic_ids:
                continue
            diff = abs((s.recorded_at - d.recorded_at).total_seconds())
            if diff <= tolerance_seconds and (best_diff is None or diff < best_diff):
                best_match = d
                best_diff = diff

        if best_match:
            used_diastolic_ids.add(best_match.id)
            paired.append(
                BloodPressureOut(
                    recorded_at=s.recorded_at,
                    systolic=s.value,
                    diastolic=best_match.value,
                )
            )

    return paired


def get_enabled_vitals(db: Session, user_id: UUID) -> list[str]:
    settings = db.query(UserVitalSettings).filter(UserVitalSettings.user_id == user_id).first()
    if not settings:
        return ALL_VITAL_TYPES  # default: everything enabled if never configured
    return settings.enabled_vitals


def set_enabled_vitals(db: Session, user_id: UUID, payload: UserVitalSettingsUpdate) -> UserVitalSettings:
    settings = db.query(UserVitalSettings).filter(UserVitalSettings.user_id == user_id).first()
    enabled = [v.value for v in payload.enabled_vitals]

    if settings:
        settings.enabled_vitals = enabled
    else:
        settings = UserVitalSettings(user_id=user_id, enabled_vitals=enabled)
        db.add(settings)

    db.commit()
    db.refresh(settings)
    return settings