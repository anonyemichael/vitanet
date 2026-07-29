# app/dependencies/auth.py
import os
from fastapi import Header, HTTPException, status
from firebase_admin import auth as firebase_auth

DEV_BYPASS_AUTH = os.getenv("DEV_BYPASS_AUTH", "false").lower() == "true"
DEV_TEST_UID = "test-uid-12345"


def get_firebase_uid(authorization: str = Header(default=None)) -> str:
    if DEV_BYPASS_AUTH:
        return DEV_TEST_UID

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
        )

    id_token = authorization.split(" ", 1)[1].strip()

    try:
        decoded_token = firebase_auth.verify_id_token(id_token)
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except firebase_auth.RevokedIdTokenError:
        raise HTTPException(status_code=401, detail="Token has been revoked")
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception:
        raise HTTPException(status_code=401, detail="Could not verify token")

    return decoded_token["uid"]