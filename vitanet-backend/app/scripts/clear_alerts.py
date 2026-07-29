# app/scripts/clear_alerts.py
"""Clear all health alerts for a user, for clean testing."""
import argparse
from uuid import UUID

from app.database.connection import SessionLocal
from app.models.health_alert import HealthAlert


def clear_alerts(user_id: UUID):
    db = SessionLocal()
    try:
        deleted = db.query(HealthAlert).filter(HealthAlert.user_id == user_id).delete()
        db.commit()
        print(f"Deleted {deleted} alerts for user {user_id}")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("user_id", type=UUID)
    args = parser.parse_args()
    clear_alerts(args.user_id)