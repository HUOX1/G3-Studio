from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.library_scanner")


VIDEO_EXTENSIONS = {
	".mp4", ".mkv", ".avi", ".mov", ".wmv", ".m4v", ".ts", ".webm",
}
import re

SEASON_PATTERNS = [
	re.compile(r"^S(\d+)$", re.IGNORECASE),
	re.compile(r"^Season[\s._-]*(\d+)$", re.IGNORECASE),
	re.compile(r"^第([一二三四五六七八九十百千\d]+)季$"),
	re.compile(r"^(\d+)季$"),
]

EPISODE_PATTERNS = [
	re.compile(r"[Ss](\d+)[Ee](\d+)"),         # S01E02
	re.compile(r"[Ee][Pp]?(\d+)"),             # E02 / EP02
	re.compile(r"第(\d+)集"),
	re.compile(r"^(\d+)$"),                    # 纯数字
	re.compile(r"[_\-\s](\d+)$"),              # 末尾数字
]


_CN_DIGITS: dict[str, int] = {
	"一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
	"六": 6, "七": 7, "八": 8, "九": 9,
}


def _cn_to_int(text: str) -> int | None:
	"""把 `第X季` 里捕获的季号转成 int，支持阿拉伯数字和常见中文数字。

	支持：`1`、`一`、`十`、`十一`、`二十`、`二十五`。
	不支持 `一百` 等复杂组合——现实中季号不会那么大。
	"""
	if not text:
		return None
	if text.isdigit():
		return int(text)
	if text in _CN_DIGITS:
		return _CN_DIGITS[text]
	if "十" in text:
		left, _, right = text.partition("十")
		if left and left not in _CN_DIGITS:
			return None
		if right and right not in _CN_DIGITS:
			return None
		left_value = _CN_DIGITS.get(left, 1) if left else 1
		right_value = _CN_DIGITS.get(right, 0) if right else 0
		return left_value * 10 + right_value
	return None


def _parse_season(folder_name: str) -> int | None:
	for pat in SEASON_PATTERNS:
		m = pat.match(folder_name.strip())
		if m:
			return _cn_to_int(m.group(1))
	return None


def _parse_episode(filename_stem: str) -> int | None:
	for pat in EPISODE_PATTERNS:
		m = pat.search(filename_stem)
		if not m:
			continue
		# `S01E02` 格式有两个 group：group(1)=季号，group(2)=集号
		# 其余 pattern 只有一个 group，就是集号
		groups = m.groups()
		value = groups[1] if len(groups) >= 2 else groups[0]
		if value is None:
			return None
		try:
			return int(value)
		except ValueError:
			return None

def _find_season(folder: Path, video: Path) -> int | None:
	"""从 video 所在路径向上找最近的季号文件夹，一直到 folder 为止。"""
	cur = video.parent
	while cur != folder and cur != cur.parent:
		s = _parse_season(cur.name)
		if s is not None:
			return s
		cur = cur.parent
	return None

@dataclass
class ScanResult:
	added: int = 0
	updated: int = 0
	offline: int = 0
	online: int = 0
	errors: int = 0
	total_found: int = 0

	def to_dict(self) -> dict:
		return {
			"added": self.added,
			"updated": self.updated,
			"offline": self.offline,
			"online": self.online,
			"errors": self.errors,
			"total_found": self.total_found,
		}


