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
	var available: bool = true
	var next_id: int = 0
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		next_id += 1
		var rid: String = "update-%d" % next_id
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _fontsets: Array[Dictionary] = []
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

func _on_fontset(scope: String, rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_fontsets.append({"scope": scope, "id": rid, "ok": ok, "data": data, "error": error})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = SETTINGS_SCRIPT.new()
	add_child(empty)
	_check(empty.update_state("last_movie_id_main", "x").is_empty(), "unconfigured state rejected")
	_check(empty.update_setting("window_mode", "windowed").is_empty(), "unconfigured settings rejected")
	_check(empty.request_fontset_switch("movies", "f").is_empty(), "unconfigured fontset rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = SETTINGS_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.fontset_switch_completed.connect(_on_fontset)
	_check(ctrl.update_state("", "x").is_empty(), "empty state key rejected")
	_check(ctrl.update_setting("", "x").is_empty(), "empty setting key rejected")
	_check(ctrl.request_fontset_switch("other", "x").is_empty(), "invalid fontset scope rejected")
	_check(ctrl.request_fontset_switch("games", "").is_empty(), "empty fontset rejected")
	_check(router.pending_route_count() == 0, "invalid writes register no routes")
	var main_id: String = ctrl.update_state("last_movie_id_main", "m1")
	var private_id: String = ctrl.update_state("last_movie_id_private", "p1")
	_check(main_id != private_id and not main_id.is_empty(), "main/private updates independent")
	_check(backend.sent[main_id] == {"command": "state.update", "payload": {"last_movie_id_main": "m1"}}, "main state payload")
	_check(backend.sent[private_id] == {"command": "state.update", "payload": {"last_movie_id_private": "p1"}}, "private state payload")
	var start_id: String = ctrl.update_setting("default_start_section", "games")
	var window_id: String = ctrl.update_setting("window_mode", "fullscreen")
	var created_id: String = ctrl.update_setting("fontset_id", "created")
	_check(backend.sent[start_id] == {"command": "settings.update", "payload": {"default_start_section": "games"}}, "default section payload")
	_check(backend.sent[window_id] == {"command": "settings.update", "payload": {"window_mode": "fullscreen"}}, "window mode payload")
	_check(backend.sent[created_id] == {"command": "settings.update", "payload": {"fontset_id": "created"}}, "created fontset payload")
	_check(router.pending_route_count() == 5, "fire-and-forget writes remain independent")
	var movie_old: String = ctrl.request_fontset_switch("movies", "m-a")
	var movie_new: String = ctrl.request_fontset_switch("movies", "m-b")
	var game_id: String = ctrl.request_fontset_switch("games", "g-a")
	_check(movie_old != movie_new, "movie fontset latest replaces old")
	_check(backend.sent[movie_new]["payload"] == {"fontset_id": "m-b"}, "movie fontset key")
	_check(backend.sent[game_id]["payload"] == {"fontset_id_games": "g-a"}, "game fontset key")
	_check(router.pending_route_count() == 7, "movie/game fontset slots independent")
	backend.reply(movie_old, true, {})
	backend.reply(game_id, false, null, {"message": "failed"})
	backend.reply(movie_new, true, {})
	_check(_fontsets.size() == 2, "out-of-order fontset callbacks delivered")
	_check(str(_fontsets[0]["scope"]) == "games" and not bool(_fontsets[0]["ok"]), "game error retains scope")
	_check(str((_fontsets[0]["error"] as Dictionary).get("message", "")) == "failed", "game error payload")
	_check(str(_fontsets[1]["scope"]) == "movies" and bool(_fontsets[1]["ok"]), "movie success retains scope")
	backend.reply(main_id, true, {})
	backend.reply(private_id, true, {})
	backend.reply(start_id, true, {})
	backend.reply(window_id, false, null, {"message": "fail"})
	backend.reply(created_id, true, {})
	_check(router.pending_route_count() == 0, "all routed writes consumed")
	_check(_legacy == 0, "writes do not leak to legacy handler")
	var late_game: String = ctrl.request_fontset_switch("games", "late")
	backend.disconnected.emit(1006, "offline")
	backend.reply(late_game, true, {})
	_check(router.pending_route_count() == 0, "disconnect clears pending writes")
	backend.available = false
	_check(ctrl.update_setting("window_mode", "windowed").is_empty(), "failed send returns empty ID")
	_check(router.pending_route_count() == 0, "failed send registers no route")
	if _failures == 0:
		print("SYSTEM SETTINGS UPDATES CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("SYSTEM SETTINGS UPDATES CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
