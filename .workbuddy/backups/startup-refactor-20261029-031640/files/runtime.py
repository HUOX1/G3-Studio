from __future__ import annotations

import asyncio
import logging
import os
import secrets
from pathlib import Path
import subprocess
import time

from .startup_splash import NativeWindowGate, create_startup_splash

from g3_core.backend_app import BackendApplication
from g3_core.logging_setup import configure_logging
from g3_core.paths import TerminalPaths
from g3_core.websocket_server import HOST, PORT, TerminalWebSocketServer

from .discovery import resolve_godot_executable


logger = logging.getLogger("g3.launcher")


def build_godot_command(executable: Path, project_directory: Path) -> list[str]:
    return [str(Path(executable).resolve()), "--path", str(Path(project_directory).resolve())]


async def run_terminal(
    *,
    repo_root: Path | None = None,
    paths: TerminalPaths | None = None,
) -> int:
    repository_root = (
        Path(repo_root).resolve()
        if repo_root is not None
        else Path(__file__).resolve().parent.parent
    )
    splash = None
    ready_signal: Path | None = None
    runtime_paths = paths or TerminalPaths.from_environment()
    runtime_paths.ensure()
    configure_logging(runtime_paths.logs)

    builtin_themes = repository_root / "g3_frontend" / "themes"
    frontend = repository_root / "g3_frontend"
    if not (frontend / "project.godot").is_file():
        raise FileNotFoundError(frontend / "project.godot")

    app = BackendApplication(runtime_paths, builtin_theme_root=builtin_themes)
    app.initialize()
    app.start_background_tasks()
    godot_executable = resolve_godot_executable(app.settings)
    app.settings.save(runtime_paths.settings)

    session_token = secrets.token_urlsafe(32)
    server = TerminalWebSocketServer(app.handle_command, host=HOST, port=PORT, token=session_token)
    app.set_event_sink(server.broadcast)
    await server.start()
    logger.info("Backend listening on ws://%s:%d", HOST, PORT)

    creationflags = 0
    if os.name == "nt":
        creationflags = int(getattr(subprocess, "CREATE_NO_WINDOW", 0))
    process: subprocess.Popen | None = None
    window_gate: NativeWindowGate | None = None
    try:
        command = build_godot_command(godot_executable, frontend)
        logger.info("Starting Godot frontend: %s", godot_executable)
        splash = create_startup_splash()
        if splash is not None:
            splash.set_status("正在启动 G3 图形界面")
        ready_signal = runtime_paths.cache / f"startup-ready-{os.getpid()}-{secrets.token_hex(8)}.flag"
        ready_signal.unlink(missing_ok=True)
        diag_file = runtime_paths.logs / "startup_window_diagnostic.txt"
        diag_file.write_text("G3 startup window diagnostic\n", encoding="utf-8")
        child_env = {**os.environ, "G3_WS_TOKEN": session_token, "G3_STARTUP_READY_FILE": str(ready_signal), "G3_STARTUP_DIAG_FILE": str(diag_file)}
        process = subprocess.Popen(
            command,
            cwd=str(repository_root),
            shell=False,
            creationflags=creationflags,
            env=child_env,
        )
        if splash is not None and os.name == "nt":
            try:
                window_gate = NativeWindowGate(process.pid)
            except Exception:
                logger.warning("Could not initialize native window gate; continuing without external splash.", exc_info=True)
                splash.close()
                splash = None

        if splash is not None and window_gate is not None:
            # Keep the external splash visible while repeatedly hiding any native
            # top-level window created by Godot during startup.
            deadline = time.monotonic() + 35.0
            splash_started = time.monotonic()
            ready = False
            last_window_state: tuple[int, ...] | None = None
            while process.poll() is None:
                splash.pump()
                windows = tuple(window_gate._windows())
                if windows != last_window_state:
                    with diag_file.open("a", encoding="utf-8") as diag:
                        diag.write(f"launcher t={time.monotonic():.3f} native_windows={windows}\n")
                    last_window_state = windows
                window_gate.hide()
                if ready_signal.exists():
                    ready = True
                    # The signal is written after Godot's first post-draw callback;
                    # allow a short settling period before handing over the screen.
                    settle_until = max(splash_started + 1.2, time.monotonic() + 0.8)
                    while process.poll() is None and time.monotonic() < settle_until:
                        splash.pump()
                        window_gate.hide()
                        await asyncio.sleep(0.02)
                    break
                if time.monotonic() >= deadline:
                    logger.warning("G3 frontend readiness signal timed out; revealing the window as a fallback.")
                    break
                await asyncio.sleep(0.02)
            with diag_file.open("a", encoding="utf-8") as diag:
                diag.write(f"launcher t={time.monotonic():.3f} handoff ready={ready} process_returncode={process.poll()}\n")
            window_gate.reveal()
            splash.close()
            splash = None
            if not ready and process.poll() is not None:
                return int(process.returncode or 0)
        return int(await asyncio.to_thread(process.wait))
    finally:
        if splash is not None:
            splash.close()
        if ready_signal is not None:
            ready_signal.unlink(missing_ok=True)
        if process is not None and process.poll() is None:
            process.terminate()
        await server.close()
        await app.close_background_tasks()
        logger.info("Terminal launcher stopped")
