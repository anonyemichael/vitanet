"""
app/routes/sms.py

SMS-to-AI webhook router for Africa's Talking.

Flow:
1. Contestant texts your short code.
2. Africa's Talking POSTs the message to this router's /sms/inbound route.
3. This router sends the text to an AI and gets a reply.
4. This router sends the AI's reply back via Africa's Talking's SMS API.

SETUP:
1. pip install africastalking python-multipart --break-system-packages
2. Set AT_USERNAME and AT_API_KEY as environment variables.
3. Already wired into app/main.py via app.include_router(sms.router).
4. Run: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
5. In another terminal: ngrok http 8000
6. Paste https://xxxx.ngrok-free.app/sms/inbound into the Africa's Talking
   sandbox inbox callback field:
   https://account.africastalking.com/apps/sandbox/sms/inbox/callback
7. Test it from the simulator: https://simulator.africastalking.com:1517/
"""

import os
import africastalking
from fastapi import APIRouter, Request

# ---- CONFIG ----
AT_USERNAME = os.environ.get("AT_USERNAME", "sandbox")  # "sandbox" for testing
AT_API_KEY = os.environ.get("AT_API_KEY", "771da6baddf0681f705d0dc96a8c02b5b663b386af865eadbddd0f26cb270e6c6c90be48")

# Initialize Africa's Talking SDK
africastalking.initialize(AT_USERNAME, AT_API_KEY)
sms = africastalking.SMS

router = APIRouter(prefix="/sms", tags=["sms"])


def call_ai(message_text: str) -> str:
    """
    Replace this with your actual AI call (Anthropic API, OpenAI, etc).
    Keep replies short -- SMS is limited to 160 characters per segment.
    """
    # --- Example using the Anthropic API ---
    # import requests
    # response = requests.post(
    #     "https://api.anthropic.com/v1/messages",
    #     headers={
    #         "x-api-key": os.environ["ANTHROPIC_API_KEY"],
    #         "anthropic-version": "2023-06-01",
    #         "content-type": "application/json",
    #     },
    #     json={
    #         "model": "claude-sonnet-4-6",
    #         "max_tokens": 100,
    #         "messages": [{"role": "user", "content": message_text}],
    #     },
    # )
    # return response.json()["content"][0]["text"]

    # Placeholder response for now, so you can test the plumbing first:
    return f"Got it! You said: {message_text}"


@router.post("/inbound")
async def sms_inbound(request: Request):
    """URL to paste into the Africa's Talking inbox callback field
    (full path once mounted: /sms/inbound)."""
    form = await request.form()
    from_number = form.get("from")
    text = form.get("text")

    print(f"[INBOUND] From {from_number}: {text}")

    if not from_number or not text:
        return {"error": "Missing data"}

    reply_text = call_ai(text)

    try:
        response = sms.send(reply_text, [from_number])
        print(f"[OUTBOUND] To {from_number}: {reply_text}")
        print(response)
    except Exception as e:
        print(f"[ERROR sending SMS] {e}")

    return "OK"


@router.get("/health")
async def health_check():
    return {"status": "SMS-to-AI webhook is running."}