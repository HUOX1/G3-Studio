from __future__ import annotations

import logging
import os
from pathlib import Path


logger = logging.getLogger("g3.fonts")


_SUPPORTED_EXTENSIONS = {".ttf", ".otf", ".ttc", ".otc", ".woff", ".woff2"}

# 注册表值名可能带这些后缀，需要剥掉
_NAME_SUFFIXES = (
	" (TrueType)",
	" (OpenType)",
	" (All res)",
	" (VGA res)",
	" (TrueType Font)",
)


def _clean_font_name(raw: str) -> str:
	name = raw.strip()
	for suffix in _NAME_SUFFIXES:
		if name.endswith(suffix):
			name = name[: -len(suffix)]
			break
	return name.strip()


def _resolve_font_path(raw_value: str) -> Path | None:
	"""注册表里的路径可能是绝对路径，也可能是相对 C:\\Windows\\Fonts 的文件名。"""
	p = Path(raw_value)
	if p.is_absolute():
		return p
	windows_dir = os.environ.get("WINDIR") or r"C:\Windows"
	return Path(windows_dir) / "Fonts" / raw_value


def list_windows_fonts() -> list[dict[str, str]]:
	"""读取 Windows 已安装字体。

	同时扫 HKLM 和 HKCU（用户级安装的字体在 HKCU）。

	返回：[{"name": "微软雅黑", "path": "C:/Windows/Fonts/msyh.ttc"}, ...]
	"""
	if os.name != "nt":
		return []

	try:
		import winreg
	except ImportError:
		logger.warning("winreg unavailable, cannot list fonts")
		return []

	seen_paths: set[str] = set()
	results: list[dict[str, str]] = []

	locations = [
		(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"),
		(winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"),
	]

	for hive, subkey in locations:
		try:
			key = winreg.OpenKey(hive, subkey)
		except OSError:
			continue
		try:
			index = 0
			while True:
				try:
					value_name, value_data, _ = winreg.EnumValue(key, index)
					index += 1
				except OSError:
					break

				if not isinstance(value_data, str) or not value_data:
					continue

				path = _resolve_font_path(value_data)
				if path is None:
					continue
				if path.suffix.lower() not in _SUPPORTED_EXTENSIONS:
					continue

				path_str = str(path).replace("\\", "/")
				if path_str in seen_paths:
					continue
				seen_paths.add(path_str)

				results.append({
					"name": _clean_font_name(str(value_name)),
					"path": path_str,
				})
		finally:
			key.Close()

	results.sort(key=lambda item: item["name"].casefold())
	logger.info("found %d fonts", len(results))
	return results