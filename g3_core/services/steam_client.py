from __future__ import annotations

import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any


logger = logging.getLogger("g3.steam")


STEAM_STORE_BASE = "https://store.steampowered.com"
# 使用中文商店 + 中国区
DEFAULT_LANG = "schinese"
DEFAULT_CC = "cn"


class SteamError(RuntimeError):
	pass


@dataclass(slots=True)
class SteamClient:
	language: str = DEFAULT_LANG
	cc: str = DEFAULT_CC
	timeout_s: float = 30.0
	# 本地缓存：term -> 搜索结果列表（避免重复搜索）
	_search_cache: dict[str, list[dict[str, Any]]] = field(default_factory=dict)

	# ---------- 搜索 ----------

	def search(self, term: str) -> list[dict[str, Any]]:
		"""搜索 Steam 商店。返回 [{appid, name, tiny_image}]。"""
		term = term.strip()
		if not term:
			return []
		if term in self._search_cache:
			return self._search_cache[term]

		url = f"{STEAM_STORE_BASE}/api/storesearch/"
		params = {
			"term": term,
			"l": self.language,
			"cc": self.cc,
		}
		data = self._get_json(url, params)
		items = data.get("items", []) if isinstance(data, dict) else []
		out: list[dict[str, Any]] = []
		for it in items:
			if not isinstance(it, dict):
				continue
			appid = int(it.get("id", 0) or 0)
			if appid <= 0:
				continue
			out.append({
				"appid": appid,
				"name": str(it.get("name", "") or ""),
				"tiny_image": str(it.get("tiny_image", "") or ""),
			})
		self._search_cache[term] = out
		return out

	# ---------- 详情 ----------

	def app_details(self, appid: int) -> dict[str, Any]:
		"""获取 app 详情。返回扁平化的 dict，字段见下方 _normalize。"""
		url = f"{STEAM_STORE_BASE}/api/appdetails"
		params = {
			"appids": str(appid),
			"l": self.language,
			"cc": self.cc,
		}
		data = self._get_json(url, params)
		key = str(appid)
		entry = data.get(key) if isinstance(data, dict) else None
		if not isinstance(entry, dict) or not bool(entry.get("success", False)):
			raise SteamError(f"Steam 未返回 appid={appid} 的数据")
		raw = entry.get("data", {})
		if not isinstance(raw, dict):
			raise SteamError(f"Steam 返回结构异常 appid={appid}")
		return self._normalize(raw)

	def english_name(self, appid: int) -> str:
		"""用英文语言拉一次详情，只取名字。"""
		url = f"{STEAM_STORE_BASE}/api/appdetails"
		params = {"appids": str(appid), "l": "english", "cc": "us"}
		try:
			data = self._get_json(url, params)
		except SteamError:
			return ""
		entry = data.get(str(appid)) if isinstance(data, dict) else None
		if not isinstance(entry, dict) or not bool(entry.get("success", False)):
			return ""
		raw = entry.get("data", {})
		if not isinstance(raw, dict):
			return ""
		return str(raw.get("name", "") or "").strip()

	@staticmethod
	def _normalize(raw: dict[str, Any]) -> dict[str, Any]:
		"""把 Steam 原始结构拍平，字段名统一。"""
		developers = raw.get("developers", []) or []
		publishers = raw.get("publishers", []) or []

		# genres 在 Steam 上可能是 dict 列表，也可能是纯字符串列表 → 两种都兼容
		genres_raw = raw.get("genres", []) or []
		genres: list[str] = []
		for g in genres_raw:
			if isinstance(g, dict):
				desc = str(g.get("description", "") or "")
			else:
				desc = str(g or "")
			if desc:
				genres.append(desc)

		release = raw.get("release_date", {}) or {}
		release_date = (
			str(release.get("date", "") or "")
			if isinstance(release, dict) else ""
		)

		metacritic = raw.get("metacritic", {}) or {}
		metacritic_score = (
			int(metacritic.get("score", 0) or 0)
			if isinstance(metacritic, dict) else 0
		)

		screenshots_raw = raw.get("screenshots", []) or []
		screenshots = [
			str(s.get("path_full", "") or "")
			for s in screenshots_raw if isinstance(s, dict)
		]
		screenshots = [s for s in screenshots if s]

		return {
			"appid": int(raw.get("steam_appid", 0) or 0),
			"name": str(raw.get("name", "") or ""),
			"short_description": str(raw.get("short_description", "") or ""),
			"detailed_description": str(raw.get("detailed_description", "") or ""),
			"developers": [str(x) for x in developers if x],
			"publishers": [str(x) for x in publishers if x],
			"release_date": release_date,
			"genres": genres,
			"metacritic": metacritic_score,
			"screenshots": screenshots,
		}

	# ---------- 下载图片 ----------

	def download_image(self, url: str) -> bytes:
		if not url:
			raise SteamError("图片 URL 为空")
		req = urllib.request.Request(
			url,
			headers={"User-Agent": "Mozilla/5.0"},
		)
		try:
			with urllib.request.urlopen(req, timeout=30.0) as resp:
				return resp.read()
		except urllib.error.HTTPError as exc:
			raise SteamError(f"下载图片失败：HTTP {exc.code}") from exc
		except (urllib.error.URLError, TimeoutError, OSError) as exc:
			reason = getattr(exc, "reason", exc)
			raise SteamError(f"下载图片失败：{reason}") from exc

	# ---------- HTTP ----------

	def _get_json(self, url: str, params: dict[str, Any]) -> Any:
		query = "?" + urllib.parse.urlencode(params)
		full = url + query
		req = urllib.request.Request(full, headers={"User-Agent": "Mozilla/5.0"})
		raw = ""
		last_exc: Exception | None = None
		for attempt in range(3):
			try:
				with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
					raw = resp.read().decode("utf-8")
				last_exc = None
				break
			except urllib.error.HTTPError as exc:
				raise SteamError(f"Steam HTTP {exc.code}：{exc.reason}") from exc
			except (urllib.error.URLError, TimeoutError, OSError) as exc:
				last_exc = exc
				if attempt < 2:
					time.sleep(0.6 * (attempt + 1))
					continue
		if last_exc is not None:
			reason = getattr(last_exc, "reason", last_exc)
			raise SteamError(f"Steam 网络错误：{reason}") from last_exc
		try:
			return json.loads(raw)
		except json.JSONDecodeError as exc:
			raise SteamError(f"Steam 返回非 JSON：{exc}") from exc