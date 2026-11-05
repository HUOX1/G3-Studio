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
		var rid: String = "batch-%d" % next_id
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _legacy: int = 0
var _single_completions: int = 0
func _ready() -> void:
	call_deferred("_run")
func _check(value: bool, label: String) -> void:
	_checks += 1
	if value:
		print("[PASS] ", label)
	else:
		_failures += 1
		push_error("[FAIL] " + label)
func _on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1
func _on_single(_ok: bool, _data: Variant, _error: Variant) -> void:
	_single_completions += 1
func _run() -> void:
	var orphan: Node = GAME_SCRIPT.new()
	add_child(orphan)
	_check(orphan.request_batch_remove("a").is_empty(), "unconfigured controller rejects batch remove")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var game: Node = GAME_SCRIPT.new()
	add_child(game)
	game.configure(router)
	game.remove_completed.connect(_on_single)
	_check(game.request_batch_remove("").is_empty(), "empty ID rejected")
	var a: String = game.request_batch_remove("game-a")
	var b: String = game.request_batch_remove("game-b")
	_check(not a.is_empty() and not b.is_empty() and a != b, "two independent batch requests accepted")
	_check(backend.sent[a]["command"] == "game.remove", "first command is game.remove")
	_check(backend.sent[a]["payload"] == {"id": "game-a"}, "first ID preserved")
	_check(backend.sent[b]["payload"] == {"id": "game-b"}, "second ID preserved")
	_check(router.pending_route_count() == 2, "two routes remain pending")
	backend.reply(b, false, null, {"message": "failure"})
	_check(router.pending_route_count() == 1, "failed batch reply retires only its route")
	_check(_single_completions == 0, "batch failure does not trigger single-delete UI")
	backend.reply(a, true, {})
	_check(router.pending_route_count() == 0, "successful batch reply retires route")
	backend.reply(a, true, {})
	_check(_single_completions == 0, "duplicate reply does not trigger UI")
	_check(_legacy == 0, "batch replies never leak into legacy handler")
	var stale: String = game.request_batch_remove("game-c")
	backend.disconnected.emit(1006, "lost")
	_check(router.pending_route_count() == 0, "disconnect retires batch route")
	backend.reply(stale, true, {})
	_check(_legacy == 0, "late disconnected reply ignored")
	backend.available = false
	_check(game.request_batch_remove("game-d").is_empty(), "failed send returns empty ID")
	_check(router.pending_route_count() == 0, "failed send creates no route")
	if _failures == 0:
		print("GAME BATCH REMOVE CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("GAME BATCH REMOVE CONTRACT FAIL: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
