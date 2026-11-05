"""Per-game Hero-first palettes for adaptive G3 visuals.

This service derives an ephemeral visual palette from the active game's Hero
image, falling back to its cover. It is an internal per-game visual adaptation,
not a user-selectable application theme system.
"""
from __future__ import annotations

import colorsys
import hashlib
import json
import logging
import math
import os
import tempfile
import threading
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps, UnidentifiedImageError


logger = logging.getLogger("g3.game_theme")


class GameThemeService:
    """Extract, derive, cache, and invalidate per-game Hero-first palettes.

    Public API:
      - ``get_palette(image_path)`` returns a stable semantic palette.
      - ``invalidate(image_path)`` removes the persisted cache for a Hero or cover.
      - ``clear_cache()`` clears persisted palettes after algorithm changes.

    The cache is keyed by canonical image path and validated against file size,
    nanosecond mtime, schema version, and algorithm version. No database schema
    changes are required. UI modules should consume the returned semantic color
    roles rather than performing their own image analysis.
    """

    SCHEMA_VERSION = 1
    ALGORITHM_VERSION = 4
    SAMPLE_SIZE = (160, 160)

    DEFAULT_COLORS = {
        "accent": "#8196AA",
        "secondary": "#65798D",
        "surface": "#292F3A",
        "ambient": "#242D39",
        "shadow": "#0A0D13",
    }

    def __init__(self, cache_root: Path) -> None:
        self.cache_root = Path(cache_root) / "game_theme_palettes"
        self.cache_root.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()

    def get_palette(self, cover_path: str | Path | None) -> dict[str, Any]:
        """Return a semantic palette; use neutral colors when no Hero/cover image is usable."""
        diagnostic = os.environ.get("G3_THEME_DIAG") == "1"
        if cover_path is None or not str(cover_path).strip():
            if diagnostic:
                logger.warning("[G3_THEME_DIAG] palette fallback: image path missing")
            return self._fallback("missing_cover")

        try:
            path = Path(cover_path).expanduser().resolve(strict=True)
            if not path.is_file():
                return self._fallback("missing_cover")
            stat = path.stat()
        except (OSError, RuntimeError, ValueError):
            return self._fallback("missing_cover")

        signature = {
            "size": int(stat.st_size),
            "mtime_ns": int(getattr(stat, "st_mtime_ns", stat.st_mtime * 1_000_000_000)),
            "algorithm_version": self.ALGORITHM_VERSION,
        }
        cache_path = self._cache_path(path)

        with self._lock:
            cached = self._read_cache(cache_path)
            if (
                cached is not None
                and cached.get("schema_version") == self.SCHEMA_VERSION
                and cached.get("signature") == signature
                and isinstance(cached.get("palette"), dict)
            ):
                if diagnostic:
                    logger.warning("[G3_THEME_DIAG] cache=hit image=%s signature=%s colors=%s", path, signature, cached["palette"].get("colors"))
                return self._copy_palette(cached["palette"])

            if diagnostic:
                logger.warning("[G3_THEME_DIAG] cache=miss image=%s signature=%s cache_file=%s", path, signature, cache_path)
            palette = self._extract_palette(path)
            if diagnostic:
                logger.warning("[G3_THEME_DIAG] extraction status=%s method=%s colors=%s", palette.get("status"), palette.get("method"), palette.get("colors"))
            record = {
                "schema_version": self.SCHEMA_VERSION,
                "signature": signature,
                "palette": palette,
            }
            self._write_cache(cache_path, record)
            return self._copy_palette(palette)

    def invalidate(self, cover_path: str | Path | None) -> bool:
        """Remove one cover's persisted palette, if it exists."""
        if cover_path is None or not str(cover_path).strip():
            return False
        cache_path = self._cache_path(Path(cover_path).expanduser())
        with self._lock:
            try:
                cache_path.unlink()
                return True
            except FileNotFoundError:
                return False
            except OSError:
                logger.warning("Unable to invalidate game image palette cache", exc_info=True)
                return False

    def clear_cache(self) -> int:
        """Remove all persisted palettes; return the number of deleted records."""
        removed = 0
        with self._lock:
            for path in self.cache_root.glob("*.json"):
                try:
                    path.unlink()
                    removed += 1
                except OSError:
                    logger.warning("Unable to remove game palette cache %s", path, exc_info=True)
        return removed

    def _cache_path(self, path: Path) -> Path:
        try:
            canonical = str(path.resolve(strict=False))
        except (OSError, RuntimeError):
            canonical = str(path.absolute())
        canonical = os.path.normcase(canonical)
        key = hashlib.sha256(canonical.encode("utf-8", errors="surrogatepass")).hexdigest()
        return self.cache_root / f"{key}.json"

    @staticmethod
    def _read_cache(path: Path) -> dict[str, Any] | None:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            return None
        return payload if isinstance(payload, dict) else None

    def _write_cache(self, path: Path, record: dict[str, Any]) -> None:
        temp_path: Path | None = None
        try:
            fd, raw_path = tempfile.mkstemp(prefix=".game-theme-", suffix=".tmp", dir=self.cache_root)
            temp_path = Path(raw_path)
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
                json.dump(record, stream, ensure_ascii=False, separators=(",", ":"))
            os.replace(temp_path, path)
        except OSError:
            logger.warning("Unable to persist game image palette cache", exc_info=True)
        finally:
            if temp_path is not None:
                try:
                    temp_path.unlink(missing_ok=True)
                except OSError:
                    pass

    def _extract_palette(self, path: Path) -> dict[str, Any]:
        try:
            with Image.open(path) as source:
                # Animated covers use their first frame for a stable palette.
                try:
                    source.seek(0)
                except EOFError:
                    pass
                image = ImageOps.exif_transpose(source)
                image.thumbnail(self.SAMPLE_SIZE, Image.Resampling.LANCZOS)
                raw_pixels = image.convert("RGBA").tobytes()
                pixels = (raw_pixels[index:index + 4] for index in range(0, len(raw_pixels), 4))
        except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError):
            logger.debug("Could not extract game palette from %s", path, exc_info=True)
            return self._fallback("unreadable_cover")

        # Group colors by hue rather than RGB cubes. RGB cubes split visually
        # similar colors across several buckets; circular hue bins retain a
        # stable theme even when a cover contains gradients or antialiased art.
        bin_count = 36
        bins: list[dict[str, float]] = [
            {"weight": 0.0, "hx": 0.0, "hy": 0.0, "s": 0.0, "l": 0.0}
            for _ in range(bin_count)
        ]
        sampled_pixels = 0
        for r, g, b, alpha in pixels:
            if alpha < 96:
                continue
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            hue, lightness, saturation = colorsys.rgb_to_hls(rf, gf, bf)
            luminance = self._relative_luminance((r, g, b))
            # Ignore near-black framing, near-white logos and neutral artwork.
            if luminance < 0.012 or luminance > 0.92 or saturation < 0.045:
                continue
            midtone_weight = 0.62 + 0.38 * (1.0 - min(1.0, abs(lightness - 0.50) / 0.50))
            weight = (0.12 + 0.88 * saturation) * midtone_weight * (alpha / 255.0)
            index = int(hue * bin_count) % bin_count
            bucket = bins[index]
            angle = hue * 2.0 * math.pi
            bucket["weight"] += weight
            bucket["hx"] += math.cos(angle) * weight
            bucket["hy"] += math.sin(angle) * weight
            bucket["s"] += saturation * weight
            bucket["l"] += lightness * weight
            sampled_pixels += 1

        if not sampled_pixels:
            return self._fallback("low_chroma_or_unusable_cover", sampled_pixels=0)

        # Smooth each bin with its neighbors so hues near the 0/360 boundary
        # (especially reds) are not arbitrarily split.
        scores = [
            bins[(index - 1) % bin_count]["weight"]
            + 2.0 * bins[index]["weight"]
            + bins[(index + 1) % bin_count]["weight"]
            for index in range(bin_count)
        ]
        primary_index = max(range(bin_count), key=lambda index: scores[index])
        primary = self._combine_hue_bins(bins, primary_index, bin_count, radius=1)
        if primary is None or primary["saturation"] < 0.045:
            return self._fallback("low_chroma_cover", sampled_pixels=sampled_pixels)

        accent = self._hex(self._hsl_to_rgb(
            primary["hue"],
            min(0.62, max(0.43, primary["lightness"])),
            min(0.84, max(0.16, primary["saturation"] * 1.55)),
        ))
        accent_rgb = self._from_hex(accent)

        secondary_rgb: tuple[int, int, int] | None = None
        secondary_candidates: list[tuple[float, dict[str, float]]] = []
        for index in range(bin_count):
            if scores[index] <= 0:
                continue
            candidate = self._combine_hue_bins(bins, index, bin_count, radius=1)
            if candidate is None or candidate["saturation"] < 0.20:
                continue
            hue_distance = abs(candidate["hue"] - primary["hue"])
            hue_distance = min(hue_distance, 1.0 - hue_distance)
            if hue_distance < 0.14:
                continue
            secondary_candidates.append((scores[index], candidate))
        if secondary_candidates:
            secondary_candidates.sort(key=lambda item: item[0], reverse=True)
            candidate = secondary_candidates[0][1]
            secondary_rgb = self._hsl_to_rgb(
                candidate["hue"],
                min(0.58, max(0.44, candidate["lightness"])),
                min(0.70, max(0.32, candidate["saturation"])),
            )
        if secondary_rgb is None:
            secondary_rgb = self._shift_hue(accent_rgb, 0.075)
        secondary = self._normalize_accent(secondary_rgb, max_saturation=0.68)

        # Surface colors keep a fixed perceptual lightness while inheriting the
        # cover's hue. This avoids the old behavior where theme changes mainly
        # looked like brightness changes. Different surfaces target the existing
        # detail panel, sidebar and shadow darkness respectively.
        surface = self._theme_tint(accent_rgb, target_l=0.215, chroma_scale=0.82, max_chroma=0.100)
        ambient = self._theme_tint(accent_rgb, target_l=0.205, chroma_scale=0.70, max_chroma=0.085)
        shadow = self._theme_tint(accent_rgb, target_l=0.115, chroma_scale=0.35, max_chroma=0.040)
        return {
            "schema_version": self.SCHEMA_VERSION,
            "algorithm_version": self.ALGORITHM_VERSION,
            "status": "ready",
            "reason": "",
            "sampled_pixels": sampled_pixels,
            "method": "weighted_hue_bins_oklab_surfaces_v4_chroma_preserving_hero_first",
            "colors": {
                "accent": accent,
                "secondary": secondary,
                "surface": surface,
                "ambient": ambient,
                "shadow": shadow,
            },
        }

    @staticmethod
    def _relative_luminance(rgb: tuple[int, int, int]) -> float:
        def linearize(channel: int) -> float:
            value = channel / 255.0
            return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        r, g, b = (linearize(channel) for channel in rgb)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b

    @staticmethod
    def _combine_hue_bins(
        bins: list[dict[str, float]], index: int, bin_count: int, *, radius: int
    ) -> dict[str, float] | None:
        total = {key: 0.0 for key in ("weight", "hx", "hy", "s", "l")}
        for offset in range(-radius, radius + 1):
            bucket = bins[(index + offset) % bin_count]
            for key in total:
                total[key] += bucket[key]
        weight = total["weight"]
        if weight <= 0.0:
            return None
        hue = (math.atan2(total["hy"], total["hx"]) / (2.0 * math.pi)) % 1.0
        return {
            "hue": hue,
            "saturation": total["s"] / weight,
            "lightness": total["l"] / weight,
            "weight": weight,
        }

    @staticmethod
    def _hsl_to_rgb(hue: float, lightness: float, saturation: float) -> tuple[int, int, int]:
        return tuple(round(channel * 255) for channel in colorsys.hls_to_rgb(hue % 1.0, lightness, saturation))

    @staticmethod
    def _rgb_to_oklab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
        def linearize(channel: int) -> float:
            value = channel / 255.0
            return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        r, g, b = (linearize(channel) for channel in rgb)
        l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1.0 / 3.0)
        m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1.0 / 3.0)
        s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1.0 / 3.0)
        return (
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
        )

    @staticmethod
    def _oklab_to_rgb_float(lightness: float, a: float, b: float) -> tuple[float, float, float]:
        l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
        m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
        s_ = lightness - 0.0894841775 * a - 1.2914855480 * b
        l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
        return (
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
        )

    @staticmethod
    def _encode_srgb(value: float) -> int:
        value = max(0.0, min(1.0, value))
        encoded = value * 12.92 if value <= 0.0031308 else 1.055 * (value ** (1.0 / 2.4)) - 0.055
        return round(encoded * 255)

    @classmethod
    def _theme_tint(
        cls, accent_rgb: tuple[int, int, int], *, target_l: float, chroma_scale: float, max_chroma: float
    ) -> str:
        _, a, b = cls._rgb_to_oklab(accent_rgb)
        hue_angle = math.atan2(b, a)
        chroma = min(max_chroma, math.hypot(a, b) * chroma_scale)
        # Reduce chroma until the requested hue/lightness is in the sRGB gamut.
        for _ in range(12):
            aa, bb = chroma * math.cos(hue_angle), chroma * math.sin(hue_angle)
            linear_rgb = cls._oklab_to_rgb_float(target_l, aa, bb)
            if all(-1e-6 <= channel <= 1.000001 for channel in linear_rgb):
                return cls._hex(tuple(cls._encode_srgb(channel) for channel in linear_rgb))
            chroma *= 0.82
        # The neutral fallback still keeps the requested dark lightness if an
        # unusually saturated hue cannot be represented at the target lightness.
        return cls._hex(tuple(cls._encode_srgb(channel) for channel in cls._oklab_to_rgb_float(target_l, 0.0, 0.0)))

    def _fallback(self, reason: str, *, sampled_pixels: int = 0) -> dict[str, Any]:
        return {
            "schema_version": self.SCHEMA_VERSION,
            "algorithm_version": self.ALGORITHM_VERSION,
            "status": "fallback",
            "reason": reason,
            "sampled_pixels": sampled_pixels,
            "method": "neutral_fallback_v1",
            "colors": dict(self.DEFAULT_COLORS),
        }

    @staticmethod
    def _copy_palette(palette: dict[str, Any]) -> dict[str, Any]:
        copied = dict(palette)
        colors = palette.get("colors")
        copied["colors"] = dict(colors) if isinstance(colors, dict) else dict(GameThemeService.DEFAULT_COLORS)
        return copied

    @staticmethod
    def _saturation(rgb: tuple[int, int, int]) -> float:
        maximum, minimum = max(rgb), min(rgb)
        return 0.0 if maximum == 0 else (maximum - minimum) / maximum

    @staticmethod
    def _color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5

    @staticmethod
    def _hex(rgb: tuple[int, int, int]) -> str:
        return "#{:02X}{:02X}{:02X}".format(*(max(0, min(255, int(round(channel)))) for channel in rgb))

    @staticmethod
    def _from_hex(value: str) -> tuple[int, int, int]:
        value = value.lstrip("#")
        return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)

    @staticmethod
    def _mix(base: tuple[int, int, int], tint: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
        return tuple(int(round(base[i] * (1.0 - amount) + tint[i] * amount)) for i in range(3))

    @staticmethod
    def _darken(rgb: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
        return tuple(int(round(channel * amount)) for channel in rgb)

    @staticmethod
    def _normalize_accent(rgb: tuple[int, int, int], *, max_saturation: float = 0.78) -> str:
        h, s, v = colorsys.rgb_to_hsv(*(channel / 255.0 for channel in rgb))
        s = min(max_saturation, max(0.22, s))
        v = min(0.82, max(0.42, v))
        return GameThemeService._hex(tuple(round(channel * 255) for channel in colorsys.hsv_to_rgb(h, s, v)))

    @staticmethod
    def _shift_hue(rgb: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
        h, s, v = colorsys.rgb_to_hsv(*(channel / 255.0 for channel in rgb))
        shifted = ((h + amount) % 1.0, max(0.22, s * 0.76), min(0.78, v * 0.9))
        return tuple(round(channel * 255) for channel in colorsys.hsv_to_rgb(*shifted))
