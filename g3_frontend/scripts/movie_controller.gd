extends Node

# Stage 3.1: request ownership only. The movie wall, selection and restore
# state stay in main.gd until their UI lifecycle is audited separately.
signal list_completed(scope: String, ok: bool, data: Variant, error: Variant)
signal metadata_completed(item_id: String, ok: bool, data: Variant, error: Variant)
signal backdrop_refresh_completed(item_id: String, ok: bool, data: Variant, error: Variant)
signal create_completed(ok: bool, data: Variant, error: Variant)
signal remove_completed(ok: bool, data: Variant, error: Variant)
signal metadata_update_completed(ok: bool, data: Variant, error: Variant)

var _router: Node = null
var _pending_remove_target_id: String = ""
var _pending_cover_file_target_id: String = ""
var _pending_backdrop_file_target_id: String = ""

func configure(router: Node) -> void:
	_router = router

# UI-S8b: resolve movie-menu intent and target policy here; main.gd performs UI effects.
func resolve_manage_action(action: String, movie: Dictionary, scope: String) -> Dictionary:
	if movie.is_empty():
		return {}
	var item_id: String = str(movie.get("id", ""))
	match action:
		"edit_metadata":
			if item_id.is_empty():
				return {}
			return {"kind": "request_metadata", "item_id": item_id}
		"set_cover":
			if item_id.is_empty():
				return {}
			return {"kind": "set_cover", "item_id": item_id}
		"set_backdrop":
			if item_id.is_empty():
				return {}
			return {"kind": "set_backdrop", "item_id": item_id}
		"refresh_backdrop":
			if item_id.is_empty():
				return {}
			return {"kind": "refresh_backdrop", "item_id": item_id}
		"select_poster":
			if scope == "private":
				return {"kind": "error", "title": "选择海报失败", "message": "私有库已禁用 TMDB 功能"}
			if item_id.is_empty():
				return {}
			var poster_tmdb_id: int = int(movie.get("tmdb_id", 0))
			if poster_tmdb_id <= 0:
				return {"kind": "error", "title": "选择海报失败", "message": "该作品还没有 TMDB ID，请先使用「从 TMDB 获取资料」"}
			return {
				"kind": "select_poster",
				"item_id": item_id,
				"tmdb_id": poster_tmdb_id,
				"media_type": str(movie.get("media_type", "movie")),
				"title": str(movie.get("title", "")),
			}
		"tmdb_scrape":
			if scope == "private":
				return {"kind": "error", "title": "从 TMDB 获取资料失败", "message": "私有库已禁用 TMDB 功能"}
			if item_id.is_empty():
				return {}
			return {"kind": "tmdb_scrape", "item_id": item_id, "title": str(movie.get("title", ""))}
		"scrape_sgdb":
			if item_id.is_empty():
				return {}
			return {"kind": "scrape_sgdb", "item_id": item_id, "title": str(movie.get("title", ""))}
		"remove":
			if item_id.is_empty():
				return {}
			return {"kind": "remove", "item_id": item_id, "title": str(movie.get("title", "Untitled"))}
		_:
			return {}

