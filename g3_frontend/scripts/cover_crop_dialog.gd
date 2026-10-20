extends Window
class_name G3CoverCropDialog

signal apply_requested(source_path: String, title: String, front_start_px: int)

const IMAGE_AREA_HEIGHT: float = 340.0

var _source_path: String = ""
var _title: String = ""
var _image_orig_w: int = 0
var _image_orig_h: int = 0

var _image_area: Control
var _texture_rect: TextureRect
var _red_line: ColorRect
var _info_label: Label

var _current_front_px: int = 0
var _dragging: bool = false

func _ready() -> void:
	title = "手动调整 Front"
	size = Vector2i(720, 500)
	min_size = Vector2i(560, 420)
	transient = true
	exclusive = false
	close_requested.connect(hide)
	_build_ui()
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "手动调整 Front"
	heading.add_theme_font_size_override("font_size", 18)
	root.add_child(heading)

	var hint := Label.new()
	hint.text = "拖动红色竖线，确定 Front 的起点。线右侧即为要裁下的封面。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(hint)

	_image_area = Control.new()
	_image_area.custom_minimum_size = Vector2(0, IMAGE_AREA_HEIGHT)
	_image_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_area.clip_contents = true
	_image_area.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_image_area.gui_input.connect(_on_image_input)
	_image_area.resized.connect(_refresh_line)
	root.add_child(_image_area)

	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_area.add_child(_texture_rect)

	_red_line = ColorRect.new()
	_red_line.color = Color(1.0, 0.15, 0.2, 1.0)
	_red_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_area.add_child(_red_line)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	root.add_child(_info_label)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btns)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(hide)
	btns.add_child(cancel)

	var apply_btn := Button.new()
	apply_btn.text = "应用"
	apply_btn.pressed.connect(_on_apply_pressed)
	btns.add_child(apply_btn)

func show_for(source_path: String, title_text: String, initial_front_start_px: int) -> void:
	_source_path = source_path
	_title = title_text
	_current_front_px = max(0, initial_front_start_px)

	var img := Image.new()
	if img.load(source_path) != OK:
		push_warning("cover crop: load failed: %s" % source_path)
		return
	_image_orig_w = img.get_width()
	_image_orig_h = img.get_height()
	_texture_rect.texture = ImageTexture.create_from_image(img)

	title = "手动调整 · %s" % title_text
	popup_centered()
	await get_tree().process_frame
	await get_tree().process_frame
	_refresh_line()

func _display_rect() -> Rect2:
	var cw: float = _image_area.size.x
	var ch: float = _image_area.size.y
	if cw <= 0.0 or ch <= 0.0 or _image_orig_w <= 0 or _image_orig_h <= 0:
		return Rect2(0, 0, 0, 0)
	var orig_ar: float = float(_image_orig_w) / float(_image_orig_h)
	var cont_ar: float = cw / ch
	var dw: float = 0.0
	var dh: float = 0.0
	if orig_ar > cont_ar:
		dw = cw
		dh = dw / orig_ar
	else:
		dh = ch
		dw = dh * orig_ar
	var dx: float = (cw - dw) * 0.5
	var dy: float = (ch - dh) * 0.5
	return Rect2(dx, dy, dw, dh)

func _refresh_line() -> void:
	if _image_orig_w <= 0 or _red_line == null:
		return
	var dr: Rect2 = _display_rect()
	if dr.size.x <= 0.0:
		return
	var t: float = clampf(float(_current_front_px) / float(_image_orig_w), 0.0, 1.0)
	var x_in_area: float = dr.position.x + t * dr.size.x
	_red_line.position = Vector2(x_in_area - 1.0, dr.position.y)
	_red_line.size = Vector2(2.0, dr.size.y)
	_info_label.text = "Front 起点：%d px / 总宽 %d px（裁出的 Front 宽 %d px）" % [
		_current_front_px, _image_orig_w, _image_orig_w - _current_front_px
	]

func _on_image_input(event: InputEvent) -> void:
	if _image_orig_w <= 0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_update_front_from_mouse(mb.position.x)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_update_front_from_mouse(mm.position.x)

func _update_front_from_mouse(x_in_area: float) -> void:
	var dr: Rect2 = _display_rect()
	if dr.size.x <= 0.0:
		return
	var t: float = clampf((x_in_area - dr.position.x) / dr.size.x, 0.0, 1.0)
	_current_front_px = int(round(t * _image_orig_w))
	_refresh_line()

func _on_apply_pressed() -> void:
	if _source_path.is_empty() or _title.is_empty():
		return
	apply_requested.emit(_source_path, _title, _current_front_px)
	hide()