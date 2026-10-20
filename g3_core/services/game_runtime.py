from __future__ import annotations

import logging
import os
import shlex
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from g3_core.repository import LibraryRepository


if os.name == "nt":
	# 只在 Windows 导入；其他地方保持无副作用
	import ctypes


logger = logging.getLogger("g3.game_runtime")


def _allow_set_foreground_window() -> None:
	"""放行前台切换，让即将启动的游戏能自己抢到前台。

	Windows 的前台锁定：新进程默认不允许抢前台，除非父进程显式放行。
	ASFW_ANY = -1 表示不限制哪个进程可以抢前台。

	只在 Windows 生效；失败也不影响启动，所以吞掉异常。
	"""
	if os.name != "nt":
		return
	try:
		ctypes.windll.user32.AllowSetForegroundWindow(-1)
	except Exception:
		logger.debug("AllowSetForegroundWindow failed", exc_info=True)


def _startupinfo_for_windows() -> subprocess.STARTUPINFO | None:
	"""Windows 下给新进程一个「正常显示」的启动信息，帮助它出现在前台。"""
	if os.name != "nt":
		return None
	si = subprocess.STARTUPINFO()
	si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
	si.wShowWindow = 1  # SW_SHOWNORMAL
	return si


def _force_foreground(hwnd) -> None:
	"""用 AttachThreadInput 绕过前台锁定，把窗口拉到前台。仅 Windows。"""
	if os.name != "nt":
		return
	try:
		import ctypes

		user32 = ctypes.windll.user32
		fg_hwnd = user32.GetForegroundWindow()
		fg_thread = user32.GetWindowThreadProcessId(fg_hwnd, None)
		target_thread = user32.GetWindowThreadProcessId(hwnd, None)
		if fg_thread != target_thread:
			user32.AttachThreadInput(fg_thread, target_thread, True)
		try:
			user32.ShowWindow(hwnd, 9)  # SW_RESTORE
			user32.SetForegroundWindow(hwnd)
			user32.BringWindowToTop(hwnd)
			user32.SetActiveWindow(hwnd)
		finally:
			if fg_thread != target_thread:
				user32.AttachThreadInput(fg_thread, target_thread, False)
	except Exception:
		logger.debug("force foreground failed", exc_info=True)


def _bring_window_to_front_by_pid(pid: int, timeout_s: float = 3.0) -> None:
	"""等待 pid 对应的可见窗口出现，把它拉到前台。仅 Windows，后台线程运行。"""
	if os.name != "nt" or pid <= 0:
		return
	try:
		import ctypes
		from ctypes import wintypes
		import time

		user32 = ctypes.windll.user32
		WNDENUMPROC = ctypes.WINFUNCTYPE(
			wintypes.BOOL, wintypes.HWND, wintypes.LPARAM
		)
		deadline = time.time() + timeout_s
		while time.time() < deadline:
			found = [None]

			def enum_proc(hwnd, _lparam):
				win_pid = wintypes.DWORD()
				user32.GetWindowThreadProcessId(hwnd, ctypes.byref(win_pid))
				if win_pid.value == pid and user32.IsWindowVisible(hwnd):
					# 排除无标题的隐藏窗口
					if user32.GetWindowTextLengthW(hwnd) > 0:
						found[0] = hwnd
						return False
				return True

			user32.EnumWindows(WNDENUMPROC(enum_proc), 0)
			if found[0] is not None:
				_force_foreground(found[0])
				return
			time.sleep(0.15)
	except Exception:
		logger.debug("bring to front failed", exc_info=True)


@dataclass(slots=True)
class RunningGame:
	item_id: str
	process: subprocess.Popen | None
	started_at: datetime
	launch_exe: str
	monitorable: bool = True
	monitor_exe: str = ""


