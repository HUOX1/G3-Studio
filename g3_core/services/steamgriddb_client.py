from __future__ import annotations

import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


logger = logging.getLogger("g3.sgdb")


SGDB_API_BASE = "https://www.steamgriddb.com/api/v2"


class SGDBError(RuntimeError):
	pass


@dataclass(slots=True)
class SGDBConfig:
	api_key: str
	timeout_s: float = 30.0

	@classmethod
	def load(cls, path: Path) -> "SGDBConfig":
		if not path.is_file():
			raise SGDBError(f"SteamGridDB 配置文件不存在：{path}")
		try:
			data = json.loads(path.read_text(encoding="utf-8"))
		except (OSError, json.JSONDecodeError) as exc:
			raise SGDBError(f"读取 sgdb.json 失败：{exc}") from exc
		if not isinstance(data, dict):
			raise SGDBError("sgdb.json 根必须是对象")
		api_key = str(data.get("api_key", "")).strip()
		if not api_key:
			raise SGDBError("sgdb.json 缺少 api_key")
		return cls(api_key=api_key)


class SGDBClient:
	def __init__(self, config: SGDBConfig) -> None:
		self.config = config

	def _get(self, path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
		query = ""
		if params:
			query = "?" + urllib.parse.urlencode(params)
		url = f"{SGDB_API_BASE}{path}{query}"
		logger.debug("SGDB GET %s", url)
		req = urllib.request.Request(
			url,
			headers={
				"Authorization": f"Bearer {self.config.api_key}",
				"Accept": "application/json",
				"User-Agent": (
					"Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
					"AppleWebKit/537.36 (KHTML, like Gecko) "
					"Chrome/120.0.0.0 Safari/537.36"
				),
			},
		)
		raw = ""
		last_exc: Exception | None = None
		for attempt in range(2):
			try:
				with urllib.request.urlopen(req, timeout=self.config.timeout_s) as resp:
					raw = resp.read().decode("utf-8")
				logger.debug(
					"SGDB OK status=%s len=%d body[:160]=%r",
					getattr(resp, "status", "?"), len(raw), raw[:160],
				)
				last_exc = None
				break
			except urllib.error.HTTPError as exc:
				logger.warning("SGDB HTTPError %s %s", exc.code, exc.reason)
				raise SGDBError(f"SteamGridDB HTTP {exc.code}：{exc.reason}") from exc
			except (urllib.error.URLError, TimeoutError, OSError) as exc:
				logger.debug(
					"SGDB attempt %d error: %s %s",
					attempt, type(exc).__name__, exc,
				)
				last_exc = exc
				if attempt == 0:
					logger.warning("SGDB 请求超时/抖动，重试一次：%s", path)
					continue
		if last_exc is not None:
			reason = getattr(last_exc, "reason", last_exc)
			raise SGDBError(f"SteamGridDB 网络错误：{reason}") from last_exc

		try:
			data = json.loads(raw)
		except json.JSONDecodeError as exc:
			raise SGDBError(f"SteamGridDB 返回非 JSON：{exc}") from exc
		if not isinstance(data, dict):
			raise SGDBError("SteamGridDB 返回数据格式异常")
		if not bool(data.get("success", False)):
			raise SGDBError(f"SteamGridDB 请求失败：{data}")
		return data

	def search_game(self, term: str) -> list[dict[str, Any]]:
		"""按名称搜游戏。返回 [{id, name, types}]。"""
		term = term.strip()
		if not term:
			return []
		data = self._get(f"/search/autocomplete/{urllib.parse.quote(term)}")
		items = data.get("data", [])
		if not isinstance(items, list):
			return []
		out: list[dict[str, Any]] = []
		for it in items:
			if not isinstance(it, dict):
				continue
			out.append({
				"id": int(it.get("id", 0) or 0),
				"name": str(it.get("name", "") or ""),
				"types": list(it.get("types", []) or []),
			})
		return out

	def get_grids(self, game_id: int) -> list[dict[str, Any]]:
		"""返回竖版封面（600x900 等）。types=static,animated 才能拿到动图。"""
		return self._fetch_asset_list(
			f"/grids/game/{game_id}",
			extra_kind="grid",
			params={"types": "static,animated"},
		)

	def get_heroes(self, game_id: int) -> list[dict[str, Any]]:
		"""返回横版壁纸（1920x620 / 3840x1240 等）。"""
		return self._fetch_asset_list(f"/heroes/game/{game_id}", extra_kind="hero")

	def get_logos(self, game_id: int) -> list[dict[str, Any]]:
		"""返回透明底 LOGO。"""
		return self._fetch_asset_list(f"/logos/game/{game_id}", extra_kind="logo")

	def get_icons(self, game_id: int) -> list[dict[str, Any]]:
		"""返回图标。"""
		return self._fetch_asset_list(f"/icons/game/{game_id}", extra_kind="icon")

	def _fetch_asset_list(
		self,
		path: str,
		extra_kind: str,
		params: dict[str, Any] | None = None,
	) -> list[dict[str, Any]]:
		data = self._get(path, params)
		items = data.get("data", [])
		if not isinstance(items, list):
			return []
		out: list[dict[str, Any]] = []
		for it in items:
			if not isinstance(it, dict):
				continue
			url = str(it.get("url", "") or "")
			thumb = str(it.get("thumb", "") or "")
			if not url and not thumb:
				continue
			mime: str = str(it.get("mime", "") or "").lower()
			is_animated: bool = ("webp" in mime) and (thumb.endswith(".webm") or url.endswith(".webp"))
			entry = {
				"id": int(it.get("id", 0) or 0),
				"url": url,
				"thumb": thumb,
				"width": int(it.get("width", 0) or 0),
				"height": int(it.get("height", 0) or 0),
				"style": str(it.get("style", "") or ""),
				"language": str(it.get("language", "") or ""),
				"mime": mime,
				"is_animated": is_animated,
				"kind": extra_kind,
			}
			out.append(entry)
		return out

	def download_image(self, url: str) -> bytes:
		if not url:
			raise SGDBError("素材 URL 为空")
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
		try:
			with urllib.request.urlopen(req, timeout=30.0) as resp:
				return resp.read()
		except urllib.error.HTTPError as exc:
			raise SGDBError(f"下载素材失败：HTTP {exc.code}") from exc
		except (urllib.error.URLError, TimeoutError, OSError) as exc:
			reason = getattr(exc, "reason", exc)
			raise SGDBError(f"下载素材失败：{reason}") from exc
