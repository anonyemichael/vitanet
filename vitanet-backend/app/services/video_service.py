# app/services/video_service.py
"""Health videos for the app's Learn / Clips pages: real, recent uploads from trusted health channels.

How it works
  - Trusted channels: the channels of the hand-checked videos in video_seeds.json (exact channel ids, looked up
    from those videos) plus a few big health organisations found by their YouTube handle (EXTRA_HANDLES).
    General channels (TED, Goodful, ...) keep their hand-picked video but their other uploads are not pulled.
  - Every REFRESH_HOURS the server reads each channel's newest uploads with the official YouTube Data API v3
    (free key, ~60 of the 10,000 free daily quota units per refresh), drops live streams, videos that cannot be
    embedded and very long talks, and keeps the result in memory and in a JSON file. The app is served from that
    copy, so the feed answers in milliseconds and the key never leaves the server.
  - Search only looks inside that copy, so results always come from trusted channels (important for health).
  - No key, or YouTube unreachable: the hand-checked videos are served, so the page always works.

Settings: YOUTUBE_API_KEY (falls back to GOOGLE_API_KEY with "YouTube Data API v3" enabled on the same project).
"""
import json
import logging
import os
import re
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

API = "https://www.googleapis.com/youtube/v3"
SEEDS = json.loads(Path(__file__).with_name("video_seeds.json").read_text(encoding="utf-8"))
GENERAL_CHANNELS = {"TED", "TED-Ed", "TEDx Talks", "Goodful"}      # not health-only: no uploads pulled
EXTRA_HANDLES = ["@WHO", "@MayoClinic", "@BritishRedCross", "@AmericanRedCross", "@osmosis"]
UPLOAD_PAGES = 2            # 2 x 50 newest uploads per channel
MAX_LONG_S = 30 * 60        # skip press conferences and lectures
SHORT_MAX_S = 60
REFRESH_HOURS = 6
CACHE_PATH = Path(os.environ.get("VIDEO_CACHE_PATH",
                                 Path(__file__).resolve().parents[2] / ".media_cache" / "video_catalog.json"))

# The app's topic chips -> words that put a video in that topic (title + description).
CATEGORIES = {
    "First Aid & CPR": ["cpr", "first aid", "choking", "recovery position", "defibrillator", "aed", "resuscitat",
                        "unconscious", "seizure", "fit", "anaphylaxis", "allergic reaction"],
    "Trauma": ["bleed", "burn", "fracture", "broken bone", "wound", "cut", "sprain", "head injury", "concussion",
               "snake", "bite", "sting", "road traffic", "injur"],
    "Cardio & Vitals": ["heart", "cardiac", "blood pressure", "hypertension", "stroke", "pulse", "cholesterol",
                        "oxygen", "palpitation", "atrial", "chest pain"],
    "Guided Breathing": ["breath", "anxiety", "panic", "stress", "mental health", "depress", "mindful", "calm",
                         "relax", "worry"],
    "Nutrition & Sleep": ["sleep", "diet", "nutrition", "food", "eat", "weight", "diabetes", "sugar", "water",
                          "vitamin", "obesity"],
    "Physical Therapy": ["exercise", "stretch", "back pain", "posture", "physio", "joint", "knee", "neck",
                         "mobility", "walking"],
}

_lock = threading.Lock()
_state = {"videos": [], "updated": 0.0, "channels": [], "refreshing": False, "error": None}


# ---------------------------------------------------------------- helpers
def api_key() -> str:
    return os.environ.get("YOUTUBE_API_KEY") or getattr(settings, "YOUTUBE_API_KEY", "") or \
        os.environ.get("GOOGLE_API_KEY", "")


def parse_duration(iso: str) -> int:
    """ISO 8601 "PT1H2M3S" -> seconds."""
    m = re.fullmatch(r"P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", iso or "")
    if not m:
        return 0
    d, h, mi, s = (int(x or 0) for x in m.groups())
    return d * 86400 + h * 3600 + mi * 60 + s


def categorise(text: str, fallback: str = "") -> str:
    low = text.lower()
    best, hits = fallback, 0
    for cat, words in CATEGORIES.items():
        n = sum(1 for w in words if w in low)
        if n > hits:
            best, hits = cat, n
    return best or "General health"


def takeaways_from(description: str) -> list:
    lines = [l.strip(" -•*\t") for l in (description or "").splitlines()]
    keep = [l for l in lines if 25 <= len(l) <= 200 and "http" not in l and "#" not in l
            and not re.search(r"subscribe|follow us|instagram|facebook|twitter|tiktok|donate", l, re.I)]
    return keep[:3]


