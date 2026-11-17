"""Library photos: each article without a picture gets its own Pexels photo, never one already used, with credit;
kept across refreshes; no key = untouched."""
import pytest

from app.services import photo_service as ps


class FakePexels:
    """Pexels search answers (documented format). Every query returns the same 3 photos, so uniqueness is tested."""
    def __init__(self):
        self.queries = []

    def get(self, url, params=None, headers=None, timeout=None):
        assert url == ps.API and headers["Authorization"] == "k" and params["orientation"] == "landscape"
        self.queries.append(params["query"])
        photos = [{"id": i, "url": f"https://www.pexels.com/photo/{i}/", "photographer": f"Ama {i}", "alt": f"alt {i}",
                   "src": {"large": f"https://images.pexels.com/photos/{i}/large.jpg"}} for i in (1, 2, 3)]
        return type("R", (), {"json": lambda s: {"photos": photos}, "raise_for_status": lambda s: None})()


@pytest.fixture
def key(monkeypatch):
    monkeypatch.setenv("PEXELS_API_KEY", "k")


def arts():
    return [{"id": "mp-malaria", "title": "Malaria", "image_urls": []},
            {"id": "mp-fever", "title": "Fever", "image_urls": []},
            {"id": "hf-25", "title": "Keep Your Heart Healthy", "image_urls": ["https://odphp.health.gov/x.jpg"]},
            {"id": "mp-asthma", "title": "Asthma", "image_urls": []}]


def test_every_article_gets_its_own_photo_with_credit(key):
    a, px = arts(), FakePexels()
    assert ps.add_photos(px, a) == 3
    urls = [x["image_urls"][0] for x in a]
    assert len(set(urls)) == 4                                   # no picture twice
    assert a[2]["image_urls"] == ["https://odphp.health.gov/x.jpg"] and "photo" not in a[2]
    assert a[0]["image_credit"] == "Photo: Ama 1 / Pexels" and a[0]["image_credit_url"].startswith("https://www.pexels.com/")
    assert px.queries[:2] == ["mosquito net bed", "thermometer temperature"]   # kinder searches for these topics


def test_photos_are_kept_across_refreshes(key):
    first = arts()
    ps.add_photos(FakePexels(), first)
    previous = {x["id"]: x.get("photo") for x in first}
    again, px = arts(), FakePexels()
    assert ps.add_photos(px, again, previous) == 0 and px.queries == []
    assert [x["image_urls"] for x in again] == [x["image_urls"] for x in first]


def test_no_key_changes_nothing(monkeypatch):
    monkeypatch.delenv("PEXELS_API_KEY", raising=False)
    monkeypatch.setattr(ps, "api_key", lambda: "")
    a = arts()
    assert ps.add_photos(FakePexels(), a) == 0 and a[0]["image_urls"] == []