class MovieLibraryScanner:
	"""扫描影视库文件夹，按规则自动建立/更新电影档案。

	规则：
	- 库根的直接子文件夹 → 一部作品，标题取文件夹名
	- 库根的散落视频文件 → 一部作品，标题取文件名（去扩展名）
	- 文件夹内的视频递归查找，取第一个作为主视频
	- 用 source_path 匹配已有条目
	- 本次未匹配到的已有条目 → 标记离线
	"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	def scan(self, library_paths: list[str], scope: str = "main") -> ScanResult:
		result = ScanResult()
		found_sources: set[str] = set()

		for raw_path in library_paths:
			if not raw_path:
				continue
			lib_root = Path(raw_path).expanduser().resolve()
			if not lib_root.is_dir():
				logger.warning("library path not found: %s", lib_root)
				result.errors += 1
				continue
			self._scan_library_root(lib_root, found_sources, result, scope)

		self._mark_offline(found_sources, result, scope)
		return result

	def _scan_library_root(
		self,
		lib_root: Path,
		found_sources: set[str],
		result: ScanResult,
		scope: str = "main",
	) -> None:
		try:
			entries = sorted(lib_root.iterdir())
		except OSError:
			logger.exception("failed to list library root: %s", lib_root)
			result.errors += 1
			return

		for entry in entries:
			if entry.name.startswith("."):
				continue
			if entry.is_dir():
				if entry.name.casefold() == "covers":
					continue
				self._scan_folder_as_movie(entry, found_sources, result, scope)
			elif entry.is_file() and entry.suffix.casefold() in VIDEO_EXTENSIONS:
				self._scan_file_as_movie(entry, found_sources, result, scope)

	def _scan_folder_as_movie(
		self,
		folder: Path,
		found_sources: set[str],
		result: ScanResult,
		scope: str = "main",
	) -> None:
		videos_raw = [
			p for p in folder.rglob("*")
			if p.is_file() and p.suffix.casefold() in VIDEO_EXTENSIONS
		]

		def _sort_key(p: Path) -> tuple:
			season = _find_season(folder, p)
			episode = _parse_episode(p.stem)
			return (
				season if season is not None else 9999,
				episode if episode is not None else 9999,
				str(p).casefold(),
			)

		videos = sorted(videos_raw, key=_sort_key)
		if not videos:
			return

		title = folder.name

		if len(videos) == 1:
			# A series with missing files must not be converted into a new movie.
			path = str(videos[0].resolve()).replace("\\", "/")
			if self.repository.find_series_by_episode_paths([path], scope) is not None:
				self._upsert_series(title, folder, videos, found_sources, result, scope)
			else:
				self._upsert(title, videos[0], found_sources, result, scope)
			return

		# 多视频 → 剧集
		self._upsert_series(title, folder, videos, found_sources, result, scope)

	def _scan_file_as_movie(
		self,
		video: Path,
		found_sources: set[str],
		result: ScanResult,
		scope: str = "main",
	) -> None:
		title = video.stem
		self._upsert(title, video, found_sources, result, scope)

	def _upsert_series(
		self,
		title: str,
		folder: Path,
		videos: list[Path],
		found_sources: set[str],
		result: ScanResult,
		scope: str = "main",
	) -> None:
		"""多视频 = 剧集。"""
		episodes: list[dict] = []
		for order, video in enumerate(videos):
			try:
				source = str(video.resolve()).replace("\\", "/")
			except OSError:
				continue
			found_sources.add(source)

			# 向上找最近的季号文件夹
			season: int | None = _find_season(folder, video)
			
			episode = _parse_episode(video.stem)
			episodes.append({
				"video_path": source,
				"season": season,
				"episode": episode,
				"display_order": order,
				"title": "",
			})

		if not episodes:
			return
		result.total_found += len(episodes)

		# 用第一个视频的路径去查重
		primary = episodes[0]["video_path"]
		existing = self.repository.find_movie_by_source_path(primary, scope)
		if existing is None:
			existing = self.repository.find_series_by_episode_paths(
				[ep["video_path"] for ep in episodes], scope
			)
		if existing is not None:
			# 已存在 → 更新集数列表
			try:
				self.repository.replace_series_episodes(
					str(existing["id"]), episodes
				)
				result.updated += 1
			except Exception:
				logger.exception("failed to update series: %s", title)
				result.errors += 1
			return

		try:
			self.repository.create_series_with_episodes(
				title=title, episodes=episodes, scope=scope
			)
			result.added += 1
		except Exception:
			logger.exception("failed to create series: %s", title)
			result.errors += 1

	def _upsert(
		self,
		title: str,
		video: Path,
		found_sources: set[str],
		result: ScanResult,
		scope: str = "main",
	) -> None:
		try:
			source = str(video.resolve()).replace("\\", "/")
		except OSError:
			result.errors += 1
			return
		found_sources.add(source)
		result.total_found += 1

		existing = self.repository.find_movie_by_source_path(source, scope)
		if existing is None:
			try:
				self.repository.create_movie(title=title, source_path=source, scope=scope)
				result.added += 1
			except Exception:
				logger.exception("failed to create movie: %s", source)
				result.errors += 1
			return

		# A library scan must never overwrite the editable display title.

	def _mark_offline(
		self,
		found_sources: set[str],
		result: ScanResult,
		scope: str = "main",
	) -> None:
		for row in self.repository.list_all_movies_for_scan(scope):
			item_id = str(row["id"])
			src = str(row.get("source_path", ""))
			was_offline = bool(row.get("offline", 0))
			if src in found_sources:
				if was_offline:
					self.repository.set_movie_offline(item_id, False)
					result.online += 1
			else:
				if not was_offline:
					self.repository.set_movie_offline(item_id, True)
					result.offline += 1