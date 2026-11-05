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
		var rid: String = "emu-write-%d" % counter
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _save_events: Array[Dictionary] = []
var _delete_events: Array[Dictionary] = []
var _list_events: Array[Dictionary] = []
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

func _on_save(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_save_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_delete(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_delete_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_list(rid: String, ok: bool, data: Variant, error: Variant) -> void:
	_list_events.append({"id": rid, "ok": ok, "data": data, "error": error})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = EMULATOR_SCRIPT.new()
	add_child(empty)
	_check(empty.request_save({"name": "Test"}).is_empty(), "unconfigured save rejected")
	_check(empty.request_delete("emu").is_empty(), "unconfigured delete rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = EMULATOR_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.save_completed.connect(_on_save)
	ctrl.delete_completed.connect(_on_delete)
	ctrl.list_completed.connect(_on_list)
	_check(ctrl.request_delete("").is_empty(), "empty delete ID rejected")
	_check(router.pending_route_count() == 0, "invalid delete creates no route")

	var payload: Dictionary = {"id": "emu-a", "name": "Emulator A", "scan_dirs": ["D:/Games"], "executable": "emu.exe"}
	var save_old: String = ctrl.request_save(payload)
	var delete_old: String = ctrl.request_delete("emu-b")
	var list_id: String = ctrl.request_list()
	_check(not save_old.is_empty() and not delete_old.is_empty() and not list_id.is_empty(), "save delete list sent")
	_check(save_old != delete_old and delete_old != list_id and save_old != list_id, "three request IDs independent")
	_check(router.pending_route_count() == 3, "three independent latest slots coexist")
	_check(backend.sent[save_old]["command"] == "emulators.save", "save command preserved")
	_check(backend.sent[save_old]["payload"] == payload, "save payload preserved")
	_check(backend.sent[delete_old] == {"command": "emulators.delete", "payload": {"id": "emu-b"}}, "delete command and ID preserved")
	_check(backend.sent[list_id] == {"command": "emulators.list", "payload": {}}, "list command unaffected")
	payload["name"] = "Changed"
	(payload["scan_dirs"] as Array).append("E:/Games")
	_check(backend.sent[save_old]["payload"]["name"] == "Emulator A", "save name deep copied by backend")
	_check((backend.sent[save_old]["payload"]["scan_dirs"] as Array).size() == 1, "save nested dirs deep copied")

	var save_new: String = ctrl.request_save({"name": "New"})
	_check(save_new != save_old, "second save gets fresh ID")
	_check(router.pending_route_count() == 3, "save supersession leaves delete and list pending")
	backend.reply(save_old, true, {"id": "stale"})
	_check(_save_events.is_empty(), "superseded save reply ignored")
	backend.reply(delete_old, true, {"id": "emu-b", "deleted": true})
	_check(_delete_events.size() == 1, "delete success independent of save")
	_check(_delete_events[0]["id"] == delete_old, "delete response ID preserved")
	_check((_delete_events[0]["data"] as Dictionary)["deleted"], "delete response data preserved")
	backend.reply(save_new, true, {"id": "new"})
	_check(_save_events.size() == 1, "latest save success delivered")
	_check(_save_events[0]["id"] == save_new, "save response ID preserved")
	_check((_save_events[0]["data"] as Dictionary)["id"] == "new", "save response data preserved")
	backend.reply(save_new, true, {})
	backend.reply(delete_old, true, {})
	_check(_save_events.size() == 1, "duplicate save response ignored")
	_check(_delete_events.size() == 1, "duplicate delete response ignored")
	backend.reply(list_id, true, [{"id": "emu-a"}])
	_check(_list_events.size() == 1, "list response survives both writes")
	_check(router.pending_route_count() == 0, "completed requests retire all routes")

	var delete_stale: String = ctrl.request_delete("emu-c")
	var delete_latest: String = ctrl.request_delete("emu-d")
	_check(delete_stale != delete_latest, "second delete gets fresh ID")
	_check(router.pending_route_count() == 1, "delete latest slot supersedes prior delete")
	backend.reply(delete_stale, true, {})
	_check(_delete_events.size() == 1, "stale delete response ignored")
	backend.reply(delete_latest, false, null, {"message": "cannot remove"})
	_check(_delete_events.size() == 2 and not _delete_events[1]["ok"], "latest delete failure delivered")
	_check((_delete_events[1]["error"] as Dictionary)["message"] == "cannot remove", "delete error preserved")
	var failed_save: String = ctrl.request_save({"name": "Fail"})
	backend.reply(failed_save, false, null, {"message": "cannot save"})
	_check(_save_events.size() == 2 and not _save_events[1]["ok"], "save failure delivered")
	_check((_save_events[1]["error"] as Dictionary)["message"] == "cannot save", "save error preserved")

	var pending_save: String = ctrl.request_save({"name": "Pending"})
	var pending_delete: String = ctrl.request_delete("emu-z")
	_check(router.pending_route_count() == 2, "two writes pending before disconnect")
	backend.disconnected.emit(1006, "offline")
	_check(router.pending_route_count() == 0, "disconnect retires both write routes")
	backend.reply(pending_save, true, {})
	backend.reply(pending_delete, true, {})
	_check(_save_events.size() == 2, "late save reply ignored")
	_check(_delete_events.size() == 2, "late delete reply ignored")

	backend.available = false
	_check(ctrl.request_save({"name": "No"}).is_empty(), "failed save send returns empty ID")
	_check(ctrl.request_delete("emu-x").is_empty(), "failed delete send returns empty ID")
	_check(router.pending_route_count() == 0, "failed sends leave no routes")
	backend.available = true
	var recovered: String = ctrl.request_save({"name": "Recovered"})
	backend.reply(recovered, true, {"id": "recovered"})
	_check(_save_events.size() == 3, "save succeeds after reconnect")
	_check(_save_events[2]["id"] == recovered, "reconnect response ID preserved")
	_check(_legacy == 0, "migrated write responses do not leak into legacy")

	if _failures == 0:
		print("EMULATOR WRITES CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("EMULATOR WRITES CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
