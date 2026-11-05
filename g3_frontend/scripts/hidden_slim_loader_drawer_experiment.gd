extends Control

const DRIVE_BUTTON_SCRIPT := preload("res://scripts/disc_loader_experiment_button.gd")
const DRAWER_HEIGHT: float = 135.2
const HANDLE_VISIBLE_WIDTH: float = 30.0
const HANDLE_WIDTH: float = 34.0
const HANDLE_HEIGHT: float = 84.0
const HANDLE_Y: float = 25.6

signal demo_state_changed(state: String)
signal drawer_state_changed(expanded: bool)

var _panel_width: float = 520.0
var _drawer_reveal: float = 0.0
var _theme_accent: Color = Color(0.43, 0.69, 0.76, 1.0)
var _drawer_tween: Tween
var _mask: Control
var _drive_button: Button
var _panel_root: Control
var _handle_button: Button
var _active_variant: int = 1

func _ready() -> void:
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(HANDLE_VISIBLE_WIDTH, DRAWER_HEIGHT)
	_build_ui()
	_sync_geometry()

func set_drive_variant(variant: int) -> void:
	_active_variant = variant
	if _drive_button != null:
		_drive_button.call("set_drive_variant", variant)
	if not is_instance_valid(_drive_button):
		return
	if _theme_accent == Color(0.43, 0.69, 0.76, 1.0) or _theme_accent == Color(0.78, 0.57, 0.30, 1.0):
		_theme_accent = _default_variant_accent()
		_drive_button.call("set_theme_accent", _theme_accent, 0.0)
	_sync_handle_theme()

func set_panel_width(width: float) -> void:
	_panel_width = clampf(width, 380.0, 520.0)
	if _drive_button != null:
		_drive_button.call("set_panel_width", _panel_width)
		_drive_button.custom_minimum_size = Vector2(_panel_width, DRAWER_HEIGHT)
	if _panel_root != null:
		_panel_root.custom_minimum_size = Vector2(_panel_width, DRAWER_HEIGHT)
	if _handle_button != null:
		_handle_button.position = Vector2(_panel_width - HANDLE_WIDTH, HANDLE_Y)
	_sync_geometry()

func set_theme_accent(accent: Color, transition_seconds: float = 0.68) -> void:
	_theme_accent = accent
	if _drive_button != null:
		_drive_button.call("set_theme_accent", accent, transition_seconds)
	_sync_handle_theme()

func apply_game_theme_palette(palette: Dictionary) -> void:
	if _drive_button != null:
		_drive_button.call("apply_game_theme_palette", palette)
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent_value: Variant = colors.get("accent", "")
	if typeof(accent_value) == TYPE_COLOR:
		_theme_accent = accent_value
	elif not str(accent_value).strip_edges().is_empty():
		_theme_accent = Color.from_string(str(accent_value), _theme_accent)
	_sync_handle_theme()

func reset_game_theme_palette() -> void:
	_theme_accent = _default_variant_accent()
	if _drive_button != null:
		_drive_button.call("reset_game_theme_palette")
	_sync_handle_theme()

func reset_demo() -> void:
	if _drive_button != null:
		_drive_button.call("reset_demo")
	_set_drawer_open(false, false)

func animate_eject() -> void:
	if _drive_button != null:
		_drive_button.call("animate_eject")

func get_demo_state() -> String:
	return str(_drive_button.call("get_demo_state")) if _drive_button != null else "READY"

func _build_ui() -> void:
	_mask = Control.new()
	_mask.name = "DrawerMask"
	_mask.clip_contents = true
	_mask.custom_minimum_size = Vector2(HANDLE_VISIBLE_WIDTH, DRAWER_HEIGHT)
	add_child(_mask)

	_panel_root = Control.new()
	_panel_root.name = "DrawerPanelRoot"
	_panel_root.custom_minimum_size = Vector2(_panel_width, DRAWER_HEIGHT)
	_mask.add_child(_panel_root)

	_drive_button = DRIVE_BUTTON_SCRIPT.new()
	_drive_button.name = "DiscLoaderExperimentButton"
	_drive_button.custom_minimum_size = Vector2(_panel_width, DRAWER_HEIGHT)
	_drive_button.connect("demo_state_changed", _on_demo_state_changed)
	_panel_root.add_child(_drive_button)
	_drive_button.call("set_drive_variant", _active_variant)
	_drive_button.call("set_panel_width", _panel_width)
	_drive_button.call("set_theme_accent", _theme_accent, 0.0)

	_handle_button = Button.new()
	_handle_button.name = "DrawerHandle"
	_handle_button.focus_mode = Control.FOCUS_NONE
	_handle_button.text = ""
	_handle_button.tooltip_text = "点击把手展开 / 收起启动面板"
	_handle_button.custom_minimum_size = Vector2(HANDLE_WIDTH, HANDLE_HEIGHT)
	_handle_button.position = Vector2(_panel_width - HANDLE_WIDTH, HANDLE_Y)
	_handle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_handle_button.pressed.connect(_toggle_drawer)
	_panel_root.add_child(_handle_button)
	_sync_handle_theme()

