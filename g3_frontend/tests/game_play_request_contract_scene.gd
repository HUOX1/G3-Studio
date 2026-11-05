extends Node

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const GAME_SCRIPT: Script = preload("res://scripts/game_controller.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	@warning_ignore("unused_signal")
	signal event_received(event_type: String, payload: Dictionary)
	@warning_ignore("unused_signal")
	signal disconnected(code: int, reason: String)
	var next_id: int = 0
	var available: bool = true
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		next_id += 1
		var rid: String = "play-%d" % next_id
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _results: Array[Dictionary] = []
var _legacy: int = 0
func _ready() -> void:
	call_deferred("_run")
func _check(value: bool, label: String) -> void:
	_checks += 1
	if value:
		print("[PASS] ", label)
	else:
		_failures += 1
		push_error("[FAIL] " + label)
func _on_play(ok: bool, data: Variant, error: Variant) -> void:
	_results.append({"ok": ok, "data": data, "error": error})
func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1
func _run() -> void:
	var orphan: Node = GAME_SCRIPT.new()
	add_child(orphan)
	_check(orphan.request_play("a").is_empty(), "unconfigured controller rejects play")
	_check(not orphan.has_pending_play(), "unconfigured controller has no pending play")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var game: Node = GAME_SCRIPT.new()
	add_child(game)
	game.configure(router)
	game.play_completed.connect(_on_play)
	_check(game.request_play("").is_empty(), "empty game ID rejected")
	var first: String = game.request_play("game-a")
	_check(not first.is_empty(), "first play request accepted")
	_check(backend.sent[first]["command"] == "game.play", "play command correct")
	_check(backend.sent[first]["payload"] == {"id": "game-a"}, "game ID forwarded")
	_check(game.has_pending_play(), "pending state set")
	_check(game.request_play("game-b").is_empty(), "concurrent play rejected")
	_check(backend.sent.size() == 1, "no second backend launch sent")
	_check(router.pending_route_count() == 1, "exactly one pending route")
	backend.reply(first, true, {"monitorable": true, "play_session_id": "game-session-1"})
	_check(_results.size() == 1 and _results[0]["ok"], "success callback delivered")
	_check(_results[0]["data"].get("monitorable", false), "monitorable data preserved")
	_check(_results[0]["data"].get("play_session_id", "") == "game-session-1", "game session ID preserved")
	_check(not game.has_pending_play(), "success releases pending slot")
	backend.reply(first, false, null, {"message": "duplicate"})
	_check(_results.size() == 1, "duplicate reply ignored")
	_check(_results[0]["data"].get("play_session_id", "") == "game-session-1", "duplicate cannot replace game session ID")
	var second: String = game.request_play("game-b")
	_check(not second.is_empty() and second != first, "next launch accepted after reply")
	backend.reply(second, false, null, {"message": "bad"})
	_check(_results.size() == 2 and not _results[1]["ok"], "failure callback delivered")
	_check(_results[1]["error"].get("message", "") == "bad", "failure details preserved")
	_check(not game.has_pending_play(), "failure releases pending slot")
	var third: String = game.request_play("launcher")
	backend.reply(third, true, {"monitorable": false, "play_session_id": "unmonitorable-session"})
	_check(_results.size() == 3 and not _results[2]["data"].get("monitorable", true), "unmonitorable launcher data delivered")
	_check(_results[2]["data"].get("play_session_id", "") == "unmonitorable-session", "unmonitorable session ID preserved")
	var stale: String = game.request_play("disconnected")
	backend.disconnected.emit(1006, "lost")
	game.clear_pending_play()
	_check(not game.has_pending_play(), "disconnect clears pending slot")
	_check(router.pending_route_count() == 0, "router retires disconnect route")
	backend.reply(stale, true, {})
	_check(_results.size() == 3, "late reply after disconnect ignored")
	_check(_results[0]["data"].get("play_session_id", "") == "game-session-1", "disconnect does not mutate completed session")
	backend.available = false
	_check(game.request_play("send-fails").is_empty(), "backend send failure rejected")
	_check(not game.has_pending_play(), "failed send does not lock slot")
	_check(_legacy == 0, "routed replies do not leak to legacy")
	if _failures == 0:
		print("GAME PLAY REQUEST CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("GAME PLAY REQUEST CONTRACT FAIL: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
