"""SGDB smart Hero optimization and non-blocking progress regression tests."""
import io
import os
from pathlib import Path

import pytest
from PIL import Image

from g3_core.backend_app import BackendApplication
from g3_core.paths import TerminalPaths
from g3_core.services.sgdb_hero_optimizer import optimize_hero_image


def _png(width=2048, height=700):
    image = Image.frombytes("RGB", (width, height), os.urandom(width * height * 3))
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def _paths(root):
    return TerminalPaths(
        root=root, database=root / "library.db", assets=root / "assets",
        cache=root / "cache", logs=root / "logs",
        settings=root / "settings.json", covers=root / "covers",
        covers_games=root / "covers/games", covers_movies=root / "covers/movies",
        media=root / "media", tmdb_config=root / "tmdb.json",
        sgdb_config=root / "sgdb.json", psn_config=root / "psn.json",
    )


def test_small_4k_hero_is_kept_without_reencode():
    source = b"tiny source image"
    result = optimize_hero_image(source, "jpg")
    assert result[:3] == (source, "jpg", False)


def test_large_hero_is_resized_and_encoded_as_webp():
    source = _png()
    assert len(source) > 2 * 1024 * 1024
    result, extension, optimized, original = optimize_hero_image(source, "png")
    assert optimized and extension == "webp"
    assert original == (2048, 700)
    assert len(result) < len(source) * 0.9
    with Image.open(io.BytesIO(result)) as image:
        assert image.size[0] <= 1920 and image.size[1] <= 620
        assert image.width / image.height == pytest.approx(2048 / 700, rel=0.01)


def test_animated_hero_is_preserved():
    first = Image.new("RGB", (24, 24), "red")
    second = Image.new("RGB", (24, 24), "blue")
    stream = io.BytesIO()
    first.save(stream, format="WEBP", save_all=True, append_images=[second], duration=120)
    source = stream.getvalue() + b"\x00" * (2 * 1024 * 1024 + 1)
    data, ext, optimized, _ = optimize_hero_image(source, "webp")
    assert data == source and ext == "webp" and not optimized


