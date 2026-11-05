extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const SCAN_SCRIPT: Script = preload("res://scripts/library_scan_controller.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	@warning_ignore("unused_signal")
	signal event_received(event_type: String, payload: Dictionary)
	@warning_ignore("unused_signal")
	signal disconnected(code: int, reason: String)
	var counter: int = 0
	var available: bool = true
	var commands: Dictionary = {}
	var payloads: Dictionary = {}
	func request(command: String, payload: Dictionary = {}) -> String:
		if not available:
			return ""
		counter += 1
		var req_id: String = "import-%d" % counter
		commands[req_id] = command
		payloads[req_id] = payload
		return req_id
	func reply(req_id: String, ok: bool) -> void:
		response_received.emit(req_id, ok, {}, null)

var _checks: int = 0
var _failures: int = 0
var _progress: Array = []
var _finished: Array = []
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

func _on_progress(done: int, total: int) -> void:
	_progress.append([done, total])

func _on_finished(added: int, skipped: int, errors: int) -> void:
	_finished.append([added, skipped, errors])

func _on_legacy(_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var scan: Node = SCAN_SCRIPT.new()
	add_child(scan)
	scan.configure(router)
	scan.emulator_import_progress.connect(_on_progress)
	scan.emulator_import_finished.connect(_on_finished)
	var items: Array[Dictionary] = [{"title": "A"}, {"title": "B"}, {"title": "C"}]
	_check(scan.start_emulator_import(items, 2) == 3, "three requests sent")
	_check(router.pending_route_count() == 3, "three concurrent routes")
	_check(backend.commands["import-1"] == "game.create" and backend.payloads["import-1"]["title"] == "A", "create payload preserved")
	backend.reply("import-3", true)
	_check(_progress.size() == 1 and _progress[0] == [1, 3], "out-of-order progress")
	backend.reply("import-1", false)
	_check(_progress.size() == 2 and _progress[1] == [2, 3], "failed create counted")
	_check(_finished.is_empty(), "not finished before final response")
	backend.reply("import-2", true)
	_check(_progress.size() == 3 and _progress[2] == [3, 3], "final progress")
	_check(_finished.size() == 1 and _finished[0] == [2, 2, 1], "added skipped errors totals")
	_check(router.pending_route_count() == 0 and _legacy == 0, "all create replies owned by Router")
	backend.reply("import-2", true)
	_check(_finished.size() == 1 and _progress.size() == 3, "duplicate response ignored")
	var empty_items: Array[Dictionary] = []
	_check(scan.start_emulator_import(empty_items, 4) == 0, "empty batch sends no request")
	_check(_finished.size() == 2 and _finished[1] == [0, 4, 0], "empty batch completion and skips")
	backend.available = false
	var failed_send_items: Array[Dictionary] = [{"title": "D"}]
	_check(scan.start_emulator_import(failed_send_items, 1) == 0, "failed send not counted")
	_check(_finished.size() == 3 and _finished[2] == [0, 1, 0], "failed send matches legacy zero-create behavior")
	backend.available = true
	var retry_items: Array[Dictionary] = [{"title": "E"}]
	_check(scan.start_emulator_import(retry_items, 0) == 1, "new batch after failure")
	backend.reply("import-4", true)
	_check(_finished.size() == 4 and _finished[3] == [1, 0, 0], "new batch completed")
	_check(_legacy == 0, "no legacy fallback for migrated creates")
	if _failures == 0:
		print("LIBRARY SCAN IMPORT CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("LIBRARY SCAN IMPORT CONTRACT FAIL: %d/%d failed" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
