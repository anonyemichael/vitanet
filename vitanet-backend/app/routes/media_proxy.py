# app/routes/media_proxy.py
"""Server-side media and health-feed proxy.

Solves browser CORS limitations for DailyMed images and Europe PMC queries.
Caches fetched images in memory and on disk for sub-millisecond repeated responses.
"""
import hashlib
import os
from typing import Optional

import httpx
from fastapi import APIRouter, HTTPException, Query, Response

router = APIRouter(tags=["media"])

_CACHE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", ".media_cache")
os.makedirs(_CACHE_DIR, exist_ok=True)

_MEM_CACHE = {}  # sha256 -> (content_type, bytes)
_MAX_MEM_ITEMS = 300


def _cache_key(url: str) -> str:
    return hashlib.sha256(url.strip().encode("utf-8")).hexdigest()


@router.get("/media/proxy")
async def proxy_media(url: str = Query(..., description="Target image URL to proxy")):
    clean_url = url.strip()
    if not clean_url.startswith("http://") and not clean_url.startswith("https://"):
        raise HTTPException(status_code=400, detail="Invalid URL protocol")

    key = _cache_key(clean_url)

    # 1. Check memory cache
    if key in _MEM_CACHE:
        content_type, data = _MEM_CACHE[key]
        return Response(
            content=data,
            media_type=content_type,
            headers={
                "Cache-Control": "public, max-age=604800, immutable",
                "Access-Control-Allow-Origin": "*",
            },
        )

    # 2. Check disk cache
    disk_path = os.path.join(_CACHE_DIR, key)
    meta_path = disk_path + ".meta"
    if os.path.exists(disk_path) and os.path.exists(meta_path):
        try:
            with open(meta_path, "r", encoding="utf-8") as f:
                content_type = f.read().strip()
            with open(disk_path, "rb") as f:
                data = f.read()
            if len(_MEM_CACHE) < _MAX_MEM_ITEMS:
                _MEM_CACHE[key] = (content_type, data)
            return Response(
                content=data,
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=604800, immutable",
                    "Access-Control-Allow-Origin": "*",
                },
            )
        except Exception:
            pass

    # 3. Fetch from origin
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    }
    try:
        async with httpx.AsyncClient(timeout=12.0, follow_redirects=True) as client:
            resp = await client.get(clean_url, headers=headers)
            if resp.status_code != 200 or len(resp.content) == 0:
                raise HTTPException(status_code=resp.status_code, detail="Could not retrieve media")

            content_type = resp.headers.get("content-type", "image/jpeg")
            data = resp.content

            # Save to memory
            if len(_MEM_CACHE) < _MAX_MEM_ITEMS:
                _MEM_CACHE[key] = (content_type, data)

            # Save to disk
            try:
                with open(disk_path, "wb") as f:
                    f.write(data)
                with open(meta_path, "w", encoding="utf-8") as f:
                    f.write(content_type)
            except Exception:
                pass

            return Response(
                content=data,
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=604800, immutable",
                    "Access-Control-Allow-Origin": "*",
                },
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Proxy error: {str(e)}")


@router.get("/api/health-feed")
async def health_feed(
    query: str = Query("Cardiology", description="Europe PMC search query"),
    cursorMark: str = Query("*", description="Pagination cursor token"),
    pageSize: int = Query(12, ge=1, le=50, description="Articles per page"),
):
    """Server-side proxy for Europe PMC that bypasses browser CORS restrictions."""
    url = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
    params = {
        "query": query.strip(),
        "resultType": "core",
        "cursorMark": cursorMark.strip(),
        "pageSize": pageSize,
        "format": "json",
    }
    headers = {
        "User-Agent": "VitaNet-Healthcare/2.0 (medical-portal; contact: health@vitanet.local)",
        "Accept": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            resp = await client.get(url, params=params, headers=headers)
            if resp.status_code == 200:
                return Response(
                    content=resp.content,
                    media_type="application/json",
                    headers={
                        "Cache-Control": "public, max-age=1800",
                        "Access-Control-Allow-Origin": "*",
                    },
                )
            return Response(
                content=b'{"hitCount": 0, "nextCursorMark": null, "resultList": {"result": []}}',
                media_type="application/json",
                headers={"Access-Control-Allow-Origin": "*"},
            )
    except Exception:
        return Response(
            content=b'{"hitCount": 0, "nextCursorMark": null, "resultList": {"result": []}}',
            media_type="application/json",
            headers={"Access-Control-Allow-Origin": "*"},
        )
