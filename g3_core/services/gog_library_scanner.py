from __future__ import annotations

import logging
import os
from pathlib import Path

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.gog_library")

# GOG 在注册表里的位置，按顺序尝试
_REGISTRY_ATTEMPTS: tuple[tuple[str, str], ...] = (
	("HKLM", r"SOFTWARE\WOW6432Node\GOG.com\Games"),
	("HKLM", r"SOFTWARE\GOG.com\Games"),
)


class GogLibraryScanner:
	"""扫描本机已安装的 GOG 游戏。

	数据来源：注册表 HKLM\\SOFTWARE\\...\\GOG.com\\Games 下的子键。
	不落库、不改库，纯查询。
	"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	def scan(self) -> dict:
		empty = {
			"items": [],
			"summary": {"total": 0, "new": 0, "existing": 0, "errors": 0},
		}
		if os.name != "nt":
			logger.info("GOG scan skipped: not on Windows")
			empty["summary"]["errors"] = 1
			return empty

		try:
			import winreg
		except ImportError:
			logger.warning("winreg unavailable")
			empty["summary"]["errors"] = 1
			return empty

		items: list[dict] = []
		errors = 0
		opened = False

		for hive_name, key_path in _REGISTRY_ATTEMPTS:
			hive = (
				winreg.HKEY_LOCAL_MACHINE if hive_name == "HKLM"
				else winreg.HKEY_CURRENT_USER
			)
			try:
				root = winreg.OpenKey(hive, key_path)
			except OSError:
				continue
			opened = True
			try:
				item, err = self._scan_key(winreg, root)
			finally:
				self._close_key(winreg, root)
			items.extend(item)
			errors += err
			# 只有第一处成功就够了
			break

		if not opened:
			logger.warning("GOG registry key not found")
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
		"""遍历 GOG\\Games 下的子键，返回 (items, errors)。"""
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
			try:
				sub = winreg.OpenKey(root, sub_name)
			except OSError:
				errors += 1
				continue
			try:
				values = self._read_values(winreg, sub)
			finally:
				self._close_key(winreg, sub)
			item = self._make_item(values, sub_name)
			if item is None:
				continue
			items.append(item)
		return items, errors

	@staticmethod
	def _close_key(winreg, key) -> None:
		"""用官方 winreg.CloseKey 关闭句柄（不依赖 key 对象自带 Close）。"""
		try:
			winreg.CloseKey(key)
		except Exception:
			logger.debug("CloseKey failed", exc_info=True)

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
		raw_path = str(values.get("path", "")).strip()
		if not raw_path:
			return None
		install_dir = Path(raw_path)
		try:
			if not install_dir.is_dir():
				logger.info("GOG game uninstalled, skip: %s", raw_path)
				return None
		except OSError:
			return None

		game_id = str(values.get("gameid", "")).strip() or str(sub_name).strip()
		title = str(values.get("gamename", "")).strip() or install_dir.name

		raw_exe = str(values.get("exe", "")).strip()
		launch_exe = self._slash(install_dir / raw_exe) if raw_exe else ""

		raw_work = str(values.get("workingdir", "")).strip()
		working_directory = (
			self._slash(Path(raw_work)) if raw_work else self._slash(install_dir)
		)

		existing = None
		if game_id:
			try:
				existing = self.repository.find_game_by_external_id(game_id, "gog")
			except Exception:
				logger.exception("find_game_by_external_id failed: gog/%s", game_id)

		return {
			"title": title,
			"game_id": game_id,
			"install_dir": self._slash(install_dir),
			"launch_exe": launch_exe,
			"working_directory": working_directory,
			"already_exists": existing is not None,
		}

	@staticmethod
	def _slash(path: Path) -> str:
		return str(path).replace("\\", "/")
