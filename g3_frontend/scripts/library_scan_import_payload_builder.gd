extends RefCounted

# Converts scanned rows to the existing game.create payloads without UI or backend access.
# Do not change per-platform field names, trimming, or validation rules.

static func count_existing(items: Array) -> int:
	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1
	return skipped_existing

static func build(platform: String, items: Array) -> Array[Dictionary]:
	match platform:
		"emulator":
			return _build_emulator(items)
		"steam":
			return _build_steam(items)
		"gog":
			return _build_gog(items)
		"epic":
			return _build_epic(items)
		"uplay":
			return _build_uplay(items)
		"rockstar":
			return _build_rockstar(items)
		"psn":
			return _build_psn(items)
		_:
			return []

static func _build_emulator(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("suggested_title", "")).strip_edges()
		var rom_path: String = str(item.get("rom_path", "")).strip_edges()
		if title.is_empty() or rom_path.is_empty():
			continue
		payloads.append({
			"title": title,
			"platform": str(item.get("platform_tag", "")),
			"profile_type": "emulator",
			"video_path": rom_path,
			"content_path": rom_path,
			"launch_exe": str(item.get("launch_exe", "")),
			"launch_args": str(item.get("launch_args", "")),
			"working_directory": str(item.get("working_directory", "")),
			"cover_source": "",
		})
	return payloads

static func _build_steam(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("name", "")).strip_edges()
		# 注意：GDScript 的 `x or default` 返回 bool，不能用来给默认值
		var appid: int = int(item.get("steam_appid", 0))
		if title.is_empty() or appid <= 0:
			continue
		payloads.append({
			"title": title,
			"platform": "Steam",
			"profile_type": "direct",
			"launch_exe": "",
			"video_path": "",
			"content_path": "",
			"source": "steam",
			"steam_appid": appid,
			"cover_source": "",
		})
	return payloads

static func _build_gog(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var game_id: String = str(item.get("game_id", "")).strip_edges()
		if title.is_empty() or game_id.is_empty():
			continue
		payloads.append({
			"title": title,
			"platform": "GOG",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"working_directory": str(item.get("working_directory", "")),
			"video_path": "",
			"content_path": "",
			"source": "gog",
			"external_id": game_id,
			"cover_source": "",
		})
	return payloads

static func _build_epic(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var app_name: String = str(item.get("app_name", "")).strip_edges()
		if title.is_empty() or app_name.is_empty():
			continue
		payloads.append({
			"title": title,
			"platform": "Epic",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"video_path": "",
			"content_path": "",
			"source": "epic",
			"external_id": app_name,
			"namespace_id": str(item.get("namespace_id", "")),
			"artifact_id": str(item.get("artifact_id", "")),
			"cover_source": "",
		})
	return payloads

static func _build_uplay(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var game_id: String = str(item.get("game_id", "")).strip_edges()
		if title.is_empty() or game_id.is_empty():
			continue
		payloads.append({
			"title": title,
			"platform": "Uplay",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"working_directory": str(item.get("working_directory", "")),
			"video_path": "",
			"content_path": "",
			"source": "uplay",
			"external_id": game_id,
			"cover_source": "",
		})
	return payloads

static func _build_psn(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		if bool(item.get("already_exists", false)):
			continue
		payloads.append({
			"title": str(item.get("title", "")),
			"english_name": str(item.get("english_name", "")),
			"platform": str(item.get("platform", "")),
			"profile_type": "direct",
			"launch_exe": "",
			"video_path": "",
			"content_path": "",
			"source": "psn",
			"external_id": str(item.get("external_id", "")),
			"psn_playtime_seconds": int(item.get("psn_playtime_seconds", 0)),
		})
	return payloads


static func _build_rockstar(items: Array) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var game_id: String = str(item.get("game_id", "")).strip_edges()
		if title.is_empty() or game_id.is_empty():
			continue
		payloads.append({
			"title": title,
			"platform": "Rockstar",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"working_directory": str(item.get("working_directory", "")),
			"video_path": "",
			"content_path": "",
			"source": "rockstar",
			"external_id": game_id,
			"cover_source": "",
		})
	return payloads
