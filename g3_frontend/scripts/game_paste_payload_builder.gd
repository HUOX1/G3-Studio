extends RefCounted

# UI-S6h: Convert parsed paste fields into existing game create/update payloads.
# Backend connectivity and request routing remain in main.gd.

static func _release_year(parsed: Dictionary) -> String:
	# GDScript `or` returns bool; preserve the explicit fallback and whitespace handling.
	var year_value: String = str(parsed.get("release_year", "")).strip_edges()
	if year_value.is_empty():
		year_value = str(parsed.get("release_date", "")).strip_edges()
	return year_value


static func build_create(parsed: Dictionary) -> Dictionary:
	return {
		"title": str(parsed.get("title", "")),
		"english_name": str(parsed.get("english_name", "")),
		"platform": str(parsed.get("platform", "")),
		"developer": str(parsed.get("developer", "")),
		"publisher": str(parsed.get("publisher", "")),
		"genres": str(parsed.get("genres", "")),
		"tags": str(parsed.get("tags", "")),
		"profile_type": "direct",
		"video_path": "",
		"launch_exe": "",
		"content_path": "",
		"launch_args": "",
		"working_directory": "",
		"cover_source": "",
		"release_year": _release_year(parsed),
		"description": str(parsed.get("description", "")),
	}


static func build_update(parsed: Dictionary) -> Dictionary:
	return {
		"id": str(parsed.get("target_item_id", "")),
		"title": str(parsed.get("title", "")),
		"english_name": str(parsed.get("english_name", "")),
		"platform": str(parsed.get("platform", "")),
		"developer": str(parsed.get("developer", "")),
		"publisher": str(parsed.get("publisher", "")),
		"release_year": _release_year(parsed),
		"genres": str(parsed.get("genres", "")),
		"tags": str(parsed.get("tags", "")),
		"description": str(parsed.get("description", "")),
	}
