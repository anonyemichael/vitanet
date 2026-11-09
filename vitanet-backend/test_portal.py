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
    "pat2": ("pat2-uid", "pat2@example.com", "Yaw Patient"),
    "doc2": ("doc2-uid", "doc2@example.com", "Dr Two"),
    "doc3": ("doc3-uid", "doc3@example.com", "Dr Three"),
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
    case = c.get(f"/portal/cases/{cid}", headers=h("doc")).json()
    assert case["status"] == "expected" and case["arrived_at"] is None
    arr = c.post(f"/portal/cases/{cid}/arrived", headers=h("nurse"))
    assert arr.status_code == 200 and arr.json()["status"] == "waiting" and arr.json()["arrived_at"]
    assert c.post(f"/portal/cases/{cid}/arrived", headers=h("nurse")).status_code == 409
    assert c.get("/referrals/mine", headers=h("pat")).json()[0]["status"] == "arrived"
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
    assert c.post(f"/portal/cases/{cid}/discharge", headers=h("doc"),
                  json={"summary": "Stable", "outcome": "somewhere"}).status_code == 400
    d = c.post(f"/portal/cases/{cid}/discharge", headers=h("doc"),
               json={"summary": "Stable, follow up in clinic", "outcome": "home"})
    assert d.json()["status"] == "discharged" and d.json()["ward_id"] is None and d.json()["outcome"] == "home"
    assert c.get("/portal/capacity", headers=h("doc")).json()["wards"][0]["beds_occupied"] == 1
    mine = c.get("/referrals/mine", headers=h("pat")).json()[0]
    assert mine["status"] == "closed" and mine["case"]["outcome"] == "home"


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
    # occupancy follows patients; only an admin can correct or resize a ward
    assert c.put(f"/portal/wards/{w}", headers=h("nurse"),
                 json={"name": "Emergency", "beds_total": 2, "beds_occupied": 2, "critical": True}).status_code == 403
    fixed = c.put(f"/portal/wards/{w}", headers=h("boss"),
                  json={"name": "Emergency", "beds_total": 3, "beds_occupied": 1, "critical": True})
    assert fixed.status_code == 200 and fixed.json()["patients"] == ["Kofi"]
    assert any(a["action"] == "ward.update" and "→" in (a["detail"] or "")
               for a in c.get("/portal/audit", headers=h("boss")).json())
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
    assert bc.status_code == 400  # unknown severity is refused, not silently changed
    bc = c.post("/portal/alerts", headers=h("boss"), json={
        "title": "Trauma Ward Surge", "message": "High influx of trauma admissions; prep OR 2.", "severity": "critical", "department": "Trauma"
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
    assert chk.json()["source"] == "checkin" and chk.json()["eta_minutes"] is not None and chk.json()["eta_at"]
    # never fills in the account name the patient didn't choose to share
    assert chk.json()["summary"]["patient_name"] == "Name not shared"
    S["checkin"] = chk.json()["id"]

    # 4. Patient cases endpoint (inpatient & discharge history)
    pat_cases = c.get("/patient/cases", headers=h("pat")).json()
    assert len(pat_cases) >= 1
    assert any("hospital_name" in pc for pc in pat_cases)

    # 5. Facility capacity in list_facilities
    fac = c.get("/facilities?lat=5.55&lng=-0.21", headers=h("pat")).json()
    assert "beds_total" in fac[0] and "beds_free" in fac[0]


def test_vitals_tiles_and_early_warning_alert():
    case = c.post("/portal/cases", headers=h("nurse"), json={
        "patient_name": "Kwame Mensah", "complaint": "Short of breath", "level": "urgent"}).json()
    S["sick"] = case["id"]
    assert c.post(f"/portal/cases/{case['id']}/vitals", headers=h("nurse"), json={}).status_code == 400
    calm = c.post(f"/portal/cases/{case['id']}/vitals", headers=h("nurse"), json={
        "heart_rate": 80, "blood_oxygen": 98, "respiratory_rate": 16, "temperature": 36.8, "bp_systolic": 125,
        "bp_diastolic": 80}).json()
    assert calm["latest_vitals"]["early_warning"] == 0 and calm["latest_vitals"]["bp_systolic"] == 125
    bad = c.post(f"/portal/cases/{case['id']}/vitals", headers=h("nurse"), json={
        "heart_rate": 124, "blood_oxygen": 91, "respiratory_rate": 26, "blood_pressure": "98/60", "pain": 6}).json()
    lv = bad["latest_vitals"]
    assert (lv["heart_rate"], lv["bp_systolic"], lv["bp_diastolic"], lv["pain"]) == (124, 98, 60, 6)
    assert lv["early_warning"] >= 7
    assert any(e["kind"] == "warning" for e in bad["timeline"])
    full = c.get(f"/portal/cases/{case['id']}", headers=h("doc")).json()
    assert len(full["vitals_history"]) == 2 and full["vitals_history"][0]["heart_rate"] == 124
    listed = next(x for x in c.get("/portal/cases?status=waiting,treatment", headers=h("doc")).json() if x["id"] == case["id"])
    assert listed["latest_vitals"]["early_warning"] == lv["early_warning"]
    ews = [a for a in c.get("/portal/alerts", headers=h("doc")).json() if a["kind"] == "early_warning"]
    assert ews and ews[0]["case_id"] == case["id"] and ews[0]["severity"] == "critical"
    S["ews"] = ews[0]["id"]


def test_alert_acknowledge():
    key = S["ews"]
    first = c.post(f"/portal/alerts/{key}/ack", headers=h("doc")).json()
    assert first["acked_by_me"] and first["ack_count"] == 1 and first["ack_names"] == ["Dr Addo"]
    again = c.post(f"/portal/alerts/{key}/ack", headers=h("doc")).json()
    assert again["ack_count"] == 1  # idempotent
    seen = next(a for a in c.get("/portal/alerts", headers=h("nurse")).json() if a["id"] == key)
    assert seen["ack_count"] == 1 and seen["acked_by_me"] is False
    assert c.post("/portal/alerts/ews-999999/ack", headers=h("doc")).status_code == 404
    assert c.post(f"/portal/alerts/{key}/ack", headers=h("boss2")).status_code == 404  # other hospital


def test_suggestion_allergy_guard_and_accepting_switch():
    c.post("/portal/wards", headers=h("boss"), json={"name": "Resus", "beds_total": 2, "critical": True})
    c.put("/portal/me/duty", headers=h("doc"), json={"on_duty": True})
    ref = c.get(f"/portal/referrals/{S['checkin']}", headers=h("nurse")).json()
    sug = ref["suggestion"]
    assert sug["ward_name"] == "Resus" and sug["assignee_uid"] == "doc-uid"
    acc = c.post(f"/portal/referrals/{S['checkin']}/accept", headers=h("nurse"),
                 json={"ward_id": sug["ward_id"], "assignee_uid": sug["assignee_uid"]}).json()
    assert acc["case"]["status"] == "expected" and acc["case"]["ward_name"] == "Resus"
    # a recorded allergy blocks a matching prescription
    walk = c.post("/portal/cases", headers=h("doc"), json={
        "patient_name": "Esi", "complaint": "Sore throat", "level": "routine", "allergies": "Penicillin, Sulfa"}).json()
    rx = c.post(f"/portal/cases/{walk['id']}/prescriptions", headers=h("doc"), json={
        "medication": "Penicillin V", "dosage": "500 mg", "frequency": "QDS", "duration": "10 days"})
    assert rx.status_code == 409 and "allergic" in rx.json()["detail"]
    # admin pauses referrals; patients can't send new ones
    assert c.put("/portal/hospital/accepting", headers=h("nurse"), json={"accepting_referrals": False}).status_code == 403
    off = c.put("/portal/hospital/accepting", headers=h("boss"), json={"accepting_referrals": False}).json()
    assert off["accepting_referrals"] is False
    assert c.get("/portal/dashboard", headers=h("doc")).json()["accepting_referrals"] is False
    blocked = c.post("/referrals", headers=h("pat2"), json={
        "hospital_id": S["hid"], "consent": True, "triage_level": "doctor", "complaint": "Rash"})
    assert blocked.status_code == 409
    c.put("/portal/hospital/accepting", headers=h("boss"), json={"accepting_referrals": True})


def test_handover_moves_my_patients():
    c.patch(f"/portal/cases/{S['sick']}", headers=h("nurse"), json={"assignee_uid": "doc-uid"})
    before = [x for x in c.get("/portal/cases?mine=true&status=expected,waiting,treatment", headers=h("doc")).json()]
    assert len(before) >= 2
    assert c.post("/portal/handover", headers=h("doc"), json={"to_uid": "doc-uid"}).status_code == 400
    r = c.post("/portal/handover", headers=h("doc"), json={"to_uid": "nurse-uid", "note": "Kwame needs obs every 30 min"})
    assert r.status_code == 200 and r.json()["handed_over"] == len(before)
    assert c.get("/portal/cases?mine=true&status=expected,waiting,treatment", headers=h("doc")).json() == []
    sick = c.get(f"/portal/cases/{S['sick']}", headers=h("nurse")).json()
    assert sick["assignee_uid"] == "nurse-uid" and "obs every 30 min" in sick["timeline"][-1]["text"]
    team = {m["firebase_uid"]: m for m in c.get("/portal/capacity", headers=h("nurse")).json()["team"]}
    assert team["doc-uid"]["on_duty"] is False and team["nurse-uid"]["active_cases"] >= 2


def test_staff_lifecycle_guards():
    # the only admin can't be demoted or suspended by anyone
    c.post("/staff/register", headers=h("doc2"), json={"full_name": "Dr Two", "role": "doctor", "hospital_id": S["hid"]})
    assert c.post("/admin/staff-requests/doc2-uid/approve", headers=h("boss"), json={"role": "admin"}).status_code == 200
    assert c.post("/admin/staff-requests/boss-uid/role", headers=h("doc2"), json={"role": "doctor"}).status_code == 200
    assert c.post("/admin/staff-requests/doc2-uid/suspend", headers=h("boss")).status_code == 403  # boss is a doctor now
    assert c.post("/admin/staff-requests/boss-uid/role", headers=h("doc2"), json={"role": "admin"}).status_code == 200
    assert c.post("/admin/staff-requests/doc2-uid/suspend", headers=h("boss")).status_code == 200
    # admins can manage each other, but nobody can act on their own account
    c.post("/staff/register", headers=h("doc3"), json={"full_name": "Dr Three", "role": "admin", "hospital_id": S["hid"]})
    assert c.post("/admin/staff-requests/doc3-uid/approve", headers=h("boss")).status_code == 200
    assert c.post("/admin/staff-requests/boss-uid/suspend", headers=h("doc3")).status_code == 200
    assert c.post("/admin/staff-requests/doc3-uid/suspend", headers=h("doc3")).status_code == 400  # not yourself
    c.post("/admin/staff-requests/boss-uid/reinstate", headers=h("doc3"))
    assert c.post("/admin/staff-requests/doc3-uid/role", headers=h("boss"), json={"role": "nurse"}).status_code == 200
    assert c.post("/admin/staff-requests/boss-uid/role", headers=h("boss"), json={"role": "nurse"}).status_code == 400
    # suspended staff can't escape by joining another hospital
    moved = c.post("/staff/register", headers=h("doc2"), json={"full_name": "Dr Two", "role": "doctor", "hospital_id": S["hid2"]})
    assert moved.status_code == 409
    assert c.post("/admin/staff-requests/doc2-uid/reinstate", headers=h("boss")).json()["status"] == "approved"
    assert c.post("/admin/staff-requests/doc2-uid/reinstate", headers=h("boss")).status_code == 409


def test_live_socket_auth_and_events():
    with c.websocket_connect("/portal/ws") as ws:
        ws.send_json({"token": "pat"})  # a patient, not staff
        try:
            ws.receive_json()
            assert False, "patient socket should close"
        except Exception:
            pass
    with c.websocket_connect("/portal/ws") as ws:
        ws.send_json({"token": "nurse"})
        assert ws.receive_json() == {"type": "ready"}
        r = c.post("/referrals", headers=h("pat2"), json={
            "hospital_id": S["hid"], "consent": True, "triage_level": "urgent", "complaint": "Seizure"})
        assert r.status_code == 200, r.text
        got = [ws.receive_json(), ws.receive_json()]
        assert {"type": "referral", "id": r.json()["id"]} in got and {"type": "alert", "id": r.json()["id"]} in got
