from __future__ import annotations

import logging
import os
import re
from pathlib import Path

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.rockstar_library")

_REGISTRY_ATTEMPTS: tuple[tuple[str, str], ...] = (
	("HKLM", r"SOFTWARE\WOW6432Node\Rockstar Games"),
	("HKLM", r"SOFTWARE\Rockstar Games"),
)

# 排除非游戏的子键
_EXCLUDE_KEYS: tuple[str, ...] = (
	"launcher",
	"social club",
	"rockstar games social club",
)

# exe 排除名单（参考 Epic 和 Uplay）
_EXE_NAME_DENY: tuple[str, ...] = (
	"crash", "launcher", "setup", "prereq", "vcredist", "dxsetup",
	"unins", "redist", "directx", "dotnet",
	"socialclub", "rockstarlauncher",
)

_EXE_MAX_DEPTH: int = 4
_NAME_STRIP_RE = re.compile(r"[\s_\-]+")


def _normalize_name(text: str) -> str:
	return _NAME_STRIP_RE.sub("", str(text).casefold())


def _find_main_exe(install_dir: Path) -> str:
	"""在 install_dir 里找最像主程序的 exe。"""
	try:
		root = Path(install_dir)
	except (TypeError, ValueError):
		return ""

	candidates: list[Path] = []
	try:
		for path in root.rglob("*.exe"):
			try:
				if not path.is_file():
					continue
				relative = path.relative_to(root)
			except (OSError, ValueError):
				continue
			if len(relative.parts) > _EXE_MAX_DEPTH:
				continue

			if any(k in path.stem.casefold() for k in _EXE_NAME_DENY):
				continue
			
			dir_parts = [p.casefold() for p in relative.parts[:-1]]
			if any("redist" in part for part in dir_parts):
				continue
			candidates.append(path)
	except OSError:
		logger.exception("failed to scan exe under: %s", root)

	if not candidates:
		return ""

	target = _normalize_name(root.name)
	if target:
		scored: list[tuple[int, str, Path]] = []
		for path in candidates:
			stem = _normalize_name(path.stem)
			if not stem:
				continue
			if stem in target or target in stem:
				scored.append((abs(len(stem) - len(target)), stem, path))
		if scored:
			scored.sort(key=lambda item: (item[0], item[1]))
			return str(scored[0][2]).replace("\\", "/")

	def _size(path: Path) -> int:
		try:
			return path.stat().st_size
		except OSError:
			return -1

	candidates.sort(key=lambda p: (-_size(p), str(p).casefold()))
	best = candidates[0]
	if _size(best) <= 0:
		return ""
	return str(best).replace("\\", "/")


class RockstarLibraryScanner:
	"""扫描本机已安装的 Rockstar 游戏。"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	def scan(self) -> dict:
		empty = {
			"items": [],
			"summary": {"total": 0, "new": 0, "existing": 0, "errors": 0},
		}
		if os.name != "nt":
			empty["summary"]["errors"] = 1
			return empty

		try:
			import winreg
		except ImportError:
			empty["summary"]["errors"] = 1
			return empty

		items: list[dict] = []
		errors = 0
		opened = False

		for hive_name, key_path in _REGISTRY_ATTEMPTS:
			hive = winreg.HKEY_LOCAL_MACHINE if hive_name == "HKLM" else winreg.HKEY_CURRENT_USER
			try:
				root = winreg.OpenKey(hive, key_path)
			except OSError:
				continue
			opened = True
			try:
				item, err = self._scan_key(winreg, root)
			finally:
				try:
					winreg.CloseKey(root)
				except Exception:
					pass
			items.extend(item)
			errors += err
			# 只要第一处成功就够
			break

		if not opened:
			empty["summary"]["errors"] = 1
			return empty

		new_count = sum(1 for i in items if not i["already_exists"])
		return {
			"items": items,
			"summary": {
				"total": len(items),
				"new": new_count,
				"existing": len(items) - new_count,
				"errors": errors,
			},
		}

	def _scan_key(self, winreg, root) -> tuple[list[dict], int]:
		items: list[dict] = []
		errors = 0
		try:
			sub_count = winreg.QueryInfoKey(root)[0]
		except OSError:
			return [], 1

		for index in range(sub_count):
			try:
				sub_name = winreg.EnumKey(root, index)
			except OSError:
				errors += 1
				continue
			
			if sub_name.casefold() in _EXCLUDE_KEYS:
				continue

			try:
				sub = winreg.OpenKey(root, sub_name)
			except OSError:
				errors += 1
				continue
			
			try:
				values = self._read_values(winreg, sub)
			finally:
				try:
					winreg.CloseKey(sub)
				except Exception:
					pass
			
			item = self._make_item(values, sub_name)
			if item is None:
				continue
			items.append(item)
		return items, errors

	@staticmethod
	def _read_values(winreg, key) -> dict:
		values: dict[str, str] = {}
		try:
			count = winreg.QueryInfoKey(key)[1]
		except OSError:
			return values
		for i in range(count):
			try:
				name, value, _kind = winreg.EnumValue(key, i)
			except OSError:
				continue
			values[str(name).casefold()] = str(value or "")
		return values

	def _make_item(self, values: dict, sub_name: str) -> dict | None:
		raw_path = str(values.get("installfolder", "")).strip()
		if not raw_path:
			return None

		install_dir = Path(raw_path)
		try:
			if not install_dir.is_dir():
				return None
		except OSError:
			return None

		game_id = str(sub_name).strip()
		title = game_id
		
		# 尝试从注册表里找更好的名字，如果没有就用子键名
		game_name = str(values.get("gamename", "")).strip()
		if game_name:
			title = game_name

		existing = None
		if game_id:
			try:
				existing = self.repository.find_game_by_external_id(game_id, "rockstar")
			except Exception:
				logger.exception("find_game_by_external_id failed: rockstar/%s", game_id)

		return {
			"title": title,
			"game_id": game_id,
			"install_dir": str(install_dir).replace("\\", "/"),
			"launch_exe": _find_main_exe(install_dir),
			"working_directory": str(install_dir).replace("\\", "/"),
			"already_exists": existing is not None,
		}