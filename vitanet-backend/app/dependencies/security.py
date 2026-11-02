# app/dependencies/security.py
"""Authentication and authorisation for every API route.

* `get_current_user`  – verifies the Firebase ID token in `Authorization: Bearer`.
* `owned_user_id`     – resolves a path `{user_id}` (backend UUID or Firebase UID)
                        and guarantees it belongs to the caller. Unknown callers
                        get their own user row; nobody is ever mapped onto another
                        account (the old demo-user fallback is gone).
* `require_staff` / `require_admin` – hospital portal access, decided only by the
                        backend `staff_accounts` table.
"""
import os
from dataclasses import dataclass
from typing import Optional
from uuid import UUID

import google.auth.transport.requests
from fastapi import Depends, Header, HTTPException, status
from google.oauth2 import id_token as google_id_token
from sqlalchemy.orm import Session

from app.core.firebase import FIREBASE_PROJECT_ID
from app.database.connection import get_db
from app.enums import AccountType
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus
from app.models.user import User

ENVIRONMENT = os.getenv("ENVIRONMENT", "production").lower()
# The bypass can never be active in production, whatever the env var says.
DEV_BYPASS_AUTH = (
    os.getenv("DEV_BYPASS_AUTH", "false").lower() == "true" and ENVIRONMENT != "production"
)
DEV_TEST_UID = "dev-test-uid"

BOOTSTRAP_ADMIN_EMAILS = {
    e.strip().lower()
    for e in os.getenv("BOOTSTRAP_ADMIN_EMAILS", "").split(",")
    if e.strip()
}


_google_request = google.auth.transport.requests.Request()


def verify_firebase_id_token(token: str) -> dict:
    """Verify a Firebase ID token's signature, expiry, issuer and audience
    against Google's public keys. Needs no service-account credentials."""
    claims = google_id_token.verify_firebase_token(
        token, _google_request, audience=FIREBASE_PROJECT_ID, clock_skew_in_seconds=10
    )
    if not claims or claims.get("iss") != f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}":
        raise ValueError("wrong issuer")
    if not claims.get("sub"):
        raise ValueError("missing subject")
    return claims


@dataclass
class CurrentUser:
    uid: str
    email: Optional[str] = None
    email_verified: bool = False
    name: Optional[str] = None
    anonymous: bool = False


def get_current_user(authorization: Optional[str] = Header(default=None)) -> CurrentUser:
    if DEV_BYPASS_AUTH:
        return CurrentUser(uid=DEV_TEST_UID, email="dev@vitanet.local", email_verified=True)

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sign in required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ", 1)[1].strip()
    try:
        decoded = verify_firebase_id_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired sign-in, please sign in again")

    provider = (decoded.get("firebase") or {}).get("sign_in_provider")
    return CurrentUser(
        uid=decoded["sub"],
        email=(decoded.get("email") or None),
        email_verified=bool(decoded.get("email_verified")),
        name=decoded.get("name"),
        anonymous=provider == "anonymous",
    )


def get_or_create_user(db: Session, current: CurrentUser) -> User:
    user = db.query(User).filter(User.firebase_uid == current.uid).first()
    if user:
        return user
    email = current.email
    if email and db.query(User).filter(User.email == email).first():
        email = None  # never collide with another account's unique email
    user = User(
        firebase_uid=current.uid,
        full_name=current.name or "VitaNet user",
        email=email,
        account_type=AccountType.PERSONAL_USER,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def resolve_owned_user_id(identifier: str, current: CurrentUser, db: Session) -> UUID:
    """Return the backend user UUID for `identifier`, only if it is the caller."""
    try:
        as_uuid = UUID(str(identifier))
    except ValueError:
        as_uuid = None

    if as_uuid is not None:
        user = db.query(User).filter(User.id == as_uuid).first()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        if user.firebase_uid != current.uid:
            raise HTTPException(status_code=403, detail="Not allowed")
        return user.id

    if identifier != current.uid:
        raise HTTPException(status_code=403, detail="Not allowed")
    return get_or_create_user(db, current).id


def owned_user_id(
    user_id: str,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UUID:
    return resolve_owned_user_id(user_id, current, db)


def current_user_id(
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UUID:
    return get_or_create_user(db, current).id


def _staff_for(db: Session, current: CurrentUser) -> Optional[StaffAccount]:
    return db.query(StaffAccount).filter(StaffAccount.firebase_uid == current.uid).first()


def require_staff(
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> StaffAccount:
    staff = _staff_for(db, current)
    if staff is None or staff.status != StaffStatus.APPROVED:
        raise HTTPException(status_code=403, detail="Approved hospital staff only")
    return staff


def require_admin(staff: StaffAccount = Depends(require_staff)) -> StaffAccount:
    if staff.role != StaffRole.ADMIN:
        raise HTTPException(status_code=403, detail="Hospital administrators only")
    return staff


def is_bootstrap_admin(current: CurrentUser) -> bool:
    return bool(
        current.email
        and current.email_verified
        and current.email.lower() in BOOTSTRAP_ADMIN_EMAILS
    )
