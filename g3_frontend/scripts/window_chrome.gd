extends Control
class_name G3WindowChrome

class IconButton extends Button:
	var icon_type: String = "minimize"
	var icon_color: Color = Color.WHITE
	var icon_hover_color: Color = Color.WHITE
	var _hovered: bool = false

	func _ready() -> void:
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func _on_enter() -> void:
		_hovered = true
		queue_redraw()

	func _on_exit() -> void:
		_hovered = false
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var s: float = 5.0
		var col: Color = icon_hover_color if _hovered else icon_color
		var w: float = 1.5
		match icon_type:
			"minimize":
				draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, w, true)
			"maximize":
				draw_rect(Rect2(c + Vector2(-s, -s), Vector2(s * 2.0, s * 2.0)), col, false, w)
			"restore":
				draw_rect(Rect2(c + Vector2(-s + 2.0, -s + 2.0), Vector2(s * 2.0 - 2.0, s * 2.0 - 2.0)), col, false, w)
				draw_line(c + Vector2(-s, -s + 2.0), c + Vector2(-s, -s), col, w, true)
				draw_line(c + Vector2(-s, -s), c + Vector2(s - 2.0, -s), col, w, true)
				draw_line(c + Vector2(s - 2.0, -s), c + Vector2(s - 2.0, -s + 2.0), col, w, true)
			"close":
				draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, w, true)
				draw_line(c + Vector2(s, -s), c + Vector2(-s, s), col, w, true)

const TITLE_BAR_HEIGHT: float = 34.0
const BUTTON_WIDTH: float = 44.0
const RESIZE_MARGIN: float = 6.0
const CORNER_MARGIN: float = 10.0

var _title_bar: Panel
var _title_label: Label
var _minimize_button: IconButton
var _maximize_button: IconButton
var _close_button: IconButton
var _text_color: Color = Color(0.93, 1.0, 1.0, 1.0)
var _muted_color: Color = Color(0.55, 0.70, 0.72, 1.0)
var _accent_color: Color = Color(0.20, 0.82, 0.76, 1.0)
var _base_color: Color = Color(0.025, 0.085, 0.105, 1.0)
var _is_maximized: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_title_bar()
	_build_resize_handles()
	set_process(true)

func set_theme_colors(text: Color, muted: Color, accent: Color, base: Color) -> void:
	_text_color = text
	_muted_color = muted
	_accent_color = accent
	_base_color = base
	if _title_bar != null:
		_apply_theme()

func _build_title_bar() -> void:
	_title_bar = Panel.new()
	_title_bar.anchor_left = 0.0
	_title_bar.anchor_right = 1.0
	_title_bar.anchor_top = 0.0
	_title_bar.anchor_bottom = 0.0
	_title_bar.offset_left = 0.0
	_title_bar.offset_right = 0.0
	_title_bar.offset_top = 0.0
	_title_bar.offset_bottom = TITLE_BAR_HEIGHT
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.z_index = 100
	_title_bar.gui_input.connect(_on_title_bar_input)
	add_child(_title_bar)

	_title_label = Label.new()
	_title_label.position = Vector2(12.0, 0.0)
	_title_label.size = Vector2(240.0, TITLE_BAR_HEIGHT)
	_title_label.text = "G3"
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_bar.add_child(_title_label)

	_minimize_button = _make_window_button("minimize", 2)
	_minimize_button.pressed.connect(_minimize_window)
	_title_bar.add_child(_minimize_button)

	_maximize_button = _make_window_button("maximize", 1)
	_maximize_button.pressed.connect(_toggle_maximize)
	_title_bar.add_child(_maximize_button)

	_close_button = _make_window_button("close", 0)
	_close_button.pressed.connect(_close_window)
	_title_bar.add_child(_close_button)

	_apply_theme()

func _make_window_button(icon_type: String, slot_from_right: int) -> IconButton:
	var button: IconButton = IconButton.new()
	button.icon_type = icon_type
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.offset_left = -BUTTON_WIDTH * float(slot_from_right + 1)
	button.offset_right = -BUTTON_WIDTH * float(slot_from_right)
	button.offset_top = 0.0
	button.offset_bottom = TITLE_BAR_HEIGHT
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button

