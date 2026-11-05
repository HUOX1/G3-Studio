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
	var sequence: int = 0
	var sent: Array[Dictionary] = []
	func request(command: String, payload: Dictionary) -> String:
		sequence += 1
		var request_id: String = "remaining-%d" % sequence
		sent.append({"id": request_id, "command": command, "payload": payload})
		return request_id
	func reply(request_id: String, ok: bool, data: Variant = null) -> void:
		response_received.emit(request_id, ok, data, null)
var checks: int = 0
var failures: int = 0
var matches: Array[Dictionary] = []
func _ready() -> void:
	call_deferred("_run")
func _check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[FAIL] " + name)
func _on_match(ok: bool, data: Variant, error: Variant) -> void:
	matches.append({"ok": ok, "data": data, "error": error})
func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	var movie: Node = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	movie.covers_match_completed.connect(_on_match)
	_check(movie.request_backdrop_ensure("") == "", "ensure rejects empty item")
	var a: String = movie.request_backdrop_ensure("film-a")
	_check(not a.is_empty(), "ensure sends request")
	_check(backend.sent[-1]["command"] == "movie.backdrop.ensure", "ensure command")
	_check(backend.sent[-1]["payload"].get("id") == "film-a", "ensure item payload")
	var b: String = movie.request_backdrop_ensure("film-b")
	_check(b != a, "ensures remain independent")
	backend.reply(b, true, {"status": "cached"})
	backend.reply(a, false, {})
	_check(matches.is_empty(), "ensure responses do not open UI")
	_check(router.pending_route_count() == 0, "ensure responses retired")
	_check(movie.request_covers_match("other") == "", "invalid scope rejected")
	var m1: String = movie.request_covers_match("main")
	_check(backend.sent[-1]["payload"].get("scope") == "main", "main scope forwarded")
	var m2: String = movie.request_covers_match("private")
	_check(backend.sent[-1]["payload"].get("scope") == "private", "private scope forwarded")
	backend.reply(m1, true, {"matched": 9})
	_check(matches.is_empty(), "old match reply retired")
	backend.reply(m2, true, {"matched": 2})
	_check(matches.size() == 1, "latest match emits once")
	_check(matches[0]["ok"] and int(matches[0]["data"].get("matched", 0)) == 2, "latest match payload intact")
	backend.reply(m2, true, {"matched": 2})
	_check(matches.size() == 1, "duplicate match reply ignored")
	var m3: String = movie.request_covers_match("main")
	backend.reply(m3, false, {})
	_check(matches.size() == 2 and not matches[-1]["ok"], "match error forwarded")
	var m4: String = movie.request_covers_match("private")
	backend.disconnected.emit(1006, "offline")
	backend.reply(m4, true, {"matched": 7})
	_check(matches.size() == 2, "late match after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears outstanding routes")
	if failures == 0 and checks == 17:
		print("MOVIE REMAINING REQUESTS CONTRACT PASS: 17 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE REMAINING REQUESTS CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
