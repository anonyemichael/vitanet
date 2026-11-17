"""SMS line: keywords, limits, memory, safety warning, SMS length (in-memory database, fake model)."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.base import Base
from app.models.sms import SmsContact, SmsMessage
from app.services import sms_service


class FakeModel:
    def __init__(self, answer):
        self.answer, self.seen = answer, []
        self.chat = self
        self.completions = self

    def create(self, model, messages, **kw):
        self.seen.append(messages)
        msg = type("M", (), {"content": self.answer})
        return type("R", (), {"choices": [type("C", (), {"message": msg})]})


@pytest.fixture
def db():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine, tables=[SmsMessage.__table__, SmsContact.__table__])
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


@pytest.fixture
def model(monkeypatch):
    fake = FakeModel("Sorry to hear that. How long has the headache lasted?")
    monkeypatch.setattr(sms_service.ai_client, "get_client", lambda: fake)
    return fake


def test_reply_comes_from_the_model_and_remembers_the_conversation(db, model):
    assert sms_service.handle_inbound(db, "+233241234567", "I have a headache") == model.answer
    sms_service.handle_inbound(db, "+233 24 123 4567", "Since yesterday")      # same number, other spacing
    second = model.seen[-1]
    assert second[0]["role"] == "system" and "SMS" in second[0]["content"]
    assert [m["content"] for m in second[1:]] == ["I have a headache", model.answer, "Since yesterday"]


def test_phone_number_is_never_stored(db, model):
    sms_service.handle_inbound(db, "+233241234567", "hello")
    stored = " ".join(f"{r.phone_key} {r.text}" for r in db.query(SmsMessage).all())
    assert "241234567" not in stored


def test_danger_sign_gets_a_short_warning_even_when_offline(db, monkeypatch):
    monkeypatch.setattr(sms_service.ai_client, "get_client", lambda: None)
    reply = sms_service.handle_inbound(db, "+233200000001", "My son is fitting and very hot")
    assert reply.startswith("URGENT: Go to the nearest hospital now") and "112" in reply
    assert sms_service.sms_length(reply) == (len(reply), True)                 # plain characters: cheap SMS


def test_stop_and_start(db, model):
    assert "no more" in sms_service.handle_inbound(db, "+233200000002", "stop")
    assert sms_service.handle_inbound(db, "+233200000002", "I have a cough") is None
    assert "Welcome back" in sms_service.handle_inbound(db, "+233200000002", "START")
    assert sms_service.handle_inbound(db, "+233200000002", "I have a cough") == model.answer


def test_hourly_limit(db, model, monkeypatch):
    monkeypatch.setattr(sms_service.settings, "SMS_MAX_PER_HOUR", 2)
    replies = [sms_service.handle_inbound(db, "+233200000003", f"question {i}") for i in range(4)]
    assert replies[:2] == [model.answer, model.answer]
    assert "limit" in replies[2] and replies[3] is None


@pytest.mark.parametrize("text,parts,limit", [
    ("Rest and drink water. " * 40, 3, 459),                                  # plain: 153 per part
    ("Nom nsuo pii na home. Wo yare yɛ den a, kɔ ayaresabea. " * 10, 3, 201),   # Twi ɛ ɔ: 67 per part
])
def test_fit_sms_cuts_at_a_sentence(text, parts, limit):
    out = sms_service.fit_sms(text, parts)
    assert sms_service.sms_length(out)[0] <= limit and out.endswith(".")


def test_route_checks_the_token(monkeypatch):
    from fastapi.testclient import TestClient
    from app.main import app
    monkeypatch.setattr(sms_service.settings, "SMS_WEBHOOK_TOKEN", "secret-token")
    monkeypatch.setattr("app.routes.sms_router._reply_in_background", lambda phone, text: None)
    c = TestClient(app)
    assert c.post("/sms/inbound?token=wrong", data={"from": "+233200000004", "text": "hi"}).status_code == 403
    assert c.post("/sms/inbound?token=secret-token", data={"from": "+233200000004", "text": "hi"}).status_code == 200
