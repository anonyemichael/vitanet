"""Video catalogue: trusted channels only, no live / unembeddable / very long videos, feed mixing, search, fallback."""
import pytest

from app.services import video_service as vs


class FakeYouTube:
    """Answers the 4 YouTube Data API calls the service makes, like the real API."""
    def __init__(self):
        self.calls = []
        seed_items = [{"id": s["id"], "snippet": {"channelId": f"UC_{s['channel']}", "channelTitle": s["channel"],
                                                   "title": s["title"], "publishedAt": "2024-01-01T00:00:00Z",
                                                   "description": "", "liveBroadcastContent": "none"},
                       "contentDetails": {"duration": f"PT{s['duration_s']}S"}, "statistics": {"viewCount": "100"},
                       "status": {"embeddable": True, "privacyStatus": "public"}} for s in vs.SEEDS]
        def up(vid, ch, title, dur, published, live="none", embeddable=True):
            return {"id": vid, "snippet": {"channelId": ch, "channelTitle": ch.replace("UC_", ""), "title": title,
                                           "publishedAt": published, "description": "How to help.\nKeep the person calm and call 112 if worse.",
                                           "liveBroadcastContent": live},
                    "contentDetails": {"duration": dur}, "statistics": {"viewCount": "5000"},
                    "status": {"embeddable": embeddable, "privacyStatus": "public"}}
        uploads = [up("n1", "UC_NHS", "How to treat a burn", "PT2M10S", "2026-11-10T00:00:00Z"),
                   up("n2", "UC_NHS", "Signs of a stroke", "PT45S", "2026-11-12T00:00:00Z"),
                   up("n3", "UC_NHS", "Live Q&A", "PT0S", "2026-11-13T00:00:00Z", live="live"),
                   up("w1", "UC_WHO", "Malaria: what you need to know", "PT3M", "2026-11-11T00:00:00Z"),
                   up("w2", "UC_WHO", "Press conference", "PT1H10M", "2026-11-14T00:00:00Z"),
                   up("w3", "UC_WHO", "Handwashing", "PT1M", "2026-11-09T00:00:00Z", embeddable=False),
                   up("t1", "UC_TED", "A talk about cities", "PT12M", "2026-11-15T00:00:00Z")]
        self.items = {i["id"]: i for i in seed_items + uploads}
        self.playlists = {"UU_NHS": ["n1", "n2", "n3"], "UU_WHO": ["w1", "w2", "w3"], "UU_TED": ["t1"]}

    def get(self, url, params=None, timeout=None):
        self.calls.append(url.rsplit("/", 1)[-1])
        path = url.rsplit("/", 1)[-1]
        if path == "videos":
            data = {"items": [self.items[i] for i in params["id"].split(",") if i in self.items]}
        elif path == "channels" and "forHandle" in params:
            data = {"items": [{"id": "UC_WHO", "snippet": {"title": "World Health Organization"}}]} \
                if params["forHandle"] == "@WHO" else {"items": []}
        elif path == "channels":
            data = {"items": [{"id": c, "contentDetails": {"relatedPlaylists": {"uploads": c.replace("UC_", "UU_")}}}
                              for c in params["id"].split(",")]}
        elif path == "playlistItems":
            data = {"items": [{"contentDetails": {"videoId": v}} for v in self.playlists.get(params["playlistId"], [])]}
        else:
            raise AssertionError(path)
        return type("R", (), {"json": lambda s: data, "raise_for_status": lambda s: None})()


@pytest.fixture
def fresh(monkeypatch, tmp_path):
    monkeypatch.setattr(vs, "CACHE_PATH", tmp_path / "videos.json")
    monkeypatch.setenv("YOUTUBE_API_KEY", "test-key")
    monkeypatch.setattr(vs, "_state", {"videos": [], "updated": 0.0, "channels": [], "refreshing": False, "error": None})
    monkeypatch.setattr(vs, "_ensure_fresh_in_background", lambda: None)


def test_catalogue_keeps_only_trusted_playable_videos(fresh):
    assert vs.refresh(FakeYouTube()) is True
    ids = {v["id"] for v in vs.catalog()}
    assert {"n1", "n2", "w1"} <= ids
    assert not ids & {"n3", "w2", "w3", "t1"}          # live, 70-min press conference, not embeddable, TED upload
    assert {s["id"] for s in vs.SEEDS} <= ids           # the hand-checked videos stay
    n2 = next(v for v in vs.catalog() if v["id"] == "n2")
    assert n2["is_short"] and n2["category"] == "Cardio & Vitals" and n2["views"] == 5000
    assert vs.status()["channels"] and vs.CACHE_PATH.exists()


def test_feed_is_newest_first_with_channels_taking_turns(fresh):
    vs.refresh(FakeYouTube())
    page = vs.feed(kind="long", limit=3)["videos"]
    assert [v["id"] for v in page][:2] in (["n1", "w1"], ["w1", "n1"])
    assert all(not v["is_short"] for v in vs.feed(kind="long", limit=50)["videos"])


def test_feed_pages_never_repeat(fresh):
    vs.refresh(FakeYouTube())
    seen, cursor = [], 0
    while cursor is not None:
        page = vs.feed(limit=7, cursor=cursor)
        seen += [v["id"] for v in page["videos"]]
        cursor = page["next_cursor"]
    assert len(seen) == len(set(seen)) == page["total"]


def test_search_only_inside_trusted_catalogue(fresh):
    vs.refresh(FakeYouTube())
    assert [v["id"] for v in vs.search("malaria")["videos"]] == ["w1"]
    assert vs.search("cities")["videos"] == []                      # the TED upload was never pulled
    assert vs.search("burn treat")["videos"][0]["id"] == "n1"


def test_no_key_serves_the_hand_checked_videos(fresh, monkeypatch):
    monkeypatch.delenv("YOUTUBE_API_KEY")
    monkeypatch.setattr(vs, "api_key", lambda: "")
    assert vs.refresh(FakeYouTube()) is False
    vids = vs.feed(limit=50)["videos"]
    assert len(vids) == len(vs.SEEDS) and vs.status()["serving"] == "curated"


def test_failed_refresh_keeps_the_old_copy(fresh):
    vs.refresh(FakeYouTube())
    before = len(vs.catalog())
    class Broken:
        def get(self, *a, **k): raise RuntimeError("quota exceeded")
    assert vs.refresh(Broken()) is False and len(vs.catalog()) == before and "quota" in vs.status()["error"]


@pytest.mark.parametrize("iso,s", [("PT45S", 45), ("PT2M10S", 130), ("PT1H10M", 4200), ("P0D", 0), ("", 0)])
def test_parse_duration(iso, s):
    assert vs.parse_duration(iso) == s


def test_routes(fresh):
    from fastapi.testclient import TestClient
    from app.main import app
    vs.refresh(FakeYouTube())
    c = TestClient(app)
    r = c.get("/videos/feed?kind=short&limit=5")
    assert r.status_code == 200 and all(v["is_short"] for v in r.json()["videos"]) and "max-age" in r.headers["cache-control"]
    assert c.get("/videos/search?q=malaria").json()["videos"][0]["id"] == "w1"
    assert c.get("/videos/feed?kind=bad").status_code == 422
