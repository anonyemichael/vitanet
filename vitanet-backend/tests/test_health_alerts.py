"""Health alerts: fixed danger limits, own baseline, no repeats, care circle told only with consent (in-memory DB)."""
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.models  # noqa: F401
from app.database.schema_sync import sync_schema
from app.enums import AccountType
from app.models.care_circle import CareCircle, CareCircleStatus, Relationship
from app.models.health_alert import AlertSeverity, AlertStatus, HealthAlert
from app.models.user import User
from app.schemas.vitals import VitalReadingBatchCreate
from app.services import health_alert_service as alerts, sms_service, vitals_service


@pytest.fixture
def db():
    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        sync_schema(conn)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


@pytest.fixture
def user(db):
    u = User(firebase_uid="u1", full_name="Ama Mensah", account_type=AccountType.PERSONAL_USER)
    db.add(u)
    db.commit()
    return u


def reading(db, user, vt, value, minutes_ago=0):
    at = datetime.utcnow() - timedelta(minutes=minutes_ago)
    r = vitals_service.create_readings_batch(db, user.id, VitalReadingBatchCreate(
        readings=[{"vital_type": vt, "value": value, "source": "device", "recorded_at": at}]))[0]
    return alerts.check_vital_for_alert(db, user.id, vt, value, reading_id=r.id)


def test_first_ever_low_oxygen_is_urgent(db, user):
    a = reading(db, user, "blood_oxygen", 88)                        # no history at all
    assert a.severity == AlertSeverity.URGENT and "88%" in a.message and "112" in a.message


def test_normal_reading_no_alert_and_watch_level(db, user):
    assert reading(db, user, "heart_rate", 72) is None
    assert reading(db, user, "temperature", 38.2).severity == AlertSeverity.WATCH


def test_own_baseline_still_counts(db, user):
    for i, v in enumerate([99, 99, 98, 99]):
        assert reading(db, user, "blood_oxygen", v, minutes_ago=100 - i) is None
    a = reading(db, user, "blood_oxygen", 94)                        # above the fixed limits, 5 below usual
    assert a.severity == AlertSeverity.WATCH and "usual is about 98.8%" in a.message


def test_no_repeat_unless_more_serious(db, user):
    assert reading(db, user, "blood_oxygen", 93).severity == AlertSeverity.WATCH
    assert reading(db, user, "blood_oxygen", 93) is None            # same level again: no new alert
    assert reading(db, user, "blood_oxygen", 89).severity == AlertSeverity.URGENT


def add_contact(db, user, status, phone="024 123 4567", email=None):
    c = CareCircle(requester_id=user.id, full_name="Kofi", contact_phone=phone, contact_email=email,
                   relationship=Relationship.FAMILY, status=status)
    db.add(c)
    db.commit()
    return c


def test_unanswered_urgent_alert_texts_only_contacts_who_agreed(db, user):
    add_contact(db, user, CareCircleStatus.ACCEPTED)
    add_contact(db, user, CareCircleStatus.PENDING, phone="0200000000")
    a = reading(db, user, "blood_oxygen", 88)
    sent = []
    send = lambda phone, text: sent.append((phone, text)) or True
    assert alerts.escalate_due(db, sms_send=send) == 0               # too early
    later = datetime.utcnow() + timedelta(minutes=11)
    assert alerts.escalate_due(db, now=later, sms_send=send) == 1
    assert [p for p, _ in sent] == ["024 123 4567"]
    text = sent[0][1]
    assert text.startswith("VitaNet alert for Ama: blood oxygen 88%") and "112" in text
    assert sms_service.sms_length(text) == (len(text), True) and len(text) <= 160
    db.refresh(a)
    assert a.status == AlertStatus.ESCALATED
    assert alerts.escalate_due(db, now=later, sms_send=send) == 0    # never sent twice


def test_answered_alert_is_not_escalated(db, user):
    add_contact(db, user, CareCircleStatus.ACCEPTED)
    a = reading(db, user, "heart_rate", 160)
    alerts.acknowledge_alert(db, a.id)                                # "I'm OK"
    sent = []
    alerts.escalate_due(db, now=datetime.utcnow() + timedelta(hours=1), sms_send=lambda p, t: sent.append(p) or True)
    assert sent == []


def test_contact_agrees_by_sms_and_can_stop(db, user, monkeypatch):
    monkeypatch.setattr(sms_service.ai_client, "get_client", lambda: None)
    c = add_contact(db, user, CareCircleStatus.PENDING)
    assert "You will get a text if Ama" in sms_service.handle_inbound(db, "+233241234567", "Yes")
    db.refresh(c)
    assert c.status == CareCircleStatus.ACCEPTED
    sms_service.handle_inbound(db, "+233241234567", "STOP")
    assert sms_service.is_opted_out(db, "024 123 4567")              # same number, other spelling


@pytest.mark.parametrize("raw", ["024 123 4567", "0241234567", "+233 24 123 4567", "00233241234567"])
def test_phone_spellings_match(raw):
    assert sms_service.normalize_phone(raw) == "+233241234567"


def test_profile_contacts_become_the_care_circle_once(db, user, monkeypatch):
    from app.schemas.health_profile import AppProfileSync
    from app.services import health_profile_service
    texts = []
    monkeypatch.setattr(sms_service, "send", lambda phone, text: texts.append((phone, text)) or True)
    sync = lambda contacts, replace=True: health_profile_service.sync_from_app(
        db, user.id, AppProfileSync(contacts=contacts, contacts_replace=replace))
    sync([{"name": "Kofi", "phone": "024 123 4567", "relation": "Husband"}])
    sync([{"name": "Kofi", "phone": "+233241234567", "relation": "Husband"}])   # saved again, other spelling
    rows = db.query(CareCircle).all()
    assert len(rows) == 1 and rows[0].relationship == Relationship.PARTNER and rows[0].status == CareCircleStatus.PENDING
    assert len(texts) == 1 and "Reply YES" in texts[0][1] and "Ama" in texts[0][1]
    sync([], replace=False)                                            # app start with an old copy: nothing removed
    assert db.query(CareCircle).count() == 1
    sync([])                                                           # removed in the app
    assert db.query(CareCircle).count() == 0


def test_tick_endpoint_needs_its_token(monkeypatch):
    from fastapi.testclient import TestClient
    from app.main import app
    from app.routes import internal
    monkeypatch.setattr(internal.settings, "TICK_TOKEN", "")
    c = TestClient(app)
    assert c.post("/internal/tick?token=x").status_code == 403          # off when no token is configured
    monkeypatch.setattr(internal.settings, "TICK_TOKEN", "s3cret")
    assert c.post("/internal/tick?token=wrong").status_code == 403
    monkeypatch.setattr(internal.health_alert_service, "escalate_due", lambda db: 2)
    monkeypatch.setattr(internal.video_service, "_ensure_fresh_in_background", lambda: None)
    monkeypatch.setattr(internal.library_service, "_ensure_fresh_in_background", lambda: None)
    assert c.post("/internal/tick?token=s3cret").json() == {"escalated": 2}
