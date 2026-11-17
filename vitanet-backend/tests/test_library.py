"""Health library: parsing real MedlinePlus / MyHealthfinder answers (saved in tests/fixtures), topics, search,
the shipped copy, routes. No network."""
import json
from pathlib import Path

import pytest

from app.services import library_service as ls

FIX = Path(__file__).with_name("fixtures")


class FakeSources:
    def __init__(self):
        self.mp = (FIX / "medlineplus_sickle_cell.xml").read_text(encoding="utf-8")
        self.hf = json.loads((FIX / "myhealthfinder_25.json").read_text(encoding="utf-8"))
        self.calls = []

    def get(self, url, params=None, timeout=None):
        self.calls.append((url, dict(params or {})))
        if url == ls.MP_API:
            body, js = self.mp, None
        elif url.endswith("itemlist.json"):
            body, js = None, {"Result": {"Items": {"Item": [{"Type": "Topic", "Id": "25", "Title": "x"}]}}}
        else:
            body, js = None, self.hf
        return type("R", (), {"text": body, "json": lambda s: js, "raise_for_status": lambda s: None})()


@pytest.fixture
def fresh(monkeypatch, tmp_path):
    monkeypatch.setattr(ls, "CACHE_PATH", tmp_path / "library.json")
    monkeypatch.setattr(ls, "MEDLINEPLUS_TERMS", ["sickle cell disease"])
    monkeypatch.setattr(ls, "_state", {"articles": [], "updated": 0.0, "refreshing": False, "error": None})
    monkeypatch.setattr(ls, "_live_cache", {})
    monkeypatch.setattr(ls, "_ensure_fresh_in_background", lambda: None)


def test_medlineplus_article_has_headings_plain_text_and_credit():
    a = ls.parse_medlineplus((FIX / "medlineplus_sickle_cell.xml").read_text(encoding="utf-8"))[0]
    assert a["title"] == "Sickle Cell Disease" and a["topics"][0] == "Chronic conditions"
    assert a["verified_source"] == ls.MP_SOURCE and a["source_url"].startswith("https://medlineplus.gov/")
    headings = [s["heading"] for s in a["sections"]]
    assert "What is sickle cell disease (SCD)?" in headings and len(headings) >= 4
    text = " ".join(s["content"] for s in a["sections"])
    assert "<" not in text and "qt0" not in text and "&amp;" not in text


def test_myhealthfinder_article_sections_bullets_photo_and_ghana_note():
    r = json.loads((FIX / "myhealthfinder_25.json").read_text(encoding="utf-8"))["Result"]["Resources"]["Resource"][0]
    a = ls._hf_article(r)
    assert a["id"] == "hf-25" and a["image_urls"] and a["topics"] == ["Heart"]
    assert any(s["content"].startswith("•") or "\n•" in s["content"] for s in a["sections"])
    assert not a["excerpt"].endswith(":") and not a["excerpt"].startswith("•")
    assert a["sections"][-1]["heading"] == "In Ghana" and "112" in a["sections"][-1]["content"]


def test_refresh_mixes_sources_and_saves(fresh):
    src = FakeSources()
    assert ls.refresh(src, pause=0) is True
    ids = [a["id"] for a in ls.catalog()]
    assert ids == ["mp-sicklecelldisease", "hf-25"] and ls.CACHE_PATH.exists()
    assert ls.feed(topic="Heart")["articles"][0]["id"] == "hf-25"
    assert ls.feed(topic="Infections")["articles"] == []


def test_search_library_first_then_medlineplus_live(fresh):
    src = FakeSources()
    ls.refresh(src, pause=0)
    n = len(src.calls)
    assert ls.search("heart attack", client=src)["articles"][0]["id"] == "hf-25"
    res = ls.search("hemoglobin rods", client=src)          # in the library: no live call needed? (<5 hits -> live)
    assert res["articles"][0]["id"] == "mp-sicklecelldisease"
    live_calls = [c for c in src.calls[n:] if c[0] == ls.MP_API]
    assert live_calls and live_calls[0][1]["term"] in ("heart attack", "hemoglobin rods")
    before = len(src.calls)
    ls.search("hemoglobin rods", client=src)               # same question again: from the day cache
    assert len(src.calls) == before


def test_shipped_copy_is_used_before_the_first_refresh(fresh):
    arts = ls.catalog()
    assert len(arts) > 100 and ls._state["updated"] == 0.0  # old on purpose, so a refresh starts at once
    titles = {a["title"] for a in arts}
    assert "Malaria" in titles and "Sickle Cell Disease" in titles


def test_routes(fresh):
    from fastapi.testclient import TestClient
    from app.main import app
    ls.refresh(FakeSources(), pause=0)
    c = TestClient(app)
    r = c.get("/library/feed?topic=Heart&limit=5")
    assert r.status_code == 200 and r.json()["articles"][0]["title"] == "Keep Your Heart Healthy"
    assert c.get("/library/article/hf-25").json()["id"] == "hf-25"
    assert c.get("/library/article/nope").status_code == 404
