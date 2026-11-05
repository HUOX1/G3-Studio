extends Node
class_name FontManager

var _cache: Dictionary = {}
var _styled_cache: Dictionary = {}
# scope -> fontset dict（"movies" / "games"）
var _current: Dictionary = {}

func set_fontset(scope: String, fontset: Dictionary) -> void:
	_current[scope] = fontset

func get_fontset(scope: String) -> Dictionary:
	return _current.get(scope, {})

func get_font_for(key: String, scope: String = "movies") -> Font:
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
	return _get_styled_font(path, entry)

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

func get_field_settings(key: String, scope: String = "movies") -> Dictionary:
	var fs: Dictionary = _current.get(scope, {})
	var fields = fs.get("fields", {})
	if not (fields is Dictionary):
		return {}
	var entry = fields.get(key, {})
	return entry if entry is Dictionary else {}

func apply_style_to_control(control: Control, key: String, scope: String = "movies") -> void:
	if control == null:
		return
	var entry := get_field_settings(key, scope)
	var color_hex := str(entry.get("font_color", "")).strip_edges()
	var color_item := "default_color" if control is RichTextLabel else "font_color"
	var base_meta_key := "_g3_base_color_" + color_item
	if not control.has_meta(base_meta_key):
		control.set_meta(base_meta_key, control.get_theme_color(color_item))
	var base_color: Color = control.get_meta(base_meta_key)
	if not color_hex.is_empty():
		control.add_theme_color_override(color_item, Color.from_string(color_hex, base_color))
	else:
		control.add_theme_color_override(color_item, base_color)
	if control is RichTextLabel:
		control.add_theme_constant_override("line_separation", int(entry.get("line_spacing", 0)))
	elif control is Label:
		control.add_theme_constant_override("line_spacing", int(entry.get("line_spacing", 0)))

func _get_styled_font(path: String, entry: Dictionary) -> Font:
	var weight := clampf(float(entry.get("font_weight", 0.0)), 0.0, 1.0)
	var letter_spacing := clampi(int(entry.get("letter_spacing", 0)), -2, 4)
	if is_zero_approx(weight) and letter_spacing == 0:
		return _load_font(path)
	var cache_key := "%s|%.2f|%d" % [path, weight, letter_spacing]
	if _styled_cache.has(cache_key):
		return _styled_cache[cache_key]
	var base := _load_font(path)
	if base == null:
		return null
	var styled := FontVariation.new()
	styled.base_font = base
	styled.variation_embolden = weight
	styled.set_spacing(TextServer.SPACING_GLYPH, letter_spacing)
	_styled_cache[cache_key] = styled
	return styled

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