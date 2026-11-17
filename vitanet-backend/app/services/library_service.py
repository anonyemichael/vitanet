# app/services/library_service.py
"""Health library: plain-language articles from two trusted, free, public-domain sources.

  - MyHealthfinder (U.S. Office of Disease Prevention and Health Promotion, odphp.health.gov API v4): ~100
    everyday-health topics with sections and a photo.
  - MedlinePlus (U.S. National Library of Medicine, wsearch.nlm.nih.gov): a reviewed summary for almost any
    condition. The library holds the conditions in MEDLINEPLUS_TERMS (chosen for Ghana: malaria, typhoid,
    sickle cell, ...); a search the library cannot answer goes to MedlinePlus live.

Both are U.S. government works, free to reuse with credit; each article carries its source and a link to the
original. Written for the U.S., so articles mentioning 911 or U.S. insurance get a Ghana note.

The catalogue is rebuilt in the background every REFRESH_HOURS and kept in memory and on disk, so the app's pages
answer in milliseconds. With no network on first start the app shows its built-in articles.
"""
import html as htmllib
import json
import logging
import os
import re
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from xml.etree import ElementTree

import httpx

logger = logging.getLogger(__name__)

HF_API = "https://odphp.health.gov/myhealthfinder/api/v4"
MP_API = "https://wsearch.nlm.nih.gov/ws/query"
HF_SOURCE = "MyHealthfinder · U.S. Office of Disease Prevention and Health Promotion"
MP_SOURCE = "MedlinePlus · U.S. National Library of Medicine"
REFRESH_HOURS = 24
MP_PAUSE_S = 0.8          # NLM asks for no more than 85 requests a minute
CACHE_PATH = Path(os.environ.get("LIBRARY_CACHE_PATH",
                                 Path(__file__).resolve().parents[2] / ".media_cache" / "library_catalog.json"))
GHANA_NOTE = ("Written for the United States. In Ghana, call 112 or the National Ambulance Service on 193 in an "
              "emergency, and ask your clinic or pharmacist about the services and medicines available to you.")

# Conditions people in Ghana ask about most, looked up on MedlinePlus (first result each).
MEDLINEPLUS_TERMS = [
    "malaria", "typhoid fever", "cholera", "diarrhea", "dehydration", "fever", "sickle cell disease", "anemia",
    "high blood pressure", "diabetes", "stroke", "heart attack", "heart failure", "high cholesterol", "asthma",
    "pneumonia", "tuberculosis", "HIV", "hepatitis B", "hepatitis C", "COVID-19", "flu", "common cold", "measles",
    "meningitis", "parasitic diseases", "malnutrition", "breastfeeding", "pregnancy", "prenatal care",
    "postpartum care", "birth control", "menstruation", "menopause", "infant and newborn care",
    "childhood immunization", "jaundice", "kidney diseases", "obesity", "breast cancer", "cervical cancer",
    "prostate cancer", "depression", "anxiety", "stress", "insomnia", "alcohol use disorder", "smoking",
    "burns", "wounds and injuries", "snakebites", "poisoning", "CPR", "first aid", "seizures", "headache",
    "back pain", "arthritis", "eye care", "dental health", "skin infections", "food safety", "drinking water",
    "germs and hygiene", "insect bites and stings", "rabies", "tetanus", "glaucoma", "cataract", "peptic ulcer",
    "urinary tract infections", "sexually transmitted infections", "sleep disorders", "exercise and physical fitness",
    "nutrition", "older adult health",
]

# The app's topic chips -> words in an article's title / categories that put it there.
TOPICS = {
    "Infections": ["malaria", "typhoid", "cholera", "infection", "hiv", "hepatitis", "tuberculosis", "covid", "flu",
                   "cold", "measles", "meningitis", "parasit", "germ", "hygiene", "vaccin", "immuniz", "shots",
                   "rabies", "tetanus", "sexually transmitted", "sti", "fever", "diarrhea"],
    "Heart": ["heart", "blood pressure", "cholesterol", "stroke", "cardio", "aspirin"],
    "Breathing": ["asthma", "lung", "pneumonia", "breath", "smok", "copd", "tuberculosis"],
    "Mental health": ["mental", "depress", "anxiety", "stress", "alcohol", "drug", "sleep", "insomnia", "relationship",
                      "suicid"],
    "Nutrition": ["nutrition", "food", "eat", "diet", "folic", "calcium", "weight", "obesity", "malnutrition",
                  "breastfeed", "water"],
    "Women & children": ["women", "pregnan", "prenatal", "postpartum", "birth", "menstru", "menopause", "breast",
                         "cervical", "infant", "newborn", "child", "teen", "baby", "breastfeed", "folic", "midwife"],
    "Fitness": ["physical activity", "exercise", "fitness", "active", "falling", "back pain", "arthritis"],
    "Chronic conditions": ["diabetes", "kidney", "sickle", "anemia", "cancer", "high blood pressure", "arthritis",
                           "glaucoma", "cataract", "ulcer", "seizure"],
    "First aid & safety": ["first aid", "cpr", "burn", "wound", "injur", "snake", "poison", "bite", "sting",
                           "safety", "seizure", "falling"],
}

