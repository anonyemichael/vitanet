"""The app's profile reaches the assistant's get_health_profile tool (in-memory database)."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.models  # noqa: F401
from app.database.base import Base
from app.database.schema_sync import sync_schema
from app.enums import AccountType
from app.models.user import User
from app.schemas.health_profile import AppProfileSync
from app.services import ai_tools, health_profile_service


@pytest.fixture
def db():
    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        sync_schema(conn)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


def test_profile_from_the_app_is_what_the_model_sees(db):
    user = User(firebase_uid="abc", full_name="VitaNet user", account_type=AccountType.PERSONAL_USER)
    db.add(user)
    db.commit()
    health_profile_service.sync_from_app(db, user.id, AppProfileSync(
        name="Ama Mensah", age=34, sex="Female", dob="March 3, 1992", conditions=["Hypertension", " "],
        allergies=["Penicillin", "Penicillin"], medications=["Amlodipine 5mg"], blood_type="O+",
        exercise_frequency="Sometimes", smoking=False))
    out = ai_tools.get_health_profile(db, user.id)
    assert out["conditions"] == ["Hypertension"] and out["allergies"] == ["Penicillin"]
    assert out["medications"] == ["Amlodipine 5mg"] and out["blood_type"] == "O+"
    assert out["biological_sex"] == "female" and out["age"] >= 34 and out["exercise_frequency"] == "sometimes"


def test_age_without_date_of_birth_and_nothing_invented(db):
    user = User(firebase_uid="def", full_name="VitaNet user", account_type=AccountType.PERSONAL_USER)
    db.add(user)
    db.commit()
    health_profile_service.sync_from_app(db, user.id, AppProfileSync(age=61))
    out = ai_tools.get_health_profile(db, user.id)
    assert out["age"] == 61 and out["conditions"] == [] and out["blood_type"] is None


def test_same_watch_reading_is_stored_once(db):
    from datetime import datetime, timezone
    from app.schemas.vitals import VitalReadingBatchCreate
    from app.services import vitals_service
    user = User(firebase_uid="ghi", full_name="VitaNet user", account_type=AccountType.PERSONAL_USER)
    db.add(user)
    db.commit()
    at = datetime(2026, 11, 16, 9, 30, tzinfo=timezone.utc)
    batch = VitalReadingBatchCreate(readings=[{"vital_type": "heart_rate", "value": 72, "source": "device", "recorded_at": at},
                                              {"vital_type": "blood_oxygen", "value": 97, "source": "device", "recorded_at": at}])
    assert len(vitals_service.create_readings_batch(db, user.id, batch)) == 2
    assert vitals_service.create_readings_batch(db, user.id, batch) == []        # sent again 2 minutes later
    manual = VitalReadingBatchCreate(readings=[{"vital_type": "heart_rate", "value": 80}])
    assert len(vitals_service.create_readings_batch(db, user.id, manual)) == 1   # no time given: always new
