from __future__ import annotations

import json
import logging
import urllib.error
import urllib.parse
import urllib.request
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


logger = logging.getLogger("g3.tmdb")


TMDB_API_BASE = "https://api.themoviedb.org/3"
TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p"


class TMDBError(RuntimeError):
	pass

TMDB_GENRE_MAP: dict[str, str] = {
	"Action": "动作",
	"Adventure": "冒险",
	"Animation": "动画",
	"Comedy": "喜剧",
	"Crime": "犯罪",
	"Documentary": "纪录片",
	"Drama": "剧情",
	"Family": "家庭",
	"Fantasy": "奇幻",
	"History": "历史",
	"Horror": "恐怖",
	"Music": "音乐",
	"Mystery": "悬疑",
	"Romance": "爱情",
	"Science Fiction": "科幻",
	"TV Movie": "电视电影",
	"Thriller": "惊悚",
	"War": "战争",
	"Western": "西部",
	"Action & Adventure": "动作冒险",
	"Kids": "儿童",
	"News": "新闻",
	"Reality": "真人秀",
	"Sci-Fi & Fantasy": "科幻奇幻",
	"Soap": "肥皂剧",
	"Talk": "脱口秀",
	"War & Politics": "战争政治",
}


def localize_genre(name: str) -> str:
	clean = name.strip()
	if not clean:
		return ""
	return TMDB_GENRE_MAP.get(clean, clean)

@dataclass(slots=True)
class TMDBConfig:
	api_key: str
	language: str = "zh-CN"
	timeout_s: float = 30.0

	@classmethod
	def load(cls, path: Path) -> "TMDBConfig":
		if not path.is_file():
			raise TMDBError(f"TMDB 配置文件不存在：{path}")
		try:
			data = json.loads(path.read_text(encoding="utf-8"))
		except (OSError, json.JSONDecodeError) as exc:
			raise TMDBError(f"读取 tmdb.json 失败：{exc}") from exc
		if not isinstance(data, dict):
			raise TMDBError("tmdb.json 根必须是对象")
		api_key = str(data.get("api_key", "")).strip()
		if not api_key:
			raise TMDBError("tmdb.json 缺少 api_key")
		language = str(data.get("language", "zh-CN")).strip() or "zh-CN"
		return cls(api_key=api_key, language=language)


class TMDBClient:
	def __init__(self, config: TMDBConfig) -> None:
		self.config = config

	def _get(self, path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
		query: dict[str, Any] = {
			"api_key": self.config.api_key,
			"language": self.config.language,
		}
		if params:
			query.update(params)
		url = f"{TMDB_API_BASE}{path}?{urllib.parse.urlencode(query)}"
		req = urllib.request.Request(url, headers={"Accept": "application/json"})

		# 网络抖动重试一次（hosts 直连时偶发超时）
		raw = ""
		last_exc: Exception | None = None
		for attempt in range(2):
			try:
				with urllib.request.urlopen(req, timeout=self.config.timeout_s) as resp:
					raw = resp.read().decode("utf-8")
				last_exc = None
				break
			except urllib.error.HTTPError as exc:
				# 4xx / 5xx 不重试，直接报错
				raise TMDBError(f"TMDB HTTP {exc.code}：{exc.reason}") from exc
			except (urllib.error.URLError, TimeoutError, OSError) as exc:
				last_exc = exc
				if attempt == 0:
					logger.warning("TMDB 请求超时/抖动，重试一次：%s", path)
					continue
		if last_exc is not None:
			reason = getattr(last_exc, "reason", last_exc)
			raise TMDBError(f"TMDB 网络错误：{reason}") from last_exc

		try:
			data = json.loads(raw)
		except json.JSONDecodeError as exc:
			raise TMDBError(f"TMDB 返回非 JSON：{exc}") from exc
		if not isinstance(data, dict):
			raise TMDBError("TMDB 返回数据格式异常")
		return data

	def search_movie(self, query: str, year: str | None = None) -> list[dict[str, Any]]:
		params: dict[str, Any] = {"query": query}
		if year:
			params["year"] = year
		data = self._get("/search/movie", params)
		results = data.get("results", [])
		if not isinstance(results, list):
			return []
		return [self._normalize_hit(r, "movie") for r in results if isinstance(r, dict)]

	def search_tv(self, query: str) -> list[dict[str, Any]]:
		data = self._get("/search/tv", {"query": query})
		results = data.get("results", [])
		if not isinstance(results, list):
			return []
		return [self._normalize_hit(r, "tv") for r in results if isinstance(r, dict)]

	def movie_detail(self, movie_id: int) -> dict[str, Any]:
		return self._get(f"/movie/{movie_id}")

	def tv_detail(self, tv_id: int) -> dict[str, Any]:
		return self._get(f"/tv/{tv_id}")

	def tv_season(self, tv_id: int, season_number: int) -> dict[str, Any]:
		return self._get(f"/tv/{tv_id}/season/{season_number}")

	def movie_images(self, movie_id: int) -> dict[str, Any]:
		return self._get(
			f"/movie/{movie_id}/images",
			{"include_image_language": "zh,en,null"},
		)

	def tv_images(self, tv_id: int) -> dict[str, Any]:
		return self._get(
			f"/tv/{tv_id}/images",
			{"include_image_language": "zh,en,null"},
		)

	def download_image(self, image_path: str, size: str = "w500") -> bytes:
		if not image_path:
			raise TMDBError("image_path 为空")
		url = f"{TMDB_IMAGE_BASE}/{size}{image_path}"
		req = urllib.request.Request(
			url,
			headers={
				"User-Agent": (
					"Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
					"AppleWebKit/537.36 (KHTML, like Gecko) "
					"Chrome/120.0.0.0 Safari/537.36"
				),
			},
		)
		last_exc: Exception | None = None
		for attempt in range(3):
			try:
				with urllib.request.urlopen(req, timeout=20.0) as resp:
					return resp.read()
			except urllib.error.HTTPError as exc:
				raise TMDBError(f"下载封面失败：HTTP {exc.code}") from exc
			except (urllib.error.URLError, TimeoutError, OSError) as exc:
				last_exc = exc
				if attempt < 2:
					time.sleep(0.6 * (attempt + 1))
					continue
		reason = getattr(last_exc, "reason", last_exc)
		raise TMDBError(f"下载封面失败：{reason}") from last_exc
	@staticmethod
	def _normalize_hit(raw: dict[str, Any], kind: str) -> dict[str, Any]:
		if kind == "movie":
			date = str(raw.get("release_date", "") or "")
			title = str(raw.get("title", "") or raw.get("original_title", ""))
			original = str(raw.get("original_title", ""))
		else:
			date = str(raw.get("first_air_date", "") or "")
			title = str(raw.get("name", "") or raw.get("original_name", ""))
			original = str(raw.get("original_name", ""))
		year = date[:4] if len(date) >= 4 else ""
		return {
			"tmdb_id": int(raw.get("id", 0) or 0),
			"title": title,
			"original_title": original,
			"year": year,
			"overview": str(raw.get("overview", "") or ""),
			"poster_path": str(raw.get("poster_path", "") or ""),
		}