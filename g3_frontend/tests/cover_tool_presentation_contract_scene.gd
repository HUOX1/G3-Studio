extends Node

const PRESENTER: Script = preload("res://scripts/cover_tool_presentation.gd")
const MOVIE_WALL_SCRIPT: Script = preload("res://scripts/movie_wall.gd")
const EXPECTED_BEFORE_FINAL: int = 42

class ScanDialogMock:
	extends Node
	var results: Array = []
	var progress: Array = []
	var done: Array = []
	func show_scan_results(items: Array) -> void:
		results.append(items.duplicate(true))
	func show_apply_progress(current: int, total: int) -> void:
		progress.append([current, total])
	func show_apply_done(succeeded: int, failed: int) -> void:
		done.append([succeeded, failed])

class CropDialogMock:
	extends Node
	var calls: Array = []
	func show_for(path: String, title: String, front_px: int) -> void:
		calls.append([path, title, front_px])

var checks: int = 0
var failures: int = 0
var errors: Array = []
var reload_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[FAIL] " + name)

func _error(title: String, message: String) -> void:
	errors.append([title, message])

func _reload() -> void:
	reload_count += 1

func _run() -> void:
	var p: RefCounted = PRESENTER.new()
	p.runtime_error_requested.connect(_error)
	p.batch_reload_requested.connect(_reload)
	p.show_scan_completed(true, {"items": [1]}, "")
	_check(errors.is_empty(), "success does not emit errors")
	p.show_batch_progress(1, 2)
	p.show_batch_finished(1, 0)
	_check(reload_count == 1, "reload requested even without dialog")
	p.show_crop_editor({"file_path": "A", "matched_title": "B"})
	_check(errors.is_empty(), "missing dialogs remain safe")
	var scan := ScanDialogMock.new()
	var crop := CropDialogMock.new()
	add_child(scan)
	add_child(crop)
	p.configure(scan, crop)
	p.show_scan_completed(true, {"items": [{"file_path": "x"}]}, "")
	_check(scan.results.size() == 1, "success shows results")
	_check(scan.results[0].size() == 1, "success retains one item")
	_check(scan.results[0][0].file_path == "x", "result contents preserved")
	_check(errors.is_empty(), "success emits no runtime error")
	p.show_scan_completed(true, {"items": "invalid"}, "")
	_check(scan.results.size() == 2, "invalid items still displayed")
	_check(scan.results[1].is_empty(), "invalid items coerced to empty")
	p.show_scan_completed(true, {}, "")
	_check(scan.results[2].is_empty(), "missing items default empty")
	p.show_scan_completed(false, null, "network")
	_check(scan.results.size() == 4, "failure clears results")
	_check(scan.results[3].is_empty(), "failure displays empty array")
	_check(errors.size() == 1, "failure emits runtime error")
	_check(errors[0] == ["扫描失败", "network"], "failure error wording preserved")
	p.show_scan_completed(true, [], "invalid payload")
	_check(scan.results.size() == 5, "non-dictionary success treated as failure")
	_check(scan.results[4].is_empty(), "non-dictionary clears list")
	_check(errors.size() == 2, "non-dictionary emits error")
	_check(errors[1] == ["扫描失败", "invalid payload"], "error message passed through")
	p.show_batch_progress(2, 5)
	_check(scan.progress.size() == 1, "batch progress forwarded")
	_check(scan.progress[0] == [2, 5], "batch progress values preserved")
	p.show_batch_finished(3, 1)
	_check(scan.done.size() == 1, "batch completion forwarded")
	_check(scan.done[0] == [3, 1], "batch completion values preserved")
	_check(reload_count == 2, "batch completion triggers reload once")
	p.show_crop_editor({})
	_check(crop.calls.is_empty(), "empty crop payload ignored")
	p.show_crop_editor({"file_path": "A"})
	_check(crop.calls.is_empty(), "crop missing title ignored")
	p.show_crop_editor({"matched_title": "B"})
	_check(crop.calls.is_empty(), "crop missing path ignored")
	p.show_crop_editor({"file_path": "C:/cover.jpg", "matched_title": "Movie", "front_start_px": 42})
	_check(crop.calls.size() == 1, "valid crop editor opened")
	_check(crop.calls[0] == ["C:/cover.jpg", "Movie", 42], "crop payload preserved")
	p.show_crop_editor({"file_path": "A", "matched_title": "B"})
	_check(crop.calls.size() == 2, "second crop editor opened")
	_check(crop.calls[1] == ["A", "B", 0], "missing front offset defaults zero")
	var wall: Variant = MOVIE_WALL_SCRIPT.new()
	_check(not wall.consume_cover_reload_after_list(), "cover reload has no initial pending state")
	wall.mark_cover_reload_after_list()
	_check(wall.consume_cover_reload_after_list(), "cover reload pending state consumed")
	_check(not wall.consume_cover_reload_after_list(), "cover reload pending state consumed once")
	_check(not wall.consume_backdrop_refresh_after_list(), "backdrop refresh has no initial pending state")
	wall.mark_backdrop_refresh_after_list()
	_check(wall.consume_backdrop_refresh_after_list(), "backdrop refresh pending state consumed")
	_check(not wall.consume_backdrop_refresh_after_list(), "backdrop refresh pending state consumed once")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("COVER_TOOL_PRESENTATION_SCRIPT.new()"), "main instantiates presentation")
	_check(main_source.contains("_cover_tool_presentation.batch_reload_requested.connect(_on_cover_tool_batch_reload_requested)"), "main owns refresh signal")
	_check(main_source.contains("movie_wall.mark_cover_reload_after_list()"), "main delegates cover reload intent to movie wall")
	_check(main_source.contains("movie_wall.mark_backdrop_refresh_after_list()"), "main delegates backdrop refresh intent to movie wall")
	_check(not main_source.contains("_force_reload_covers_on_next_list"), "main no longer owns deferred cover reload flag")
	_check(not main_source.contains("_pending_backdrop_changed"), "main no longer owns deferred backdrop refresh flag")
	_check(checks == EXPECTED_BEFORE_FINAL, "expected check count")
	if failures == 0:
		print("COVER TOOL PRESENTATION CONTRACT PASS: %d checks" % checks)
	else:
		push_error("COVER TOOL PRESENTATION CONTRACT FAIL: %d/%d failed" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
