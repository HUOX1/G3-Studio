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
	var counter: int = 0
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		counter += 1
		var rid: String = "special-%d" % counter
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

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

func _on_paths(rid: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	_events.append({"kind": "paths", "id": rid, "scope": scope, "ok": ok, "data": data, "error": error})

func _on_folder(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_events.append({"kind": "folder", "id": rid, "ok": ok, "data": data, "error": error})

func _on_source(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_events.append({"kind": "source", "id": rid, "ok": ok, "data": data, "error": error})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = SETTINGS_SCRIPT.new()
	add_child(empty)
	_check(empty.request_movie_paths("main", []).is_empty(), "unconfigured paths rejected")
	_check(empty.request_movie_cover_folder("main", "").is_empty(), "unconfigured folder rejected")
	_check(empty.request_cover_tool_source("x").is_empty(), "unconfigured source rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = SETTINGS_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.movie_paths_completed.connect(_on_paths)
	ctrl.movie_cover_folder_completed.connect(_on_folder)
	ctrl.cover_tool_source_completed.connect(_on_source)
	_check(ctrl.request_movie_paths("bad", []).is_empty(), "invalid paths scope rejected")
	_check(ctrl.request_movie_cover_folder("bad", "x").is_empty(), "invalid folder scope rejected")
	_check(router.pending_route_count() == 0, "invalid requests create no routes")

	var main_old: String = ctrl.request_movie_paths("main", ["C:/main-old"])
	var private_new: String = ctrl.request_movie_paths("private", ["D:/private"])
	_check(not main_old.is_empty() and main_old != private_new, "path writes have distinct IDs")
	_check(backend.sent[main_old] == {"command": "settings.set_movie_paths", "payload": {"paths": ["C:/main-old"], "scope": "main"}}, "main path payload")
	_check(backend.sent[private_new] == {"command": "settings.set_movie_paths", "payload": {"paths": ["D:/private"], "scope": "private"}}, "private path payload")
	_check(router.pending_route_count() == 1, "paths preserve single latest slot")
	backend.reply(main_old, true, {"movie_library_paths": ["stale"]})
	_check(_events.is_empty(), "superseded path reply ignored")
	backend.reply(private_new, true, {"movie_library_paths_private": ["D:/private"]})
	_check(_events.size() == 1 and _events[0]["scope"] == "private", "private path scope bound to request")
	_check((_events[0]["data"] as Dictionary)["movie_library_paths_private"] == ["D:/private"], "private response data preserved")
	backend.reply(private_new, true, {})
	_check(_events.size() == 1, "duplicate path reply ignored")

	var folder_old: String = ctrl.request_movie_cover_folder("main", "C:/covers")
	var folder_new: String = ctrl.request_movie_cover_folder("private", "")
	_check(backend.sent[folder_old] == {"command": "settings.set_movie_cover_folder", "payload": {"folder": "C:/covers", "scope": "main"}}, "main cover folder payload")
	_check(backend.sent[folder_new] == {"command": "settings.set_movie_cover_folder", "payload": {"folder": "", "scope": "private"}}, "private cover folder clear payload")
	_check(router.pending_route_count() == 1, "cover folders preserve one latest slot")
	backend.reply(folder_old, true, {})
	_check(_events.size() == 1, "stale cover folder ignored")
	backend.reply(folder_new, false, null, {"message": "disk full"})
	_check(_events.size() == 2 and _events[1]["kind"] == "folder" and not _events[1]["ok"], "cover folder error forwarded")
	_check((_events[1]["error"] as Dictionary)["message"] == "disk full", "cover folder error detail preserved")

	var source_old: String = ctrl.request_cover_tool_source("C:/source-old")
	var source_new: String = ctrl.request_cover_tool_source("D:/source-new")
	_check(backend.sent[source_new] == {"command": "settings.set_cover_tool_source", "payload": {"folder": "D:/source-new"}}, "cover tool source payload")
	_check(router.pending_route_count() == 1, "source picker latest slot")
	backend.reply(source_old, true, {"cover_tool_source_dir": "C:/source-old"})
	_check(_events.size() == 2, "stale source reply ignored")
	backend.reply(source_new, true, {"cover_tool_source_dir": "D:/source-new"})
	_check(_events.size() == 3 and _events[2]["kind"] == "source", "newest source response forwarded")
	_check((_events[2]["data"] as Dictionary)["cover_tool_source_dir"] == "D:/source-new", "newest source value retained")
	_check(router.pending_route_count() == 0, "all specialized routes retired")

	var late: String = ctrl.request_movie_paths("main", ["C:/late"])
	backend.disconnected.emit(1006, "offline")
	backend.reply(late, true, {"movie_library_paths": ["C:/late"]})
	_check(_events.size() == 3, "disconnect invalidates late path response")
	_check(router.pending_route_count() == 0, "disconnect clears specialized routes")
	backend.available = false
	_check(ctrl.request_movie_cover_folder("main", "x").is_empty(), "failed folder send returns empty ID")
	_check(ctrl.request_cover_tool_source("x").is_empty(), "failed source send returns empty ID")
	_check(router.pending_route_count() == 0, "failed sends register no routes")
	_check(_legacy == 0, "specialized replies do not leak to legacy handler")

	if _failures == 0:
		print("SYSTEM SETTINGS SPECIALIZED CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("SYSTEM SETTINGS SPECIALIZED CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
