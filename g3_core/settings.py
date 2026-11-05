
from __future__ import annotations

from dataclasses import asdict, dataclass, field, fields
import json
from pathlib import Path

DEFAULT_START_SECTIONS = {"games", "movies", "comics", "music", "system"}


@dataclass(slots=True)
class TerminalSettings:
	settings_schema: int = 3
	display_mode: str = "borderless"
	monitor: int = 0
	preview_audio: bool = True
	preview_volume: float = 0.25
	preview_auto_play: bool = True
	ui_sfx: bool = True                        # UI 音效总开关
	ui_sfx_overrides: dict[str, str] = field(default_factory=dict)
	ui_sfx_volume: float = 0.6                 # UI 音效音量 0..1
	restore_last_section: bool = False
	default_start_section: str = "games"
	restore_last_item: bool = True
	fontset_id: str = "default"           # 电影板块字体组别（旧字段，保留兼容）
	fontset_id_games: str = "default"     # 游戏板块字体组别
	window_mode: str = "windowed"
	ffmpeg_path: str = "ffmpeg"
	godot_executable: str = ""
	movie_library_paths: list[str] = field(default_factory=list)
	movie_library_paths_private: list[str] = field(default_factory=list)
	movie_cover_folder_main: str = ""
	movie_cover_folder_private: str = ""
	cover_tool_source_dir: str = ""
	mpv_path: str = ""

	@classmethod
	def default(cls) -> "TerminalSettings":
		return cls()

	def to_dict(self) -> dict[str, object]:
		return asdict(self)

	@classmethod
	def from_dict(cls, payload: dict[str, object]) -> "TerminalSettings":
		allowed = {field.name for field in fields(cls)}
		unknown = sorted(set(payload) - allowed)
		if unknown:
			raise ValueError(f"Unknown settings key(s): {', '.join(unknown)}")
		settings = cls(**payload)
		settings._validate()
		return settings

	@classmethod
	def load(cls, path: Path) -> "TerminalSettings":
		if not path.exists():
			return cls.default()
		payload = json.loads(path.read_text(encoding="utf-8"))
		if not isinstance(payload, dict):
			raise ValueError("settings root must be an object")
		payload = dict(payload)
		# Schema 3 removes the user-selectable application theme system.
		# Discard its legacy keys while preserving all unrelated user settings.
		for deprecated_key in ("current_theme", "theme_music", "theme_music_volume"):
			payload.pop(deprecated_key, None)
		try:
			previous_schema = int(payload.get("settings_schema", 1))
		except (TypeError, ValueError):
			previous_schema = 1
		payload["settings_schema"] = max(previous_schema, 3)
		return cls.from_dict(payload)

	def save(self, path: Path) -> None:
		self._validate()
		path.parent.mkdir(parents=True, exist_ok=True)
		temporary = path.with_name(f".{path.name}.tmp")
		temporary.write_text(
			json.dumps(self.to_dict(), ensure_ascii=False, indent=2) + "\n",
			encoding="utf-8",
		)
		json.loads(temporary.read_text(encoding="utf-8"))
		temporary.replace(path)

	def _validate(self) -> None:
		if self.display_mode not in {"borderless", "windowed", "fullscreen"}:
			raise ValueError(f"invalid display_mode: {self.display_mode}")
		if self.default_start_section not in DEFAULT_START_SECTIONS:
			raise ValueError(f"invalid default_start_section: {self.default_start_section}")
		if self.window_mode not in {"windowed", "fullscreen"}:
			raise ValueError(f"invalid window_mode: {self.window_mode}")
		if self.monitor < 0:
			raise ValueError("monitor must be >= 0")
		if not 0.0 <= self.preview_volume <= 1.0:
			raise ValueError("preview_volume must be between 0 and 1")
		if not 0.0 <= self.ui_sfx_volume <= 1.0:
			raise ValueError("ui_sfx_volume must be between 0 and 1")
		if not isinstance(self.ui_sfx_overrides, dict):
			raise ValueError("ui_sfx_overrides must be an object")
		if any(k not in {"boot", "detail_in", "detail_out", "card_click", "game_launch", "drive_draw", "drive_read", "launch_unavailable", "sort_cycle", "section_switch", "drive_hover", "drive_signal"} or not isinstance(v, str) or len(v) > 512 or (v and not v.startswith("user://g3_ui_sfx/")) for k, v in self.ui_sfx_overrides.items()):
			raise ValueError("invalid ui_sfx_overrides mapping")
		if not isinstance(self.movie_library_paths, list):
			raise ValueError("movie_library_paths must be a list")
		for p in self.movie_library_paths:
			if not isinstance(p, str):
				raise ValueError("movie_library_paths entries must be strings")
		if not isinstance(self.movie_library_paths_private, list):
			raise ValueError("movie_library_paths_private must be a list")
		for p in self.movie_library_paths_private:
			if not isinstance(p, str):
				raise ValueError("movie_library_paths_private entries must be strings")
		if not isinstance(self.movie_cover_folder_main, str):
			raise ValueError("movie_cover_folder_main must be a string")
		if not isinstance(self.movie_cover_folder_private, str):
			raise ValueError("movie_cover_folder_private must be a string")
		if not isinstance(self.cover_tool_source_dir, str):
			raise ValueError("cover_tool_source_dir must be a string")
