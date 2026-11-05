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
		var rid: String = "sgdb-%d" % serial
		sent[rid] = {"command": command, "payload": payload.duplicate(true)}
		return rid
	func reply(rid: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(rid, ok, data, error)

var checks: int = 0
var failures: int = 0
var searches: Array[Dictionary] = []
var assets: Array[Dictionary] = []
var applies: Array[Dictionary] = []
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

func on_search(ok: bool, data: Variant, error: Variant) -> void:
	searches.append({"ok": ok, "data": data, "error": error})
func on_assets(tag: String, ok: bool, data: Variant, error: Variant) -> void:
	assets.append({"tag": tag, "ok": ok, "data": data, "error": error})
func on_apply(tag: String, remaining: int, ok: bool, data: Variant, error: Variant) -> void:
	applies.append({"tag": tag, "remaining": remaining, "ok": ok, "data": data, "error": error})
func on_legacy(_rid: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	legacy += 1

func _run() -> void:
	var orphan: Node = GAME_SCRIPT.new()
	add_child(orphan)
	check(orphan.request_sgdb_search("a").is_empty(), "unconfigured search rejected")
	check(orphan.request_sgdb_assets(1, "grid").is_empty(), "unconfigured assets rejected")
	check(orphan.request_sgdb_apply("game", 1, "grid", "u").is_empty(), "unconfigured apply rejected")
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
	game.sgdb_search_completed.connect(on_search)
	game.sgdb_assets_completed.connect(on_assets)
	game.sgdb_apply_completed.connect(on_apply)
	var s1: String = game.request_sgdb_search("first")
	var s2: String = game.request_sgdb_search("second")
	check(s1 != s2 and not s1.is_empty(), "search IDs unique")
	check(backend.sent[s2].command == "sgdb.search", "search command")
	check(backend.sent[s2].payload.query == "second", "search query payload")
	backend.reply(s1, true, [])
	check(searches.is_empty(), "stale search retired")
	backend.reply(s2, true, [{"id": 5}])
	check(searches.size() == 1 and searches[0].ok, "new search delivered")
	backend.reply(s2, true, [])
	check(searches.size() == 1, "duplicate search retired")
	var a1: String = game.request_sgdb_assets(51, "grid")
	var a2: String = game.request_sgdb_assets(52, "hero")
	check(a1 != a2 and not a1.is_empty(), "assets concurrent IDs")
	check(backend.sent[a1].command == "sgdb.assets", "assets command")
	check(backend.sent[a1].payload.sgdb_id == 51, "assets SGDB ID")
	check(backend.sent[a2].payload.asset_type == "hero", "assets tag payload")
	backend.reply(a2, true, {"items": [1]})
	check(assets.size() == 1 and assets[0].tag == "hero", "second assets can finish first")
	backend.reply(a1, false, null, "err")
	check(assets.size() == 2 and assets[1].tag == "grid" and not assets[1].ok, "first assets failure bound to tag")
	backend.reply(a1, true, {})
	check(assets.size() == 2, "duplicate assets retired")
	var p1: String = game.request_sgdb_apply("game-A", 51, "grid", "url1")
	var p2: String = game.request_sgdb_apply("game-B", 52, "hero", "url2")
	check(p1 != p2 and not p1.is_empty(), "apply concurrent IDs")
	check(backend.sent[p1].command == "sgdb.apply", "apply command")
	check(backend.sent[p1].payload.id == "game-A", "first apply target bound")
	check(backend.sent[p2].payload.id == "game-B", "second apply target bound")
	check(backend.sent[p2].payload.sgdb_id == 52, "apply SGDB ID")
	check(backend.sent[p1].payload.asset_type == "grid", "apply asset type")
	check(backend.sent[p2].payload.url == "url2", "apply URL")
	backend.reply(p2, true, {})
	check(applies.size() == 1 and applies[0].tag == "hero", "out-of-order apply tag")
	check(applies[0].remaining == 1, "first completion leaves one pending")
	backend.reply(p1, true, {})
	check(applies.size() == 2 and applies[1].remaining == 0, "last completion reports zero pending")
	backend.reply(p1, true, {})
	check(applies.size() == 2, "duplicate apply retired")
	var p3: String = game.request_sgdb_apply("game-C", 53, "icon", "url3")
	backend.reply(p3, false, null, "error")
	check(applies.size() == 3 and not applies[2].ok, "failed apply delivered")
	check(applies[2].remaining == 0, "failed apply removed from pending")
	check(game.request_sgdb_apply("", 1, "grid", "u").is_empty(), "empty target rejected")
	backend.available = false
	check(game.request_sgdb_search("offline").is_empty(), "search send failure")
	check(game.request_sgdb_assets(1, "grid").is_empty(), "assets send failure")
	check(game.request_sgdb_apply("game", 1, "grid", "u").is_empty(), "apply send failure")
	backend.available = true
	var a3: String = game.request_sgdb_assets(54, "logo")
	var p4: String = game.request_sgdb_apply("game-D", 54, "logo", "u")
	backend.disconnected.emit(1000, "closed")
	game.clear_sgdb_pending()
	backend.reply(a3, true, {"items": []})
	backend.reply(p4, true, {})
	check(assets.size() == 2, "disconnect retires assets")
	check(applies.size() == 3, "disconnect retires applies")
	var p5: String = game.request_sgdb_apply("game-E", 55, "grid", "u")
	backend.reply(p5, true, {})
	check(applies.size() == 4 and applies[3].remaining == 0, "reconnect has clean pending count")
	check(legacy == 0, "routed responses do not leak to legacy")
	if failures == 0:
		print("GAME SGDB CONTRACT PASS: %d checks" % checks)
	else:
		print("GAME SGDB CONTRACT FAIL: %d/%d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
