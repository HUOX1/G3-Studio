from __future__ import annotations

import logging
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

from g3_core.repository import LibraryRepository
from g3_core.services.media_assets import sanitize_cover_stem
from g3_core.services.vdf_parser import parse_vdf


logger = logging.getLogger("g3.steam_library")

# 库文件夹配置的候选位置（相对 Steam 安装目录）
_LIBRARY_FOLDER_CANDIDATES: tuple[str, ...] = (
	"steamapps/libraryfolders.vdf",
	"config/libraryfolders.vdf",
)


class SteamLibraryScanner:
	"""扫描本地 Steam 库，列出已安装的游戏。

	不落库、不改库，纯查询。
	"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	# ------------------------------------------------------------------
	# 定位 Steam

	@staticmethod
	def find_steam_root() -> Path | None:
		"""找 Steam 安装目录。注册表优先，失败返回 None。"""
		if os.name != "nt":
			return None
		try:
			import winreg
		except ImportError:
			return None

		attempts = (
			(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam", "SteamPath"),
			(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath"),
		)
		for hive, key_path, value_name in attempts:
			try:
				with winreg.OpenKey(hive, key_path) as key:
					value, _kind = winreg.QueryValueEx(key, value_name)
			except OSError:
				continue
			text = str(value or "").strip()
			if not text:
				continue
			root = Path(text)
			if root.is_dir():
				return root
		return None

	# ------------------------------------------------------------------
	# 扫描

	def scan(self) -> dict:
		items: list[dict] = []
		errors = 0

		steam_root = self.find_steam_root()
		if steam_root is None:
			logger.warning("Steam install not found (registry lookup failed)")
			return {
				"items": [],
				"summary": {"total": 0, "new": 0, "existing": 0, "errors": 1},
			}

		# Steam 本地时长（分钟 / 最后游玩时间戳）
		playtimes = self.read_playtimes()

		library_roots = self._library_roots(steam_root)
		if not library_roots:
			logger.warning("no Steam library folders found under %s", steam_root)
			errors += 1

		for root in library_roots:
			steamapps = root / "steamapps"
			if not steamapps.is_dir():
				errors += 1
				continue
			try:
				manifests = sorted(steamapps.glob("appmanifest_*.acf"))
			except OSError:
				logger.exception("failed to list manifests: %s", steamapps)
				errors += 1
				continue

			for manifest in manifests:
				item = self._read_manifest(manifest, root, steam_root, playtimes)
				if item is None:
					errors += 1
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

	def _library_roots(self, steam_root: Path) -> list[Path]:
		"""读 libraryfolders.vdf，返回所有库根目录。"""
		roots: list[Path] = []
		seen: set[str] = set()

		for rel in _LIBRARY_FOLDER_CANDIDATES:
			vdf_path = steam_root / rel
			if not vdf_path.is_file():
				continue
			try:
				data = parse_vdf(vdf_path.read_text(encoding="utf-8", errors="replace"))
			except OSError:
				logger.exception("failed to read %s", vdf_path)
				continue
			except Exception:
				logger.exception("failed to parse %s", vdf_path)
				continue
			for folder in self._collect_paths(data):
				key = str(folder).casefold()
				if key in seen:
					continue
				seen.add(key)
				if folder.is_dir():
					roots.append(folder)
				else:
					logger.warning("steam library folder missing: %s", folder)

		# 兜底：Steam 自己的安装目录也是一个库
		if steam_root.is_dir():
			key = str(steam_root).casefold()
			if key not in seen:
				seen.add(key)
				roots.append(steam_root)
		return roots

	@staticmethod
	def _collect_paths(data: dict) -> list[Path]:
		"""从 libraryfolders.vdf 的解析结果里挖出所有 "path" 字段。"""
		found: list[Path] = []

		def visit(node: object) -> None:
			if not isinstance(node, dict):
				return
			raw = node.get("path")
			if isinstance(raw, str) and raw.strip():
				found.append(Path(raw.strip()))
			for value in node.values():
				if isinstance(value, dict):
					visit(value)

		visit(data)
		return found

	def _read_manifest(
		self,
		manifest: Path,
		library_root: Path,
		steam_root: Path,
		playtimes: dict[int, dict] | None = None,
	) -> dict | None:
		"""解析一个 appmanifest_*.acf，返回候选 item。"""
		try:
			data = parse_vdf(manifest.read_text(encoding="utf-8", errors="replace"))
		except OSError:
			logger.exception("failed to read manifest: %s", manifest)
			return None
		except Exception:
			logger.exception("failed to parse manifest: %s", manifest)
			return None

		entry = data.get("AppState") if isinstance(data, dict) else None
		if not isinstance(entry, dict):
			logger.warning("manifest has no AppState: %s", manifest)
			return None

		try:
			appid = int(str(entry.get("appid", "0")).strip() or 0)
		except ValueError:
			return None
		if appid <= 0:
			return None

		name = str(entry.get("name", "") or "").strip()
		install_dirname = str(entry.get("installdir", "") or "").strip()
		if not name or not install_dirname:
			return None

		install_dir = library_root / "steamapps" / "common" / install_dirname
		existing = self.repository.find_game_by_steam_appid(appid)

		info = (playtimes or {}).get(appid, {})
		playtime_min = int(info.get("playtime_min", 0) or 0)
		last_played_ts = int(info.get("last_played", 0) or 0)
		playtime_seconds = max(0, playtime_min) * 60
		last_played_iso = (
			datetime.fromtimestamp(last_played_ts, timezone.utc).isoformat()
			if last_played_ts > 0 else ""
		)

		# 已入库的 Steam 游戏：Steam 时长更长就顺手刷新（repository 内只增不减）
		if existing is not None and playtime_seconds > 0:
			try:
				self.repository.update_steam_playtime(
					appid, playtime_seconds, last_played_ts
				)
			except Exception:
				logger.exception("update steam playtime failed: appid=%s", appid)

		return {
			"steam_appid": appid,
			"name": name,
			"install_dir": str(install_dir).replace("\\", "/"),
			"install_size_gb": self._parse_size_gb(entry.get("SizeOnDisk")),
			"already_exists": existing is not None,
			"has_cover": self._has_cover(steam_root, appid),
			"playtime_seconds": playtime_seconds,
			"last_played_at": last_played_iso,
		}

	@staticmethod
	def _parse_size_gb(raw: object) -> float:
		try:
			value = int(str(raw).strip() or 0)
		except (TypeError, ValueError):
			return 0.0
		if value <= 0:
			return 0.0
		return round(value / (1024 ** 3), 2)

	def _has_cover(self, steam_root: Path, appid: int) -> bool:
		"""Steam 缓存里有没有竖版封面（library_600x900.jpg）。"""
		cover = (
			steam_root / "appcache" / "librarycache" / str(appid)
			/ "library_600x900.jpg"
		)
		try:
			return cover.is_file()
		except OSError:
			return False

	# ------------------------------------------------------------------
	# 本地时长

	def _find_steam_root(self) -> Path | None:
		"""实例方法版，方便在其它方法里复用。"""
		return self.find_steam_root()

	def _active_user_localconfig(self) -> Path | None:
		"""找当前活跃账号的 localconfig.vdf（userdata 下 mtime 最新的数字目录）。"""
		steam_root = self._find_steam_root()
		if steam_root is None:
			return None
		userdata = steam_root / "userdata"
		if not userdata.is_dir():
			return None

		best_path: Path | None = None
		best_mtime = -1.0
		try:
			entries = sorted(userdata.iterdir())
		except OSError:
			logger.exception("failed to list userdata: %s", userdata)
			return None

		for entry in entries:
			if not entry.name.isdigit():
				continue
			try:
				if not entry.is_dir():
					continue
				candidate = entry / "config" / "localconfig.vdf"
				if not candidate.is_file():
					continue
				mtime = candidate.stat().st_mtime
			except OSError:
				continue
			if mtime > best_mtime:
				best_mtime = mtime
				best_path = candidate
		return best_path

	def get_localconfig_mtime(self) -> float:
		"""返回活跃账号 localconfig.vdf 的 mtime；找不到返回 0.0。给轮询用。"""
		path = self._active_user_localconfig()
		if path is None:
			return 0.0
		try:
			return float(path.stat().st_mtime)
		except OSError:
			return 0.0

	def read_playtimes(self) -> dict[int, dict]:
		"""读 localconfig.vdf，返回 {appid: {"playtime_min": int, "last_played": int}}。

		找不到 SteamID / 文件缺失 / 层级缺失时返回空 dict。
		"""
		path = self._active_user_localconfig()
		if path is None:
			return {}
		try:
			data = parse_vdf(path.read_text(encoding="utf-8", errors="replace"))
		except OSError:
			logger.exception("failed to read localconfig: %s", path)
			return {}
		except Exception:
			logger.exception("failed to parse localconfig: %s", path)
			return {}

		node: object = data
		for key in ("UserLocalConfigStore", "Software", "Valve", "Steam", "apps"):
			if not isinstance(node, dict):
				return {}
			node = node.get(key)
			if node is None:
				return {}
		if not isinstance(node, dict):
			return {}

		result: dict[int, dict] = {}
		for raw_appid, entry in node.items():
			try:
				appid = int(str(raw_appid).strip())
			except (TypeError, ValueError):
				continue
			if appid <= 0 or not isinstance(entry, dict):
				continue
			result[appid] = {
				"playtime_min": self._to_int(entry.get("Playtime")),
				"last_played": self._to_int(entry.get("LastPlayed")),
			}
		return result

	@staticmethod
	def _to_int(raw: object) -> int:
		try:
			return int(str(raw).strip() or 0)
		except (TypeError, ValueError):
			return 0

	# ------------------------------------------------------------------
	# 素材搬运

	# Steam 缓存文件名 → 目标素材名
	_ASSET_MAP: tuple[tuple[str, str], ...] = (
		("library_600x900.jpg", "cover.jpg"),
		("library_hero.jpg", "backdrop.jpg"),
		("logo.png", "logo.png"),
	)

	def _import_steam_assets(self, appid: int, game_title: str, item_id: str | None = None) -> dict:
		"""从 Steam 缓存搬素材到 covers/games/<stem>/。

		目标已存在 → 跳过（不覆盖用户手动换的素材）；
		源缺失 → 跳过该项。返回搬了哪些。
		"""
		result: dict[str, object] = {
			"cover": False, "backdrop": False, "logo": False, "target_dir": "",
		}
		steam_root = self._find_steam_root()
		if steam_root is None or int(appid or 0) <= 0:
			return result

		cache_dir = steam_root / "appcache" / "librarycache" / str(int(appid))
		if not cache_dir.is_dir():
			return result

		covers_root = Path(self.repository.database.path).parent / "covers"
		target_dir = covers_root / "games" / (str(item_id) if item_id else sanitize_cover_stem(game_title))
		try:
			target_dir.mkdir(parents=True, exist_ok=True)
		except OSError:
			logger.exception("failed to create asset dir: %s", target_dir)
			return result

		for source_name, asset_name in self._ASSET_MAP:
			source = cache_dir / source_name
			if not source.is_file():
				continue
			target = target_dir / asset_name
			if target.exists():
				# 已有目标 → 不覆盖
				continue
			try:
				shutil.copy2(source, target)
			except OSError:
				logger.exception("steam asset copy failed: %s", source)
				continue
			key = asset_name.split(".")[0]
			if key == "cover":
				result["cover"] = True
			elif key == "backdrop":
				result["backdrop"] = True
			elif key == "logo":
				result["logo"] = True

		result["target_dir"] = str(target_dir).replace("\\", "/")
		return result
