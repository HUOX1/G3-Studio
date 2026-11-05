"""Current-schema repository round trips (Stage 8.0)."""

from g3_core.database import Database
from g3_core.repository import LibraryRepository
from g3_core.services.media_assets import MediaAssetService


def _repo(tmp_path):
    db = Database(tmp_path / "library.db")
    db.initialize()
    return LibraryRepository(db)


def test_new_database_has_current_tables(tmp_path):
    repo = _repo(tmp_path)
    with repo.database.connect() as conn:
        tables = {row["name"] for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'")}
        assert {"library_items", "games", "game_metadata", "terminal_state"} <= tables
        game_cols = {row["name"] for row in conn.execute("PRAGMA table_info(games)")}
        assert {"launch_exe", "playtime_seconds", "steam_appid", "english_name"} <= game_cols


def test_create_and_list_game_round_trip(tmp_path):
    repo = _repo(tmp_path)
    exe = tmp_path / "demo.exe"
    exe.write_bytes(b"")
    created = repo.create_game(title="Demo", launch_exe=str(exe))
    loaded = repo.get_game(created["id"])
    assert loaded is not None
    assert loaded["title"] == "Demo"
    assert loaded["launch_exe"] == str(exe)
    assert repo.list_games()[0]["id"] == created["id"]


def test_manual_cover_replaces_previous_asset(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Demo")
    auto = tmp_path / "auto.jpg"
    manual = tmp_path / "manual.png"
    auto.write_bytes(b"auto")
    manual.write_bytes(b"manual")
    service = MediaAssetService(repo, tmp_path / "cache")
    old = service.set_game_cover(game["id"], auto)
    assert old.is_file()
    latest = service.set_game_cover(game["id"], manual)
    assert latest.is_file()
    assert latest.read_bytes() == b"manual"
    assert not old.exists()
