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
		var rid: String = "write-%d" % next_id
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

func _on_action(action: String, scope: String, rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_events.append({"action": action, "scope": scope, "id": rid, "ok": ok, "data": data, "error": error})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = SETTINGS_SCRIPT.new()
	add_child(empty)
	_check(empty.request_fontset_action("save", {}).is_empty(), "unconfigured action rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = SETTINGS_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.fontset_action_completed.connect(_on_action)
	_check(ctrl.request_fontset_action("bad", {}).is_empty(), "unknown action rejected")
	_check(router.pending_route_count() == 0, "invalid actions do not register")
	var actions: Array[String] = ["save", "create", "rename", "delete"]
	var ids: Dictionary = {}
	for action in actions:
		for scope in ["movies", "games"]:
			var payload: Dictionary = {"scope": scope, "id": action + "-" + scope, "name": "Example"}
			var rid: String = ctrl.request_fontset_action(action, payload)
			ids[action + "." + scope] = rid
			_check(not rid.is_empty(), action + " " + scope + " sent")
			_check(str(backend.sent[rid]["command"]) == "fontsets." + action, action + " command")
			_check(backend.sent[rid]["payload"] == payload, action + " payload " + scope)
	_check(router.pending_route_count() == 8, "eight independent action/scope slots")
	var old_save: String = str(ids["save.movies"])
	var latest_save: String = ctrl.request_fontset_action("save", {"scope": "movies", "id": "new"})
	_check(not latest_save.is_empty() and latest_save != old_save, "new save replaces previous movie save")
	_check(router.pending_route_count() == 8, "replaced slot does not leak route")
	backend.reply(old_save, true, {"id": "old"})
	_check(_events.is_empty(), "superseded save response ignored")
	backend.reply(str(ids["create.games"]), true, {"id": "game-created"})
	backend.reply(str(ids["rename.movies"]), false, null, {"message": "rename failed"})
	backend.reply(latest_save, true, {"id": "new"})
	_check(_events.size() == 3, "out-of-order actions delivered")
	_check(str(_events[0]["action"]) == "create" and str(_events[0]["scope"]) == "games", "game create context preserved")
	_check(str((_events[0]["data"] as Dictionary).get("id", "")) == "game-created", "create response payload preserved")
	_check(str(_events[1]["action"]) == "rename" and not bool(_events[1]["ok"]), "rename failure preserved")
	_check(str((_events[1]["error"] as Dictionary).get("message", "")) == "rename failed", "rename error preserved")
	_check(str(_events[2]["action"]) == "save" and str(_events[2]["scope"]) == "movies", "movie save context preserved")
	backend.reply(latest_save, true, {})
	_check(_events.size() == 3, "duplicate reply ignored")
	_check(router.pending_route_count() == 5, "remaining independent requests still pending")
	var implicit: String = ctrl.request_fontset_action("delete", {"id": "default"})
	_check(not implicit.is_empty() and backend.sent[implicit]["payload"] == {"id": "default"}, "missing scope preserves original payload")
	backend.reply(implicit, true, {})
	_check(str(_events[-1]["scope"]) == "movies", "missing scope uses movies")
	var other: String = ctrl.request_fontset_action("save", {"scope": "other", "id": "x"})
	backend.reply(other, true, {})
	_check(str(_events[-1]["scope"]) == "movies", "non-games scope uses legacy movies routing")
	var late: String = ctrl.request_fontset_action("create", {"scope": "movies", "id": "late"})
	backend.disconnected.emit(1006, "offline")
	backend.reply(late, true, {})
	_check(_events.size() == 5, "disconnect discards late response")
	_check(router.pending_route_count() == 0, "disconnect clears pending actions")
	backend.available = false
	_check(ctrl.request_fontset_action("save", {}).is_empty(), "failed send returns empty ID")
	_check(router.pending_route_count() == 0, "failed send leaves no route")
	_check(_legacy == 0, "action responses do not leak to main legacy handler")
	if _failures == 0:
		print("SYSTEM SETTINGS WRITES CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("SYSTEM SETTINGS WRITES CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
