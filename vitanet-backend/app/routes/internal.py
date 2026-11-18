# app/routes/internal.py
"""POST /internal/tick?token=...: run the background jobs once.

On a server that is always on, the alert sweeper in app/main.py runs every minute by itself. On a host that pauses
the server between requests (Google Cloud Run without "CPU always allocated"), a free scheduler (Cloud Scheduler)
calls this every minute instead, so urgent alerts still reach the care circle on time and the video / library
copies stay fresh. Off unless TICK_TOKEN is set."""
import hmac

from fastapi import APIRouter, HTTPException, Query

from app.core.config import settings
from app.database.connection import SessionLocal
from app.services import health_alert_service, library_service, video_service

router = APIRouter(prefix="/internal", tags=["internal"])


@router.post("/tick")
def tick(token: str = Query("")):
    if not settings.TICK_TOKEN or not hmac.compare_digest(token, settings.TICK_TOKEN):
        raise HTTPException(status_code=403, detail="Not allowed")
    db = SessionLocal()
    try:
        escalated = health_alert_service.escalate_due(db)
    finally:
        db.close()
    video_service._ensure_fresh_in_background()     # both only start a refresh when their copy is old
    library_service._ensure_fresh_in_background()
    return {"escalated": escalated}
