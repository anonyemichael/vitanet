# app/scripts/seed_vitals.py
"""
Seeds historical vitals data for a user, useful for testing trend endpoints
without waiting for the live simulator to accumulate days of data.

Run: python -m app.scripts.seed_vitals <user_id> [--days 7] [--readings-per-day 4]
"""
import sys
import random
import argparse
from uuid import UUID
from datetime import datetime, timedelta

from app.database.connection import SessionLocal
from app.models.vitals import VitalReading, VitalType


def generate_reading(vital_type: VitalType, recorded_at: datetime) -> dict:
    """Generate one realistic value for the given vital type."""
    ranges = {
        VitalType.HEART_RATE: (65, 80),
        VitalType.BP_SYSTOLIC: (112, 124),
        VitalType.BP_DIASTOLIC: (72, 80),
        VitalType.TEMPERATURE: (36.4, 37.0),
        VitalType.BLOOD_OXYGEN: (96, 99),
    }
    low, high = ranges[vital_type]
    return {
        "vital_type": vital_type,
        "value": round(random.uniform(low, high), 1),
        "recorded_at": recorded_at,
        "source": "seed_script",
    }


def seed(user_id: UUID, days: int, readings_per_day: int):
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        readings = []
        for day_offset in range(days, 0, -1):
            day = now - timedelta(days=day_offset)
            for tick in range(readings_per_day):
                # spread readings evenly across the day
                hour_offset = (24 / readings_per_day) * tick
                recorded_at = day.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(hours=hour_offset)
                for vt in VitalType:
                    data = generate_reading(vt, recorded_at)
                    readings.append(
                        VitalReading(
                            user_id=user_id,
                            vital_type=data["vital_type"],
                            value=data["value"],
                            recorded_at=data["recorded_at"],
                            source=data["source"],
                        )
                    )

        db.add_all(readings)
        db.commit()
        print(f"Seeded {len(readings)} readings across {days} days for user {user_id}.")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("user_id", type=UUID)
    parser.add_argument("--days", type=int, default=7, help="How many days of history to seed")
    parser.add_argument("--readings-per-day", type=int, default=4, help="Readings per vital per day")
    args = parser.parse_args()
    seed(args.user_id, args.days, args.readings_per_day)