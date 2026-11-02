# app/core/firebase.py
import os
import firebase_admin
from firebase_admin import credentials

_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")  # path to service account JSON

if not firebase_admin._apps:
    try:
        if _cred_path and os.path.exists(_cred_path):
            cred = credentials.Certificate(_cred_path)
            firebase_admin.initialize_app(cred)
        else:
            firebase_admin.initialize_app()
    except Exception as e:
        print(f"[FIREBASE NOTICE] Backend running without Firebase Admin credentials ({e})")