# Stage 3.12: lazy backdrop ensure is fire-and-forget from the UI's point of view.
# Do not coalesce different item IDs: each selection may schedule independent work.
func request_backdrop_ensure(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request(
		"movie.backdrop.ensure", {"id": item_id},
		Callable(self, "_on_backdrop_ensure_response")
	)

func _on_backdrop_ensure_response(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	# Legacy main.gd intentionally ignored this response. Backend events refresh UI.
	pass

signal covers_match_completed(ok: bool, data: Variant, error: Variant)

func request_covers_match(scope: String) -> String:
	if _router == null or (scope != "main" and scope != "private"):
		return ""
	return _router.request_latest(
		"movie.covers.match_local", "movie.covers.match_local", {"scope": scope},
		Callable(self, "_on_covers_match_response")
	)

func _on_covers_match_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	covers_match_completed.emit(ok, data, error)

func request_list(scope: String) -> String:
	if _router == null or (scope != "main" and scope != "private"):
		return ""
	# Preserve the original single _pending_movies_id latest-wins slot,
	# including replacement across main/private scope changes.
	return _router.request_latest(
		"movies.list", "library.movies.list", {"scope": scope},
		Callable(self, "_on_list_response").bind(scope)
	)

func _on_list_response(_request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	list_completed.emit(scope, ok, data, error)

# The legacy metadata and backdrop-refresh requests each had their own
# single pending ID. Do not share a slot between these two operations.
func request_metadata(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"movie.metadata.get", "movie.metadata.get", {"id": item_id},
		Callable(self, "_on_metadata_response").bind(item_id)
	)

func _on_metadata_response(_request_id: String, ok: bool, data: Variant, error: Variant, item_id: String) -> void:
	metadata_completed.emit(item_id, ok, data, error)

func request_backdrop_refresh(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"movie.backdrop.refresh", "movie.backdrop.refresh", {"id": item_id},
		Callable(self, "_on_backdrop_refresh_response").bind(item_id)
	)

func _on_backdrop_refresh_response(_request_id: String, ok: bool, data: Variant, error: Variant, item_id: String) -> void:
	backdrop_refresh_completed.emit(item_id, ok, data, error)

# Three independent legacy pending slots; each operation is latest-wins.
# MovieController owns the staged removal target; main.gd owns the confirmation UI and status messaging.
func request_create(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"movie.create", "movie.create", payload,
		Callable(self, "_on_create_response")
	)

func _on_create_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	create_completed.emit(ok, data, error)

func set_pending_remove_target(item_id: String) -> void:
	_pending_remove_target_id = item_id

func has_pending_remove_target() -> bool:
	return not _pending_remove_target_id.is_empty()

func request_pending_remove() -> String:
	if _pending_remove_target_id.is_empty():
		return ""
	return request_remove(_pending_remove_target_id)

func request_remove(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"movie.remove", "movie.remove", {"id": item_id},
		Callable(self, "_on_remove_response")
	)

func _on_remove_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_pending_remove_target_id = ""
	remove_completed.emit(ok, data, error)

func request_metadata_update(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"movie.metadata.update", "movie.metadata.update", payload,
		Callable(self, "_on_metadata_update_response")
	)

func _on_metadata_update_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	metadata_update_completed.emit(ok, data, error)

# MovieController owns the item IDs staged by the cover and backdrop file pickers.
# main.gd continues to own the picker UI, connection messaging and list refresh.
signal cover_set_completed(ok: bool, data: Variant, error: Variant)
signal backdrop_set_completed(ok: bool, data: Variant, error: Variant)

func set_pending_cover_file_target(item_id: String) -> void:
	_pending_cover_file_target_id = item_id

func has_pending_cover_file_target() -> bool:
	return not _pending_cover_file_target_id.is_empty()

func request_pending_cover_set(source_path: String) -> String:
	if _pending_cover_file_target_id.is_empty():
		return ""
	return request_cover_set(_pending_cover_file_target_id, source_path)

func request_cover_set(item_id: String, source_path: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"movie.cover.set", "movie.cover.set", {"id": item_id, "source": source_path},
		Callable(self, "_on_cover_set_response")
	)

func _on_cover_set_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_pending_cover_file_target_id = ""
	cover_set_completed.emit(ok, data, error)

func set_pending_backdrop_file_target(item_id: String) -> void:
	_pending_backdrop_file_target_id = item_id

func has_pending_backdrop_file_target() -> bool:
	return not _pending_backdrop_file_target_id.is_empty()

func request_pending_backdrop_set(source_path: String) -> String:
	if _pending_backdrop_file_target_id.is_empty():
		return ""
	return request_backdrop_set(_pending_backdrop_file_target_id, source_path)

func request_backdrop_set(item_id: String, source_path: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"movie.backdrop.set", "movie.backdrop.set", {"id": item_id, "source": source_path},
		Callable(self, "_on_backdrop_set_response")
	)

func _on_backdrop_set_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_pending_backdrop_file_target_id = ""
	backdrop_set_completed.emit(ok, data, error)

# Stage 3.5: preserve the independent legacy single-pending slots.
# UI messaging and list refresh remain owned by main.gd.
signal scan_completed(scope: String, ok: bool, data: Variant, error: Variant)
signal tmdb_search_completed(ok: bool, data: Variant, error: Variant)

func request_scan(scope: String) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"movie.scan", "library.scan_movies", {"scope": scope},
		Callable(self, "_on_scan_response").bind(scope)
	)

func _on_scan_response(_request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	scan_completed.emit(scope, ok, data, error)

func request_tmdb_search(query: String, media_type: String) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"tmdb.search", "tmdb.search", {"query": query, "media_type": media_type},
		Callable(self, "_on_tmdb_search_response")
	)

func _on_tmdb_search_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	tmdb_search_completed.emit(ok, data, error)

# Stage 3.6: three independent latest slots, plus concurrently outstanding
# thumbnail requests. Bind each thumbnail path to its own Router callback.
signal tmdb_apply_completed(ok: bool, data: Variant, error: Variant)
signal poster_list_completed(ok: bool, data: Variant, error: Variant)
signal poster_thumb_completed(file_path: String, ok: bool, data: Variant, error: Variant)
signal poster_apply_completed(ok: bool, data: Variant, error: Variant)

func request_tmdb_apply(item_id: String, tmdb_id: int, media_type: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"tmdb.apply", "tmdb.apply",
		{"id": item_id, "tmdb_id": tmdb_id, "media_type": media_type},
		Callable(self, "_on_tmdb_apply_response")
	)

func _on_tmdb_apply_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	tmdb_apply_completed.emit(ok, data, error)

func request_poster_list(tmdb_id: int, media_type: String) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"tmdb.poster.list", "tmdb.poster.list",
		{"tmdb_id": tmdb_id, "media_type": media_type},
		Callable(self, "_on_poster_list_response")
	)

func _on_poster_list_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	poster_list_completed.emit(ok, data, error)

func request_poster_thumb(file_path: String) -> String:
	if _router == null:
		return ""
	# Legacy _pending_poster_thumb_ids was a map, not a latest slot.
	return _router.request(
		"tmdb.poster.thumb", {"file_path": file_path},
		Callable(self, "_on_poster_thumb_response").bind(file_path)
	)

func _on_poster_thumb_response(_request_id: String, ok: bool, data: Variant, error: Variant, file_path: String) -> void:
	poster_thumb_completed.emit(file_path, ok, data, error)

func request_poster_apply(item_id: String, file_path: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest(
		"tmdb.poster.apply", "tmdb.poster.apply",
		{"id": item_id, "file_path": file_path},
		Callable(self, "_on_poster_apply_response")
	)

func _on_poster_apply_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	poster_apply_completed.emit(ok, data, error)

# Stage 3.7: only movie.play request/response ownership moves here.
# Playback process monitoring, render pause/resume, and movie.exited remain
# owned by main.gd. Both movie-card and episode launches shared one pending ID.
signal play_completed(ok: bool, data: Variant, error: Variant)

# The backend may report movie.exited before the matching movie.play reply.
# Retain a bounded set of early exits, keyed by the backend's session ID.
# No ID means a legacy event; it must not cancel an unrelated play reply.
var _early_exited_sessions: Dictionary = {}
# Only confirmed, session-identified mpv replies can establish active ownership.
# A superseded reply or a legacy no-ID player cannot be inferred as active.
var _active_play_sessions: Dictionary = {}
var _early_exit_order: Array[String] = []
const MAX_EARLY_EXITS: int = 64

func observe_playback_exit(payload: Dictionary) -> void:
	var session_id: String = str(payload.get("play_session_id", ""))
	if session_id.is_empty():
		return
	# A late or duplicate exit must never release another known mpv session.
	_active_play_sessions.erase(session_id)
	if _early_exited_sessions.has(session_id):
		return
	_early_exited_sessions[session_id] = true
	_early_exit_order.append(session_id)
	if _early_exit_order.size() > MAX_EARLY_EXITS:
		_early_exited_sessions.erase(_early_exit_order.pop_front())

func has_active_playback_sessions() -> bool:
	return not _active_play_sessions.is_empty()

func clear_playback_exit_history() -> void:
	_early_exited_sessions.clear()
	_early_exit_order.clear()
	_active_play_sessions.clear()

func request_play(item_id: String, episode_id: String = "") -> String:
	if _router == null or item_id.is_empty():
		return ""
	var payload: Dictionary = {"id": item_id}
	if not episode_id.is_empty():
		payload["episode_id"] = episode_id
	return _router.request_latest(
		"movie.play", "movie.play", payload,
		Callable(self, "_on_play_response")
	)

func _on_play_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary:
		var session_id: String = str((data as Dictionary).get("play_session_id", ""))
		if not session_id.is_empty():
			if _early_exited_sessions.has(session_id):
				# Do not mutate the response object owned by BackendRouter.
				var resolved: Dictionary = (data as Dictionary).duplicate()
				resolved["already_exited"] = true
				play_completed.emit(ok, resolved, error)
				return
			if bool((data as Dictionary).get("monitorable", true)):
				_active_play_sessions[session_id] = true
	play_completed.emit(ok, data, error)
