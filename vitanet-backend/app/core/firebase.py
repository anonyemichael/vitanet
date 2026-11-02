# app/core/firebase.py
import os
import firebase_admin
from firebase_admin import credentials

_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")  # optional service account JSON
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "vitanet-62e40")

if not firebase_admin._apps:
    try:
        if _cred_path and os.path.exists(_cred_path):
            firebase_admin.initialize_app(credentials.Certificate(_cred_path))
        else:
            # ID-token verification only needs the project ID (Google's public
            # signing keys are fetched over HTTPS), so no service account is
            # required for authenticating app users.
            firebase_admin.initialize_app(options={"projectId": FIREBASE_PROJECT_ID})
    except Exception as e:
        print(f"[FIREBASE NOTICE] Firebase Admin initialisation failed ({e})")
