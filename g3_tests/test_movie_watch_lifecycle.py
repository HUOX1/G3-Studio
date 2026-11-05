"""Stage 3.9: movie watcher termination and render-release event contract."""
from __future__ import annotations

import asyncio
import time
from unittest.mock import Mock

import pytest

from g3_core.backend_app import BackendApplication


class _Process:
    def __init__(self, *, fail: bool = False):
        self.fail = fail
        self.wait_calls = 0

    def wait(self) -> int:
        self.wait_calls += 1
        if self.fail:
            raise OSError("process handle lost")
        return 0


@pytest.mark.asyncio
async def test_watch_failure_still_releases_render_without_recording_time(caplog):
    app = object.__new__(BackendApplication)
    app.repository = Mock()
    events = []

    async def sink(name, payload):
        events.append((name, payload))

    app._event_sink = sink
    proc = _Process(fail=True)
    await app._watch_movie_process(proc, "movie-1", time.monotonic() - 180)
    assert proc.wait_calls == 1
    assert events == [("movie.exited", {})]
    app.repository.add_watch_seconds.assert_not_called()
    assert "Movie process watch failed" in caplog.text


@pytest.mark.asyncio
async def test_short_watch_keeps_existing_threshold_and_emits_one_exit():
    app = object.__new__(BackendApplication)
    app.repository = Mock()
    events = []

    async def sink(name, payload):
        events.append((name, payload))

    app._event_sink = sink
    await app._watch_movie_process(_Process(), "movie-2", time.monotonic())
    assert events == [("movie.exited", {})]
    app.repository.add_watch_seconds.assert_not_called()


@pytest.mark.asyncio
async def test_long_watch_emits_completed_then_exit():
    app = object.__new__(BackendApplication)
    app.repository = Mock()
    app.repository.add_watch_seconds.return_value = True
    events = []

    async def sink(name, payload):
        events.append((name, payload))

    app._event_sink = sink
    await app._watch_movie_process(_Process(), "movie-3", time.monotonic() - 125)
    assert events == [
        ("movie.watched_complete", {"item_id": "movie-3"}),
        ("movie.exited", {}),
    ]
    args = app.repository.add_watch_seconds.call_args.args
    assert args[0] == "movie-3" and args[1] >= 120


@pytest.mark.asyncio
async def test_watch_persistence_failure_still_emits_exit(caplog):
    app = object.__new__(BackendApplication)
    app.repository = Mock()
    app.repository.add_watch_seconds.side_effect = OSError("database busy")
    events = []

    async def sink(name, payload):
        events.append((name, payload))

    app._event_sink = sink
    await app._watch_movie_process(_Process(), "movie-4", time.monotonic() - 125)
    assert events == [("movie.exited", {})]
    assert "Failed to record watch seconds" in caplog.text


@pytest.mark.asyncio
async def test_watch_exit_contains_matching_play_session_id():
    app = object.__new__(BackendApplication)
    app.repository = Mock()
    events = []

    async def sink(name, payload):
        events.append((name, payload))

    app._event_sink = sink
    await app._watch_movie_process(_Process(), "movie-session", time.monotonic(), "session-123")
    assert events == [("movie.exited", {"play_session_id": "session-123"})]


@pytest.mark.asyncio
async def test_failed_watch_exit_keeps_play_session_id(caplog):
    app = object.__new__(BackendApplication)
    app.repository = Mock()
    events = []

    async def sink(name, payload):
        events.append((name, payload))

    app._event_sink = sink
    await app._watch_movie_process(_Process(fail=True), "movie-session", time.monotonic(), "session-failed")
    assert events == [("movie.exited", {"play_session_id": "session-failed"})]
    app.repository.add_watch_seconds.assert_not_called()
