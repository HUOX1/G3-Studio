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
		var request_id: String = "multi-%d" % counter
		commands[request_id] = command
		payloads[request_id] = payload
		return request_id
	func reply(request_id: String, ok: bool) -> void:
		response_received.emit(request_id, ok, {}, null)

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

func _on_progress(platform: String, done: int, total: int) -> void:
	_progress.append([platform, done, total])

func _on_finished(platform: String, added: int, skipped: int, errors: int) -> void:
	_finished.append([platform, added, skipped, errors])

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
	scan.platform_import_progress.connect(_on_progress)
	scan.platform_import_finished.connect(_on_finished)
	var platforms: Array[String] = ["steam", "gog", "epic", "uplay", "rockstar", "psn"]
	for platform: String in platforms:
		var payloads: Array[Dictionary] = [{"title": platform + " A", "source": platform}, {"title": platform + " B", "source": platform}]
		var before: int = backend.counter
		_check(scan.start_platform_import(platform, payloads, 3) == 2, platform + " sends two creates")
		var first_id: String = "multi-%d" % (before + 1)
		var second_id: String = "multi-%d" % (before + 2)
		_check(backend.commands[first_id] == "game.create" and backend.payloads[first_id] == payloads[0], platform + " payload preserved")
		backend.reply(second_id, false)
		_check(_progress.back() == [platform, 1, 2], platform + " out-of-order failure progress")
		backend.reply(first_id, true)
		_check(_finished.back() == [platform, 1, 3, 1], platform + " final totals")
		var progress_count: int = _progress.size()
		backend.reply(first_id, true)
		_check(_progress.size() == progress_count, platform + " duplicate ignored")
	_check(_legacy == 0 and router.pending_route_count() == 0, "all platform creates routed exactly once")
	var empty_items: Array[Dictionary] = []
	_check(scan.start_platform_import("steam", empty_items, 4) == 0, "empty batch sends nothing")
	_check(_finished.back() == ["steam", 0, 4, 0], "empty batch reports skipped")
	backend.available = false
	var failed_items: Array[Dictionary] = [{"title": "fail"}]
	_check(scan.start_platform_import("gog", failed_items, 1) == 0, "failed send not counted")
	_check(_finished.back() == ["gog", 0, 1, 0], "failed send reports skipped")
	backend.available = true
	var one: Array[Dictionary] = [{"title": "X"}]
	_check(scan.start_platform_import("steam", one, 0) == 1, "steam concurrent with other platform")
	_check(scan.start_platform_import("gog", one, 0) == 1, "gog concurrent with steam")
	backend.reply("multi-%d" % backend.counter, true)
	_check(_finished.back() == ["gog", 1, 0, 0], "gog finishes independently")
	backend.reply("multi-%d" % (backend.counter - 1), true)
	_check(_finished.back() == ["steam", 1, 0, 0], "steam finishes independently")
	_check(_legacy == 0 and router.pending_route_count() == 0, "no legacy create response leakage")
	if _failures == 0:
		print("LIBRARY SCAN PLATFORM IMPORT CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("LIBRARY SCAN PLATFORM IMPORT CONTRACT FAIL: %d/%d failed" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
