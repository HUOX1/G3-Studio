extends Node

# Stage 4.1: game-list request ownership only. UI snapshots and state restore
# remain in main.gd. The single legacy pending ID was latest-wins.
signal list_completed(ok: bool, data: Variant, error: Variant)

var _router: Node = null
var _pending_remove_target_id: String = ""

func configure(router: Node) -> void:
	_router = router

# UI-S8c: resolve game-management intent and its data context before main.gd performs UI effects.
func resolve_manage_action(action: String, game: Dictionary) -> Dictionary:
	if game.is_empty():
		return {}
	var item_id: String = str(game.get("id", ""))
	if item_id.is_empty():
		return {}
	match action:
		"scrape_sgdb":
			return {
				"kind": "scrape_sgdb",
				"item_id": item_id,
				"query": _resolve_manage_search_query(game),
			}
		"steam_metadata":
			return {
				"kind": "steam_metadata",
				"item_id": item_id,
				"query": _resolve_manage_search_query(game),
			}
		"edit_metadata":
			return {"kind": "edit_metadata", "item_id": item_id}
		"paste_import":
			return {"kind": "paste_import", "item_id": item_id}
		"browse_game_dir":
			var dir: String = ""
			var launch_exe: String = str(game.get("launch_exe", "")).strip_edges()
			if not launch_exe.is_empty():
				dir = launch_exe.get_base_dir()
			else:
				var source_path: String = str(game.get("source_path", "")).strip_edges()
				if not source_path.is_empty():
					dir = source_path.get_base_dir()
			return {"kind": "browse_game_dir", "item_id": item_id, "path": dir}
		"browse_assets_dir":
			return {
				"kind": "browse_assets_dir",
				"item_id": item_id,
				"path": str(game.get("cover_dir", "")).strip_edges(),
			}
		"edit_launch":
			return {"kind": "edit_launch", "item_id": item_id}
		"edit_playtime":
			return {
				"kind": "edit_playtime",
				"item_id": item_id,
				"playtime_seconds": int(game.get("playtime_seconds", 0)),
			}
		"remove":
			return {
				"kind": "remove",
				"item_id": item_id,
				"title": str(game.get("title", "Untitled")),
			}
		_:
			return {}

func _resolve_manage_search_query(game: Dictionary) -> String:
	var query: String = str(game.get("english_name", "")).strip_edges()
	if query.is_empty():
		query = str(game.get("title", ""))
	return query

func request_list() -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"games.list", "library.games.list", {},
		Callable(self, "_on_list_response")
	)

func _on_list_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	list_completed.emit(ok, data, error)

# Stage 4.2: distinct UI intents must not collide even when command matches.
signal metadata_completed(item_id: String, ok: bool, data: Variant, error: Variant)
signal launch_metadata_completed(item_id: String, ok: bool, data: Variant, error: Variant)
signal metadata_update_completed(ok: bool, data: Variant, error: Variant)
signal paste_update_completed(ok: bool, data: Variant, error: Variant)

