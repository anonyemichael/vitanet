# app/core/firebase.py
import firebase_admin
from firebase_admin import credentials
import os

_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")  # path to service account JSON

if not firebase_admin._apps:
    if _cred_path:
        cred = credentials.Certificate(_cred_path)
        firebase_admin.initialize_app(cred)
    else:
        # Falls back to Application Default Credentials
        # (useful on GCP/Cloud Run where ADC is auto-provided)
        firebase_admin.initialize_app()