_lock = threading.Lock()
_state = {"articles": [], "updated": 0.0, "refreshing": False, "error": None}
_live_cache: dict = {}     # live MedlinePlus searches: query -> (time, articles)


# ---------------------------------------------------------------- text helpers
def _clean(text: str) -> str:
    return re.sub(r"[ \t\r\f\v]+", " ", htmllib.unescape(text or "")).strip()


def html_sections(raw_html: str, first_heading: str) -> list:
    """HTML -> [{heading, content}]: a new section at every <h2>-<h4>, paragraphs separated by a blank line,
    list items as "• " lines, all tags removed."""
    s = re.sub(r"(?is)<(script|style)\b.*?</\1>", "", raw_html or "")
    s = re.sub(r"(?i)</?span[^>]*>", "", s)          # MedlinePlus search highlights
    # MedlinePlus search drops the heading tags: a short question right before a paragraph is a heading
    s = re.sub(r"(?:(?<=>)|^)\s*([^<>]{3,120}\?)\s*(?=<p\b)", r"<h3>\1</h3>", s)
    s = re.sub(r"(?is)<h[2-4][^>]*>(.*?)</h[2-4]>", lambda m: f"\x00H{_strip(m.group(1))}\x00", s)
    s = re.sub(r"(?is)<li[^>]*>", "\n• ", s)
    s = re.sub(r"(?is)</(p|ul|ol|div|li)>|<br\s*/?>", "\n", s)
    s = _strip(s, keep_newlines=True)
    sections, heading, buf = [], first_heading, []
    for part in s.split("\x00"):
        if part.startswith("H"):
            if "".join(buf).strip():
                sections.append({"heading": heading, "content": _paragraphs(buf)})
            heading, buf = part[1:].strip() or heading, []
        else:
            buf.append(part)
    if "".join(buf).strip():
        sections.append({"heading": heading, "content": _paragraphs(buf)})
    return sections


def _strip(s: str, keep_newlines: bool = False) -> str:
    s = re.sub(r"(?s)<[^>]+>", "", s)
    s = htmllib.unescape(s).replace("\xa0", " ")
    if not keep_newlines:
        return re.sub(r"\s+", " ", s).strip()
    return s


def _paragraphs(parts: list) -> str:
    lines = [re.sub(r"[ \t]+", " ", l).strip() for l in "".join(parts).split("\n")]
    out, prev_bullet = [], False
    for l in lines:
        if not l or l == "•":
            continue
        bullet = l.startswith("•")
        if out and not (bullet and prev_bullet):
            out.append("")              # blank line between paragraphs, bullets stay together
        out.append(l)
        prev_bullet = bullet
    return "\n".join(out).strip()


def topics_for(text: str) -> list:
    low = text.lower()
    return [t for t, words in TOPICS.items() if any(w in low for w in words)]


def _finish(article: dict) -> dict:
    words = sum(len(s["content"].split()) for s in article["sections"])
    article["read_time"] = f"{max(1, round(words / 200))} min read"
    paras = [p for s in article["sections"] for p in s["content"].split("\n\n")]
    prose = [p for p in paras if not p.startswith("•") and "\n" not in p]      # not a list
    para = next((p for p in prose if len(p) >= 60 and not p.endswith(":")), (prose or paras or [""])[0]).lstrip("• ")
    article["excerpt"] = para if len(para) <= 280 else para[:277].rsplit(" ", 1)[0] + "…"
    text = " ".join(s["content"] for s in article["sections"]).lower()
    if re.search(r"\b911\b|medicare|medicaid|health insurance|affordable care act", text):
        article["sections"].append({"heading": "In Ghana", "content": GHANA_NOTE})
    # the title decides; the source's broad groups only when the title says nothing (malaria is not "Heart")
    article["topics"] = topics_for(article["title"]) or topics_for(article.get("category", "")) or ["General health"]
    article["category"] = article["topics"][0]
    return article


