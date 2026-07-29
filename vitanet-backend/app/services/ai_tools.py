# app/services/ai_tools.py
from uuid import UUID
from sqlalchemy.orm import Session

from app.services import vitals_service, health_profile_service, care_circle_service, hospital_service, user_location_service
from app.models.vitals import VitalType

TOOL_DEFINITIONS = [
    {
        "name": "get_health_metrics",
        "description": "Get the user's latest vitals (heart rate, blood pressure, temperature, blood oxygen) and recent trend.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "name": "get_nearby_hospitals",
        "description": "Get hospitals near the user's current location, ranked by distance, including ambulance availability.",
        "parameters": {"type": "object", "properties": {}},
    },
]



def execute_tool(name: str, args: dict, db: Session, user_id: UUID):
    if name == "get_health_metrics":
        latest = vitals_service.get_all_latest(db, user_id)
        result = {}
        for vt, reading in latest.items():
            if reading is None:
                continue
            trend = vitals_service.get_trend(db, user_id, vt, days=7)
            values = [r.value for r in trend]
            result[vt.value] = {
                "latest_value": reading.value,
                "recorded_at": reading.recorded_at.isoformat(),
                "min": min(values) if values else None,
                "max": max(values) if values else None,
                "avg": round(sum(values) / len(values), 1) if values else None,
            }
        return result

    elif name == "get_health_profile":
        profile = health_profile_service.get_or_create_profile(db, user_id)
        allergies = health_profile_service.get_allergies(db, user_id)
        return {
            "smoking": profile.smoking,
            "alcohol": profile.alcohol,
            "exercise_frequency": profile.exercise_frequency.value,
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "bio": profile.bio,
            "allergies": [a.allergen for a in allergies],
        }

    elif name == "get_care_circle":
        contacts = care_circle_service.get_care_circle_for_user(db, user_id)
        return [
            {"full_name": c.full_name, "relationship": c.relationship, "status": c.status.value}
            for c in contacts
        ]

    elif name == "get_nearby_hospitals":
        location = user_location_service.get_location(db, user_id)
        if not location:
            return {"error": "No location on file for this user"}
        return hospital_service.get_nearby_hospitals(db, location.latitude, location.longitude, limit=3)

    raise ValueError(f"Unknown tool: {name}")