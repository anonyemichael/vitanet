# app/services/health_alert_service.py
"""Health alerts from watch / manual readings.

1. A new reading is checked two ways and the more serious result counts:
   - DANGER_LIMITS: fixed levels that are dangerous for anyone (works from the very first reading);
   - BASELINE: a big change from the person's own 7-day average (needs at least 3 earlier readings).
2. No repeats: no new alert for the same vital within REPEAT_WINDOW unless it is more serious.
3. The app shows the alert on every screen with "I'm OK" (acknowledge) and "Get help".
4. Urgent and not acknowledged after ALERT_ESCALATION_MINUTES: the care-circle contacts who agreed to get alerts
   are told by SMS (Africa's Talking), or email when they have no phone number (escalate_due, run every minute).

The message is a fixed template, never written by a model: an alert must show the exact numbers and must work when
the model is offline.
"""
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.config import settings as app_settings
from app.models.care_circle import CareCircleStatus
from app.models.care_circle_activity import ActivityType
from app.models.health_alert import AlertSeverity, AlertStatus, HealthAlert
from app.models.user import User
from app.models.vitals import VitalType
from app.services import care_circle_activity_service, care_circle_service, vitals_service

logger = logging.getLogger(__name__)

# REVIEW (clinical reviewer): fixed danger levels, based on the NEWS2 bands. Heart rate is set wider than NEWS2
# because a watch also measures during exercise. (low_urgent, low_watch, high_watch, high_urgent); None = no limit.
DANGER_LIMITS = {
    "blood_oxygen": (91, 93, None, None),            # %: 91 or less urgent, 92-93 watch
    "heart_rate": (40, 50, 131, 150),                # bpm
    "bp_systolic": (90, 100, 160, 180),              # mmHg
    "bp_diastolic": (None, None, 100, 120),          # mmHg
    "temperature": (35.0, None, 38.0, 39.5),         # °C
    "respiratory_rate": (8, None, 21, 25),           # breaths/min
}

# Change from the person's own 7-day average.
BASELINE = {
    "heart_rate": {"watch": 10, "urgent": 20},
    "bp_systolic": {"watch": 10, "urgent": 20},
    "bp_diastolic": {"watch": 8, "urgent": 15},
    "blood_oxygen": {"watch": -3, "urgent": -6},      # negative = only a drop counts
    "temperature": {"watch": 0.5, "urgent": 1.0},
}
THRESHOLDS = BASELINE   # old name

REPEAT_WINDOW = timedelta(hours=6)
_RANK = {None: 0, AlertSeverity.WATCH: 1, AlertSeverity.URGENT: 2}

LABEL = {"heart_rate": "heart rate", "bp_systolic": "blood pressure (top number)",
         "bp_diastolic": "blood pressure (bottom number)", "blood_oxygen": "blood oxygen",
         "temperature": "temperature", "respiratory_rate": "breathing rate"}
UNIT = {"heart_rate": " bpm", "bp_systolic": " mmHg", "bp_diastolic": " mmHg", "blood_oxygen": "%",
        "temperature": " °C", "respiratory_rate": " breaths/min"}


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _fmt(vital_type: str, value) -> str:
    v = float(value)
    return f"{v:g}{UNIT.get(vital_type, '')}" if vital_type != "temperature" else f"{v:.1f}{UNIT['temperature']}"


def absolute_severity(vital_type: str, value: float) -> Optional[AlertSeverity]:
    limits = DANGER_LIMITS.get(vital_type)
    if not limits:
        return None
    low_u, low_w, high_w, high_u = limits
    if (low_u is not None and value <= low_u) or (high_u is not None and value >= high_u):
        return AlertSeverity.URGENT
    if (low_w is not None and value <= low_w) or (high_w is not None and value >= high_w):
        return AlertSeverity.WATCH
    return None


def baseline_severity(vital_type: str, value: float, avg: Optional[float]) -> Optional[AlertSeverity]:
    t = BASELINE.get(vital_type)
    if not t or avg is None:
        return None
    deviation = value - avg
    if t["watch"] < 0:                                   # only a drop counts
        return (AlertSeverity.URGENT if deviation <= t["urgent"]
                else AlertSeverity.WATCH if deviation <= t["watch"] else None)
    return (AlertSeverity.URGENT if abs(deviation) >= t["urgent"]
            else AlertSeverity.WATCH if abs(deviation) >= t["watch"] else None)


def generate_alert_message(vital_type: str, latest_value: float, avg_value: Optional[float], severity: str) -> str:
    label = LABEL.get(vital_type, vital_type.replace("_", " "))
    usual = f" Your usual is about {_fmt(vital_type, avg_value)}." if avg_value is not None else ""
    if severity == "urgent":
        advice = ("This can be dangerous. If you feel unwell, short of breath, confused or have chest pain, go to "
                  "the nearest hospital now or call 112 / 193. Tap \"I'm OK\" if you are fine.")
    else:
        advice = "Please rest and measure again soon. If you feel unwell, contact a clinic."
    return f"Your {label} reading is {_fmt(vital_type, latest_value)}.{usual} {advice}"


