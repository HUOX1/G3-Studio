extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const MOVIE_SCRIPT: Script = preload("res://scripts/movie_controller.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	@warning_ignore("unused_signal")
	signal event_received(event_type: String, payload: Dictionary)
	@warning_ignore("unused_signal")
	signal disconnected(code: int, reason: String)
	var counter: int = 0
	var available: bool = true
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		counter += 1
		var request_id: String = "movie-detail-%d" % counter
		sent[request_id] = {"command": command, "payload": payload.duplicate(true)}
		return request_id
	func reply(request_id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

var _checks: int = 0
var _failed: int = 0
var _legacy: int = 0
var _metadata: Array[Dictionary] = []
var _backdrops: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	_checks += 1
	if value:
		print("[PASS] ", label)
	else:
		_failed += 1
		push_error("[FAIL] " + label)

func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _on_metadata(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_metadata.append({"id": item_id, "ok": ok, "data": data, "error": error})

func _on_backdrop(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_backdrops.append({"id": item_id, "ok": ok, "data": data, "error": error})

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var movie: Node = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	movie.metadata_completed.connect(_on_metadata)
	movie.backdrop_refresh_completed.connect(_on_backdrop)

	var first: String = movie.request_metadata("film-A")
	_check(not first.is_empty(), "metadata request sent")
	_check(backend.sent[first]["command"] == "movie.metadata.get", "metadata command preserved")
	_check(backend.sent[first]["payload"].get("id") == "film-A", "metadata target preserved")
	var second: String = movie.request_metadata("film-B")
	_check(router.pending_route_count() == 1, "metadata latest slot replaces old target")
	backend.reply(first, true, {"title": "stale"})
	_check(_metadata.is_empty(), "stale metadata response ignored")
	backend.reply(second, true, {"title": "new"})
	_check(_metadata.size() == 1 and _metadata[0]["id"] == "film-B", "metadata callback uses matching target")
	_check(_metadata.size() == 1 and _metadata[0]["data"].get("title") == "new", "metadata payload preserved")
	backend.reply(second, true, {"title": "duplicate"})
	_check(_metadata.size() == 1, "duplicate metadata reply ignored")

	var backdrop: String = movie.request_backdrop_refresh("film-C")
	_check(backend.sent[backdrop]["command"] == "movie.backdrop.refresh", "backdrop refresh command preserved")
	_check(backend.sent[backdrop]["payload"].get("id") == "film-C", "backdrop refresh target preserved")
	var metadata_error: String = movie.request_metadata("film-D")
	_check(router.pending_route_count() == 2, "metadata and backdrop requests remain independent")
	backend.reply(backdrop, false, null, {"message": "refresh failed"})
	_check(_backdrops.size() == 1 and not _backdrops[0]["ok"] and _backdrops[0]["id"] == "film-C", "backdrop failure forwarded")
	backend.reply(metadata_error, false, null, {"message": "not found"})
	_check(_metadata.size() == 2 and not _metadata[1]["ok"] and _metadata[1]["id"] == "film-D", "metadata failure forwarded")
	_check(router.pending_route_count() == 0, "both routes consumed")
	_check(movie.request_metadata("").is_empty() and movie.request_backdrop_refresh("").is_empty(), "empty item IDs rejected")
	var old: String = movie.request_metadata("film-E")
	backend.available = false
	_check(movie.request_metadata("film-F").is_empty(), "failed replacement returns empty ID")
	backend.reply(old, true, {"title": "late"})
	_check(_metadata.size() == 2, "failed replacement invalidates old metadata")
	backend.available = true
	var disconnected: String = movie.request_backdrop_refresh("film-G")
	backend.disconnected.emit(1006, "lost")
	backend.reply(disconnected, true, {})
	_check(_backdrops.size() == 1, "late backdrop reply after disconnect ignored")
	_check(_legacy == 0, "migrated replies never reach legacy")
	if _failed == 0:
		print("MOVIE REQUESTS CONTRACT PASS: %d checks" % _checks)
	else:
		print("MOVIE REQUESTS CONTRACT FAIL: %d of %d checks" % [_failed, _checks])
	get_tree().quit(0 if _failed == 0 else 1)
