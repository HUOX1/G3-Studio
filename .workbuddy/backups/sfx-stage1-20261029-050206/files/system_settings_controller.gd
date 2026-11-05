extends Node

# Stage 5.1: route only system/state/font read requests.
# UI application and startup request ordering remain in main.gd.
signal state_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal settings_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal fonts_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal fontsets_list_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal fontset_completed(request_id: String, ok: bool, data: Variant, error: Variant, scope: String)
signal fontset_action_completed(action: String, scope: String, request_id: String, ok: bool, data: Variant, error: Variant)
signal theme_switch_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal fontset_switch_completed(scope: String, request_id: String, ok: bool, data: Variant, error: Variant)
signal movie_paths_completed(request_id: String, ok: bool, data: Variant, error: Variant, scope: String)
signal movie_cover_folder_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal cover_tool_source_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal theme_current_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal themes_list_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal app_info_completed(request_id: String, ok: bool, data: Variant, error: Variant)

var _router: Node = null

func configure(router: Node) -> void:
	_router = router

# UI-S8d: normalize backend settings values and defaults before main applies UI state.
func normalize_settings_payload(settings: Dictionary, section_ids: Array) -> Dictionary:
	var default_section: String = str(settings.get("default_start_section", "games")).to_upper()
	var start_index: int = section_ids.find(default_section)
	if start_index < 0:
		start_index = 0

	var movie_paths: Array[String] = []
	var raw_movie_paths: Variant = settings.get("movie_library_paths", [])
	if raw_movie_paths is Array:
		for path in raw_movie_paths:
			movie_paths.append(str(path))

	var private_movie_paths: Array[String] = []
	var raw_private_movie_paths: Variant = settings.get("movie_library_paths_private", [])
	if raw_private_movie_paths is Array:
		for path in raw_private_movie_paths:
			private_movie_paths.append(str(path))

	var movie_fontset_id: String = str(settings.get("fontset_id", "default")).strip_edges()
	if movie_fontset_id.is_empty():
		movie_fontset_id = "default"
	var game_fontset_id: String = str(settings.get("fontset_id_games", "default")).strip_edges()
	if game_fontset_id.is_empty():
		game_fontset_id = "default"

	return {
		"theme_music_enabled": bool(settings.get("theme_music", true)),
		"theme_music_base_volume": clampf(float(settings.get("theme_music_volume", 0.35)), 0.0, 1.0),
		"default_section_index": start_index,
		"movie_library_paths": movie_paths,
		"movie_library_paths_private": private_movie_paths,
		"movie_cover_folder_main": str(settings.get("movie_cover_folder_main", "")),
		"movie_cover_folder_private": str(settings.get("movie_cover_folder_private", "")),
		"cover_tool_source_dir": str(settings.get("cover_tool_source_dir", "")),
		"window_mode": str(settings.get("window_mode", "windowed")).to_lower(),
		"fontset_id": movie_fontset_id,
		"fontset_id_games": game_fontset_id,
	}

# UI-S8k: normalize the fontset catalog and selected indexes before main updates controls.
func normalize_fontsets_catalog(entries: Array, current_movie_id: String, current_game_id: String) -> Dictionary:
	var movie_ids: Array[String] = []
	var game_ids: Array[String] = []
	var movie_names: Array[String] = []
	var game_names: Array[String] = []
	var movie_index: int = 0
	var game_index: int = 0
	for value in entries:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		var fontset_id: String = str(entry.get("id", ""))
		if fontset_id.is_empty():
			continue
		var fontset_name: String = str(entry.get("name", fontset_id))
		if str(entry.get("scope", "movies")) == "games":
			game_ids.append(fontset_id)
			game_names.append(fontset_name)
			if fontset_id == current_game_id:
				game_index = game_ids.size() - 1
		else:
			movie_ids.append(fontset_id)
			movie_names.append(fontset_name)
			if fontset_id == current_movie_id:
				movie_index = movie_ids.size() - 1
	return {
		"movie_ids": movie_ids,
		"game_ids": game_ids,
		"movie_names": movie_names,
		"game_names": game_names,
		"movie_index": movie_index,
		"game_index": game_index,
	}

# Theme current uses the same latest slot on initial connect and after switching.
# Theme catalog and app metadata were ordinary requests, not latest-wins.
func request_theme_current() -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"theme.current", "theme.current", {}, Callable(self, "_on_theme_current_response")
	)

func request_themes_list() -> String:
	if _router == null:
		return ""
	return _router.request("themes.list", {}, Callable(self, "_on_themes_list_response"))

func request_app_info() -> String:
	if _router == null:
		return ""
	return _router.request("app.info", {}, Callable(self, "_on_app_info_response"))

func _on_theme_current_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	theme_current_completed.emit(request_id, ok, data, error)

func _on_themes_list_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	themes_list_completed.emit(request_id, ok, data, error)

func _on_app_info_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	app_info_completed.emit(request_id, ok, data, error)

# Startup reads were ordinary routed requests, not latest-wins.
func request_state() -> String:
	if _router == null:
		return ""
	return _router.request("state.get", {}, Callable(self, "_on_state_response"))