# ---------------------------------------------------------------- sources
def _hf_article(r: dict) -> Optional[dict]:
    secs = (r.get("Sections") or {}).get("section") or []
    sections = []
    for sec in secs:
        sections += html_sections(sec.get("Content", ""), _clean(sec.get("Title", "")))
    if not sections:
        return None
    updated = r.get("LastUpdate")
    try:
        published = datetime.fromtimestamp(int(updated), timezone.utc).date().isoformat() if updated else None
    except (ValueError, OverflowError, OSError):
        published = None
    return _finish({
        "id": f"hf-{r['Id']}", "title": _clean(r.get("Title", "")), "category": _clean(r.get("Categories", "")),
        "verified_source": HF_SOURCE, "source_url": r.get("AccessibleVersion") or "https://odphp.health.gov/myhealthfinder",
        "image_urls": [r["ImageUrl"]] if r.get("ImageUrl") else [], "image_alt": _clean(r.get("ImageAlt", "")),
        "published_date": published, "sections": sections, "key_takeaways": [],
    })


def fetch_myhealthfinder(client) -> list:
    items = client.get(f"{HF_API}/itemlist.json", params={"Type": "topic"}, timeout=20).json()
    ids = [i["Id"] for i in items["Result"]["Items"]["Item"] if i.get("Type") == "Topic"]
    out = []
    for tid in ids:
        try:
            data = client.get(f"{HF_API}/topicsearch.json", params={"TopicId": tid}, timeout=20).json()
            for r in (data["Result"].get("Resources") or {}).get("Resource") or []:
                a = _hf_article(r)
                if a:
                    out.append(a)
        except Exception as e:
            logger.warning("MyHealthfinder topic %s failed: %s", tid, e)
    return out


def parse_medlineplus(xml_text: str) -> list:
    root = ElementTree.fromstring(xml_text)
    out = []
    for doc in root.iter("document"):
        fields = {}
        for c in doc.findall("content"):
            fields.setdefault(c.get("name"), []).append(c.text or "")
        title = _strip(htmllib.unescape("".join(fields.get("title", [""]))))
        summary = htmllib.unescape("".join(fields.get("FullSummary", [""])))
        url = doc.get("url", "")
        if not title or not summary or "medlineplus.gov" not in url:
            continue
        slug = re.sub(r"[^a-z0-9]+", "-", url.rsplit("/", 1)[-1].replace(".html", "").lower()).strip("-")
        groups = [_strip(htmllib.unescape(g)) for g in fields.get("groupName", [])]
        out.append(_finish({
            "id": f"mp-{slug}", "title": title, "category": ", ".join(groups), "verified_source": MP_SOURCE,
            "source_url": url, "image_urls": [], "image_alt": "", "published_date": None,
            "sections": html_sections(summary, f"About {title.lower()}" if len(title) < 40 else "Overview"),
            "key_takeaways": [],
        }))
    return out


def medlineplus_search(client, term: str, n: int = 1) -> list:
    r = client.get(MP_API, params={"db": "healthTopics", "term": term, "retmax": n}, timeout=20)
    r.raise_for_status()
    return parse_medlineplus(r.text)


def build_catalog(client, pause: float = MP_PAUSE_S) -> list:
    articles, seen = [], set()
    mp = []
    for term in MEDLINEPLUS_TERMS:
        try:
            mp += medlineplus_search(client, term, 1)
        except Exception as e:
            logger.warning("MedlinePlus %r failed: %s", term, e)
        time.sleep(pause)
    hf = []
    try:
        hf = fetch_myhealthfinder(client)
    except Exception as e:
        logger.warning("MyHealthfinder failed: %s", e)
    # alternate the two sources so the "For you" feed is mixed (MedlinePlus first: the Ghana conditions)
    for i in range(max(len(mp), len(hf))):
        for src in (mp, hf):
            if i < len(src) and src[i]["id"] not in seen:
                seen.add(src[i]["id"])
                articles.append(src[i])
    return articles


# ---------------------------------------------------------------- cache
SEED_PATH = Path(__file__).with_name("library_seed.json")   # a copy shipped with the code (built 2026-11-17)


def _load_file() -> None:
    """The last saved copy, else the shipped copy (marked old, so a refresh starts at once)."""
    for path, fresh in ((CACHE_PATH, True), (SEED_PATH, False)):
        try:
            d = json.loads(path.read_text(encoding="utf-8"))
            with _lock:
                _state.update(articles=d["articles"], updated=d["updated"] if fresh else 0.0)
            return
        except Exception:
            continue


