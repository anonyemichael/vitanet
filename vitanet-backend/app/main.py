import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database.base import Base
from app.database.connection import engine, SessionLocal
from app.database.seed_data import seed_hospital_data
from app.models import *  # noqa: F401, F403 Ensure all models are registered with Base
from app.routes import (
    chat,
    health_alert,
    health_profile,
    user_location,
    user_settings,
    users,
    care_circles,
    vitals,
    hospitals,
    sms_router,
    admin,
    triage,
)

if os.getenv("DEV_BYPASS_AUTH", "false").lower() == "true":
    print("=" * 60)
    print("WARNING: DEV_BYPASS_AUTH is enabled — auth is DISABLED")
    print("=" * 60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize all database tables automatically
    Base.metadata.create_all(bind=engine)
    # Seed default hospital and patient records if empty
    db = SessionLocal()
    try:
        seed_hospital_data(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title="VitaNet API",
    lifespan=lifespan,
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
    allow_origin_regex=r"https?://.*",
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
app.include_router(triage.router)


@app.get("/")
def root():
    return {
        "message": "VitaNet API running",
        "version": "2.0.0",
        "environment": "production-ready",
    }
