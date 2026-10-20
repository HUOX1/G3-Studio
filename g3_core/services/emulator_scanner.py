from __future__ import annotations

import logging
import re
from pathlib import Path

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.emulator_scanner")

# 光盘镜像扩展名，按优先级从高到低
_EXT_PRIORITY: tuple[str, ...] = (".cue", ".chd", ".iso", ".cso", ".pbp", ".bin")

# 末尾括号内容，例如 " (Japan, Asia)" / " (USA)"
_TRAILING_PAREN = re.compile(r"\s*\([^)]+\)\s*$")

# 不当作游戏候选的文件夹名
_SKIP_FOLDERS: frozenset[str] = frozenset({"shortcuts"})

# 找 PS3_GAME 的最大递归层数
_PS3_MAX_DEPTH: int = 3


class EmulatorScanner:
	"""扫描已配置模拟器的 scan_dirs，列出可导入的游戏候选。

	结构：每个 scan_dir 的直接子文件夹 = 一个游戏候选。
	不落库、不改库，纯查询。
	"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	def scan(self) -> dict:
		items: list[dict] = []
		errors = 0

		for emulator in self.repository.list_emulators():
			emulator_id = str(emulator.get("id", ""))
			emulator_name = str(emulator.get("name", ""))
			platform_tag = str(emulator.get("platform_tag", ""))
			launch_exe = str(emulator.get("executable", "") or "")
			working_dir = str(emulator.get("working_dir", "") or "")
			launch_args = self._resolve_launch_args(emulator)

			raw_dirs: object = emulator.get("scan_dirs", [])
			if not isinstance(raw_dirs, (list, tuple)):
				continue

			for raw_dir in raw_dirs:
				root = Path(str(raw_dir))
				if not root.is_dir():
					logger.warning("scan dir not found: %s", root)
					errors += 1
					continue
				try:
					children = sorted(root.iterdir())
				except OSError:
					logger.exception("failed to list scan dir: %s", root)
					errors += 1
					continue

				for folder in children:
					try:
						if not folder.is_dir():
							continue
					except OSError:
						errors += 1
						continue
					if self._should_skip(folder.name):
						continue
					item = self._make_item(
						folder=folder,
						emulator_id=emulator_id,
						emulator_name=emulator_name,
						platform_tag=platform_tag,
						launch_exe=launch_exe,
						launch_args=launch_args,
						working_directory=working_dir,
					)
					if item is None:
						continue
					items.append(item)

		new_count = sum(1 for i in items if not i["already_exists"])
		existing = len(items) - new_count
		return {
			"items": items,
			"summary": {
				"total": len(items),
				"new": new_count,
				"existing": existing,
				"errors": errors,
			},
		}

	# ------------------------------------------------------------------
	# 单个候选

	def _make_item(
		self,
		*,
		folder: Path,
		emulator_id: str,
		emulator_name: str,
		platform_tag: str,
		launch_exe: str,
		launch_args: str,
		working_directory: str,
	) -> dict | None:
		kind, rom_path = self._detect_kind(folder)
		if kind == "unknown" or rom_path is None:
			return None

		rom = self._to_slash(rom_path)
		exists = self.find_existing(rom)

		if kind == "ps3":
			# PS3 传文件夹路径，标题用文件夹名
			title = folder.name
		else:
			# 光盘镜像：用文件名去扩展名 + 去末尾括号，空了回落文件夹名
			title = self._clean_title(rom_path.stem) or folder.name

		return {
			"suggested_title": title,
			"folder_path": self._to_slash(folder),
			"rom_path": rom,
			"emulator_id": emulator_id,
			"emulator_name": emulator_name,
			"platform_tag": platform_tag,
			"already_exists": exists,
			"kind": kind,
			"launch_exe": launch_exe,
			"launch_args": launch_args,
			"working_directory": working_directory,
		}

	def find_existing(self, rom_path: str) -> bool:
		"""按 source_path 判断该 ROM 是否已经有游戏条目。"""
		return self.repository.find_game_by_video_path(rom_path) is not None

	@staticmethod
	def _should_skip(name: str) -> bool:
		if not name:
			return True
		if name.startswith("."):
			return True
		lower = name.casefold()
		if lower in _SKIP_FOLDERS:
			return True
		if lower.startswith("readme"):
			return True
		return False

	@staticmethod
	def _clean_title(text: str) -> str:
		"""去掉末尾括号内容（只去一次），返回 strip 后的标题。"""
		return _TRAILING_PAREN.sub("", text).strip()

	@staticmethod
	def _to_slash(path: Path) -> str:
		try:
			return str(path.resolve()).replace("\\", "/")
		except OSError:
			return str(path).replace("\\", "/")

	@staticmethod
	def _resolve_launch_args(emulator: dict) -> str:
		"""把模拟器的占位符统一成 {content}，前端导入时直接用。

		这样 game_runtime 不需要知道 {rom} 之类的自定义占位符。
		"""
		args = str(emulator.get("default_args", "") or "")
		placeholder = str(emulator.get("content_placeholder", "") or "").strip()
		if not placeholder or placeholder == "{content}":
			return args
		return args.replace(placeholder, "{content}")

	# ------------------------------------------------------------------
	# 类型识别

	def _detect_kind(self, folder: Path) -> tuple[str, Path | None]:
		"""判断候选文件夹是 PS3 文件夹还是光盘镜像。

		返回 (kind, path)：
		- ("ps3", folder)  PS3 传文件夹路径
		- ("file", rom)    光盘镜像传文件路径
		- ("unknown", None)
		"""
		if self._find_ps3_game(folder) is not None:
			return ("ps3", folder)
		rom = self._find_disc_image(folder)
		if rom is not None:
			return ("file", rom)
		return ("unknown", None)

	@staticmethod
	def _find_ps3_game(folder: Path) -> Path | None:
		"""在 folder 起最多 3 层内找名为 PS3_GAME 的子目录。

		注意：folder 自身就叫 PS3_GAME 时**不算**——否则普通光盘镜像的
		PS3_GAME 子目录会被误判成 PS3 文件夹游戏。
		"""
		frontier: list[Path] = [folder]
		for _depth in range(_PS3_MAX_DEPTH):
			next_frontier: list[Path] = []
			for current in frontier:
				try:
					children = sorted(current.iterdir())
				except OSError:
					continue
				for child in children:
					try:
						if not child.is_dir():
							continue
					except OSError:
						continue
					if child.name.casefold() == "ps3_game":
						return child
					next_frontier.append(child)
			if not next_frontier:
				return None
			frontier = next_frontier
		return None

	@staticmethod
	def _find_disc_image(folder: Path) -> Path | None:
		"""按扩展名优先级挑一个光盘镜像；同优先级取文件名字典序最小。

		只认直接子文件，不递归。扩展名比较忽略大小写。
		"""
		try:
			files = sorted(
				(p for p in folder.iterdir() if p.is_file()),
				key=lambda p: p.name.casefold(),
			)
		except OSError:
			return None
		for ext in _EXT_PRIORITY:
			for path in files:
				if path.suffix.casefold() == ext:
					return path
		return None
