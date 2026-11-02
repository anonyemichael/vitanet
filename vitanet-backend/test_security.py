"""Security tests: authentication, ownership, staff approval, CORS.

Run against a throwaway database:
    DATABASE_URL=sqlite:///./security_test.db BOOTSTRAP_ADMIN_EMAILS=boss@example.com \
        python -m pytest -q test_security.py
"""
import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./security_test.db")
os.environ.setdefault("BOOTSTRAP_ADMIN_EMAILS", "boss@example.com")
os.environ["ENVIRONMENT"] = "production"
os.environ["DEV_BYPASS_AUTH"] = "true"  # must be ignored in production

from fastapi.testclient import TestClient  # noqa: E402

from app.dependencies import security  # noqa: E402
from app.main import app  # noqa: E402

USERS = {
    "tok-alice": security.CurrentUser(uid="alice-uid", email="alice@example.com", email_verified=True),
    "tok-bob": security.CurrentUser(uid="bob-uid", email="bob@example.com", email_verified=True),
    "tok-nurse": security.CurrentUser(uid="nurse-uid", email="nurse@example.com", email_verified=True, name="Nurse Joy"),
    "tok-boss": security.CurrentUser(uid="boss-uid", email="boss@example.com", email_verified=True, name="Boss"),
    "tok-fakeboss": security.CurrentUser(uid="fake-uid", email="boss@example.com", email_verified=False),
    "tok-anon": security.CurrentUser(uid="anon-uid", anonymous=True),
}


def fake_verify(token):
    user = USERS.get(token)
    if user is None:
        raise ValueError("bad token")
    return {
        "sub": user.uid,
        "email": user.email,
        "email_verified": user.email_verified,
        "name": user.name,
        "firebase": {"sign_in_provider": "anonymous" if user.anonymous else "password"},
    }


security.verify_firebase_id_token = fake_verify
client = TestClient(app)
client.__enter__()  # run the lifespan so tables are created in the test DB


def h(tok):
    return {"Authorization": f"Bearer {tok}"}


def test_bypass_ignored_in_production():
    assert security.DEV_BYPASS_AUTH is False


def test_requires_token():
    for method, path in [
        ("get", "/vitals/alice-uid/latest"),
        ("get", "/admin/stats"),
        ("get", "/admin/patients"),
        ("get", "/triage/symptoms"),
        ("post", "/ai/chat/completions"),
    ]:
        r = getattr(client, method)(path)
        assert r.status_code == 401, (path, r.status_code)
    assert client.get("/vitals/alice-uid/latest", headers=h("garbage")).status_code == 401


def test_public_routes_stay_public():
    assert client.get("/").status_code == 200


def test_new_user_gets_own_empty_vitals_not_demo():
    r = client.get("/vitals/alice-uid/latest", headers=h("tok-alice"))
    assert r.status_code == 200
    assert all(v is None for v in r.json().values()), r.json()


def test_user_can_write_and_read_own_vitals():
    r = client.post("/vitals/alice-uid", headers=h("tok-alice"),
                    json={"vital_type": "heart_rate", "value": 71.0, "source": "device"})
    assert r.status_code == 200, r.text
    latest = client.get("/vitals/alice-uid/latest", headers=h("tok-alice")).json()
    assert latest["heart_rate"]["value"] == 71.0


def test_cannot_access_someone_else():
    # by firebase uid
    assert client.get("/vitals/alice-uid/latest", headers=h("tok-bob")).status_code == 403
    # by backend uuid
    alice_id = client.get("/users/firebase/alice-uid", headers=h("tok-alice")).json()["id"]
    assert client.get(f"/users/{alice_id}", headers=h("tok-bob")).status_code == 403
    assert client.get(f"/health-profile/{alice_id}", headers=h("tok-bob")).status_code == 403
    assert client.get("/users/firebase/alice-uid", headers=h("tok-bob")).status_code == 403
    # the old shared demo account is not reachable by others either
    assert client.get("/vitals/00000000-0000-0000-0000-000000000001/latest",
                      headers=h("tok-bob")).status_code in (403, 404)


def test_staff_needs_approval():
    assert client.get("/admin/stats", headers=h("tok-nurse")).status_code == 403
    r = client.post("/staff/register", headers=h("tok-nurse"),
                    json={"full_name": "Nurse Joy", "role": "admin"})
    assert r.status_code == 200 and r.json()["status"] == "pending"
    # self-requested "admin" grants nothing until approved
    assert client.get("/admin/stats", headers=h("tok-nurse")).status_code == 403
    assert client.get("/admin/staff-requests", headers=h("tok-nurse")).status_code == 403


def test_anonymous_cannot_register_as_staff():
    r = client.post("/staff/register", headers=h("tok-anon"), json={"full_name": "Anon"})
    assert r.status_code == 400


def test_unverified_bootstrap_email_is_not_admin():
    r = client.post("/staff/register", headers=h("tok-fakeboss"), json={"full_name": "Fake"})
    assert r.json()["status"] == "pending"
    assert client.get("/admin/stats", headers=h("tok-fakeboss")).status_code == 403


def test_bootstrap_admin_approves_staff():
    me = client.get("/staff/me", headers=h("tok-boss"))
    assert me.status_code == 200 and me.json()["status"] == "approved" and me.json()["role"] == "admin"
    assert client.get("/admin/stats", headers=h("tok-boss")).status_code == 200
    pending = client.get("/admin/staff-requests?status=pending", headers=h("tok-boss")).json()
    assert any(p["firebase_uid"] == "nurse-uid" for p in pending)
    r = client.post("/admin/staff-requests/nurse-uid/approve", headers=h("tok-boss"), json={"role": "nurse"})
    assert r.status_code == 200 and r.json()["status"] == "approved" and r.json()["role"] == "nurse"
    assert client.get("/admin/stats", headers=h("tok-nurse")).status_code == 200
    # a nurse can't approve others
    assert client.get("/admin/staff-requests", headers=h("tok-nurse")).status_code == 403
    # an admin can't approve themselves
    assert client.post("/admin/staff-requests/boss-uid/approve", headers=h("tok-boss")).status_code == 400


def test_cors_only_vitanet_origins():
    def preflight(origin):
        return client.options("/admin/stats", headers={
            "Origin": origin, "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization"})
    assert preflight("https://evil.example.com").headers.get("access-control-allow-origin") is None
    for ok in ["https://vitanet-62e40.web.app",
               "https://vitanet-62e40--staging-f24f9y82.web.app",
               "http://localhost:5000"]:
        assert preflight(ok).headers.get("access-control-allow-origin") == ok, ok
