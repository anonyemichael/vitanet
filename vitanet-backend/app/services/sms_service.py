# app/services/sms_service.py
"""VitaNet by SMS: people without internet text the short code, the VitaNet model answers by SMS.

Flow (app/routes/sms_router.py):
  Africa's Talking -> POST /sms/inbound -> handle_inbound() works out the reply -> send() texts it back.

What it does, in order:
  1. Keywords: STOP (no more replies), START (replies again), HELP (what this line is).
  2. Limit: at most SMS_MAX_PER_HOUR replies per number per hour (every SMS costs money).
  3. Memory: the last few messages from the same number in the last 24 h, stored under a keyed hash of the number
     (the number itself is never saved).
  4. The VitaNet model answers with its trained instructions plus "keep it short, this is SMS". No personal tools:
     an SMS number is not a verified VitaNet account.
  5. The safety layer puts a short danger-sign warning first when needed (also when the model is offline).
  6. The reply is cut at a sentence so it fits SMS_MAX_SEGMENTS parts.
"""
import hashlib
import hmac
import logging
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.sms import SmsContact, SmsMessage
from app.services import ai_client
from app.services.safety import SafetyLayer

logger = logging.getLogger(__name__)
safety = SafetyLayer()

SYSTEM = (Path(__file__).with_name("vitanet_system_prompt.txt").read_text(encoding="utf-8").strip()
          + "\n\nThis conversation is by SMS. Reply in plain text, at most 3 short sentences (under 300 characters), "
            "no lists, no links, no emoji. Ask one question at a time.")

# Short warnings for SMS (plain characters, so a reply stays a cheap 160-character-per-part message).
SMS_BANNERS = {
    "emergency": "URGENT: Go to the nearest hospital now or call 112 / ambulance 193.",
    "crisis": "Please talk to someone now: call 112 or go to the nearest hospital. You are not alone.",
}
OFFLINE = "VitaNet cannot answer right now. If you feel very unwell, go to the nearest hospital or call 112 / 193."
HELP = ("VitaNet health line: text your question in English or Twi and we reply. "
        "Not a doctor. Emergency: call 112 or 193. Text STOP to stop.")
STOPPED = "You will get no more VitaNet messages. Text START to use VitaNet again."
STARTED = "Welcome back to VitaNet. Text your health question. Emergency: call 112 or 193."
LIMIT = "You have reached the VitaNet message limit for now. Please try again in an hour. Emergency: call 112 or 193."

HISTORY_TURNS = 6


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)   # naive UTC, like the stored times

HISTORY_WINDOW = timedelta(hours=24)

# GSM 03.38 basic characters: a message made only of these costs 160 characters per part (153 when split).
# Anything else (e.g. Twi ɛ ɔ, emoji) switches the whole message to 70 per part (67 when split).
_GSM = set("@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§"
           "¿abcdefghijklmnopqrstuvwxyzäöñüà")
_GSM_EXT = set("^{}\\[~]|€")   # count as two characters


def normalize_phone(phone: str) -> str:
    """One spelling per number: "024 123 4567", "0241234567", "+233241234567" and "00233..." -> "+233241234567"
    (a leading 0 with 10 digits is a Ghana number)."""
    digits = re.sub(r"\D", "", phone or "")
    if digits.startswith("00"):
        digits = digits[2:]
    elif digits.startswith("0") and len(digits) == 10:
        digits = "233" + digits[1:]
    return f"+{digits}" if digits else ""


def phone_key(phone: str) -> str:
    """Keyed hash of a normalised phone number (the number itself is never stored)."""
    secret = (settings.SMS_HASH_SECRET or "vitanet-sms-dev-only").encode()
    return hmac.new(secret, normalize_phone(phone).encode(), hashlib.sha256).hexdigest()


def is_opted_out(db: Session, phone: str) -> bool:
    c = db.get(SmsContact, phone_key(phone))
    return bool(c and c.opted_out)


CARE_INVITE = ("{person} added you as a VitaNet health contact. If their readings are dangerous and they do not "
               "answer, we will text you. Reply YES to agree or NO to refuse.")
CARE_YES = "Thank you. You will get a text if {person} has a dangerous reading and does not answer. Text STOP to end."
CARE_NO = "OK, you will not get VitaNet alerts for {person}."


def _care_reply(db: Session, phone: str, word: str) -> Optional[str]:
    """YES / NO from a number someone added to their care circle: record the answer (pending invites only)."""
    from app.models.care_circle import CareCircle, CareCircleStatus
    from app.services.health_alert_service import _person
    me = normalize_phone(phone)
    pending = [c for c in db.query(CareCircle).filter(CareCircle.status == CareCircleStatus.PENDING,
                                                       CareCircle.contact_phone.isnot(None)).all()
               if normalize_phone(c.contact_phone) == me]
    if not pending:
        return None
    for c in pending:
        c.status = CareCircleStatus.ACCEPTED if word == "YES" else CareCircleStatus.REJECTED
    db.commit()
    person = _person(db, pending[0].requester_id)
    return (CARE_YES if word == "YES" else CARE_NO).format(person=person)


