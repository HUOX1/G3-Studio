"""Direct launch behavior of the current GameRuntime (Stage 8.0)."""

from pathlib import Path
import sys

import pytest

from g3_core.database import Database
from g3_core.repository import LibraryRepository
from g3_core.services.game_runtime import GameRuntime


def _repo(tmp_path):
    db = Database(tmp_path / "library.db")
    db.initialize()
    return LibraryRepository(db)


def test_runtime_launches_direct_process_without_shell(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Sleeper", launch_exe=sys.executable,
                            launch_args='-c "import sys; sys.exit(0)"',
                            working_directory=str(tmp_path))
    running = GameRuntime(repo).launch(game)
    assert running.item_id == game["id"]
    assert running.process is not None
    try:
        assert running.process.pid > 0
        assert running.process.wait(timeout=10) == 0
    finally:
        if running.process.poll() is None:
            running.process.kill()
            running.process.wait(timeout=10)


def test_runtime_rejects_missing_executable(tmp_path):
    repo = _repo(tmp_path)
    missing = tmp_path / "missing.exe"
    game = repo.create_game(title="Demo", launch_exe=str(missing))
    with pytest.raises(FileNotFoundError) as exc:
        GameRuntime(repo).launch(game)
    assert Path(str(exc.value)) == missing