def check_vital_for_alert(db: Session, user_id: UUID, vital_type: str, latest_value: float,
                          reading_id: Optional[UUID] = None) -> HealthAlert | None:
    """A new alert for this reading, or None. `reading_id` (the stored reading) is left out of the baseline."""
    try:
        vt_enum = VitalType(vital_type)
    except ValueError:
        return None

    trend = vitals_service.get_trend(db, user_id, vt_enum, days=7)
    if reading_id is not None:
        earlier = [r.value for r in trend if r.id != reading_id]
    else:
        earlier = [r.value for r in trend][:-1]
    avg = round(sum(earlier) / len(earlier), 1) if len(earlier) >= 3 else None

    a, b = absolute_severity(vital_type, latest_value), baseline_severity(vital_type, latest_value, avg)
    severity = a if _RANK[a] >= _RANK[b] else b
    if severity is None:
        return None

    recent = (db.query(HealthAlert)
              .filter(HealthAlert.user_id == user_id, HealthAlert.vital_type == vital_type,
                      HealthAlert.created_at >= _now() - REPEAT_WINDOW).all())
    if any(_RANK[r.severity] >= _RANK[severity] for r in recent):
        return None                                                    # already told them

    alert = HealthAlert(
        user_id=user_id, vital_type=vital_type, severity=severity, status=AlertStatus.PENDING,
        message=generate_alert_message(vital_type, latest_value, avg, severity.value),
        latest_value=str(latest_value), baseline_avg=str(avg) if avg is not None else None,
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
    alert.acknowledged_at = _now()
    db.commit()
    db.refresh(alert)
    return alert


# ---------------------------------------------------------------- telling the care circle
def care_message(alert: HealthAlert, person: str) -> str:
    """Plain-character SMS (one part where possible)."""
    label = LABEL.get(alert.vital_type, alert.vital_type.replace("_", " "))
    value = _fmt(alert.vital_type, alert.latest_value).replace(" °C", "C")
    usual = (f" (usual about {_fmt(alert.vital_type, alert.baseline_avg).replace(' °C', 'C')})"
             if alert.baseline_avg else "")
    when = alert.created_at.strftime("%H:%M") + " GMT" if alert.created_at else ""
    return (f"VitaNet alert for {person}: {label} {value}{usual} at {when}, and they have not answered. "
            f"Please check on them now. Emergency: 112 / ambulance 193.")


def _person(db: Session, user_id: UUID) -> str:
    user = db.get(User, user_id)
    name = (user.full_name or "").strip() if user else ""
    return name.split()[0] if name and name != "VitaNet user" else "your contact"


def _send_email(to: str, subject: str, text: str) -> bool:
    if not app_settings.RESEND_API_KEY:
        logger.warning("Alert email not sent: RESEND_API_KEY is not set")
        return False
    try:
        import resend
        resend.api_key = app_settings.RESEND_API_KEY
        resend.Emails.send({"from": "VitaNet <onboarding@resend.dev>", "to": [to], "subject": subject, "text": text})
        return True
    except Exception as e:
        logger.warning("Alert email failed: %s", e)
        return False


def escalate(db: Session, alert: HealthAlert, sms_send=None) -> int:
    """Tell the care-circle contacts who agreed to get alerts. Returns how many were reached."""
    from app.services import sms_service
    sms_send = sms_send or sms_service.send
    person = _person(db, alert.user_id)
    text = care_message(alert, person)
    reached = 0
    for c in care_circle_service.get_care_circle_for_user(db, alert.user_id):
        if c.status != CareCircleStatus.ACCEPTED:
            continue                                                    # never agreed: not contacted
        sent = False
        if c.contact_phone and not sms_service.is_opted_out(db, c.contact_phone):
            sent = sms_send(c.contact_phone, text)
        if not sent and c.contact_email:
            sent = _send_email(c.contact_email, f"VitaNet alert for {person}", text)
        reached += bool(sent)
        care_circle_activity_service.create_activity(
            db, user_id=alert.user_id, care_circle_id=c.id, activity_type=ActivityType.URGENT_ALERT,
            title=f"{c.full_name} was told about your alert" if sent else f"Could not reach {c.full_name}",
            message=alert.message)
    return reached


def escalate_due(db: Session, now: Optional[datetime] = None, sms_send=None) -> int:
    """Escalate every urgent alert still pending after ALERT_ESCALATION_MINUTES. Each alert is claimed with one
    UPDATE first, so two server workers never both send it."""
    now = now or _now()
    cutoff = now - timedelta(minutes=app_settings.ALERT_ESCALATION_MINUTES)
    due = (db.query(HealthAlert.id)
           .filter(HealthAlert.status == AlertStatus.PENDING, HealthAlert.severity == AlertSeverity.URGENT,
                   HealthAlert.created_at <= cutoff).all())
    done = 0
    for (alert_id,) in due:
        claimed = (db.query(HealthAlert)
                   .filter(HealthAlert.id == alert_id, HealthAlert.status == AlertStatus.PENDING)
                   .update({HealthAlert.status: AlertStatus.ESCALATED, HealthAlert.escalated_at: now},
                           synchronize_session=False))
        db.commit()
        if claimed != 1:
            continue
        alert = db.get(HealthAlert, alert_id)
        try:
            escalate(db, alert, sms_send=sms_send)
            db.commit()
        except Exception:
            logger.exception("Escalating alert %s failed", alert_id)
            db.rollback()
        done += 1
    return done
