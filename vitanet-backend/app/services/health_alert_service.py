# app/services/health_alert_service.py
import os
from uuid import UUID
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from google import genai
from app.core.config import settings as app_settings
from app.models.health_alert import HealthAlert, AlertSeverity, AlertStatus
from app.models.vitals import VitalType
from app.services import vitals_service, care_circle_activity_service, care_circle_service
from app.models.care_circle_activity import ActivityType

client = genai.Client(api_key=app_settings.GEMINI_API_KEY)

# Simple absolute thresholds — deviation from the user's own 7-day baseline
THRESHOLDS = {
    "heart_rate": {"watch": 10, "urgent": 20},        # bpm deviation from avg
    "bp_systolic": {"watch": 10, "urgent": 20},         # mmHg deviation from avg
    "bp_diastolic": {"watch": 8, "urgent": 15},
    "blood_oxygen": {"watch": -3, "urgent": -6},        # negative = drop from avg
    "temperature": {"watch": 0.5, "urgent": 1.0},       # °C deviation from avg
}

ESCALATION_DELAY_SECONDS = 30  # short for demo purposes; would be 15-30 min in production


def generate_alert_message(vital_type: str, latest_value: float, avg_value: float, severity: str) -> str:
    """Use Gemini for a natural-language alert message — simple text call, no tools needed."""
    prompt = (
        f"Write a short (1-2 sentence), calm, plain-language health alert for a care app. "
        f"Vital: {vital_type}. Latest reading: {latest_value}. Recent average: {avg_value}. "
        f"Severity: {severity}. Do not diagnose. Do not use markdown."
    )
    try:
        interaction = client.interactions.create(model="gemini-3.6-flash", input=prompt)
        return interaction.output_text.strip()
    except Exception:
        # Fallback if Gemini fails — never let alerting silently break
        return f"Your {vital_type.replace('_', ' ')} reading ({latest_value}) is outside your usual range (avg {avg_value})."


def check_vital_for_alert(db: Session, user_id: UUID, vital_type: str, latest_value: float) -> HealthAlert | None:
    if vital_type not in THRESHOLDS:
        return None

    try:
        vt_enum = VitalType(vital_type)
    except ValueError:
        return None

    trend = vitals_service.get_trend(db, user_id, vt_enum, days=7)
    if len(trend) < 3:
        return None  # not enough history to establish a baseline yet

    values = [r.value for r in trend]
    avg_value = sum(values) / len(values)
    deviation = latest_value - avg_value

    thresholds = THRESHOLDS[vital_type]
    is_negative_metric = thresholds["watch"] < 0  # e.g. blood_oxygen: alert on drops, not rises

    severity = None
    if is_negative_metric:
        if deviation <= thresholds["urgent"]:
            severity = AlertSeverity.URGENT
        elif deviation <= thresholds["watch"]:
            severity = AlertSeverity.WATCH
    else:
        if abs(deviation) >= thresholds["urgent"]:
            severity = AlertSeverity.URGENT
        elif abs(deviation) >= thresholds["watch"]:
            severity = AlertSeverity.WATCH

    if not severity:
        return None

    message = generate_alert_message(vital_type, latest_value, round(avg_value, 1), severity.value)

    alert = HealthAlert(
        user_id=user_id,
        vital_type=vital_type,
        severity=severity,
        status=AlertStatus.PENDING,
        message=message,
        latest_value=str(latest_value),
        baseline_avg=str(round(avg_value, 1)),
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert


def acknowledge_alert(db: Session, alert_id: UUID) -> HealthAlert | None:
    alert = db.query(HealthAlert).filter(HealthAlert.id == alert_id).first()
    if not alert:
        return None
    alert.status = AlertStatus.ACKNOWLEDGED
    alert.acknowledged_at = datetime.utcnow()
    db.commit()
    db.refresh(alert)
    return alert


def escalate_if_unacknowledged(db: Session, alert_id: UUID):
    """Called after a delay (background task). Only escalates urgent, still-pending alerts."""
    alert = db.query(HealthAlert).filter(HealthAlert.id == alert_id).first()
    if not alert or alert.status != AlertStatus.PENDING or alert.severity != AlertSeverity.URGENT:
        return  # already acknowledged, or not urgent — nothing to do

    contacts = care_circle_service.get_care_circle_for_user(db, alert.user_id)
    for contact in contacts:
        care_circle_activity_service.create_activity(
            db,
            user_id=contact.requester_id,
            care_circle_id=contact.id,
            activity_type=ActivityType.CONTACT_ADDED,  # swap for a dedicated URGENT_ALERT type if you add one
            title="Urgent health alert — unacknowledged",
            message=alert.message,
        )

    alert.status = AlertStatus.ESCALATED
    alert.escalated_at = datetime.utcnow()
    db.commit()