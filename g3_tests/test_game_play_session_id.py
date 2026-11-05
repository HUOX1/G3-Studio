"""Stage 6.2: game.play response and watcher event correlation."""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from pathlib import Path
import os
from types import SimpleNamespace

import pytest

from g3_core.backend_app import BackendApplication
from g3_core.paths import TerminalPaths


def _paths(tmp_path: Path) -> TerminalPaths:
    root = tmp_path / "G3"
    return TerminalPaths(root=root, database=root / "library.db", assets=root / "assets",
                         cache=root / "cache", logs=root / "logs",
                         settings=root / "settings.json", covers=root / "covers",
                         covers_games=root / "covers" / "games", covers_movies=root / "covers" / "movies",
                         media=root / "media", tmdb_config=root / "tmdb.json",
                         sgdb_config=root / "sgdb.json", psn_config=root / "psn.json")


@pytest.mark.asyncio
async def test_two_launches_of_same_game_receive_distinct_session_ids(tmp_path, monkeypatch):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    created = await app.handle_command("game.create", {"title": "Test", "executable_path": __file__})
    item_id = created["id"]
    observed = []

    def launch(game):
        return SimpleNamespace(item_id=item_id, monitorable=True)

    async def watcher(running, before_pids, session_id):
        observed.append((running.item_id, session_id))

    monkeypatch.setattr(app.game_runtime, "launch", launch)
    monkeypatch.setattr(app, "_watch_game_process", watcher)
    first = await app.handle_command("game.play", {"id": item_id})
    second = await app.handle_command("game.play", {"id": item_id})
    await asyncio.sleep(0)
    assert first["item_id"] == second["item_id"] == item_id
    assert first["monitorable"] is second["monitorable"] is True
    assert len(first["play_session_id"]) == len(second["play_session_id"]) == 32
    assert first["play_session_id"] != second["play_session_id"]
    assert observed == [(item_id, first["play_session_id"]), (item_id, second["play_session_id"])]
    await asyncio.gather(*tuple(app._movie_tasks))


@pytest.mark.asyncio
async def test_unmonitorable_launch_returns_id_without_running_event(tmp_path, monkeypatch):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    created = await app.handle_command("game.create", {"title": "Test", "executable_path": __file__})
    item_id = created["id"]
    events = []

    async def sink(kind, payload):
        events.append((kind, payload))

    app.set_event_sink(sink)
    monkeypatch.setattr(app.game_runtime, "launch", lambda game: SimpleNamespace(item_id=item_id, monitorable=False))
    result = await app.handle_command("game.play", {"id": item_id})
    await asyncio.gather(*tuple(app._movie_tasks))
    assert result["monitorable"] is False
    assert len(result["play_session_id"]) == 32
    assert events == []


@pytest.mark.skipif(os.name == "nt", reason="non-Windows direct-process watcher path")
@pytest.mark.asyncio
async def test_non_windows_watcher_events_share_session_id(tmp_path):
    app = BackendApplication(_paths(tmp_path))
    app.initialize()
    events = []

    async def sink(kind, payload):
        events.append((kind, payload))

    app.set_event_sink(sink)

    class FakeProcess:
        def wait(self):
            return 0

    running = SimpleNamespace(item_id="game-a", monitorable=True, process=FakeProcess(),
                              started_at=datetime.now(timezone.utc))
    await app._watch_game_process(running, set(), "session-a")
    assert [kind for kind, _ in events] == ["game.running", "game.exited"]
    assert all(payload["play_session_id"] == "session-a" for _, payload in events)
    assert all(payload["item_id"] == "game-a" for _, payload in events)
