"""Hospital portal live updates (WS /portal/ws), audit F-12: sign-in, staff checks, hospital isolation, pings,
clean-up. Token -> staff lookup is tested against an in-memory database; the socket tests use a fake lookup."""
import json
import uuid

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.websockets import WebSocketDisconnect

import app.models  # noqa: F401
from app.database.schema_sync import sync_schema
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus
from app.routes import portal_live
from app.services.portal_events import hub

H1, H2 = uuid.uuid4(), uuid.uuid4()


@pytest.fixture
def client(monkeypatch):
    from fastapi.testclient import TestClient
    from app.main import app
    staff = {"t-h1": (H1, None), "t-h1b": (H1, None), "t-h2": (H2, None), "t-pending": (None, 4403)}
    monkeypatch.setattr(portal_live, "_hospital_for_token", lambda tok: staff.get(tok, (None, 4401)))
    yield TestClient(app)   # no startup jobs (alert sweeper, video / library refresh) in these tests


def connect(c, token):
    ws = c.websocket_connect("/portal/ws").__enter__()
    ws.send_text(json.dumps({"token": token}))
    return ws


def test_bad_token_and_pending_staff_are_refused(client):
    for token, code in (("nonsense", 4401), ("t-pending", 4403)):
        ws = connect(client, token)
        with pytest.raises(WebSocketDisconnect) as e:
            ws.receive_json()
        assert e.value.code == code


def test_events_reach_only_their_own_hospital(client):
    a, b, other = connect(client, "t-h1"), connect(client, "t-h1b"), connect(client, "t-h2")
    for ws in (a, b, other):
        assert ws.receive_json() == {"type": "ready"}
    hub.publish(H1, "referral", "r-1")
    assert a.receive_json() == {"type": "referral", "id": "r-1"}
    assert b.receive_json() == {"type": "referral", "id": "r-1"}       # every staff phone of hospital 1
    hub.publish(H2, "case", "c-9")
    assert other.receive_json() == {"type": "case", "id": "c-9"}       # hospital 2 only gets its own event
    hub.publish(H1, "not-a-type", "x")                                  # unknown event types are dropped
    hub.publish(H1, "alert", "a-1")
    assert a.receive_json() == {"type": "alert", "id": "a-1"}
    for ws in (a, b, other):
        ws.__exit__(None, None, None)


def test_ping_when_quiet(client, monkeypatch):
    monkeypatch.setattr(portal_live, "PING_SECONDS", 0.05)
    ws = connect(client, "t-h1")
    assert ws.receive_json() == {"type": "ready"}
    assert ws.receive_json() == {"type": "ping"}
    ws.__exit__(None, None, None)


def test_closed_phones_are_unsubscribed(client):
    ws = connect(client, "t-h2")
    assert ws.receive_json() == {"type": "ready"}
    assert hub.listeners(H2) >= 1
    ws.close()
    ws.__exit__(None, None, None)
    import time
    for _ in range(50):
        if hub.listeners(H2) == 0:
            break
        time.sleep(0.02)
    assert hub.listeners(H2) == 0


def test_token_lookup_checks_staff_approval_and_hospital(monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with engine.begin() as conn:
        sync_schema(conn)
    Session = sessionmaker(bind=engine)
    db = Session()
    from app.models.hospital import Hospital
    hosp_cols = {c.name for c in Hospital.__table__.columns}
    h = Hospital(**{k: v for k, v in {"id": H1, "name": "Ridge", "latitude": 5.56, "longitude": -0.2}.items()
                    if k in hosp_cols})
    db.add(h)
    db.add_all([
        StaffAccount(firebase_uid="ok", full_name="Nurse A", role=list(StaffRole)[0], status=StaffStatus.APPROVED,
                     hospital_id=H1),
        StaffAccount(firebase_uid="wait", full_name="Nurse B", role=list(StaffRole)[0], status=StaffStatus.PENDING,
                     hospital_id=H1),
    ])
    db.commit()
    monkeypatch.setattr(portal_live, "SessionLocal", Session)
    monkeypatch.setattr(portal_live.security, "DEV_BYPASS_AUTH", False)
    def verify(token):
        if token.startswith("bad"):
            raise ValueError("expired")
        return {"sub": token}
    monkeypatch.setattr(portal_live.security, "verify_firebase_id_token", verify)
    assert portal_live._hospital_for_token("ok") == (H1, None)
    assert portal_live._hospital_for_token("wait") == (None, 4403)     # not approved yet
    assert portal_live._hospital_for_token("stranger") == (None, 4403)  # not staff
    assert portal_live._hospital_for_token("bad-expired") == (None, 4401)
