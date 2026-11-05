from __future__ import annotations

import os
from pathlib import Path

from PIL import Image

from g3_core.services.game_theme import GameThemeService


def _solid_cover(path: Path, color: tuple[int, int, int]) -> Path:
    Image.new("RGB", (48, 72), color).save(path, format="PNG")
    return path


def test_game_theme_service_extracts_semantic_palette_and_caches(tmp_path, monkeypatch):
    cover = _solid_cover(tmp_path / "cover.png", (210, 38, 44))
    service = GameThemeService(tmp_path / "cache")
    original_extract = service._extract_palette
    calls = []

    def count_extract(path):
        calls.append(path)
        return original_extract(path)

    monkeypatch.setattr(service, "_extract_palette", count_extract)
    first = service.get_palette(cover)
    second = service.get_palette(cover)

    assert first["status"] == "ready"
    assert set(first["colors"]) == {"accent", "secondary", "surface", "ambient", "shadow"}
    assert first["colors"]["accent"].startswith("#")
    assert first == second
    assert len(calls) == 1
    assert list((tmp_path / "cache" / "game_theme_palettes").glob("*.json"))


def test_game_theme_service_recalculates_when_cover_changes(tmp_path):
    cover = _solid_cover(tmp_path / "cover.png", (220, 30, 35))
    service = GameThemeService(tmp_path / "cache")
    red_palette = service.get_palette(cover)

    _solid_cover(cover, (24, 70, 220))
    stat = cover.stat()
    os.utime(cover, ns=(stat.st_atime_ns, stat.st_mtime_ns + 2_000_000_000))
    blue_palette = service.get_palette(cover)

    assert red_palette["status"] == "ready"
    assert blue_palette["status"] == "ready"
    assert red_palette["colors"]["accent"] != blue_palette["colors"]["accent"]
    red = red_palette["colors"]["accent"]
    blue = blue_palette["colors"]["accent"]
    assert int(red[1:3], 16) > int(red[5:7], 16)
    assert int(blue[5:7], 16) > int(blue[1:3], 16)
    assert service.invalidate(cover) is True
    assert service.invalidate(cover) is False


def test_game_theme_service_uses_neutral_fallback_for_missing_or_monochrome_cover(tmp_path):
    service = GameThemeService(tmp_path / "cache")
    missing = service.get_palette(tmp_path / "missing.png")
    assert missing["status"] == "fallback"
    assert missing["reason"] == "missing_cover"

    monochrome = tmp_path / "mono.png"
    Image.new("RGB", (32, 32), (70, 70, 70)).save(monochrome, format="PNG")
    fallback = service.get_palette(monochrome)
    assert fallback["status"] == "fallback"
    assert fallback["reason"] in {"low_chroma_cover", "low_chroma_or_unusable_cover"}
    assert fallback["colors"] == service.DEFAULT_COLORS


def test_game_theme_service_returns_fallback_for_unreadable_cover(tmp_path):
    cover = tmp_path / "broken.png"
    cover.write_bytes(b"not an image")
    service = GameThemeService(tmp_path / "cache")

    palette = service.get_palette(cover)

    assert palette["status"] == "fallback"
    assert palette["reason"] == "unreadable_cover"
    assert palette["colors"] == service.DEFAULT_COLORS


def test_game_theme_service_can_clear_all_persisted_palettes(tmp_path):
    cover = _solid_cover(tmp_path / "cover.png", (210, 38, 44))
    service = GameThemeService(tmp_path / "cache")
    service.get_palette(cover)

    assert service.clear_cache() == 1
    assert service.clear_cache() == 0


def test_game_theme_surface_tracks_cover_hue_without_large_lightness_shift(tmp_path):
    red_cover = _solid_cover(tmp_path / "red.png", (210, 38, 44))
    blue_cover = _solid_cover(tmp_path / "blue.png", (24, 70, 220))
    service = GameThemeService(tmp_path / "cache")

    red_palette = service.get_palette(red_cover)
    blue_palette = service.get_palette(blue_cover)

    assert red_palette["algorithm_version"] == 3
    assert blue_palette["algorithm_version"] == 3
    assert red_palette["method"] == "weighted_hue_bins_oklab_surfaces_v3_hero_first"
    red_surface = service._from_hex(red_palette["colors"]["surface"])
    blue_surface = service._from_hex(blue_palette["colors"]["surface"])
    red_l, red_a, red_b = service._rgb_to_oklab(red_surface)
    blue_l, blue_a, blue_b = service._rgb_to_oklab(blue_surface)

    # Different cover hues should create visibly different surface tints while
    # retaining nearly the same perceptual lightness.
    assert abs(red_l - blue_l) < 0.025
    assert (red_a, red_b) != (blue_a, blue_b)
    assert red_palette["colors"]["surface"] != blue_palette["colors"]["surface"]
    assert red_palette["colors"]["ambient"] != blue_palette["colors"]["ambient"]
