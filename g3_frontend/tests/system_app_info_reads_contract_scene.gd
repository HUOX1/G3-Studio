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
		var rid: String = "system-%d" % counter
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _info_events: Array[Dictionary] = []
var _fontset_events: Array[Dictionary] = []
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

func _on_info(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_info_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_fontsets(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_fontset_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = SETTINGS_SCRIPT.new()
	add_child(empty)
	_check(empty.request_app_info().is_empty(), "unconfigured app info rejected")
	_check(empty.request_fontsets_list().is_empty(), "unconfigured fontset catalog rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = SETTINGS_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.app_info_completed.connect(_on_info)
	ctrl.fontsets_list_completed.connect(_on_fontsets)
	var fontsets_id: String = ctrl.request_fontsets_list()
	var info_id: String = ctrl.request_app_info()
	_check(not fontsets_id.is_empty() and not info_id.is_empty() and fontsets_id != info_id, "two independent startup reads sent")
	_check(backend.sent[fontsets_id] == {"command": "fontsets.list", "payload": {}}, "fontset catalog command preserved")
	_check(backend.sent[info_id] == {"command": "app.info", "payload": {}}, "app info command preserved")
	_check(router.pending_route_count() == 2, "both startup reads coexist")
	backend.reply(info_id, true, {"display": "v1"})
	backend.reply(fontsets_id, true, [{"id": "default"}])
	_check(_info_events.size() == 1 and str((_info_events[0]["data"] as Dictionary).get("display", "")) == "v1", "app metadata routed")
	_check(_fontset_events.size() == 1 and str((_fontset_events[0]["data"] as Array)[0].get("id", "")) == "default", "fontset catalog routed")
	_check(router.pending_route_count() == 0, "completed startup reads retired")
	var pending_info: String = ctrl.request_app_info()
	var pending_fontsets: String = ctrl.request_fontsets_list()
	backend.disconnected.emit(1006, "offline")
	_check(router.pending_route_count() == 0, "disconnect retires pending startup reads")
	backend.reply(pending_info, true, {})
	backend.reply(pending_fontsets, true, [])
	_check(_info_events.size() == 1 and _fontset_events.size() == 1, "late responses ignored after disconnect")
	backend.available = false
	_check(ctrl.request_app_info().is_empty(), "failed app info send returns empty ID")
	_check(ctrl.request_fontsets_list().is_empty(), "failed fontset send returns empty ID")
	_check(router.pending_route_count() == 0, "failed sends register no routes")
	_check(_legacy == 0, "routed replies never reach legacy handler")
	if _failures == 0:
		print("SYSTEM APP INFO READS CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("SYSTEM APP INFO READS CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
