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
		var id: String = "asset-%d" % counter
		sent[id] = {"command": command, "payload": payload.duplicate(true)}
		return id
	func reply(id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(id, ok, data, error)

var checks: int = 0
var failures: int = 0
var legacy: int = 0
var covers: Array[Dictionary] = []
var backdrops: Array[Dictionary] = []

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

func _on_cover(ok: bool, data: Variant, error: Variant) -> void:
	covers.append({"ok": ok, "data": data, "error": error})

func _on_backdrop(ok: bool, data: Variant, error: Variant) -> void:
	backdrops.append({"ok": ok, "data": data, "error": error})

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
	_check(not movie.has_pending_cover_file_target(), "cover picker target starts empty")
	_check(movie.request_pending_cover_set("unused.png").is_empty(), "pending cover request rejects missing target")
	movie.set_pending_cover_file_target("film-pending-cover")
	_check(movie.has_pending_cover_file_target(), "cover picker target staged")
	var pending_cover_id: String = movie.request_pending_cover_set("selected.png")
	var pending_cover_sent: bool = not pending_cover_id.is_empty() and backend.sent.has(pending_cover_id)
	_check(pending_cover_sent, "pending cover request sent")
	_check(pending_cover_sent and backend.sent[pending_cover_id]["payload"] == {"id": "film-pending-cover", "source": "selected.png"}, "pending cover uses staged target")
	if pending_cover_sent:
		backend.reply(pending_cover_id, true, {})
	_check(pending_cover_sent and not movie.has_pending_cover_file_target(), "cover picker target cleared after response")
	_check(not movie.has_pending_backdrop_file_target(), "backdrop picker target starts empty")
	_check(movie.request_pending_backdrop_set("unused.png").is_empty(), "pending backdrop request rejects missing target")
	movie.set_pending_backdrop_file_target("film-pending-backdrop")
	_check(movie.has_pending_backdrop_file_target(), "backdrop picker target staged")
	var pending_backdrop_id: String = movie.request_pending_backdrop_set("selected-backdrop.png")
	var pending_backdrop_sent: bool = not pending_backdrop_id.is_empty() and backend.sent.has(pending_backdrop_id)
	_check(pending_backdrop_sent, "pending backdrop request sent")
	_check(pending_backdrop_sent and backend.sent[pending_backdrop_id]["payload"] == {"id": "film-pending-backdrop", "source": "selected-backdrop.png"}, "pending backdrop uses staged target")
	if pending_backdrop_sent:
		backend.reply(pending_backdrop_id, true, {})
	_check(pending_backdrop_sent and not movie.has_pending_backdrop_file_target(), "backdrop picker target cleared after response")
	movie.cover_set_completed.connect(_on_cover)
	movie.backdrop_set_completed.connect(_on_backdrop)

	_check(movie.request_cover_set("", "a.png").is_empty(), "empty cover target rejected")
	_check(movie.request_backdrop_set("", "b.png").is_empty(), "empty backdrop target rejected")
	var cover_old: String = movie.request_cover_set("film-1", "first.png")
	_check(not cover_old.is_empty(), "cover request sent")
	_check(backend.sent[cover_old]["command"] == "movie.cover.set", "cover command preserved")
	_check(backend.sent[cover_old]["payload"] == {"id": "film-1", "source": "first.png"}, "cover payload preserved")
	var backdrop_old: String = movie.request_backdrop_set("film-2", "back.png")
	_check(not backdrop_old.is_empty(), "backdrop request sent")
	_check(backend.sent[backdrop_old]["command"] == "movie.backdrop.set", "backdrop command preserved")
	_check(backend.sent[backdrop_old]["payload"] == {"id": "film-2", "source": "back.png"}, "backdrop payload preserved")
	_check(router.pending_route_count() == 2, "cover and backdrop independent")
	var cover_new: String = movie.request_cover_set("film-3", "second.png")
	_check(router.pending_route_count() == 2, "new cover supersedes cover only")
	backend.reply(cover_old, true, {})
	_check(covers.is_empty(), "old cover response ignored")
	backend.reply(backdrop_old, false, null, {"message": "failed"})
	_check(backdrops.size() == 1 and not backdrops[0]["ok"], "backdrop failure delivered independently")
	backend.reply(cover_new, true, {"updated": true})
	_check(covers.size() == 1 and covers[0]["ok"], "new cover success delivered")
	backend.reply(cover_new, true, {})
	_check(covers.size() == 1, "duplicate cover response ignored")
	_check(router.pending_route_count() == 0, "all asset routes consumed")
	var stale: String = movie.request_backdrop_set("film-4", "old.png")
	backend.available = false
	_check(movie.request_backdrop_set("film-5", "new.png").is_empty(), "failed latest replacement returns empty")
	backend.reply(stale, true, {})
	_check(backdrops.size() == 1, "failed replacement invalidates old response")
	backend.available = true
	var pending: String = movie.request_cover_set("film-6", "last.png")
	backend.disconnected.emit(1006, "lost")
	backend.reply(pending, true, {})
	_check(covers.size() == 1, "late cover response after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears pending asset routes")
	_check(legacy == 0, "asset replies do not leak to legacy")
	if failures == 0 and checks == 32:
		print("MOVIE ASSETS CONTRACT PASS: 32 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE ASSETS CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
