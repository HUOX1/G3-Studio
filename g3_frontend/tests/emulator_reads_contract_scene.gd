extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const EMULATOR_SCRIPT: Script = preload("res://scripts/emulator_controller.gd")

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
		var rid: String = "emu-%d" % counter
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _list_events: Array[Dictionary] = []
var _create_events: Array[Dictionary] = []
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

func _on_list(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_list_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_create(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_create_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = EMULATOR_SCRIPT.new()
	add_child(empty)
	_check(empty.request_list().is_empty(), "unconfigured system list rejected")
	_check(empty.request_game_create_list().is_empty(), "unconfigured create list rejected")

	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = EMULATOR_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.list_completed.connect(_on_list)
	ctrl.game_create_list_completed.connect(_on_create)

	var list_old: String = ctrl.request_list()
	var create_old: String = ctrl.request_game_create_list()
	_check(not list_old.is_empty() and list_old != create_old, "read contexts use distinct IDs")
	_check(backend.sent[list_old] == {"command": "emulators.list", "payload": {}}, "system list command and payload")
	_check(backend.sent[create_old] == {"command": "emulators.list", "payload": {}}, "create list command and payload")
	_check(router.pending_route_count() == 2, "independent latest slots coexist")

	var list_new: String = ctrl.request_list()
	_check(list_new != list_old, "new system request gets fresh ID")
	_check(router.pending_route_count() == 2, "system refresh retains create slot")
	backend.reply(list_old, true, [{"id": "stale"}])
	_check(_list_events.is_empty(), "stale system response ignored")
	backend.reply(create_old, true, [{"id": "ps2"}])
	_check(_create_events.size() == 1, "create response survives system refresh")
	_check((_create_events[0]["data"] as Array)[0]["id"] == "ps2", "create data preserved")
	backend.reply(list_new, true, [{"id": "retroarch"}])
	_check(_list_events.size() == 1 and _list_events[0]["id"] == list_new, "latest system response delivered")
	_check((_list_events[0]["data"] as Array)[0]["id"] == "retroarch", "system data preserved")
	backend.reply(list_new, true, [])
	_check(_list_events.size() == 1, "duplicate system reply ignored")
	_check(router.pending_route_count() == 0, "completed reads retire both routes")

	var create_stale: String = ctrl.request_game_create_list()
	var create_latest: String = ctrl.request_game_create_list()
	_check(create_stale != create_latest, "create refresh gets new ID")
	_check(router.pending_route_count() == 1, "create latest slot supersedes previous")
	backend.reply(create_stale, true, [])
	_check(_create_events.size() == 1, "stale create response ignored")
	backend.reply(create_latest, false, null, {"message": "read failed"})
	_check(_create_events.size() == 2 and not _create_events[1]["ok"], "create failure forwarded")
	_check((_create_events[1]["error"] as Dictionary)["message"] == "read failed", "create error preserved")

	var list_failed: String = ctrl.request_list()
	backend.reply(list_failed, false, null, {"message": "offline"})
	_check(_list_events.size() == 2 and not _list_events[1]["ok"], "system failure forwarded")
	_check((_list_events[1]["error"] as Dictionary)["message"] == "offline", "system error preserved")

	var pending_system: String = ctrl.request_list()
	var pending_create: String = ctrl.request_game_create_list()
	_check(router.pending_route_count() == 2, "both reads pending before disconnect")
	backend.disconnected.emit(1006, "offline")
	_check(router.pending_route_count() == 0, "disconnect retires both slots")
	backend.reply(pending_system, true, [])
	backend.reply(pending_create, true, [])
	_check(_list_events.size() == 2, "late system reply ignored")
	_check(_create_events.size() == 2, "late create reply ignored")

	backend.available = false
	_check(ctrl.request_list().is_empty(), "failed system send returns empty ID")
	_check(ctrl.request_game_create_list().is_empty(), "failed create send returns empty ID")
	_check(router.pending_route_count() == 0, "failed sends create no routes")
	backend.available = true
	var recovered: String = ctrl.request_list()
	backend.reply(recovered, true, [{"id": "reconnected"}])
	_check(_list_events.size() == 3, "new request works after reconnect")
	_check(_list_events[2]["id"] == recovered, "reconnect response ID preserved")
	_check(_create_events.size() == 2, "reconnect system response does not affect create")
	_check(_legacy == 0, "migrated replies never leak to legacy")

	if _failures == 0:
		print("EMULATOR READS CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("EMULATOR READS CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
