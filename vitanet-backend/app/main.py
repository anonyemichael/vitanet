from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import re



from app.routes import chat, health_alert, health_profile, user_location, user_settings, users, care_circles, vitals, hospitals, sms_router, admin

import os
if os.getenv("DEV_BYPASS_AUTH", "false").lower() == "true":
    print("=" * 60)
    print("WARNING: DEV_BYPASS_AUTH is enabled — auth is DISABLED")
    print("=" * 60)

app = FastAPI(
    title="VitaNet API"
)

# Allow all localhost origins (any port) for Flutter web dev, plus any
# additional origins configured via the ALLOWED_ORIGINS env var.
_extra_origins = [
    o.strip()
    for o in os.getenv("ALLOWED_ORIGINS", "").split(",")
    if o.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        *_extra_origins,
    ],
    # Allow all localhost ports via regex pattern
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(users.router)
app.include_router(care_circles.router)
app.include_router(vitals.router)
app.include_router(health_profile.router)
app.include_router(user_location.router)
app.include_router(hospitals.router)
app.include_router(user_settings.router)
app.include_router(chat.router)
app.include_router(health_alert.router)
app.include_router(sms_router.router)
app.include_router(admin.router)

@app.get("/")
def root():
    return {
        "message": "VitaNet API running"
    }
