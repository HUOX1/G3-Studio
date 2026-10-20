from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
import os
from pathlib import Path
import shutil
import subprocess
import time
from typing import Awaitable, Callable

from .database import Database
from .paths import TerminalPaths
from .repository import LibraryRepository
from .services.media_assets import MediaAssetService
from .services.cover_tool import CoverToolService
from .services.game_runtime import GameRuntime
from .services.library_scanner import MovieLibraryScanner
from .services.emulator_scanner import EmulatorScanner
from .services.steam_library_scanner import SteamLibraryScanner
from .services.gog_library_scanner import GogLibraryScanner
from .services.epic_library_scanner import EpicLibraryScanner
from .services.uplay_library_scanner import UplayLibraryScanner
from .services.rockstar_library_scanner import RockstarLibraryScanner
from .services.psn_library_scanner import PSNLibraryScanner
from .services.themes import ThemeManifest, ThemeService
from .settings import TerminalSettings
from g3_core.version import VERSION, DISPLAY
from .services.tmdb_client import TMDBClient, TMDBConfig, TMDBError, localize_genre
from .services.steamgriddb_client import SGDBClient, SGDBConfig, SGDBError
from .services.steam_client import SteamClient, SteamError
from .services.fontset_store import FontsetStore
from .services.font_scanner import list_windows_fonts
from .services.media_assets import MediaAssetService, sanitize_cover_stem

logger = logging.getLogger("g3.backend")
EventSink = Callable[[str, dict[str, object]], Awaitable[None]]


async def _noop_event_sink(event_type: str, payload: dict[str, object]) -> None:
	return None


def _is_process_running(image_name: str) -> bool:
	"""检查系统里是否有该映像名（= exe 文件名）的进程。仅 Windows。"""
	if os.name != "nt" or not image_name:
		return False
	try:
		kwargs = {
			"capture_output": True,
			"text": True,
			"encoding": "utf-8",
			"errors": "replace",
			"timeout": 5.0,
		}
		if os.name == "nt":
			kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
		result = subprocess.run(
			["tasklist", "/FI", f"IMAGENAME eq {image_name}",
			 "/NH", "/FO", "CSV"],
			**kwargs,
		)
		if result.returncode != 0:
			return False
		out = (result.stdout or "").strip()
		if not out or out.upper().startswith("INFO:"):
			return False
		return image_name.casefold() in out.casefold()
	except Exception:
		logger.debug("tasklist failed", exc_info=True)
		return False


def _list_process_names() -> set[str]:
	"""返回当前所有进程名（含 .exe），casefold 后的小写集合。仅 Windows。"""
	if os.name != "nt":
		return set()
	try:
		kwargs = {
			"capture_output": True,
			"text": True,
			"encoding": "utf-8",
			"errors": "replace",
			"timeout": 5.0,
		}
		if os.name == "nt":
			kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
		result = subprocess.run(
			["tasklist", "/FO", "CSV", "/NH"],
			**kwargs,
		)
		if result.returncode != 0:
			return set()
		names: set[str] = set()
		for line in (result.stdout or "").splitlines():
			line = line.strip()
			if not line or line.startswith("INFO:"):
				continue
			# CSV 格式："name.exe","PID",...
			if not line.startswith('"'):
				continue
			end = line.find('"', 1)
			if end <= 1:
				continue
			name = line[1:end]
			if name:
				names.add(name.casefold())
		return names
	except Exception:
		logger.debug("tasklist failed", exc_info=True)
		return set()


def _find_derived_process(launch_stem: str) -> str:
	"""在进程列表里找以 launch_stem 开头（忽略大小写）的进程名（含 .exe）。

	找到多个选最长的一个（更具体的主程序名通常更长，如
	'sifu-win64-shipping.exe' vs 'sifu.exe'）。
	找不到返回空串。
	"""
	if os.name != "nt" or not launch_stem:
		return ""
	stem_low = launch_stem.casefold()
	best = ""
	for name in _list_process_names():
		if not name.endswith(".exe"):
			continue
		name_stem = name[:-4]
		if name_stem.startswith(stem_low) and name_stem != stem_low:
			if len(name) > len(best):
				best = name
	return best


