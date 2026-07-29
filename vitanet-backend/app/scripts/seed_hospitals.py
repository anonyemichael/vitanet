# app/scripts/seed_hospitals.py
"""Seed a handful of mock hospitals for the demo. Run: python -m app.scripts.seed_hospitals"""
from app.database.connection import SessionLocal
from app.models.hospital import Hospital

MOCK_HOSPITALS = [
    {"name": "Komfo Anokye Teaching Hospital", "address": "Bantama, Kumasi",
     "latitude": 6.6980, "longitude": -1.6244, "phone_number": "+233322022308",
     "has_ambulance": True, "ambulance_available": True, "has_emergency_room": True},
    {"name": "Kumasi South Hospital", "address": "Kumasi South, Kumasi",
     "latitude": 6.6720, "longitude": -1.6110, "phone_number": "+233322047777",
     "has_ambulance": True, "ambulance_available": False, "has_emergency_room": True},
    {"name": "Suntreso Government Hospital", "address": "Suntreso, Kumasi",
     "latitude": 6.6935, "longitude": -1.6402, "phone_number": "+233322044113",
     "has_ambulance": False, "ambulance_available": False, "has_emergency_room": True},
]


def seed():
    db = SessionLocal()
    try:
        for h in MOCK_HOSPITALS:
            db.add(Hospital(**h))
        db.commit()
        print(f"Seeded {len(MOCK_HOSPITALS)} hospitals")
    finally:
        db.close()


if __name__ == "__main__":
    seed()