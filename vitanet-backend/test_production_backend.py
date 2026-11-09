"""Comprehensive backend test suite verifying real production endpoints."""
import os

# Endpoints require a signed-in user; the dev bypass (never active when
# ENVIRONMENT=production) stands in for one. Must be set before app import.
os.environ.setdefault("ENVIRONMENT", "development")
os.environ.setdefault("DEV_BYPASS_AUTH", "true")
# Own throwaway database (like test_security.py) so the dev vitanet.db is
# never modified; recreated each run so seed data is fresh.
os.environ.setdefault("DATABASE_URL", "sqlite:///./production_test.db")
if os.environ["DATABASE_URL"] == "sqlite:///./production_test.db" and os.path.exists("production_test.db"):
    os.remove("production_test.db")

from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)
# Run the lifespan so tables are created and seed data loaded; without it
# every query failed with "no such table".
client.__enter__()


def _ensure_dev_staff():
    """Admin routes require an approved staff account; give the dev user one."""
    from app.database.connection import SessionLocal
    from app.dependencies.security import DEV_TEST_UID
    from app.models.hospital import Hospital
    from app.models.staff_account import StaffAccount, StaffRole, StaffStatus

    db = SessionLocal()
    try:
        if db.get(StaffAccount, DEV_TEST_UID) is None:
            hospital = db.query(Hospital).first()
            db.add(StaffAccount(
                firebase_uid=DEV_TEST_UID,
                email="dev@vitanet.test",
                full_name="Dev Tester",
                role=StaffRole.ADMIN,
                status=StaffStatus.APPROVED,
                hospital_id=hospital.id if hospital else None,
            ))
            db.commit()

        # Patient endpoints only serve the caller's own records, so the seeded
        # demo patient must belong to the dev identity for the patient tests.
        from uuid import UUID as _UUID
        from app.models.user import User
        demo = db.get(User, _UUID("00000000-0000-0000-0000-000000000001"))
        if demo is not None and demo.firebase_uid != DEV_TEST_UID:
            demo.firebase_uid = DEV_TEST_UID
            db.commit()
    finally:
        db.close()


_ensure_dev_staff()


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "VitaNet API running"
    assert data["version"] == "2.0.0"


def test_portal_smoke():
    """The dev user is an approved admin of the first seeded hospital."""
    dash = client.get("/portal/dashboard")
    assert dash.status_code == 200, dash.text
    assert {"incoming", "waiting", "in_treatment", "beds_free"} <= set(dash.json()["counts"])
    ward = client.post("/portal/wards", json={"name": "Emergency", "beds_total": 4})
    assert ward.status_code == 200, ward.text
    case = client.post("/portal/cases", json={
        "patient_name": "Ama Kuffour", "complaint": "Pneumonia, low SpO2", "level": "urgent",
        "ward_id": ward.json()["id"]}).json()
    assert case["status"] == "waiting" and case["ward_name"] == "Emergency"
    v = client.post(f"/portal/cases/{case['id']}/vitals", json={"blood_oxygen": 90, "respiratory_rate": 26})
    assert v.status_code == 200 and v.json()["latest_vitals"]["early_warning"] >= 5
    cap = client.get("/portal/capacity").json()
    assert cap["wards"][0]["beds_occupied"] == 1 and cap["wards"][0]["patients"] == ["Ama Kuffour"]
    assert any(a["kind"] == "early_warning" for a in client.get("/portal/alerts").json())


def test_legacy_admin_routes_are_gone():
    for path in ("/admin/stats", "/admin/patients", "/admin/alerts"):
        assert client.get(path).status_code == 404


def test_ml_triage_prediction():
    response = client.post(
        "/triage/predict",
        json={
            "symptoms": ["chest_pain", "shortness_of_breath"],
            "age": 62,
            "gender": "M",
            "heart_rate": 108.0,
            "blood_oxygen": 95.0,
            "systolic_bp": 162.0,
            "diastolic_bp": 98.0
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "disease" in data
    assert "confidence" in data
    assert "severity" in data
    assert data["severity"] in ["urgent", "doctor", "routine"]
    assert "description" in data
    assert len(data["precautions"]) > 0
    assert "recommendation" in data


def test_ml_symptoms_list():
    response = client.get("/triage/symptoms")
    assert response.status_code == 200
    symptoms = response.json()
    assert len(symptoms) > 10
    assert "chest_pain" in symptoms
    assert "fever" in symptoms


def test_patient_vitals_endpoints():
    demo_id = "00000000-0000-0000-0000-000000000001"
    # 1. Fetch latest
    response = client.get(f"/vitals/{demo_id}/latest")
    assert response.status_code == 200
    data = response.json()
    assert "heart_rate" in data
    assert data["heart_rate"]["value"] == 74.0

    # 2. Post new reading
    post_resp = client.post(
        f"/vitals/{demo_id}",
        json={"vital_type": "heart_rate", "value": 78.0, "source": "device"}
    )
    assert post_resp.status_code == 200
    reading = post_resp.json()
    assert reading["value"] == 78.0


def test_care_circles_endpoints():
    demo_id = "00000000-0000-0000-0000-000000000001"
    # 1. List members
    response = client.get(f"/care-circles/user/{demo_id}")
    assert response.status_code == 200
    members = response.json()
    assert len(members) >= 2
    names = [m["full_name"] for m in members]
    assert "Sarah Mensah" in names

    # 2. Add member
    add_resp = client.post(
        f"/care-circles/user/{demo_id}",
        json={
            "full_name": "Kofi Mensah Jr",
            "relationship": "family",
            "contact_email": "junior.mensah@gmail.com",
            "is_primary": False
        }
    )
    assert add_resp.status_code == 201
    created = add_resp.json()
    assert created["full_name"] == "Kofi Mensah Jr"


if __name__ == "__main__":
    tests = [(n, f) for n, f in list(globals().items()) if n.startswith("test_") and callable(f)]
    for i, (name, fn) in enumerate(tests, 1):
        print(f"{i}. {name}...", flush=True)
        fn()
    print(f"ALL {len(tests)} BACKEND TESTS PASSED", flush=True)
