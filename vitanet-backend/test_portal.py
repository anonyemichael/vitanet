"""Hospital portal flow tests (throwaway DB, simulated Firebase users)."""
import os

os.environ["DATABASE_URL"] = os.environ.get("PORTAL_TEST_DB", "sqlite:///./portal_test.db")
os.environ["BOOTSTRAP_ADMIN_EMAILS"] = "boss@example.com,boss2@example.com"
os.environ["ENVIRONMENT"] = "production"

from fastapi.testclient import TestClient  # noqa: E402

from app.dependencies import security  # noqa: E402
from app.main import app  # noqa: E402

U = {
    "boss": ("boss-uid", "boss@example.com", "Dr Boss"),
    "boss2": ("boss2-uid", "boss2@example.com", "Dr Other"),
    "nurse": ("nurse-uid", "nurse@example.com", "Nurse Joy"),
    "doc": ("doc-uid", "doc@example.com", "Dr Addo"),
    "pat": ("pat-uid", "pat@example.com", "Ama Patient"),
}


def fake_verify(token):
    uid, email, name = U[token]
    return {"sub": uid, "email": email, "email_verified": True, "name": name,
            "firebase": {"sign_in_provider": "password"}}


security.verify_firebase_id_token = fake_verify
c = TestClient(app)
c.__enter__()


def h(k):
    return {"Authorization": f"Bearer {k}"}


S = {}


def test_admin_creates_facility():
    me = c.get("/staff/me", headers=h("boss")).json()
    assert me["status"] == "approved" and me["role"] == "admin" and me["hospital_id"] is None
    assert c.get("/portal/dashboard", headers=h("boss")).status_code == 409  # no hospital yet
    r = c.post("/portal/hospitals", headers=h("boss"), json={
        "name": "Korle Bu Teaching Hospital", "address": "Accra", "latitude": 5.5365, "longitude": -0.2263,
        "phone_number": "+233302665401"})
    assert r.status_code == 200, r.text
    S["hid"] = r.json()["id"]
    assert c.post("/portal/hospitals", headers=h("boss"), json={
        "name": "Again", "latitude": 1, "longitude": 1}).status_code == 409
    w = c.post("/portal/wards", headers=h("boss"), json={"name": "Emergency", "beds_total": 2, "critical": True})
    assert w.status_code == 200
    S["ward"] = w.json()["id"]
    assert c.post("/portal/equipment", headers=h("boss"),
                  json={"name": "Ventilators", "available": 3, "total": 4}).status_code == 200


def test_other_hospital_isolated():
    c.get("/staff/me", headers=h("boss2"))
    r = c.post("/portal/hospitals", headers=h("boss2"), json={"name": "Ridge Hospital", "latitude": 5.56, "longitude": -0.2})
    S["hid2"] = r.json()["id"]


def test_staff_join_requires_hospital_and_approval():
    assert c.post("/staff/register", headers=h("nurse"), json={"full_name": "Nurse Joy", "role": "nurse"}).status_code == 400
    r = c.post("/staff/register", headers=h("nurse"), json={"full_name": "Nurse Joy", "role": "nurse", "hospital_id": S["hid"]})
    assert r.json()["status"] == "pending"
    c.post("/staff/register", headers=h("doc"), json={"full_name": "Dr Addo", "role": "doctor", "hospital_id": S["hid"]})
    assert c.get("/portal/dashboard", headers=h("nurse")).status_code == 403
    # other hospital's admin can't see or approve them
    assert all(x["firebase_uid"] != "nurse-uid" for x in c.get("/admin/staff-requests", headers=h("boss2")).json())
    assert c.post("/admin/staff-requests/nurse-uid/approve", headers=h("boss2")).status_code == 404
    for uid in ("nurse-uid", "doc-uid"):
        assert c.post(f"/admin/staff-requests/{uid}/approve", headers=h("boss")).status_code == 200
    assert c.get("/portal/dashboard", headers=h("nurse")).status_code == 200
    assert c.get("/portal/team", headers=h("nurse")).status_code == 403  # admin only