class GameRuntime:
	"""游戏启动器。支持 direct / launcher / emulator 三种模式。"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	def launch(self, game: dict) -> RunningGame:
		"""根据启动配置启动游戏。"""
		# Steam 游戏走 steam:// URL 交给 Steam 客户端启动，拿不到进程句柄
		source = str(game.get("source", "manual")).lower()
		steam_appid = int(game.get("steam_appid", 0) or 0)
		external_id = str(game.get("external_id", "") or "").strip()
		if source == "steam" and steam_appid > 0:
			if os.name == "nt":
				# 优先用 steam.exe -applaunch（比 URL 可靠，避免"配置文件不可用"）
				from g3_core.services.steam_library_scanner import SteamLibraryScanner

				steam_root = SteamLibraryScanner.find_steam_root()
				steam_exe = (steam_root / "steam.exe") if steam_root else None
				if steam_exe and steam_exe.is_file():
					kwargs = {"creationflags": subprocess.CREATE_NO_WINDOW}
					subprocess.Popen(
						[str(steam_exe), "-applaunch", str(steam_appid)], **kwargs
					)
					logger.info(
						"Steam game launched via steam.exe: appid=%s", steam_appid
					)
				else:
					# 兜底：URL
					os.startfile(f"steam://rungameid/{steam_appid}")
					logger.info(
						"Steam game launched via URL (fallback): appid=%s", steam_appid
					)
			else:
				import subprocess as _subprocess

				_subprocess.Popen(
					["xdg-open", f"steam://rungameid/{steam_appid}"]
				)
				logger.info("Steam game launched via xdg-open: appid=%s", steam_appid)
			return RunningGame(
				item_id=str(game.get("id", "")),
				process=None,
				started_at=datetime.now(timezone.utc),
				launch_exe="",
				monitorable=False,
				monitor_exe="",
			)

		# Epic：优先直接启动 exe（拿得到句柄、能计时）。
		# URL 会报 "Application Not Owned"，只作为没有 exe 时的回落。
		if source == "epic":
			launch_exe = str(game.get("launch_exe", "") or "").strip()
			if launch_exe and Path(launch_exe).is_file():
				exe_path = Path(launch_exe)
				epic_kwargs: dict = {"cwd": str(exe_path.parent)}
				if os.name == "nt":
					epic_kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
					_allow_set_foreground_window()
					epic_si = _startupinfo_for_windows()
					if epic_si is not None:
						epic_kwargs["startupinfo"] = epic_si
				epic_process = subprocess.Popen([str(exe_path)], **epic_kwargs)
				logger.info("Epic game launched via exe: %s", exe_path)
				# 后台线程把窗口拉到前台
				if os.name == "nt" and epic_process is not None:
					import threading

					threading.Thread(
						target=_bring_window_to_front_by_pid,
						args=(epic_process.pid, 3.0),
						daemon=True,
					).start()
				return RunningGame(
					item_id=str(game.get("id", "")),
					process=epic_process,
					started_at=datetime.now(timezone.utc),
					launch_exe=str(exe_path),
					monitorable=True,
					monitor_exe=str(game.get("monitor_exe", "") or "").strip(),
				)

			# 没有可用 exe → 回落 URL（老数据）
			if external_id:
				namespace_id = str(game.get("namespace_id", "") or "").strip()
				artifact_id = str(game.get("artifact_id", "") or "").strip()
				if os.name == "nt":
					if namespace_id and artifact_id:
						# 官方完整三元组格式（冒号做 URL 编码）
						url = (
							f"com.epicgames.launcher://apps/"
							f"{namespace_id}%3A{external_id}%3A{artifact_id}"
							f"?action=launch&silent=true"
						)
					else:
						# 兼容旧的单哈希格式
						url = (
							f"com.epicgames.launcher://apps/"
							f"{external_id}?action=launch&silent=true"
						)
					os.startfile(url)
					logger.info("Epic game launched via URL: %s", url)
				else:
					logger.warning("Epic launch only supported on Windows")
				return RunningGame(
					item_id=str(game.get("id", "")),
					process=None,
					started_at=datetime.now(timezone.utc),
					launch_exe="",
					monitorable=False,
					monitor_exe="",
				)
			# 都没有 → 落到下面普通逻辑（会报 launch_exe 缺失）

		profile_type = str(game.get("profile_type", "direct")).lower()
		launch_exe = str(game.get("launch_exe", "")).strip()
		content_path = str(game.get("content_path", "")).strip()
		launch_args = str(game.get("launch_args", "")).strip()
		working_dir = str(game.get("working_directory", "")).strip()
		run_as_admin = bool(game.get("run_as_admin", 0))

		# direct 模式：没有单独的 launch_exe，用 source_path 当 exe
		if profile_type == "direct" and not launch_exe:
			launch_exe = str(game.get("source_path", "")).strip()

		if not launch_exe:
			raise ValueError("launch_exe is required")
		exe_path = Path(launch_exe)
		if not exe_path.is_file():
			raise FileNotFoundError(launch_exe)

		# 解析参数：{content} 占位符替换
		args = self._parse_args(launch_args, content_path)
		cwd = Path(working_dir) if working_dir else exe_path.parent
		if not cwd.is_dir():
			cwd = exe_path.parent

		kwargs: dict = {"cwd": str(cwd)}
		if os.name == "nt":
			kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
			startupinfo = _startupinfo_for_windows()
			if startupinfo is not None:
				kwargs["startupinfo"] = startupinfo

		if run_as_admin and os.name == "nt":
			process = self._launch_elevated(exe_path, args, cwd, code_label="elevated launch")
		else:
			try:
				# Popen 之前放行前台切换
				_allow_set_foreground_window()
				process = subprocess.Popen([str(exe_path), *args], **kwargs)
			except OSError as exc:
				# WinError 740：该 exe 的 manifest 要求管理员权限，Popen 会被拒绝
				# → 自动改用 runas 提升启动（拿不到进程句柄，monitorable = False）
				if os.name == "nt" and getattr(exc, "winerror", None) == 740:
					logger.info(
						"Launch needs elevation (WinError 740), retrying via runas: %s",
						exe_path,
					)
					process = self._launch_elevated(
						exe_path, args, cwd, code_label="auto-elevated launch"
					)
				else:
					raise

		logger.info(
			"Game launched: item=%s type=%s exe=%s args=%r monitorable=%s",
			game.get("id"), profile_type, exe_path, args, process is not None,
		)

		# 拿得到 PID 才去抢前台（runas 路径 process=None，不做，避免按名字误抓）
		if os.name == "nt" and process is not None:
			import threading

			threading.Thread(
				target=_bring_window_to_front_by_pid,
				args=(process.pid, 3.0),
				daemon=True,
			).start()

		return RunningGame(
			item_id=str(game.get("id", "")),
			process=process,
			started_at=datetime.now(timezone.utc),
			launch_exe=str(exe_path),
			monitorable=process is not None,
			monitor_exe=str(game.get("monitor_exe", "") or "").strip(),
		)

	def _launch_elevated(
		self,
		exe_path: Path,
		args: list[str],
		cwd: Path,
		*,
		code_label: str,
	) -> None:
		"""用 ShellExecuteW("runas") 提升启动。这条路拿不到进程句柄，返回 None。"""
		# ShellExecuteW 之前同样放行前台切换（UAC 提示 / 游戏窗口都能到前台）
		_allow_set_foreground_window()

		params = subprocess.list2cmdline(args) if args else None
		result = ctypes.windll.shell32.ShellExecuteW(
			None, "runas", str(exe_path), params, str(cwd), 1
		)
		if int(result) <= 32:
			raise OSError(f"{code_label} failed: code {result}")
		return None

	def _parse_args(self, args_str: str, content_path: str) -> list[str]:
		if not args_str:
			return []
		try:
			parts = shlex.split(args_str, posix=False)
		except ValueError:
			parts = args_str.split()
		result: list[str] = []
		used_content = False
		for p in parts:
			# 去掉两侧引号
			if len(p) >= 2 and p[0] == p[-1] and p[0] in ('"', "'"):
				p = p[1:-1]
			if "{content}" in p:
				used_content = True
				p = p.replace("{content}", content_path)
			result.append(p)
		# emulator 模式：如果没写 {content} 但提供了 content_path，自动追加
		if content_path and not used_content:
			result.append(content_path)
		return result