func request_settings() -> String:
	if _router == null:
		return ""
	return _router.request("settings.get", {}, Callable(self, "_on_settings_response"))

func request_fonts() -> String:
	if _router == null:
		return ""
	return _router.request("fonts.list", {}, Callable(self, "_on_fonts_response"))

# The fontset list and each scope-specific read already used latest slots.
func request_fontsets_list() -> String:
	if _router == null:
		return ""
	return _router.request_latest("fontsets.list", "fontsets.list", {}, Callable(self, "_on_fontsets_list_response"))

func request_fontset_get(scope: String, fontset_id: String) -> String:
	if _router == null or (scope != "movies" and scope != "games"):
		return ""
	return _router.request_latest(
		"fontsets.get." + scope, "fontsets.get",
		{"id": fontset_id, "scope": scope},
		Callable(self, "_on_fontset_response").bind(scope)
	)

# Each action and library scope has its own latest-wins slot, matching the
# previous one-pending-ID-per-action/per-scope behavior in main.gd.
func request_fontset_action(action: String, payload: Dictionary) -> String:
	if _router == null or action not in ["save", "create", "rename", "delete"]:
		return ""
	var scope: String = str(payload.get("scope", "movies"))
	# Legacy manager treated any non-games scope as movies.
	if scope != "games":
		scope = "movies"
	return _router.request_latest(
		"fontsets." + action + "." + scope, "fontsets." + action, payload,
		Callable(self, "_on_fontset_action_response").bind(action, scope)
	)

# Fire-and-forget partial writes must remain independent. They do not share
# a latest slot: updating one setting must never retire an unrelated write.
func update_state(key: String, value: Variant) -> String:
	if _router == null or key.is_empty():
		return ""
	return _router.request("state.update", {key: value}, Callable(self, "_on_unobserved_write_response"))

func update_setting(key: String, value: Variant) -> String:
	if _router == null or key.is_empty():
		return ""
	return _router.request("settings.update", {key: value}, Callable(self, "_on_unobserved_write_response"))

# Theme switching retains its dedicated latest-wins slot and UI response.
func request_theme_switch(theme_id: String) -> String:
	if _router == null or theme_id.is_empty():
		return ""
	return _router.request_latest(
		"settings.update.current_theme", "settings.update", {"current_theme": theme_id},
		Callable(self, "_on_theme_switch_response")
	)

# Movie and game font selections must not supersede one another.
func request_fontset_switch(scope: String, fontset_id: String) -> String:
	if _router == null or (scope != "movies" and scope != "games") or fontset_id.is_empty():
		return ""
	var key: String = "fontset_id_games" if scope == "games" else "fontset_id"
	return _router.request_latest(
		"fontset.switch." + scope, "settings.update", {key: fontset_id},
		Callable(self, "_on_fontset_switch_response").bind(scope)
	)

# Stage 5.4: dedicated movie-folder settings are separate backend commands.
# Movie path writes previously used one pending ID for both library scopes;
# keep that latest-only policy but bind the originating scope for the UI.
func request_movie_paths(scope: String, paths: Array) -> String:
	if _router == null or (scope != "main" and scope != "private"):
		return ""
	return _router.request_latest(
		"settings.set_movie_paths", "settings.set_movie_paths",
		{"paths": paths.duplicate(), "scope": scope},
		Callable(self, "_on_movie_paths_response").bind(scope)
	)

# One cover-folder latest slot was already shared by main and private.
func request_movie_cover_folder(scope: String, folder: String) -> String:
	if _router == null or (scope != "main" and scope != "private"):
		return ""
	return _router.request_latest(
		"movie.cover_folder.set", "settings.set_movie_cover_folder",
		{"folder": folder, "scope": scope},
		Callable(self, "_on_movie_cover_folder_response")
	)

# The cover-tool source picker previously tracked one pending request ID.
func request_cover_tool_source(folder: String) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"settings.set_cover_tool_source", "settings.set_cover_tool_source",
		{"folder": folder}, Callable(self, "_on_cover_tool_source_response")
	)

func _on_movie_paths_response(request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	movie_paths_completed.emit(request_id, ok, data, error, scope)

func _on_movie_cover_folder_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	movie_cover_folder_completed.emit(request_id, ok, data, error)

func _on_cover_tool_source_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	cover_tool_source_completed.emit(request_id, ok, data, error)

func _on_unobserved_write_response(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	pass

func _on_theme_switch_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	theme_switch_completed.emit(request_id, ok, data, error)

func _on_fontset_switch_response(request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	fontset_switch_completed.emit(scope, request_id, ok, data, error)

func _on_fontset_action_response(request_id: String, ok: bool, data: Variant, error: Variant, action: String, scope: String) -> void:
	fontset_action_completed.emit(action, scope, request_id, ok, data, error)

func _on_state_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	state_completed.emit(request_id, ok, data, error)

func _on_settings_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	settings_completed.emit(request_id, ok, data, error)

func _on_fonts_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	fonts_completed.emit(request_id, ok, data, error)

func _on_fontsets_list_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	fontsets_list_completed.emit(request_id, ok, data, error)

func _on_fontset_response(request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	fontset_completed.emit(request_id, ok, data, error, scope)
