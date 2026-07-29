# app/scripts/check_bp_pairing.py
"""
Quick check: confirms get_blood_pressure_series pairs systolic/diastolic correctly.
Run: python -m app.scripts.check_bp_pairing <user_id>
"""
import argparse
from uuid import UUID

from app.database.connection import SessionLocal
from app.services.vitals_service import get_blood_pressure_series, get_trend
from app.models.vitals import VitalType


def check(user_id: UUID):
    db = SessionLocal()
    try:
        systolic_count = len(get_trend(db, user_id, VitalType.BP_SYSTOLIC, days=7))
        diastolic_count = len(get_trend(db, user_id, VitalType.BP_DIASTOLIC, days=7))
        paired = get_blood_pressure_series(db, user_id, days=7)

        print(f"Systolic readings:  {systolic_count}")
        print(f"Diastolic readings: {diastolic_count}")
        print(f"Paired BP entries:  {len(paired)}")
        print()
        for p in paired[:5]:
            print(f"  {p.recorded_at} — {p.systolic}/{p.diastolic}")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("user_id", type=UUID)
    args = parser.parse_args()
    check(args.user_id)