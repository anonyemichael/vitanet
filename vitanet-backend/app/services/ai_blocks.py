# app/services/ai_blocks.py
from app.schemas.chat_blocks import (
    TextBlock, HospitalRecommendationBlock, VitalCheckLoadingBlock,
    VitalResultBlock, ActionButtonsBlock, ActionButton,
)

VITAL_LABELS = {
    "heart_rate": ("Heart Rate", "BPM"),
    "bp_systolic": ("Blood Pressure (Systolic)", "mmHg"),
    "bp_diastolic": ("Blood Pressure (Diastolic)", "mmHg"),
    "temperature": ("Temperature", "°C"),
    "blood_oxygen": ("Blood Oxygen", "%"),
}


def classify_vital_status(vital_type: str, value: float) -> str:
    """Very simple thresholding for a hackathon demo — not medical advice."""
    if vital_type == "heart_rate":
        return "Normal" if 60 <= value <= 100 else "Watch"
    if vital_type == "bp_systolic":
        return "Normal" if value < 130 else "Watch"
    if vital_type == "blood_oxygen":
        return "Normal" if value >= 95 else "Watch"
    if vital_type == "temperature":
        return "Normal" if 36.1 <= value <= 37.5 else "Watch"
    return "Normal"


def blocks_for_health_metrics(result: dict) -> list:
    blocks = []
    # Demo focuses on heart rate first, matching the screenshot's flow
    priority = ["heart_rate", "bp_systolic", "blood_oxygen", "temperature"]
    for vt in priority:
        if vt not in result:
            continue
        label, unit = VITAL_LABELS.get(vt, (vt, ""))
        blocks.append(VitalCheckLoadingBlock(vital_type=vt, label=f"Checking your {label.lower()}..."))
        data = result[vt]
        blocks.append(VitalResultBlock(
            vital_type=vt,
            label=label,
            value=data["latest_value"],
            unit=unit,
            status=classify_vital_status(vt, data["latest_value"]),
            min_value=data.get("min"),
            avg_value=data.get("avg"),
            max_value=data.get("max"),
        ))
        break  # keep it to one vital per turn for a clean demo; remove to show all
    return blocks


def blocks_for_hospitals(result) -> list:
    if isinstance(result, dict) and result.get("error"):
        return []
    if not result:
        return []
    top = result[0]
    return [HospitalRecommendationBlock(
        name=top["name"],
        distance_km=top["distance_km"],
        est_time_min=max(1, round(top["distance_km"] * 3)),  # rough estimate for demo
        crowd_level="Low" if top.get("ambulance_available") else "Moderate",
        address=top.get("address"),
    )]

def build_action_buttons(tools_used: set[str], hospital_result=None) -> ActionButtonsBlock | None:
    buttons = []

    hospital_available = (
        hospital_result
        and isinstance(hospital_result, list)
        and len(hospital_result) > 0
    )

    if "get_nearby_hospitals" in tools_used and hospital_available:
        top = hospital_result[0]
        buttons.append(ActionButton(label=f"Call {top['name']}", action="call_hospital", target_id=str(top["id"])))
        buttons.append(ActionButton(label="Get Directions", action="get_directions", target_id=str(top["id"])))

    buttons.append(ActionButton(label="Notify Caregiver", action="notify_caregiver"))
    return ActionButtonsBlock(buttons=buttons) if buttons else None