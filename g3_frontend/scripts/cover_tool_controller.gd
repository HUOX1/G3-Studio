extends Node

# Stage 5.5: cover-tool backend request ownership and serialized batch work.
# UI remains in main.gd. Batch and manual crop requests never share callbacks.
signal scan_completed(ok: bool, data: Variant, error: Variant)
signal batch_progress(done: int, total: int)
signal batch_finished(succeeded: int, failed: int)
signal crop_completed(ok: bool, data: Variant, error: Variant)

var _router: Node = null
var _queue: Array = []
var _batch_total: int = 0
var _batch_succeeded: int = 0
var _batch_failed: int = 0
var _batch_generation: int = 0
var _batch_active: bool = false

func configure(router: Node) -> void:
	_router = router

func request_scan(scope: String, source_dir: String, overwrite: bool) -> String:
	if _router == null or (scope != "main" and scope != "private") or source_dir.is_empty():
		return ""
	return _router.request_latest(
		"cover_tool.scan", "cover_tool.scan",
		{"scope": scope, "source_dir": source_dir, "overwrite": overwrite},
		Callable(self, "_on_scan_response")
	)

func request_crop_apply(source_path: String, title: String, front_start_px: int) -> String:
	if _router == null or source_path.is_empty() or title.is_empty():
		return ""
	return _router.request(
		"cover_tool.apply_one", _make_payload(source_path, title, front_start_px),
		Callable(self, "_on_crop_response")
	)

func start_batch(items: Array) -> bool:
	if _router == null or items.is_empty():
		return false
	# A new batch retires ownership of the previous batch's in-flight reply.
	# The router still consumes that reply, but its generation cannot advance this batch.
	_batch_generation += 1
	_batch_active = true
	_queue = items.duplicate(true)
	_batch_total = _queue.size()
	_batch_succeeded = 0
	_batch_failed = 0
	_dispatch_next(_batch_generation)
	return true

func _make_payload(source_path: String, title: String, front_start_px: int) -> Dictionary:
	return {"source_path": source_path, "title": title, "front_start_px": front_start_px}

func _on_scan_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	scan_completed.emit(ok, data, error)

func _on_crop_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	crop_completed.emit(ok, data, error)

func _on_batch_response(_request_id: String, ok: bool, _data: Variant, _error: Variant, generation: int) -> void:
	if not _batch_active or generation != _batch_generation:
		return
	if ok:
		_batch_succeeded += 1
	else:
		_batch_failed += 1
	batch_progress.emit(_batch_succeeded + _batch_failed, _batch_total)
	_dispatch_next(generation)

func _dispatch_next(generation: int) -> void:
	if not _batch_active or generation != _batch_generation:
		return
	while not _queue.is_empty():
		var raw: Variant = _queue.pop_front()
		var item: Dictionary = raw if raw is Dictionary else {}
		var source_path: String = str(item.get("file_path", ""))
		var title: String = str(item.get("matched_title", ""))
		var front_start_px: int = int(item.get("front_start_px", 0))
		if source_path.is_empty() or title.is_empty():
			_batch_failed += 1
			batch_progress.emit(_batch_succeeded + _batch_failed, _batch_total)
			continue
		var request_id: String = _router.request(
			"cover_tool.apply_one", _make_payload(source_path, title, front_start_px),
			Callable(self, "_on_batch_response").bind(generation)
		)
		if request_id.is_empty():
			_batch_failed += 1
			batch_progress.emit(_batch_succeeded + _batch_failed, _batch_total)
			continue
		return
	_batch_active = false
	batch_finished.emit(_batch_succeeded, _batch_failed)