@pytest.mark.asyncio
async def test_sgdb_apply_emits_real_download_progress_and_optimizes_hero(tmp_path, monkeypatch):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    exe = tmp_path / "game.exe"
    exe.write_bytes(b"")
    game = await app.handle_command("game.create", {"title": "Test", "launch_exe": str(exe)})
    source = _png()
    events = []

    async def capture(kind, payload):
        events.append((kind, payload))

    class FakeClient:
        def download_image(self, url, progress=None):
            assert url == "https://example.test/hero.png"
            if progress:
                progress(0, len(source))
                progress(len(source) // 2, len(source))
                progress(len(source), len(source))
            return source

    app.set_event_sink(capture)
    monkeypatch.setattr(app, "_get_sgdb_client", lambda: FakeClient())
    result = await app.handle_command("sgdb.apply", {
        "id": game["id"], "sgdb_id": 123, "asset_type": "hero",
        "url": "https://example.test/hero.png", "operation_id": "test-batch",
    })
    assert result["optimized"] is True
    assert result["original_bytes"] == len(source)
    assert result["final_bytes"] < len(source)
    kinds = [kind for kind, _ in events]
    assert "sgdb.apply.progress" in kinds
    phases = [payload["phase"] for kind, payload in events if kind == "sgdb.apply.progress"]
    assert phases[0] == "download"
    assert "optimize" in phases and "save" in phases
    assert kinds[-1] == "library.changed"
    hero = tmp_path / "covers" / "games" / game["id"] / "backdrop.webp"
    assert hero.is_file() and hero.suffix == ".webp"
    with Image.open(hero) as img:
        assert img.width <= 1920


@pytest.mark.asyncio
async def test_sgdb_apply_small_hero_keeps_original_bytes(tmp_path, monkeypatch):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    exe = tmp_path / "game.exe"
    exe.write_bytes(b"")
    game = await app.handle_command("game.create", {"title": "Test", "launch_exe": str(exe)})
    stream = io.BytesIO()
    Image.new("RGB", (1920, 620), "purple").save(stream, format="JPEG", quality=88)
    source = stream.getvalue()

    class FakeClient:
        def download_image(self, url, progress=None):
            if progress:
                progress(len(source), len(source))
            return source

    monkeypatch.setattr(app, "_get_sgdb_client", lambda: FakeClient())
    result = await app.handle_command("sgdb.apply", {
        "id": game["id"], "asset_type": "hero", "url": "https://example.test/hero.jpg",
    })
    assert not result["optimized"]
    assert result["original_bytes"] == result["final_bytes"] == len(source)
    hero = tmp_path / "covers" / "games" / game["id"] / "backdrop.jpg"
    assert hero.is_file() and hero.read_bytes() == source

@pytest.mark.asyncio
async def test_thumbnail_progress_events_are_streamed_per_item(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    events = []

    async def capture(kind, payload):
        events.append((kind, payload))

    stream = io.BytesIO()
    Image.new("RGB", (20, 20), "red").save(stream, format="PNG")
    png = stream.getvalue()

    class FakeClient:
        def download_image(self, url, progress=None):
            return png

    app.set_event_sink(capture)
    await app._download_thumbs_bg(FakeClient(), [
        {"url": "https://example.test/a.png", "thumb": "https://example.test/a.png"},
        {"url": "https://example.test/b.png", "thumb": "https://example.test/b.png"},
    ], "hero", 321, "batch-test")
    assert len(events) == 2
    assert [event[1]["done"] for event in events] == [1, 2]
    assert all(event[1]["batch_id"] == "batch-test" for event in events)
    assert all(event[1]["sgdb_id"] == 321 for event in events)
    assert all(Path(event[1]["thumb_local"]).is_file() for event in events)


@pytest.mark.asyncio
async def test_selected_hero_size_uses_head_only(tmp_path, monkeypatch):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()

    class FakeClient:
        def image_content_length(self, url):
            assert url == "https://example.test/hero.png"
            return 8 * 1024 * 1024

    monkeypatch.setattr(app, "_get_sgdb_client", lambda: FakeClient())
    data = await app.handle_command("sgdb.asset.info", {"url": "https://example.test/hero.png"})
    assert data["file_size"] == 8 * 1024 * 1024


@pytest.mark.asyncio
async def test_corrupt_cached_thumbnail_is_refetched_before_frontend_receives_it(tmp_path, monkeypatch):
    import hashlib

    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    url = "https://example.test/thumb.jpg"
    cache = tmp_path / "cache" / "sgdb_thumb"
    cache.mkdir(parents=True)
    stale = cache / (hashlib.sha1(url.encode()).hexdigest()[:16] + ".jpg")
    stale.write_bytes(b"<html>temporary error</html>")
    png_stream = io.BytesIO()
    Image.new("RGB", (20, 20), "blue").save(png_stream, format="PNG")
    valid = png_stream.getvalue()
    events = []

    class FakeClient:
        def get_heroes(self, sgdb_id):
            return [{"url": url, "thumb": url}]

        def download_image(self, requested):
            assert requested == url
            return valid

    async def capture(kind, payload):
        events.append((kind, payload))

    monkeypatch.setattr(app, "_get_sgdb_client", lambda: FakeClient())
    app.set_event_sink(capture)
    result = await app.handle_command("sgdb.assets", {
        "sgdb_id": 321, "asset_type": "hero", "batch_id": "test-stale",
    })
    assert result["items"][0]["thumb_local"] == ""
    assert not stale.exists()
    await next(iter(app._sgdb_thumb_tasks))
    ready = [payload for kind, payload in events if kind == "sgdb.thumb_ready"]
    assert len(ready) == 1
    assert Path(ready[0]["thumb_local"]).read_bytes() == valid


@pytest.mark.asyncio
async def test_invalid_thumbnail_response_is_not_cached(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    events = []

    class FakeClient:
        def download_image(self, url):
            return b"<html>rate limit</html>"

    async def capture(kind, payload):
        events.append((kind, payload))

    app.set_event_sink(capture)
    await app._download_thumbs_bg(FakeClient(), [{
        "url": "https://example.test/fail", "thumb": "https://example.test/fail",
    }], "hero", 321, "invalid-test")
    assert events[0][1]["thumb_local"] == ""
    assert not list((tmp_path / "cache" / "sgdb_thumb").glob("*"))
