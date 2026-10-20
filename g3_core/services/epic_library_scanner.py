from __future__ import annotations

import json
import logging
import os
import re
from pathlib import Path

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.epic_library")

# Epic 的已安装清单
DEFAULT_MANIFEST = Path(
	os.path.join(
		os.environ.get("ProgramData", r"C:\ProgramData"),
		"Epic", "UnrealEngineLauncher", "LauncherInstalled.dat",
	)
)


# 非游戏分类关键词：只要某个分类名里含其中之一就算「非游戏」
_NON_GAME_KEYWORDS: tuple[str, ...] = ("engine", "tool", "plugin", "sdk")


def _is_non_game_category(raw: object) -> bool:
	text = str(raw).strip().lower()
	return any(keyword in text for keyword in _NON_GAME_KEYWORDS)


# ---------------------------------------------------------------------------
# 自动挑主程序 exe

# 文件名 stem 里含这些词 → 不是主程序
_EXE_NAME_DENY: tuple[str, ...] = (
	"crash", "launcher", "setup", "prereq", "vcredist", "dxsetup",
	"unins", "redist", "ue4prereq", "unitycrashhandler", "dotnet",
	# Epic Online Services 的引导器，不是游戏本体
	# （实测 MyNightJob 里 EOSBootstrapper.exe 比真正的 mnj.exe 还大，
	#  不排除掉就会被「体积最大」选走）
	"eosbootstrapper",
)

# 路径里任一层含这些词 → 整个目录跳过
_EXE_PATH_DENY: tuple[str, ...] = (
	"engine", "redist", "_commonredist", "directx", "dotnet",
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


class EpicLibraryScanner:
	"""扫描本机已安装的 Epic 游戏。

	数据来源：%ProgramData%\\Epic\\UnrealEngineLauncher\\LauncherInstalled.dat
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
			logger.info("Epic scan skipped: not on Windows")
			empty["summary"]["errors"] = 1
			return empty

		manifest = DEFAULT_MANIFEST
		if not manifest.is_file():
			logger.warning("Epic LauncherInstalled.dat not found: %s", manifest)
			empty["summary"]["errors"] = 1
			return empty

		try:
			payload = json.loads(manifest.read_text(encoding="utf-8-sig"))
		except (OSError, ValueError):
			logger.exception("failed to read Epic manifest: %s", manifest)
			empty["summary"]["errors"] = 1
			return empty

		install_list = payload.get("InstallationList", []) if isinstance(payload, dict) else []
		if not isinstance(install_list, list):
			logger.warning("Epic manifest InstallationList is not a list")
			empty["summary"]["errors"] = 1
			return empty

		items: list[dict] = []
		errors = 0
		for entry in install_list:
			try:
				item = self._make_item(entry)
			except Exception:
				logger.exception("failed to read Epic entry: %r", entry)
				errors += 1
				continue
			if item is None:
				continue
			items.append(item)

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

	def _make_item(self, entry: object) -> dict | None:
		if not isinstance(entry, dict):
			return None

		# 过滤引擎 / 工具 / 插件 / SDK。
		# 注意：Epic 有不少条目**根本不带 AppCategories**（实测如此），
		# 所以「缺失或空列表」一律按游戏处理。
		# 只要出现任何一个非游戏分类就跳过（例如 ["engines", "applications"]）——
		# 用 any 而不是 all，否则 ["engines","applications"] 这种会被误导入。
		categories = entry.get("AppCategories")
		if isinstance(categories, list) and categories:
			if any(_is_non_game_category(c) for c in categories):
				return None

		app_name = str(entry.get("AppName") or "").strip()
		if not app_name:
			return None

		raw_location = str(entry.get("InstallLocation") or "").strip()
		if not raw_location:
			return None
		install_dir = Path(raw_location)
		try:
			if not install_dir.is_dir():
				logger.info("Epic game not installed, skip: %s", raw_location)
				return None
		except OSError:
			return None

		# AppName 通常是代号（如 "Sugar"），目录名才是用户认得出的名字
		title = install_dir.name.strip() or app_name

		existing = None
		try:
			existing = self.repository.find_game_by_external_id(app_name, "epic")
		except Exception:
			logger.exception("find_game_by_external_id failed: epic/%s", app_name)

		return {
			"title": title,
			"app_name": app_name,
			"namespace_id": str(entry.get("NamespaceId") or "").strip(),
			"item_id": str(entry.get("ItemId") or "").strip(),
			"artifact_id": str(entry.get("ArtifactId") or "").strip(),
			"install_dir": str(install_dir).replace("\\", "/"),
			"launch_exe": _find_main_exe(install_dir),
			"already_exists": existing is not None,
		}