class BackendApplication:
	def __init__(self, paths: TerminalPaths, *, builtin_theme_root: Path) -> None:
		self.paths = paths
		self.database = Database(paths.database)
		self.repository = LibraryRepository(self.database)
		self.settings = TerminalSettings.default()
		self.media = MediaAssetService(
			self.repository,
			paths.cache,
			covers_root=paths.covers,
			media_root=paths.media,
		)
		self.themes = ThemeService(
			builtin_root=Path(builtin_theme_root),
			user_root=paths.themes,
		)
		self.scanner = MovieLibraryScanner(self.repository)
		self.cover_tool = CoverToolService(self.repository)
		self.game_runtime = GameRuntime(self.repository)
		self.fontsets = FontsetStore(paths.root / "fontsets")
		self._event_sink: EventSink = _noop_event_sink
		self._movie_tasks: set[asyncio.Task[None]] = set()
		self._backdrop_tasks: set[asyncio.Task[None]] = set()
		self._backdrop_tasks_keys: set[str] = set()
		self._sgdb_thumb_tasks: set[asyncio.Task[None]] = set()
		self._steam_watch_task: asyncio.Task[None] | None = None

	def initialize(self) -> None:
		self.paths.ensure()
		self.database.initialize()
		# 一次性把 covers/games 的旧平铺素材迁进「按游戏名分文件夹」结构
		self._migrate_game_assets()
		self._log_broken_steam_appids()
		self.settings = TerminalSettings.load(self.paths.settings)
		self.media.ffmpeg_path = self.settings.ffmpeg_path
		self.settings.save(self.paths.settings)

	def _log_broken_steam_appids(self) -> None:
		"""只记日志：把 source='steam' 但 appid 明显不对（<= 1）的条目标出来。

		这是历史 bug 的脏数据（GDScript 的 `x or default` 返回 bool，
		导致 appid 被写成 1）。怕删错，所以不自动删，交给用户手动清理。
		"""
		try:
			with self.database.connect() as conn:
				rows = conn.execute(
					"""
					SELECT li.title, li.id FROM library_items li
					WHERE li.id IN (
						SELECT item_id FROM games
						WHERE source = 'steam' AND steam_appid <= 1
					)
					"""
				).fetchall()
		except Exception:
			logger.exception("failed to check broken steam appids")
			return
		for row in rows:
			logger.warning(
				"broken steam appid (<=1), please re-import: %s (%s)",
				row["title"], row["id"],
			)
		if rows:
			logger.warning(
				"found %d steam game(s) with broken appid; "
				"remove and re-import them", len(rows)
			)

	def _migrate_game_assets(self) -> None:
		"""把 covers/games/ 的旧平铺素材迁成 covers/games/<游戏名>/ 结构。

		幂等、不覆盖：目标文件已存在就跳过（避免覆盖用户手动换的封面）。
		"""
		games_dir = self.media.covers_root / "games"
		if not games_dir.is_dir():
			return
		image_exts = tuple(self.media.SUPPORTED_COVER_EXTENSIONS)
		sub_kinds = ("backdrop", "logo", "icon")
		moved = 0
		skipped = 0

		try:
			entries = sorted(games_dir.iterdir())
		except OSError:
			logger.exception("failed to list games dir: %s", games_dir)
			return

		for entry in entries:
			try:
				is_dir = entry.is_dir()
			except OSError:
				continue

			# 旧的 <stem>.screenshots/ 目录 → <stem>/screenshots/
			if is_dir:
				if entry.name.casefold().endswith(".screenshots"):
					old_stem = entry.name[: -len(".screenshots")]
					if not old_stem:
						continue
					dest = games_dir / old_stem / "screenshots"
					try:
						dest.mkdir(parents=True, exist_ok=True)
						for shot in sorted(entry.iterdir()):
							if not shot.is_file():
								continue
							dst = dest / shot.name
							if dst.exists():
								skipped += 1
								continue
							shutil.move(str(shot), str(dst))
							moved += 1
						try:
							entry.rmdir()
						except OSError:
							pass
					except Exception:
						logger.exception("screenshots migrate failed: %s", entry)
				continue

			if not entry.is_file():
				continue
			ext = entry.suffix.lstrip(".").casefold()
			if ext not in image_exts:
				continue
			stem = entry.stem
			asset_name = "cover"
			for kind in sub_kinds:
				if stem.casefold().endswith(f".{kind}"):
					asset_name = kind
					stem = stem[: -(len(kind) + 1)]
					break
			if not stem:
				continue
			dest_dir = games_dir / stem
			dest = dest_dir / f"{asset_name}.{entry.suffix.lstrip('.').casefold()}"
			try:
				if dest.exists():
					skipped += 1
					continue
				dest_dir.mkdir(parents=True, exist_ok=True)
				shutil.move(str(entry), str(dest))
				moved += 1
			except Exception:
				logger.exception("game asset migrate failed: %s", entry)

		if moved or skipped:
			logger.info(
				"game assets migrated: moved=%d skipped=%d", moved, skipped
			)

	def set_event_sink(self, sink: EventSink) -> None:
		self._event_sink = sink

	def start_background_tasks(self) -> None:
		"""启动后台任务（时长轮询等）。同步方法，不 await，不阻塞启动。"""
		if self._steam_watch_task is not None:
			return
		try:
			loop = asyncio.get_running_loop()
		except RuntimeError:
			# 没有事件循环就跳过
			logger.debug("no running event loop; steam playtime watch not started")
			return
		self._steam_watch_task = loop.create_task(self._watch_steam_playtime())

	async def close_background_tasks(self) -> None:
		"""取消后台任务，保证优雅退出。"""
		task = self._steam_watch_task
		self._steam_watch_task = None
		if task is None:
			return
		task.cancel()
		try:
			await task
		except asyncio.CancelledError:
			pass
		except Exception:
			logger.exception("steam playtime watch stop failed")

	async def _watch_steam_playtime(self) -> None:
		"""每 10 秒看 localconfig.vdf 的 mtime，变了就刷新 source='steam' 的时长。"""
		last_mtime = 0.0
		while True:
			try:
				await asyncio.sleep(10.0)
				scanner = SteamLibraryScanner(self.repository)
				mtime = await asyncio.to_thread(scanner.get_localconfig_mtime)
				if mtime <= last_mtime:
					continue
				last_mtime = mtime
				playtimes = await asyncio.to_thread(scanner.read_playtimes)
				for appid, info in playtimes.items():
					self.repository.update_steam_playtime(
						appid, info["playtime_min"] * 60, info["last_played"]
					)
				await self._event_sink("library.changed", {"media_type": "game"})
			except asyncio.CancelledError:
				raise
			except Exception:
				logger.exception("steam playtime watch failed")

	async def handle_command(self, command_type: str, payload: dict) -> object:
		if command_type == "library.movies.list":
			scope = str(payload.get("scope", "main")).strip() or "main"
			movies_list = self.repository.list_movies(scope)
			return [self._movie_to_dict(m) for m in movies_list]

		if command_type == "library.games.list":
			games_list = self.repository.list_games()
			return [self._game_to_dict(g) for g in games_list]

		if command_type == "game.create":
			title = str(payload.get("title", "")).strip()
			if not title:
				raise ValueError("title is required")
			# 允许空壳：无启动方式也能建（粘贴建条目、记录老游戏）
			platform = str(payload.get("platform", "")).strip()
			video_path = str(payload.get("video_path", "")).strip()
			description = str(payload.get("description", ""))
			year_raw = payload.get("release_year", "")
			year_text = str(year_raw).strip() if year_raw else None
			source_value = str(payload.get("source", "manual") or "manual").strip().lower()
			steam_appid_value = int(payload.get("steam_appid", 0) or 0)
			game = self.repository.create_game(
				title=title,
				platform=platform,
				developer=str(payload.get("developer", "")),
				psn_playtime_seconds=int(payload.get("psn_playtime_seconds", 0)),				
				publisher=str(payload.get("publisher", "")),
				genres=str(payload.get("genres", "")),
				tags=str(payload.get("tags", "")),				
				english_name=str(payload.get("english_name", "")),
				video_path=video_path,
				description=description,
				release_year=year_text,
				profile_type=str(payload.get("profile_type", "direct")),
				launch_exe=str(payload.get("launch_exe", "")),
				launch_args=str(payload.get("launch_args", "")),
				working_directory=str(payload.get("working_directory", "")),
				content_path=str(payload.get("content_path", "")),
				monitor_exe=str(payload.get("monitor_exe", "")),
				run_as_admin=bool(payload.get("run_as_admin", False)),
				source=source_value,
				steam_appid=steam_appid_value,
				external_id=str(payload.get("external_id", "") or ""),
				namespace_id=str(payload.get("namespace_id", "")).strip(),
				artifact_id=str(payload.get("artifact_id", "")).strip(),
			)
			cover_source = str(payload.get("cover_source", "")).strip()
			if cover_source:
				try:
					self.media.set_game_cover(game["id"], Path(cover_source))
				except Exception as exc:
					logger.warning("game cover import failed: %s", exc)
			# Steam 游戏：顺手从 Steam 缓存搬素材（失败不影响创建）
			if source_value == "steam" and steam_appid_value > 0:
				try:
					steam_scanner = SteamLibraryScanner(self.repository)
					await asyncio.to_thread(
						steam_scanner._import_steam_assets, steam_appid_value, title, game["id"]
					)
				except Exception:
					logger.exception(
						"steam asset import failed: appid=%s", steam_appid_value
					)
			await self._event_sink("library.changed", {"media_type": "game"})
			return self._game_to_dict(game)

		if command_type == "game.remove":
			item_id = self._require_id(payload)
			removed = self.repository.remove_game(item_id)
			if not removed:
				raise KeyError(item_id)
			await self._event_sink(
				"library.changed",
				{"media_type": "game", "item_id": item_id, "removed": True},
			)
			return {"id": item_id, "removed": True}

		if command_type == "game.metadata.get":
			item_id = self._require_id(payload)
			game = self.repository.get_game(item_id)
			if game is None:
				raise KeyError(item_id)
			return self._game_to_dict(game)

		if command_type == "game.metadata.update":
			item_id = self._require_id(payload)
			previous = self.repository.get_game(item_id)
			if previous is None:
				raise KeyError(item_id)
			if str(previous["title"]) != str(payload.get("title", "")).strip():
				self._preserve_game_assets_before_rename(previous)
			updated = self.repository.update_game_metadata(
				item_id,
				title=str(payload.get("title", "")),
				platform=str(payload.get("platform", "")),
				english_name=str(payload.get("english_name", "")),
				description=str(payload.get("description", "")),
				developer=str(payload.get("developer", "")),
				publisher=str(payload.get("publisher", "")),
				release_year=payload.get("release_year"),
				tags=str(payload.get("tags", "")),
				notes=str(payload.get("notes", "")),
				genres=str(payload.get("genres", "")),
			)
			await self._event_sink("library.changed", {"media_type": "game", "item_id": item_id})
			return self._game_to_dict(updated)

		if command_type == "game.launch_profile.update":
			item_id = self._require_id(payload)
			updated = self.repository.update_game_launch_profile(
				item_id,
				profile_type=str(payload.get("profile_type", "direct")),
				launch_exe=str(payload.get("launch_exe", "")),
				launch_args=str(payload.get("launch_args", "")),
				working_directory=str(payload.get("working_directory", "")),
				content_path=str(payload.get("content_path", "")),
				monitor_exe=str(payload.get("monitor_exe", "")),
				run_as_admin=bool(payload.get("run_as_admin", False)),
			)
			await self._event_sink("library.changed", {"media_type": "game", "item_id": item_id})
			return self._game_to_dict(updated)

		if command_type == "game.playtime.set":
			item_id = self._require_id(payload)
			seconds = int(payload.get("seconds", 0) or 0)
			if seconds < 0:
				raise ValueError("seconds must be >= 0")
			ok = self.repository.set_game_playtime(item_id, seconds)
			if not ok:
				raise ValueError("已达到修改次数上限（2 次）")
			await self._event_sink(
				"library.changed",
				{"media_type": "game", "item_id": item_id},
			)
			updated = self.repository.get_game(item_id)
			if updated is None:
				raise KeyError(item_id)
			return self._game_to_dict(updated)

		if command_type == "game.cover.set":
			item_id = self._require_id(payload)
			source_str = str(payload.get("source", "")).strip()
			if not source_str:
				raise ValueError("source is required")
			cover_path = self.media.set_game_cover(item_id, Path(source_str))
			await self._event_sink("library.changed", {"media_type": "game", "item_id": item_id})
			return {"cover": str(cover_path)}

		if command_type == "game.play":
			item_id = self._require_id(payload)
			game = self.repository.get_game(item_id)
			if game is None:
				raise KeyError(item_id)
			try:
				running = self.game_runtime.launch(game)
			except Exception:
				logger.exception("Game launch failed: item=%s", item_id)
				raise
			task = asyncio.create_task(self._watch_game_process(running))
			self._movie_tasks.add(task)
			task.add_done_callback(self._movie_tasks.discard)
			return {"ok": True, "item_id": item_id, "monitorable": running.monitorable}

		if command_type == "movie.backdrop.ensure":
			item_id = self._require_id(payload)
			# 惰性探测总时长（还没测过才派发）
			try:
				if self.repository.get_total_seconds(item_id) <= 0:
					task = asyncio.create_task(self._probe_duration_async(item_id))
					self._backdrop_tasks.add(task)
					task.add_done_callback(self._backdrop_tasks.discard)
			except Exception:
				logger.exception("schedule duration probe failed: %s", item_id)
			cached = self.media.get_cached_movie_backdrops(item_id)
			if cached:
				return {"status": "cached"}
			if item_id in self._backdrop_tasks_keys:
				return {"status": "running"}
			self._backdrop_tasks_keys.add(item_id)
			task = asyncio.create_task(self._ensure_backdrop_async(item_id))
			self._backdrop_tasks.add(task)
			task.add_done_callback(
				lambda t, m=item_id: (
					self._backdrop_tasks.discard(t),
					self._backdrop_tasks_keys.discard(m),
				)
			)
			return {"status": "started"}
		if command_type == "movie.create":
			title = str(payload.get("title", "")).strip()
			if not title:
				raise ValueError("title is required")
			video_path = str(payload.get("video_path", "")).strip()
			if not video_path:
				raise ValueError("video_path is required")
			year_raw = payload.get("release_year", "")
			year_text = str(year_raw).strip() if year_raw else None
			scope = str(payload.get("scope", "main")).strip() or "main"
			movie = self.repository.create_movie(
				title=title,
				source_path=video_path,
				description=str(payload.get("description", "")),
				release_year=year_text,
				scope=scope,
			)
			cover_source = str(payload.get("cover_source", "")).strip()
			if cover_source:
				try:
					self.media.set_movie_cover(movie["id"], Path(cover_source))
				except Exception as exc:
					logger.warning("movie cover import failed: %s", exc)
			else:
				# 没手动指定封面 → 尝试从封面文件夹匹配
				if scope == "private":
					folder_str = self.settings.movie_cover_folder_private
				else:
					folder_str = self.settings.movie_cover_folder_main
				if folder_str and Path(folder_str).is_dir():
					try:
						await asyncio.to_thread(
							self.media.match_local_covers, scope, Path(folder_str)
						)
					except Exception:
						logger.exception("auto local cover match failed")
			await self._event_sink("library.changed", {"media_type": "movie"})
			return self._movie_to_dict(movie)
		if command_type == "movie.remove":
			item_id = self._require_id(payload)
			removed = self.repository.remove_movie(item_id)
			if not removed:
				raise KeyError(item_id)
			await self._event_sink(
				"library.changed",
				{"media_type": "movie", "item_id": item_id, "removed": True},
			)
			return {"id": item_id, "removed": True}
		if command_type == "movie.cover.set":
			item_id = self._require_id(payload)
			source_str = str(payload.get("source", "")).strip()
			if not source_str:
				raise ValueError("source is required")
			cover_path = self.media.set_movie_cover(item_id, Path(source_str))
			await self._event_sink(
				"library.changed",
				{"media_type": "movie", "item_id": item_id},
			)
			return {"cover": str(cover_path)}
		if command_type == "movie.metadata.get":
			item_id = self._require_id(payload)
			movie = self.repository.get_movie(item_id)
			if movie is None:
				raise KeyError(item_id)
			return {
				"id": movie["id"],
				"title": movie["title"],
				"release_year": movie["release_year"],
				"description": movie["description"],
				"genres": str(movie.get("genres", "") or ""),
				"runtime_minutes": int(movie.get("runtime_minutes", 0) or 0),
				"vote_average": float(movie.get("vote_average", 0.0) or 0.0),
				"tagline": str(movie.get("tagline", "") or ""),
				"tmdb_id": int(movie.get("tmdb_id", 0) or 0),
			}
		if command_type == "movie.metadata.update":
			item_id = self._require_id(payload)
			movie = self.repository.get_movie(item_id)
			if movie is None:
				raise KeyError(item_id)
			updated = self.repository.update_movie_metadata(
				item_id,
				title=str(payload.get("title", "")),
				release_year=payload.get("release_year"),
				description=str(payload.get("description", "")),
				tagline=str(payload.get("tagline", "")),
			)
			await self._event_sink(
				"library.changed",
				{"media_type": "movie", "item_id": item_id},
			)
			return updated
		if command_type == "movie.play":
			item_id = self._require_id(payload)
			episode_id = str(payload.get("episode_id", "")).strip()
			source = ""
			if episode_id:
				with self.database.connect() as conn:
					row = conn.execute(
						"SELECT video_path FROM movie_episodes WHERE id = ? AND item_id = ?",
						(episode_id, item_id),
					).fetchone()
					if row is not None:
						source = str(row["video_path"])
			if not source:
				source = self.repository.get_movie_source_path(item_id)
			if not source:
				raise ValueError("movie has no source path")
			source_path = Path(source)
			if not source_path.is_file():
				raise FileNotFoundError(source)

			mpv = str(self.settings.mpv_path or "").strip()
			monitorable = False
			if mpv and Path(mpv).is_file():
				import subprocess
				import time as _time
				kwargs = {}
				if os.name == "nt":
					kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
				proc = subprocess.Popen(
					[
						mpv,
						str(source_path),
						"--fullscreen",
						"--no-border",
						"--ontop",
						"--keep-open=no",
						"--force-window=yes",
					],
					**kwargs,
				)
				task = asyncio.create_task(
					self._watch_movie_process(proc, item_id, _time.monotonic())
				)
				self._movie_tasks.add(task)
				task.add_done_callback(self._movie_tasks.discard)
				monitorable = True
			elif os.name == "nt":
				os.startfile(str(source_path))
			else:
				import subprocess
				subprocess.Popen(["xdg-open", str(source_path)])
			return {"ok": True, "path": str(source_path), "monitorable": monitorable}

		if command_type == "movie.backdrop.refresh":
			item_id = self._require_id(payload)
			# 删掉手动背景图（用户明确点了"重新截取"，就是要覆盖）
			movie = self.repository.get_movie(item_id)
			if movie is not None:
				movies_dir = self.media._movie_asset_dir(movie)
				for ext in self.media.SUPPORTED_COVER_EXTENSIONS:
					stale = movies_dir / f"backdrop.{ext}"
					if stale.is_file():
						try:
							stale.unlink()
						except OSError:
							pass

			# 清缓存
			cache_dir = self.media.cache_root / "movie_backdrop" / item_id
			if cache_dir.is_dir():
				import shutil as _shutil
				_shutil.rmtree(cache_dir, ignore_errors=True)
			if item_id in self._backdrop_tasks_keys:
				return {"status": "already_running"}
			self._backdrop_tasks_keys.add(item_id)
			task = asyncio.create_task(self._ensure_backdrop_async(item_id))
			self._backdrop_tasks.add(task)
			task.add_done_callback(
				lambda t, m=item_id: (
					self._backdrop_tasks.discard(t),
					self._backdrop_tasks_keys.discard(m),
				)
			)
			return {"status": "started"}

		if command_type == "movie.backdrop.set":
			item_id = self._require_id(payload)
			source_str = str(payload.get("source", "")).strip()
			if not source_str:
				raise ValueError("source is required")
			path = self.media.set_movie_backdrop(item_id, Path(source_str))
			await self._event_sink(
				"library.changed",
				{"media_type": "movie", "item_id": item_id},
			)
			return {"backdrop": str(path)}
		if command_type == "tmdb.search":
			query = str(payload.get("query", "")).strip()
			if not query:
				raise ValueError("query is required")
			media_type = str(payload.get("media_type", "movie")).strip() or "movie"
			year = str(payload.get("year", "")).strip() or None
			client = self._get_tmdb_client()
			# urllib 是阻塞调用，放到线程池里跑，避免卡住后端事件循环
			if media_type == "tv":
				return await asyncio.to_thread(client.search_tv, query)
			return await asyncio.to_thread(client.search_movie, query, year)

		if command_type == "tmdb.apply":
			item_id = self._require_id(payload)
			tmdb_id = int(payload.get("tmdb_id", 0) or 0)
			if tmdb_id <= 0:
				raise ValueError("tmdb_id is required")
			media_type = str(payload.get("media_type", "movie")).strip() or "movie"
			result = await asyncio.to_thread(
				self._apply_tmdb, item_id, tmdb_id, media_type
			)
			await self._event_sink("library.changed", {"media_type": "movie", "item_id": item_id})
			return result
		if command_type == "tmdb.poster.list":
			tmdb_id = int(payload.get("tmdb_id", 0) or 0)
			if tmdb_id <= 0:
				raise ValueError("tmdb_id is required")
			media_type = str(payload.get("media_type", "movie")).strip() or "movie"
			client = self._get_tmdb_client()
			if media_type in ("tv", "series"):
				data = await asyncio.to_thread(client.tv_images, tmdb_id)
			else:
				data = await asyncio.to_thread(client.movie_images, tmdb_id)
			posters_raw = data.get("posters", [])
			if not isinstance(posters_raw, list):
				posters_raw = []
			items: list[dict[str, object]] = []
			for p in posters_raw:
				if not isinstance(p, dict):
					continue
				fp = str(p.get("file_path", "") or "")
				if not fp:
					continue
				items.append({
					"file_path": fp,
					"width": int(p.get("width", 0) or 0),
					"height": int(p.get("height", 0) or 0),
					"language": str(p.get("iso_639_1", "") or ""),
					"vote_average": float(p.get("vote_average", 0.0) or 0.0),
					"vote_count": int(p.get("vote_count", 0) or 0),
				})
			items.sort(key=lambda x: float(x["vote_average"]), reverse=True)
			return {"posters": items}

		if command_type == "tmdb.poster.thumb":
			file_path = str(payload.get("file_path", "")).strip()
			if not file_path:
				raise ValueError("file_path is required")
			import hashlib
			h = hashlib.sha1(file_path.encode("utf-8")).hexdigest()[:16]
			cache_dir = self.paths.cache / "tmdb_poster"
			cache_dir.mkdir(parents=True, exist_ok=True)
			target = cache_dir / f"{h}.jpg"
			if not target.is_file():
				client = self._get_tmdb_client()
				data = await asyncio.to_thread(
					client.download_image, file_path, "w185"
				)
				tmp = target.with_suffix(".tmp")
				tmp.write_bytes(data)
				tmp.replace(target)
			return {"path": str(target)}

		if command_type == "tmdb.poster.apply":
			item_id = self._require_id(payload)
			file_path = str(payload.get("file_path", "")).strip()
			if not file_path:
				raise ValueError("file_path is required")
			client = self._get_tmdb_client()
			image_bytes = await asyncio.to_thread(
				client.download_image, file_path, "w500"
			)
			import tempfile
			with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
				tmp.write(image_bytes)
				tmp_path = Path(tmp.name)
			try:
				self.media.set_movie_cover(item_id, tmp_path)
			finally:
				try:
					tmp_path.unlink(missing_ok=True)
				except OSError:
					pass
			await self._event_sink(
				"library.changed",
				{"media_type": "movie", "item_id": item_id},
			)
			return {"applied": True}

		if command_type == "sgdb.search":
			query = str(payload.get("query", "")).strip()
			if not query:
				raise ValueError("query is required")
			client = self._get_sgdb_client()
			return await asyncio.to_thread(client.search_game, query)

		if command_type == "sgdb.assets":
			sgdb_id = int(payload.get("sgdb_id", 0) or 0)
			if sgdb_id <= 0:
				raise ValueError("sgdb_id is required")
			asset_type = str(payload.get("asset_type", "grid")).strip() or "grid"
			client = self._get_sgdb_client()
			if asset_type == "hero":
				items = await asyncio.to_thread(client.get_heroes, sgdb_id)
			elif asset_type == "logo":
				items = await asyncio.to_thread(client.get_logos, sgdb_id)
			elif asset_type == "icon":
				items = await asyncio.to_thread(client.get_icons, sgdb_id)
			else:
				items = await asyncio.to_thread(client.get_grids, sgdb_id)

			def _score_key(it: dict) -> int:
				try:
					return int(it.get("score", 0) or 0)
				except (ValueError, TypeError):
					return 0
			items.sort(key=_score_key, reverse=True)
			MAX_THUMBS = 24
			items = items[:MAX_THUMBS]

			import hashlib
			cache_dir = self.paths.cache / "sgdb_thumb"
			cache_dir.mkdir(parents=True, exist_ok=True)

			def _cached_path(src_url: str) -> str:
				h = hashlib.sha1(src_url.encode("utf-8")).hexdigest()[:16]
				for ext in ("png", "jpg", "jpeg", "webp", "bmp"):
					candidate = cache_dir / f"{h}.{ext}"
					if candidate.is_file():
						return str(candidate).replace("\\", "/")
				return ""

			# 一阶段：只填已有缓存，立即返回列表
			missing: list[dict] = []
			for item in items:
				# 与二阶段 _fetch_one 保持一致的 key 选择
				if bool(item.get("is_animated", False)):
					src_url = str(item.get("url") or "")
				else:
					src_url = str(item.get("thumb") or item.get("url") or "")
				cached = _cached_path(src_url) if src_url else ""
				item["thumb_local"] = cached
				if src_url and not cached:
					missing.append(item)

			# 二阶段：缺的图片派发后台任务，一张下好推一个事件
			if missing:
				task = asyncio.create_task(
					self._download_thumbs_bg(client, missing, asset_type)
				)
				self._sgdb_thumb_tasks.add(task)
				task.add_done_callback(self._sgdb_thumb_tasks.discard)

			return {"items": items, "asset_type": asset_type}

		if command_type == "sgdb.apply":
			item_id = self._require_id(payload)
			sgdb_id = int(payload.get("sgdb_id", 0) or 0)
			url = str(payload.get("url", "")).strip()
			asset_type = str(payload.get("asset_type", "grid")).strip() or "grid"
			if not url:
				raise ValueError("url is required")
			client = self._get_sgdb_client()
			image_bytes = await asyncio.to_thread(client.download_image, url)
			# 按字节头判断真实格式（webp / png / jpg）
			real_ext = self._detect_image_ext(image_bytes)
			import tempfile
			with tempfile.NamedTemporaryFile(suffix=f".{real_ext}", delete=False) as tmp:
				tmp.write(image_bytes)
				tmp_path = Path(tmp.name)
			try:
				if asset_type == "icon":
					self._save_icon_as_png(item_id, tmp_path)
				elif asset_type == "grid":
					self.media.set_game_asset(item_id, tmp_path, "")
				elif asset_type == "hero":
					self.media.set_game_asset(item_id, tmp_path, "backdrop")
				else:
					self.media.set_game_asset(item_id, tmp_path, asset_type)
			finally:
				try:
					tmp_path.unlink(missing_ok=True)
				except OSError:
					pass
			if sgdb_id > 0:
				self.repository.set_game_sgdb_id(item_id, sgdb_id)
			await self._event_sink(
				"library.changed",
				{"media_type": "game", "item_id": item_id},
			)
			return {"applied": True, "asset_type": asset_type}

		if command_type == "game.scrape.search":
			query = str(payload.get("query", "")).strip()
			if not query:
				raise ValueError("query is required")
			client = self._get_steam_client()
			results = await asyncio.to_thread(client.search, query)
			# 统一加 source 字段
			return [
				{
					"source": "steam",
					"external_id": int(r.get("appid", 0)),
					"name": str(r.get("name", "")),
					"tiny_image": str(r.get("tiny_image", "")),
				}
				for r in results
			]

		if command_type == "game.scrape.apply":
			item_id = self._require_id(payload)
			source = str(payload.get("source", "steam")).strip() or "steam"
			external_id = int(payload.get("external_id", 0) or 0)
			if source != "steam":
				raise ValueError(f"unsupported source: {source}")
			if external_id <= 0:
				raise ValueError("external_id is required")
			result = await asyncio.to_thread(
				self._apply_steam_scrape, item_id, external_id
			)
			await self._event_sink(
				"library.changed",
				{"media_type": "game", "item_id": item_id},
			)
			return result

		if command_type == "library.scan_movies":
			scope = str(payload.get("scope", "main")).strip() or "main"
			if scope == "private":
				paths = list(self.settings.movie_library_paths_private)
				folder_str = self.settings.movie_cover_folder_private
			else:
				paths = list(self.settings.movie_library_paths)
				folder_str = self.settings.movie_cover_folder_main
			if not paths:
				return {"added": 0, "updated": 0, "offline": 0,
						"online": 0, "errors": 0, "total_found": 0,
						"message": "未配置库文件夹"}
			result = await asyncio.to_thread(self.scanner.scan, paths, scope)
			# 扫描后自动用封面文件夹匹配
			if folder_str and Path(folder_str).is_dir():
				try:
					await asyncio.to_thread(
						self.media.match_local_covers, scope, Path(folder_str)
					)
				except Exception:
					logger.exception("auto local cover match failed")
			await self._event_sink(
				"library.changed",
				{"media_type": "movie", "scan": True},
			)
			return result.to_dict()

		if command_type == "game.scan_emulator":
			# 纯查询：遍历已配置模拟器的 scan_dirs，列出可导入的候选游戏
			scanner = EmulatorScanner(self.repository)
			return await asyncio.to_thread(scanner.scan)

		if command_type == "game.scan_steam_library":
			# 纯查询：扫本地 Steam 库，列出已安装的游戏
			steam_scanner = SteamLibraryScanner(self.repository)
			return await asyncio.to_thread(steam_scanner.scan)

		if command_type == "game.scan_gog_library":
			# 纯查询：读 GOG 注册表，列出已安装的游戏
			gog_scanner = GogLibraryScanner(self.repository)
			return await asyncio.to_thread(gog_scanner.scan)

		if command_type == "game.scan_epic_library":
			# 纯查询：读 Epic 的 LauncherInstalled.dat，列出已安装的游戏
			epic_scanner = EpicLibraryScanner(self.repository)
			return await asyncio.to_thread(epic_scanner.scan)

		if command_type == "game.scan_uplay_library":
			# 纯查询：读 Ubisoft 注册表，列出已安装的游戏
			uplay_scanner = UplayLibraryScanner(self.repository)
			return await asyncio.to_thread(uplay_scanner.scan)

		if command_type == "game.scan_rockstar_library":
			# 纯查询：读 Rockstar 注册表，列出已安装的游戏
			rockstar_scanner = RockstarLibraryScanner(self.repository)
			return await asyncio.to_thread(rockstar_scanner.scan)

		if command_type == "game.scan_psn_library":
			scanner = PSNLibraryScanner(self.repository)
			return await asyncio.to_thread(scanner.scan, self.paths.psn_config)				

		if command_type == "settings.set_movie_paths":
			paths_value = payload.get("paths", [])
			if not isinstance(paths_value, list):
				raise ValueError("paths must be a list")
			scope = str(payload.get("scope", "main")).strip() or "main"
			merged = self.settings.to_dict()
			if scope == "private":
				merged["movie_library_paths_private"] = [str(p) for p in paths_value]
			else:
				merged["movie_library_paths"] = [str(p) for p in paths_value]
			self.settings = TerminalSettings.from_dict(merged)
			self.settings.save(self.paths.settings)
			return self.settings.to_dict()
		if command_type == "settings.set_movie_cover_folder":
			folder = str(payload.get("folder", "")).strip()
			scope = str(payload.get("scope", "main")).strip() or "main"
			merged = self.settings.to_dict()
			if scope == "private":
				merged["movie_cover_folder_private"] = folder
			else:
				merged["movie_cover_folder_main"] = folder
			self.settings = TerminalSettings.from_dict(merged)
			self.settings.save(self.paths.settings)
			return self.settings.to_dict()

		if command_type == "settings.set_cover_tool_source":
			folder = str(payload.get("folder", "")).strip()
			merged = self.settings.to_dict()
			merged["cover_tool_source_dir"] = folder
			self.settings = TerminalSettings.from_dict(merged)
			self.settings.save(self.paths.settings)
			return self.settings.to_dict()

		if command_type == "cover_tool.scan":
			scope = str(payload.get("scope", "main")).strip() or "main"
			overwrite = bool(payload.get("overwrite", False))
			source_str = str(payload.get("source_dir", "")).strip() or self.settings.cover_tool_source_dir
			if not source_str:
				raise ValueError("未设置源封面目录")
			source_dir = Path(source_str)
			if not source_dir.is_dir():
				raise ValueError(f"源封面目录不存在：{source_dir}")
			output_dir = self.paths.covers_movies
			items = await asyncio.to_thread(
				self.cover_tool.scan, source_dir, scope, output_dir, overwrite
			)
			return {
				"items": [
					{
						"filename": it.filename,
						"file_path": it.file_path,
						"matched_item_id": it.matched_item_id,
						"matched_title": it.matched_title,
						"width": it.width,
						"height": it.height,
						"status": it.status,
						"front_start_px": it.front_start_px,
						"front_width_px": it.front_width_px,
						"reason": it.reason,
					}
					for it in items
				],
				"summary": {
					"total": len(items),
					"auto_ok": sum(1 for it in items if it.status == "auto_ok"),
					"needs_review": sum(1 for it in items if it.status == "needs_review"),
					"skip": sum(1 for it in items if it.status == "skip"),
					"error": sum(1 for it in items if it.status == "error"),
				},
			}

		if command_type == "cover_tool.apply_one":
			source_str = str(payload.get("source_path", "")).strip()
			if not source_str:
				raise ValueError("source_path is required")
			title = str(payload.get("title", "")).strip()
			if not title:
				raise ValueError("title is required")
			front_start_px = int(payload.get("front_start_px", 0) or 0)
			output_dir = self.paths.covers_movies
			written = await asyncio.to_thread(
				self.cover_tool.apply_one,
				Path(source_str), title, front_start_px, output_dir,
			)
			await self._event_sink(
				"library.changed",
				{"media_type": "movie"},
			)
			return {"written": str(written)}

		if command_type == "movie.covers.match_local":
			scope = str(payload.get("scope", "main")).strip() or "main"
			if scope == "private":
				folder_str = self.settings.movie_cover_folder_private
			else:
				folder_str = self.settings.movie_cover_folder_main
			if not folder_str:
				raise ValueError("未配置封面文件夹")
			folder = Path(folder_str)
			if not folder.is_dir():
				raise ValueError(f"封面文件夹不存在：{folder}")
			matched = await asyncio.to_thread(
				self.media.match_local_covers, scope, folder
			)
			await self._event_sink("library.changed", {"media_type": "movie"})
			return {"matched": matched}
		if command_type == "app.info":
			return {
				"version": VERSION,
				"display": DISPLAY,
			}
		if command_type == "settings.get":
			return self.settings.to_dict()
		if command_type == "settings.update":
			merged = self.settings.to_dict()
			merged.update(payload)
			self.settings = TerminalSettings.from_dict(merged)
			self.media.ffmpeg_path = self.settings.ffmpeg_path
			self.settings.save(self.paths.settings)
			return self.settings.to_dict()
		if command_type == "state.get":
			return self.repository.get_state()
		if command_type == "state.update":
			self.repository.update_state(payload)
			return self.repository.get_state()
		if command_type == "fonts.list":
			return await asyncio.to_thread(list_windows_fonts)
		if command_type == "fontsets.list":
			scope_filter = str(payload.get("scope", "")).strip()
			items = [
				{"id": fs.id, "name": fs.name, "scope": fs.scope}
				for fs in self.fontsets.list_fontsets()
			]
			if scope_filter:
				items = [x for x in items if x["scope"] == scope_filter]
			return items
		if command_type == "fontsets.get":
			fontset_id = str(payload.get("id", "default")).strip() or "default"
			scope = str(payload.get("scope", "movies")).strip() or "movies"
			return self.fontsets.get(fontset_id, scope).to_dict()
		if command_type == "fontsets.save":
			fontset_id = str(payload.get("id", "")).strip()
			if not fontset_id:
				raise ValueError("id is required")
			name = str(payload.get("name", "")).strip()
			fields_value = payload.get("fields", {})
			if not isinstance(fields_value, dict):
				raise ValueError("fields must be an object")
			scope = str(payload.get("scope", "movies")).strip() or "movies"
			fs = self.fontsets.save(fontset_id, name, fields_value, scope)
			return fs.to_dict()

		if command_type == "fontsets.create":
			name = str(payload.get("name", "")).strip()
			if not name:
				raise ValueError("name is required")
			copy_from = str(payload.get("copy_from", "")).strip() or None
			scope = str(payload.get("scope", "movies")).strip() or "movies"
			fs = self.fontsets.create(name, copy_from, scope)
			return fs.to_dict()

		if command_type == "fontsets.rename":
			fontset_id = str(payload.get("id", "")).strip()
			new_name = str(payload.get("name", "")).strip()
			if not fontset_id:
				raise ValueError("id is required")
			if not new_name:
				raise ValueError("name is required")
			scope = str(payload.get("scope", "movies")).strip() or "movies"
			fs = self.fontsets.rename(fontset_id, new_name, scope)
			return fs.to_dict()

		if command_type == "fontsets.delete":
			fontset_id = str(payload.get("id", "")).strip()
			if not fontset_id:
				raise ValueError("id is required")
			deleted = self.fontsets.delete(fontset_id)
			return {"id": fontset_id, "deleted": deleted}
		if command_type == "emulators.list":
			return self.repository.list_emulators()

		if command_type == "emulators.save":
			name = str(payload.get("name", "")).strip()
			if not name:
				raise ValueError("name is required")
			scan_dirs = payload.get("scan_dirs", [])
			if scan_dirs is None:
				scan_dirs = []
			saved = self.repository.save_emulator(
				emulator_id=str(payload.get("id", "") or ""),
				name=name,
				executable=str(payload.get("executable", "") or ""),
				working_dir=str(payload.get("working_dir", "") or ""),
				default_args=str(payload.get("default_args", "") or ""),
				content_placeholder=str(
					payload.get("content_placeholder", "") or ""
				),
				scan_dirs=scan_dirs,
				platform_tag=str(payload.get("platform_tag", "") or ""),
				icon_path=str(payload.get("icon_path", "") or ""),
			)
			return saved

		if command_type == "emulators.delete":
			emulator_id = self._require_id(payload)
			deleted = self.repository.delete_emulator(emulator_id)
			return {"id": emulator_id, "deleted": deleted}

		if command_type == "themes.list":
			return self._list_themes()
		if command_type == "theme.current":
			manifest = self.themes.load(self.settings.current_theme)
			return self._theme_to_dict(manifest)
		raise KeyError(f"unknown command: {command_type}")

	def _list_themes(self) -> list[dict[str, object]]:
		"""复用 ThemeService.list_themes()，避免遍历逻辑重复。"""
		active_theme_id: str = self.settings.current_theme
		return [
			{
				"id": manifest.id,
				"name": manifest.name,
				"active": manifest.id == active_theme_id,
			}
			for manifest in self.themes.list_themes()
		]

	async def _ensure_backdrop_async(self, item_id: str) -> None:
		try:
			status = await asyncio.to_thread(
				self.media.extract_movie_backdrops, item_id
			)
		except Exception:
			logger.exception("Movie backdrop extraction failed: %s", item_id)
			return
		if status == "fresh":
			await self._event_sink(
				"library.changed",
				{
					"media_type": "movie",
					"item_id": item_id,
					"backdrop_changed": True,
				},
			)

	async def _probe_duration_async(self, item_id: str) -> None:
		try:
			seconds = await asyncio.to_thread(
				self.media.probe_movie_duration, item_id
			)
		except Exception:
			logger.exception("probe duration failed: %s", item_id)
			return
		if seconds > 0:
			self.repository.set_total_seconds(item_id, seconds)
			logger.info(
				"probed duration: item_id=%s seconds=%d", item_id, seconds
			)

	async def _watch_movie_process(
		self, proc, item_id: str, started_at: float
	) -> None:
		import time as _time
		loop = asyncio.get_running_loop()
		try:
			await loop.run_in_executor(None, proc.wait)
		except Exception:
			logger.exception("Movie process watch failed")
			return

		elapsed = _time.monotonic() - started_at
		# 2 分钟门槛：低于门槛不计入
		if elapsed >= 120.0 and item_id:
			try:
				just_completed = await asyncio.to_thread(
					self.repository.add_watch_seconds, item_id, int(elapsed)
				)
				if just_completed:
					await self._event_sink(
						"movie.watched_complete", {"item_id": item_id}
					)
			except Exception:
				logger.exception(
					"Failed to record watch seconds: item_id=%s", item_id
				)

		await self._event_sink("movie.exited", {})

	async def _watch_game_process(self, running) -> None:
		"""等游戏会话结束。"""
		monitor_name = ""
		raw_monitor = getattr(running, "monitor_exe", "") or ""
		if raw_monitor:
			monitor_name = Path(raw_monitor).name

		counted: bool = True

		if monitor_name:
			counted = await self._watch_by_monitor_name(monitor_name)
		else:
			proc = running.process
			launch_exe = str(getattr(running, "launch_exe", "") or "")
			if not launch_exe:
				# 兜底：从数据库里拿 launch_exe
				try:
					game_row = self.repository.get_game(running.item_id)
					if game_row is not None:
						launch_exe = str(game_row.get("launch_exe", "") or "")
						if not launch_exe and str(game_row.get("profile_type", "direct")) == "direct":
							# direct 模式下，launch_exe 可能为空，真正的启动路径在 source_path
							launch_exe = str(game_row.get("source_path", "") or "")
				except Exception:
					logger.exception("failed to fetch launch_exe for item: %s", running.item_id)
			fallback_name = Path(launch_exe).name if launch_exe else ""

			if proc is None:
				# 管理员启动拿不到句柄 → 用 launch_exe 的文件名兜底轮询
				if fallback_name:
					counted = await self._watch_by_monitor_name(fallback_name)
				else:
					return
			else:
				# 【关键修复】应对 R星/Epic 这种启动壳
				# 刚启动时给一点缓冲，然后用 tasklist 查一下 exe 是不是真的在跑
				if fallback_name and os.name == "nt":
					await asyncio.sleep(1.0)
					if _is_process_running(fallback_name):
						# 如果系统里还有这个进程，说明 Popen 的句柄不可靠
						# 直接放弃 proc.wait()，改用名字轮询，死等它消失
						logger.info(
							"Process handle unreliable, fallback to name polling: %s",
							fallback_name,
						)
						counted = await self._watch_by_monitor_name(fallback_name)
						# 轮询结束后，直接跳到最后记录时长，不再往下走
						started = running.started_at
						now = datetime.now(timezone.utc)
						elapsed = int((now - started).total_seconds())
						if elapsed > 0 and counted:
							try:
								self.repository.update_game_play_stats(running.item_id, elapsed, now)
							except Exception:
								logger.exception("Failed to update playtime: %s", running.item_id)
						await self._event_sink(
							"game.exited",
							{"item_id": running.item_id, "elapsed_seconds": elapsed},
						)
						return

				# 如果句柄可靠，或者不是 Windows，就老老实实等进程退出
				loop = asyncio.get_running_loop()
				try:
					await loop.run_in_executor(None, proc.wait)
				except Exception:
					logger.exception("Game process watch failed")
					return

				# 启动进程正常退出后，找衍生进程
				if launch_exe and os.name == "nt":
					try:
						stem = Path(launch_exe).stem
						derived = ""
						for _ in range(40):
							derived = await loop.run_in_executor(
								None, _find_derived_process, stem
							)
							if derived:
								break
							await asyncio.sleep(1.5)
					except Exception:
						logger.exception("derived process probe failed")
						derived = ""
					if derived:
						logger.info(
							"derived process detected: %s (launcher=%s)",
							derived, launch_exe,
						)
						await self._watch_by_monitor_name(derived)

		started = running.started_at
		now = datetime.now(timezone.utc)
		elapsed = int((now - started).total_seconds())
		if elapsed > 0 and counted:
			try:
				self.repository.update_game_play_stats(running.item_id, elapsed, now)
			except Exception:
				logger.exception("Failed to update playtime: %s", running.item_id)
		await self._event_sink(
			"game.exited",
			{"item_id": running.item_id, "elapsed_seconds": elapsed},
		)

	async def _watch_by_monitor_name(self, monitor_name: str) -> bool:
		"""轮询 monitor_exe 名字的进程：
		1. 等它出现（最长 60 秒）—— 启动器拉游戏本体的时间
		2. 等它消失（每 1.5 秒查一次）
		3. 消失后再等 2 秒确认（避免误判）
		"""
		loop = asyncio.get_running_loop()

		# 阶段 1：等出现（缩短到 15 秒。如果 UAC 被拒绝或闪退，15 秒后自动恢复）
		appear_timeout = 15.0
		t0 = time.monotonic()
		seen = False
		while time.monotonic() - t0 < appear_timeout:
			ok = await loop.run_in_executor(
				None, _is_process_running, monitor_name
			)
			if ok:
				seen = True
				break
			await asyncio.sleep(1.0)
		if not seen:
			logger.info(
				"monitor_exe never appeared within %.0fs: %s",
				appear_timeout, monitor_name,
			)
			return False

		# 阶段 2：等消失
		while True:
			ok = await loop.run_in_executor(
				None, _is_process_running, monitor_name
			)
			if not ok:
				break
			await asyncio.sleep(1.5)

		# 阶段 3：确认 2 秒
		await asyncio.sleep(2.0)
		return True


	def _get_tmdb_client(self) -> TMDBClient:
		try:
			config = TMDBConfig.load(self.paths.tmdb_config)
		except TMDBError as exc:
			raise ValueError(str(exc)) from exc
		return TMDBClient(config)

	def _get_sgdb_client(self) -> SGDBClient:
		try:
			config = SGDBConfig.load(self.paths.sgdb_config)
		except SGDBError as exc:
			raise ValueError(str(exc)) from exc
		return SGDBClient(config)

	def _get_steam_client(self) -> SteamClient:
		# Steam 免费，无需 key
		return SteamClient()

	async def _download_thumbs_bg(
		self, client: SGDBClient, items: list[dict], asset_type: str
	) -> None:
		"""后台并发下载缺的缩略图，每张下好推一个事件。"""
		import hashlib
		cache_dir = self.paths.cache / "sgdb_thumb"
		cache_dir.mkdir(parents=True, exist_ok=True)

		def _fetch_one(item: dict) -> tuple[dict, str]:
			is_anim: bool = bool(item.get("is_animated", False))
			# 动态图：thumb 是 webm，Godot 读不了。用原图（webp）下载 + PIL 缩成 PNG
			if is_anim:
				src_url = str(item.get("url") or "")
			else:
				src_url = str(item.get("thumb") or item.get("url") or "")
			if not src_url:
				return item, ""
			try:
				data = client.download_image(src_url)
			except Exception:
				logger.warning("sgdb thumb download failed: %s", src_url)
				return item, ""
			h = hashlib.sha1(src_url.encode("utf-8")).hexdigest()[:16]
			if is_anim:
				try:
					from PIL import Image as PILImage
					import io
					pil_img = PILImage.open(io.BytesIO(data))
					pil_img.seek(0)
					if pil_img.mode != "RGBA":
						pil_img = pil_img.convert("RGBA")
					pil_img.thumbnail((320, 320), PILImage.LANCZOS)
					target = cache_dir / f"{h}.png"
					tmp = target.with_suffix(".tmp")
					pil_img.save(str(tmp), format="PNG")
					tmp.replace(target)
					return item, str(target).replace("\\", "/")
				except Exception:
					logger.warning("sgdb animated thumb convert failed: %s", src_url)
					return item, ""
			real_ext = self._detect_image_ext(data)
			target = cache_dir / f"{h}.{real_ext}"
			try:
				tmp = target.with_suffix(".tmp")
				tmp.write_bytes(data)
				tmp.replace(target)
			except OSError:
				return item, ""
			return item, str(target).replace("\\", "/")

		def _work() -> list[tuple[dict, str]]:
			from concurrent.futures import ThreadPoolExecutor, as_completed
			out: list[tuple[dict, str]] = []
			with ThreadPoolExecutor(max_workers=12) as pool:
				futures = [pool.submit(_fetch_one, it) for it in items]
				for f in as_completed(futures):
					try:
						out.append(f.result())
					except Exception:
						continue
			return out

		results = await asyncio.to_thread(_work)
		for item, local_path in results:
			if not local_path:
				continue
			item["thumb_local"] = local_path
			url = str(item.get("url", ""))
			if not url:
				continue
			await self._event_sink("sgdb.thumb_ready", {
				"asset_type": asset_type,
				"url": url,
				"thumb_local": local_path,
			})

	@staticmethod
	def _detect_image_ext(data: bytes) -> str:
		"""按字节头判断图片真实格式。SGDB 的 thumb 常见 png / webp。"""
		if data[:8] == b"\x89PNG\r\n\x1a\n":
			return "png"
		if data[:3] == b"\xff\xd8\xff":
			return "jpg"
		if data[:4] == b"RIFF" and len(data) >= 12 and data[8:12] == b"WEBP":
			return "webp"
		if data[:2] == b"BM":
			return "bmp"
		return "jpg"

	@staticmethod
	def _collect_genres(detail: dict) -> str:
		genres_raw = detail.get("genres", [])
		if not isinstance(genres_raw, list):
			return ""
		names: list[str] = []
		for g in genres_raw:
			if isinstance(g, dict):
				name = localize_genre(str(g.get("name", "")))
				if name:
					names.append(name)
		return ", ".join(names)

	def _apply_tmdb(self, item_id: str, tmdb_id: int, media_type: str) -> dict[str, object]:
		client = self._get_tmdb_client()
		if media_type == "tv":
			detail = client.tv_detail(tmdb_id)
			seasons_raw = detail.get("seasons", [])
			seasons = seasons_raw if isinstance(seasons_raw, list) else []

			# 先收集所有季的集标题，再一次性交给 repository 处理
			tmdb_seasons: dict[int, dict[int, dict[str, str]]] = {}
			for season in seasons:
				if not isinstance(season, dict):
					continue
				season_num = int(season.get("season_number", 0) or 0)
				if season_num <= 0:
					# 跳过 specials
					continue
				try:
					season_data = client.tv_season(tmdb_id, season_num)
				except TMDBError as exc:
					logger.warning("拉取 S%02d 失败：%s", season_num, exc)
					continue
				episodes = season_data.get("episodes", [])
				if not isinstance(episodes, list):
					continue
				episode_map: dict[int, dict[str, str]] = {}
				for ep in episodes:
					if not isinstance(ep, dict):
						continue
					ep_num = int(ep.get("episode_number", 0) or 0)
					if ep_num <= 0:
						continue
					ep_name = str(ep.get("name", "") or "").strip()
					ep_overview = str(ep.get("overview", "") or "").strip()
					if not ep_name and not ep_overview:
						continue
					episode_map[ep_num] = {
						"title": ep_name,
						"overview": ep_overview,
					}
				if episode_map:
					tmdb_seasons[season_num] = episode_map

			total_episodes = self.repository.apply_tmdb_episode_metadata(
				item_id, tmdb_seasons
			)

			# 顺便把剧集本身的资料填上
			first_air = str(detail.get("first_air_date", "") or "")
			year = first_air[:4] if len(first_air) >= 4 else ""
			overview = str(detail.get("overview", "") or "")
			genres_str = self._collect_genres(detail)
			episode_run = detail.get("episode_run_time", [])
			runtime_min = 0
			if isinstance(episode_run, list) and episode_run:
				try:
					runtime_min = int(episode_run[0])
				except (ValueError, TypeError):
					runtime_min = 0
			vote = float(detail.get("vote_average", 0.0) or 0.0)
			tagline = str(detail.get("tagline", "") or "").strip()
			self.repository.apply_tmdb_movie(
				item_id,
				release_year=year or None,
				description=overview or None,
				genres=genres_str or None,
				runtime_minutes=runtime_min or None,
				vote_average=vote or None,
				tagline=tagline or None,
				tmdb_id=tmdb_id,
			)
			return {
				"applied": True,
				"media_type": "tv",
				"episodes_updated": total_episodes,
			}

		# 电影
		detail = client.movie_detail(tmdb_id)
		release = str(detail.get("release_date", "") or "")
		year = release[:4] if len(release) >= 4 else ""
		overview = str(detail.get("overview", "") or "")
		genres_str = self._collect_genres(detail)
		runtime_min = int(detail.get("runtime", 0) or 0)
		vote = float(detail.get("vote_average", 0.0) or 0.0)
		tagline = str(detail.get("tagline", "") or "").strip()
		self.repository.apply_tmdb_movie(
			item_id,
			release_year=year or None,
			description=overview or None,
			genres=genres_str or None,
			runtime_minutes=runtime_min or None,
			vote_average=vote or None,
			tagline=tagline or None,
			tmdb_id=tmdb_id,
		)

		# 封面：只有在还没封面时下载
		poster_path = str(detail.get("poster_path", "") or "")
		if poster_path and self.media.resolve_movie_cover(item_id) is None:
			try:
				image_bytes = client.download_image(poster_path, "w500")
				import tempfile
				with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
					tmp.write(image_bytes)
					tmp_path = Path(tmp.name)
				try:
					self.media.set_movie_cover(item_id, tmp_path)
				finally:
					try:
						tmp_path.unlink(missing_ok=True)
					except OSError:
						pass
			except Exception:
				logger.exception("下载 TMDB 封面失败：%s", poster_path)

		return {"applied": True, "media_type": "movie"}

	@staticmethod
	def _require_id(payload: dict) -> str:
		item_id = payload.get("id")
		if not isinstance(item_id, str) or not item_id:
			raise ValueError("id must be a non-empty string")
		return item_id

	def _movie_to_dict(self, movie: dict) -> dict[str, object]:
		item_id = str(movie["id"])
		cover_path = self.media.resolve_movie_cover(item_id)
		backdrop_paths = self.media.get_cached_movie_backdrops(item_id)

		# 查 media_type 和剧集列表
		media_type = "movie"
		episodes: list[dict] = []
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT media_type FROM library_items WHERE id = ?",
				(item_id,),
			).fetchone()
			if row is not None:
				media_type = str(row["media_type"])
		if media_type == "series":
			episodes = self.repository.get_series_episodes(item_id)

		return {
			"id": item_id,
			"media_type": media_type,
			"library_scope": str(movie.get("library_scope", "main")),
			"title": movie["title"],
			"description": movie["description"],
			"offline": bool(movie.get("offline", 0)),
			"watched_complete": bool(movie.get("watched_complete", 0)),
			"developer": movie["developer"],
			"publisher": movie["publisher"],
			"release_year": movie["release_year"],
			"tags": movie["tags"],
			"notes": movie["notes"],
			"genres": str(movie.get("genres", "") or ""),
			"runtime_minutes": int(movie.get("runtime_minutes", 0) or 0),
			"vote_average": float(movie.get("vote_average", 0.0) or 0.0),
			"tagline": str(movie.get("tagline", "") or ""),
			"tmdb_id": int(movie.get("tmdb_id", 0) or 0),
			"platform": "",
			"playtime_seconds": 0,
			"last_played_at": None,
			"cover": str(cover_path).replace("\\", "/") if cover_path else "",
			"backdrop": [str(p).replace("\\", "/") for p in backdrop_paths],
			"episodes": [
				{
					"id": str(ep["id"]),
					"season": ep.get("season"),
					"episode": ep.get("episode"),
					"display_order": int(ep.get("display_order", 0)),
					"title": str(ep.get("title", "")),
					"overview": str(ep.get("overview", "")),
				}
				for ep in episodes
			],
		}

	def _apply_steam_scrape(self, item_id: str, appid: int) -> dict[str, object]:
		"""抓取 Steam 数据、写库。"""
		game = self.repository.get_game(item_id)
		if game is None:
			raise KeyError(item_id)
		client = self._get_steam_client()
		detail = client.app_details(appid)

		# 厂商 / 类型
		developer = "、".join(detail.get("developers", []))
		publisher = "、".join(detail.get("publishers", []))
		genres = ", ".join(detail.get("genres", []))

		# 只用简短介绍，不再拉 HTML 图文混合
		desc = str(detail.get("short_description", "") or "").strip()
		if not desc:
			# 兜底：从 detailed_description 简单剥掉 HTML 标签
			import re as _re
			import html as _html
			detailed = str(detail.get("detailed_description", "") or "")
			if detailed:
				detailed = _re.sub(r"<br\s*/?>", "\n", detailed, flags=_re.IGNORECASE)
				detailed = _re.sub(r"</(p|div|li|ul|ol|h[1-6])>", "\n", detailed, flags=_re.IGNORECASE)
				text_only = _re.sub(r"<[^>]+>", "", detailed)
				text_only = _html.unescape(text_only)
				text_only = _re.sub(r"\n{3,}", "\n\n", text_only)
				text_only = _re.sub(r"[ \t]+", " ", text_only).strip()
				if len(text_only) > 300:
					cut: int = text_only.rfind("。", 0, 300)
					if cut < 100:
						cut = text_only.rfind(". ", 0, 300)
					if cut < 100:
						cut = text_only.rfind("\n", 0, 300)
					if cut < 100:
						cut = 300
					text_only = text_only[:cut + 1].rstrip() + "…"
				desc = text_only

		# 发售年份
		release_date = str(detail.get("release_date", "") or "")
		year = ""
		for token in release_date.replace("年", " ").replace("/", " ").split():
			if token.isdigit() and len(token) == 4:
				year = token
				break

		# 截图（最多 8 张，并发）
		screenshot_urls = list(detail.get("screenshots", []))[:8]
		local_screenshots: list[str] = []
		if screenshot_urls:
			try:
				local_screenshots = self._save_steam_screenshots(
					item_id, screenshot_urls, client
				)
			except Exception:
				logger.exception("Steam 截图下载失败 item_id=%s", item_id)

		import json as _json
		self.repository.apply_steam_metadata(
			item_id,
			steam_appid=appid,
			release_date=release_date,
			screenshots_json=_json.dumps(local_screenshots, ensure_ascii=False),
			metacritic=int(detail.get("metacritic", 0) or 0),
			developer=developer,
			publisher=publisher,
			genres=genres,
			description=desc,
			release_year=year or None,
		)
		return {
			"applied": True,
			"screenshots_count": len(local_screenshots),
			"videos_count": 0,
		}

	def _save_icon_as_png(self, item_id: str, source: Path) -> None:
		"""把下载的 icon 转成 PNG。SGDB 的 icon 是 ICO 格式，Godot 读不了。"""
		from PIL import Image as PILImage
		game = self.repository.get_game(item_id)
		if game is None:
			return
		target_dir = self.media.covers_root / "games" / str(item_id)
		target_dir.mkdir(parents=True, exist_ok=True)
		target = target_dir / "icon.png"
		# 清掉旧的 icon.* 文件（除了 .png 自己）
		for old_ext in ("jpg", "jpeg", "webp", "bmp"):
			stale = target_dir / f"icon.{old_ext}"
			if stale.is_file():
				try:
					stale.unlink()
				except OSError:
					pass
		# ICO 可能有多张图，取最大的
		with PILImage.open(source) as img:
			img = img.convert("RGBA")
			tmp = target.with_suffix(".png.tmp")
			img.save(str(tmp), format="PNG")
			tmp.replace(target)

	def _save_steam_hero(self, item_id: str, data: bytes) -> None:
		game = self.repository.get_game(item_id)
		if game is None:
			return
		target_dir = self.media.covers_root / "games" / str(item_id)
		target_dir.mkdir(parents=True, exist_ok=True)
		# 按字节头判断扩展名
		ext = "jpg"
		if data[:8] == b"\x89PNG\r\n\x1a\n":
			ext = "png"
		elif data[:4] == b"RIFF" and len(data) >= 12 and data[8:12] == b"WEBP":
			ext = "webp"
		target = target_dir / f"backdrop.{ext}"
		# 清掉其他扩展名的旧文件
		for other in ("jpg", "jpeg", "png", "webp", "bmp"):
			if other == ext:
				continue
			stale = target_dir / f"backdrop.{other}"
			if stale.is_file():
				try:
					stale.unlink()
				except OSError:
					pass
		tmp = target.with_name(target.name + ".tmp")
		tmp.write_bytes(data)
		tmp.replace(target)

	def _save_steam_screenshots(
		self, item_id: str, urls: list[str], client: SteamClient
	) -> list[str]:
		game = self.repository.get_game(item_id)
		if game is None:
			return []
		target_dir = self.media.covers_root / "games" / str(item_id) / "screenshots"
		# 清空旧目录
		if target_dir.is_dir():
			import shutil as _shutil
			_shutil.rmtree(target_dir, ignore_errors=True)
		target_dir.mkdir(parents=True, exist_ok=True)

		from concurrent.futures import ThreadPoolExecutor, as_completed

		def _one(idx_url: tuple[int, str]) -> tuple[int, str]:
			idx, url = idx_url
			try:
				data = client.download_image(url)
			except Exception:
				return idx, ""
			ext = "jpg"
			if data[:8] == b"\x89PNG\r\n\x1a\n":
				ext = "png"
			target = target_dir / f"{idx + 1:02d}.{ext}"
			try:
				target.write_bytes(data)
			except OSError:
				return idx, ""
			return idx, str(target).replace("\\", "/")

		results: list[str] = [""] * len(urls)
		with ThreadPoolExecutor(max_workers=6) as pool:
			futures = [pool.submit(_one, (i, u)) for i, u in enumerate(urls)]
			for f in as_completed(futures):
				try:
					idx, path = f.result()
					results[idx] = path
				except Exception:
					continue
		return [p for p in results if p]

	@staticmethod
	def _is_playable(game: dict) -> bool:
		"""判定游戏是否有可用的启动方式。
		无启动方式 → 视为"空壳"（粘贴建条目、只搬资料的老游戏）。
		"""
		profile = str(game.get("profile_type", "direct") or "").lower()
		launch_exe = str(game.get("launch_exe", "") or "").strip()
		source_path = str(game.get("source_path", "") or "").strip()
		content_path = str(game.get("content_path", "") or "").strip()
		source = str(game.get("source", "manual") or "manual").lower()
		steam_appid = int(game.get("steam_appid", 0) or 0)

		if source == "steam" and steam_appid > 0:
			return True
		if profile == "direct":
			return bool(launch_exe) or bool(source_path)
		if profile == "launcher":
			return bool(launch_exe)
		if profile == "emulator":
			return bool(launch_exe) and bool(content_path)
		return False

	def _legacy_game_dir(self, game: dict) -> Path | None:
		"""Reuse legacy title directories only when no other game shares the title."""
		title = str(game["title"])
		if sum(str(g["title"]).casefold() == title.casefold()
		       for g in self.repository.list_games()) != 1:
			return None
		return self.media.covers_root / "games" / sanitize_cover_stem(title)

	def _preserve_game_assets_before_rename(self, game: dict) -> None:
		"""Copy title-based assets into stable ID storage without moving originals."""
		old_dir = self._legacy_game_dir(game)
		if old_dir is None or not old_dir.is_dir():
			return
		dest = self.media.covers_root / "games" / str(game["id"])
		for source in old_dir.rglob("*"):
			if not source.is_file():
				continue
			rel = source.relative_to(old_dir)
			target = dest / rel
			if target.exists():
				continue
			target.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(source, target)

	def _game_to_dict(self, game: dict) -> dict[str, object]:
		item_id = str(game["id"])
		stem = sanitize_cover_stem(str(game["title"]))
		games_dir = self.media.covers_root / "games"
		cover_path: Path | None = None
		backdrop_path: Path | None = None
		logo_path: Path | None = None
		icon_path: Path | None = None
		game_dirs: list[Path] = [games_dir / item_id]
		legacy = self._legacy_game_dir(game)
		if legacy is not None:
			game_dirs.append(legacy)
		for game_dir in game_dirs:
			if not game_dir.is_dir():
				continue
			for ext in self.media.SUPPORTED_COVER_EXTENSIONS:
				if cover_path is None:
					c = game_dir / f"cover.{ext}"
					if c.is_file():
						cover_path = c.resolve()
				if backdrop_path is None:
					c = game_dir / f"backdrop.{ext}"
					if c.is_file():
						backdrop_path = c.resolve()
				if logo_path is None:
					c = game_dir / f"logo.{ext}"
					if c.is_file():
						logo_path = c.resolve()
				if icon_path is None:
					c = game_dir / f"icon.{ext}"
					if c.is_file():
						icon_path = c.resolve()
		last_played = game.get("last_played_at")
		def _p(p: Path | None) -> str:
			return str(p).replace("\\", "/") if p else ""
		
		def _parse_content_blocks(raw: str) -> list[dict]:
			if not raw:
				return []
			try:
				import json as _json
				data = _json.loads(raw)
			except Exception:
				return []
			if not isinstance(data, list):
				return []
			out: list[dict] = []
			for item in data:
				if not isinstance(item, dict):
					continue
				t = str(item.get("type", ""))
				if t == "text":
					out.append({"type": "text", "content": str(item.get("content", ""))})
				elif t == "video":
					p = str(item.get("path", "")).replace("\\", "/")
					if p and Path(p).is_file():
						out.append({"type": "video", "path": p})
			return out

		def _parse_videos(raw: str) -> list[str]:
			if not raw:
				return []
			try:
				import json as _json
				data = _json.loads(raw)
			except Exception:
				return []
			if not isinstance(data, list):
				return []
			out: list[str] = []
			for item in data:
				s = str(item).replace("\\", "/")
				if s and Path(s).is_file():
					out.append(s)
			return out

		def _parse_screenshots(_game: dict, raw: str) -> list[str]:
			if not raw:
				return []
			try:
				import json as _json
				data = _json.loads(raw)
			except Exception:
				return []
			if not isinstance(data, list):
				return []
			out: list[str] = []
			for item in data:
				s = str(item).replace("\\", "/")
				if s and Path(s).is_file():
					out.append(s)
			return out
		return {
			"id": item_id,
			"title": str(game["title"]),
			"platform": str(game.get("platform", "")),
			"english_name": str(game.get("english_name", "") or ""),
			"playable": self._is_playable(game),						
			"description": str(game.get("description", "")),
			"source_path": str(game.get("source_path", "")),
			"profile_type": str(game.get("profile_type", "direct")),
			"launch_exe": str(game.get("launch_exe", "")),
			"launch_args": str(game.get("launch_args", "")),
			"working_directory": str(game.get("working_directory", "")),
			"content_path": str(game.get("content_path", "")),
			"monitor_exe": str(game.get("monitor_exe", "")),
			"run_as_admin": bool(game.get("run_as_admin", 0)),
			"playtime_seconds": int(game.get("playtime_seconds", 0) or 0),
			"psn_playtime_seconds": int(game.get("psn_playtime_seconds", 0) or 0),			
			"playtime_edit_count": int(game.get("playtime_edit_count", 0) or 0),
			"last_played_at": str(last_played) if last_played else "",
			"developer": str(game.get("developer", "")),
			"publisher": str(game.get("publisher", "")),
			"release_year": game.get("release_year"),
			"tags": str(game.get("tags", "") or ""),
			"notes": str(game.get("notes", "") or ""),
			"offline": bool(game.get("offline", 0)),
			"sgdb_id": int(game.get("sgdb_id", 0) or 0),
			"steam_appid": int(game.get("steam_appid", 0) or 0),
			"source": str(game.get("source", "manual") or "manual"),
			"playtime_source": str(game.get("playtime_source", "g3") or "g3"),
			"external_id": str(game.get("external_id", "") or ""),
			"cover_dir": str(games_dir / stem).replace("\\", "/"),
			"namespace_id": str(game.get("namespace_id", "") or ""),
			"artifact_id": str(game.get("artifact_id", "") or ""),
			"release_date": str(game.get("release_date", "") or ""),
			"metacritic": int(game.get("metacritic", 0) or 0),
			"genres": str(game.get("genres", "") or ""),
			"detailed_description": str(game.get("detailed_description", "") or ""),
			"videos": _parse_videos(game.get("videos_json", "")),
			"content_blocks": _parse_content_blocks(game.get("content_blocks", "")),
			"screenshots": _parse_screenshots(
				game, str(game.get("screenshots_json", "") or "")
			),
			"cover": _p(cover_path),
			"backdrop": [_p(backdrop_path)] if backdrop_path else [],
			"logo": _p(logo_path),
			"icon": _p(icon_path),
		}

	@staticmethod
	def _theme_to_dict(manifest: ThemeManifest) -> dict[str, object]:
		return {
			"id": manifest.id,
			"name": manifest.name,
			"colors": manifest.colors,
			"ambient": manifest.ambient,
			"audio": manifest.audio,
			"icons": manifest.icons,
			"transitions": manifest.transitions,
			"directory": str(manifest.directory),
		}