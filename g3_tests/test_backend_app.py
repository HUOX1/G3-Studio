from __future__ import annotations

import asyncio
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest

from g3_core.backend_app import BackendApplication
from g3_core.paths import TerminalPaths


def _paths(tmp_path: Path) -> TerminalPaths:
    root = tmp_path / "G3"
    return TerminalPaths(
        root=root,
        database=root / "library.db",
        assets=root / "assets",
        cache=root / "cache",
        logs=root / "logs",
        settings=root / "settings.json",
        covers=root / "covers",
        covers_games=root / "covers/games",
        covers_movies=root / "covers/movies",
        media=root / "media",
        tmdb_config=root / "tmdb.json",
        sgdb_config=root / "sgdb.json",
        psn_config=root / "psn.json",
    )


@pytest.mark.asyncio
async def test_backend_can_create_list_and_restore_state(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    exe = tmp_path / "demo.exe"
    exe.write_bytes(b"")

    created = await app.handle_command(
        "game.create",
        {"title": "Demo", "executable_path": str(exe)},
    )
    games = await app.handle_command("library.games.list", {})
    assert games[0]["id"] == created["id"]
    assert games[0]["title"] == "Demo"

    await app.handle_command(
        "state.update",
        {"last_section": "games", "last_item_id": created["id"]},
    )
    state = await app.handle_command("state.get", {})
    assert state == {"last_section": "games", "last_item_id": created["id"]}


@pytest.mark.asyncio
async def test_game_play_correlates_running_and_exited_events(tmp_path, monkeypatch):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    game = await app.handle_command(
        "game.create",
        {"title": "Sleeper", "launch_exe": sys.executable},
    )
    events: list[tuple[str, dict]] = []

    async def capture(event_type: str, payload: dict) -> None:
        events.append((event_type, payload))

    async def fake_watcher(running, _before_pids, session_id):
        await app._event_sink("game.running", {"item_id": running.item_id,
                                                   "play_session_id": session_id})
        await app._event_sink("game.exited", {"item_id": running.item_id,
                                                  "play_session_id": session_id})

    app.set_event_sink(capture)
    monkeypatch.setattr(app.game_runtime, "launch", lambda _game: SimpleNamespace(
        item_id=game["id"], monitorable=True))
    monkeypatch.setattr(app, "_watch_game_process", fake_watcher)
    result = await app.handle_command("game.play", {"id": game["id"]})
    await asyncio.gather(*tuple(app._movie_tasks))
    assert result["item_id"] == game["id"]
    assert result["monitorable"] is True
    assert len(result["play_session_id"]) == 32
    assert [kind for kind, _ in events] == ["game.running", "game.exited"]
    assert all(payload["play_session_id"] == result["play_session_id"]
               for _, payload in events)


@pytest.mark.asyncio
async def test_library_games_list_exposes_explicitly_imported_cover(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    game_dir = tmp_path / "RainWorld"
    game_dir.mkdir()
    exe = game_dir / "RainWorld.exe"
    exe.write_bytes(b"")
    cover = game_dir / "cover.jpg"
    cover.write_bytes(b"cover")

    await app.handle_command(
        "game.create",
        {"title": "Rain World", "launch_exe": str(exe),
         "cover_source": str(cover)},
    )
    games = await app.handle_command("library.games.list", {})

    assert Path(games[0]["cover"]).is_file()
    assert Path(games[0]["cover"]).read_bytes() == cover.read_bytes()


@pytest.mark.asyncio
async def test_game_theme_palette_command_uses_resolved_game_cover(tmp_path):
    from PIL import Image

    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    source_cover = tmp_path / "cover.png"
    Image.new("RGB", (40, 60), (205, 42, 48)).save(source_cover, format="PNG")
    game = await app.handle_command(
        "game.create",
        {"title": "Theme Sample", "cover_source": str(source_cover)},
    )

    result = await app.handle_command("game.theme.palette", {"id": game["id"]})

    assert result["item_id"] == game["id"]
    assert result["palette"]["status"] == "ready"
    assert set(result["palette"]["colors"]) == {"accent", "secondary", "surface", "ambient", "shadow"}


@pytest.mark.asyncio
async def test_game_theme_palette_prefers_hero_and_falls_back_to_cover(tmp_path):
    from PIL import Image

    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    cover_source = tmp_path / "cover.png"
    hero_source = tmp_path / "hero.png"
    Image.new("RGB", (48, 72), (220, 35, 40)).save(cover_source, format="PNG")
    Image.new("RGB", (160, 90), (22, 78, 218)).save(hero_source, format="PNG")
    game = await app.handle_command(
        "game.create",
        {"title": "Hero Theme Sample", "cover_source": str(cover_source)},
    )
    app.media.set_game_asset(game["id"], hero_source, "backdrop")

    hero_result = await app.handle_command("game.theme.palette", {"id": game["id"]})
    assert hero_result["source"] == "hero"
    assert hero_result["palette"]["status"] == "ready"

    mono_hero = tmp_path / "mono_hero.png"
    Image.new("RGB", (160, 90), (70, 70, 70)).save(mono_hero, format="PNG")
    app.media.set_game_asset(game["id"], mono_hero, "backdrop")
    cover_result = await app.handle_command("game.theme.palette", {"id": game["id"]})
    assert cover_result["source"] == "cover"
    assert cover_result["palette"]["status"] == "ready"


@pytest.mark.asyncio
async def test_game_theme_palette_command_returns_fallback_without_cover(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    game = await app.handle_command("game.create", {"title": "No Cover"})

    result = await app.handle_command("game.theme.palette", {"id": game["id"]})

    assert result["palette"]["status"] == "fallback"
    assert result["palette"]["reason"] == "missing_cover"


@pytest.mark.asyncio
async def test_legacy_application_theme_commands_are_removed(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    with pytest.raises(KeyError, match="unknown command"):
        await app.handle_command("themes.list", {})
    with pytest.raises(KeyError, match="unknown command"):
        await app.handle_command("theme.current", {})
