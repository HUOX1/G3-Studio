extends Node

const PRESENTER: Script = preload("res://scripts/library_scan_presentation.gd")
const EXPECTED_BEFORE_FINAL: int = 55

class MockDialog:
	extends Node
	var progress: Array = []
	var completed: Array = []
	func set_import_progress(platform: String, done: int, total: int) -> void:
		progress.append({"platform": platform, "done": done, "total": total})
	func set_import_done(platform: String, added: int, skipped: int, errors: int) -> void:
		completed.append({"platform": platform, "added": added, "skipped": skipped, "errors": errors})

var checks: int = 0
var failures: int = 0
var errors_seen: Array = []
var events: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	checks += 1
	if ok:
		print("[PASS] ", name)
	else:
		failures += 1
		push_error("[FAIL] " + name)

func _on_error(title: String, message: String) -> void:
	errors_seen.append({"title": title, "message": message})
	events.append("error")

func _on_clear() -> void:
	events.append("clear")

func _on_refresh() -> void:
	events.append("refresh")

func _run() -> void:
	var dialog: MockDialog = MockDialog.new()
	add_child(dialog)
	var status: Label = Label.new()
	add_child(status)
	var presenter: Node = PRESENTER.new()
	add_child(presenter)
	presenter.configure(null, null, dialog, status)
	presenter.runtime_error_requested.connect(_on_error)
	presenter.runtime_error_clear_requested.connect(_on_clear)
	presenter.games_refresh_requested.connect(_on_refresh)
	var platforms: Array[String] = ["steam", "gog", "epic", "uplay", "rockstar", "psn"]
	for platform in platforms:
		presenter.on_platform_import_progress(platform, 2, 5)
		_check(dialog.progress.back() == {"platform": platform, "done": 2, "total": 5}, "progress routed " + platform)
		events.clear()
		status.text = "waiting"
		presenter.on_platform_import_finished(platform, 3, 1, 0)
		var skip_label: String = "跳过" if platform == "psn" else "跳过已存在"
		_check(status.text == "导入完成：新增 3 · %s 1" % skip_label, "success text " + platform)
		_check(dialog.completed.back() == {"platform": platform, "added": 3, "skipped": 1, "errors": 0}, "completion dialog " + platform)
		_check(events == (["refresh"] if platform == "psn" else ["clear", "refresh"]), "success event order " + platform)
		events.clear()
		status.text = "unchanged"
		presenter.on_platform_import_finished(platform, 2, 1, 4)
		_check(status.text == "unchanged", "failure keeps status " + platform)
		_check(errors_seen.back() == {"title": "导入完成", "message": "新增 2 · %s 1 · 失败 4" % skip_label}, "failure text " + platform)
		_check(events == ["error", "refresh"], "failure event order " + platform)
	presenter.on_emulator_import_progress(1, 9)
	_check(dialog.progress.back() == {"platform": "emulator", "done": 1, "total": 9}, "emulator progress")
	events.clear()
	presenter.on_emulator_import_finished(4, 2, 0)
	_check(status.text == "导入完成：新增 4 · 跳过已存在 2", "emulator success text")
	_check(dialog.completed.back() == {"platform": "emulator", "added": 4, "skipped": 2, "errors": 0}, "emulator completion dialog")
	_check(events == ["clear", "refresh"], "emulator success order")
	events.clear()
	status.text = "unchanged"
	presenter.on_emulator_import_finished(1, 2, 3)
	_check(status.text == "unchanged", "emulator failure keeps status")
	_check(errors_seen.back() == {"title": "导入完成", "message": "新增 1 · 跳过已存在 2 · 失败 3"}, "emulator failure text")
	_check(events == ["error", "refresh"], "emulator failure order")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("_library_scan_controller.platform_import_finished.connect(_library_scan_presentation.on_platform_import_finished)"), "platform callback wired directly")
	_check(main_source.contains("_library_scan_controller.emulator_import_finished.connect(_library_scan_presentation.on_emulator_import_finished)"), "emulator callback wired directly")
	_check(main_source.contains("_library_scan_presentation.games_refresh_requested.connect(_request_games_list)"), "refresh stays with main")
	_check(main_source.contains("_library_scan_presentation.runtime_error_clear_requested.connect(_clear_runtime_error)"), "error clearing stays with main")
	_check(not main_source.contains("func _on_platform_import_finished("), "legacy platform UI callback removed")
	_check(not main_source.contains("func _on_emulator_import_finished("), "legacy emulator UI callback removed")
	_check(checks == EXPECTED_BEFORE_FINAL, "expected check count")
	if failures == 0:
		print("LIBRARY SCAN IMPORT PRESENTATION CONTRACT PASS: %d checks" % checks)
	else:
		push_error("LIBRARY SCAN IMPORT PRESENTATION CONTRACT FAIL: %d/%d failed" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
