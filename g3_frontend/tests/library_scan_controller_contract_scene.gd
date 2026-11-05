extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const SCAN_SCRIPT: Script = preload("res://scripts/library_scan_controller.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	signal event_received(event_type: String, payload: Dictionary)
	signal disconnected(code: int, reason: String)
	var counter: int = 0
	var available: bool = true
	var commands: Dictionary = {}
	func request(command: String, _payload: Dictionary = {}) -> String:
		if not available:
			return ""
		counter += 1
		var req_id: String = "scan-%d" % counter
		commands[req_id] = command
		return req_id
	func reply(req_id: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(req_id, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _results: Array = []
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

func _on_result(tab_id: String, ok: bool, items: Array, error: Variant) -> void:
	_results.append({"tab": tab_id, "ok": ok, "items": items, "error": error})

func _on_legacy(_req_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
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
	scan.scan_completed.connect(_on_result)
	var tabs: Array[String] = ["emulator", "steam", "gog", "epic", "uplay", "rockstar", "psn"]
	var expected: Array[String] = ["game.scan_emulator", "game.scan_steam_library", "game.scan_gog_library", "game.scan_epic_library", "game.scan_uplay_library", "game.scan_rockstar_library", "game.scan_psn_library"]
	var ids: Dictionary = {}
	for i in range(tabs.size()):
		var req_id: String = scan.start_scan(tabs[i])
		ids[tabs[i]] = req_id
		_check(not req_id.is_empty() and str(backend.commands.get(req_id, "")) == expected[i], "command mapping " + tabs[i])
	_check(router.pending_route_count() == 7, "seven independent in-flight scans")
	# Reverse-order delivery verifies that tabs cannot cross-route.
	for i in range(tabs.size() - 1, -1, -1):
		backend.reply(str(ids[tabs[i]]), true, {"items": [{"title": tabs[i]}]})
		_check(_results.size() == tabs.size() - i and str(_results.back()["tab"]) == tabs[i], "response routing " + tabs[i])
	_check(router.pending_route_count() == 0 and _legacy == 0, "scan responses consumed by Router only")
	backend.reply(str(ids["steam"]), true, {"items": []})
	_check(_results.size() == 7 and _legacy == 0, "duplicate scan reply ignored")
	var old_id: String = scan.start_scan("epic")
	var new_id: String = scan.start_scan("epic")
	backend.reply(old_id, true, {"items": [{"title": "old"}]})
	_check(_results.size() == 7, "superseded scan ignored")
	backend.reply(new_id, true, {"items": [{"title": "new"}]})
	_check(_results.size() == 8 and str(_results.back()["items"][0]["title"]) == "new", "newest scan accepted")
	var failed_id: String = scan.start_scan("gog")
	backend.reply(failed_id, false, null, {"message": "mock failure"})
	_check(_results.size() == 9 and not bool(_results.back()["ok"]), "failed scan reported")
	var malformed_id: String = scan.start_scan("psn")
	backend.reply(malformed_id, true, ["unexpected"])
	_check(_results.size() == 10 and not bool(_results.back()["ok"]), "malformed payload reported as failure")
	_check(scan.start_scan("unknown").is_empty(), "unknown platform rejected")
	backend.available = false
	_check(scan.start_scan("steam").is_empty(), "failed send returns empty ID")
	backend.available = true
	var disconnected_id: String = scan.start_scan("steam")
	backend.disconnected.emit(1006, "mock disconnect")
	backend.reply(disconnected_id, true, {"items": []})
	_check(_results.size() == 10, "late reply after disconnect ignored")
	if _failures == 0:
		print("LIBRARY SCAN CONTROLLER CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("LIBRARY SCAN CONTROLLER CONTRACT FAIL: %d/%d failed" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
