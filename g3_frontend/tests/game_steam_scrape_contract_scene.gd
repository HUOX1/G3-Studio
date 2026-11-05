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
	var serial: int = 0
	var available: bool = true
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		serial += 1
		var rid: String = "steam-%d" % serial
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var checks: int = 0
var failures: int = 0
var manual_search: Array[Dictionary] = []
var manual_apply: Array[Dictionary] = []
var batch_search: Array[Dictionary] = []
var batch_apply: Array[Dictionary] = []
var legacy: int = 0

func _ready() -> void:
	call_deferred("_run")

func check(value: bool, name: String) -> void:
	checks += 1
	if value:
		print("[PASS] ", name)
	else:
		failures += 1
		push_error("[FAIL] " + name)

func on_manual_search(ok: bool, data: Variant, error: Variant) -> void:
	manual_search.append({"ok": ok, "data": data, "error": error})
func on_manual_apply(ok: bool, data: Variant, error: Variant) -> void:
	manual_apply.append({"ok": ok, "data": data, "error": error})
func on_batch_search(generation: int, item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	batch_search.append({"generation": generation, "item_id": item_id, "ok": ok, "data": data, "error": error})
func on_batch_apply(generation: int, item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	batch_apply.append({"generation": generation, "item_id": item_id, "ok": ok, "data": data, "error": error})
func on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	legacy += 1

func _run() -> void:
	var orphan: Node = GAME_SCRIPT.new()
	add_child(orphan)
	check(orphan.request_steam_manual_search("a").is_empty(), "unconfigured manual search rejected")
	check(orphan.request_steam_manual_apply("a", 1).is_empty(), "unconfigured manual apply rejected")
	check(orphan.request_steam_batch_search("a", "id", 1).is_empty(), "unconfigured batch search rejected")
	check(orphan.request_steam_batch_apply("id", 1, 1).is_empty(), "unconfigured batch apply rejected")
	orphan.queue_free()
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(on_legacy)
	var game: Node = GAME_SCRIPT.new()
	add_child(game)
	game.configure(router)
	game.steam_manual_search_completed.connect(on_manual_search)
	game.steam_manual_apply_completed.connect(on_manual_apply)
	game.steam_batch_search_completed.connect(on_batch_search)
	game.steam_batch_apply_completed.connect(on_batch_apply)
	check(game.request_steam_manual_apply("", 2).is_empty(), "empty manual item rejected")
	check(game.request_steam_batch_search("x", "", 1).is_empty(), "empty batch search item rejected")
	check(game.request_steam_batch_apply("", 2, 1).is_empty(), "empty batch apply item rejected")
	var ms1: String = game.request_steam_manual_search("first")
	var bs1: String = game.request_steam_batch_search("batch title", "batch-A", 5)
	var ma1: String = game.request_steam_manual_apply("manual-A", 33)
	var ba1: String = game.request_steam_batch_apply("batch-A", 44, 5)
	check(backend.sent[ms1].command == "game.scrape.search", "manual search command")
	check(backend.sent[ms1].payload.query == "first", "manual search query")
	check(backend.sent[bs1].payload.query == "batch title", "batch search query")
	check(backend.sent[ma1].command == "game.scrape.apply", "manual apply command")
	check(backend.sent[ma1].payload.id == "manual-A", "manual apply target")
	check(backend.sent[ma1].payload.source == "steam", "manual apply source")
	check(backend.sent[ma1].payload.external_id == 33, "manual apply external ID")
	check(backend.sent[ba1].payload.id == "batch-A", "batch apply target")
	check(backend.sent[ba1].payload.external_id == 44, "batch apply external ID")
	backend.reply(bs1, true, [{"external_id": 44}])
	check(batch_search.size() == 1, "batch search delivered independently")
	check(batch_search[0].generation == 5 and batch_search[0].item_id == "batch-A", "batch search binds generation and target")
	backend.reply(ma1, false, null, {"message": "fail"})
	check(manual_apply.size() == 1 and not manual_apply[0].ok, "manual apply failure independent")
	backend.reply(ba1, true, {})
	check(batch_apply.size() == 1 and batch_apply[0].generation == 5, "batch apply generation preserved")
	check(batch_apply[0].item_id == "batch-A", "batch apply binds target item")
	backend.reply(ms1, true, [{"external_id": 11}])
	check(manual_search.size() == 1, "manual search delivered independently")
	var ms2: String = game.request_steam_manual_search("old")
	var ms3: String = game.request_steam_manual_search("new")
	backend.reply(ms2, true, [])
	check(manual_search.size() == 1, "superseded manual search ignored")
	backend.reply(ms3, true, [])
	check(manual_search.size() == 2, "new manual search accepted")
	backend.reply(ms3, true, [])
	check(manual_search.size() == 2, "duplicate manual response ignored")
	var bs2: String = game.request_steam_batch_search("old batch", "old", 6)
	var bs3: String = game.request_steam_batch_search("new batch", "new", 7)
	backend.reply(bs2, true, [])
	check(batch_search.size() == 1, "superseded batch search ignored")
	backend.reply(bs3, false, null, "err")
	check(batch_search.size() == 2 and batch_search[1].generation == 7 and batch_search[1].item_id == "new", "new batch identity preserved")
	var ma2: String = game.request_steam_manual_apply("m", 5)
	var ma3: String = game.request_steam_manual_apply("m", 6)
	backend.reply(ma2, true, {})
	check(manual_apply.size() == 1, "superseded manual apply ignored")
	backend.reply(ma3, true, {})
	check(manual_apply.size() == 2, "new manual apply accepted")
	var ba2: String = game.request_steam_batch_apply("b", 5, 8)
	var ba3: String = game.request_steam_batch_apply("b", 6, 9)
	backend.reply(ba2, true, {})
	check(batch_apply.size() == 1, "superseded batch apply ignored")
	backend.reply(ba3, true, {})
	check(batch_apply.size() == 2 and batch_apply[1].generation == 9, "new batch apply accepted")
	check(batch_apply[1].item_id == "b", "superseded apply keeps newest target")
	backend.available = false
	check(game.request_steam_manual_search("offline").is_empty(), "manual send failure")
	check(game.request_steam_batch_apply("b", 1, 9).is_empty(), "batch send failure")
	backend.available = true
	var in_flight: String = game.request_steam_batch_search("disconnect", "b", 10)
	backend.disconnected.emit(1000, "closed")
	backend.reply(in_flight, true, [])
	check(batch_search.size() == 2, "disconnect retires batch response")
	check(legacy == 0, "no routed responses leak to legacy")
	if failures == 0:
		print("GAME STEAM SCRAPE CONTRACT PASS: %d checks" % checks)
	else:
		print("GAME STEAM SCRAPE CONTRACT FAIL: %d/%d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