def _seed_video(s: dict) -> dict:
    return {"id": s["id"], "title": s["title"], "channel": s["channel"], "channel_id": "", "category": s["category"],
            "duration_s": s["duration_s"], "is_short": s["is_short"], "views": None, "published_at": None,
            "takeaways": s["takeaways"], "description": "", "verified": s["channel"] not in GENERAL_CHANNELS,
            "source": "curated"}


# ---------------------------------------------------------------- YouTube reads
def _get(client, path: str, **params) -> dict:
    r = client.get(f"{API}/{path}", params={**params, "key": api_key()}, timeout=15)
    r.raise_for_status()
    return r.json()


def _videos_details(client, ids: list) -> list:
    out = []
    for i in range(0, len(ids), 50):
        data = _get(client, "videos", part="snippet,contentDetails,statistics,status", id=",".join(ids[i:i + 50]),
                    maxResults=50)
        out.extend(data.get("items", []))
    return out


def build_catalog(client) -> tuple[list, list]:
    """(videos, channels) read from YouTube. Raises on network / key errors."""
    seeds = {s["id"]: s for s in SEEDS}
    seed_items = _videos_details(client, list(seeds))
    channel_ids = {it["snippet"]["channelId"]: it["snippet"]["channelTitle"] for it in seed_items
                   if seeds.get(it["id"], {}).get("channel") not in GENERAL_CHANNELS}
    for handle in EXTRA_HANDLES:
        try:
            items = _get(client, "channels", part="snippet", forHandle=handle).get("items", [])
            if items:
                channel_ids[items[0]["id"]] = items[0]["snippet"]["title"]
            else:
                logger.warning("YouTube handle %s not found", handle)
        except Exception as e:
            logger.warning("YouTube handle %s failed: %s", handle, e)
    channels = []
    ids = list(channel_ids)
    for i in range(0, len(ids), 50):
        for c in _get(client, "channels", part="contentDetails", id=",".join(ids[i:i + 50])).get("items", []):
            uploads = c.get("contentDetails", {}).get("relatedPlaylists", {}).get("uploads")
            if uploads:
                channels.append({"id": c["id"], "title": channel_ids.get(c["id"], ""), "uploads": uploads})

    upload_ids = []
    for ch in channels:
        token = None
        for _ in range(UPLOAD_PAGES):
            params = {"part": "contentDetails", "playlistId": ch["uploads"], "maxResults": 50}
            if token:
                params["pageToken"] = token
            data = _get(client, "playlistItems", **params)
            upload_ids += [it["contentDetails"]["videoId"] for it in data.get("items", [])]
            token = data.get("nextPageToken")
            if not token:
                break

    trusted = {c["id"] for c in channels}
    items = seed_items + _videos_details(client, [v for v in dict.fromkeys(upload_ids) if v not in seeds])
    videos = []
    for it in items:
        sn, cd, st = it.get("snippet", {}), it.get("contentDetails", {}), it.get("status", {})
        seed = seeds.get(it["id"])
        if not seed and (sn.get("channelId") not in trusted or sn.get("liveBroadcastContent", "none") != "none"
                         or st.get("embeddable") is False or st.get("privacyStatus", "public") != "public"):
            continue
        dur = parse_duration(cd.get("duration", ""))
        if not seed and (dur == 0 or dur > MAX_LONG_S):
            continue
        desc = sn.get("description", "")
        views = it.get("statistics", {}).get("viewCount")
        videos.append({
            "id": it["id"], "title": sn.get("title", ""), "channel": sn.get("channelTitle", ""),
            "channel_id": sn.get("channelId", ""),
            "category": seed["category"] if seed else categorise(f"{sn.get('title', '')} {desc}"),
            "duration_s": dur, "is_short": dur <= SHORT_MAX_S, "views": int(views) if views else None,
            "published_at": sn.get("publishedAt"),
            "takeaways": (seed or {}).get("takeaways") or takeaways_from(desc),
            "description": desc[:400], "verified": not seed or seed["channel"] not in GENERAL_CHANNELS,
            "source": "curated" if seed else "channel",
        })
    return videos, channels


# ---------------------------------------------------------------- cache
def _load_file() -> None:
    try:
        d = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
        with _lock:
            _state.update(videos=d["videos"], updated=d["updated"], channels=d.get("channels", []))
    except Exception:
        pass


