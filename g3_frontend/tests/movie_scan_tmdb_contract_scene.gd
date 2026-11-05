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
		var id: String = "scan-tmdb-%d" % counter
		sent[id] = {"command": command, "payload": payload.duplicate(true)}
		return id
	func reply(id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(id, ok, data, error)

var checks: int = 0
var failures: int = 0
var legacy: int = 0
var scans: Array[Dictionary] = []
var searches: Array[Dictionary] = []

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

func _on_scan(scope: String, ok: bool, data: Variant, error: Variant) -> void:
	scans.append({"scope": scope, "ok": ok, "data": data, "error": error})

func _on_search(ok: bool, data: Variant, error: Variant) -> void:
	searches.append({"ok": ok, "data": data, "error": error})

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
	movie.scan_completed.connect(_on_scan)
	movie.tmdb_search_completed.connect(_on_search)
	var old_scan: String = movie.request_scan("main")
	_check(not old_scan.is_empty(), "scan request sent")
	_check(backend.sent[old_scan]["command"] == "library.scan_movies", "scan command preserved")
	_check(backend.sent[old_scan]["payload"] == {"scope": "main"}, "scan scope preserved")
	var old_search: String = movie.request_tmdb_search("海边", "movie")
	_check(not old_search.is_empty(), "TMDB search sent")
	_check(backend.sent[old_search]["command"] == "tmdb.search", "TMDB command preserved")
	_check(backend.sent[old_search]["payload"] == {"query": "海边", "media_type": "movie"}, "TMDB payload preserved")
	_check(router.pending_route_count() == 2, "scan and TMDB search independent")
	var new_scan: String = movie.request_scan("private")
	_check(router.pending_route_count() == 2, "new scan supersedes old scan only")
	backend.reply(old_scan, true, {"total_found": 100})
	_check(scans.is_empty(), "old scan response ignored")
	backend.reply(old_search, true, [{"title": "test"}])
	_check(searches.size() == 1 and searches[0]["ok"], "TMDB result delivered independently")
	backend.reply(new_scan, true, {"added": 2})
	_check(scans.size() == 1 and scans[0]["scope"] == "private" and scans[0]["ok"], "latest scan result delivered with scope")
	backend.reply(new_scan, true, {})
	_check(scans.size() == 1, "duplicate scan ignored")
	var new_search: String = movie.request_tmdb_search("new", "tv")
	_check(backend.sent[new_search]["payload"] == {"query": "new", "media_type": "tv"}, "new TMDB search payload preserved")
	backend.reply(new_search, false, null, {"message": "offline"})
	_check(searches.size() == 2 and not searches[1]["ok"], "TMDB error delivered")
	_check(router.pending_route_count() == 0, "all routes consumed")
	var stale: String = movie.request_tmdb_search("old", "movie")
	backend.available = false
	_check(movie.request_tmdb_search("failed", "movie").is_empty(), "failed latest send returns empty")
	backend.reply(stale, true, [])
	_check(searches.size() == 2, "failed send invalidates old TMDB request")
	backend.available = true
	var pending: String = movie.request_scan("main")
	backend.disconnected.emit(1006, "lost")
	backend.reply(pending, true, {})
	_check(scans.size() == 1, "late scan response after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears routes")
	_check(legacy == 0, "migrated replies never reach legacy")
	if failures == 0 and checks == 20:
		print("MOVIE SCAN TMDB CONTRACT PASS: 20 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE SCAN TMDB CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
