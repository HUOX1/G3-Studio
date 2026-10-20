extends Node
class_name FontManager

var _cache: Dictionary = {}
# scope -> fontset dict（"movies" / "games"）
var _current: Dictionary = {}

func set_fontset(scope: String, fontset: Dictionary) -> void:
	_current[scope] = fontset

func get_fontset(scope: String) -> Dictionary:
	return _current.get(scope, {})

func get_font_for(key: String, scope: String = "movies") -> FontFile:
	var fs: Dictionary = _current.get(scope, {})
	var fields = fs.get("fields", {})
	if not (fields is Dictionary):
		return null
	var entry = fields.get(key, {})
	if not (entry is Dictionary):
		return null
	var path: String = str(entry.get("font_path", "")).strip_edges()
	if path.is_empty():
		return null
	return _load_font(path)

func get_size_for(key: String, fallback: int, scope: String = "movies") -> int:
	var fs: Dictionary = _current.get(scope, {})
	var fields = fs.get("fields", {})
	if not (fields is Dictionary):
		return fallback
	var entry = fields.get(key, {})
	if not (entry is Dictionary):
		return fallback
	var value = entry.get("font_size", fallback)
	var size = int(value)
	return size if size > 0 else fallback

func get_font_for_path(path: String) -> FontFile:
	return _load_font(path)

func _load_font(path: String) -> FontFile:
	if _cache.has(path):
		return _cache[path]
	var font := FontFile.new()
	var err := font.load_dynamic_font(path)
	if err != OK:
		push_warning("font load failed: %s" % path)
		_cache[path] = null
		return null
	_cache[path] = font
	return font