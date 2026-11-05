extends RefCounted

# UI-S7b: Read startup preferences from the same local settings file.
# Missing/unreadable/invalid data retains the original fallback behavior.
static func _read_settings() -> Dictionary:
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if local_app_data.is_empty():
		return {}
	var path = local_app_data + "/G3/settings.json"
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return parsed

static func read_window_mode() -> String:
	var settings: Dictionary = _read_settings()
	var mode = str(settings.get("window_mode", "windowed")).to_lower()
	return "fullscreen" if mode == "fullscreen" else "windowed"

static func read_start_section(sections: Array[String]) -> int:
	var settings: Dictionary = _read_settings()
	var section = str(settings.get("default_start_section", "games")).to_upper()
	var idx = sections.find(section)
	return idx if idx >= 0 else 0

# Boot audio must respect the same local preference file before the async
# settings response, otherwise a custom boot sound can be cut mid-playback.
static func read_sfx_settings() -> Dictionary:
	var settings: Dictionary = _read_settings()
	var result: Dictionary = {}
	for key in ["ui_sfx_volume", "ui_sfx_enabled", "ui_sfx_overrides"]:
		if settings.has(key):
			result[key] = settings[key]
	return result
