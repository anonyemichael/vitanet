# app/routes/ai_proxy.py
"""Server-side AI helpers for the app: the health-report note (VitaNet model) and the web-search proxies, so API
keys live only on the server (never inside the app bundle). The old OpenRouter/Gemini chat relay is removed: the app
chats through POST /chat/{user_id} (app/services/ai_agent.py), which uses the VitaNet model and its tools."""
import os
import time
from collections import defaultdict, deque
from typing import Deque, Dict, List

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from pydantic import BaseModel, Field

from app.dependencies.security import CurrentUser, get_current_user
from app.services import ai_client

router = APIRouter(prefix="/ai", tags=["ai"])

TAVILY_URL = "https://api.tavily.com/search"
GOOGLE_CSE_URL = "https://www.googleapis.com/customsearch/v1"

RATE_LIMIT_PER_MINUTE = int(os.getenv("AI_RATE_LIMIT_PER_MINUTE", "30"))
_calls: Dict[str, Deque[float]] = defaultdict(deque)


def _rate_limit(uid: str) -> None:
    now = time.monotonic()
    window = _calls[uid]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= RATE_LIMIT_PER_MINUTE:
        raise HTTPException(status_code=429, detail="Too many AI requests, please wait a moment")
    window.append(now)


class HealthReportIn(BaseModel):
    metric_name: str = Field(max_length=60)
    current_value: str = Field(max_length=20)
    unit: str = Field(default="", max_length=20)
    avg: str = Field(default="", max_length=20)
    high: str = Field(default="", max_length=20)
    low: str = Field(default="", max_length=20)


@router.post("/health-report")
def health_report(payload: HealthReportIn, current: CurrentUser = Depends(get_current_user)):
    """Short plain-language note about one vital, written by the VitaNet model (replaces the old Gemini call made
    from the app). When the model is offline the app still gets a factual summary of the numbers."""
    _rate_limit(current.uid)
    p = payload
    prompt = (
        f"Explain this health reading to the user in under 4 short sentences, plain language, no diagnosis, using only "
        f"these numbers. Metric: {p.metric_name}. Current: {p.current_value} {p.unit}. Recent average: {p.avg} {p.unit}. "
        f"Highest: {p.high} {p.unit}. Lowest: {p.low} {p.unit}. If a value could be a danger sign, say to seek care."
    )
    text = ai_client.complete_text(prompt, max_tokens=220)
    source = "vitanet" if text else "summary"
    if not text:
        text = (f"Your latest {p.metric_name.lower()} is {p.current_value} {p.unit}. Over recent readings it averaged "
                f"{p.avg} {p.unit} (lowest {p.low}, highest {p.high}). The VitaNet assistant is offline, so this is "
                f"only a summary of your numbers; if you feel unwell, contact a clinician.").replace("  ", " ")
    return {"report": text, "source": source}


@router.post("/search/tavily")
async def tavily_search(request: Request, current: CurrentUser = Depends(get_current_user)):
    _rate_limit(current.uid)
    key = os.getenv("TAVILY_API_KEY", "").strip()
    if not key:
        raise HTTPException(status_code=503, detail="Web search is not configured on the server")
    body = await request.json()
    body["api_key"] = key
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(TAVILY_URL, json=body)
        return JSONResponse(status_code=resp.status_code, content=resp.json())


@router.get("/search/google")
async def google_search(q: str, num: int = 3, current: CurrentUser = Depends(get_current_user)):
    _rate_limit(current.uid)
    key = os.getenv("GOOGLE_API_KEY", "").strip()
    cx = os.getenv("GOOGLE_CSE_ID", "").strip()
    if not key or not cx:
        raise HTTPException(status_code=503, detail="Web search is not configured on the server")
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(GOOGLE_CSE_URL, params={"key": key, "cx": cx, "q": q, "num": min(num, 10)})
        return JSONResponse(status_code=resp.status_code, content=resp.json())