def refresh(client=None) -> bool:
    """Read YouTube now and replace the catalogue. False (old copy kept) when there is no key or it fails."""
    if not api_key():
        return False
    with _lock:
        if _state["refreshing"]:
            return False
        _state["refreshing"] = True
    try:
        own = client is None
        client = client or httpx.Client()
        try:
            videos, channels = build_catalog(client)
        finally:
            if own:
                client.close()
        if not videos:
            raise RuntimeError("no videos returned")
        with _lock:
            _state.update(videos=videos, channels=channels, updated=time.time(), error=None)
        try:
            CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
            CACHE_PATH.write_text(json.dumps({"videos": videos, "channels": channels, "updated": _state["updated"]}),
                                  encoding="utf-8")
        except OSError as e:
            logger.warning("Video catalogue not saved: %s", e)
        logger.info("Video catalogue: %d videos from %d channels", len(videos), len(channels))
        return True
    except Exception as e:
        logger.warning("Video catalogue refresh failed: %s", e)
        with _lock:
            _state["error"] = str(e)[:200]
        return False
    finally:
        with _lock:
            _state["refreshing"] = False


def refresh_if_stale() -> None:
    if not _state["videos"]:
        _load_file()
    if api_key() and time.time() - _state["updated"] > REFRESH_HOURS * 3600:
        refresh()


def _ensure_fresh_in_background() -> None:
    if api_key() and not _state["refreshing"] and time.time() - _state["updated"] > REFRESH_HOURS * 3600:
        threading.Thread(target=refresh, daemon=True).start()


def catalog() -> list:
    if not _state["videos"]:
        _load_file()
    _ensure_fresh_in_background()
    with _lock:
        vids = list(_state["videos"])
    return vids or [_seed_video(s) for s in SEEDS]


# ---------------------------------------------------------------- feed + search
def _newest_first(videos: list) -> list:
    return sorted(videos, key=lambda v: v.get("published_at") or "", reverse=True)


def _mix_channels(videos: list) -> list:
    """Newest first, but channels take turns so one busy channel does not fill the page."""
    by_ch = {}
    for v in _newest_first(videos):
        by_ch.setdefault(v["channel"], []).append(v)
    queues = sorted(by_ch.values(), key=lambda q: q[0].get("published_at") or "", reverse=True)
    out = []
    while queues:
        for q in list(queues):
            out.append(q.pop(0))
            if not q:
                queues.remove(q)
    return out


def _kind_ok(v: dict, kind: Optional[str]) -> bool:
    return kind is None or (kind == "short") == bool(v["is_short"])


def feed(topic: Optional[str] = None, kind: Optional[str] = None, cursor: int = 0, limit: int = 20) -> dict:
    vids = [v for v in catalog() if _kind_ok(v, kind)]
    if topic and topic != "All":
        vids = [v for v in vids if v["category"] == topic]
    ordered = _mix_channels(vids)
    page = ordered[cursor:cursor + limit]
    nxt = cursor + limit if cursor + limit < len(ordered) else None
    return {"videos": page, "next_cursor": nxt, "total": len(ordered), "updated": _state["updated"] or None}


def search(q: str, kind: Optional[str] = None, cursor: int = 0, limit: int = 20) -> dict:
    words = [w for w in re.findall(r"\w+", (q or "").lower()) if len(w) > 1]
    if not words:
        return feed(kind=kind, cursor=cursor, limit=limit)
    scored = []
    for v in catalog():
        if not _kind_ok(v, kind):
            continue
        title, rest = v["title"].lower(), f"{v['channel']} {v['category']} {v.get('description', '')} " \
                                          f"{' '.join(v.get('takeaways') or [])}".lower()
        if not all(w in title or w in rest for w in words):
            continue
        scored.append((sum(3 for w in words if w in title) + sum(1 for w in words if w in rest), v))
    scored.sort(key=lambda sv: (sv[0], sv[1].get("published_at") or ""), reverse=True)
    ordered = [v for _, v in scored]
    page = ordered[cursor:cursor + limit]
    nxt = cursor + limit if cursor + limit < len(ordered) else None
    return {"videos": page, "next_cursor": nxt, "total": len(ordered), "updated": _state["updated"] or None}


def status() -> dict:
    with _lock:
        return {"key_set": bool(api_key()), "videos": len(_state["videos"]), "channels": [c["title"] for c in _state["channels"]],
                "updated": datetime.fromtimestamp(_state["updated"], timezone.utc).isoformat() if _state["updated"] else None,
                "refreshing": _state["refreshing"], "error": _state["error"],
                "serving": "youtube" if _state["videos"] else "curated"}