def test_patient_referral_flow():
    fac = c.get("/facilities?lat=5.55&lng=-0.21", headers=h("pat")).json()
    assert fac[0]["name"] in ("Korle Bu Teaching Hospital", "Ridge Hospital") and "eta_minutes" in fac[0]
    body = {"hospital_id": S["hid"], "consent": False, "triage_level": "urgent", "complaint": "Chest pain"}
    assert c.post("/referrals", headers=h("pat"), json=body).status_code == 400
    body.update(consent=True, allergies=["Penicillin"], age=54, sex="F", latitude=5.55, longitude=-0.21,
                vitals={"heart_rate": 118})
    r = c.post("/referrals", headers=h("pat"), json=body)
    assert r.status_code == 200, r.text
    S["ref"] = r.json()["id"]
    assert c.post("/referrals", headers=h("pat"), json=body).status_code == 409  # one open at a time
    # hospital 2 cannot see it
    assert c.get(f"/portal/referrals/{S['ref']}", headers=h("boss2")).status_code == 404
    dash = c.get("/portal/dashboard", headers=h("nurse")).json()
    assert dash["counts"]["incoming"] == 1 and dash["counts"]["incoming_urgent"] == 1
    assert any(a["kind"] == "referral" for a in c.get("/portal/alerts", headers=h("nurse")).json())
    acc = c.post(f"/portal/referrals/{S['ref']}/accept", headers=h("nurse"),
                 json={"assignee_uid": "doc-uid", "ward_id": S["ward"], "bed": "Bay 2"})
    assert acc.status_code == 200, acc.text
    case = acc.json()["case"]
    S["case"] = case["id"]
    assert case["assignee_name"] == "Dr Addo" and case["ward_name"] == "Emergency" and case["allergies"] == "Penicillin"
    mine = c.get("/referrals/mine", headers=h("pat")).json()[0]
    assert mine["status"] == "accepted" and mine["case"]["assignee_name"] == "Dr Addo"
    assert c.post(f"/portal/referrals/{S['ref']}/accept", headers=h("nurse"), json={}).status_code == 409
    beds = c.get("/portal/capacity", headers=h("doc")).json()["wards"][0]
    assert beds["beds_occupied"] == 1


def test_case_lifecycle():
    cid = S["case"]
    assert c.patch(f"/portal/cases/{cid}", headers=h("doc"), json={"status": "treatment"}).json()["status"] == "treatment"
    note = c.post(f"/portal/cases/{cid}/notes", headers=h("doc"), json={"text": "ECG done, troponin sent"}).json()
    assert any(e["kind"] == "note" for e in note["timeline"])
    assert c.get(f"/portal/cases/{cid}", headers=h("boss2")).status_code == 404
    walk = c.post("/portal/cases", headers=h("nurse"), json={
        "patient_name": "Kofi", "complaint": "Cut hand", "level": "routine", "ward_id": S["ward"]})
    assert walk.status_code == 200
    # ward full now (2/2)
    full = c.post("/portal/cases", headers=h("nurse"), json={
        "patient_name": "Esi", "complaint": "Fever", "level": "doctor", "ward_id": S["ward"]})
    assert full.status_code == 409
    d = c.post(f"/portal/cases/{cid}/discharge", headers=h("doc"), json={"summary": "Stable, follow up in clinic"})
    assert d.json()["status"] == "discharged" and d.json()["ward_id"] is None
    assert c.get("/portal/capacity", headers=h("doc")).json()["wards"][0]["beds_occupied"] == 1
    assert c.get("/referrals/mine", headers=h("pat")).json()[0]["status"] == "arrived"


def test_decline_and_audit():
    r = c.post("/referrals", headers=h("pat"), json={
        "hospital_id": S["hid"], "consent": True, "triage_level": "doctor", "complaint": "Ankle pain"}).json()
    d = c.post(f"/portal/referrals/{r['id']}/decline", headers=h("nurse"), json={"reason": "No orthopaedics today"})
    assert d.json()["status"] == "declined"
    assert c.get("/referrals/mine", headers=h("pat")).json()[0]["decline_reason"] == "No orthopaedics today"
    log = c.get("/portal/audit", headers=h("boss")).json()
    actions = {a["action"] for a in log}
    assert {"facility.create", "referral.accept", "referral.decline", "case.discharge"} <= actions
    assert c.get("/portal/audit", headers=h("doc")).status_code == 403


