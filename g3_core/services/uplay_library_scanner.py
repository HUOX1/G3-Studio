from __future__ import annotations

import logging
import os
import re
from pathlib import Path

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.uplay_library")

# Ubisoft Connect / Uplay 在注册表里的位置，按顺序尝试。
# 子键名是 gameid（数字字符串），子键里是安装信息。
_REGISTRY_ATTEMPTS: tuple[tuple[str, str], ...] = (
	("HKLM", r"SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs"),
	("HKLM", r"SOFTWARE\Ubisoft\Launcher\Installs"),
)


# ---------------------------------------------------------------------------
# 自动挑主程序 exe（抄 Epic 的实现，独立一份，不改 Epic 的）

# 文件名 stem 里含这些词 → 不是主程序
_EXE_NAME_DENY: tuple[str, ...] = (
	"crash", "launcher", "setup", "prereq", "vcredist", "dxsetup",
	"unins", "redist", "directx", "dotnet",
	# Ubisoft 自家的引导器 / 服务，不是游戏本体
	"uplayinstaller", "uplayservice", "ubisoftgamelauncher",
)

# 路径里任一层含这些词 → 整个目录跳过
_EXE_PATH_DENY: tuple[str, ...] = (
	"redist", "_commonredist", "directx", "dotnet",
)

_EXE_MAX_DEPTH: int = 4

# 归一化时去掉空格 / 下划线 / 短横线
_NAME_STRIP_RE = re.compile(r"[\s_\-]+")


def _find_main_exe(install_dir: Path) -> str:
	"""在 install_dir 里递归找最像主程序的 exe。找不到返回空串。"""
	try:
		root = Path(install_dir)
	except (TypeError, ValueError):
		return ""

	# a. 收集候选（限制深度 4 层）
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

			# b. 排除名单：文件名
			if any(k in path.stem.casefold() for k in _EXE_NAME_DENY):
				continue
			# b. 排除名单：路径任一层
			dir_parts = [p.casefold() for p in relative.parts[:-1]]
			if any(
				any(k in part for k in _EXE_PATH_DENY) for part in dir_parts
			):
				continue
			candidates.append(path)
	except OSError:
		logger.exception("failed to scan exe under: %s", root)

	if not candidates:
		return ""

	# c. 优先与 install_dir 名字相似（互相包含即算相似）
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

	# d. 没有相似的 → 体积最大的；体积并列 → 字母序
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


def _normalize_name(text: str) -> str:
	return _NAME_STRIP_RE.sub("", str(text).casefold())


# 目录名"像不像标题"：至少含一个字母才算（纯数字 / 纯符号 → 用 gameid）
_HAS_LETTER_RE = re.compile(r"[^\W\d_]", re.UNICODE)


def _looks_like_title(text: str) -> bool:
	name = str(text).strip()
	if len(name) < 2:
		return False
	return _HAS_LETTER_RE.search(name) is not None


class UplayLibraryScanner:
	"""扫描本机已安装的 Ubisoft Connect (Uplay) 游戏。

	数据来源：注册表 HKLM\\SOFTWARE\\...\\Ubisoft\\Launcher\\Installs 下的子键。
	子键名 = gameid，子键内 InstallDir 或默认值为安装路径。
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
			logger.info("Uplay scan skipped: not on Windows")
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
			logger.warning("Uplay registry key not found")
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
		"""遍历 Installs 下的子键，返回 (items, errors)。"""
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
		"""读子键的所有值；默认值（名字为空串）存到 "" 键下。"""
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
		# 优先 InstallDir，回退默认值（winreg.EnumValue 里默认值的名字是空串）
		raw_path = str(values.get("installdir", "")).strip()
		if not raw_path:
			raw_path = str(values.get("", "")).strip()
		if not raw_path:
			return None

		install_dir = Path(raw_path)
		try:
			if not install_dir.is_dir():
				logger.info("Uplay game uninstalled, skip: %s", raw_path)
				return None
		except OSError:
			return None

		game_id = str(sub_name).strip()
		dir_name = install_dir.name.strip()
		# 目录名不像标题（纯数字 / 太短）→ 回退 gameid
		title = dir_name if _looks_like_title(dir_name) else game_id

		existing = None
		if game_id:
			try:
				existing = self.repository.find_game_by_external_id(game_id, "uplay")
			except Exception:
				logger.exception("find_game_by_external_id failed: uplay/%s", game_id)

		return {
			"title": title,
			"game_id": game_id,
			"install_dir": self._slash(install_dir),
			"launch_exe": _find_main_exe(install_dir),
			"working_directory": self._slash(install_dir),
			"already_exists": existing is not None,
		}

	@staticmethod
	def _slash(path: Path) -> str:
		return str(path).replace("\\", "/")
