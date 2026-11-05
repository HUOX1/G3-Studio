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
	var available: bool = true
	var counter: int = 0
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		counter += 1
		var id: String = "play-%d" % counter
		sent[id] = {"command": command, "payload": payload.duplicate(true)}
		return id
	func reply(id: String, ok: bool, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(id, ok, data, error)

var checks: int = 0
var failures: int = 0
var legacy_responses: int = 0
var legacy_events: Array[String] = []
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

func _on_legacy_response(_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	legacy_responses += 1

func _on_legacy_event(name: String, _payload: Dictionary) -> void:
	legacy_events.append(name)

func _on_play(ok: bool, data: Variant, error: Variant) -> void:
	completions.append({"ok": ok, "data": data, "error": error})

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy_response)
	router.legacy_event_received.connect(_on_legacy_event)
	var movie: Node = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	movie.play_completed.connect(_on_play)

	var first: String = movie.request_play("movie-1")
	_check(not first.is_empty(), "movie play request sent")
	_check(backend.sent[first]["command"] == "movie.play", "movie play command preserved")
	_check(backend.sent[first]["payload"] == {"id": "movie-1"}, "movie payload excludes episode ID")
	var second: String = movie.request_play("series-2", "episode-3")
	_check(not second.is_empty() and first != second, "episode play has distinct ID")
	_check(backend.sent[second]["payload"] == {"id": "series-2", "episode_id": "episode-3"}, "episode payload preserved")
	_check(router.pending_route_count() == 1, "movie and episode share latest slot")
	backend.reply(first, true, {"monitorable": true})
	_check(completions.is_empty(), "superseded movie response ignored")
	backend.reply(second, true, {"monitorable": true})
	_check(completions.size() == 1 and completions[0]["ok"], "latest episode response delivered")
	_check(completions[0]["data"] == {"monitorable": true}, "monitorable flag preserved")
	backend.reply(second, true, {})
	_check(completions.size() == 1, "duplicate play reply ignored")
	backend.event_received.emit("movie.exited", {})
	_check(legacy_events == ["movie.exited"], "movie exit event still reaches legacy owner once")
	var unmonitored: String = movie.request_play("movie-4")
	backend.reply(unmonitored, true, {"monitorable": false})
	_check(completions.size() == 2 and completions[1]["data"] == {"monitorable": false}, "unmonitorable launch flag preserved")
	var failed: String = movie.request_play("movie-5")
	backend.reply(failed, false, null, {"message": "missing file"})
	_check(completions.size() == 3 and not completions[2]["ok"], "failed launch reported")
	_check(completions[2]["error"] == {"message": "missing file"}, "launch error preserved")
	_check(movie.request_play("").is_empty(), "empty movie ID rejected")
	_check(router.pending_route_count() == 0, "completed requests release routes")
	var stale: String = movie.request_play("movie-stale")
	backend.available = false
	_check(movie.request_play("movie-not-sent").is_empty(), "failed send returns empty ID")
	backend.reply(stale, true, {})
	_check(completions.size() == 3, "failed replacement retires stale reply")
	backend.available = true
	var pending: String = movie.request_play("movie-disconnect")
	backend.disconnected.emit(1006, "offline")
	backend.reply(pending, true, {})
	_check(completions.size() == 3 and router.pending_route_count() == 0, "disconnect retires pending play")
	_check(legacy_responses == 0, "migrated play responses never reach legacy")

	if failures == 0 and checks == 20:
		print("MOVIE PLAY CONTRACT PASS: 20 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE PLAY CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
