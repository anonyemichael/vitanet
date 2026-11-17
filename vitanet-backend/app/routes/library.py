# app/routes/library.py
"""Health library for the app (app/services/library_service.py). Public: the same articles for everyone.

  GET /library/feed?topic=&cursor=0&limit=12   articles for a topic chip ("For you" = all, sources mixed)
  GET /library/search?q=&cursor=&limit=        library first, then MedlinePlus live for anything else
  GET /library/article/{id}                    one article (for links and notifications)
  GET /library/status                          how many articles, from where, when refreshed
"""
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Response

from app.services import library_service

router = APIRouter(prefix="/library", tags=["library"])
_CACHE = "public, max-age=900"


@router.get("/feed")
def feed(response: Response, topic: Optional[str] = Query(None, max_length=40), cursor: int = Query(0, ge=0),
         limit: int = Query(12, ge=1, le=50)):
    response.headers["Cache-Control"] = _CACHE
    return library_service.feed(topic=topic, cursor=cursor, limit=limit)


@router.get("/search")
def search(response: Response, q: str = Query("", max_length=100), cursor: int = Query(0, ge=0),
           limit: int = Query(12, ge=1, le=50)):
    response.headers["Cache-Control"] = _CACHE
    return library_service.search(q, cursor=cursor, limit=limit)


@router.get("/article/{article_id}")
def article(article_id: str):
    a = library_service.article(article_id)
    if a is None:
        raise HTTPException(status_code=404, detail="Article not found")
    return a


@router.get("/status")
def status():
    return library_service.status()
