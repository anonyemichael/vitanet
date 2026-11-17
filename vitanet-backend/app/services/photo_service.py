# app/services/photo_service.py
"""A photo of its own for every health-library article that has none (MedlinePlus articles come without one).

Source: Pexels (free API key, PEXELS_API_KEY; curated stock photos, no injury or gore pictures, free to use). Each
article gets the best-matching landscape photo that no other article already uses, so the library never shows
the same picture twice. Pexels asks for a link back and credit to the photographer: every photo carries
"Photo: <name> / Pexels" and the photo's page.

Some topics would search badly or come back too clinical, so they use a kinder search (PHOTO_QUERIES).
Without a key nothing changes here and the app falls back to its own topic photos.
"""
import logging
import os
import re
from typing import Optional

logger = logging.getLogger(__name__)

API = "https://api.pexels.com/v1/search"

# article title (lower case) -> what to search instead (relevant, never graphic)
PHOTO_QUERIES = {
    "malaria": "mosquito net bed", "salmonella infections": "clean drinking water glass",
    "cholera": "clean water tap washing hands", "diarrhea": "glass of water hydration",
    "dehydration": "drinking water bottle", "fever": "thermometer temperature",
    "sickle cell disease": "blood test laboratory", "anemia": "blood test laboratory",
    "burns": "first aid kit", "wounds and injuries": "first aid bandage", "animal bites": "dog",
    "snakebites": "snake", "poisoning": "medicine cabinet", "cpr": "cpr training", "first aid": "first aid kit",
    "seizures": "neurologist doctor", "tuberculosis": "chest x-ray doctor", "hiv": "red ribbon",
    "hiv/aids": "red ribbon", "hepatitis b": "liver health doctor", "hepatitis c": "liver health doctor",
    "skin infections": "skin care", "parasitic diseases": "microscope laboratory",
    "sexually transmitted infections": "doctor consultation", "rabies": "dog vaccination veterinarian",
    "tetanus": "vaccination", "jaundice": "newborn baby", "infant and newborn care": "newborn baby",
    "pregnancy": "pregnant woman", "breastfeeding": "mother and baby", "menstruation": "calendar woman",
    "kidney diseases": "kidney health doctor", "peptic ulcer": "stomach ache",
    "urinary tract infections": "doctor consultation", "insect bites and stings": "mosquito",
    "germs and hygiene": "washing hands soap", "food safety": "kitchen cooking clean",
    "drinking water": "drinking water", "older adult health": "elderly people walking",
}


def api_key() -> str:
    from app.core.config import settings
    return os.environ.get("PEXELS_API_KEY") or getattr(settings, "PEXELS_API_KEY", "")


def query_for(title: str) -> str:
    t = title.strip().lower()
    return PHOTO_QUERIES.get(t) or re.sub(r"\(.*?\)|[^\w\s'-]", " ", title).strip()


def find_photo(client, query: str, used: set) -> Optional[dict]:
    r = client.get(API, params={"query": query, "per_page": 15, "orientation": "landscape"},
                   headers={"Authorization": api_key()}, timeout=15)
    r.raise_for_status()
    for p in r.json().get("photos", []):
        if p["id"] in used:
            continue
        src = p.get("src") or {}
        url = src.get("large") or src.get("landscape") or src.get("original")
        if not url:
            continue
        used.add(p["id"])
        return {"id": p["id"], "url": url, "alt": p.get("alt") or "", "credit": f"Photo: {p.get('photographer', 'Pexels')} / Pexels",
                "credit_url": p.get("url") or "https://www.pexels.com"}
    return None


def add_photos(client, articles: list, previous: Optional[dict] = None) -> int:
    """Give each article without an image its own photo. `previous` (article id -> photo) keeps the photo an
    article already had, so pictures do not change every day and few requests are made. Returns how many
    articles got a new photo from Pexels."""
    if not api_key():
        return 0
    previous = previous or {}
    used = {p["id"] for p in previous.values() if p}
    added = 0
    for a in articles:
        if a.get("image_urls") and not a.get("photo"):
            continue                                   # has its own picture from the source
        photo = previous.get(a["id"])
        if not photo:
            try:
                photo = find_photo(client, query_for(a["title"]), used)
                if photo is None and query_for(a["title"]) != a["title"]:
                    photo = find_photo(client, a["title"], used)
                added += bool(photo)
            except Exception as e:
                logger.warning("Pexels photo for %r failed: %s", a["title"], e)
                photo = None
        if photo:
            a.update(photo=photo, image_urls=[photo["url"]], image_alt=photo["alt"] or a.get("image_alt", ""),
                     image_credit=photo["credit"], image_credit_url=photo["credit_url"])
    return added
