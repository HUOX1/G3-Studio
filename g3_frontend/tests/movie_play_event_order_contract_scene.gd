extends Node

# Stage 3.8: characterize existing Router/controller event ownership.
# This test does not simulate RenderingServer, mpv, or the main.gd UI.
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
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		sequence += 1
		var id: String = "event-%d" % sequence
		sent[id] = {"command": command, "payload": payload.duplicate(true)}
		return id
	func reply(id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(id, ok, data, error)

var checks: int = 0
var failures: int = 0
var events: Array[String] = []
var completions: Array[Dictionary] = []
var legacy_replies: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", name)
	else:
		failures += 1
		push_error("[FAIL] " + name)

func _on_event(name: String, _payload: Dictionary) -> void:
	events.append(name)

func _on_play(ok: bool, data: Variant, error: Variant) -> void:
	completions.append({"ok": ok, "data": data, "error": error})

func _on_legacy_response(_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	legacy_replies += 1

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_event_received.connect(_on_event)
	router.legacy_response_received.connect(_on_legacy_response)
	var movie: Node = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	movie.play_completed.connect(_on_play)

	# Event-before-response: characterize current behavior, not render safety.
	var first: String = movie.request_play("film-1")
	_check(not first.is_empty(), "play request registered")
	_check(router.pending_route_count() == 1, "play response still pending")
	backend.event_received.emit("movie.exited", {})
	_check(events == ["movie.exited"], "exit event forwarded before reply")
	_check(completions.is_empty(), "exit event does not synthesize play reply")
	backend.reply(first, true, {"monitorable": true})
	_check(completions.size() == 1, "late successful play reply still delivered")
	_check(bool(completions[0]["data"].get("monitorable", false)), "late reply retains monitorable flag")
	_check(router.pending_route_count() == 0, "late reply consumes route")

	# Multiple events are forwarded as received; they are not de-duplicated.
	backend.event_received.emit("movie.exited", {})
	_check(events.size() == 2, "second exit event forwarded")
	_check(completions.size() == 1, "exit event does not duplicate completion")

	# Distinct sessions still share latest-slot response ownership.
	var older: String = movie.request_play("film-older")
	var newer: String = movie.request_play("film-newer")
	_check(not older.is_empty() and not newer.is_empty() and older != newer, "overlapping launches have distinct IDs")
	_check(router.pending_route_count() == 1, "latest-slot owns one response")
	backend.reply(older, true, {"monitorable": true})
	_check(completions.size() == 1, "superseded launch response ignored")
	backend.event_received.emit("movie.exited", {})
	_check(events.size() == 3, "exit event independent of latest-slot")
	backend.reply(newer, false, null, {"message": "launch failed"})
	_check(completions.size() == 2 and not completions[1]["ok"], "newest failed reply reaches controller")

	# Disconnect retires replies, but event forwarding remains legacy-owned.
	var pending: String = movie.request_play("film-disconnect")
	backend.disconnected.emit(1006, "offline")
	backend.reply(pending, true, {"monitorable": true})
	_check(completions.size() == 2 and router.pending_route_count() == 0, "disconnect discards late reply")
	_check(legacy_replies == 0, "movie play never leaks to legacy response handler")

	if failures == 0 and checks == 16:
		print("MOVIE PLAY EVENT ORDER CONTRACT PASS: 16 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE PLAY EVENT ORDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
