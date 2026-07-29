# app/scripts/test_alert_trigger.py
"""
Directly test the alert-checking logic with an extreme value, bypassing the simulator.
Run: python -m app.scripts.test_alert_trigger <user_id>
"""
import argparse
from uuid import UUID

from app.database.connection import SessionLocal
from app.services import health_alert_service


def test(user_id: UUID):
    db = SessionLocal()
    try:
        print("Testing with an extreme heart rate value (150 bpm)...")
        alert = health_alert_service.check_vital_for_alert(db, user_id, "heart_rate", 150.0)
        if alert:
            print(f"ALERT CREATED: severity={alert.severity}, message={alert.message}")
        else:
            print("No alert created — check_vital_for_alert returned None")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("user_id", type=UUID)
    args = parser.parse_args()
    test(args.user_id)