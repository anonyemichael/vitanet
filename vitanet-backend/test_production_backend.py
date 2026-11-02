"""Comprehensive backend test suite verifying real production endpoints."""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "VitaNet API running"
    assert data["version"] == "2.0.0"


def test_admin_stats():
    response = client.get("/admin/stats")
    assert response.status_code == 200
    data = response.json()
    assert "activePatients" in data
    assert "availableWards" in data
    assert "systemHealth" in data
    assert "staffOnDuty" in data
    assert data["availableWards"] >= 5


def test_admin_patients():
    response = client.get("/admin/patients")
    assert response.status_code == 200
    patients = response.json()
    assert len(patients) >= 7
    first = patients[0]
    assert "id" in first
    assert "name" in first
    assert "status" in first


def test_admin_patient_detail_and_notes():
    # 1. Fetch detail
    response = client.get("/admin/patients/P-10233")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "P-10233"
    assert data["name"] == "Ama Kuffour"
    assert len(data["vitals"]) > 0
    assert len(data["timeline"]) > 0

    # 2. Add clinical note
    note_resp = client.post(
        "/admin/patients/P-10233/notes",
        json={"note": "Oxygen titrated to 96%. Patient resting quietly.", "author": "Dr. Kwame Mensah"}
    )
    assert note_resp.status_code == 200
    updated_data = note_resp.json()
    assert "Oxygen titrated" in updated_data["note"]
    assert any("Oxygen titrated" in t["text"] for t in updated_data["timeline"])


def test_admin_patient_transfer():
    response = client.patch(
        "/admin/patients/P-10233/transfer",
        json={"newLocation": "ICU · Bed 2", "author": "Dr. Kwame Mensah"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["location"] == "ICU · Bed 2"
    assert any("Transferred from" in t["text"] for t in data["timeline"])


def test_admin_cases():
    # List cases
    response = client.get("/admin/cases")
    assert response.status_code == 200
    cases = response.json()
    assert len(cases) >= 10

    # Filter waiting cases
    waiting_resp = client.get("/admin/cases?status=waiting")
    assert waiting_resp.status_code == 200
    waiting = waiting_resp.json()
    assert all(c["status"] == "waiting" for c in waiting)

    # Update case status
    update_resp = client.patch(
        "/admin/cases/C-2041",
        json={"status": "treatment", "assignee": "Dr. Kwame Mensah"}
    )
    assert update_resp.status_code == 200
    updated = update_resp.json()
    assert updated["status"] == "treatment"
    assert updated["assignee"] == "Dr. Kwame Mensah"


def test_admin_wards():
    response = client.get("/admin/wards")
    assert response.status_code == 200
    wards = response.json()
    assert len(wards) >= 5
    ward_names = [w["name"] for w in wards]
    assert "Emergency" in ward_names
    assert "ICU" in ward_names


def test_admin_equipment():
    response = client.get("/admin/equipment")
    assert response.status_code == 200
    items = response.json()
    assert len(items) >= 4
    names = [i["name"] for i in items]
    assert "Ventilators" in names
    assert "Oxygen supply" in names


def test_admin_staff():
    response = client.get("/admin/staff")
    assert response.status_code == 200
    staff = response.json()
    assert len(staff) >= 5
    names = [s["name"] for s in staff]
    assert any("Dr. Kwame Mensah" in n for n in names)


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
    import sys
    print("Running test suite...", flush=True)
    print("1. test_root...", flush=True)
    test_root()
    print("2. test_admin_stats...", flush=True)
    test_admin_stats()
    print("3. test_admin_patients...", flush=True)
    test_admin_patients()
    print("4. test_admin_patient_detail_and_notes...", flush=True)
    test_admin_patient_detail_and_notes()
    print("5. test_admin_patient_transfer...", flush=True)
    test_admin_patient_transfer()
    print("6. test_admin_cases...", flush=True)
    test_admin_cases()
    print("7. test_admin_wards...", flush=True)
    test_admin_wards()
    print("8. test_admin_equipment...", flush=True)
    test_admin_equipment()
    print("9. test_admin_staff...", flush=True)
    test_admin_staff()
    print("10. test_ml_triage_prediction...", flush=True)
    test_ml_triage_prediction()
    print("11. test_ml_symptoms_list...", flush=True)
    test_ml_symptoms_list()
    print("12. test_patient_vitals_endpoints...", flush=True)
    test_patient_vitals_endpoints()
    print("13. test_care_circles_endpoints...", flush=True)
    test_care_circles_endpoints()
    print("ALL BACKEND TEST SUITES PASSED CLEANLY!", flush=True)
