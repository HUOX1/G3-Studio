"""游戏素材目录命名契约：写入走标题目录，UUID 仅作内部标识与旧素材兜底。"""

from pathlib import Path

from PIL import Image

from g3_core.database import Database
from g3_core.repository import LibraryRepository
from g3_core.services.media_assets import (
    MediaAssetService,
    assign_game_asset_names,
    game_asset_dir_for,
    sanitize_cover_stem,
)


def _repo(tmp_path) -> LibraryRepository:
    db = Database(tmp_path / "library.db")
    db.initialize()
    return LibraryRepository(db)


def _service(tmp_path, repo) -> MediaAssetService:
    return MediaAssetService(repo, tmp_path / "cache")


def _png(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (4, 4), (10, 20, 30)).save(path)
    return path


# ── 文件名安全 ────────────────────────────────────────────
def test_sanitize_replaces_illegal_chars(tmp_path):
    assert sanitize_cover_stem('A/B:C*D?E"F<G>H|I') == "A_B_C_D_E_F_G_H_I"


def test_sanitize_strips_trailing_dots_and_spaces():
    assert sanitize_cover_stem("Doom...   ") == "Doom"


def test_sanitize_prefixes_windows_reserved_names():
    assert sanitize_cover_stem("CON") == "_CON"
    assert sanitize_cover_stem("com1") == "_com1"
    assert sanitize_cover_stem("NUL.txt") == "_NUL.txt"


def test_sanitize_empty_falls_back():
    assert sanitize_cover_stem("   ") == "Untitled"


# ── 同名分配（纯函数） ────────────────────────────────────
def test_unique_title_keeps_plain_name():
    names = assign_game_asset_names([{"id": "a", "title": "Doom"}])
    assert names["a"] == "Doom"


def test_duplicate_titles_get_readable_suffixes():
    games = [
        {"id": "a", "title": "Doom", "created_at": "2024-01-01", "release_year": 1993},
        {"id": "b", "title": "Doom", "created_at": "2024-02-01", "release_year": 2016},
    ]
    names = assign_game_asset_names(games)
    assert names["a"] == "Doom"
    assert names["b"] == "Doom (2016)"
    assert names["a"] != names["b"]


def test_duplicate_names_are_stable_across_calls():
    games = [
        {"id": "a", "title": "Doom", "created_at": "2024-01-01"},
        {"id": "b", "title": "Doom", "created_at": "2024-02-01"},
        {"id": "c", "title": "Doom", "created_at": "2024-03-01"},
    ]
    first = assign_game_asset_names(games)
    second = assign_game_asset_names(list(reversed(games)))
    assert first == second
    assert len(set(first.values())) == 3


def test_duplicate_without_year_or_platform_falls_back_to_short_id():
    games = [
        {"id": "aaaaaaaa-1111", "title": "Same", "created_at": "2024-01-01"},
        {"id": "bbbbbbbb-2222", "title": "Same", "created_at": "2024-02-01"},
    ]
    names = assign_game_asset_names(games)
    assert names["aaaaaaaa-1111"] == "Same"
    assert names["bbbbbbbb-2222"].startswith("Same (BBBBBB")
    assert "-" not in names["bbbbbbbb-2222"].split("(")[1]


# ── 写入路径 ──────────────────────────────────────────────
def test_scraped_asset_writes_to_title_dir_not_uuid(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Skyrim")
    service = _service(tmp_path, repo)
    source = _png(tmp_path / "src.png")

    target = service.set_game_asset(game["id"], source, "")

    assert target.parent.name == "Skyrim"
    assert game["id"] not in str(target.parent)
    assert not (service.covers_root / "games" / game["id"]).exists()


def test_cover_and_backdrop_share_one_dir(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Signal")
    service = _service(tmp_path, repo)
    source = _png(tmp_path / "src.png")

    cover = service.set_game_asset(game["id"], source, "")
    backdrop = service.set_game_asset(game["id"], source, "backdrop")

    assert cover.parent == backdrop.parent
    assert cover.name == "cover.png"
    assert backdrop.name == "backdrop.png"


def test_repeated_scrape_reuses_same_dir(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Hades")
    service = _service(tmp_path, repo)
    source = _png(tmp_path / "src.png")

    first = service.set_game_asset(game["id"], source, "")
    second = service.set_game_asset(game["id"], source, "backdrop")
    games_dir = service.covers_root / "games"
    dirs = [p.name for p in games_dir.iterdir() if p.is_dir()]

    assert first.parent == second.parent
    assert dirs == ["Hades"]


def test_title_with_illegal_chars_creates_safe_dir(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title='Bad/Name: *?')
    service = _service(tmp_path, repo)

    target = service.set_game_asset(game["id"], _png(tmp_path / "src.png"), "")

    assert target.parent.name.startswith("Bad_Name")
    assert all(ch not in target.parent.name for ch in '<>:"/\\|?*')


def test_same_title_games_write_to_distinct_dirs(tmp_path):
    repo = _repo(tmp_path)
    exe_a = tmp_path / "a.exe"
    exe_b = tmp_path / "b.exe"
    exe_a.write_bytes(b"")
    exe_b.write_bytes(b"")
    first = repo.create_game(title="Doom", release_year="1993")
    second = repo.create_game(title="Doom", release_year="2016")
    service = _service(tmp_path, repo)
    source = _png(tmp_path / "src.png")

    dir_a = service.set_game_asset(first["id"], source, "").parent
    dir_b = service.set_game_asset(second["id"], source, "").parent

    assert dir_a != dir_b
    names = {dir_a.name, dir_b.name}
    assert "Doom" in names
    assert any(name.startswith("Doom (") for name in names)


# ── 读取兼容 ──────────────────────────────────────────────
def test_legacy_uuid_dir_is_still_readable(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Legacy")
    service = _service(tmp_path, repo)
    legacy = service.covers_root / "games" / game["id"]
    legacy.mkdir(parents=True, exist_ok=True)
    _png(legacy / "cover.png")

    dirs = service.game_asset_dirs(game)

    assert dirs[0].name == "Legacy"
    assert legacy in dirs
    assert (legacy / "cover.png").is_file()


def test_title_dir_takes_priority_over_uuid_dir(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Dual")
    service = _service(tmp_path, repo)
    uuid_dir = service.covers_root / "games" / game["id"]
    uuid_dir.mkdir(parents=True, exist_ok=True)
    title_dir = service.ensure_game_asset_dir(game)

    dirs = service.game_asset_dirs(game)

    assert dirs[0] == title_dir
    assert dirs[0] != uuid_dir


def test_module_helper_matches_service_path(tmp_path):
    repo = _repo(tmp_path)
    game = repo.create_game(title="Shared")
    service = _service(tmp_path, repo)
    record = repo.get_game(game["id"])

    assert game_asset_dir_for(repo, service.covers_root, record) == service.game_asset_dir(record)