func _apply_theme() -> void:
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = _base_color.darkened(0.24)
	bar_style.border_width_bottom = 0
	_title_bar.add_theme_stylebox_override("panel", bar_style)
	_title_label.add_theme_color_override("font_color", _text_color)

	for button: IconButton in [_minimize_button, _maximize_button, _close_button]:
		if button == null:
			continue
		button.add_theme_stylebox_override("normal", _button_style(Color(0.0, 0.0, 0.0, 0.0)))
		button.add_theme_stylebox_override("hover", _button_style(_accent_color.darkened(0.62)))
		button.add_theme_stylebox_override("pressed", _button_style(_accent_color.darkened(0.48)))
		var dim: Color = _muted_color
		dim.a = 0.30
		button.icon_color = dim
		button.icon_hover_color = _text_color
		button.queue_redraw()

func _button_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	return style

func _on_title_bar_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	if mouse_event.double_click:
		_toggle_maximize()
		return
	var window: Window = get_window()
	if window is Window:
		window.start_drag()

func _minimize_window() -> void:
	var window: Window = get_window()
	if window != null:
		window.mode = Window.MODE_MINIMIZED

func _toggle_maximize() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.borderless = true
	if window.mode == Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN
	_refresh_maximize_glyph()

func _close_window() -> void:
	get_tree().quit()

func _process(_delta: float) -> void:
	_refresh_maximize_glyph()

func _refresh_maximize_glyph() -> void:
	if _maximize_button == null:
		return
	var window: Window = get_window()
	if window == null:
		return
	var now_maximized: bool = window.mode == Window.MODE_FULLSCREEN
	if now_maximized == _is_maximized:
		return
	_is_maximized = now_maximized
	_maximize_button.icon_type = "restore" if now_maximized else "maximize"
	_maximize_button.queue_redraw()

func _build_resize_handles() -> void:
	_add_resize_handle(DisplayServer.WINDOW_EDGE_TOP, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, RESIZE_MARGIN, Control.CURSOR_VSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_BOTTOM, 0.0, 1.0, 1.0, 1.0, 0.0, -RESIZE_MARGIN, 0.0, 0.0, Control.CURSOR_VSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_LEFT, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, RESIZE_MARGIN, 0.0, Control.CURSOR_HSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_RIGHT, 1.0, 0.0, 1.0, 1.0, -RESIZE_MARGIN, 0.0, 0.0, 0.0, Control.CURSOR_HSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_TOP_LEFT, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, CORNER_MARGIN, CORNER_MARGIN, Control.CURSOR_FDIAGSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_TOP_RIGHT, 1.0, 0.0, 1.0, 0.0, -CORNER_MARGIN, 0.0, 0.0, CORNER_MARGIN, Control.CURSOR_BDIAGSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_BOTTOM_LEFT, 0.0, 1.0, 0.0, 1.0, 0.0, -CORNER_MARGIN, CORNER_MARGIN, 0.0, Control.CURSOR_BDIAGSIZE)
	_add_resize_handle(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT, 1.0, 1.0, 1.0, 1.0, -CORNER_MARGIN, -CORNER_MARGIN, 0.0, 0.0, Control.CURSOR_FDIAGSIZE)

func _add_resize_handle(
	edge: int,
	anchor_left_value: float,
	anchor_top_value: float,
	anchor_right_value: float,
	anchor_bottom_value: float,
	offset_left_value: float,
	offset_top_value: float,
	offset_right_value: float,
	offset_bottom_value: float,
	cursor_shape: int
) -> void:
	var handle: Control = Control.new()
	handle.anchor_left = anchor_left_value
	handle.anchor_top = anchor_top_value
	handle.anchor_right = anchor_right_value
	handle.anchor_bottom = anchor_bottom_value
	handle.offset_left = offset_left_value
	handle.offset_top = offset_top_value
	handle.offset_right = offset_right_value
	handle.offset_bottom = offset_bottom_value
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = cursor_shape
	handle.z_index = 110
	handle.gui_input.connect(_on_resize_input.bind(edge))
	add_child(handle)

func _on_resize_input(event: InputEvent, edge: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	var window: Window = get_window()
	if window == null or window.mode != Window.MODE_WINDOWED:
		return
	window.start_resize(edge)