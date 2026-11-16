"""
app/routes/sms_router.py

VitaNet by SMS, through Africa's Talking (https://africastalking.com).

Flow:
1. Someone texts your short code (no internet needed).
2. Africa's Talking POSTs the message to /sms/inbound.
3. We answer "OK" at once, then app/services/sms_service.py works out the reply with the VitaNet model and the
   safety layer, and texts it back through Africa's Talking.

SETUP (server settings / .env, never in the code):
  AT_USERNAME        your Africa's Talking app username ("sandbox" for testing)
  AT_API_KEY         its API key
  AT_SHORTCODE       your short code or sender id
  SMS_WEBHOOK_TOKEN  a long random string; the callback URL is then https://<server>/sms/inbound?token=<it>
  SMS_HASH_SECRET    another long random string (phone numbers are stored only as a hash made with it)
Paste the callback URL into Africa's Talking: SMS -> Inbox callback URL (sandbox: account.africastalking.com/apps/
sandbox/sms/inbox/callback) and test with their simulator.
"""
import hmac
import logging

from fastapi import APIRouter, BackgroundTasks, HTTPException, Request

from app.core.config import settings
from app.database.connection import SessionLocal
from app.services import ai_client, sms_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sms", tags=["sms"])


def _reply_in_background(phone: str, text: str) -> None:
    db = SessionLocal()
    try:
        reply = sms_service.handle_inbound(db, phone, text)
    except Exception:
        logger.exception("SMS reply failed")
        db.rollback()
        reply = sms_service.fit_sms(sms_service.safety.apply(text, sms_service.OFFLINE, banners=sms_service.SMS_BANNERS))
    finally:
        db.close()
    if reply:
        sms_service.send(phone, reply)


@router.post("/inbound")
async def sms_inbound(request: Request, background_tasks: BackgroundTasks, token: str = ""):
    """Africa's Talking inbox callback (form fields: from, to, text, date, id, linkId)."""
    if settings.SMS_WEBHOOK_TOKEN and not hmac.compare_digest(token, settings.SMS_WEBHOOK_TOKEN):
        raise HTTPException(status_code=403, detail="Bad token")
    form = await request.form()
    phone, text = (form.get("from") or "").strip(), (form.get("text") or "")
    if not phone:
        return {"error": "Missing sender"}
    background_tasks.add_task(_reply_in_background, phone, text)   # Africa's Talking wants a quick answer
    return "OK"


@router.get("/health")
async def health_check():
    return {"status": "ok", "model_configured": ai_client.enabled(), "sms_configured": bool(settings.AT_API_KEY),
            "token_required": bool(settings.SMS_WEBHOOK_TOKEN)}