def refresh(client=None, pause: float = MP_PAUSE_S) -> bool:
    with _lock:
        if _state["refreshing"]:
            return False
        _state["refreshing"] = True
    try:
        own = client is None
        client = client or httpx.Client(headers={"User-Agent": "VitaNet-HealthLibrary/1.0"}, follow_redirects=True)
        try:
            articles = build_catalog(client, pause)
        finally:
            if own:
                client.close()
        if not articles:
            raise RuntimeError("no articles returned")
        with _lock:
            _state.update(articles=articles, updated=time.time(), error=None)
        try:
            CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
            CACHE_PATH.write_text(json.dumps({"articles": articles, "updated": _state["updated"]}), encoding="utf-8")
        except OSError as e:
            logger.warning("Library not saved: %s", e)
        logger.info("Health library: %d articles", len(articles))
        return True
    except Exception as e:
        logger.warning("Health library refresh failed: %s", e)
        with _lock:
            _state["error"] = str(e)[:200]
        return False
    finally:
        with _lock:
            _state["refreshing"] = False


def refresh_if_stale() -> None:
    if not _state["articles"]:
        _load_file()
    if time.time() - _state["updated"] > REFRESH_HOURS * 3600:
        refresh()


def _ensure_fresh_in_background() -> None:
    if not _state["refreshing"] and time.time() - _state["updated"] > REFRESH_HOURS * 3600:
        threading.Thread(target=refresh, daemon=True).start()


def catalog() -> list:
    if not _state["articles"]:
        _load_file()
    _ensure_fresh_in_background()
    with _lock:
        return list(_state["articles"])


# ---------------------------------------------------------------- feed, search, article
def _page(items: list, cursor: int, limit: int) -> dict:
    page = items[cursor:cursor + limit]
    nxt = cursor + limit if cursor + limit < len(items) else None
    return {"articles": page, "next_cursor": nxt, "total": len(items), "updated": _state["updated"] or None}


def feed(topic: Optional[str] = None, cursor: int = 0, limit: int = 12) -> dict:
    arts = catalog()
    if topic and topic not in ("All", "For you"):
        arts = [a for a in arts if topic in a.get("topics", [])]
    return _page(arts, cursor, limit)


def search(q: str, cursor: int = 0, limit: int = 12, client=None) -> dict:
    words = [w for w in re.findall(r"\w+", (q or "").lower()) if len(w) > 1]
    if not words:
        return feed(cursor=cursor, limit=limit)
    scored = []
    for a in catalog():
        title = a["title"].lower()
        body = f"{a.get('category', '')} {a.get('excerpt', '')} " + " ".join(s["content"] for s in a["sections"])
        body = body.lower()
        if all(w in title or w in body for w in words):
            scored.append((sum(5 for w in words if w in title) + sum(body.count(w) for w in words), a))
    scored.sort(key=lambda sa: sa[0], reverse=True)
    found = [a for _, a in scored]
    if cursor == 0 and len(found) < 5:
        found += [a for a in _live(q, client) if a["id"] not in {f["id"] for f in found}]
    return _page(found, cursor, limit)


def _live(q: str, client=None) -> list:
    """MedlinePlus live search for a question the library cannot answer (cached a day per question)."""
    key = q.strip().lower()
    hit = _live_cache.get(key)
    if hit and time.time() - hit[0] < 86400:
        return hit[1]
    try:
        own = client is None
        client = client or httpx.Client(headers={"User-Agent": "VitaNet-HealthLibrary/1.0"}, follow_redirects=True)
        try:
            res = medlineplus_search(client, q, 5)
        finally:
            if own:
                client.close()
    except Exception as e:
        logger.warning("MedlinePlus live search failed: %s", e)
        return []
    if len(_live_cache) > 500:
        _live_cache.clear()
    _live_cache[key] = (time.time(), res)
    return res


def article(article_id: str) -> Optional[dict]:
    for a in catalog():
        if a["id"] == article_id:
            return a
    for _, res in _live_cache.values():
        for a in res:
            if a["id"] == article_id:
                return a
    return None


def status() -> dict:
    with _lock:
        arts = _state["articles"]
        return {"articles": len(arts),
                "by_source": {s: sum(a["verified_source"] == s for a in arts) for s in (MP_SOURCE, HF_SOURCE)},
                "updated": datetime.fromtimestamp(_state["updated"], timezone.utc).isoformat() if _state["updated"] else None,
                "refreshing": _state["refreshing"], "error": _state["error"]}