def sms_length(text: str) -> tuple[int, bool]:
    """(length as the network counts it, is_gsm)."""
    if all(c in _GSM or c in _GSM_EXT for c in text):
        return sum(2 if c in _GSM_EXT else 1 for c in text), True
    return len(text.encode("utf-16-le")) // 2, False


def max_chars(is_gsm: bool, parts: int) -> int:
    if parts <= 1:
        return 160 if is_gsm else 70
    return parts * (153 if is_gsm else 67)


def fit_sms(text: str, parts: Optional[int] = None) -> str:
    """Shorten to at most `parts` SMS parts, cutting at a sentence end where possible (the warning comes first,
    so it is never the part that is cut)."""
    parts = parts or settings.SMS_MAX_SEGMENTS
    text = re.sub(r"[*_#`]+", "", text or "")              # markdown has no meaning in an SMS
    text = re.sub(r"[ \t]*\n\s*", " ", text).strip()
    length, gsm = sms_length(text)
    limit = max_chars(gsm, parts)
    if length <= limit:
        return text
    sentences = re.split(r"(?<=[.!?])\s+", text)
    out = ""
    for s in sentences:
        candidate = f"{out} {s}".strip()
        if sms_length(candidate)[0] > limit:
            break
        out = candidate
    if not out:                                            # one very long sentence: cut at a word
        out = text
        while sms_length(out + "...")[0] > limit:
            out = out[: out.rfind(" ")] if " " in out else out[:-1]
        out += "..."
    return out


def _history(db: Session, key: str) -> list[dict]:
    since = _now() - HISTORY_WINDOW
    rows = (db.query(SmsMessage).filter(SmsMessage.phone_key == key, SmsMessage.created_at >= since)
            .order_by(SmsMessage.created_at.desc()).limit(HISTORY_TURNS).all())
    return [{"role": r.role, "content": r.text} for r in reversed(rows)]


def _replies_last_hour(db: Session, key: str) -> int:
    since = _now() - timedelta(hours=1)
    return (db.query(SmsMessage).filter(SmsMessage.phone_key == key, SmsMessage.role == "assistant",
                                        SmsMessage.created_at >= since).count())


def _contact(db: Session, key: str) -> SmsContact:
    c = db.get(SmsContact, key)
    if c is None:
        c = SmsContact(phone_key=key, opted_out=False)
        db.add(c)
    return c


def _ask_model(messages: list[dict]) -> Optional[str]:
    client = ai_client.get_client()
    if client is None:
        return None
    try:
        r = client.chat.completions.create(model=settings.AI_MODEL, messages=messages, temperature=0.2, max_tokens=220)
        return (r.choices[0].message.content or "").strip() or None
    except Exception as e:
        logger.warning("VitaNet model unavailable for SMS: %s", e)
        return None


def handle_inbound(db: Session, phone: str, text: str) -> Optional[str]:
    """The reply to send, or None when nothing should be sent (opted out, over the limit)."""
    text = (text or "").strip()[:1000]
    key = phone_key(phone)
    contact = _contact(db, key)
    word = text.upper().strip(" .!")

    if word in ("STOP", "UNSUBSCRIBE", "STOPALL"):
        contact.opted_out = True
        db.commit()
        return STOPPED
    if word in ("START", "UNSTOP"):
        contact.opted_out = False
        db.commit()
        return STARTED
    if contact.opted_out:
        db.commit()
        return None
    if word in ("YES", "NO", "Y", "N", "AANE", "DAABI", "DABI"):   # aane / daabi = yes / no in Twi
        answer = _care_reply(db, phone, "YES" if word in ("YES", "Y", "AANE") else "NO")
        if answer:
            return answer
    if word in ("HELP", "INFO", "?") or not text:
        db.commit()
        return HELP

    sent = _replies_last_hour(db, key)
    if sent > settings.SMS_MAX_PER_HOUR:
        db.commit()
        return None                                        # already told them about the limit
    if sent == settings.SMS_MAX_PER_HOUR:
        reply = safety.apply(text, LIMIT, banners=SMS_BANNERS)   # a danger sign still gets the warning
    else:
        history = _history(db, key)
        answer = _ask_model([{"role": "system", "content": SYSTEM}] + history + [{"role": "user", "content": text}])
        reply = safety.apply(text, answer or OFFLINE, banners=SMS_BANNERS)

    reply = fit_sms(reply)
    db.add(SmsMessage(phone_key=key, role="user", text=text))
    db.add(SmsMessage(phone_key=key, role="assistant", text=reply))
    db.commit()
    return reply


def send(phone: str, reply: str) -> bool:
    """Text the reply through Africa's Talking. False (and a log line) when SMS is not configured or fails."""
    if not settings.AT_API_KEY:
        logger.warning("SMS reply not sent: AT_API_KEY is not set")
        return False
    try:
        import africastalking
        africastalking.initialize(settings.AT_USERNAME, settings.AT_API_KEY)
        africastalking.SMS.send(reply, [normalize_phone(phone)], sender_id=settings.AT_SHORTCODE or None)
        return True
    except Exception as e:
        logger.warning("SMS send failed: %s", e)
        return False
