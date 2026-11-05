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
		var id: String = "tmdb-posters-%d" % counter
		sent[id] = {"command": command, "payload": payload.duplicate(true)}
		return id
	func reply(id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(id, ok, data, error)

var checks: int = 0
var failures: int = 0
var legacy: int = 0
var applied: Array[Dictionary] = []
var listed: Array[Dictionary] = []
var thumbs: Array[Dictionary] = []
var poster_applied: Array[Dictionary] = []

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

func _on_apply(ok: bool, data: Variant, error: Variant) -> void:
	applied.append({"ok": ok, "data": data, "error": error})

func _on_list(ok: bool, data: Variant, error: Variant) -> void:
	listed.append({"ok": ok, "data": data, "error": error})

func _on_thumb(path: String, ok: bool, data: Variant, error: Variant) -> void:
	thumbs.append({"path": path, "ok": ok, "data": data, "error": error})

func _on_poster_apply(ok: bool, data: Variant, error: Variant) -> void:
	poster_applied.append({"ok": ok, "data": data, "error": error})

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
	movie.tmdb_apply_completed.connect(_on_apply)
	movie.poster_list_completed.connect(_on_list)
	movie.poster_thumb_completed.connect(_on_thumb)
	movie.poster_apply_completed.connect(_on_poster_apply)

	var a: String = movie.request_tmdb_apply("movie-a", 77, "movie")
	_check(not a.is_empty(), "TMDB apply request registered")
	_check(backend.sent[a] == {"command": "tmdb.apply", "payload": {"id": "movie-a", "tmdb_id": 77, "media_type": "movie"}}, "TMDB apply payload preserved")
	var l: String = movie.request_poster_list(77, "movie")
	_check(not l.is_empty(), "poster list registered")
	_check(backend.sent[l]["payload"] == {"tmdb_id": 77, "media_type": "movie"}, "poster list payload preserved")
	var t1: String = movie.request_poster_thumb("/a.jpg")
	var t2: String = movie.request_poster_thumb("/b.jpg")
	_check(not t1.is_empty() and not t2.is_empty() and t1 != t2, "thumbnail requests have separate IDs")
	_check(backend.sent[t1]["command"] == "tmdb.poster.thumb" and backend.sent[t1]["payload"] == {"file_path": "/a.jpg"}, "thumbnail payload preserved")
	var pa: String = movie.request_poster_apply("movie-a", "/a.jpg")
	_check(not pa.is_empty(), "poster apply registered")
	_check(backend.sent[pa]["payload"] == {"id": "movie-a", "file_path": "/a.jpg"}, "poster apply payload preserved")
	_check(router.pending_route_count() == 5, "three slots and two thumbnail routes coexist")
	backend.reply(t2, true, {"path": "/cache/b.jpg"})
	_check(thumbs.size() == 1 and thumbs[0]["path"] == "/b.jpg", "out-of-order thumbnail keeps source path")
	backend.reply(t1, false, null, {"message": "offline"})
	_check(thumbs.size() == 2 and thumbs[1]["path"] == "/a.jpg" and not thumbs[1]["ok"], "thumbnail failure keeps source path")
	backend.reply(t2, true, {})
	_check(thumbs.size() == 2, "duplicate thumbnail response ignored")
	backend.reply(l, true, {"posters": ["a", "b"]})
	_check(listed.size() == 1 and listed[0]["ok"], "poster list response delivered")
	backend.reply(a, true, {"updated": true})
	_check(applied.size() == 1 and applied[0]["ok"], "TMDB apply response delivered")
	backend.reply(pa, false, null, {"message": "bad"})
	_check(poster_applied.size() == 1 and not poster_applied[0]["ok"], "poster apply error delivered")
	_check(router.pending_route_count() == 0, "all first-batch routes consumed")

	var old_apply: String = movie.request_tmdb_apply("movie-a", 88, "tv")
	var new_apply: String = movie.request_tmdb_apply("movie-b", 99, "movie")
	backend.reply(old_apply, true, {})
	_check(applied.size() == 1, "superseded TMDB apply ignored")
	backend.reply(new_apply, true, {})
	_check(applied.size() == 2, "latest TMDB apply accepted")
	var old_list: String = movie.request_poster_list(10, "tv")
	var new_list: String = movie.request_poster_list(11, "movie")
	backend.reply(old_list, true, {})
	_check(listed.size() == 1, "superseded poster list ignored")
	backend.reply(new_list, false, null, {"message": "offline"})
	_check(listed.size() == 2 and not listed[1]["ok"], "latest poster list failure delivered")
	var old_pa: String = movie.request_poster_apply("movie-a", "old")
	var new_pa: String = movie.request_poster_apply("movie-b", "new")
	backend.reply(old_pa, true, {})
	_check(poster_applied.size() == 1, "superseded poster apply ignored")
	backend.reply(new_pa, true, {})
	_check(poster_applied.size() == 2 and poster_applied[1]["ok"], "latest poster apply accepted")
	_check(router.pending_route_count() == 0, "latest slots consumed")

	var pending_thumb: String = movie.request_poster_thumb("/pending.jpg")
	backend.disconnected.emit(1006, "lost")
	backend.reply(pending_thumb, true, {"path": "late"})
	_check(thumbs.size() == 2, "late thumbnail after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears thumbnail route")
	backend.available = false
	_check(movie.request_poster_thumb("/failed.jpg").is_empty(), "failed thumbnail send returns empty ID")
	_check(movie.request_poster_list(55, "tv").is_empty(), "failed list send returns empty ID")
	_check(router.pending_route_count() == 0, "failed sends register no routes")
	_check(legacy == 0, "migrated replies never leak to legacy")
	if failures == 0 and checks == 29:
		print("MOVIE TMDB POSTERS CONTRACT PASS: 29 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE TMDB POSTERS CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