func request_metadata(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest("games.metadata.read", "game.metadata.get", {"id": item_id}, Callable(self, "_on_metadata_response").bind(item_id))

func request_launch_metadata(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest("games.launch.read", "game.metadata.get", {"id": item_id}, Callable(self, "_on_launch_metadata_response").bind(item_id))

func request_metadata_update(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.metadata.write", "game.metadata.update", payload.duplicate(true), Callable(self, "_on_metadata_update_response"))

func request_paste_update(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.paste.write", "game.metadata.update", payload.duplicate(true), Callable(self, "_on_paste_update_response"))

func _on_metadata_response(_request_id: String, ok: bool, data: Variant, error: Variant, item_id: String) -> void:
	metadata_completed.emit(item_id, ok, data, error)

func _on_launch_metadata_response(_request_id: String, ok: bool, data: Variant, error: Variant, item_id: String) -> void:
	launch_metadata_completed.emit(item_id, ok, data, error)

func _on_metadata_update_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	metadata_update_completed.emit(ok, data, error)

func _on_paste_update_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	paste_update_completed.emit(ok, data, error)

# Stage 4.3: preserve distinct manual and paste create contexts.
# Single-delete and batch-delete intentionally have different response handling.
signal launch_update_completed(ok: bool, data: Variant, error: Variant)
signal playtime_completed(ok: bool, data: Variant, error: Variant)
signal remove_completed(ok: bool, data: Variant, error: Variant)
signal create_completed(ok: bool, data: Variant, error: Variant)
signal paste_create_completed(ok: bool, data: Variant, error: Variant)

func request_launch_update(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.launch.write", "game.launch_profile.update", payload.duplicate(true), Callable(self, "_on_launch_update_response"))

func request_playtime(item_id: String, seconds: int) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.playtime.write", "game.playtime.set", {"id": item_id, "seconds": seconds}, Callable(self, "_on_playtime_response"))

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
	return _router.request_latest("games.remove.single", "game.remove", {"id": item_id}, Callable(self, "_on_remove_response"))

func request_create(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.create.manual", "game.create", payload.duplicate(true), Callable(self, "_on_create_response"))

func request_paste_create(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.create.paste", "game.create", payload.duplicate(true), Callable(self, "_on_paste_create_response"))

func _on_launch_update_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	launch_update_completed.emit(ok, data, error)

func _on_playtime_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	playtime_completed.emit(ok, data, error)

func _on_remove_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_pending_remove_target_id = ""
	remove_completed.emit(ok, data, error)

func _on_create_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	create_completed.emit(ok, data, error)

func _on_paste_create_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	paste_create_completed.emit(ok, data, error)

# Stage 4.8: batch deletion remains fire-and-forget from the UI. Unlike the
# confirmed single-item removal, it must not emit a completion or refresh.
# Each deletion gets an independent route, so concurrent replies cannot
# accidentally invoke a single-delete callback or leak into legacy main.gd.
func request_batch_remove(item_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request("game.remove", {"id": item_id}, Callable(self, "_on_batch_remove_response"))

func _on_batch_remove_response(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	pass

# Stage 4.4: manual and sequential batch Steam scraper requests have separate
# latest slots. Batch generation and item ID are bound at request creation.
signal steam_manual_search_completed(ok: bool, data: Variant, error: Variant)
signal steam_manual_apply_completed(ok: bool, data: Variant, error: Variant)
signal steam_batch_search_completed(generation: int, item_id: String, ok: bool, data: Variant, error: Variant)
signal steam_batch_apply_completed(generation: int, item_id: String, ok: bool, data: Variant, error: Variant)

func request_steam_manual_search(query: String) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.steam.manual.search", "game.scrape.search", {"query": query}, Callable(self, "_on_steam_manual_search_response"))

func request_steam_manual_apply(item_id: String, external_id: int) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest("games.steam.manual.apply", "game.scrape.apply", {"id": item_id, "source": "steam", "external_id": external_id}, Callable(self, "_on_steam_manual_apply_response"))

func request_steam_batch_search(query: String, item_id: String, generation: int) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest("games.steam.batch.search", "game.scrape.search", {"query": query}, Callable(self, "_on_steam_batch_search_response").bind(generation, item_id))

func request_steam_batch_apply(item_id: String, external_id: int, generation: int) -> String:
	if _router == null or item_id.is_empty():
		return ""
	return _router.request_latest("games.steam.batch.apply", "game.scrape.apply", {"id": item_id, "source": "steam", "external_id": external_id}, Callable(self, "_on_steam_batch_apply_response").bind(generation, item_id))

func _on_steam_manual_search_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	steam_manual_search_completed.emit(ok, data, error)

func _on_steam_manual_apply_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	steam_manual_apply_completed.emit(ok, data, error)

func _on_steam_batch_search_response(_request_id: String, ok: bool, data: Variant, error: Variant, generation: int, item_id: String) -> void:
	steam_batch_search_completed.emit(generation, item_id, ok, data, error)

func _on_steam_batch_apply_response(_request_id: String, ok: bool, data: Variant, error: Variant, generation: int, item_id: String) -> void:
	steam_batch_apply_completed.emit(generation, item_id, ok, data, error)

# Stage 4.5: SGDB search is latest-wins; asset listings and applies are
# independently routed and may complete in any order.
signal sgdb_search_completed(ok: bool, data: Variant, error: Variant)
signal sgdb_assets_completed(asset_tag: String, batch_id: String, ok: bool, data: Variant, error: Variant)
signal sgdb_asset_info_completed(ok: bool, data: Variant, error: Variant)
signal sgdb_apply_completed(asset_tag: String, operation_id: String, remaining: int, ok: bool, data: Variant, error: Variant)

var _sgdb_pending_applies: Dictionary = {}

func request_sgdb_search(query: String) -> String:
	if _router == null:
		return ""
	return _router.request_latest("games.sgdb.search", "sgdb.search", {"query": query}, Callable(self, "_on_sgdb_search_response"))

func request_sgdb_assets(sgdb_id: int, asset_tag: String, batch_id: String) -> String:
	if _router == null:
		return ""
	return _router.request("sgdb.assets", {"sgdb_id": sgdb_id, "asset_type": asset_tag, "batch_id": batch_id}, Callable(self, "_on_sgdb_assets_response").bind(asset_tag, batch_id))

func request_sgdb_asset_info(url: String) -> String:
	if _router == null or url.is_empty():
		return ""
	return _router.request_latest("games.sgdb.asset.info", "sgdb.asset.info", {"url": url}, Callable(self, "_on_sgdb_asset_info_response"))

func request_sgdb_apply(item_id: String, sgdb_id: int, asset_tag: String, url: String, operation_id: String) -> String:
	if _router == null or item_id.is_empty():
		return ""
	var rid: String = _router.request("sgdb.apply", {"id": item_id, "sgdb_id": sgdb_id, "asset_type": asset_tag, "url": url, "operation_id": operation_id}, Callable(self, "_on_sgdb_apply_response").bind(asset_tag, operation_id))
	if not rid.is_empty():
		_sgdb_pending_applies[rid] = true
	return rid

func clear_sgdb_pending() -> void:
	# BackendRouter already retires routed requests on disconnect.
	_sgdb_pending_applies.clear()

func _on_sgdb_search_response(_rid: String, ok: bool, data: Variant, error: Variant) -> void:
	sgdb_search_completed.emit(ok, data, error)

func _on_sgdb_assets_response(_rid: String, ok: bool, data: Variant, error: Variant, asset_tag: String, batch_id: String) -> void:
	sgdb_assets_completed.emit(asset_tag, batch_id, ok, data, error)

func _on_sgdb_asset_info_response(_rid: String, ok: bool, data: Variant, error: Variant) -> void:
	sgdb_asset_info_completed.emit(ok, data, error)

func _on_sgdb_apply_response(rid: String, ok: bool, data: Variant, error: Variant, asset_tag: String, operation_id: String) -> void:
	_sgdb_pending_applies.erase(rid)
	sgdb_apply_completed.emit(asset_tag, operation_id, _sgdb_pending_applies.size(), ok, data, error)

# Stage 4.7: game.play is a single in-flight operation, NOT latest-wins.
# The actual process-running and exit events remain owned by main.gd.
signal play_completed(ok: bool, data: Variant, error: Variant)
var _pending_play_id: String = ""

func has_pending_play() -> bool:
	return not _pending_play_id.is_empty()

func request_play(item_id: String) -> String:
	if _router == null or item_id.is_empty() or has_pending_play():
		return ""
	var request_id: String = _router.request("game.play", {"id": item_id}, Callable(self, "_on_play_response"))
	if not request_id.is_empty():
		_pending_play_id = request_id
	return request_id

func clear_pending_play() -> void:
	# Used when backend disconnects. Router independently retires all routes.
	_pending_play_id = ""

func _on_play_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if request_id != _pending_play_id:
		return
	_pending_play_id = ""
	play_completed.emit(ok, data, error)
