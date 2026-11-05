extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const COVER_SCRIPT: Script = preload("res://scripts/cover_tool_controller.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	@warning_ignore("unused_signal")
	signal event_received(event_type: String, payload: Dictionary)
	signal disconnected(code: int, reason: String)
	var available: bool = true
	var counter: int = 0
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		counter += 1
		var rid: String = "cover-%d" % counter
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _scans: Array[Dictionary] = []
var _crops: Array[Dictionary] = []
var _progress: Array[Dictionary] = []
var _finished: Array[Dictionary] = []
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

func _on_scan(ok: bool, data: Variant, error: Variant) -> void:
	_scans.append({"ok": ok, "data": data, "error": error})

func _on_crop(ok: bool, data: Variant, error: Variant) -> void:
	_crops.append({"ok": ok, "data": data, "error": error})

func _on_progress(done: int, total: int) -> void:
	_progress.append({"done": done, "total": total})

func _on_finished(succeeded: int, failed: int) -> void:
	_finished.append({"succeeded": succeeded, "failed": failed})

func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var empty: Node = COVER_SCRIPT.new()
	add_child(empty)
	_check(empty.request_scan("main", "C:/covers", false).is_empty(), "unconfigured scan rejected")
	_check(empty.request_crop_apply("x", "t", 0).is_empty(), "unconfigured crop rejected")
	_check(not empty.start_batch([{"file_path": "x", "matched_title": "t"}]), "unconfigured batch rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var ctrl: Node = COVER_SCRIPT.new()
	add_child(ctrl)
	ctrl.configure(router)
	ctrl.scan_completed.connect(_on_scan)
	ctrl.crop_completed.connect(_on_crop)
	ctrl.batch_progress.connect(_on_progress)
	ctrl.batch_finished.connect(_on_finished)
	_check(ctrl.request_scan("other", "C:/covers", false).is_empty(), "invalid scan scope rejected")
	_check(ctrl.request_scan("main", "", false).is_empty(), "empty source rejected")
	_check(ctrl.request_crop_apply("", "t", 0).is_empty(), "empty crop source rejected")
	_check(ctrl.request_crop_apply("x", "", 0).is_empty(), "empty crop title rejected")
	_check(not ctrl.start_batch([]), "empty batch rejected")
	_check(router.pending_route_count() == 0, "invalid requests register no routes")

	var old_scan: String = ctrl.request_scan("main", "C:/source", false)
	var new_scan: String = ctrl.request_scan("private", "D:/source", true)
	_check(not old_scan.is_empty() and old_scan != new_scan, "scan requests have distinct IDs")
	_check(backend.sent[old_scan] == {"command": "cover_tool.scan", "payload": {"scope": "main", "source_dir": "C:/source", "overwrite": false}}, "first scan command and payload")
	_check(backend.sent[new_scan] == {"command": "cover_tool.scan", "payload": {"scope": "private", "source_dir": "D:/source", "overwrite": true}}, "second scan command and payload")
	_check(router.pending_route_count() == 1, "latest scan supersedes old")
	backend.reply(old_scan, true, {"items": ["stale"]})
	_check(_scans.is_empty(), "stale scan ignored")
	backend.reply(new_scan, true, {"items": ["current"]})
	_check(_scans.size() == 1 and _scans[0]["ok"], "latest scan delivered")
	_check((_scans[0]["data"] as Dictionary)["items"] == ["current"], "scan data preserved")
	backend.reply(new_scan, false, null)
	_check(_scans.size() == 1, "duplicate scan ignored")
	var error_scan: String = ctrl.request_scan("main", "C:/source", false)
	backend.reply(error_scan, false, null, {"message": "offline"})
	_check(_scans.size() == 2 and not _scans[1]["ok"], "scan error delivered")
	_check((_scans[1]["error"] as Dictionary)["message"] == "offline", "scan error detail preserved")

	var crop_a: String = ctrl.request_crop_apply("C:/a.jpg", "Movie A", 55)
	var crop_b: String = ctrl.request_crop_apply("C:/b.jpg", "Movie B", 80)
	_check(not crop_a.is_empty() and crop_a != crop_b, "independent crop requests coexist")
	_check(backend.sent[crop_a] == {"command": "cover_tool.apply_one", "payload": {"source_path": "C:/a.jpg", "title": "Movie A", "front_start_px": 55}}, "crop payload exact")
	_check(router.pending_route_count() == 2, "both crops remain pending")
	backend.reply(crop_b, false, null, {"message": "bad crop"})
	_check(_crops.size() == 1 and not _crops[0]["ok"], "crop failure delivered")
	backend.reply(crop_a, true, {"saved": true})
	_check(_crops.size() == 2 and _crops[1]["ok"], "crop success delivered")
	backend.reply(crop_a, true, {})
	_check(_crops.size() == 2, "duplicate crop ignored")
	_check(_progress.is_empty() and _finished.is_empty(), "manual crop never changes batch progress")

	var items: Array = [
		{"file_path": "C:/1.jpg", "matched_title": "One", "front_start_px": 10},
		{"file_path": "", "matched_title": "Invalid"},
		{"file_path": "C:/2.jpg", "matched_title": "Two", "front_start_px": 20},
	]
	_check(ctrl.start_batch(items), "batch accepted")
	_check(router.pending_route_count() == 1, "batch sends only first item")
	var first: String = "cover-%d" % backend.counter
	_check(backend.sent[first]["payload"]["title"] == "One", "batch starts in input order")
	items[0]["matched_title"] = "mutated"
	_check(backend.sent[first]["payload"]["title"] == "One", "batch payload copied")
	backend.reply(first, true, {})
	_check(_progress.size() == 2, "success and invalid entry each emit progress")
	_check(_progress[0] == {"done": 1, "total": 3}, "first progress has fixed total")
	_check(_progress[1] == {"done": 2, "total": 3}, "invalid entry counted as failure")
	_check(router.pending_route_count() == 1, "second valid item sent serially")
	var second: String = "cover-%d" % backend.counter
	_check(backend.sent[second]["payload"]["title"] == "Two", "batch dispatches second valid item")
	backend.reply(second, false, null, {"message": "write failed"})
	_check(_progress.size() == 3 and _progress[2] == {"done": 3, "total": 3}, "failed reply updates progress")
	_check(_finished.size() == 1 and _finished[0] == {"succeeded": 1, "failed": 2}, "batch final counts correct")
	_check(router.pending_route_count() == 0, "completed batch has no pending routes")
	backend.reply(second, true, {})
	_check(_finished.size() == 1, "duplicate batch reply does not finish twice")

	backend.available = false
	_check(ctrl.start_batch([{"file_path": "C:/fail.jpg", "matched_title": "Fail"}]), "send-failure batch starts")
	_check(_finished.size() == 2 and _finished[1] == {"succeeded": 0, "failed": 1}, "failed send counts once and finishes")
	_check(_progress.back() == {"done": 1, "total": 1}, "failed send updates progress")
	_check(ctrl.request_scan("main", "C:/source", false).is_empty(), "failed scan send returns empty ID")
	_check(ctrl.request_crop_apply("C:/x", "X", 0).is_empty(), "failed crop send returns empty ID")
	_check(router.pending_route_count() == 0, "failed sends create no routes")
	backend.available = true

	_check(ctrl.start_batch([{"file_path": "C:/old", "matched_title": "Old"}]), "old overlapping batch starts")
	var old_batch: String = "cover-%d" % backend.counter
	_check(ctrl.start_batch([{"file_path": "C:/new", "matched_title": "New"}]), "new batch supersedes old ownership")
	var new_batch: String = "cover-%d" % backend.counter
	backend.reply(old_batch, true, {})
	_check(_finished.size() == 2, "old batch reply cannot finish new batch")
	backend.reply(new_batch, true, {})
	_check(_finished.size() == 3 and _finished[2] == {"succeeded": 1, "failed": 0}, "new batch finishes independently")
	_check(_legacy == 0, "all migrated replies stay out of legacy")

	var late_scan: String = ctrl.request_scan("main", "C:/late", false)
	var late_crop: String = ctrl.request_crop_apply("C:/late", "Late", 0)
	backend.disconnected.emit(1006, "offline")
	backend.reply(late_scan, true, {})
	backend.reply(late_crop, true, {})
	_check(_scans.size() == 2 and _crops.size() == 2, "disconnect retires late scan and crop")
	_check(router.pending_route_count() == 0, "disconnect clears outstanding routes")
	_check(_legacy == 0, "no late replies leak into legacy")

	if _failures == 0:
		print("COVER TOOL CONTROLLER CONTRACT PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("COVER TOOL CONTROLLER CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
		get_tree().quit(1)
