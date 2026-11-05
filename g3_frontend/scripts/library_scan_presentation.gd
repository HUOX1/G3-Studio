extends Node

# UI-S5a: owns only scan UI presentation and seven per-platform result caches.
# Request ID matching and import creation stay in LibraryScanController.
# The legacy main.gd request entry remains in place during this safe incremental step.
signal runtime_error_requested(title: String, message: String)
signal runtime_error_clear_requested()
signal games_refresh_requested()

const SCAN_START_LABELS: Dictionary = {
	"emulator": "正在扫描模拟器游戏…",
	"steam": "正在扫描 Steam 库…",
	"gog": "正在扫描 GOG 库…",
	"epic": "正在扫描 Epic 库…",
	"uplay": "正在扫描 Uplay 库…",
	"rockstar": "正在扫描 Rockstar 库…",
	"psn": "正在扫描 PSN 库…",
}
const SCAN_DONE_LABELS: Dictionary = {
	"emulator": "扫描完成",
	"steam": "Steam 库扫描完成",
	"gog": "GOG 库扫描完成",
	"epic": "Epic 库扫描完成",
	"uplay": "Uplay 库扫描完成",
	"rockstar": "Rockstar 库扫描完成",
	"psn": "PSN 库扫描完成",
}
const SCAN_ERROR_TITLES: Dictionary = {
	"emulator": "扫描模拟器游戏失败",
	"steam": "扫描 Steam 库失败",
	"gog": "扫描 GOG 库失败",
	"epic": "扫描 Epic 库失败",
	"uplay": "扫描 Uplay 库失败",
	"rockstar": "扫描 Rockstar 库失败",
	"psn": "扫描 PSN 库失败",
}

var _scan_controller: Node
var _backend: Node
var _dialog: Node
var _backend_label: Label
var _items_by_tab: Dictionary = {}

func configure(scan_controller: Node, backend: Node, dialog: Node, backend_label: Label) -> void:
	_scan_controller = scan_controller
	_backend = backend
	_dialog = dialog
	_backend_label = backend_label

func request_scan(tab_id: String) -> void:
	# Preserve the old ordering: connection check happens before tab validation.
	if _backend == null or not _backend.is_connected_to_backend():
		runtime_error_requested.emit("扫描游戏库失败", "后端未连接")
		return
	if not SCAN_START_LABELS.has(tab_id):
		return
	var req_id: String = _scan_controller.start_scan(tab_id)
	if req_id.is_empty():
		return
	if _backend_label != null:
		_backend_label.text = str(SCAN_START_LABELS[tab_id])

func on_platform_import_started(platform: String, created: int) -> void:
	if created <= 0 or _backend_label == null:
		return
	var display_names: Dictionary = {
		"steam": "Steam",
		"gog": "GOG",
		"epic": "Epic",
		"uplay": "Uplay",
		"rockstar": "Rockstar",
		"psn": "PSN",
	}
	var display_name: String = str(display_names.get(platform, platform))
	_backend_label.text = "正在导入 %d 个 %s 游戏…" % [created, display_name]

func on_scan_completed(tab_id: String, ok: bool, items: Array, error: Variant) -> void:
	if not SCAN_START_LABELS.has(tab_id):
		return
	if ok:
		_items_by_tab[tab_id] = items
		if _dialog != null:
			_dialog.begin_scan(tab_id)
			_dialog.show_scan_results(tab_id, _items_by_tab[tab_id])
		if _backend_label != null:
			_backend_label.text = str(SCAN_DONE_LABELS[tab_id])
	else:
		_items_by_tab[tab_id] = []
		var message: String = _error_message(error)
		if _dialog != null:
			_dialog.show_scan_error(tab_id, message)
		runtime_error_requested.emit(str(SCAN_ERROR_TITLES[tab_id]), message)

func _error_message(error: Variant) -> String:
	if error is Dictionary:
		var payload: Dictionary = error as Dictionary
		return str(payload.get("message", payload))
	return str(error)

# UI-S5c: present routed import progress and completion; main owns backend requests.
func on_platform_import_progress(platform: String, done: int, total: int) -> void:
	if _dialog != null:
		_dialog.set_import_progress(platform, done, total)

func on_platform_import_finished(platform: String, added: int, skipped: int, errors: int) -> void:
	# Preserve PSN's original wording and no-clear-error behavior.
	var skipped_label: String = "跳过" if platform == "psn" else "跳过已存在"
	if errors > 0:
		runtime_error_requested.emit("导入完成", "新增 %d · %s %d · 失败 %d" % [added, skipped_label, skipped, errors])
	else:
		_backend_label.text = "导入完成：新增 %d · %s %d" % [added, skipped_label, skipped]
		if platform != "psn":
			runtime_error_clear_requested.emit()
	if _dialog != null:
		_dialog.set_import_done(platform, added, skipped, errors)
	games_refresh_requested.emit()

func on_emulator_import_progress(done: int, total: int) -> void:
	if _dialog != null:
		_dialog.set_import_progress("emulator", done, total)

func on_emulator_import_finished(added: int, skipped: int, errors: int) -> void:
	if errors > 0:
		runtime_error_requested.emit("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		_backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		runtime_error_clear_requested.emit()
	if _dialog != null:
		_dialog.set_import_done("emulator", added, skipped, errors)
	games_refresh_requested.emit()
