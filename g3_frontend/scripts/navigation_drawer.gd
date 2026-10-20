extends Control
class_name G3NavigationDrawer

signal section_requested(section_id: String)
signal section_long_pressed(section_id: String)
signal opened_changed(opened: bool)

const GLOW_SHADER: Shader = preload("res://shaders/glow_line.gdshader")
const LONG_PRESS_SECONDS: float = 1.5
const ICON_FILL_SHADER: Shader = preload("res://shaders/icon_fill.gdshader")
# 只有这些图标的"长按"才有意义（对应 main.gd 的切库逻辑）
const LONG_PRESS_SECTIONS: Array[String] = ["MOVIES"]

const CONTENT_SECTIONS: Array[Dictionary] = [
	{"id":"GAMES", "tip":"游戏"}, {"id":"MOVIES", "tip":"电影"},
	{"id":"COMICS", "tip":"空间展厅（实验）"}, {"id":"MUSIC", "tip":"音乐"},
]
const SYSTEM_SECTIONS: Array[Dictionary] = [
	{"id":"SYSTEM", "tip":"系统"},
]

# ============================================================
# 布局参数（调这里）
# ============================================================

const TOP_OFFSET: float = 34.0

const GLOW_WIDTH: float = 180.0
const GLOW_HEIGHT: float = 2.0
const GLOW_Y_OFFSET: float = 3.0
const GLOW_IDLE_BRIGHTNESS: float = 0.35
const GLOW_HOVER_BRIGHTNESS: float = 1.00
const GLOW_BRIGHTNESS_EASE: float = 12.0
const GLOW_EDGE_POWER: float = 1.6

const GLOW_OPEN_DURATION: float = 0.75
const GLOW_CLOSE_DURATION: float = 0.55

const GLOW_BREATH_AMPLITUDE: float = 0.12
const GLOW_BREATH_AMPLITUDE_OPEN: float = 0.06
const GLOW_BREATH_SPEED: float = 1.6

const DRAWER_TOP_GAP: float = 10.0
const EXPANDED_HEIGHT: float = 64.0
const CORNER_RADIUS: int = 6
const DRAWER_OPEN_DURATION: float = 0.32
const DRAWER_CLOSE_DURATION: float = 0.26
const DRAWER_OPEN_DELAY: float = 0.15
const DRAWER_CLOSE_DELAY: float = 0.05
const HIDE_DELAY: float = 0.35
const TITLE_BAR_HEIGHT: float = 34.0
const HOT_ENTER_DELAY: float = 0.12

const DRAWER_BUTTON: float = 44.0
const DRAWER_BUTTON_GAP: float = 10.0
const DRAWER_SIDE_PADDING: float = 16.0
const DRAWER_VERTICAL_PADDING: float = 10.0

const HOT_ZONE_WIDTH: float = 240.0
const HOT_ZONE_HEIGHT: float = 36.0

const DRAWER_BG: Color = Color(0.02, 0.06, 0.09, 0.55)

const ACTIVE_GLOW_ALPHA: float = 0.20
const INACTIVE_DIM: float = 0.62

# ============================================================
# 状态
# ============================================================

var _glow: ColorRect
var _glow_material: ShaderMaterial
var _hot_zone: Control
var _drawer: Panel
var _drawer_style: StyleBoxFlat
var _row: HBoxContainer
var _buttons: Dictionary = {}
var _separators: Array[ColorRect] = []
var _open: bool = false
var _tween_drawer: Tween
var _tween_glow: Tween
var _hide_timer: float = 0.0
var _accent: Color = Color(0.20, 0.82, 0.76, 1.0)
var _muted: Color = Color(0.55, 0.70, 0.72, 1.0)
var _expanded_width: float = 0.0
var _current_section: String = "GAMES"
var _glow_brightness: float = GLOW_IDLE_BRIGHTNESS
var _glow_brightness_target: float = GLOW_IDLE_BRIGHTNESS
var _hot_enter_timer: float = 0.0
var _press_active: bool = false
var _press_timer: float = 0.0
var _press_long_active: bool = false
var _pressing_section: String = ""
var _long_press_color: Color = Color(0.95, 0.22, 0.72)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_build_glow()
	_build_hot_zone()
	_build_drawer()
	set_process(true)

