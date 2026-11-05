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
	var next_id: int = 0
	var available: bool = true
	var sent: Dictionary = {}
	func request(command: String, payload: Dictionary) -> String:
		if not available:
			return ""
		next_id += 1
		var req_id: String = "movie-%d" % next_id
		sent[req_id] = {"command": command, "payload": payload.duplicate(true)}
		return req_id
	func reply(req_id: String, ok: bool, data: Variant, error: Variant = null) -> void:
		response_received.emit(req_id, ok, data, error)

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

func _on_result(scope: String, ok: bool, data: Variant, error: Variant) -> void:
	_results.append({"scope": scope, "ok": ok, "data": data, "error": error})

func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy += 1

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Node = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	var movie: Node = MOVIE_SCRIPT.new()
	add_child(movie)
	movie.configure(router)
	# UI-S8b: menu-action policy is resolved by MovieController, UI effects remain in main.gd.
	_check(movie.resolve_manage_action("edit_metadata", {}, "main").is_empty(), "empty movie target ignored")
	_check(movie.resolve_manage_action("remove", {"title": "No ID"}, "main").is_empty(), "movie target without ID ignored")
	var metadata_plan: Dictionary = movie.resolve_manage_action("edit_metadata", {"id": "movie-1"}, "main")
	_check(str(metadata_plan.get("kind", "")) == "request_metadata" and str(metadata_plan.get("item_id", "")) == "movie-1", "metadata action resolves item")
	var cover_plan: Dictionary = movie.resolve_manage_action("set_cover", {"id": "movie-2"}, "main")
	_check(str(cover_plan.get("kind", "")) == "set_cover" and str(cover_plan.get("item_id", "")) == "movie-2", "cover action resolves item")
	var backdrop_plan: Dictionary = movie.resolve_manage_action("set_backdrop", {"id": "movie-3"}, "main")
	_check(str(backdrop_plan.get("kind", "")) == "set_backdrop" and str(backdrop_plan.get("item_id", "")) == "movie-3", "backdrop action resolves item")
	var refresh_plan: Dictionary = movie.resolve_manage_action("refresh_backdrop", {"id": "movie-4"}, "main")
	_check(str(refresh_plan.get("kind", "")) == "refresh_backdrop" and str(refresh_plan.get("item_id", "")) == "movie-4", "backdrop refresh action resolves item")
	var private_poster: Dictionary = movie.resolve_manage_action("select_poster", {"id": "movie-5", "tmdb_id": 5}, "private")
	_check(str(private_poster.get("kind", "")) == "error" and str(private_poster.get("title", "")) == "选择海报失败" and str(private_poster.get("message", "")) == "私有库已禁用 TMDB 功能", "private poster action remains blocked")
	var missing_tmdb: Dictionary = movie.resolve_manage_action("select_poster", {"id": "movie-6", "tmdb_id": 0}, "main")
	_check(str(missing_tmdb.get("kind", "")) == "error" and str(missing_tmdb.get("message", "")) == "该作品还没有 TMDB ID，请先使用「从 TMDB 获取资料」", "poster action requires TMDB ID")
	var poster_plan: Dictionary = movie.resolve_manage_action("select_poster", {"id": "movie-7", "tmdb_id": 77, "media_type": "tv", "title": "Series"}, "main")
	_check(str(poster_plan.get("kind", "")) == "select_poster" and str(poster_plan.get("item_id", "")) == "movie-7" and int(poster_plan.get("tmdb_id", 0)) == 77 and str(poster_plan.get("media_type", "")) == "tv" and str(poster_plan.get("title", "")) == "Series", "poster context is preserved")
	var private_tmdb: Dictionary = movie.resolve_manage_action("tmdb_scrape", {"id": "movie-8"}, "private")
	_check(str(private_tmdb.get("kind", "")) == "error" and str(private_tmdb.get("title", "")) == "从 TMDB 获取资料失败", "private TMDB scrape remains blocked")
	var tmdb_plan: Dictionary = movie.resolve_manage_action("tmdb_scrape", {"id": "movie-9", "title": "Film"}, "main")
	_check(str(tmdb_plan.get("kind", "")) == "tmdb_scrape" and str(tmdb_plan.get("item_id", "")) == "movie-9" and str(tmdb_plan.get("title", "")) == "Film", "TMDB scrape context is preserved")
	var sgdb_plan: Dictionary = movie.resolve_manage_action("scrape_sgdb", {"id": "movie-10", "title": "Game"}, "main")
	_check(str(sgdb_plan.get("kind", "")) == "scrape_sgdb" and str(sgdb_plan.get("item_id", "")) == "movie-10" and str(sgdb_plan.get("title", "")) == "Game", "SGDB action context is preserved")
	var remove_plan: Dictionary = movie.resolve_manage_action("remove", {"id": "movie-11"}, "main")
	_check(str(remove_plan.get("kind", "")) == "remove" and str(remove_plan.get("item_id", "")) == "movie-11" and str(remove_plan.get("title", "")) == "Untitled", "remove action retains title fallback")
	_check(movie.resolve_manage_action("unknown", {"id": "movie-12"}, "main").is_empty(), "unknown movie action ignored")
	movie.list_completed.connect(_on_result)
	_check(not movie.has_pending_remove_target(), "remove target starts empty")
	_check(movie.request_pending_remove().is_empty(), "pending remove rejects missing target")
	movie.set_pending_remove_target("movie-confirm")
	_check(movie.has_pending_remove_target(), "remove confirmation target staged")
	var pending_remove_id: String = movie.request_pending_remove()
	var pending_remove_sent: bool = not pending_remove_id.is_empty() and backend.sent.has(pending_remove_id)
	_check(pending_remove_sent, "pending remove request sent")
	_check(pending_remove_sent and backend.sent[pending_remove_id]["command"] == "movie.remove" and backend.sent[pending_remove_id]["payload"] == {"id": "movie-confirm"}, "pending remove uses staged movie ID")
	if pending_remove_sent:
		backend.reply(pending_remove_id, true, {})
	_check(pending_remove_sent and not movie.has_pending_remove_target(), "remove target cleared after response")

	var first: String = movie.request_list("main")
	_check(not first.is_empty(), "main list sends request")
	_check(str(backend.sent[first]["command"]) == "library.movies.list", "list command preserved")
	_check(str(backend.sent[first]["payload"].get("scope", "")) == "main", "main scope preserved")
	var second: String = movie.request_list("private")
	_check(second != first and not second.is_empty(), "private list has new ID")
	_check(str(backend.sent[second]["payload"].get("scope", "")) == "private", "private scope preserved")
	_check(router.pending_route_count() == 1, "cross-scope latest slot replaces old request")
	backend.reply(first, true, [{"id": "old"}])
	_check(_results.is_empty(), "superseded main reply ignored")
	backend.reply(second, true, [{"id": "private-item"}])
	_check(_results.size() == 1 and str(_results[0]["scope"]) == "private", "private reply scoped correctly")
	_check(_results.size() == 1 and bool(_results[0]["ok"]) and _results[0]["data"] is Array, "array payload preserved")
	backend.reply(second, true, [])
	_check(_results.size() == 1, "duplicate reply ignored")
	_check(router.pending_route_count() == 0, "latest slot consumed")

	var third: String = movie.request_list("main")
	backend.reply(third, false, null, {"message": "offline"})
	_check(_results.size() == 2 and not bool(_results[1]["ok"]), "error response forwarded")
	_check(str(_results[1]["scope"]) == "main", "error retains request scope")
	var fourth: String = movie.request_list("main")
	backend.reply(fourth, true, {"bad": "shape"})
	_check(_results.size() == 3 and _results[2]["data"] is Dictionary, "malformed payload left to UI owner")
	_check(movie.request_list("unknown").is_empty(), "invalid scope rejected")
	_check(router.pending_route_count() == 0, "invalid scope creates no route")

	var old_id: String = movie.request_list("main")
	backend.available = false
	_check(movie.request_list("private").is_empty(), "failed send returns empty ID")
	_check(router.pending_route_count() == 0, "failed replacement invalidates prior request")
	backend.reply(old_id, true, [])
	_check(_results.size() == 3, "failed replacement old response ignored")
	backend.available = true
	var disconnected_id: String = movie.request_list("private")
	backend.disconnected.emit(1006, "lost")
	backend.reply(disconnected_id, true, [])
	_check(_results.size() == 3, "late reply after disconnect ignored")
	_check(router.pending_route_count() == 0, "disconnect clears movie route")
	_check(_legacy == 0, "movie responses never fall back to legacy")
	if _failures == 0:
		print("MOVIE CONTROLLER CONTRACT PASS: %d checks" % _checks)
	else:
		print("MOVIE CONTROLLER CONTRACT FAIL: %d of %d checks" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
