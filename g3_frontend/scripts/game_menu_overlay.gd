extends Control
class_name G3GameMenuOverlay

## WB-04.1-E｜游戏版块右键菜单的通用外壳。
##
## 背景：原来的实现是 PopupPanel（独立/嵌入式子窗口）。毛玻璃 shader 依赖
## hint_screen_texture 取"背后画面"，但在子窗口里取到的是子窗口自己的空
## backbuffer（实测为黑），因此无法得到模糊背景。
## 折中方案：改成挂在主 UI CanvasLayer 上的普通 Control ——
## 全屏点击捕获层 + 内容自适应的毛玻璃面板，shader 与剧集窗口完全相同
## （shaders/glass_panel.gdshader，参数一致），从而能真正采样到背后的海报墙。
##
## 交互与 PopupPanel 常用行为保持一致：点击外部关闭、Esc 关闭、窗口尺寸变化关闭、
## 点击菜单项触发动作后关闭；菜单位置按可视区域夹取，不改变菜单项顺序与间距。

signal dismissed

const GLASS_SHADER: Shader = preload("res://shaders/glass_panel.gdshader")
# 与 movie_episode_drawer.GLASS_TINT 同族配色；alpha 提高到 0.80，
# 保证在亮封面（如浅色海报）上方文字仍然清晰。
const GLASS_TINT: Color = Color(0.02, 0.05, 0.08, 0.80)
const GLASS_BLUR: float = 2.5
const EDGE_MARGIN: float = 6.0
const CONTENT_MARGIN: int = 10
const ITEM_SEPARATION: int = 4
# WB-04.2-B：菜单项悬停反馈。整行铺一层浅蓝灰半透明底色（有效 alpha ≈0.10），
# 危险操作改用克制的暖红，避免全部项目同色。
const ITEM_HOVER_BG: Color = Color(0.58, 0.74, 0.94, 0.12)
const ITEM_HOVER_BG_DANGER: Color = Color(0.90, 0.40, 0.36, 0.16)
const ITEM_HOVER_FADE: float = 0.12
const ITEM_TEXT: Color = Color(0.90, 0.90, 0.90)
const ITEM_TEXT_HOVER: Color = Color(1.0, 1.0, 1.0)
const ITEM_DANGER_TEXT: Color = Color(0.94, 0.60, 0.57)
const ITEM_DANGER_TEXT_HOVER: Color = Color(1.0, 0.74, 0.71)

var _panel: PanelContainer
var _glass: ColorRect
var _margin: MarginContainer
var _root: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_backdrop_input)
	_build_shell()
	_build_content()
	visible = false
	get_viewport().size_changed.connect(_on_viewport_size_changed)

# --- 供子类实现 ---
func _build_content() -> void:
	pass

func _build_shell() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# 毛玻璃层：铺满面板、忽略鼠标，位于内容之下
	_glass = ColorRect.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.color = Color.WHITE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter("tint", GLASS_TINT)
	mat.set_shader_parameter("blur_amount", GLASS_BLUR)
	_glass.material = mat
	_panel.add_child(_glass)

	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", CONTENT_MARGIN)
	_margin.add_theme_constant_override("margin_top", CONTENT_MARGIN)
	_margin.add_theme_constant_override("margin_right", CONTENT_MARGIN)
	_margin.add_theme_constant_override("margin_bottom", CONTENT_MARGIN)
	_panel.add_child(_margin)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", ITEM_SEPARATION)
	_margin.add_child(_root)

## 生成一个整行可点击的菜单项：文字 + 铺满整行的悬停底色（0.12s 渐入渐出）。
## danger = true 用于「移除」这类危险操作，只改文字与底色的色调，不改字号/间距/回调。
func make_item(label_text: String, font_size: int, min_size: Vector2, danger: bool = false) -> Button:
	var button := Button.new()
	button.text = label_text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = min_size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ITEM_DANGER_TEXT if danger else ITEM_TEXT)
	button.add_theme_color_override("font_hover_color", ITEM_DANGER_TEXT_HOVER if danger else ITEM_TEXT_HOVER)
	button.add_theme_color_override("font_pressed_color", ITEM_DANGER_TEXT_HOVER if danger else ITEM_TEXT_HOVER)

	var tint: Color = ITEM_HOVER_BG_DANGER if danger else ITEM_HOVER_BG
	var hover := ColorRect.new()
	hover.name = "HoverBg"
	# 画在按钮自身绘制之下（文字仍在最上层），且不参与鼠标命中
	hover.show_behind_parent = true
	hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hover.color = Color(tint.r, tint.g, tint.b, 0.0)
	button.add_child(hover)

	button.mouse_entered.connect(_fade_item_hover.bind(button, hover, tint, tint.a))
	button.mouse_exited.connect(_fade_item_hover.bind(button, hover, tint, 0.0))
	_root.add_child(button)
	return button

func _fade_item_hover(button: Button, hover: ColorRect, tint: Color, target_alpha: float) -> void:
	if not is_instance_valid(hover) or not is_instance_valid(button):
		return
	if button.has_meta("hover_tween"):
		var running: Tween = button.get_meta("hover_tween")
		if running != null and running.is_valid():
			running.kill()
	var from_alpha: float = hover.color.a
	if is_equal_approx(from_alpha, target_alpha):
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var apply_alpha := func(alpha: float) -> void:
		if is_instance_valid(hover):
			hover.color = Color(tint.r, tint.g, tint.b, alpha)
	tween.tween_method(apply_alpha, from_alpha, target_alpha, ITEM_HOVER_FADE)
	button.set_meta("hover_tween", tween)

func show_menu_at(screen_position: Vector2, min_width: float = 0.0) -> void:
	visible = true
	move_to_front()
	_reset_item_hover()
	if min_width > 0.0:
		_panel.custom_minimum_size.x = min_width
	_panel.reset_size()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sz: Vector2 = _panel.size
	var max_x: float = maxf(EDGE_MARGIN, vp.x - sz.x - EDGE_MARGIN)
	var max_y: float = maxf(EDGE_MARGIN, vp.y - sz.y - EDGE_MARGIN)
	_panel.position = Vector2(
		clampf(screen_position.x, EDGE_MARGIN, max_x),
		clampf(screen_position.y, EDGE_MARGIN, max_y)
	)

func _reset_item_hover() -> void:
	# 重新打开菜单时清掉上一次残留的悬停底色（鼠标可能已不在任何项目上）
	for child in _root.get_children():
		if not (child is Button):
			continue
		var button: Button = child as Button
		if button.has_meta("hover_tween"):
			var running: Tween = button.get_meta("hover_tween")
			if running != null and running.is_valid():
				running.kill()
		var hover: ColorRect = button.get_node_or_null("HoverBg") as ColorRect
		if hover != null:
			hover.color = Color(hover.color.r, hover.color.g, hover.color.b, 0.0)

func close() -> void:
	if not visible:
		return
	visible = false
	dismissed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	# 点击菜单面板以外区域 → 关闭（与 PopupPanel 行为一致）
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	get_viewport().set_input_as_handled()
	close()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()

func _on_viewport_size_changed() -> void:
	# 窗口尺寸变了就不再保留旧位置的菜单，避免错位
	if visible:
		close()