func _build_glow() -> void:
	_glow = ColorRect.new()
	_glow.anchor_left = 0.5
	_glow.anchor_right = 0.5
	_glow.anchor_top = 0.0
	_glow.anchor_bottom = 0.0
	_glow.offset_left = -GLOW_WIDTH * 0.5
	_glow.offset_right = GLOW_WIDTH * 0.5
	_glow.offset_top = TOP_OFFSET + GLOW_Y_OFFSET
	_glow.offset_bottom = TOP_OFFSET + GLOW_Y_OFFSET + GLOW_HEIGHT
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.color = Color(1, 1, 1, 1)
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GLOW_SHADER
	_glow_material.set_shader_parameter("glow_color", _accent)
	_glow_material.set_shader_parameter("brightness", _glow_brightness)
	_glow_material.set_shader_parameter("edge_power", GLOW_EDGE_POWER)
	_glow.material = _glow_material
	add_child(_glow)

func _build_hot_zone() -> void:
	_hot_zone = Control.new()
	_hot_zone.anchor_left = 0.5
	_hot_zone.anchor_right = 0.5
	_hot_zone.anchor_top = 0.0
	_hot_zone.anchor_bottom = 0.0
	_hot_zone.offset_left = -HOT_ZONE_WIDTH * 0.5
	_hot_zone.offset_right = HOT_ZONE_WIDTH * 0.5
	_hot_zone.offset_top = TOP_OFFSET
	_hot_zone.offset_bottom = TOP_OFFSET + HOT_ZONE_HEIGHT
	_hot_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hot_zone.z_as_relative = false
	_hot_zone.z_index = 0
	add_child(_hot_zone)

func _build_drawer() -> void:
	_drawer = Panel.new()
	_drawer.anchor_left = 0.5
	_drawer.anchor_right = 0.5
	_drawer.anchor_top = 0.0
	_drawer.anchor_bottom = 0.0
	_drawer.clip_contents = true
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.z_as_relative = false
	_drawer.z_index = 10

	var button_count: int = CONTENT_SECTIONS.size() + SYSTEM_SECTIONS.size()
	var row_width: float = float(button_count) * DRAWER_BUTTON + float(button_count - 1) * DRAWER_BUTTON_GAP
	_expanded_width = row_width + DRAWER_SIDE_PADDING * 2.0

	_drawer_style = StyleBoxFlat.new()
	_drawer_style.bg_color = DRAWER_BG
	_drawer_style.set_corner_radius_all(CORNER_RADIUS)
	_drawer_style.shadow_color = Color(0, 0, 0, 0.35)
	_drawer_style.shadow_size = 8
	_drawer_style.shadow_offset = Vector2(0, 2)
	_drawer.add_theme_stylebox_override("panel", _drawer_style)

	var open_top: float = TOP_OFFSET + DRAWER_TOP_GAP
	_drawer.offset_left = -_expanded_width * 0.5
	_drawer.offset_right = _expanded_width * 0.5
	_drawer.offset_top = open_top - EXPANDED_HEIGHT
	_drawer.offset_bottom = open_top
	_drawer.modulate.a = 0.0
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.visible = false
	add_child(_drawer)

	_row = HBoxContainer.new()
	_row.anchor_left = 0.0
	_row.anchor_right = 1.0
	_row.anchor_top = 0.0
	_row.anchor_bottom = 0.0
	_row.offset_left = DRAWER_SIDE_PADDING
	_row.offset_right = -DRAWER_SIDE_PADDING
	_row.offset_top = DRAWER_VERTICAL_PADDING
	_row.offset_bottom = EXPANDED_HEIGHT - DRAWER_VERTICAL_PADDING
	_row.add_theme_constant_override("separation", int(DRAWER_BUTTON_GAP))
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.add_child(_row)

	var total: int = CONTENT_SECTIONS.size() + SYSTEM_SECTIONS.size()
	var idx: int = 0
	for entry: Dictionary in CONTENT_SECTIONS:
		var is_last: bool = (idx == total - 1)
		_add_button(entry, is_last)
		idx += 1
	for entry: Dictionary in SYSTEM_SECTIONS:
		var is_last: bool = (idx == total - 1)
		_add_button(entry, is_last)
		idx += 1

