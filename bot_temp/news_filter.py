"""
High-impact news filter — FXAlexG rule: no trades 30 min before major news.
Uses ForexFactory public calendar JSON.
"""

import requests
from datetime import datetime, timedelta, timezone

FF_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"

_cache = {"data": None, "fetched_at": None}
_CACHE_TTL = 3600  # refresh once per hour


def _load():
    now = datetime.now(timezone.utc)
    if _cache["data"] and _cache["fetched_at"] and \
            (now - _cache["fetched_at"]).total_seconds() < _CACHE_TTL:
        return _cache["data"]
    try:
        r = requests.get(FF_URL, timeout=6)
        if r.status_code == 200:
            _cache["data"] = r.json()
            _cache["fetched_at"] = now
            return _cache["data"]
    except Exception:
        pass
    return _cache["data"] or []


def has_high_impact_news_soon(symbol, minutes=30):
    """Return (True, title) if a High-impact event affecting `symbol` is within `minutes`."""
    try:
        events = _load()
        now = datetime.now(timezone.utc)
        cutoff = now + timedelta(minutes=minutes)
        # Extract base and quote currencies (e.g. 'EURUSDm' -> 'EUR', 'USD')
        base_curr = symbol[:3]
        quote_curr = symbol[3:6]
        affected_currencies = {base_curr, quote_curr, "USD"} # USD news impacts all pairs
        
        for ev in events:
            if ev.get("impact") != "High":
                continue
            
            # Currency filter
            news_curr = ev.get("country")
            if news_curr not in affected_currencies:
                continue

            try:
                ev_time = datetime.strptime(ev["date"], "%Y-%m-%dT%H:%M:%S%z").astimezone(timezone.utc)
            except Exception:
                continue
            if now <= ev_time <= cutoff:
                return True, ev.get("title", "Unknown event")
        return False, None
    except Exception:
        return False, None  # never block trading if news check fails

def get_todays_news():
    """Return a formatted string of today's high-impact news for Telegram."""
    try:
        events = _load()
        now = datetime.now(timezone.utc)
        today_str = now.strftime("%Y-%m-%d")
        
        todays_high_impact = []
        for ev in events:
            if ev.get("impact") != "High":
                continue
            try:
                ev_time = datetime.strptime(ev["date"], "%Y-%m-%dT%H:%M:%S%z").astimezone(timezone.utc)
                if ev_time.strftime("%Y-%m-%d") == today_str:
                    todays_high_impact.append((ev_time, ev.get("country"), ev.get("title")))
            except Exception:
                continue
                
        if not todays_high_impact:
            return "📰 <b>ForexFactory News</b>\n\nNo High-Impact news scheduled for today."
            
        msg = f"📰 <b>Today's High-Impact News ({today_str})</b>\n\n"
        # Sort by time
        todays_high_impact.sort(key=lambda x: x[0])
        for t, c, title in todays_high_impact:
            time_str = t.strftime("%H:%M UTC")
            msg += f"• <b>{time_str}</b> | {c} | <i>{title}</i>\n"
            
        return msg
    except Exception as e:
        return f"❌ Failed to fetch news: {e}"
