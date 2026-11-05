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
		return "overlap-%d" % sequence
	func reply(id: String, ok: bool, data: Variant = null) -> void:
		response_received.emit(id, ok, data, null)
var checks: int = 0
var failures: int = 0
var completions: Array[Dictionary] = []
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
func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	var movie: Node = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	movie.play_completed.connect(_on_play)
	_check(not movie.has_active_playback_sessions(), "no active sessions initially")
	var a: String = movie.request_play("film-a")
	backend.reply(a, true, {"monitorable": true, "play_session_id": "a"})
	_check(movie.has_active_playback_sessions(), "first mpv reply owns rendering")
	_check(movie._active_play_sessions.size() == 1, "one known session")
	var b: String = movie.request_play("film-b")
	backend.reply(b, true, {"monitorable": true, "play_session_id": "b"})
	_check(movie._active_play_sessions.size() == 2, "overlapping mpv sessions tracked")
	movie.observe_playback_exit({"play_session_id": "a"})
	_check(movie.has_active_playback_sessions(), "first exit cannot release second")
	_check(movie._active_play_sessions.has("b"), "remaining session retained")
	movie.observe_playback_exit({"play_session_id": "a"})
	_check(movie._active_play_sessions.size() == 1, "duplicate exit idempotent")
	movie.observe_playback_exit({"play_session_id": "unknown"})
	_check(movie.has_active_playback_sessions(), "unknown exit cannot release known session")
	movie.observe_playback_exit({"play_session_id": "b"})
	_check(not movie.has_active_playback_sessions(), "last exit releases ownership")
	var early: String = movie.request_play("film-early")
	movie.observe_playback_exit({"play_session_id": "early"})
	backend.reply(early, true, {"monitorable": true, "play_session_id": "early"})
	_check(not movie.has_active_playback_sessions(), "early exit never creates active session")
	_check(bool(completions[-1]["data"].get("already_exited", false)), "early exit response still marked")
	var legacy: String = movie.request_play("film-legacy")
	backend.reply(legacy, true, {"monitorable": true})
	_check(not movie.has_active_playback_sessions(), "legacy no-ID reply not tracked")
	var default_player: String = movie.request_play("film-default")
	backend.reply(default_player, true, {"monitorable": false, "play_session_id": "fallback"})
	_check(not movie.has_active_playback_sessions(), "unmonitorable reply not tracked")
	var c: String = movie.request_play("film-c")
	backend.reply(c, true, {"monitorable": true, "play_session_id": "c"})
	var failure: String = movie.request_play("film-fail")
	backend.reply(failure, false, {})
	_check(movie._active_play_sessions.has("c"), "failed new launch does not clear existing session")
	movie.clear_playback_exit_history()
	_check(not movie.has_active_playback_sessions(), "disconnect reset clears active sessions")
	_check(movie._early_exited_sessions.is_empty(), "disconnect reset clears early exits")
	if failures == 0 and checks == 16:
		print("MOVIE PLAY OVERLAP CONTRACT PASS: 16 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE PLAY OVERLAP CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
