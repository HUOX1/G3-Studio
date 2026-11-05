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
	func request(_command: String, _payload: Dictionary) -> String:
		sequence += 1
		return "session-%d" % sequence
	func reply(id: String, ok: bool, data: Variant = null) -> void:
		response_received.emit(id, ok, data, null)
var checks: int = 0
var failures: int = 0
var completions: Array[Dictionary] = []
var event_count: int = 0
var movie: Node = null
func _ready() -> void:
	call_deferred("_run")
func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", name)
	else:
		failures += 1
		push_error("[FAIL] " + name)
func _on_play(ok: bool, data: Variant, _error: Variant) -> void:
	completions.append({"ok": ok, "data": data})
func _on_event(name: String, payload: Dictionary) -> void:
	if name == "movie.exited":
		event_count += 1
		movie.observe_playback_exit(payload)
func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	movie = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	movie.play_completed.connect(_on_play)
	router.legacy_event_received.connect(_on_event)
	var first: String = movie.request_play("film-a")
	backend.event_received.emit("movie.exited", {"play_session_id": "play-a"})
	_check(event_count == 1, "early exit forwarded")
	_check(completions.is_empty(), "exit does not fake reply")
	backend.reply(first, true, {"monitorable": true, "play_session_id": "play-a"})
	_check(completions.size() == 1, "late reply delivered")
	_check(bool(completions[0]["data"].get("already_exited", false)), "matched reply marked exited")
	_check(bool(completions[0]["data"].get("monitorable", false)), "monitorable retained")
	var second: String = movie.request_play("film-b")
	backend.reply(second, true, {"monitorable": true, "play_session_id": "play-b"})
	_check(completions.size() == 2 and not completions[1]["data"].has("already_exited"), "unrelated session not suppressed")
	var legacy: String = movie.request_play("film-legacy")
	backend.event_received.emit("movie.exited", {})
	backend.reply(legacy, true, {"monitorable": true})
	_check(completions.size() == 3 and completions[2]["data"] == {"monitorable": true}, "legacy event unchanged")
	var stale: String = movie.request_play("film-stale")
	var latest: String = movie.request_play("film-latest")
	backend.event_received.emit("movie.exited", {"play_session_id": "play-stale"})
	backend.reply(stale, true, {"monitorable": true, "play_session_id": "play-stale"})
	_check(completions.size() == 3, "superseded reply ignored")
	backend.reply(latest, true, {"monitorable": true, "play_session_id": "play-latest"})
	_check(completions.size() == 4 and not completions[3]["data"].has("already_exited"), "stale exit does not affect newest")
	movie.clear_playback_exit_history()
	var after_clear: String = movie.request_play("film-after-clear")
	backend.reply(after_clear, true, {"monitorable": true, "play_session_id": "play-a"})
	_check(completions.size() == 5 and not completions[4]["data"].has("already_exited"), "exit cache cleared")
	for index in range(70):
		movie.observe_playback_exit({"play_session_id": "bounded-%d" % index})
	_check(movie._early_exit_order.size() == 64, "exit cache bounded")
	_check(not movie._early_exited_sessions.has("bounded-0"), "oldest entry evicted")
	_check(movie._early_exited_sessions.has("bounded-69"), "newest entry retained")
	var failed: String = movie.request_play("film-error")
	backend.reply(failed, false, {"play_session_id": "bounded-69"})
	_check(completions.size() == 6 and not completions[5]["data"].has("already_exited"), "failed reply unmarked")
	if failures == 0 and checks == 14:
		print("MOVIE PLAY SESSION ORDER CONTRACT PASS: 14 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE PLAY SESSION ORDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
