extends Control
## Production overlay drawer for the existing Slim Loader Button.
## The detail layout reserves only the fixed pull tab; the 534px panel slides
## out to its right without changing screenshot or metadata layout.

signal drawer_state_changed(expanded: bool)
signal reveal_changed

const DVD_LAUNCH_BUTTON_SCRIPT = preload("res://scripts/dvd_launch_button.gd")
const HANDLE_SCRIPT = preload("res://scripts/slim_loader_drawer_handle.gd")

const BASE_PANEL_SIZE := Vector2(504.0, 120.0)
const BASE_HANDLE_SIZE := Vector2(30.0, 72.0)

var _button: Button
var _mask: Control
var _panel_root: Control
var _handle: Control
var _panel_size: Vector2 = BASE_PANEL_SIZE
var _handle_size: Vector2 = BASE_HANDLE_SIZE
var _reveal: float = 0.0
var _expanded: bool = false
var _busy: bool = false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	z_index = 20
	custom_minimum_size = Vector2(_handle_size.x, _panel_size.y)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_build_drawer()
	if _button != null:
		_attach_button()
	_sync_geometry()


func set_panel_button(button: Button) -> void:
	_button = button
	if is_node_ready():
		_attach_button()
		_sync_geometry()


func get_panel_button() -> Button:
	return _button


func set_panel_size(panel_size: Vector2) -> void:
	_panel_size = Vector2(maxf(1.0, panel_size.x), maxf(1.0, panel_size.y))
	var scale_factor: float = _panel_size.x / BASE_PANEL_SIZE.x
	_handle_size = BASE_HANDLE_SIZE * scale_factor
	custom_minimum_size = Vector2(_handle_size.x, _panel_size.y)
	if _button != null and is_instance_valid(_button):
		_button.custom_minimum_size = _panel_size
		_button.size = _panel_size
	if _handle != null:
		_handle.size = _handle_size
	_sync_geometry()


func set_theme_accent(accent: Color) -> void:
	if _handle != null:
		_handle.call("set_accent", accent)


func set_busy(busy: bool) -> void:
	_busy = busy
	if _button != null:
		_button.disabled = busy
	if _handle != null:
		_handle.call("set_interactive", not busy)


func reset_drawer(animated: bool = false) -> void:
	set_expanded(false, animated)


func is_expanded() -> bool:
	return _expanded


func set_expanded(opened: bool, animated: bool = true) -> void:
	if _expanded == opened and is_equal_approx(_reveal, 1.0 if opened else 0.0):
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
	_expanded = opened
	if _handle != null:
		_handle.call("set_expanded", opened)
	if not animated:
		_reveal = 1.0 if opened else 0.0
		_sync_geometry()
		_update_button_input()
		drawer_state_changed.emit(opened)
		return

	_tween = create_tween()
	if opened:
		# Stage 1: release the worn latch; the panel gives a short mechanical kick.
		var detent: float = minf(0.065, 1.0)
		_tween.tween_interval(0.045)
		_tween.tween_method(_set_reveal, _reveal, detent, 0.095).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(0.045)
		# Stage 2: the drawer travels out, slows down and settles with a tiny stop.
		_tween.tween_method(_set_reveal, detent, 1.0, 0.285).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_reveal, 1.0, 0.985, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_method(_set_reveal, 0.985, 1.0, 0.055).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# Retraction has a short latch release followed by a firm inward pull.
		var latch: float = maxf(0.0, _reveal - 0.075)
		_tween.tween_method(_set_reveal, _reveal, latch, 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_interval(0.035)
		_tween.tween_method(_set_reveal, latch, 0.0, 0.235).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_update_button_input()
	_tween.finished.connect(_on_transition_finished.bind(opened))


func animate_insert() -> Tween:
	if _button == null:
		return null
	return _button.call("animate_insert") as Tween


func animate_eject() -> Tween:
	if _button == null:
		return null
	return _button.call("animate_eject") as Tween


func reset_disc() -> void:
	if _button != null:
		_button.call("reset_disc")


func apply_game_theme_palette(palette: Dictionary) -> void:
	if _button != null:
		_button.call("apply_game_theme_palette", palette)
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent_value: Variant = colors.get("accent", "")
	var accent: Color = Color(0.43, 0.69, 0.76, 1.0)
	if typeof(accent_value) == TYPE_COLOR:
		accent = accent_value
	elif not str(accent_value).strip_edges().is_empty():
		accent = Color.from_string(str(accent_value), accent)
	set_theme_accent(accent)


func reset_game_theme_palette() -> void:
	if _button != null:
		_button.call("reset_game_theme_palette")
	set_theme_accent(Color(0.43, 0.69, 0.76, 1.0))


func _build_drawer() -> void:
	_mask = Control.new()
	_mask.name = "SlimLoaderDrawerMask"
	_mask.clip_contents = true
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	_panel_root = Control.new()
	_panel_root.name = "SlimLoaderDrawerPanelRoot"
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_panel_root)

	_handle = HANDLE_SCRIPT.new()
	_handle.name = "SlimLoaderDrawerHandle"
	_handle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_handle.call("set_interactive", true)
	_handle.connect("pressed", _on_handle_pressed)
	add_child(_handle)
	_handle.z_index = 30


func _attach_button() -> void:
	if _button == null or not is_instance_valid(_button) or _panel_root == null:
		return
	if _button.get_parent() != null:
		_button.get_parent().remove_child(_button)
	_button.name = "DvdLaunchButton"
	_button.position = Vector2.ZERO
	_button.custom_minimum_size = _panel_size
	_button.size = _panel_size
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.focus_mode = Control.FOCUS_NONE
	_panel_root.add_child(_button)


func _set_reveal(value: float) -> void:
	_reveal = clampf(value, 0.0, 1.0)
	_sync_geometry()


func _sync_geometry() -> void:
	if _mask == null or _panel_root == null:
		return
	var visible_panel_width: float = _panel_size.x * _reveal
	_mask.position = Vector2.ZERO
	_mask.size = Vector2(_handle_size.x + visible_panel_width, _panel_size.y)
	_panel_root.position = Vector2(lerpf(-_panel_size.x, _handle_size.x - 4.0, _reveal), 0.0)
	_panel_root.size = _panel_size
	if _button != null and is_instance_valid(_button):
		_button.position = Vector2.ZERO
		_button.size = _panel_size
	if _handle != null:
		_handle.position = Vector2(0.0, (_panel_size.y - _handle_size.y) * 0.5)
		_handle.size = _handle_size
	reveal_changed.emit()


func _update_button_input() -> void:
	if _button == null or not is_instance_valid(_button):
		return
	var transitioning: bool = _tween != null and _tween.is_running()
	_button.mouse_filter = Control.MOUSE_FILTER_STOP if _expanded and not _busy and not transitioning else Control.MOUSE_FILTER_IGNORE


func _on_handle_pressed() -> void:
	if _busy or (_tween != null and _tween.is_running()):
		return
	set_expanded(not _expanded)


func _on_transition_finished(opened: bool) -> void:
	_reveal = 1.0 if opened else 0.0
	_tween = null
	_sync_geometry()
	_update_button_input()
	drawer_state_changed.emit(opened)
