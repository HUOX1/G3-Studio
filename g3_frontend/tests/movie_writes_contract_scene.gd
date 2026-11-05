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
		var id: String = "movie-write-%d" % counter
		sent[id] = {"command": command, "payload": payload.duplicate(true)}
		return id
	func reply(id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(id, ok, data, error)

var checks: int = 0
var failures: int = 0
var legacy: int = 0
var creates: Array[Dictionary] = []
var removes: Array[Dictionary] = []
var updates: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	checks += 1
	if ok:
		print("[PASS] ", name)
	else:
		failures += 1
		push_error("[FAIL] " + name)

func _on_legacy(_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	legacy += 1

func _on_create(ok: bool, data: Variant, error: Variant) -> void:
	creates.append({"ok": ok, "data": data, "error": error})

func _on_remove(ok: bool, data: Variant, error: Variant) -> void:
	removes.append({"ok": ok, "data": data, "error": error})

func _on_update(ok: bool, data: Variant, error: Variant) -> void:
	updates.append({"ok": ok, "data": data, "error": error})

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
	movie.create_completed.connect(_on_create)
	movie.remove_completed.connect(_on_remove)
	movie.metadata_update_completed.connect(_on_update)

	var first: String = movie.request_create({"title": "Film A", "scope": "private"})
	_check(not first.is_empty(), "create request sent")
	_check(backend.sent[first]["command"] == "movie.create", "create command unchanged")
	_check(backend.sent[first]["payload"].get("scope") == "private", "create scope preserved")
	var second: String = movie.request_create({"title": "Film B", "scope": "main"})
	_check(router.pending_route_count() == 1, "create latest slot replaces previous")
	backend.reply(first, true, {})
	_check(creates.is_empty(), "superseded create response ignored")
	backend.reply(second, true, {"id": "B"})
	_check(creates.size() == 1 and creates[0]["ok"], "newest create result emitted")
	backend.reply(second, false, null, {"message": "duplicate"})
	_check(creates.size() == 1, "duplicate create response ignored")

	var remove_id: String = movie.request_remove("film-1")
	var update_id: String = movie.request_metadata_update({"id": "film-2", "title": "Edited"})
	_check(router.pending_route_count() == 2, "remove and metadata update independent")
	_check(backend.sent[remove_id]["command"] == "movie.remove", "remove command unchanged")
	_check(backend.sent[remove_id]["payload"].get("id") == "film-1", "remove target preserved")
	_check(backend.sent[update_id]["command"] == "movie.metadata.update", "metadata update command unchanged")
	_check(backend.sent[update_id]["payload"].get("title") == "Edited", "metadata update payload preserved")
	backend.reply(update_id, false, null, {"message": "write failed"})
	_check(updates.size() == 1 and not updates[0]["ok"], "metadata update failure forwarded")
	backend.reply(remove_id, true, {})
	_check(removes.size() == 1 and removes[0]["ok"], "remove success forwarded")
	_check(router.pending_route_count() == 0, "all write routes consumed")
	_check(movie.request_remove("").is_empty(), "empty remove target rejected")

	var older: String = movie.request_remove("film-old")
	var newer: String = movie.request_remove("film-new")
	backend.reply(older, true, {})
	_check(removes.size() == 1, "superseded remove response ignored")
	backend.reply(newer, false, null, {"message": "not found"})
	_check(removes.size() == 2 and not removes[1]["ok"], "new remove failure forwarded")

	var old_update: String = movie.request_metadata_update({"id": "old"})
	backend.available = false
	_check(movie.request_metadata_update({"id": "new"}).is_empty(), "failed update replacement returns empty")
	backend.reply(old_update, true, {})
	_check(updates.size() == 1, "failed replacement invalidates old update")
	backend.available = true
	var disconnected: String = movie.request_create({"title": "late"})
	backend.disconnected.emit(1006, "lost")
	backend.reply(disconnected, true, {})
	_check(creates.size() == 1, "late write response after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears write routes")
	_check(legacy == 0, "write replies never reach legacy")

	if failures == 0:
		print("MOVIE WRITES CONTRACT PASS: %d checks" % checks)
	else:
		print("MOVIE WRITES CONTRACT FAIL: %d of %d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
