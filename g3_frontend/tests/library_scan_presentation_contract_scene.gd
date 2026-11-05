extends Node

const PRESENTER_SCRIPT: Script = preload("res://scripts/library_scan_presentation.gd")
const EXPECTED_CHECKS: int = 65

class MockBackend:
	extends Node
	var connected: bool = true
	func is_connected_to_backend() -> bool:
		return connected

class MockScanController:
	extends Node
	var requests: Array[String] = []
	var allow_send: bool = true
	func start_scan(tab_id: String) -> String:
		requests.append(tab_id)
		return "req-%s" % tab_id if allow_send else ""

class MockDialog:
	extends Node
	var begins: Array[String] = []
	var results: Array = []
	var errors: Array = []
	func begin_scan(tab_id: String) -> void:
		begins.append(tab_id)
	func show_scan_results(tab_id: String, items: Array) -> void:
		results.append({"tab": tab_id, "items": items.duplicate()})
	func show_scan_error(tab_id: String, message: String) -> void:
		errors.append({"tab": tab_id, "message": message})

var checks: int = 0
var failures: int = 0
var runtime_errors: Array = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _on_error(title: String, message: String) -> void:
	runtime_errors.append({"title": title, "message": message})

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var controller: MockScanController = MockScanController.new()
	add_child(controller)
	var dialog: MockDialog = MockDialog.new()
	add_child(dialog)
	var status: Label = Label.new()
	add_child(status)
	var presenter: Node = PRESENTER_SCRIPT.new()
	add_child(presenter)
	presenter.configure(controller, backend, dialog, status)
	presenter.runtime_error_requested.connect(_on_error)
	var tabs: Array[String] = ["emulator", "steam", "gog", "epic", "uplay", "rockstar", "psn"]
	var starts: Array[String] = ["正在扫描模拟器游戏…", "正在扫描 Steam 库…", "正在扫描 GOG 库…", "正在扫描 Epic 库…", "正在扫描 Uplay 库…", "正在扫描 Rockstar 库…", "正在扫描 PSN 库…"]
	var dones: Array[String] = ["扫描完成", "Steam 库扫描完成", "GOG 库扫描完成", "Epic 库扫描完成", "Uplay 库扫描完成", "Rockstar 库扫描完成", "PSN 库扫描完成"]
	var titles: Array[String] = ["扫描模拟器游戏失败", "扫描 Steam 库失败", "扫描 GOG 库失败", "扫描 Epic 库失败", "扫描 Uplay 库失败", "扫描 Rockstar 库失败", "扫描 PSN 库失败"]
	for i in range(tabs.size()):
		var tab_id: String = tabs[i]
		presenter.request_scan(tab_id)
		_check(controller.requests.back() == tab_id, "request routed " + tab_id)
		_check(status.text == starts[i], "start label " + tab_id)
		var items: Array = [{"title": tab_id}]
		presenter.on_scan_completed(tab_id, true, items, null)
		_check(dialog.begins.back() == tab_id, "begin scan on success " + tab_id)
		_check(dialog.results.back()["tab"] == tab_id and dialog.results.back()["items"] == items, "results shown " + tab_id)
		_check(status.text == dones[i], "success label " + tab_id)
		presenter.on_scan_completed(tab_id, false, [], {"message": "failed " + tab_id})
		_check(dialog.errors.back()["tab"] == tab_id and dialog.errors.back()["message"] == "failed " + tab_id, "failure shown " + tab_id)
		_check(runtime_errors.back()["title"] == titles[i] and runtime_errors.back()["message"] == "failed " + tab_id, "failure title " + tab_id)
	var import_platforms: Array[String] = ["steam", "gog", "epic", "uplay", "rockstar", "psn"]
	var import_names: Array[String] = ["Steam", "GOG", "Epic", "Uplay", "Rockstar", "PSN"]
	for i in range(import_platforms.size()):
		presenter.on_platform_import_started(import_platforms[i], 3)
		_check(status.text == "正在导入 3 个 %s 游戏…" % import_names[i], "platform import start label " + import_platforms[i])
	var before_requests: int = controller.requests.size()
	var before_results: int = dialog.results.size()
	presenter.request_scan("unknown")
	presenter.on_scan_completed("unknown", true, [], null)
	_check(controller.requests.size() == before_requests and dialog.results.size() == before_results, "unknown tab ignored")
	backend.connected = false
	presenter.request_scan("steam")
	_check(controller.requests.size() == before_requests, "disconnected scan not sent")
	_check(runtime_errors.back()["title"] == "扫描游戏库失败" and runtime_errors.back()["message"] == "后端未连接", "disconnected error unchanged")
	backend.connected = true
	controller.allow_send = false
	status.text = "unchanged"
	presenter.request_scan("gog")
	_check(status.text == "unchanged", "failed send does not update label")
	presenter.on_scan_completed("steam", false, [], "plain failure")
	_check(dialog.errors.back()["message"] == "plain failure", "plain string error unchanged")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("_library_scan_controller.scan_completed.connect(_library_scan_presentation.on_scan_completed)"), "main connects presenter directly")
	_check(main_source.contains("func _on_library_scan_requested(tab_id: String) -> void:"), "legacy scan request retained for whitespace-safe migration")
	_check(not main_source.contains("func _on_library_scan_completed("), "old scan response switch removed")
	_check(not main_source.contains("var _steam_scan_items_cache"), "old per-platform main cache removed")
	_check(checks + 1 == EXPECTED_CHECKS, "expected check count")
	if failures == 0:
		print("LIBRARY SCAN PRESENTATION CONTRACT PASS: %d checks" % checks)
	else:
		push_error("LIBRARY SCAN PRESENTATION CONTRACT FAIL: %d/%d failed" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