func _add_button(entry: Dictionary, is_last: bool) -> void:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(DRAWER_BUTTON, DRAWER_BUTTON)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = false

	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("disabled", empty)

	# 分隔线作为按钮子节点（在右侧，用锚点定位）
	if not is_last:
		var sep := ColorRect.new()
		sep.anchor_left = 1.0
		sep.anchor_right = 1.0
		sep.anchor_top = 0.5
		sep.anchor_bottom = 0.5
		sep.offset_left = (DRAWER_BUTTON_GAP * 0.5) - 0.5
		sep.offset_right = (DRAWER_BUTTON_GAP * 0.5) + 0.5
		sep.offset_top = -11.0
		sep.offset_bottom = 11.0
		sep.color = _muted
		sep.color.a = 0.18
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sep.z_index = 1
		button.add_child(sep)
		_separators.append(sep)

	var section_id: String = str(entry["id"])
	button.tooltip_text = str(entry.get("tip", ""))
	var icon_id: String = "spatial" if section_id == "COMICS" else section_id.to_lower()
	var texture := _load_icon(icon_id)
	if texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = texture
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 11.0
		icon_rect.offset_top = 11.0
		icon_rect.offset_right = -11.0
		icon_rect.offset_bottom = -11.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.modulate = Color(1, 1, 1, 1)
		icon_rect.z_index = 2
		var icon_mat := ShaderMaterial.new()
		icon_mat.shader = ICON_FILL_SHADER
		icon_mat.set_shader_parameter("base_color", _muted)
		icon_mat.set_shader_parameter("fill_color", _long_press_color)
		icon_mat.set_shader_parameter("fill", 0.0)
		icon_rect.material = icon_mat
		icon_rect.set_meta("icon_mat", icon_mat)
		button.add_child(icon_rect)

	button.button_down.connect(func(): _on_button_down(section_id))
	button.button_up.connect(func(): _on_button_up(section_id))
	button.mouse_entered.connect(func(): _animate_button(button, true))
	button.mouse_exited.connect(func(): _animate_button(button, false))
	_buttons[section_id] = button
	_row.add_child(button)

func _load_icon(icon_id: String) -> Texture2D:
	var path: String = "res://assets/icons/%s.svg" % icon_id
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var svg_text: String = file.get_as_text()
	file.close()
	var image := Image.new()
	var err: int = image.load_svg_from_string(svg_text, 3.0)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _reveal() -> void:
	if _open:
		return
	_open = true
	opened_changed.emit(true)
	_drawer.visible = true
	if _tween_glow != null and _tween_glow.is_valid():
		_tween_glow.kill()
	if _tween_drawer != null and _tween_drawer.is_valid():
		_tween_drawer.kill()

	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var open_top: float = TOP_OFFSET + DRAWER_TOP_GAP

	_tween_glow = create_tween().set_parallel(true)
	_tween_glow.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_glow.tween_property(_glow, "offset_left", -_expanded_width * 0.5, GLOW_OPEN_DURATION)
	_tween_glow.tween_property(_glow, "offset_right", _expanded_width * 0.5, GLOW_OPEN_DURATION)

	_tween_drawer = create_tween().set_parallel(true)
	_tween_drawer.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_drawer.tween_property(_drawer, "offset_top", open_top, DRAWER_OPEN_DURATION).set_delay(DRAWER_OPEN_DELAY)
	_tween_drawer.tween_property(_drawer, "offset_bottom", open_top + EXPANDED_HEIGHT, DRAWER_OPEN_DURATION).set_delay(DRAWER_OPEN_DELAY)
	_tween_drawer.tween_property(_drawer, "modulate:a", 1.0, DRAWER_OPEN_DURATION).set_delay(DRAWER_OPEN_DELAY)
	_tween_drawer.chain().tween_callback(func():
		if _open:
			_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	)

