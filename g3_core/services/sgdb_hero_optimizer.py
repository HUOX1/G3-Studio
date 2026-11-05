"""Conservative in-memory optimization for SGDB game media.

The original download is always available as a fallback. No extra disk cache is
created; callers publish only the selected final bytes as the game asset.
"""
from __future__ import annotations

import io
import logging
from typing import Callable

from PIL import Image, ImageOps, UnidentifiedImageError

logger = logging.getLogger("g3.sgdb_media")

HERO_OPTIMIZE_THRESHOLD = 2 * 1024 * 1024
HERO_MAX_SIZE = (1920, 620)
HERO_WEBP_QUALITY = 88
HERO_MIN_SAVING_RATIO = 0.10
# Distinct size budgets prevent cover/logo/icon details from being treated like wide heroes.
MEDIA_LIMITS = {
    "hero": ((1920, 620), 2 * 1024 * 1024, 88),
    "grid": ((900, 1350), 2 * 1024 * 1024, 90),
    "logo": ((1200, 700), 1024 * 1024, 92),
    "icon": ((512, 512), 1024 * 1024, 92),
}



def optimize_hero_image(data: bytes, extension: str) -> tuple[bytes, str, bool, tuple[int, int]]:
    """Return (bytes, extension, optimized, original dimensions).

    Skip small, animated, or unrecognized images. Keep the original if encoding
    fails or doesn't reduce file size by at least 10%. Never upscale an image.
    """
    if len(data) <= HERO_OPTIMIZE_THRESHOLD:
        return data, extension, False, (0, 0)
    try:
        with Image.open(io.BytesIO(data)) as source:
            original_size = source.size
            if getattr(source, "is_animated", False) or getattr(source, "n_frames", 1) > 1:
                return data, extension, False, original_size
            if source.format not in ("JPEG", "PNG", "WEBP", "BMP"):
                return data, extension, False, original_size
            image = ImageOps.exif_transpose(source)
            if image.mode not in ("RGB", "RGBA"):
                image = image.convert("RGBA" if "A" in image.getbands() or "transparency" in image.info else "RGB")
            image.thumbnail(HERO_MAX_SIZE, Image.Resampling.LANCZOS)
            output = io.BytesIO()
            image.save(output, format="WEBP", quality=HERO_WEBP_QUALITY, method=4)
            optimized = output.getvalue()
            if len(optimized) >= len(data) * (1 - HERO_MIN_SAVING_RATIO):
                return data, extension, False, original_size
            return optimized, "webp", True, original_size
    except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError):
        logger.warning("SGDB Hero optimization failed; keeping original", exc_info=True)
        return data, extension, False, (0, 0)


def _webp_frame_durations(payload: bytes) -> list[int]:
    """Read ANMF durations from WebP RIFF chunks (Pillow omits them on some versions)."""
    if len(payload) < 12 or payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        return []
    durations = []
    offset = 12
    while offset + 8 <= len(payload):
        kind = payload[offset:offset + 4]
        length = int.from_bytes(payload[offset + 4:offset + 8], "little")
        start = offset + 8
        if start + length > len(payload):
            return []
        if kind == b"ANMF" and length >= 16:
            durations.append(int.from_bytes(payload[start + 12:start + 15], "little"))
        offset = start + length + (length % 2)
    return durations


def is_animated_webp(data: bytes) -> bool:
    """Check WebP's extended-header animation flag without decoding frames."""
    return (len(data) >= 21 and data[:4] == b"RIFF"
            and data[8:12] == b"WEBP" and data[12:16] == b"VP8X"
            and bool(data[20] & 0x02))


def optimize_sgdb_image(data: bytes, extension: str, asset_type: str, progress: Callable[[str, int, int], None] | None = None) -> tuple[bytes, str, bool, tuple[int, int]]:
    """Optimize oversized images while preserving animated WebP playback.

    Non-WebP animations and unsupported formats are never transcoded. Animated
    WebP is recompressed only with unchanged frame dimensions, frame count and
    durations, and only if a meaningful reduction is achieved.
    """
    if asset_type == "grid" and is_animated_webp(data):
        return data, extension, False, (0, 0)
    limits = MEDIA_LIMITS.get(asset_type)
    if limits is None:
        return data, extension, False, (0, 0)
    max_size, threshold, quality = limits
    if len(data) <= threshold:
        return data, extension, False, (0, 0)
    if asset_type == "hero":
        return optimize_hero_image(data, extension)
    try:
        with Image.open(io.BytesIO(data)) as source:
            original_size = source.size
            animated = getattr(source, "is_animated", False) and getattr(source, "n_frames", 1) > 1
            if animated:
                if source.format != "WEBP" or asset_type != "grid":
                    return data, extension, False, original_size
                frame_count = source.n_frames
                width, height = original_size
                # A compressed 46 MB animation may expand into gigabytes of RGBA.
                # Skip unsafe full-frame recompression instead of exhausting RAM.
                if frame_count > 180 or width * height * frame_count > 45_000_000:
                    if progress:
                        progress("skipped_large_animation", 0, frame_count)
                    return data, extension, False, original_size
                durations = _webp_frame_durations(data)
                if len(durations) != frame_count or any(d <= 0 for d in durations):
                    return data, extension, False, original_size
                frames = []
                for index in range(frame_count):
                    source.seek(index)
                    frames.append(source.convert("RGBA"))
                    if progress:
                        progress("decode", index + 1, frame_count)
                if len(frames) < 2 or any(d <= 0 for d in durations):
                    return data, extension, False, original_size
                if progress:
                    progress("encode", 0, 0)
                output = io.BytesIO()
                frames[0].save(output, format="WEBP", save_all=True, append_images=frames[1:],
                               duration=durations, loop=int(source.info.get("loop", 0)),
                               quality=92, method=4)
                compressed = output.getvalue()
                if progress:
                    progress("verify", 0, 0)
                with Image.open(io.BytesIO(compressed)) as check:
                    if check.size != original_size or check.n_frames != len(frames):
                        return data, extension, False, original_size
                    if _webp_frame_durations(compressed) != durations:
                        return data, extension, False, original_size
                if len(compressed) < len(data) * 0.90:
                    return compressed, "webp", True, original_size
                return data, extension, False, original_size
            if source.format not in ("JPEG", "PNG", "WEBP", "BMP", "ICO"):
                return data, extension, False, original_size
            image = ImageOps.exif_transpose(source)
            if image.mode not in ("RGB", "RGBA"):
                image = image.convert("RGBA" if "A" in image.getbands() or "transparency" in image.info else "RGB")
            image.thumbnail(max_size, Image.Resampling.LANCZOS)
            output = io.BytesIO()
            image.save(output, format="WEBP", quality=quality, method=4)
            compressed = output.getvalue()
            if len(compressed) < len(data) * 0.90:
                return compressed, "webp", True, original_size
            return data, extension, False, original_size
    except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError):
        logger.warning("SGDB %s optimization failed; keeping original", asset_type, exc_info=True)
        return data, extension, False, (0, 0)