func _default_variant_accent() -> Color:
	return Color(0.78, 0.57, 0.30, 1.0) if _active_variant == 0 else Color(0.43, 0.69, 0.76, 1.0)

func _toggle_drawer() -> void:
	if _drawer_reveal > 0.999:
		if get_demo_state() != "READY":
			_drive_button.call("reset_demo")
		_set_drawer_open(false)
	else:
		_set_drawer_open(true)

func _set_drawer_open(opened: bool, animated: bool = true) -> void:
	if _drawer_tween != null and _drawer_tween.is_running():
		_drawer_tween.kill()
	var target: float = 1.0 if opened else 0.0
	if not animated:
		_drawer_reveal = target
		_sync_geometry()
		drawer_state_changed.emit(opened)
		return
	_drawer_tween = create_tween()
	_drawer_tween.tween_method(_set_drawer_reveal, _drawer_reveal, target, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opened else Tween.EASE_IN_OUT)
	_drawer_tween.finished.connect(func() -> void:
		drawer_state_changed.emit(opened)
	)

func _set_drawer_reveal(value: float) -> void:
	_drawer_reveal = clampf(value, 0.0, 1.0)
	_sync_geometry()

func _sync_geometry() -> void:
	if _mask == null or _panel_root == null:
		return
	var visible_width: float = lerpf(HANDLE_VISIBLE_WIDTH, _panel_width, _drawer_reveal)
	_mask.size = Vector2(visible_width, DRAWER_HEIGHT)
	_mask.custom_minimum_size = Vector2(visible_width, DRAWER_HEIGHT)
	_panel_root.position = Vector2(lerpf(-_panel_width + HANDLE_VISIBLE_WIDTH, 0.0, _drawer_reveal), 0.0)
	custom_minimum_size = Vector2(HANDLE_VISIBLE_WIDTH, DRAWER_HEIGHT)

func _sync_handle_theme() -> void:
	if _handle_button == null:
		return
	var base: Color = Color(0.035, 0.05, 0.06, 0.98)
	var edge: Color = _theme_accent.lightened(0.12)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = base
		style.border_color = Color(edge.r, edge.g, edge.b, 0.58 if state_name == "normal" else 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(0)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		_handle_button.add_theme_stylebox_override(state_name, style)
	_handle_button.queue_redraw()

func _on_demo_state_changed(state: String) -> void:
	demo_state_changed.emit(state)

func _draw() -> void:
	# Small exterior pull tab only; the full 520 px panel lives hidden inside and overlays outward when opened.
	var accent: Color = _theme_accent
	var panel_h: float = DRAWER_HEIGHT
	var x0: float = 0.0
	var x1: float = HANDLE_VISIBLE_WIDTH - 2.0
	var top: float = HANDLE_Y + 10.0
	var bottom: float = HANDLE_Y + HANDLE_HEIGHT - 10.0
	var tab := PackedVector2Array([
		Vector2(x0 + 6.0, top),
		Vector2(x1, top),
		Vector2(x1, bottom),
		Vector2(x0 + 6.0, bottom),
		Vector2(x0, bottom - 6.0),
		Vector2(x0, top + 6.0),
	])
	draw_colored_polygon(tab, Color(0.04, 0.055, 0.065, 0.92))
	var outline := tab.duplicate()
	outline.append(tab[0])
	draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.42), 1.0, false)
	draw_line(Vector2(x0 + 8.0, top + 12.0), Vector2(x0 + 8.0, bottom - 12.0), Color(accent.r, accent.g, accent.b, 0.62), 1.0, false)
	draw_line(Vector2(x0 + 12.0, top + 12.0), Vector2(x0 + 12.0, bottom - 12.0), Color(accent.r, accent.g, accent.b, 0.30), 1.0, false)
	var lamp_center := Vector2(x0 + 18.0, panel_h * 0.50)
	draw_circle(lamp_center, 7.0, Color(accent.r, accent.g, accent.b, 0.05))
	draw_circle(lamp_center, 4.2, Color(accent.r, accent.g, accent.b, 0.10))
	draw_circle(lamp_center, 1.6, Color(accent.r, accent.g, accent.b, 0.95))
