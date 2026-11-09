# app/routes/portal_live.py
"""WS /portal/ws: live "something changed" events for the caller's hospital.

Browsers can't set headers on a WebSocket, so the client sends its Firebase
ID token as the first message: {"token": "..."}. The server replies
{"type": "ready"} and then streams events like {"type": "referral", "id": "…"},
with {"type": "ping"} every 25 s to keep proxies from closing the socket."""
import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.database.connection import SessionLocal
from app.dependencies import security
from app.models.staff_account import StaffAccount, StaffStatus
from app.services.portal_events import hub

router = APIRouter(tags=["portal"])

PING_SECONDS = 25
AUTH_TIMEOUT_SECONDS = 10


def _hospital_for_token(token: str):
    if security.DEV_BYPASS_AUTH:
        uid = security.DEV_TEST_UID
    else:
        try:
            uid = security.verify_firebase_id_token(token)["sub"]
        except Exception:
            return None, 4401
    db = SessionLocal()
    try:
        staff = db.query(StaffAccount).filter(StaffAccount.firebase_uid == uid).first()
        if staff is None or staff.status != StaffStatus.APPROVED or staff.hospital_id is None:
            return None, 4403
        return staff.hospital_id, None
    finally:
        db.close()


@router.websocket("/portal/ws")
async def portal_ws(ws: WebSocket):
    await ws.accept()
    try:
        first = await asyncio.wait_for(ws.receive_text(), timeout=AUTH_TIMEOUT_SECONDS)
        token = (json.loads(first) or {}).get("token") or ""
    except (asyncio.TimeoutError, ValueError, AttributeError, WebSocketDisconnect):
        await _close(ws, 4401)
        return
    hospital_id, error = await asyncio.to_thread(_hospital_for_token, token)
    if error:
        await _close(ws, error)
        return

    queue = hub.subscribe(hospital_id)
    receiver = asyncio.create_task(_drain(ws))
    try:
        await ws.send_json({"type": "ready"})
        while not receiver.done():
            getter = asyncio.create_task(queue.get())
            done, _ = await asyncio.wait({getter, receiver}, timeout=PING_SECONDS,
                                         return_when=asyncio.FIRST_COMPLETED)
            if getter in done:
                await ws.send_json(getter.result())
            else:
                getter.cancel()
                if not receiver.done():
                    await ws.send_json({"type": "ping"})
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        receiver.cancel()
        hub.unsubscribe(hospital_id, queue)


async def _drain(ws: WebSocket):
    """Reads (and ignores) client messages until the socket closes."""
    try:
        while True:
            await ws.receive_text()
    except (WebSocketDisconnect, RuntimeError):
        return


async def _close(ws: WebSocket, code: int):
    try:
        await ws.close(code=code)
    except RuntimeError:
        pass
