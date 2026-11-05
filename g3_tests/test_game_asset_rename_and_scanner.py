"""P0 修复回归：改名素材迁移 + Steam 扫描器统一写入。

改名契约：更新前只读收集（标题目录优先、UUID 兜底），更新成功后经
set_game_asset 原子写入新标题目录；旧目录不删除、UUID 不再写入。
扫描器契约：任意扩展名已存在即跳过（不覆盖用户素材），写入失败保留原文件。
"""

from pathlib import Path

import pytest
from PIL import Image

from g3_core.backend_app import BackendApplication
from g3_core.database import Database
from g3_core.paths import TerminalPaths
from g3_core.repository import LibraryRepository
from g3_core.services.media_assets import MediaAssetService
from g3_core.services.steam_library_scanner import SteamLibraryScanner


def _repo(tmp_path) -> LibraryRepository:
    db = Database(tmp_path / "library.db")
    db.initialize()
    return LibraryRepository(db)


def _service(tmp_path, repo) -> MediaAssetService:
    return MediaAssetService(repo, tmp_path / "cache")


def _png(path: Path, color=(10, 20, 30)) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (4, 4), color).save(path)
    return path


def _app(tmp_path, monkeypatch) -> BackendApplication:
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    paths = TerminalPaths.from_environment().ensure()
    app = BackendApplication(paths)
    app.database.initialize()
    return app


# ── 改名迁移 ──────────────────────────────────────────────
@pytest.mark.asyncio
async def test_rename_follows_assets_and_keeps_id(tmp_path, monkeypatch):
    app = _app(tmp_path, monkeypatch)
    created = await app.handle_command(
        "game.create", {"title": "Hades", "executable_path": str(tmp_path / "a.exe")}
    )
    gid = created["id"]
    app.media.set_game_cover(gid, _png(tmp_path / "c.png", (255, 0, 0)))
    old_dir = tmp_path / "G3" / "covers" / "games" / "Hades"
    assert (old_dir / "cover.png").is_file()

    result = await app.handle_command(
        "game.metadata.update", {"id": gid, "title": "Hades II"}
    )

    new_dir = tmp_path / "G3" / "covers" / "games" / "Hades II"
    assert (new_dir / "cover.png").read_bytes() == (old_dir / "cover.png").read_bytes()
    # 旧目录原样保留
    assert (old_dir / "cover.png").is_file()
    # UUID 目录从未创建
    assert not (tmp_path / "G3" / "covers" / "games" / gid).exists()
    # 数据库身份不变
    assert result["id"] == gid


@pytest.mark.asyncio
async def test_rename_with_same_title_target_gets_suffix(tmp_path, monkeypatch):
    app = _app(tmp_path, monkeypatch)
    first = await app.handle_command(
        "game.create", {"title": "Doom", "executable_path": str(tmp_path / "a.exe")}
    )
    second = await app.handle_command(
        "game.create", {"title": "Quake", "executable_path": str(tmp_path / "b.exe")}
    )
    app.media.set_game_cover(first["id"], _png(tmp_path / "d.png", (0, 0, 255)))
    app.media.set_game_cover(second["id"], _png(tmp_path / "q.png", (0, 255, 0)))

    await app.handle_command(
        "game.metadata.update",
        {"id": second["id"], "title": "Doom", "release_year": "2016"},
    )

    dirs = sorted(p.name for p in (tmp_path / "G3" / "covers" / "games").iterdir())
    assert "Doom" in dirs
    assert "Doom (2016)" in dirs
    # 同名两游戏目录隔离，先入库者不被挤走
    assert (tmp_path / "G3" / "covers" / "games" / "Doom").is_dir()
    assert (
        tmp_path / "G3" / "covers" / "games" / "Doom (2016)" / "cover.png"
    ).is_file()
    assert first["id"] != second["id"]


@pytest.mark.asyncio
async def test_rename_failure_keeps_originals_readable(tmp_path, monkeypatch):
    app = _app(tmp_path, monkeypatch)
    created = await app.handle_command(
        "game.create", {"title": "Old", "executable_path": str(tmp_path / "a.exe")}
    )
    gid = created["id"]
    app.media.set_game_cover(gid, _png(tmp_path / "c.png"))

    def boom(*a, **k):
        raise RuntimeError("db down")

    monkeypatch.setattr(app.repository, "update_game_metadata", boom)
    with pytest.raises(RuntimeError):
        await app.handle_command("game.metadata.update", {"id": gid, "title": "New"})

    # 改名失败：DB 标题未变，素材仍可从原标题目录读取
    assert app.repository.get_game(gid)["title"] == "Old"
    assert (tmp_path / "G3" / "covers" / "games" / "Old" / "cover.png").is_file()
    assert app._game_to_dict(app.repository.get_game(gid))["cover"]


@pytest.mark.asyncio
async def test_rename_migrates_screenshots_and_uuid_assets(tmp_path, monkeypatch):
    app = _app(tmp_path, monkeypatch)
    created = await app.handle_command(
        "game.create", {"title": "Sky", "executable_path": str(tmp_path / "a.exe")}
    )
    gid = created["id"]
    # 截图在规范标题目录；背景图只在旧 UUID 目录（修复前遗留）
    shots = tmp_path / "G3" / "covers" / "games" / "Sky" / "screenshots"
    (shots / "365").mkdir(parents=True)
    (shots / "365" / "shot1.jpg").write_bytes(b"shot")
    uuid_dir = tmp_path / "G3" / "covers" / "games" / gid
    uuid_dir.mkdir()
    (uuid_dir / "backdrop.webp").write_bytes(b"newbackdrop")

    await app.handle_command("game.metadata.update", {"id": gid, "title": "Skyrim"})

    new_dir = tmp_path / "G3" / "covers" / "games" / "Skyrim"
    assert (new_dir / "screenshots" / "365" / "shot1.jpg").read_bytes() == b"shot"
    assert (new_dir / "backdrop.webp").read_bytes() == b"newbackdrop"
    # 旧目录原样保留
    assert (shots / "365" / "shot1.jpg").is_file()
    assert (uuid_dir / "backdrop.webp").is_file()