def test_capacity_permissions():
    w = S["ward"]
    # nurse can change occupancy but not resize
    assert c.put(f"/portal/wards/{w}", headers=h("nurse"),
                 json={"name": "Emergency", "beds_total": 2, "beds_occupied": 2, "critical": True}).status_code == 200
    assert c.put(f"/portal/wards/{w}", headers=h("nurse"),
                 json={"name": "Emergency", "beds_total": 9, "beds_occupied": 2, "critical": True}).status_code == 403
    assert c.post("/portal/wards", headers=h("nurse"), json={"name": "X", "beds_total": 1}).status_code == 403
    prof = c.put("/portal/me/profile", headers=h("nurse"),
                 json={"full_name": "Nurse Joy Mensah", "department": "Emergency"}).json()
    assert prof["full_name"] == "Nurse Joy Mensah" and prof["role"] == "nurse"
    found = c.get("/facilities?q=korle", headers=h("pat")).json()
    assert [f["name"] for f in found] == ["Korle Bu Teaching Hospital"]
    duty = c.put("/portal/me/duty", headers=h("nurse"), json={"on_duty": True}).json()
    assert duty["on_duty"] is True
    assert c.get("/portal/dashboard", headers=h("boss")).json()["counts"]["staff_on_duty"] == 1


def test_portal_extended_features():
    # 1. Prescriptions and vitals on an active case
    c_new = c.post("/portal/cases", headers=h("doc"), json={
        "patient_name": "Adjoa Mensah", "complaint": "Bacterial pneumonia", "level": "urgent"
    })
    assert c_new.status_code == 200, c_new.text
    cid = c_new.json()["id"]

    rx = c.post(f"/portal/cases/{cid}/prescriptions", headers=h("doc"), json={
        "medication": "Amoxicillin", "dosage": "500mg", "frequency": "TID", "duration": "7 days", "instructions": "Take with meals"
    })
    assert rx.status_code == 200, rx.text
    assert any(e["kind"] == "prescription" for e in rx.json()["timeline"])

    vitals = c.post(f"/portal/cases/{cid}/vitals", headers=h("nurse"), json={
        "heart_rate": 82, "blood_oxygen": 98.0, "blood_pressure": "120/80", "temperature": 36.8, "respiratory_rate": 16
    })
    assert vitals.status_code == 200, vitals.text
    assert any(e["kind"] == "vitals" for e in vitals.json()["timeline"])

    # 2. Staff broadcast alert
    bc = c.post("/portal/alerts", headers=h("boss"), json={
        "title": "Trauma Ward Surge", "message": "High influx of trauma admissions; prep OR 2.", "severity": "urgent", "department": "Trauma"
    })
    assert bc.status_code == 200, bc.text
    alerts = c.get("/portal/alerts", headers=h("doc")).json()
    assert any(a["title"] == "Trauma Ward Surge" for a in alerts)

    # 3. Direct Emergency Pre-Arrival Checkin
    chk = c.post(f"/facilities/{S['hid']}/emergency-checkin", headers=h("pat"), json={
        "complaint": "Acute severe shortness of breath", "vitals": {"blood_oxygen": 88, "heart_rate": 125},
        "patient_lat": 5.54, "patient_lng": -0.22
    })
    assert chk.status_code == 200, chk.text
    assert chk.json()["triage_level"] == "urgent" and chk.json()["status"] == "new"

    # 4. Patient cases endpoint (inpatient & discharge history)
    pat_cases = c.get("/patient/cases", headers=h("pat")).json()
    assert len(pat_cases) >= 1
    assert any("hospital_name" in pc for pc in pat_cases)

    # 5. Facility capacity in list_facilities
    fac = c.get("/facilities?lat=5.55&lng=-0.21", headers=h("pat")).json()
    assert "beds_total" in fac[0] and "beds_free" in fac[0]
