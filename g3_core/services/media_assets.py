from __future__ import annotations

import logging
import os
import random
import re
import shutil
import subprocess
from pathlib import Path
from typing import Callable

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.media_assets")


_INVALID_FILENAME_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def sanitize_cover_stem(title: str) -> str:
	"""把电影标题转成合法文件名（去扩展名）。"""
	cleaned = _INVALID_FILENAME_CHARS.sub("_", title).strip()
	cleaned = cleaned.rstrip(". ")
	return cleaned or "Untitled"


class MediaAssetService:
	SUPPORTED_COVER_EXTENSIONS = ("jpg", "jpeg", "png", "webp", "bmp")

	def __init__(
		self,
		repository: LibraryRepository,
		cache_root: Path,
		*,
		covers_root: Path | None = None,
		media_root: Path | None = None,
		ffmpeg_path: str = "ffmpeg",
		runner: Callable[..., subprocess.CompletedProcess] = subprocess.run,
	) -> None:
		self.repository = repository
		self.cache_root = Path(cache_root)
		self.covers_root = Path(covers_root) if covers_root else Path(cache_root).parent / "covers"
		self.media_root = Path(media_root) if media_root else Path(cache_root).parent / "media"
		self.ffmpeg_path = ffmpeg_path
		self._runner = runner
		self.cache_root.mkdir(parents=True, exist_ok=True)
		self.covers_root.mkdir(parents=True, exist_ok=True)
		self.media_root.mkdir(parents=True, exist_ok=True)

	def _movie_asset_dir(self, movie: dict) -> Path:
		# Only the known library scopes may form on-disk subdirectories.
		scope = str(movie.get("library_scope", "main"))
		if scope not in ("main", "private"):
			raise ValueError("invalid movie library scope")
		return self.covers_root / "movies" / scope / str(movie["id"])

	def _legacy_movie_asset(self, movie: dict, suffix: str) -> Path | None:
		"""Legacy title-based assets are safe to reuse only for unambiguous titles.

		Never guess which library owns a shared legacy cover when titles collide.
		"""
		title = str(movie["title"])
		same_title = sum(
			str(other["title"]).casefold() == title.casefold()
			for scope in ("main", "private")
			for other in self.repository.list_movies(scope)
		)
		if same_title != 1:
			return None
		stem = sanitize_cover_stem(title)
		for ext in self.SUPPORTED_COVER_EXTENSIONS:
			candidate = self.covers_root / "movies" / f"{stem}{suffix}.{ext}"
			if candidate.is_file():
				return candidate.resolve()
		return None

	def _movie_asset(self, movie: dict, suffix: str) -> Path | None:
		for ext in self.SUPPORTED_COVER_EXTENSIONS:
			candidate = self._movie_asset_dir(movie) / f"{suffix}.{ext}"
			if candidate.is_file():
				return candidate.resolve()
		return self._legacy_movie_asset(movie, "" if suffix == "cover" else ".backdrop")

	# ---------- 电影封面 ----------

	def resolve_movie_cover(self, item_id: str) -> Path | None:
		movie = self.repository.get_movie(item_id)
		if movie is None:
			return None
		return self._movie_asset(movie, "cover")

	def get_cached_movie_backdrops(self, item_id: str) -> list[Path]:
		"""只查缓存和手动图，不抽帧。用于快速响应列表请求。"""
		movie = self.repository.get_movie(item_id)
		if movie is None:
			return []
		manual = self._movie_asset(movie, "backdrop")
		if manual is not None:
			return [manual]

		cache_dir = self.cache_root / "movie_backdrop" / item_id
		if cache_dir.is_dir():
			files = sorted(cache_dir.glob("*.jpg"))
			if files:
				return [f.resolve() for f in files]
		return []

	def extract_movie_backdrops(self, item_id: str) -> str:
		"""返回 "fresh" / "cached" / "manual" / "failed"。"""
		movie = self.repository.get_movie(item_id)
		if movie is None:
			return "failed"

		if self._movie_asset(movie, "backdrop") is not None:
			return "manual"

		source_path: Path | None = None
		src_mtime: float = 0.0

		episodes = self.repository.get_series_episodes(item_id)
		if episodes:
			candidates: list[Path] = []
			for ep in episodes:
				p = Path(str(ep["video_path"]))
				if not p.is_file():
					continue
				candidates.append(p)
				try:
					m = p.stat().st_mtime
					if m > src_mtime:
						src_mtime = m
				except OSError:
					pass
			if candidates:
				source_path = random.choice(candidates)

		if source_path is None:
			raw = self.repository.get_movie_source_path(item_id)
			if not raw:
				return "failed"
			p = Path(raw)
			if not p.is_file():
				return "failed"
			source_path = p
			try:
				src_mtime = p.stat().st_mtime
			except OSError:
				src_mtime = 0.0

		cache_dir = self.cache_root / "movie_backdrop" / item_id
		cache_dir.mkdir(parents=True, exist_ok=True)

		existing = sorted(cache_dir.glob("*.jpg"))
		if existing:
			newest_mtime = max(f.stat().st_mtime for f in existing)
			if newest_mtime >= src_mtime:
				return "cached"

		for f in existing:
			try:
				f.unlink()
			except OSError:
				pass

		try:
			duration = self._probe_video_duration(source_path)
		except Exception:
			return "failed"
		if duration <= 0:
			return "failed"

		n = 8
		# 把 15%~85% 分成 8 个桶，每个桶里随机取一点
		# 保留"均匀覆盖"的骨架，但每次重抽都得到不同的帧
		span_start = duration * 0.15
		span_end = duration * 0.85
		bucket = (span_end - span_start) / n
		starts: list[float] = []
		for i in range(n):
			# 桶内缩进 15%，避免相邻帧挤在一起
			low = span_start + bucket * i + bucket * 0.15
			high = span_start + bucket * (i + 1) - bucket * 0.15
			t = random.uniform(low, high)
			starts.append(max(0.5, min(t, duration - 0.5)))

		saved = 0
		for i, t in enumerate(starts):
			tmp = cache_dir / f"{i:03d}.jpg"
			try:
				self._extract_frame(source_path, t, tmp)
				saved += 1
			except Exception:
				continue
		return "fresh" if saved > 0 else "failed"

	def probe_movie_duration(self, item_id: str) -> int:
		"""探测电影/剧集总时长（秒）。"""
		episodes = self.repository.get_series_episodes(item_id)
		if episodes:
			total = 0
			for ep in episodes:
				p = Path(str(ep["video_path"]))
				if not p.is_file():
					continue
				try:
					total += int(self._probe_video_duration(p))
				except Exception:
					continue
			return total

		src = self.repository.get_movie_source_path(item_id)
		if not src:
			return 0
		p = Path(src)
		if not p.is_file():
			return 0
		try:
			return int(self._probe_video_duration(p))
		except Exception:
			return 0

	def _probe_video_duration(self, video: Path) -> float:
		ffmpeg = Path(self.ffmpeg_path)
		if ffmpeg.parent != Path(".") or ffmpeg.suffix.lower() == ".exe":
			ffprobe = str(ffmpeg.with_name("ffprobe.exe" if ffmpeg.suffix.lower() == ".exe" else "ffprobe"))
		else:
			ffprobe = "ffprobe"
		kwargs = {
			"capture_output": True,
			"text": True,
			"encoding": "utf-8",
			"errors": "replace",
			"check": True,
		}
		if os.name == "nt":
			kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
		result = subprocess.run(
			[ffprobe, "-v", "error", "-show_entries", "format=duration",
			 "-of", "default=noprint_wrappers=1:nokey=1", str(video)],
			**kwargs,
		)
		return float(result.stdout.strip())

	def _extract_frame(self, video: Path, t: float, output: Path) -> None:
		output.parent.mkdir(parents=True, exist_ok=True)
		temp = output.with_suffix(".tmp.jpg")
		kwargs = {
			"capture_output": True,
			"text": True,
			"encoding": "utf-8",
			"errors": "replace",
		}
		if os.name == "nt":
			kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
		result = subprocess.run(
			[self.ffmpeg_path, "-y", "-ss", f"{t:.3f}", "-i", str(video),
			 "-frames:v", "1", "-q:v", "3", "-vf", "scale=1920:-2", str(temp)],
			**kwargs,
		)
		if result.returncode != 0 or not temp.is_file():
			raise RuntimeError(f"抽帧失败: {result.stderr[-300:]}")
		temp.replace(output)

	def set_movie_cover(self, item_id: str, source: Path) -> Path:
		movie = self.repository.get_movie(item_id)
		if movie is None:
			raise KeyError(item_id)

		source = Path(source).expanduser().resolve()
		if not source.is_file():
			raise FileNotFoundError(source)
		ext = source.suffix.lstrip(".").lower()
		if ext not in self.SUPPORTED_COVER_EXTENSIONS:
			raise ValueError(f"unsupported cover extension: {ext}")

		covers_dir = self._movie_asset_dir(movie)
		covers_dir.mkdir(parents=True, exist_ok=True)
		target = covers_dir / f"cover.{ext}"
		for other_ext in self.SUPPORTED_COVER_EXTENSIONS:
			if other_ext != ext:
				stale = covers_dir / f"cover.{other_ext}"
				if stale.is_file():
					stale.unlink()

		temp_target = target.with_suffix(target.suffix + ".tmp")
		shutil.copy2(source, temp_target)
		temp_target.replace(target)
		return target

	def set_game_cover(self, item_id: str, source: Path) -> Path:
		return self.set_game_asset(item_id, source, "")

	def set_game_asset(self, item_id: str, source: Path, suffix: str = "") -> Path:
		"""Write game assets to an immutable item ID directory."""
		game = self.repository.get_game(item_id)
		if game is None:
			raise KeyError(item_id)

		source = Path(source).expanduser().resolve()
		if not source.is_file():
			raise FileNotFoundError(source)
		ext = source.suffix.lstrip(".").lower()
		if ext not in self.SUPPORTED_COVER_EXTENSIONS:
			raise ValueError(f"unsupported asset extension: {ext}")

		games_dir = self.covers_root / "games"
		target_dir = games_dir / str(item_id)
		target_dir.mkdir(parents=True, exist_ok=True)
		# suffix 为空 → 主封面统一叫 cover
		asset_name = suffix if suffix else "cover"
		target = target_dir / f"{asset_name}.{ext}"

		for other_ext in self.SUPPORTED_COVER_EXTENSIONS:
			if other_ext == ext:
				continue
			stale = target_dir / f"{asset_name}.{other_ext}"
			if stale.is_file():
				try:
					stale.unlink()
				except OSError:
					pass

		temp_target = target.with_name(target.name + ".tmp")
		shutil.copy2(source, temp_target)
		temp_target.replace(target)
		return target

	def set_movie_backdrop(self, item_id: str, source: Path) -> Path:
		movie = self.repository.get_movie(item_id)
		if movie is None:
			raise KeyError(item_id)

		source = Path(source).expanduser().resolve()
		if not source.is_file():
			raise FileNotFoundError(source)
		ext = source.suffix.lstrip(".").lower()
		if ext not in self.SUPPORTED_COVER_EXTENSIONS:
			raise ValueError(f"unsupported backdrop extension: {ext}")

		covers_dir = self._movie_asset_dir(movie)
		covers_dir.mkdir(parents=True, exist_ok=True)
		target = covers_dir / f"backdrop.{ext}"
		for other_ext in self.SUPPORTED_COVER_EXTENSIONS:
			if other_ext != ext:
				stale = covers_dir / f"backdrop.{other_ext}"
				if stale.is_file():
						stale.unlink()

		temp_target = target.with_suffix(target.suffix + ".tmp")
		shutil.copy2(source, temp_target)
		temp_target.replace(target)
		return target
	# ---------- 本地封面文件夹匹配 ----------

	_SUPPORTED_COVER_IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")

	@staticmethod
	def _strip_year_suffix(name: str) -> str:
		"""去掉文件名末尾的年份括号，比如 '银翼杀手 (1982)' → '银翼杀手'。"""
		import re
		cleaned = re.sub(r"\s*[\(\[]?\d{4}[\)\]]?\s*$", "", name).strip()
		return cleaned if cleaned else name

	def _build_cover_index(self, cover_folder: Path) -> dict[str, Path]:
		"""扫封面文件夹，建立 {stem_lower: 文件路径} 字典。"""
		index: dict[str, Path] = {}
		if not cover_folder.is_dir():
			return index
		for p in cover_folder.iterdir():
			if not p.is_file():
				continue
			if p.suffix.lower() not in self._SUPPORTED_COVER_IMAGE_EXTS:
				continue
			key = p.stem.casefold()
			if key not in index:
				index[key] = p
		return index

	def _find_cover_for_title(
		self, title: str, index: dict[str, Path]
	) -> Path | None:
		"""按标题在封面索引里找匹配的封面文件。"""
		title_clean = title.strip()
		if not title_clean:
			return None
		title_stripped = self._strip_year_suffix(title_clean)
		title_key = title_clean.casefold()
		title_stripped_key = title_stripped.casefold()

		# 精确匹配（标题原样 / 标题去括号）
		if title_key in index:
			return index[title_key]
		if title_stripped_key in index:
			return index[title_stripped_key]

		# 反向匹配：封面文件名去括号后等于标题（原样或去括号）
		for stem, path in index.items():
			stem_stripped = self._strip_year_suffix(stem).casefold()
			if stem_stripped == title_key or stem_stripped == title_stripped_key:
				return path
		return None

	def match_local_covers(self, scope: str, cover_folder: Path) -> int:
		"""给指定库所有没封面的电影，从封面文件夹里按标题匹配本地封面。返回匹配数。"""
		index = self._build_cover_index(cover_folder)
		if not index:
			logger.info("local cover folder empty or missing: %s", cover_folder)
			return 0

		matched = 0
		for movie in self.repository.list_movies(scope):
			item_id = str(movie["id"])
			title = str(movie["title"])
			if self.resolve_movie_cover(item_id) is not None:
				continue
			src = self._find_cover_for_title(title, index)
			if src is None:
				continue
			try:
				self.set_movie_cover(item_id, src)
				matched += 1
			except Exception:
				logger.exception("local cover set failed: %s", item_id)
		logger.info("local covers matched: scope=%s count=%d", scope, matched)
		return matched