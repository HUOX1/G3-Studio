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
		var request_id: String = "meta-%d" % next_id
		sent[request_id] = {"command": command, "payload": payload.duplicate(true)}
		return request_id
	func reply(request_id: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _meta: Array[Dictionary] = []
var _launch: Array[Dictionary] = []
var _writes: Array[Dictionary] = []
var _pastes: Array[Dictionary] = []
var _legacy: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		_failures += 1
		push_error("[FAIL] " + label)

func _on_meta(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_meta.append({"item_id": item_id, "ok": ok, "data": data, "error": error})
func _on_launch(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_launch.append({"item_id": item_id, "ok": ok, "data": data, "error": error})
func _on_write(ok: bool, data: Variant, error: Variant) -> void:
	_writes.append({"ok": ok, "data": data, "error": error})
func _on_paste(ok: bool, data: Variant, error: Variant) -> void:
	_pastes.append({"ok": ok, "data": data, "error": error})
func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var unconfigured: Node = GAME_SCRIPT.new()
	add_child(unconfigured)
	_check(unconfigured.request_metadata("a").is_empty(), "unconfigured read rejected")
	_check(unconfigured.request_launch_metadata("a").is_empty(), "unconfigured launch read rejected")
	_check(unconfigured.request_metadata_update({}).is_empty(), "unconfigured write rejected")
	_check(unconfigured.request_paste_update({}).is_empty(), "unconfigured paste rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var game: Node = GAME_SCRIPT.new()
	add_child(game)
	game.configure(router)
	game.metadata_completed.connect(_on_meta)
	game.launch_metadata_completed.connect(_on_launch)
	game.metadata_update_completed.connect(_on_write)
	game.paste_update_completed.connect(_on_paste)
	_check(game.request_metadata("").is_empty(), "empty metadata target rejected")
	_check(game.request_launch_metadata("").is_empty(), "empty launch target rejected")
	var first: String = game.request_metadata("a")
	var launch: String = game.request_launch_metadata("b")
	_check(first != launch and not first.is_empty(), "read intents use distinct request IDs")
	_check(backend.sent[first]["command"] == "game.metadata.get", "metadata read command")
	_check(backend.sent[launch]["command"] == "game.metadata.get", "launch read command")
	_check(backend.sent[first]["payload"] == {"id": "a"}, "metadata target payload")
	_check(backend.sent[launch]["payload"] == {"id": "b"}, "launch target payload")
	_check(router.pending_route_count() == 2, "independent read routes coexist")
	var second: String = game.request_metadata("c")
	_check(router.pending_route_count() == 2, "metadata latest only supersedes metadata")
	backend.reply(first, true, {"old": true})
	_check(_meta.is_empty(), "superseded metadata ignored")
	backend.reply(launch, true, {"title": "B"})
	_check(_launch.size() == 1 and _launch[0]["item_id"] == "b", "launch target bound to request")
	backend.reply(second, true, {"title": "C"})
	_check(_meta.size() == 1 and _meta[0]["item_id"] == "c", "metadata target bound to latest request")
	backend.reply(second, true, {})
	_check(_meta.size() == 1, "duplicate metadata reply ignored")
	var payload: Dictionary = {"id": "d", "title": "before"}
	var write: String = game.request_metadata_update(payload)
	payload["title"] = "after"
	_check(backend.sent[write]["payload"]["title"] == "before", "write payload deep copied")
	var paste: String = game.request_paste_update({"id": "e"})
	_check(backend.sent[write]["command"] == "game.metadata.update", "write command")
	_check(backend.sent[paste]["command"] == "game.metadata.update", "paste command")
	_check(router.pending_route_count() == 2, "separate write intents coexist")
	backend.reply(paste, false, null, {"message": "bad paste"})
	_check(_pastes.size() == 1 and not _pastes[0]["ok"], "paste failure routed separately")
	backend.reply(write, true, {"saved": true})
	_check(_writes.size() == 1 and _writes[0]["ok"], "metadata success routed separately")
	var stale: String = game.request_paste_update({"id": "f"})
	var fresh: String = game.request_paste_update({"id": "g"})
	backend.reply(stale, true, {})
	_check(_pastes.size() == 1, "superseded paste ignored")
	backend.reply(fresh, true, {})
	_check(_pastes.size() == 2 and _pastes[1]["ok"], "latest paste delivered")
	var disconnected: String = game.request_metadata("z")
	backend.disconnected.emit(1006, "lost")
	backend.reply(disconnected, true, {})
	_check(_meta.size() == 1, "disconnect retires metadata route")
	_check(router.pending_route_count() == 0, "disconnect empties pending routes")
	backend.available = false
	_check(game.request_metadata_update({"id": "x"}).is_empty(), "failed send returns empty ID")
	_check(_legacy == 0, "all migrated replies bypass legacy")
	if _failures == 0:
		print("GAME METADATA CONTRACT PASS: %d checks" % _checks)
	else:
		print("GAME METADATA CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
