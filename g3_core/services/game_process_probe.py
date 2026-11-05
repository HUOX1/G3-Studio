"""Windows game process discovery using stdlib Win32 APIs (no psutil dependency).

An image name alone is not a game identity: launchers frequently spawn a new
process, while unrelated games may use similarly named helper executables.
"""
from __future__ import annotations

import os
from pathlib import Path
from dataclasses import dataclass


@dataclass(frozen=True)
class ProcessInfo:
    pid: int
    parent_pid: int
    name: str
    path: str


def process_snapshot() -> dict[int, ProcessInfo]:
    """Return accessible Windows processes, including full executable paths where permitted."""
    if os.name != "nt":
        return {}
    import ctypes
    from ctypes import wintypes

    TH32CS_SNAPPROCESS = 0x00000002
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value

    class PROCESSENTRY32W(ctypes.Structure):
        _fields_ = [
            ("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
            ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
            ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
            ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG),
            ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260),
        ]

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    kernel.Process32FirstW.restype = wintypes.BOOL
    kernel.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    kernel.Process32NextW.restype = wintypes.BOOL
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
    kernel.QueryFullProcessImageNameW.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL

    handle = kernel.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if not handle or handle == INVALID_HANDLE_VALUE:
        return {}
    found: dict[int, ProcessInfo] = {}
    try:
        entry = PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(entry)
        ok = kernel.Process32FirstW(handle, ctypes.byref(entry))
        while ok:
            pid = int(entry.th32ProcessID)
            exe_path = ""
            proc_handle = kernel.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
            if proc_handle:
                try:
                    buf = ctypes.create_unicode_buffer(32768)
                    length = wintypes.DWORD(len(buf))
                    if kernel.QueryFullProcessImageNameW(proc_handle, 0, buf, ctypes.byref(length)):
                        exe_path = buf.value
                finally:
                    kernel.CloseHandle(proc_handle)
            found[pid] = ProcessInfo(pid, int(entry.th32ParentProcessID), entry.szExeFile, exe_path)
            ok = kernel.Process32NextW(handle, ctypes.byref(entry))
    finally:
        kernel.CloseHandle(handle)
    return found


def _norm(value: str) -> str:
    return os.path.normcase(os.path.normpath(value)) if value else ""


def is_beneath(path: str, folder: str) -> bool:
    if not path or not folder:
        return False
    try:
        return os.path.commonpath([_norm(path), _norm(folder)]) == _norm(folder)
    except (ValueError, OSError):
        return False


def choose_game_pids(
    processes: dict[int, ProcessInfo], before: set[int], *,
    install_dir: str = "", launch_pid: int = 0, monitor_exe: str = "",
    include_install_dir_when_monitor_exe: bool = False,
) -> set[int]:
    """Match newly spawned processes to the game; never match unrelated existing PIDs.

    The user-specified monitor_exe is normally an explicit override, but still
    requires a new process (to avoid attaching to a preexisting unrelated session).
    Some Epic games launch a bootstrap EXE and a separate shipping EXE; for those
    sessions the caller may also match new processes beneath the install directory.
    """
    new = set(processes).difference(before)
    monitor_name = Path(monitor_exe).name.casefold() if monitor_exe else ""
    matches: set[int] = set()
    for pid in new:
        item = processes[pid]
        if item.name.casefold() in PLATFORM_PROCESS_NAMES:
            continue
        in_install_dir = bool(install_dir and is_beneath(item.path, install_dir))
        if monitor_name:
            if item.name.casefold() == monitor_name or (
                include_install_dir_when_monitor_exe and in_install_dir
            ):
                matches.add(pid)
        elif in_install_dir:
            matches.add(pid)
    # A directly launched game may live outside its configured working directory.
    if launch_pid in processes and launch_pid in new and (
        not monitor_name or include_install_dir_when_monitor_exe
    ):
        if processes[launch_pid].name.casefold() not in PLATFORM_PROCESS_NAMES:
            matches.add(launch_pid)
    # Children of the launch process can be the real game executable.
    if (not monitor_name or include_install_dir_when_monitor_exe) and launch_pid:
        changed = True
        while changed:
            changed = False
            for pid in new - matches:
                if processes[pid].name.casefold() not in PLATFORM_PROCESS_NAMES and processes[pid].parent_pid in matches:
                    matches.add(pid)
                    changed = True
    return matches


def steam_install_dir(appid: int) -> str:
    """Resolve an installed Steam app from library manifests; no guess by title."""
    if os.name != "nt" or appid <= 0:
        return ""
    try:
        from g3_core.services.steam_library_scanner import SteamLibraryScanner
        root = SteamLibraryScanner.find_steam_root()
        if root is None:
            return ""
        scanner = SteamLibraryScanner.__new__(SteamLibraryScanner)
        library_roots = scanner._library_roots(root)
        import re
        for library in library_roots:
            manifest = library / "steamapps" / f"appmanifest_{appid}.acf"
            if not manifest.is_file():
                continue
            data = manifest.read_text(encoding="utf-8-sig", errors="replace")
            match = re.search(r'"installdir"\s+"([^"]+)"', data, re.IGNORECASE)
            if match:
                directory = library / "steamapps" / "common" / match.group(1)
                if directory.is_dir():
                    return str(directory)
    except Exception:
        pass
    return ""


def epic_install_dir(app_name: str) -> str:
    """Read Epic's authoritative installation manifest by AppName."""
    if os.name != "nt" or not app_name:
        return ""
    try:
        import json
        manifest = Path(os.environ.get("ProgramData", r"C:\ProgramData")) / "Epic" / "UnrealEngineLauncher" / "LauncherInstalled.dat"
        data = json.loads(manifest.read_text(encoding="utf-8-sig"))
        for item in data.get("InstallationList", []):
            if str(item.get("AppName", "")).casefold() != app_name.casefold():
                continue
            folder = Path(str(item.get("InstallLocation", "")))
            if folder.is_dir():
                return str(folder)
    except (OSError, ValueError, TypeError):
        pass
    return ""


def uplay_install_dir(game_id: str) -> str:
    """Read Ubisoft's per-game installation directory, not its launcher path."""
    if os.name != "nt" or not game_id:
        return ""
    try:
        import winreg
        roots = (r"SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs",
                 r"SOFTWARE\Ubisoft\Launcher\Installs")
        for base in roots:
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, base + chr(92) + game_id) as key:
                    for value in ("InstallDir", ""):
                        try:
                            folder = Path(str(winreg.QueryValueEx(key, value)[0]))
                            if folder.is_dir():
                                return str(folder)
                        except OSError:
                            continue
            except OSError:
                continue
    except ImportError:
        pass
    return ""


# Platform launchers/services must not be counted as the actual game process.
PLATFORM_PROCESS_NAMES = frozenset({
    "epicgameslauncher.exe", "epicwebhelper.exe", "ubisoftconnect.exe",
    "upc.exe", "uplay.exe", "ubisoftgamelauncher.exe", "steam.exe",
    "steamwebhelper.exe", "eosoverlayrenderer-win64-shipping.exe",
    "eosoverlayrenderer-win32-shipping.exe", "eosbootstrapper.exe",
})
