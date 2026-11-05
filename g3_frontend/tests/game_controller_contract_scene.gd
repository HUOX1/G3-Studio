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
		var request_id: String = "game-%d" % next_id
		sent[request_id] = {"command": command, "payload": payload.duplicate(true)}
		return request_id
	func reply(request_id: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

var _checks: int = 0
var _failures: int = 0
var _results: Array[Dictionary] = []
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

func _on_result(ok: bool, data: Variant, error: Variant) -> void:
	_results.append({"ok": ok, "data": data, "error": error})

func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var game_unconfigured: Node = GAME_SCRIPT.new()
	add_child(game_unconfigured)
	_check(game_unconfigured.request_list().is_empty(), "unconfigured controller rejects list")
	_check(game_unconfigured.resolve_manage_action("remove", {}).is_empty(), "empty game target ignored")
	_check(game_unconfigured.resolve_manage_action("remove", {"title": "No ID"}).is_empty(), "game target without ID ignored")
	var sgdb_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"scrape_sgdb", {"id": "g-1", "english_name": "  English Title  ", "title": "Local Title"}
	)
	_check(
		str(sgdb_plan.get("kind", "")) == "scrape_sgdb" and str(sgdb_plan.get("item_id", "")) == "g-1" and str(sgdb_plan.get("query", "")) == "English Title",
		"SGDB action resolves trimmed English query"
	)
	var sgdb_fallback: Dictionary = game_unconfigured.resolve_manage_action(
		"scrape_sgdb", {"id": "g-2", "english_name": "  ", "title": "Local Title"}
	)
	_check(str(sgdb_fallback.get("query", "")) == "Local Title", "SGDB action falls back to local title")
	var steam_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"steam_metadata", {"id": "g-3", "english_name": "  Steam Name  ", "title": "Local Title"}
	)
	_check(
		str(steam_plan.get("kind", "")) == "steam_metadata" and str(steam_plan.get("item_id", "")) == "g-3" and str(steam_plan.get("query", "")) == "Steam Name",
		"Steam action resolves trimmed English query"
	)
	var steam_fallback: Dictionary = game_unconfigured.resolve_manage_action(
		"steam_metadata", {"id": "g-4", "english_name": "", "title": "Local Title"}
	)
	_check(str(steam_fallback.get("query", "")) == "Local Title", "Steam action falls back to local title")
	var metadata_plan: Dictionary = game_unconfigured.resolve_manage_action("edit_metadata", {"id": "g-5"})
	_check(str(metadata_plan.get("kind", "")) == "edit_metadata" and str(metadata_plan.get("item_id", "")) == "g-5", "metadata action resolves target")
	var paste_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"paste_import", {"id": "g-6", "title": "Paste Target"}
	)
	_check(str(paste_plan.get("kind", "")) == "paste_import" and str(paste_plan.get("item_id", "")) == "g-6", "paste action resolves target")
	var game_dir_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"browse_game_dir", {"id": "g-7", "launch_exe": "C:/Games/Alpha/game.exe", "source_path": "D:/Fallback/alpha.iso"}
	)
	_check(str(game_dir_plan.get("path", "")) == "C:/Games/Alpha", "game directory prefers launch executable directory")
	var source_dir_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"browse_game_dir", {"id": "g-8", "launch_exe": "  ", "source_path": "C:/ROMs/Alpha.iso"}
	)
	_check(str(source_dir_plan.get("path", "")) == "C:/ROMs", "game directory falls back to source path")
	var assets_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"browse_assets_dir", {"id": "g-9", "cover_dir": "  C:/Games/Alpha/covers  "}
	)
	_check(str(assets_plan.get("path", "")) == "C:/Games/Alpha/covers", "assets directory is trimmed")
	var launch_plan: Dictionary = game_unconfigured.resolve_manage_action("edit_launch", {"id": "g-10"})
	_check(str(launch_plan.get("kind", "")) == "edit_launch" and str(launch_plan.get("item_id", "")) == "g-10", "launch edit resolves target")
	var playtime_plan: Dictionary = game_unconfigured.resolve_manage_action(
		"edit_playtime", {"id": "g-11", "playtime_seconds": "3600"}
	)
	_check(str(playtime_plan.get("kind", "")) == "edit_playtime" and int(playtime_plan.get("playtime_seconds", 0)) == 3600, "playtime edit resolves stored seconds")
	var remove_plan: Dictionary = game_unconfigured.resolve_manage_action("remove", {"id": "g-12"})
	_check(str(remove_plan.get("kind", "")) == "remove" and str(remove_plan.get("title", "")) == "Untitled", "remove action retains title fallback")
	_check(game_unconfigured.resolve_manage_action("unknown", {"id": "g-13"}).is_empty(), "unknown game action ignored")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("_game_controller.resolve_manage_action(action, _game_menu_target)"), "main delegates game menu resolution")
	_check(not main_source.contains("var sgdb_query: String"), "main no longer resolves SGDB query inline")
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var game: Node = GAME_SCRIPT.new()
	add_child(game)
	game.configure(router)
	game.list_completed.connect(_on_result)
	_check(not game.has_pending_remove_target(), "remove target starts empty")
	_check(game.request_pending_remove().is_empty(), "pending remove rejects missing target")
	game.set_pending_remove_target("g-confirm")
	_check(game.has_pending_remove_target(), "remove confirmation target staged")
	var pending_remove_id: String = game.request_pending_remove()
	var pending_remove_sent: bool = not pending_remove_id.is_empty() and backend.sent.has(pending_remove_id)
	_check(pending_remove_sent, "pending remove request sent")
	_check(pending_remove_sent and backend.sent[pending_remove_id]["command"] == "game.remove" and backend.sent[pending_remove_id]["payload"] == {"id": "g-confirm"}, "pending remove uses staged game ID")
	if pending_remove_sent:
		backend.reply(pending_remove_id, true, {})
	_check(pending_remove_sent and not game.has_pending_remove_target(), "remove target cleared after response")

	var first: String = game.request_list()
	_check(not first.is_empty(), "list sends request")
	_check(str(backend.sent[first]["command"]) == "library.games.list", "game list command preserved")
	_check(backend.sent[first]["payload"] == {}, "game list payload remains empty")
	var second: String = game.request_list()
	_check(second != first and not second.is_empty(), "new request has distinct ID")
	_check(router.pending_route_count() == 1, "latest slot replaces previous request")
	backend.reply(first, true, [{"id": "old"}])
	_check(_results.is_empty(), "superseded reply ignored")
	backend.reply(second, true, [{"id": "new"}])
	_check(_results.size() == 1 and bool(_results[0]["ok"]), "newest success forwarded")
	_check(_results.size() == 1 and _results[0]["data"] is Array, "array response retained")
	_check(str((_results[0]["data"] as Array)[0].get("id", "")) == "new", "newest snapshot retained")
	backend.reply(second, true, [])
	_check(_results.size() == 1, "duplicate response ignored")
	_check(router.pending_route_count() == 0, "successful route retired")

	var third: String = game.request_list()
	backend.reply(third, false, null, {"message": "offline"})
	_check(_results.size() == 2 and not bool(_results[1]["ok"]), "failed reply forwarded")
	_check(str((_results[1]["error"] as Dictionary).get("message", "")) == "offline", "error payload retained")
	var fourth: String = game.request_list()
	backend.reply(fourth, true, {"invalid": true})
	_check(_results.size() == 3 and _results[2]["data"] is Dictionary, "malformed payload left to UI owner")

	var old_id: String = game.request_list()
	backend.available = false
	_check(game.request_list().is_empty(), "failed send returns empty ID")
	_check(router.pending_route_count() == 0, "failed replacement invalidates old route")
	backend.reply(old_id, true, [])
	_check(_results.size() == 3, "old reply after failed replacement ignored")
	backend.available = true
	var disconnected_id: String = game.request_list()
	backend.disconnected.emit(1006, "lost")
	backend.reply(disconnected_id, true, [])
	_check(_results.size() == 3, "late response after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears route")
	_check(_legacy == 0, "migrated game responses never reach legacy")
	if _failures == 0:
		print("GAME CONTROLLER CONTRACT PASS: %d checks" % _checks)
	else:
		print("GAME CONTROLLER CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
