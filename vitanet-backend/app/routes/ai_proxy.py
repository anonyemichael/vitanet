# app/routes/ai_proxy.py
"""Server-side proxy for the AI and web-search providers the app uses, so the
API keys live only on the server (never inside the app bundle)."""
import os
import time
from collections import defaultdict, deque
from typing import Deque, Dict, List

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse

from app.dependencies.security import CurrentUser, get_current_user

router = APIRouter(prefix="/ai", tags=["ai"])

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
TAVILY_URL = "https://api.tavily.com/search"
GOOGLE_CSE_URL = "https://www.googleapis.com/customsearch/v1"

RATE_LIMIT_PER_MINUTE = int(os.getenv("AI_RATE_LIMIT_PER_MINUTE", "30"))
_calls: Dict[str, Deque[float]] = defaultdict(deque)


def _keys(name: str) -> List[str]:
    return [k.strip() for k in os.getenv(name, "").split(",") if k.strip()]


def _rate_limit(uid: str) -> None:
    now = time.monotonic()
    window = _calls[uid]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= RATE_LIMIT_PER_MINUTE:
        raise HTTPException(status_code=429, detail="Too many AI requests, please wait a moment")
    window.append(now)


def _openrouter_headers(key: str) -> dict:
    return {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://vitanet-62e40.web.app",
        "X-Title": "VitaNet",
    }


@router.post("/chat/completions")
async def chat_completions(request: Request, current: CurrentUser = Depends(get_current_user)):
    _rate_limit(current.uid)
    keys = _keys("OPENROUTER_API_KEYS")
    if not keys:
        raise HTTPException(status_code=503, detail="AI is not configured on the server")
    body = await request.json()

    if body.get("stream"):
        # Find a key that accepts the request, then stream its response through.
        client = httpx.AsyncClient(timeout=httpx.Timeout(120, connect=15))
        last_status, last_text = 502, "AI provider unavailable"
        for key in keys:
            req = client.build_request("POST", OPENROUTER_URL, json=body, headers=_openrouter_headers(key))
            resp = await client.send(req, stream=True)
            if resp.status_code == 200:
                async def relay(r=resp):
                    try:
                        async for chunk in r.aiter_raw():
                            yield chunk
                    finally:
                        await r.aclose()
                        await client.aclose()

                return StreamingResponse(relay(), media_type="text/event-stream")
            last_status = resp.status_code
            last_text = (await resp.aread()).decode(errors="ignore")[:500]
            await resp.aclose()
            if resp.status_code not in (401, 402, 403, 429):
                break
        await client.aclose()
        return JSONResponse(status_code=last_status, content={"error": last_text})

    async with httpx.AsyncClient(timeout=httpx.Timeout(120, connect=15)) as client:
        last = None
        for key in keys:
            last = await client.post(OPENROUTER_URL, json=body, headers=_openrouter_headers(key))
            if last.status_code not in (401, 402, 403, 429):
                break
        return JSONResponse(status_code=last.status_code, content=last.json())


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
