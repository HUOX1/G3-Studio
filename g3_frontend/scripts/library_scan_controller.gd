extends Node

# Owns seven scan requests and platform batch-create response state.
# No UI or main.gd references: response ownership is request-id + platform.
signal scan_completed(tab_id: String, ok: bool, items: Array, error: Variant)
signal emulator_import_progress(done: int, total: int)
signal emulator_import_finished(added: int, skipped: int, errors: int)
signal platform_import_progress(platform: String, done: int, total: int)
signal platform_import_finished(platform: String, added: int, skipped: int, errors: int)

const IMPORT_PLATFORMS = ["steam", "gog", "epic", "uplay", "rockstar", "psn"]
var _platform_imports: Dictionary = {}

const SCAN_COMMANDS: Dictionary = {
	"emulator": "game.scan_emulator",
	"steam": "game.scan_steam_library",
	"gog": "game.scan_gog_library",
	"epic": "game.scan_epic_library",
	"uplay": "game.scan_uplay_library",
	"rockstar": "game.scan_rockstar_library",
	"psn": "game.scan_psn_library",
}

var _router: Node = null
var _pending_ids: Dictionary = {}

func configure(router: Node) -> void:
	_router = router

func start_scan(tab_id: String) -> String:
	if _router == null or not SCAN_COMMANDS.has(tab_id):
		return ""
	var request_id: String = _router.request(
		str(SCAN_COMMANDS[tab_id]), {}, Callable(self, "_on_scan_response").bind(tab_id)
	)
	# Legacy pending IDs changed only after a successful send.
	if not request_id.is_empty():
		_pending_ids[tab_id] = request_id
	return request_id

func _on_scan_response(request_id: String, ok: bool, data: Variant, error: Variant, tab_id: String) -> void:
	# A newer request for the same platform supersedes this reply.
	if str(_pending_ids.get(tab_id, "")) != request_id:
		return
	_pending_ids.erase(tab_id)
	if ok and data is Dictionary:
		var raw_items: Variant = (data as Dictionary).get("items", [])
		scan_completed.emit(tab_id, true, raw_items if raw_items is Array else [], error)
	else:
		scan_completed.emit(tab_id, false, [], error)

# Emulator batch-create pilot (existing behavior preserved).
# Keep the legacy behavior: failed sends are not counted; overlapping batches
# share one counter set, and replies are matched by request ID, not command.
var _emulator_create_ids: Array[String] = []
var _emulator_import_total: int = 0
var _emulator_import_done: int = 0
var _emulator_import_added: int = 0
var _emulator_import_errors: int = 0
var _emulator_import_skipped: int = 0

func start_emulator_import(payloads: Array[Dictionary], skipped_existing: int) -> int:
	var created: int = 0
	for payload: Dictionary in payloads:
		var request_id: String = _router.request("game.create", payload, Callable(self, "_on_emulator_create_response")) if _router != null else ""
		if request_id.is_empty():
			continue
		_emulator_create_ids.append(request_id)
		created += 1
	_emulator_import_total = created
	_emulator_import_done = 0
	_emulator_import_added = 0
	_emulator_import_errors = 0
	_emulator_import_skipped = skipped_existing
	if created == 0:
		_finish_emulator_import()
	return created

func _on_emulator_create_response(request_id: String, ok: bool, _data: Variant, _error: Variant) -> void:
	if not _emulator_create_ids.has(request_id):
		return
	_emulator_create_ids.erase(request_id)
	_emulator_import_done += 1
	if ok:
		_emulator_import_added += 1
	else:
		_emulator_import_errors += 1
	emulator_import_progress.emit(_emulator_import_done, _emulator_import_total)
	if _emulator_import_done >= _emulator_import_total:
		_finish_emulator_import()

func _finish_emulator_import() -> void:
	var added: int = _emulator_import_added
	var errors: int = _emulator_import_errors
	var skipped: int = _emulator_import_skipped
	_emulator_import_total = 0
	_emulator_import_done = 0
	_emulator_import_added = 0
	_emulator_import_errors = 0
	_emulator_import_skipped = 0
	_emulator_create_ids.clear()
	emulator_import_finished.emit(added, skipped, errors)

# The other six platforms have separate pending-id collections and counter sets.
# A new batch on the same platform resets counters but does not discard earlier
# pending IDs, matching the old main.gd behavior. Empty send IDs are not counted.

func start_platform_import(platform: String, payloads: Array[Dictionary], skipped_existing: int) -> int:
	if not IMPORT_PLATFORMS.has(platform):
		return 0
	var state: Dictionary = _platform_imports.get(platform, {
		"ids": [], "total": 0, "done": 0, "added": 0, "errors": 0, "skipped": 0
	})
	var ids: Array = state["ids"]
	var created: int = 0
	for payload: Dictionary in payloads:
		var request_id: String = _router.request("game.create", payload, Callable(self, "_on_platform_create_response").bind(platform)) if _router != null else ""
		if request_id.is_empty():
			continue
		ids.append(request_id)
		created += 1
	state["ids"] = ids
	state["total"] = created
	state["done"] = 0
	state["added"] = 0
	state["errors"] = 0
	state["skipped"] = skipped_existing
	_platform_imports[platform] = state
	if created == 0:
		_finish_platform_import(platform)
	return created

func _on_platform_create_response(request_id: String, ok: bool, _data: Variant, _error: Variant, platform: String) -> void:
	if not _platform_imports.has(platform):
		return
	var state: Dictionary = _platform_imports[platform]
	var ids: Array = state["ids"]
	if not ids.has(request_id):
		return
	ids.erase(request_id)
	state["ids"] = ids
	state["done"] = int(state["done"]) + 1
	if ok:
		state["added"] = int(state["added"]) + 1
	else:
		state["errors"] = int(state["errors"]) + 1
	_platform_imports[platform] = state
	platform_import_progress.emit(platform, int(state["done"]), int(state["total"]))
	if int(state["done"]) >= int(state["total"]):
		_finish_platform_import(platform)

func _finish_platform_import(platform: String) -> void:
	if not _platform_imports.has(platform):
		return
	var state: Dictionary = _platform_imports[platform]
	var added: int = int(state["added"])
	var skipped: int = int(state["skipped"])
	var errors: int = int(state["errors"])
	_platform_imports.erase(platform)
	platform_import_finished.emit(platform, added, skipped, errors)
