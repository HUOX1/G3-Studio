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
		var request_id: String = "crud-%d" % next_id
		sent[request_id] = {"command": command, "payload": payload.duplicate(true)}
		return request_id
	func reply(request_id: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _launch: Array[Dictionary] = []
var _playtime: Array[Dictionary] = []
var _remove: Array[Dictionary] = []
var _create: Array[Dictionary] = []
var _paste: Array[Dictionary] = []
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

func _on_launch(ok: bool, data: Variant, error: Variant) -> void:
	_launch.append({"ok": ok, "data": data, "error": error})
func _on_playtime(ok: bool, data: Variant, error: Variant) -> void:
	_playtime.append({"ok": ok, "data": data, "error": error})
func _on_remove(ok: bool, data: Variant, error: Variant) -> void:
	_remove.append({"ok": ok, "data": data, "error": error})
func _on_create(ok: bool, data: Variant, error: Variant) -> void:
	_create.append({"ok": ok, "data": data, "error": error})
func _on_paste(ok: bool, data: Variant, error: Variant) -> void:
	_paste.append({"ok": ok, "data": data, "error": error})
func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var orphan: Node = GAME_SCRIPT.new()
	add_child(orphan)
	_check(orphan.request_launch_update({}).is_empty(), "unconfigured launch write rejected")
	_check(orphan.request_playtime("a", 10).is_empty(), "unconfigured playtime rejected")
	_check(orphan.request_remove("a").is_empty(), "unconfigured remove rejected")
	_check(orphan.request_create({}).is_empty(), "unconfigured create rejected")
	_check(orphan.request_paste_create({}).is_empty(), "unconfigured paste create rejected")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var game: Node = GAME_SCRIPT.new()
	add_child(game)
	game.configure(router)
	game.launch_update_completed.connect(_on_launch)
	game.playtime_completed.connect(_on_playtime)
	game.remove_completed.connect(_on_remove)
	game.create_completed.connect(_on_create)
	game.paste_create_completed.connect(_on_paste)
	_check(game.request_remove("").is_empty(), "empty single-delete target rejected")
	var launch_payload: Dictionary = {"id": "l", "profile": {"args": "old"}}
	var launch_id: String = game.request_launch_update(launch_payload)
	launch_payload["profile"]["args"] = "new"
	_check(backend.sent[launch_id]["command"] == "game.launch_profile.update", "launch update command")
	_check(backend.sent[launch_id]["payload"]["profile"]["args"] == "old", "launch payload deep copied")
	var time_id: String = game.request_playtime("t", 120)
	_check(backend.sent[time_id]["command"] == "game.playtime.set", "playtime command")
	_check(backend.sent[time_id]["payload"] == {"id": "t", "seconds": 120}, "playtime seconds payload")
	var remove_id: String = game.request_remove("r")
	_check(backend.sent[remove_id]["command"] == "game.remove", "single remove command")
	_check(backend.sent[remove_id]["payload"] == {"id": "r"}, "single remove target")
	var manual_payload: Dictionary = {"title": "original"}
	var create_id: String = game.request_create(manual_payload)
	manual_payload["title"] = "mutated"
	_check(backend.sent[create_id]["command"] == "game.create", "manual create command")
	_check(backend.sent[create_id]["payload"]["title"] == "original", "manual create payload copied")
	var paste_id: String = game.request_paste_create({"title": "paste"})
	_check(backend.sent[paste_id]["command"] == "game.create", "paste create command")
	_check(backend.sent[paste_id]["payload"] == {"title": "paste"}, "paste create payload")
	_check(router.pending_route_count() == 5, "five independent request contexts coexist")
	backend.reply(paste_id, true, {"id": "p"})
	_check(_paste.size() == 1 and _paste[0]["ok"], "paste create success isolated")
	backend.reply(create_id, false, null, {"message": "bad"})
	_check(_create.size() == 1 and not _create[0]["ok"], "manual create failure isolated")
	backend.reply(remove_id, true, {})
	_check(_remove.size() == 1 and _remove[0]["ok"], "single remove success delivered")
	backend.reply(time_id, false, null, {"message": "no"})
	_check(_playtime.size() == 1 and not _playtime[0]["ok"], "playtime failure delivered")
	backend.reply(launch_id, true, {})
	_check(_launch.size() == 1 and _launch[0]["ok"], "launch update success delivered")
	backend.reply(create_id, true, {})
	_check(_create.size() == 1, "duplicate manual create response ignored")
	var stale: String = game.request_remove("old")
	var latest: String = game.request_remove("new")
	_check(router.pending_route_count() == 1, "single remove latest supersedes old")
	backend.reply(stale, true, {})
	_check(_remove.size() == 1, "superseded remove ignored")
	backend.reply(latest, false, null, {"message": "denied"})
	_check(_remove.size() == 2 and not _remove[1]["ok"], "latest remove failure delivered")
	var manual2: String = game.request_create({"title": "manual2"})
	var paste2: String = game.request_paste_create({"title": "paste2"})
	var manual3: String = game.request_create({"title": "manual3"})
	backend.reply(manual2, true, {})
	_check(_create.size() == 1, "manual create supersession ignored")
	backend.reply(paste2, true, {})
	_check(_paste.size() == 2, "paste create unaffected by manual supersession")
	backend.reply(manual3, true, {})
	_check(_create.size() == 2, "latest manual create delivered")
	var disconnect_id: String = game.request_playtime("x", 3)
	backend.disconnected.emit(1006, "lost")
	backend.reply(disconnect_id, true, {})
	_check(_playtime.size() == 1, "disconnect retires playtime response")
	_check(router.pending_route_count() == 0, "disconnect clears outstanding routes")
	backend.available = false
	_check(game.request_create({"title": "x"}).is_empty(), "backend send failure returns empty ID")
	_check(_legacy == 0, "migrated replies never leak into legacy")
	if _failures == 0:
		print("GAME CRUD CONTRACT PASS: %d checks" % _checks)
	else:
		print("GAME CRUD CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
