extends RefCounted

# UI-S6b: cover-tool dialog presentation only. Request ownership remains in the controller.
signal runtime_error_requested(title: String, message: String)
signal batch_reload_requested

var _scan_dialog: Node = null
var _crop_dialog: Node = null

func configure(scan_dialog: Node, crop_dialog: Node) -> void:
	_scan_dialog = scan_dialog
	_crop_dialog = crop_dialog

func show_scan_completed(ok: bool, data: Variant, error_message: String) -> void:
	if ok and data is Dictionary:
		var items_raw: Variant = (data as Dictionary).get("items", [])
		var items: Array = items_raw if items_raw is Array else []
		if _scan_dialog != null:
			_scan_dialog.show_scan_results(items)
	else:
		if _scan_dialog != null:
			_scan_dialog.show_scan_results([])
		runtime_error_requested.emit("扫描失败", error_message)

func show_batch_progress(done: int, total: int) -> void:
	if _scan_dialog != null:
		_scan_dialog.show_apply_progress(done, total)

func show_batch_finished(succeeded: int, failed: int) -> void:
	if _scan_dialog != null:
		_scan_dialog.show_apply_done(succeeded, failed)
	batch_reload_requested.emit()

func show_crop_editor(item: Dictionary) -> void:
	if _crop_dialog == null:
		return
	var source_path: String = str(item.get("file_path", ""))
	var title: String = str(item.get("matched_title", ""))
	var initial_front_px: int = int(item.get("front_start_px", 0))
	if source_path.is_empty() or title.is_empty():
		return
	_crop_dialog.show_for(source_path, title, initial_front_px)