func _close() -> void:
	if not _open:
		return
	_open = false
	opened_changed.emit(false)
	if _tween_glow != null and _tween_glow.is_valid():
		_tween_glow.kill()
	if _tween_drawer != null and _tween_drawer.is_valid():
		_tween_drawer.kill()

	var open_top: float = TOP_OFFSET + DRAWER_TOP_GAP

	_tween_drawer = create_tween().set_parallel(true)
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween_drawer.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_drawer.tween_property(_drawer, "offset_top", open_top - EXPANDED_HEIGHT, DRAWER_CLOSE_DURATION)
	_tween_drawer.tween_property(_drawer, "offset_bottom", open_top, DRAWER_CLOSE_DURATION)
	_tween_drawer.tween_property(_drawer, "modulate:a", 0.0, DRAWER_CLOSE_DURATION)
	_tween_drawer.chain().tween_callback(func():
		if not _open:
			_drawer.visible = false
			_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

	_tween_glow = create_tween().set_parallel(true)
	_tween_glow.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_glow.tween_property(_glow, "offset_left", -GLOW_WIDTH * 0.5, GLOW_CLOSE_DURATION).set_delay(DRAWER_CLOSE_DELAY)
	_tween_glow.tween_property(_glow, "offset_right", GLOW_WIDTH * 0.5, GLOW_CLOSE_DURATION).set_delay(DRAWER_CLOSE_DELAY)

func _process(delta: float) -> void:
	if _glow == null or _hot_zone == null or _drawer == null:
		return
	# 长按计时
	if _press_active:
		_press_timer += delta
		var t: float = clampf(_press_timer / LONG_PRESS_SECONDS, 0.0, 1.0)
		_update_press_visual(t)
		if t >= 1.0 and not _press_long_active:
			_press_long_active = true

	var mouse: Vector2 = get_viewport().get_mouse_position()

	if mouse.y < TITLE_BAR_HEIGHT:
		if _open:
			_close()
		_hot_enter_timer = 0.0
		_hide_timer = 0.0
		_glow_brightness_target = GLOW_IDLE_BRIGHTNESS
		return

	var in_hot: bool = _hot_zone.get_global_rect().has_point(mouse)
	_glow_brightness_target = GLOW_HOVER_BRIGHTNESS if (in_hot or _open) else GLOW_IDLE_BRIGHTNESS

	var t: float = Time.get_ticks_msec() / 1000.0
	var breath_amplitude: float = GLOW_BREATH_AMPLITUDE_OPEN if _open else GLOW_BREATH_AMPLITUDE
	if not in_hot or _open:
		_glow_brightness_target += sin(t * GLOW_BREATH_SPEED) * breath_amplitude

	_glow_brightness = lerpf(
		_glow_brightness,
		clampf(_glow_brightness_target, 0.0, 1.0),
		1.0 - exp(-delta * GLOW_BRIGHTNESS_EASE)
	)
	_glow_material.set_shader_parameter("brightness", _glow_brightness)

	if not _open:
		if in_hot:
			_hot_enter_timer += delta
			if _hot_enter_timer >= HOT_ENTER_DELAY:
				_hot_enter_timer = 0.0
				_reveal()
		else:
			_hot_enter_timer = 0.0
		return

	var in_drawer: bool = _drawer.get_global_rect().has_point(mouse)
	if in_hot or in_drawer:
		_hide_timer = 0.0
	else:
		_hide_timer += delta
		if _hide_timer >= HIDE_DELAY:
			_close()
			_hide_timer = 0.0

func set_active_section(section_id: String) -> void:
	_current_section = section_id
	_apply_button_styles()

func _apply_button_styles() -> void:
	for key: Variant in _buttons.keys():
		var button: Button = _buttons[key]
		var is_active: bool = str(key) == _current_section
		var is_pressing: bool = str(key) == _pressing_section and _press_active
		button.modulate.a = 1.0 if is_active else INACTIVE_DIM

		var style := StyleBoxFlat.new()
		if is_active or is_pressing:
			var glow: Color = _accent
			glow.a = ACTIVE_GLOW_ALPHA
			style.bg_color = glow
			style.set_corner_radius_all(8)
		else:
			style.bg_color = Color(0, 0, 0, 0)

		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)
		button.add_theme_stylebox_override("disabled", style)

