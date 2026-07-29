from fastapi import FastAPI



from app.routes import chat, health_alert, health_profile, user_location, user_settings, users, care_circles, vitals, hospitals, sms_router

import os
if os.getenv("DEV_BYPASS_AUTH", "false").lower() == "true":
    print("=" * 60)
    print("WARNING: DEV_BYPASS_AUTH is enabled — auth is DISABLED")
    print("=" * 60)

app = FastAPI(
    title="VitaNet API"
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

@app.get("/")
def root():
    return {
        "message": "VitaNet API running"
    }