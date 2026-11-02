# app/services/ai_tools.py
from uuid import UUID
from sqlalchemy.orm import Session

from app.services import (
    vitals_service,
    health_profile_service,
    care_circle_service,
    hospital_service,
    user_location_service,
)
from app.models.vitals import VitalType
from app.services.ml_service import ml_service

TOOL_DEFINITIONS = [
    {
        "name": "get_health_metrics",
        "description": "Get the user's latest vitals (heart rate, blood pressure, temperature, blood oxygen) and recent trend.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "name": "get_health_profile",
        "description": "Get the user's health profile including allergies, lifestyle, height, and weight.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "name": "get_care_circle",
        "description": "Get the user's emergency care circle contacts and status.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "name": "get_nearby_hospitals",
        "description": "Get hospitals near the user's current location, ranked by distance, including ambulance availability.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "name": "check_symptoms_ml",
        "description": "Run the VitaNet clinical machine learning model to predict disease, assess severity (urgent, doctor, routine), and get recommended medical precautions based on symptoms and vitals.",
        "parameters": {
            "type": "object",
            "properties": {
                "symptoms": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of symptoms reported by the user (e.g. ['chest_pain', 'fever', 'shortness_of_breath', 'headache']).",
                }
            },
            "required": ["symptoms"],
        },
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

    elif name == "check_symptoms_ml":
        symptoms = args.get("symptoms", [])
        latest = vitals_service.get_all_latest(db, user_id)

        hr = latest.get(VitalType.HEART_RATE)
        hr_val = hr.value if hr else 80.0

        temp = latest.get(VitalType.TEMPERATURE)
        temp_val = temp.value if temp else 37.0

        o2 = latest.get(VitalType.BLOOD_OXYGEN)
        o2_val = o2.value if o2 else 98.0

        sys_bp = latest.get(VitalType.BP_SYSTOLIC)
        sys_val = sys_bp.value if sys_bp else 120.0

        dia_bp = latest.get(VitalType.BP_DIASTOLIC)
        dia_val = dia_bp.value if dia_bp else 80.0

        return ml_service.predict_triage(
            symptoms=symptoms,
            heart_rate=hr_val,
            temperature=temp_val,
            blood_oxygen=o2_val,
            systolic_bp=sys_val,
            diastolic_bp=dia_val,
        )

    raise ValueError(f"Unknown tool: {name}")