func set_theme_colors(accent: Color, muted: Color) -> void:
	_accent = accent
	_muted = muted
	if _glow_material != null:
		_glow_material.set_shader_parameter("glow_color", _accent)
	for key: Variant in _buttons.keys():
		var button: Button = _buttons[key]
		var icon_rect: TextureRect = null
		for child: Node in button.get_children():
			if child is TextureRect:
				icon_rect = child as TextureRect
				break
		if icon_rect != null:
			var mat: ShaderMaterial = icon_rect.get_meta("icon_mat", null)
			if mat != null:
				mat.set_shader_parameter("base_color", _muted)
	# 分隔线颜色同步
	var sep_color: Color = _muted
	sep_color.a = 0.18
	for sep in _separators:
		if is_instance_valid(sep):
			sep.color = sep_color
	set_active_section(_current_section)

func set_long_press_color(color: Color) -> void:
	_long_press_color = color
	for key: Variant in _buttons.keys():
		var button: Button = _buttons[key]
		var icon_rect: TextureRect = null
		for child: Node in button.get_children():
			if child is TextureRect:
				icon_rect = child as TextureRect
				break
		if icon_rect != null:
			var mat: ShaderMaterial = icon_rect.get_meta("icon_mat", null)
			if mat != null:
				mat.set_shader_parameter("fill_color", _long_press_color)

func _animate_button(button: Button, active: bool) -> void:
	var icon_rect: TextureRect = null
	for child in button.get_children():
		if child is TextureRect:
			icon_rect = child
			break
	if icon_rect == null:
		return
	icon_rect.pivot_offset = icon_rect.size * 0.5
	var target_scale := Vector2.ONE * (1.10 if active else 1.0)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_rect, "scale", target_scale, 0.16)

func _on_button_down(section_id: String) -> void:
	if not LONG_PRESS_SECTIONS.has(section_id):
		return
	_press_active = true
	_press_timer = 0.0
	_press_long_active = false
	_pressing_section = section_id
	_set_icon_fill(section_id, 0.0)
	_apply_button_styles()

func _on_button_up(section_id: String) -> void:
	if not LONG_PRESS_SECTIONS.has(section_id):
		# 其他图标：一律走短按
		section_requested.emit(section_id)
		return
	if not _press_active:
		return
	var elapsed: float = _press_timer
	_press_active = false
	_press_long_active = false
	_press_timer = 0.0
	if elapsed >= LONG_PRESS_SECONDS:
		section_long_pressed.emit(section_id)
	else:
		section_requested.emit(section_id)
	_set_icon_fill(section_id, 0.0)
	_pressing_section = ""
	_apply_button_styles()

func _update_press_visual(t: float) -> void:
	if _pressing_section.is_empty():
		return
	_set_icon_fill(_pressing_section, t)

func _set_icon_fill(section_id: String, t: float) -> void:
	var btn: Button = _buttons.get(section_id, null)
	if btn == null:
		return
	var icon_rect: TextureRect = null
	for child in btn.get_children():
		if child is TextureRect:
			icon_rect = child
			break
	if icon_rect == null:
		return
	var mat: ShaderMaterial = icon_rect.get_meta("icon_mat", null)
	if mat != null:
		mat.set_shader_parameter("fill", clampf(t, 0.0, 1.0))
