# app/services/hospital_service.py
from math import radians, sin, cos, sqrt, atan2
from sqlalchemy.orm import Session
from app.models.hospital import Hospital


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371  # Earth radius in km
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))


def get_nearby_hospitals(db: Session, user_lat: float, user_lon: float, limit: int = 5) -> list[dict]:
    hospitals = db.query(Hospital).all()

    ranked = [
        {
            "id": str(h.id),  # convert UUID to string for JSON serialization
            "name": h.name,
            "address": h.address,
            "phone_number": h.phone_number,
            "has_ambulance": h.has_ambulance,
            "ambulance_available": h.ambulance_available,
            "has_emergency_room": h.has_emergency_room,
            "distance_km": round(haversine_km(user_lat, user_lon, h.latitude, h.longitude), 2),
        }
        for h in hospitals
    ]

    ranked.sort(key=lambda x: x["distance_km"])
    return ranked[:limit]
