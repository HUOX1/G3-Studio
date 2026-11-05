extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const SETTINGS_SCRIPT: Script = preload("res://scripts/system_settings_controller.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	@warning_ignore("unused_signal")
	signal event_received(event_type: String, payload: Dictionary)
	@warning_ignore("unused_signal")
	signal disconnected(code: int, reason: String)
	var next_id: int = 0
	var available: bool = true
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		next_id += 1
		var request_id: String = "system-%d" % next_id
		sent[request_id] = {"command": command, "payload": payload.duplicate(true)}
		return request_id
	func reply(request_id: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _events: Array[Dictionary] = []
var _legacy: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		_failures += 1
		push_error("[FAIL] " + label)

func _on_read(request_id: String, ok: bool, data: Variant, error: Variant, kind: String) -> void:
	_events.append({"id": request_id, "kind": kind, "ok": ok, "data": data, "error": error})

func _on_fontset(request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	_events.append({"id": request_id, "kind": "fontset", "scope": scope, "ok": ok, "data": data, "error": error})

func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = SETTINGS_SCRIPT.new()
	add_child(empty)
	_check(empty.request_state().is_empty(), "unconfigured state rejected")
	_check(empty.request_settings().is_empty(), "unconfigured settings rejected")
	_check(empty.request_fonts().is_empty(), "unconfigured fonts rejected")
	_check(empty.request_fontsets_list().is_empty(), "unconfigured fontsets list rejected")
	_check(empty.request_fontset_get("movies", "default").is_empty(), "unconfigured fontset get rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var settings: Node = SETTINGS_SCRIPT.new()
	add_child(settings)
	settings.configure(router)
	var normalized: Dictionary = settings.normalize_settings_payload({
		"default_start_section": "movies",
		"movie_library_paths": ["C:/Movies", 42],
		"movie_library_paths_private": "not-an-array",
		"movie_cover_folder_main": "C:/Covers/Main",
		"movie_cover_folder_private": "C:/Covers/Private",
		"cover_tool_source_dir": "C:/Assets",
		"window_mode": "FULLSCREEN",
		"fontset_id": "  movie-custom  ",
		"fontset_id_games": "  "
	}, ["GAMES", "MOVIES", "SYSTEM"])
	_check(int(normalized.get("default_section_index", -1)) == 1, "settings normalizer resolves section index case-insensitively")
	_check(normalized.get("movie_library_paths", []) == ["C:/Movies", "42"], "settings normalizer converts main paths to strings")
	_check((normalized.get("movie_library_paths_private", []) as Array).is_empty(), "settings normalizer ignores non-array private paths")
	_check(str(normalized.get("movie_cover_folder_main", "")) == "C:/Covers/Main", "settings normalizer retains main cover folder")
	_check(str(normalized.get("movie_cover_folder_private", "")) == "C:/Covers/Private", "settings normalizer retains private cover folder")
	_check(str(normalized.get("cover_tool_source_dir", "")) == "C:/Assets", "settings normalizer retains cover-tool source")
	_check(str(normalized.get("window_mode", "")) == "fullscreen", "settings normalizer lowercases window mode")
	_check(str(normalized.get("fontset_id", "")) == "movie-custom", "settings normalizer trims movie fontset ID")
	_check(str(normalized.get("fontset_id_games", "")) == "default", "settings normalizer defaults empty game fontset ID")
	var fallback_settings: Dictionary = settings.normalize_settings_payload({"default_start_section": "unknown"}, ["GAMES", "MOVIES"])
	_check(int(fallback_settings.get("default_section_index", -1)) == 0 and str(fallback_settings.get("window_mode", "")) == "windowed" and str(fallback_settings.get("fontset_id", "")) == "default" and str(fallback_settings.get("fontset_id_games", "")) == "default", "settings normalizer preserves defaults and invalid-section fallback")
	var fontset_catalog: Dictionary = settings.normalize_fontsets_catalog([
		{"id": "m1", "scope": "movies", "name": "Movie One"},
		{"id": "g1", "scope": "games", "name": "Game One"},
		{"id": "", "scope": "games", "name": "Ignored"},
		"malformed",
		{"id": "m2", "name": ""},
	], "m2", "g1")
	_check(fontset_catalog.get("movie_ids", []) == ["m1", "m2"], "fontset catalog separates movie IDs and skips invalid entries")
	_check(fontset_catalog.get("game_ids", []) == ["g1"], "fontset catalog separates game IDs")
	_check(fontset_catalog.get("movie_names", []) == ["Movie One", ""], "fontset catalog preserves explicit empty name")
	_check(fontset_catalog.get("game_names", []) == ["Game One"], "fontset catalog retains game names")
	_check(int(fontset_catalog.get("movie_index", -1)) == 1 and int(fontset_catalog.get("game_index", -1)) == 0, "fontset catalog resolves selected indexes")
	var missing_selection: Dictionary = settings.normalize_fontsets_catalog([{"id": "m1", "name": "Movie"}], "missing", "missing")
	_check(int(missing_selection.get("movie_index", -1)) == 0 and int(missing_selection.get("game_index", -1)) == 0, "fontset catalog defaults missing selections to first entry")
	settings.state_completed.connect(Callable(self, "_on_read").bind("state"))
	settings.settings_completed.connect(Callable(self, "_on_read").bind("settings"))
	settings.fonts_completed.connect(Callable(self, "_on_read").bind("fonts"))
	settings.fontsets_list_completed.connect(Callable(self, "_on_read").bind("fontsets"))
	settings.fontset_completed.connect(_on_fontset)

	_check(settings.request_fontset_get("invalid", "x").is_empty(), "invalid scope rejected")
	var state_id: String = settings.request_state()
	var settings_id: String = settings.request_settings()
	var fonts_id: String = settings.request_fonts()
	_check(not state_id.is_empty() and not settings_id.is_empty() and not fonts_id.is_empty(), "three startup reads dispatched")
	_check(str(backend.sent[state_id]["command"]) == "state.get", "state command preserved")
	_check(str(backend.sent[settings_id]["command"]) == "settings.get", "settings command preserved")
	_check(str(backend.sent[fonts_id]["command"]) == "fonts.list", "fonts command preserved")
	_check(backend.sent[state_id]["payload"] == {} and backend.sent[settings_id]["payload"] == {} and backend.sent[fonts_id]["payload"] == {}, "startup payloads empty")
	_check(router.pending_route_count() == 3, "startup reads keep separate routes")
	backend.reply(fonts_id, true, ["Arial"])
	backend.reply(state_id, true, {"last_movie_id_private": "p"})
	backend.reply(settings_id, false, null, {"message": "settings offline"})
	_check(_events.size() == 3, "out-of-order startup replies delivered")
	_check(str(_events[0]["kind"]) == "fonts" and str(_events[1]["kind"]) == "state" and str(_events[2]["kind"]) == "settings", "startup intent preserved")
	_check(not bool(_events[2]["ok"]), "settings failure forwarded")
	_check(str((_events[2]["error"] as Dictionary).get("message", "")) == "settings offline", "settings error forwarded")
	_check((_events[1]["data"] as Dictionary).get("last_movie_id_private", "") == "p", "private restore payload retained")
	backend.reply(state_id, true, {})
	_check(_events.size() == 3, "duplicate startup reply ignored")
	_check(router.pending_route_count() == 0, "startup routes retired")

	var first_list: String = settings.request_fontsets_list()
	var second_list: String = settings.request_fontsets_list()
	_check(not first_list.is_empty() and first_list != second_list, "fontsets list latest requests distinct")
	_check(str(backend.sent[second_list]["command"]) == "fontsets.list", "fontsets list command preserved")
	_check(backend.sent[second_list]["payload"] == {}, "fontsets list payload empty")
	_check(router.pending_route_count() == 1, "fontsets list latest slot replaces old")
	backend.reply(first_list, true, [{"id": "stale"}])
	_check(_events.size() == 3, "superseded fontsets list ignored")
	backend.reply(second_list, true, [{"id": "default"}])
	_check(_events.size() == 4 and str(_events[3]["kind"]) == "fontsets", "newest fontsets list delivered")
	backend.reply(second_list, true, [])
	_check(_events.size() == 4, "duplicate fontsets list ignored")

	var movies_old: String = settings.request_fontset_get("movies", "m-old")
	var games_id: String = settings.request_fontset_get("games", "g-one")
	var movies_new: String = settings.request_fontset_get("movies", "m-new")
	_check(movies_old != movies_new and not games_id.is_empty(), "scoped requests have distinct IDs")
	_check(str(backend.sent[movies_new]["command"]) == "fontsets.get", "fontset get command preserved")
	_check(backend.sent[movies_new]["payload"] == {"id": "m-new", "scope": "movies"}, "movie fontset payload retained")
	_check(backend.sent[games_id]["payload"] == {"id": "g-one", "scope": "games"}, "game fontset payload retained")
	_check(router.pending_route_count() == 2, "fontset scopes maintain independent latest slots")
	backend.reply(movies_old, true, {"id": "m-old"})
	_check(_events.size() == 4, "stale movie fontset ignored")
	backend.reply(games_id, true, {"id": "g-one"})
	backend.reply(movies_new, true, {"id": "m-new"})
	_check(_events.size() == 6, "both fontset scopes delivered")
	_check(str(_events[4]["scope"]) == "games" and str(_events[5]["scope"]) == "movies", "fontset scope bound to request")
	_check(str((_events[5]["data"] as Dictionary).get("id", "")) == "m-new", "newest movie fontset retained")
	_check(router.pending_route_count() == 0, "scoped fontset routes retired")

	var disconnected_id: String = settings.request_fontset_get("games", "late")
	backend.disconnected.emit(1006, "offline")
	backend.reply(disconnected_id, true, {"id": "late"})
	_check(_events.size() == 6, "disconnected late response ignored")
	_check(router.pending_route_count() == 0, "disconnect clears pending routes")
	backend.available = false
	_check(settings.request_state().is_empty(), "failed state send returns empty ID")
	_check(settings.request_fontsets_list().is_empty(), "failed fontsets list send returns empty ID")
	_check(router.pending_route_count() == 0, "failed send does not leak route")
	_check(_legacy == 0, "migrated replies do not leak to legacy main handler")

	if _failures == 0:
		print("SYSTEM SETTINGS CONTROLLER CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("SYSTEM SETTINGS CONTROLLER CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
