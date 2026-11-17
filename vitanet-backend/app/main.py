import asyncio
import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database.connection import engine, SessionLocal
from app.database.schema_sync import sync_schema
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
    triage,
    staff,
    ai_proxy,
    portal,
    portal_ai,
    portal_live,
    media_proxy,
    videos,
    library,
    internal,
)
from app.dependencies.security import DEV_BYPASS_AUTH

if DEV_BYPASS_AUTH:
    print("=" * 60)
    print("WARNING: DEV_BYPASS_AUTH is enabled - auth is DISABLED (non-production only)")
    print("=" * 60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create missing tables and add columns newer than the database.
    with engine.begin() as conn:
        sync_schema(conn)
    # Seed default hospital and patient records if empty
    db = SessionLocal()
    try:
        seed_hospital_data(db)
    finally:
        db.close()
    sweeper = asyncio.create_task(_alert_sweeper())
    # health videos: load the saved copy and refresh it from YouTube in the background when it is old
    from app.services import video_service
    asyncio.create_task(asyncio.to_thread(video_service.refresh_if_stale))
    # health library: same idea, rebuilt daily from MedlinePlus and MyHealthfinder
    from app.services import library_service
    asyncio.create_task(asyncio.to_thread(library_service.refresh_if_stale))
    yield
    sweeper.cancel()


def _escalate_due_alerts() -> None:
    from app.services import health_alert_service
    db = SessionLocal()
    try:
        health_alert_service.escalate_due(db)
    finally:
        db.close()


async def _alert_sweeper():
    """Every minute: urgent health alerts nobody answered in time go to the care circle (SMS / email)."""
    while True:
        try:
            await asyncio.to_thread(_escalate_due_alerts)
        except Exception:
            logging.getLogger(__name__).exception("Alert sweeper failed")
        await asyncio.sleep(60)


app = FastAPI(
    title="VitaNet API",
    lifespan=lifespan,
)

# Browsers may only call the API from the VitaNet web app (live site and
# Firebase preview channels) or local development. Mobile apps aren't affected
# by CORS. Auth uses bearer tokens, so cookies/credentials are not needed.
_extra_origins = [
    o.strip()
    for o in os.getenv("ALLOWED_ORIGINS", "").split(",")
    if o.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://vitanet-prod-gh.web.app",
        "https://vitanet-prod-gh.firebaseapp.com",
        "https://vitanet-62e40.web.app",
        "https://vitanet-62e40.firebaseapp.com",
        *_extra_origins,
    ],
    allow_origin_regex=(
        r"https://vitanet-(?:prod-gh|62e40)--[a-z0-9-]+\.web\.app"
        r"|http://(localhost|127\.0\.0\.1)(:\d+)?"
    ),
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
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
app.include_router(triage.router)
app.include_router(staff.router)
app.include_router(ai_proxy.router)
app.include_router(portal.router)
app.include_router(portal_ai.router)
app.include_router(portal_live.router)
app.include_router(media_proxy.router)
app.include_router(videos.router)
app.include_router(library.router)
app.include_router(internal.router)


@app.get("/")
def root():
    return {
        "message": "VitaNet API running",
        "version": "2.0.0",
        "environment": "production-ready",
    }