# ── 扩展名替换与失败安全 ──────────────────────────────────
def test_ext_replacement_cleans_same_name_old_files(tmp_path):
    repo = _repo(tmp_path)
    svc = _service(tmp_path, repo)
    gid = repo.create_game(title="Braid")["id"]
    svc.set_game_asset(gid, _png(tmp_path / "b.png", (1, 1, 1)), "backdrop")
    svc.set_game_asset(gid, _png(tmp_path / "w.webp", (2, 2, 2)), "backdrop")

    game_dir = svc.game_asset_dir(repo.get_game(gid))
    assert (game_dir / "backdrop.webp").is_file()
    assert not (game_dir / "backdrop.png").exists()


def test_write_failure_keeps_original_file(tmp_path, monkeypatch):
    import g3_core.services.media_assets as ma

    repo = _repo(tmp_path)
    svc = _service(tmp_path, repo)
    gid = repo.create_game(title="Celeste")["id"]
    svc.set_game_asset(gid, _png(tmp_path / "ok.png", (9, 9, 9)), "cover")
    game_dir = svc.game_asset_dir(repo.get_game(gid))
    before = (game_dir / "cover.png").read_bytes()

    real_copy2 = ma.shutil.copy2
    def broken(src, dst, *a, **k):
        raise OSError("disk full")
    monkeypatch.setattr(ma.shutil, "copy2", broken)
    with pytest.raises(OSError):
        svc.set_game_asset(gid, _png(tmp_path / "bad.png", (8, 8, 8)), "cover")

    # 原文件完好，临时文件无残留
    assert (game_dir / "cover.png").read_bytes() == before
    assert sorted(p.name for p in game_dir.iterdir()) == ["cover.png"]
    monkeypatch.setattr(ma.shutil, "copy2", real_copy2)


# ── Steam 扫描器统一写入 ──────────────────────────────────
def _steam_root(tmp_path) -> Path:
    root = tmp_path / "steam"
    cache = root / "appcache" / "librarycache" / "480"
    cache.mkdir(parents=True, exist_ok=True)
    (cache / "library_600x900.jpg").write_bytes(b"jpgcover")
    (cache / "library_hero.jpg").write_bytes(b"jpghero")
    (cache / "logo.png").write_bytes(b"pnglogo")
    return root


def test_steam_import_uses_title_dir_and_common_writer(tmp_path):
    repo = _repo(tmp_path)
    svc = _service(tmp_path, repo)
    gid = repo.create_game(title="Half-Life")["id"]
    scanner = SteamLibraryScanner(repo, svc)
    scanner._find_steam_root = lambda: _steam_root(tmp_path)

    result = scanner._import_steam_assets(480, "Half-Life", gid)

    assert result == {
        "cover": True, "backdrop": True, "logo": True,
        "target_dir": str(svc.game_asset_dir(repo.get_game(gid))).replace("\\", "/"),
    }
    game_dir = svc.game_asset_dir(repo.get_game(gid))
    assert (game_dir / "cover.jpg").read_bytes() == b"jpgcover"
    assert (game_dir / "backdrop.jpg").read_bytes() == b"jpghero"
    assert (game_dir / "logo.png").read_bytes() == b"pnglogo"
    assert not (tmp_path / "G3" / "covers" / "games" / gid).exists()


def test_steam_reimport_does_not_clobber(tmp_path):
    repo = _repo(tmp_path)
    svc = _service(tmp_path, repo)
    gid = repo.create_game(title="Portal")["id"]
    scanner = SteamLibraryScanner(repo, svc)
    scanner._find_steam_root = lambda: _steam_root(tmp_path)
    scanner._import_steam_assets(480, "Portal", gid)
    game_dir = svc.game_asset_dir(repo.get_game(gid))
    (game_dir / "cover.jpg").write_bytes(b"usercover")

    result = scanner._import_steam_assets(480, "Portal", gid)

    assert result["cover"] is False
    assert (game_dir / "cover.jpg").read_bytes() == b"usercover"


def test_steam_import_skips_when_other_ext_exists(tmp_path):
    repo = _repo(tmp_path)
    svc = _service(tmp_path, repo)
    gid = repo.create_game(title="Limbo")["id"]
    scanner = SteamLibraryScanner(repo, svc)
    scanner._find_steam_root = lambda: _steam_root(tmp_path)
    game_dir = svc.game_asset_dir(repo.get_game(gid))
    game_dir.mkdir(parents=True)
    (game_dir / "backdrop.webp").write_bytes(b"betterhero")

    result = scanner._import_steam_assets(480, "Limbo", gid)

    # 旧 webp 保留（不被 jpg 遮蔽），cover/logo 正常导入
    assert result["backdrop"] is False
    assert result["cover"] is True
    assert (game_dir / "backdrop.webp").read_bytes() == b"betterhero"
    assert not (game_dir / "backdrop.jpg").exists()


def test_steam_import_fallback_without_media(tmp_path):
    repo = _repo(tmp_path)
    scanner = SteamLibraryScanner(repo)
    scanner._find_steam_root = lambda: _steam_root(tmp_path)

    result = scanner._import_steam_assets(480, "Unregistered Game", None)

    fallback = tmp_path / "covers" / "games" / "Unregistered Game"
    assert result["cover"] is True
    assert (fallback / "cover.jpg").is_file()
    assert result["target_dir"] == str(fallback).replace("\\", "/")
