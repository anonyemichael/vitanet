# app/routes/videos.py
"""Health videos for the app (app/services/video_service.py). Public: the same list for everyone.

  GET /videos/feed?topic=&kind=short|long&cursor=0&limit=20   newest from trusted health channels, channels mixed
  GET /videos/search?q=&kind=&cursor=&limit=                   search inside the trusted catalogue
  GET /videos/status                                           where the list comes from and when it was refreshed
"""
from typing import Optional

from fastapi import APIRouter, Query, Response

from app.services import video_service

router = APIRouter(prefix="/videos", tags=["videos"])
_CACHE = "public, max-age=300"   # phones and browsers may reuse a page for 5 minutes


@router.get("/feed")
def feed(response: Response, topic: Optional[str] = None, kind: Optional[str] = Query(None, pattern="^(short|long)$"),
         cursor: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=50)):
    response.headers["Cache-Control"] = _CACHE
    return video_service.feed(topic=topic, kind=kind, cursor=cursor, limit=limit)


@router.get("/search")
def search(response: Response, q: str = Query("", max_length=100),
           kind: Optional[str] = Query(None, pattern="^(short|long)$"),
           cursor: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=50)):
    response.headers["Cache-Control"] = _CACHE
    return video_service.search(q, kind=kind, cursor=cursor, limit=limit)


@router.get("/status")
def status():
    return video_service.status()
