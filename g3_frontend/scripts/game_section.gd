extends Node3D
class_name G3GameSection

signal selection_changed(index: int, game: Dictionary)
signal game_double_clicked(game: Dictionary)
signal add_game_requested()
signal game_context_requested(game: Dictionary, position: Vector2)
signal blank_context_requested(position: Vector2)
signal game_removed(item_id: String)
signal batch_scrape_requested(item_ids: Array)

# ============================================================
# 布局
# ============================================================
const UI_BASE_W: float = 1920.0
const UI_BASE_H: float = 1080.0
const UI_SCALE_MIN: float = 0.62
const UI_SCALE_MAX: float = 1.30
# 字号单独一条曲线：下限抬高，避免小窗口下字看不清
const FONT_SCALE_MIN: float = 0.90
const FONT_SCALE_MAX: float = 1.30

const SIDEBAR_W_BASE: float = 280.0
const SIDEBAR_PAD_BASE: float = 12.0
const SIDEBAR_ITEM_H_BASE: float = 28.0
const SIDEBAR_LOGO_SZ_BASE: float = 22.0
const SIDEBAR_HEADER_H_BASE: float = 40.0
const SIDEBAR_SEARCH_H_BASE: float = 34.0
const SIDEBAR_FOOTER_H_BASE: float = 52.0

const GRID_PADDING_BASE: float = 24.0

# 导航抽屉的几何（跟 navigation_drawer.gd 里的常量同步）：
#   5 个按钮 × 44 + 4 个间距 × 10 + 左右 padding 16×2 = 292
#   顶 34 + gap 10 + 高 64 = 底边 108
# 抽屉展开时，被它水平覆盖的卡片，顶部被压住的量就往下推。
const NAV_DRAWER_W: float = 292.0
const NAV_DRAWER_BOTTOM: float = 108.
# 抽屉底边到第一行卡片顶边的额外留白（避免贴太紧）
const NAV_DRAWER_GAP: float = 14.0
const CARD_ASPECT: float = 2.0 / 3.0
const SHADOW_H_BASE: float = 16.0

# 卡片大小分档：
#   card_w = 卡片宽度
#   min_cols / max_cols = 该档允许的列数范围
#   gap_max = 该档允许的最大间距（超过则跳下一档）
const CARD_TIERS: Array = [
	{"card_w": 150.0, "min_cols": 5, "max_cols": 7, "gap_max": 52.0},
	{"card_w": 200.0, "min_cols": 5, "max_cols": 7, "gap_max": 70.0},
	{"card_w": 290.0, "min_cols": 6, "max_cols": 8, "gap_max": 100.0},
]
const GRID_GAP_MIN: float = 12.0

# 卡片阴影 idle / hover 参数（唯一来源：_make_grid_cell 的初值与
# _refresh_grid_styles 的目标值都读这里，保证"移开"精确回到启动值）
const SHADOW_IDLE_SIZE: float = 5.0     # 默认阴影大小（越大越散）
const SHADOW_IDLE_OX: float = 1.0       # 默认横向偏移（正=向右）
const SHADOW_IDLE_OY: float = 1.0       # 默认纵向偏移（正=向下）
const SHADOW_IDLE_ALPHA: float = 0.30   # 默认不透明度

const SHADOW_HOVER_SIZE: float = 7.0   # 悬停阴影大小
const SHADOW_HOVER_OX: float = 1.0      # 悬停横向偏移
const SHADOW_HOVER_OY: float = 2.0      # 悬停纵向偏移
const SHADOW_HOVER_ALPHA: float = 0.50  # 悬停不透明度

# 海报墙弹簧（伪弹性：卡片位置改变时弹到新位置，不做碰撞检测）
const CARD_SPRING_STIFFNESS: float = 300.0
const CARD_SPRING_DAMPING: float = 16.0
const CARD_SPRING_SETTLE: float = 0.5      # 小于此速度视为停止（像素/秒）
const CARD_SPRING_MAX_SPEED: float = 1800.0  # 速度上限（像素/秒）
# “添加游戏”按钮的圆圈加号图标尺寸
const ADD_ICON_SZ_BASE: float = 28.0
const CARD_SPRING_JITTER_POS: float = 30.0  # 初始位置随机偏移范围
const CARD_SPRING_JITTER_VEL: float = 80.0  # 初始随机速度范围
# 退出详情页后的冷却时长
const EXIT_COOLDOWN_MAX: float = 2.0
const EXIT_COOLDOWN_MIN: float = 0.2
const GAME_BACKGROUND_SHADER: Shader = preload("res://shaders/game_background.gdshader")
const SIDEBAR_HOVER_BG_SHADER: Shader = preload("res://shaders/sidebar_hover_bg.gdshader")
const CARD_GRAY_SHADER: Shader = preload("res://shaders/game_card_gray.gdshader")
# 不可启动卡片的灰度系数（0.0 = 全灰，1.0 = 原色）
const CARD_UNPLAYABLE_SATURATION: float = 0.15
const BG_COLOR: Color = Color(0.10, 0.115, 0.135, 1.0)          # 中间层
const SIDEBAR_BG: Color = Color(0.075, 0.085, 0.105, 1.0)        # 最暗
const SIDEBAR_ITEM_HOVER: Color = Color(0.15, 0.18, 0.22, 1.0)
const SIDEBAR_ITEM_SEL: Color = Color(0.28, 0.36, 0.48, 0.7)
const SIDEBAR_TEXT: Color = Color(0.82, 0.86, 0.90, 1.0)
const SIDEBAR_TEXT_SEL: Color = Color(1.0, 1.0, 1.0, 1.0)

var camera: Camera3D
var _font_manager: Node = null
var _all_games: Array[Dictionary] = []
var games: Array[Dictionary] = []
var selected_index: int = 0
var _batch_scrape_btn: Button
var _search_text: String = ""
var _sort_mode: String = "name"

var _ui_layer: CanvasLayer
var _root: Control
var _bg: ColorRect

# 侧边栏
var _sidebar_root: Control
var _sidebar_header: Control
var _search_icon_btn: Button
var _sort_icon_btn: Button
var _cartridge_icon: TextureRect = null
var _game_count_label: Label = null
var _search_field: LineEdit
var _sidebar_scroll: ScrollContainer
var _sep_line: ColorRect
var _sidebar_list: VBoxContainer
var _sidebar_items: Array[Button] = []
var _sidebar_footer: Control
var _add_btn: Button

# 海报墙
var _grid_root: Control
var _grid_scroll: ScrollContainer
var _grid: Control
var _cell_buttons: Array[Button] = []
# 批量管理模式
var _batch_mode: bool = false
var _batch_selected: Dictionary = {}
var _batch_bar: HBoxContainer
var _batch_select_all_btn: Button
var _batch_delete_btn: Button
var _hover_index: int = -1
# 空状态：无游戏时让"添加"按钮光晕呼吸
var _add_glow_breathe: bool = false
var _add_btn_hovered: bool = false
# 退出详情页后的冷却：等鼠标松开 + 缓冲，避免误触第一张卡片
var _exit_cooldown: bool = false
var _exit_cooldown_t: float = 0.0

var _ui_scale: float = 1.0
var _font_scale: float = 1.0
var _detail_view = null
var _animated_cache: Dictionary = {}
# 静态纹理缓存：避免重建卡片时图片消失导致闪烁
static var _cover_texture_cache: Dictionary = {}
# 下一次 _rebuild_grid 是否要弹入（只由排序 / 搜索变化设置）
var _rebuild_should_pop: bool = false

# UI 是否已完成初次布局。就绪之前的所有 viewport 变化都不弹，
# 就绪之后的每一次（用户拖窗口 / 切全屏 / 切窗口）都弹。
var _ui_ready: bool = false
# 导航抽屉是否打开。打开时被它覆盖的卡片下推让位，收回时弹回。
var _nav_opened: bool = false

# 本次 _relayout 是否要动画（由调用方决定，用完自动重置）
var _animate_layout: bool = false

# 海报墙滚动惯性物理
var _scroll_velocity: float = 0.0
var _scroll_friction: float = 7.0     # 摩擦力（越小滑得越远）
var _scroll_wheel_power: float = 500.0 # 滚轮推力（越大滚得越快）
# 侧边栏滚动参数
var _sidebar_velocity: float = 0.0
var _sidebar_friction: float = 9.0
var _sidebar_wheel_power: float = 300.0

# ---------------------------------------------------------------------------

func configure(cam: Camera3D) -> void:
	camera = cam
	set_process_unhandled_input(true)
	_compute_scale()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_changed)
	# 建完 UI 先刷一次排序图标，否则按钮 icon 是空的
	_update_sort_icon()
	# 等启动阶段的 viewport 抖动都过去（约 3 帧）再算"就绪"
	_mark_ui_ready_later()

func _mark_ui_ready_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_ui_ready = true

func set_nav_opened(opened: bool) -> void:
	if _nav_opened == opened:
		return
	_nav_opened = opened
	# 走弹簧路径：卡片平滑地被"挤"到新位置，收回时弹回去
	_animate_layout = true
	_relayout()

func set_font_manager(fm: Node) -> void:
	_font_manager = fm
	# 转发给详情页，否则详情页的 _font_manager 一直为 null
	if _detail_view != null and _detail_view.has_method("set_font_manager"):
		_detail_view.set_font_manager(fm)

func apply_fontset() -> void:
	if _font_manager == null:
		return
	_apply_sidebar_fonts()
	if _detail_view != null and _detail_view.has_method("apply_fontset"):
		_detail_view.apply_fontset()
	_relayout()

func _apply_sidebar_fonts() -> void:
	if _game_count_label != null:
		_apply_font_to_label(_game_count_label, "game_sidebar")
	for item in _sidebar_items:
		if not is_instance_valid(item):
			continue
		var name_lbl: Label = item.get_meta("name_lbl", null)
		if name_lbl != null:
			_apply_font_to_label(name_lbl, "game_sidebar")
		var tip_lbl: Label = item.get_meta("tip_lbl", null)
		if tip_lbl != null:
			_apply_font_to_label(tip_lbl, "game_sidebar")

func _apply_font_to_label(label: Label, key: String) -> void:
	if label == null or _font_manager == null:
		return
	var f: FontFile = _font_manager.get_font_for(key, "games")
	if f != null:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")

func _font_size(key: String, fallback: int) -> int:
	if _font_manager == null:
		return fallback
	return _font_manager.get_size_for(key, fallback, "games")

func _on_viewport_changed() -> void:
	_compute_scale()
	# 就绪后的任何 viewport 变化都带动画（含全屏 ↔ 窗口切换）
	_animate_layout = _ui_ready
	_relayout()

func _compute_scale() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		_ui_scale = 1.0
		_font_scale = 1.0
		return
	var raw: float = min(vp.x / UI_BASE_W, vp.y / UI_BASE_H)
	_ui_scale = clampf(raw, UI_SCALE_MIN, UI_SCALE_MAX)
	_font_scale = clampf(raw, FONT_SCALE_MIN, FONT_SCALE_MAX)

func _compute_top_offset() -> int:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return 0
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return 0
	return 34

func _process(delta: float) -> void:
	if not visible:
		return
	# 海报墙滚动惯性（极速丝滑版）
	if abs(_scroll_velocity) > 5.0:
		var vbar := _grid_scroll.get_v_scroll_bar()
		if vbar != null:
			# 计算这一帧该滚动的像素（保留小数，防止被 int 截断导致滚不动）
			var delta_px = _scroll_velocity * delta
			_grid_scroll.scroll_vertical += int(delta_px)
			
			# 施加摩擦力（指数衰减）
			_scroll_velocity *= exp(-_scroll_friction * delta)
			
			# 边界限制
			if _grid_scroll.scroll_vertical <= 0:
				_grid_scroll.scroll_vertical = 0
				_scroll_velocity = 0.0
			elif _grid_scroll.scroll_vertical >= vbar.max_value - vbar.page:
				_grid_scroll.scroll_vertical = int(vbar.max_value - vbar.page)
				_scroll_velocity = 0.0
	else:
		_scroll_velocity = 0.0
	# 侧边栏滚动惯性
	if abs(_sidebar_velocity) > 5.0:
		var svbar := _sidebar_scroll.get_v_scroll_bar()
		if svbar != null:
			_sidebar_scroll.scroll_vertical += int(_sidebar_velocity * delta)
			_sidebar_velocity *= exp(-_sidebar_friction * delta)
			
			if _sidebar_scroll.scroll_vertical <= 0:
				_sidebar_scroll.scroll_vertical = 0
				_sidebar_velocity = 0.0
			elif _sidebar_scroll.scroll_vertical >= svbar.max_value - svbar.page:
				_sidebar_scroll.scroll_vertical = int(svbar.max_value - svbar.page)
				_sidebar_velocity = 0.0
	else:
		_sidebar_velocity = 0.0
	# 1. 批量模式下，选中的卡片发光呼吸（放在最前面，确保不受任何 return 影响）
	if _batch_mode:
		var breath = 0.4 + sin(Time.get_ticks_msec() / 500.0) * 0.4 # 0.0 ~ 0.8 之间呼吸
		for i in range(_cell_buttons.size()):
			var b: Button = _cell_buttons[i]
			if not is_instance_valid(b):
				continue
			if b.has_meta("glow_layer"):
				var glow = b.get_meta("glow_layer")
				if glow != null and glow.visible:
					var style: StyleBoxFlat = glow.get_theme_stylebox("panel")
					if style != null:
						style.border_color.a = breath
						style.shadow_color.a = breath * 0.8

	# 弹簧动画每帧都要跑（不受下面 hover 的提前 return 影响）
	_update_card_springs(delta)
	# 悬停时，灰色的卡片恢复彩色（平滑过渡）
	var color_follow = 1.0 - exp(-delta * 12.0) # 12.0 是过渡速度，越大越快
	for i in range(_cell_buttons.size()):
		var b: Button = _cell_buttons[i]
		if not is_instance_valid(b):
			continue
		if b.has_meta("gray_mat"):
			var mat = b.get_meta("gray_mat")
			if mat is ShaderMaterial:
				var is_hovered = (i == _hover_index)
				var is_playable = bool(games[i].get("playable", true))
				
				# 目标饱和度
				var target_sat = 1.0
				if not is_playable and not is_hovered:
					target_sat = CARD_UNPLAYABLE_SATURATION
				
				# 当前饱和度，平滑逼近
				var cur_sat = float(mat.get_shader_parameter("saturation"))
				var new_sat = lerpf(cur_sat, target_sat, color_follow)
				mat.set_shader_parameter("saturation", new_sat)
	# 阴影平滑过渡（同样每帧都要跑）
	_update_shadow_lerp(delta)

	# 刚退出详情页：等鼠标松开 + 缓冲，才允许响应卡片
	if _exit_cooldown:
		var mouse_held: bool = (
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		)
		if mouse_held:
			_exit_cooldown_t = 0.0
		else:
			_exit_cooldown_t += delta
			if _exit_cooldown_t >= EXIT_COOLDOWN_MIN:
				_exit_cooldown = false
		if _exit_cooldown_t >= EXIT_COOLDOWN_MAX:
			_exit_cooldown = false
		if _exit_cooldown:
			if _hover_index >= 0:
				var old_idx: int = _hover_index
				_hover_index = -1
				_refresh_grid_styles()
				if old_idx >= 0:
					_stop_cell_animation(old_idx)
			return  # 冷却中不处理 hover

	if _grid_root == null or not _grid_root.visible:
		return
	if _grid_scroll != null and not _grid_scroll.visible:
		return

	# 空状态光晕呼吸
	if _add_glow_breathe and not _add_btn_hovered:
		var t: float = Time.get_ticks_msec() / 1000.0
		var breath: float = 0.20 + sin(t * 2.1) * 0.15
		var glow_bg: ColorRect = _add_btn.get_meta("glow_bg", null)
		if glow_bg != null:
			var mat: ShaderMaterial = glow_bg.material as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("brightness", breath)

	# 鼠标 hover 检测
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var found: int = -1
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn) or not btn.visible:
			continue
		if btn.get_global_rect().has_point(mouse):
			found = i
			break
			
	if found == _hover_index:
		return
		
	var old: int = _hover_index
	_hover_index = found
	_refresh_grid_styles()
	if old >= 0:
		_stop_cell_animation(old)
	if found >= 0:
		_play_cell_animation(found)



func _update_card_springs(delta: float) -> void:
	# 伪弹性：每张卡片一个目标位置 + 当前位置，用弹簧追目标（不做碰撞检测）
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if wrapper == null or not is_instance_valid(wrapper):
			continue
		var target: Vector2 = wrapper.get_meta("target_pos", wrapper.position)
		var vel: Vector2 = wrapper.get_meta("vel", Vector2.ZERO)

		var delta_pos: Vector2 = target - wrapper.position
		# 每张卡片的刚度加 ±8% 微扰（按索引散布），
		# 让同批回弹的卡片不会整齐划一 → 视觉上"错峰"
		var jitter: float = 1.0 + sin(float(i) * 1.7) * 0.08
		vel += delta_pos * CARD_SPRING_STIFFNESS * jitter * delta
		vel *= exp(-CARD_SPRING_DAMPING * delta)   # 阻尼
		# 速度上限：否则距离越远加速度越大、峰值越高，远距离惯性过大
		if vel.length() > CARD_SPRING_MAX_SPEED:
			vel = vel.normalized() * CARD_SPRING_MAX_SPEED
		wrapper.position += vel * delta

		# 速度极小时视为停止，避免无限抖动
		if vel.length() < CARD_SPRING_SETTLE and delta_pos.length() < 0.5:
			wrapper.position = target
			vel = Vector2.ZERO

		wrapper.set_meta("vel", vel)

# ---------------------------------------------------------------------------
# UI

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 6
	add_child(_ui_layer)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_root)

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = GAME_BACKGROUND_SHADER
	_bg.material = bg_mat
	_root.add_child(_bg)

	_build_sidebar()
	_build_grid()
	_build_detail()

func _build_sidebar() -> void:
	_sidebar_root = Control.new()
	_sidebar_root.anchor_top = 0.0
	_sidebar_root.anchor_bottom = 1.0
	_sidebar_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_sidebar_root)

	var sidebar_bg := ColorRect.new()
	sidebar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidebar_bg.color = SIDEBAR_BG
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar_root.add_child(sidebar_bg)

	# 顶部：图标行
	_sidebar_header = Control.new()
	_sidebar_header.anchor_right = 1.0
	_sidebar_header.mouse_filter = Control.MOUSE_FILTER_PASS
	_sidebar_root.add_child(_sidebar_header)

	var icon_row := HBoxContainer.new()
	icon_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_row.add_theme_constant_override("separation", 6)
	_sidebar_header.add_child(icon_row)

	_search_icon_btn = Button.new()
	_search_icon_btn.text = ""
	_search_icon_btn.focus_mode = Control.FOCUS_NONE
	_search_icon_btn.toggle_mode = true
	_search_icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_search_icon_btn.custom_minimum_size = Vector2(40.0, 40.0)
	_search_icon_btn.icon = _load_svg_icon("magnifier", 80.0 / 24.0)
	_search_icon_btn.expand_icon = true
	_search_icon_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_icon_btn.toggled.connect(_on_search_icon_toggled)
	icon_row.add_child(_search_icon_btn)

	_sort_icon_btn = Button.new()
	_sort_icon_btn.text = ""                              # 不要文字
	_sort_icon_btn.expand_icon = true
	_sort_icon_btn.focus_mode = Control.FOCUS_NONE
	_sort_icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sort_icon_btn.custom_minimum_size = Vector2(40.0, 40.0)  # 方形按钮
	# 注意：Godot 4.7.2 的 Button 没有 icon_max_width 属性，
	# 限制图标尺寸只能靠加载时的 SVG 缩放（见 _update_sort_icon 传 scale_factor）
	_sort_icon_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # 不撑满
	_sort_icon_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sort_icon_btn.pressed.connect(_on_sort_icon_pressed)
	icon_row.add_child(_sort_icon_btn)

	# 撑开空白
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(spacer)

	# FC 卡带图标
	_cartridge_icon = TextureRect.new()
	_cartridge_icon.texture = _load_svg_icon("cartridge", 80.0 / 24.0)
	_cartridge_icon.custom_minimum_size = Vector2(22.0, 22.0)
	_cartridge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cartridge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cartridge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(_cartridge_icon)

	# 数量
	_game_count_label = Label.new()
	_game_count_label.text = "0"
	_game_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_count_label.add_theme_font_size_override("font_size", 13)
	_game_count_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
	_game_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(_game_count_label)

	# 搜索框（默认隐藏）
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "搜索游戏"
	_search_field.text_changed.connect(_on_search_changed)
	_search_field.visible = false
	_sidebar_root.add_child(_search_field)

	# 中部：滚动列表
	_sidebar_scroll = ScrollContainer.new()
	_sidebar_scroll.anchor_right = 1.0
	_sidebar_scroll.anchor_bottom = 1.0
	_sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# 隐藏原生滚动条
	_sidebar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var svbar := _sidebar_scroll.get_v_scroll_bar()
	if svbar != null:
		svbar.custom_minimum_size = Vector2(0, 0)
		var empty_style := StyleBoxEmpty.new()
		svbar.add_theme_stylebox_override("scroll", empty_style)
		svbar.add_theme_stylebox_override("grabber", empty_style)
		svbar.add_theme_stylebox_override("grabber_highlight", empty_style)
		svbar.add_theme_stylebox_override("grabber_pressed", empty_style)
	
	# 接管滚轮
	_sidebar_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_sidebar_scroll.gui_input.connect(_on_sidebar_scroll_input)
	# 保留空白右键菜单信号（如果你之前绑了的话）
	_sidebar_scroll.gui_input.connect(_on_blank_area_input)
	
	_sidebar_root.add_child(_sidebar_scroll)

	_sidebar_list = VBoxContainer.new()
	_sidebar_list.add_theme_constant_override("separation", 0)
	_sidebar_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_scroll.add_child(_sidebar_list)

	_sep_line = ColorRect.new()
	_sep_line.anchor_right = 1.0
	_sep_line.color = Color(0.16, 0.20, 0.26, 1.0)
	_sidebar_root.add_child(_sep_line)

	# 底部：+ 按钮
	_sidebar_footer = Control.new()
	_sidebar_footer.anchor_right = 1.0
	_sidebar_footer.anchor_top = 1.0
	_sidebar_footer.anchor_bottom = 1.0
	_sidebar_footer.mouse_filter = Control.MOUSE_FILTER_PASS
	_sidebar_root.add_child(_sidebar_footer)

	var footer_bg := ColorRect.new()
	footer_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer_bg.color = Color(0.105, 0.130, 0.165, 1.0)  # 和侧边栏同色
	footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar_footer.add_child(footer_bg)

	_add_btn = Button.new()
	_add_btn.text = ""          # 改成圆圈加号图标
	_add_btn.focus_mode = Control.FOCUS_NONE
	_add_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 悬停反馈完全交给光晕层 → 四个状态 stylebox 一律透明
	var empty_st := StyleBoxEmpty.new()
	_add_btn.add_theme_stylebox_override("normal", empty_st)
	_add_btn.add_theme_stylebox_override("hover", empty_st)
	_add_btn.add_theme_stylebox_override("pressed", empty_st)
	_add_btn.add_theme_stylebox_override("focus", empty_st)
	_add_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_btn.pressed.connect(func(): add_game_requested.emit())
	_add_btn.mouse_entered.connect(func():
		_add_btn_hovered = true
		_animate_add_glow(0.55)
	)
	_add_btn.mouse_exited.connect(func():
		_add_btn_hovered = false
		_animate_add_glow(0.0)
	)
	_sidebar_footer.add_child(_add_btn)

	# 光点光晕背景层（放在按钮内容之下）
	var glow_bg := ColorRect.new()
	glow_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_bg.color = Color.WHITE
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = preload("res://shaders/dot_glow.gdshader")
	glow_mat.set_shader_parameter("glow_color", Color(0.50, 0.72, 0.95))
	glow_mat.set_shader_parameter("brightness", 0.0)   # 初始不可见
	glow_mat.set_shader_parameter("falloff", 2.0)
	# 光点半径走"自动模式"：0 = 用 min(node_size) × glow_radius_scale
	glow_mat.set_shader_parameter("glow_radius_px", 0.0)
	glow_mat.set_shader_parameter("glow_radius_scale", 2.0)
	# node_size 由 _relayout 每帧同步（像素距离法需要知道节点物理尺寸）
	glow_bg.material = glow_mat
	_add_btn.add_child(glow_bg)
	_add_btn.move_child(glow_bg, 0)
	_add_btn.set_meta("glow_bg", glow_bg)

	# 圆圈加号图标（固定尺寸，居中）
	var icon_rect := TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.size = Vector2(ADD_ICON_SZ_BASE, ADD_ICON_SZ_BASE)
	var icon_tex: Texture2D = _load_svg_icon("add_circle", 80.0 / 24.0)
	if icon_tex != null:
		icon_rect.texture = icon_tex
	_add_btn.add_child(icon_rect)
	_add_btn.set_meta("icon_rect", icon_rect)

func _load_svg_icon(icon_id: String, scale_factor: float = 3.0) -> Texture2D:
	# 与 navigation_drawer._load_icon 同法：读 SVG 文本 → load_svg_from_string
	# scale_factor：SVG 是 24×24 viewBox，乘出来就是纹理像素尺寸。
	# 小按钮（排序图标，24×24 按钮 40×40）传 1.0，别放大到 72×72 撑破布局。
	var path: String = "res://assets/icons/%s.svg" % icon_id
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var svg_text: String = file.get_as_text()
	file.close()
	var image := Image.new()
	if image.load_svg_from_string(svg_text, scale_factor) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _animate_add_glow(target: float) -> void:
	var glow_bg: ColorRect = _add_btn.get_meta("glow_bg", null)
	if glow_bg == null:
		return
	var mat: ShaderMaterial = glow_bg.material as ShaderMaterial
	if mat == null:
		return
	if _add_btn.has_meta("glow_tween"):
		var old: Tween = _add_btn.get_meta("glow_tween")
		if old != null and old.is_valid():
			old.kill()
	# tween_method 的 from 必须传当前值，否则会跳变
	var cur: float = 0.0
	var v: Variant = mat.get_shader_parameter("brightness")
	if v is float:
		cur = v
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(val: float) -> void:
			mat.set_shader_parameter("brightness", val),
		cur,
		target,
		0.5
	)
	_add_btn.set_meta("glow_tween", tw)

func _build_grid() -> void:
	_grid_root = Control.new()
	_grid_root.anchor_left = 0.0
	_grid_root.anchor_top = 0.0
	_grid_root.anchor_right = 1.0
	_grid_root.anchor_bottom = 1.0
	_grid_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_grid_root)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# 保留滚动功能，但隐藏原生滚动条（下面用空 StyleBox 彻底隐藏）
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var vbar := _grid_scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.custom_minimum_size = Vector2(0, 0)
		var empty_style := StyleBoxEmpty.new()
		vbar.add_theme_stylebox_override("scroll", empty_style)
		vbar.add_theme_stylebox_override("grabber", empty_style)
		vbar.add_theme_stylebox_override("grabber_highlight", empty_style)
		vbar.add_theme_stylebox_override("grabber_pressed", empty_style)

	# 滚轮惯性：手动接管滚轮事件
	_grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid_scroll.gui_input.connect(_on_grid_scroll_input)
	# 空白右键菜单：保留原信号
	_grid_scroll.gui_input.connect(_on_blank_area_input)
	_grid_root.add_child(_grid_scroll)

	var grid_pad := MarginContainer.new()
	grid_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(grid_pad)

	# 普通 Control：卡片位置由 _relayout 算目标 + _process 弹簧驱动
	_grid = Control.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_pad.add_child(_grid)
	_grid.set_meta("pad", grid_pad)

	# 批量操作栏
	_batch_bar = HBoxContainer.new()
	_batch_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_batch_bar.offset_left = 24
	_batch_bar.offset_top = 12
	_batch_bar.add_theme_constant_override("separation", 12)
	_batch_bar.visible = false
	_grid_root.add_child(_batch_bar)

	_batch_select_all_btn = Button.new()
	_batch_select_all_btn.text = "全选"
	_batch_select_all_btn.pressed.connect(_on_batch_select_all)
	_batch_bar.add_child(_batch_select_all_btn)

	_batch_delete_btn = Button.new()
	_batch_delete_btn.text = "删除选中 (0)"
	_batch_delete_btn.pressed.connect(_on_batch_delete)
	_batch_bar.add_child(_batch_delete_btn)

	_batch_scrape_btn = Button.new()
	_batch_scrape_btn.text = "批量刮削 (Steam)"
	_batch_scrape_btn.pressed.connect(_on_batch_scrape)
	_batch_bar.add_child(_batch_scrape_btn)

func _build_detail() -> void:
	var detail_script: Script = load("res://scripts/game_detail_view.gd")
	_detail_view = detail_script.new()
	_detail_view.back_requested.connect(_on_detail_back)
	_detail_view.play_requested.connect(_on_detail_play)
	# 加在右侧海报墙区域里（这样它紧贴 _grid_root 的 rect，不会盖住侧边栏）
	_grid_root.add_child(_detail_view)

# ---------------------------------------------------------------------------
# 布局刷新

func _relayout() -> void:
	if _sidebar_root == null or _grid_root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s: float = _ui_scale
	var fs: float = _font_scale
	var sidebar_w: float = SIDEBAR_W_BASE * s
	var top: int = _compute_top_offset()

	_sidebar_root.offset_left = 0.0
	_sidebar_root.offset_right = sidebar_w
	_sidebar_root.offset_top = top
	_sidebar_root.offset_bottom = 0.0

	var header_h: float = SIDEBAR_HEADER_H_BASE * s
	# 顶部按钮高度用 fs（要放得下字），可能超过 40*s（最小窗口 s<fs）。
	# header_h 必须至少容纳按钮，否则按钮会溢出到分隔线上，造成视觉重叠。
	var top_btn_h: float = 40.0 * fs
	if top_btn_h > header_h:
		header_h = top_btn_h
	var search_h: float = (SIDEBAR_SEARCH_H_BASE * s) if _search_field.visible else 0.0
	var footer_h: float = SIDEBAR_FOOTER_H_BASE * s
	var pad: float = SIDEBAR_PAD_BASE * s

	_sidebar_header.offset_left = pad
	_sidebar_header.offset_right = -pad
	_sidebar_header.offset_top = pad
	_sidebar_header.offset_bottom = pad + header_h

	# 按钮/输入框高度要放得下字 → 用 fs
	_search_icon_btn.custom_minimum_size = Vector2(top_btn_h, top_btn_h)
	# 搜索/排序按钮都是图标（无文字）→ 方形、不加字号 override
	_sort_icon_btn.custom_minimum_size = Vector2(top_btn_h, top_btn_h)
	if _cartridge_icon != null:
		_cartridge_icon.custom_minimum_size = Vector2(22.0 * s, 22.0 * s)
	if _game_count_label != null:
		var cnt_size: int = _font_size("game_sidebar", 13)
		_game_count_label.add_theme_font_size_override("font_size", int(float(cnt_size) * fs))
	# 光晕用"像素距离法" → 必须把节点物理尺寸同步给 shader，
	# 否则宽扁按钮上的光点会被 UV 拉伸成椭圆
	if _add_btn != null and _add_btn.has_meta("glow_bg"):
		var glow_bg: ColorRect = _add_btn.get_meta("glow_bg", null)
		if glow_bg != null:
			var glow_mat: ShaderMaterial = glow_bg.material as ShaderMaterial
			if glow_mat != null:
				glow_mat.set_shader_parameter("node_size", _add_btn.size)

	_search_field.position = Vector2(pad, pad + header_h + 4.0 * s)
	_search_field.size = Vector2(sidebar_w - 2.0 * pad, search_h)
	if _search_field.visible:
		_search_field.add_theme_font_size_override("font_size", int(13.0 * fs))

	# 顶部功能块的真实底边：搜索框可见时算上它（含上方 4*s 间距），否则只到 header。
	# 分隔线与滚动列表都从这里往下排，避免在任何窗口尺寸下压住顶部控件。
	var block_bottom: float = pad + header_h
	if _search_field.visible:
		block_bottom = pad + header_h + 4.0 * s + search_h

	_sidebar_scroll.offset_left = 0.0
	_sidebar_scroll.offset_right = 0.0
	_sidebar_scroll.offset_top = block_bottom + 8.0 * s
	_sidebar_scroll.offset_bottom = -(footer_h + 16.0 * s)

	if _sep_line != null:
		_sep_line.offset_left = pad
		_sep_line.offset_right = -pad
		_sep_line.offset_top = block_bottom + 4.0 * s
		_sep_line.offset_bottom = _sep_line.offset_top + 1.0

	_sidebar_footer.offset_left = 0.0
	_sidebar_footer.offset_right = 0.0
	_sidebar_footer.offset_top = -footer_h
	_sidebar_footer.offset_bottom = 0.0

	_add_btn.add_theme_font_size_override("font_size", int(14.0 * fs))
	# 圆圈加号图标居中
	var add_icon: TextureRect = _add_btn.get_meta("icon_rect", null)
	if add_icon != null:
		var icon_sz: float = ADD_ICON_SZ_BASE * s
		add_icon.size = Vector2(icon_sz, icon_sz)
		add_icon.position = Vector2(
			(_add_btn.size.x - icon_sz) * 0.5,
			(_add_btn.size.y - icon_sz) * 0.5
		)

	# 海报墙（顶边固定贴窗口栏底边，不整块下移；被抽屉压住的卡片单独下推）
	_grid_root.offset_left = sidebar_w
	_grid_root.offset_right = 0.0
	_grid_root.offset_top = top
	_grid_root.offset_bottom = 0.0

	var grid_pad: MarginContainer = _grid.get_meta("pad")
	var padding: int = int(GRID_PADDING_BASE * s)
	grid_pad.add_theme_constant_override("margin_left", padding)
	grid_pad.add_theme_constant_override("margin_top", padding)
	grid_pad.add_theme_constant_override("margin_right", padding)
	grid_pad.add_theme_constant_override("margin_bottom", padding)

	# 可用宽度（卡片网格区域）
	var avail_w: float = vp.x - sidebar_w - 2.0 * padding
	if avail_w < 100.0:
		return   # 窗口异常小，不做布局

	# avail_w 转成"逻辑像素"（基准 1920 尺度）
	# 因为 CARD_TIERS 里的 card_w 都是基准尺度下的值；
	# 不换算就会出现"物理 px 比逻辑 card_w"的尺度错配 → 列数偏少、卡片排不满。
	var avail_w_logic: float = avail_w / maxf(s, 0.0001)

	# 从 3 档里挑一个
	var chosen_card_w: float = float(CARD_TIERS[0]["card_w"])
	var chosen_cols: int = int(CARD_TIERS[0]["min_cols"])
	var chosen_gap: float = GRID_GAP_MIN

	for i in range(CARD_TIERS.size()):
		var tier: Dictionary = CARD_TIERS[i]
		var card_w: float = float(tier["card_w"])
		var min_cols: int = int(tier["min_cols"])
		var max_cols: int = int(tier["max_cols"])
		var gap_max: float = float(tier["gap_max"])

		# 该档在最小间距下最多能放几列
		var n_max: int = int(floor(
			(avail_w_logic + GRID_GAP_MIN) / (card_w + GRID_GAP_MIN)
		))
		var n: int = clampi(n_max, min_cols, max_cols)
		var tier_gap: float = 0.0
		if n > 1:
			tier_gap = (avail_w_logic - float(n) * card_w) / float(n - 1)

		var is_last: bool = (i == CARD_TIERS.size() - 1)

		# 情况 A：窗口太小，连 min_cols 都放不下 → 用该档，缩小卡片硬撑
		if n_max < min_cols:
			chosen_cols = min_cols
			# 反算卡片宽：让 min_cols 列 + 最小间距正好填满
			chosen_card_w = maxf(
				80.0,
				(avail_w_logic - float(min_cols - 1) * GRID_GAP_MIN) / float(min_cols)
			)
			chosen_gap = GRID_GAP_MIN
			break

		# 情况 B：该档合适（列数在范围内、间距不超过上限）
		if n_max <= max_cols and tier_gap <= gap_max:
			chosen_card_w = card_w
			chosen_cols = n
			chosen_gap = maxf(tier_gap, 0.0)
			break

		# 情况 C：该档放不下（列数超上限 或 间距超上限）→ 继续下一档
		# 如果是最后一档，用最后一档的 max_cols 硬撑
		if is_last:
			chosen_card_w = card_w
			chosen_cols = max_cols
			chosen_gap = maxf(tier_gap, 0.0)
			break

		# 否则继续循环（用下一档）

	# 档位宽高是逻辑像素 → 乘 _ui_scale，窗口缩小时卡片/间距一起缩
	var cell_w: float = chosen_card_w * s
	var cell_h: float = cell_w / CARD_ASPECT
	var gap: float = chosen_gap * s
	var cols: int = chosen_cols

	# 无条件覆盖布局参数，供 _process 里做 hover 检测
	_grid.set_meta("cols", chosen_cols)
	_grid.set_meta("cell_w", cell_w)
	_grid.set_meta("cell_h", cell_h)
	_grid.set_meta("col_gap", gap)
	_grid.set_meta("row_gap", gap)

	var shadow_h: float = SHADOW_H_BASE * s
	# 本次是否要动画（由调用方设置），用完立即重置
	var should_animate: bool = _animate_layout
	_animate_layout = false
	# ── 抽屉挤压 ──
	# 被抽屉明显覆盖的列 → 整列下推同一距离（避免"一高一低"）；
	# 只被"碰一角"的列 → 不动（避免误伤）。
	var nav_open: bool = _nav_opened
	var nav_cx: float = vp.x * 0.5
	var nav_left: float = nav_cx - NAV_DRAWER_W * 0.5
	var nav_right: float = nav_cx + NAV_DRAWER_W * 0.5
	var nav_bottom: float = NAV_DRAWER_BOTTOM

	# 1. 找出被明显覆盖的列（水平重叠 ≥ 卡片宽的 35%）
	var covered_cols: Array = []
	if nav_open:
		for col_i in range(cols):
			var col_left_s: float = (
				sidebar_w + float(padding) + float(col_i) * (cell_w + gap)
			)
			var col_right_s: float = col_left_s + cell_w
			var h_ov: float = minf(col_right_s, nav_right) - maxf(col_left_s, nav_left)
			h_ov = maxf(0.0, h_ov)
			if h_ov / maxf(cell_w, 1.0) >= 0.35:
				covered_cols.append(col_i)

	# 2. 每个被覆盖列，逐行算"几何约束下推量"
	#    第一行被抽屉压 → 顶边落到"抽屉底边 + 留白"处
	#    下一行的下推量 = 上一行下推量 - 行间距（gap）
	#    因为"下推 d 后，行间空档会缩短 d"
	#    → 下推量逐行减去 gap，直到归零
	var push_by_col_row: Dictionary = {}
	if nav_open:
		for col_i in covered_cols:
			var d_prev: float = 0.0
			var n_rows: int = (_cell_buttons.size() + cols - 1) / cols
			for row_i in range(n_rows):
				var d: float = 0.0
				if row_i == 0:
					var top_s: float = float(top) + float(padding)
					d = maxf(0.0, nav_bottom + NAV_DRAWER_GAP - top_s)
				else:
					d = maxf(0.0, d_prev - gap)
				push_by_col_row["%d:%d" % [col_i, row_i]] = d
				d_prev = d
				if d <= 0.0:
					break

	# 3. 应用
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if wrapper != null:
			var row: int = i / cols
			var col: int = i % cols
			var target_x: float = float(col) * (cell_w + gap)
			var target_y: float = float(row) * (cell_h + gap + shadow_h)
			var key: String = "%d:%d" % [col, row]
			if push_by_col_row.has(key):
				target_y += float(push_by_col_row[key])

			wrapper.set_meta("target_pos", Vector2(target_x, target_y))
			wrapper.custom_minimum_size = Vector2(cell_w, cell_h + shadow_h)
			# _grid 是普通 Control（不是 GridContainer），custom_minimum_size
			# 不会自动撑开 size → 必须显式设，否则缩窗时卡片尺寸不变
			wrapper.size = Vector2(cell_w, cell_h + shadow_h)
			if not should_animate:
				# 不动画 → 直接到位（弹簧看到 position == target 就不会动）
				wrapper.position = Vector2(target_x, target_y)
				wrapper.set_meta("vel", Vector2.ZERO)
		# btn 底部让出的阴影高度要跟 wrapper 的高度用同一尺度（乘 s），
		# 否则缩窗后 btn 比 wrapper 内容区高、卡片溢出格子
		btn.offset_bottom = -shadow_h
		var cover: TextureRect = btn.get_meta("cover_rect", null)
		if cover != null:
			cover.custom_minimum_size = Vector2(cell_w, cell_h)
		var ov: Panel = btn.get_meta("overlay", null)
		if ov != null:
			ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# pivot 在卡片中心：整体放大更自然
		btn.pivot_offset = Vector2(btn.size.x * 0.5, btn.size.y * 0.5)

	# 内容总高（让 ScrollContainer 能滚）
	if _grid != null:
		var rows: int = (_cell_buttons.size() + cols - 1) / cols
		_grid.custom_minimum_size.y = float(rows) * (cell_h + gap + shadow_h)

	var sidebar_base: int = _font_size("game_sidebar", 14)
	for item in _sidebar_items:
		if is_instance_valid(item):
			# 行高要放得下放大的字 → 用 fs
			item.custom_minimum_size.y = SIDEBAR_ITEM_H_BASE * fs
			var logo: TextureRect = item.get_meta("logo", null)
			if logo != null:
				logo.custom_minimum_size = Vector2(SIDEBAR_LOGO_SZ_BASE * s, SIDEBAR_LOGO_SZ_BASE * s)
			var name_lbl: Label = item.get_meta("name_lbl", null)
			if name_lbl != null:
				name_lbl.add_theme_font_size_override("font_size", int(float(sidebar_base) * fs))
			# tooltip 也跟字号曲线走
			var tip_lbl: Label = item.get_meta("tip_lbl", null)
			if tip_lbl != null:
				tip_lbl.add_theme_font_size_override("font_size", int(float(sidebar_base) * fs))

# ---------------------------------------------------------------------------
# 数据

func set_games(arr: Array[Dictionary]) -> void:
	# 简单比对，如果数据完全没变，就不重建了，省去无谓的性能开销
	if arr.size() == _all_games.size():
		var identical: bool = true
		for i in range(arr.size()):
			if str(arr[i].get("id", "")) != str(_all_games[i].get("id", "")):
				identical = false
				break
			# 如果时长之类的更新了，ID 虽然一样，但我们需要重建来刷新侧边栏信息
			# 所以这里只拦截：大小和顺序完全一样，且没有任何变动的情况
			# 其实最简单的就是保留原有逻辑，加上上面的纹理缓存就完全足够了
	_all_games = arr
	_rebuild_view()

func _rebuild_view() -> void:
	var filtered: Array[Dictionary] = []
	var q: String = _search_text.strip_edges().to_lower()
	for g in _all_games:
		if q.is_empty() or str(g.get("title", "")).to_lower().contains(q):
			filtered.append(g)

	# 构造排序器（按当前 _sort_mode）
	var sort_func: Callable
	if _sort_mode == "playtime":
		sort_func = func(a, b):
			return int(a.get("playtime_seconds", 0)) > int(b.get("playtime_seconds", 0))
	elif _sort_mode == "recent":
		# 按 last_played_at 降序；空值排最后（内部按标题升序稳定）
		sort_func = func(a, b):
			var ta: String = str(a.get("last_played_at", ""))
			var tb: String = str(b.get("last_played_at", ""))
			if ta.is_empty() and tb.is_empty():
				return str(a.get("title", "")).to_lower() < str(b.get("title", "")).to_lower()
			if ta.is_empty():
				return false
			if tb.is_empty():
				return true
			return ta > tb
	else:
		sort_func = func(a, b):
			return str(a.get("title", "")).to_lower() < str(b.get("title", "")).to_lower()

	# 先按 playable 分组，各自排序，可启动的排前面
	var playable: Array[Dictionary] = []
	var unplayable: Array[Dictionary] = []
	for g in filtered:
		if bool(g.get("playable", true)):
			playable.append(g)
		else:
			unplayable.append(g)
	playable.sort_custom(sort_func)
	unplayable.sort_custom(sort_func)
	filtered = []
	filtered.append_array(playable)
	filtered.append_array(unplayable)

	games = filtered
	selected_index = clampi(selected_index, 0, maxi(games.size() - 1, 0))
	_rebuild_sidebar()
	# _rebuild_grid 内部已经调过一次 _relayout（算 target_pos），这里不再重复
	_rebuild_grid()
	# 游戏总数 = 当前过滤后的可见数（搜索时也能看到匹配数）
	if _game_count_label != null:
		_game_count_label.text = str(games.size())
	_refresh_selection()
	if not games.is_empty():
		selection_changed.emit(selected_index, games[selected_index])
	# 空状态：无游戏时启动"添加"按钮光晕呼吸
	_add_glow_breathe = games.is_empty()
	if not _add_glow_breathe and not _add_btn_hovered:
		# 从空变有 → 关掉呼吸
		_animate_add_glow(0.0)

func _on_search_changed(text: String) -> void:
	_search_text = text
	_rebuild_should_pop = true
	_rebuild_view()

func _on_search_icon_toggled(pressed: bool) -> void:
	_search_field.visible = pressed
	if not pressed:
		_search_text = ""
		_search_field.text = ""
		_rebuild_should_pop = true
		_rebuild_view()
	else:
		_search_field.grab_focus()
	_relayout()

func _on_sort_icon_pressed() -> void:
	# 循环：name → playtime → recent → name
	if _sort_mode == "name":
		_sort_mode = "playtime"
	elif _sort_mode == "playtime":
		_sort_mode = "recent"
	else:
		_sort_mode = "name"
	_update_sort_icon()
	_rebuild_should_pop = true
	_rebuild_view()

func _update_sort_icon() -> void:
	if _sort_icon_btn == null:
		return
	var tex: Texture2D = _load_svg_icon("sort_%s" % _sort_mode, 80.0 / 24.0)
	if tex != null:
		_sort_icon_btn.icon = tex
	var label_map: Dictionary = {
		"name": "名称",
		"playtime": "时长",
		"recent": "最近游玩",
	}
	var sort_label: String = str(label_map.get(_sort_mode, _sort_mode))

# ---------------------------------------------------------------------------
# 侧边栏列表

func _rebuild_sidebar() -> void:
	for it in _sidebar_items:
		if is_instance_valid(it):
			it.queue_free()
	_sidebar_items.clear()
	for i in range(games.size()):
		var btn := _make_sidebar_item(i, games[i])
		_sidebar_list.add_child(btn)
		_sidebar_items.append(btn)

func _make_sidebar_item(index: int, game: Dictionary) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, SIDEBAR_ITEM_H_BASE)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# hover 背景层：从左往右渐隐（必须在 hb 之前加，才会画在内容下面）
	var hover_bg := ColorRect.new()
	hover_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 上下各内缩 3px：框高 = 行高 - 6（锚点仍是 FULL_RECT，只改 offset）
	hover_bg.offset_top = 3.0
	hover_bg.offset_bottom = -3.0
	hover_bg.color = Color.WHITE          # shader 覆盖，白色打底
	hover_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb_mat := ShaderMaterial.new()
	hb_mat.shader = SIDEBAR_HOVER_BG_SHADER
	hb_mat.set_shader_parameter("bg_color", Color(0.30, 0.38, 0.50, 0.75))
	hb_mat.set_shader_parameter("falloff_power", 1.6)
	hover_bg.material = hb_mat
	hover_bg.visible = false
	btn.add_child(hover_bg)
	btn.set_meta("hover_bg", hover_bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 12.0
	hb.offset_right = -12.0
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(SIDEBAR_LOGO_SZ_BASE, SIDEBAR_LOGO_SZ_BASE)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = str(game.get("icon", "")).replace("\\", "/")
	if icon_path.is_empty() or not FileAccess.file_exists(icon_path):
		icon_path = str(game.get("logo", "")).replace("\\", "/")
	if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
		var tex: Texture2D = _load_image_smart(icon_path)
		if tex != null:
			logo.texture = tex
	hb.add_child(logo)

	var name_lbl := Label.new()
	name_lbl.text = str(game.get("title", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", SIDEBAR_TEXT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(name_lbl)

	btn.set_meta("logo", logo)
	btn.set_meta("name_lbl", name_lbl)
	btn.set_meta("hovered", false)
	if _font_manager != null:
		_apply_font_to_label(name_lbl, "game_sidebar")

	# 自定义 tooltip：只在名字被省略号截断时，贴在同一行右侧弹出
	var tip := PanelContainer.new()
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.z_index = 100
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.05, 0.07, 0.10, 0.95)
	tip_style.set_corner_radius_all(4)
	tip_style.content_margin_left = 8.0
	tip_style.content_margin_right = 8.0
	tip_style.content_margin_top = 4.0
	tip_style.content_margin_bottom = 4.0
	tip.add_theme_stylebox_override("panel", tip_style)
	var tip_lbl := Label.new()
	tip_lbl.text = str(game.get("title", ""))
	tip_lbl.add_theme_font_size_override("font_size", 13)
	tip_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	tip.add_child(tip_lbl)
	if _font_manager != null:
		_apply_font_to_label(tip_lbl, "game_sidebar")
	btn.add_child(tip)
	tip.set_meta("tip_is_custom", true)
	btn.set_meta("tip", tip)
	btn.set_meta("tip_lbl", tip_lbl)

	btn.mouse_entered.connect(func(): btn.set_meta("hovered", true); _refresh_sidebar_styles())
	btn.mouse_exited.connect(func(): btn.set_meta("hovered", false); _refresh_sidebar_styles())
	btn.pressed.connect(_on_sidebar_pressed.bind(index))
	return btn

# ---------------------------------------------------------------------------
# 海报墙卡片

func _rebuild_grid() -> void:
	for c in _cell_buttons:
		if is_instance_valid(c):
			var wrap: Control = c.get_meta("wrapper", null)
			if wrap != null and is_instance_valid(wrap):
				wrap.queue_free()
			else:
				c.queue_free()
	_cell_buttons.clear()
	for i in range(games.size()):
		var btn := _make_grid_cell(i, games[i])
		var wrap: Control = btn.get_meta("wrapper")
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(wrap)
		_cell_buttons.append(btn)
	# 重建过程本身不弹（位置由下方逻辑接管）
	_animate_layout = false
	_relayout()
	# 取出标记（本次用完即重置，下次默认不弹）
	var pop: bool = _rebuild_should_pop
	_rebuild_should_pop = false
	for j in range(_cell_buttons.size()):
		var b: Button = _cell_buttons[j]
		if not is_instance_valid(b):
			continue
		var w: Control = b.get_meta("wrapper", null)
		if w == null or not is_instance_valid(w):
			continue
		var tp: Vector2 = w.get_meta("target_pos", Vector2.ZERO)
		if pop:
			# 排序 / 搜索变化 → jitter 弹入
			w.position = tp + Vector2(
				randf_range(-CARD_SPRING_JITTER_POS, CARD_SPRING_JITTER_POS),
				randf_range(-CARD_SPRING_JITTER_POS, CARD_SPRING_JITTER_POS)
			)
			w.set_meta("vel", Vector2(
				randf_range(-CARD_SPRING_JITTER_VEL, CARD_SPRING_JITTER_VEL),
				randf_range(-CARD_SPRING_JITTER_VEL, CARD_SPRING_JITTER_VEL)
			))
		else:
			# 其他场景（启动 / 数据刷新 / 切库）→ 直接到位
			w.position = tp
			w.set_meta("vel", Vector2.ZERO)

func _make_grid_cell(index: int, game: Dictionary) -> Button:
	# wrapper 是 _grid 里的格子，比卡片高 SHADOW_H_BASE，下面留阴影空间
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.set_meta("game_index", index)

	# 卡片本体：占 wrapper 上部，底部让出 SHADOW_H_BASE 给阴影
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 底部让出的阴影高度要跟 _relayout 里 wrapper 的高度用同一尺度（乘 _ui_scale），
	# 否则缩窗时 btn 会比 wrapper 的内容区高，卡片会溢出格子
	btn.offset_bottom = -SHADOW_H_BASE * _ui_scale
	btn.set_meta("game_index", index)
	btn.set_meta("wrapper", wrapper)
	# 阴影直接用 StyleBoxFlat 画（带圆角的投影，跟着卡片一起放大）
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.205, 0.245, 0.305, 1.0)
	bg.set_corner_radius_all(6)
	# A1: a hairline edge gives the poster a physical boundary without a glass frame.
	bg.set_border_width_all(1)
	bg.border_color = Color(0.62, 0.73, 0.86, 0.14)
	bg.shadow_color = Color(0, 0, 0, SHADOW_IDLE_ALPHA)
	bg.shadow_size = int(SHADOW_IDLE_SIZE)
	bg.shadow_offset = Vector2(SHADOW_IDLE_OX, SHADOW_IDLE_OY)
	btn.add_theme_stylebox_override("normal", bg)
	# hover / pressed / focus 都用同一个（悬停时的变化在 _refresh_grid_styles 里做）
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	btn.set_meta("bg_style", bg)
	# 阴影平滑过渡用的"当前值 / 目标值"（tween_property 对 StyleBoxFlat
	# 的 shadow_* 不生效，改在 _process 里手动 lerp）
	btn.set_meta("shadow_cur_size", SHADOW_IDLE_SIZE)
	btn.set_meta("shadow_cur_ox", SHADOW_IDLE_OX)
	btn.set_meta("shadow_cur_oy", SHADOW_IDLE_OY)
	btn.set_meta("shadow_cur_alpha", SHADOW_IDLE_ALPHA)
	btn.set_meta("shadow_tgt_size", SHADOW_IDLE_SIZE)
	btn.set_meta("shadow_tgt_ox", SHADOW_IDLE_OX)
	btn.set_meta("shadow_tgt_oy", SHADOW_IDLE_OY)
	btn.set_meta("shadow_tgt_alpha", SHADOW_IDLE_ALPHA)
	btn.set_meta("shadow_state", 0)   # 0 = 未悬停，1 = 悬停

	var cover_wrap := Control.new()
	cover_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_wrap.clip_contents = true
	cover_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cover_wrap)

	var cover_rect := TextureRect.new()
	cover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 缩小时启用 mipmap，避免边缘锐利（配合 _load_image_smart 的 generate_mipmaps）
	cover_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 灰度 shader：不可启动的游戏 → 降饱和
	var gray_mat := ShaderMaterial.new()
	gray_mat.shader = CARD_GRAY_SHADER
	var is_playable: bool = bool(game.get("playable", true))
	gray_mat.set_shader_parameter(
		"saturation",
		1.0 if is_playable else CARD_UNPLAYABLE_SATURATION
	)
	gray_mat.set_shader_parameter("brightness", 1.0)
	cover_rect.material = gray_mat
	btn.set_meta("gray_mat", gray_mat)
	var cover_path: String = str(game.get("cover", "")).replace("\\", "/")
	if not cover_path.is_empty() and FileAccess.file_exists(cover_path):
		# 优先从缓存读取，秒出图，防闪烁
		if _cover_texture_cache.has(cover_path):
			cover_rect.texture = _cover_texture_cache[cover_path]
			_check_animated(cover_path, btn)
		else:
			# 没缓存才走异步加载
			_load_cover_async(cover_rect, cover_path, btn)
	cover_wrap.add_child(cover_rect)
	btn.set_meta("cover_rect", cover_rect)

	var anim_holder := Control.new()
	anim_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anim_holder.clip_contents = true
	anim_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_holder.visible = false
	cover_wrap.add_child(anim_holder)
	btn.set_meta("anim_holder", anim_holder)

	# 悬停亮度层：叠一层浅白，悬停时淡入
	var brightness_layer := ColorRect.new()
	brightness_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brightness_layer.color = Color(1.0, 1.0, 1.0, 0.0)
	brightness_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_wrap.add_child(brightness_layer)
	btn.set_meta("brightness_layer", brightness_layer)

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0)
	ov_style.set_corner_radius_all(6)
	overlay.add_theme_stylebox_override("panel", ov_style)
	btn.add_child(overlay)
	btn.set_meta("overlay", overlay)

	# 批量模式下的复选框
	var check := CheckBox.new()
	check.set_anchors_preset(Control.PRESET_TOP_LEFT)
	check.position = Vector2(8, 8)
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	check.visible = _batch_mode
	check.toggled.connect(func(toggled): _on_card_toggled(index, toggled))
	wrapper.add_child(check)

	# 批量模式的青色发光层
	var glow_layer := Panel.new()
	glow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_layer.visible = false
	
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0) # 内部透明
	glow_style.set_border_width_all(3)      # 边框厚度
	glow_style.border_color = Color(0.2, 0.9, 1.0, 0.8) # 亮青色
	glow_style.shadow_color = Color(0.2, 0.9, 1.0, 0.6) # 外发光阴影
	glow_style.shadow_size = 12
	glow_style.set_corner_radius_all(6)
	glow_layer.add_theme_stylebox_override("panel", glow_style)
	
	btn.add_child(glow_layer)
	btn.set_meta("glow_layer", glow_layer)

	wrapper.add_child(btn)

	btn.pressed.connect(_on_grid_pressed.bind(index))
	btn.gui_input.connect(_on_grid_input.bind(index, game))
	return btn

func _fmt_playtime(seconds: int) -> String:
	if seconds <= 0:
		return "未游玩"
	if seconds < 60:
		return "< 1 分钟"
	if seconds < 3600:
		return "%d 分钟" % (seconds / 60)
	return "%.1f 小时" % (float(seconds) / 3600.0)

# ---------------------------------------------------------------------------
# 选中 / 交互

func _refresh_selection() -> void:
	_refresh_sidebar_styles()
	_refresh_grid_styles()

func _refresh_sidebar_styles() -> void:
	for i in range(_sidebar_items.size()):
		var btn: Button = _sidebar_items[i]
		if not is_instance_valid(btn):
			continue
		var is_hov: bool = false
		if btn.has_meta("hovered"):
			is_hov = bool(btn.get_meta("hovered"))

		# 背景全部改由 hover_bg 层画（渐隐），stylebox 一律透明
		var empty_st := StyleBoxFlat.new()
		empty_st.bg_color = Color(0, 0, 0, 0)
		btn.add_theme_stylebox_override("normal", empty_st)
		btn.add_theme_stylebox_override("hover", empty_st)
		btn.add_theme_stylebox_override("pressed", empty_st)
		btn.add_theme_stylebox_override("focus", empty_st)

		# hover 时才显示渐隐背景层
		var hover_bg: Variant = btn.get_meta("hover_bg", null)
		if hover_bg != null and is_instance_valid(hover_bg):
			(hover_bg as ColorRect).visible = is_hov

		var name_lbl: Label = null
		if btn.has_meta("name_lbl"):
			name_lbl = btn.get_meta("name_lbl") as Label
		if name_lbl != null:
			var color := SIDEBAR_TEXT
			if is_hov:
				color = Color(1.0, 1.0, 1.0, 1.0)
			name_lbl.add_theme_color_override("font_color", color)

		# 自定义 tooltip：只在名字被截断且 hover 时显示
		_update_sidebar_tip(btn, is_hov)

func _update_sidebar_tip(btn: Button, is_hov: bool) -> void:
	"""只在名字被省略号截断且 hover 时，显示自定义 tooltip（贴同行右侧）。"""
	var tip: Variant = btn.get_meta("tip", null)
	if not (tip is PanelContainer):
		return
	var tip_node: PanelContainer = tip as PanelContainer
	var name_lbl: Label = null
	if btn.has_meta("name_lbl"):
		name_lbl = btn.get_meta("name_lbl") as Label
	if name_lbl == null or not is_instance_valid(name_lbl):
		tip_node.visible = false
		return
	if not is_hov:
		tip_node.visible = false
		return

	# 判断是否被截断：整串文字宽度 > 可用宽度
	var font: Font = name_lbl.get_theme_font("font")
	var fs_base: int = name_lbl.get_theme_font_size("font_size")
	var full_w: float = 0.0
	if font != null and fs_base > 0:
		full_w = font.get_string_size(
			name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_base
		).x
	var avail_w: float = name_lbl.size.x
	var truncated: bool = full_w > avail_w + 2.0
	if not truncated:
		tip_node.visible = false
		return

	tip_node.position = Vector2(
		name_lbl.position.x + name_lbl.size.x + 8.0,
		name_lbl.position.y
	)
	tip_node.visible = true

func _refresh_grid_styles() -> void:
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var is_hover: bool = (i == _hover_index)

		# 阴影：只更新"目标值"，实际写回 stylebox 由 _update_shadow_lerp 每帧插值。
		# 注意：_process 的 hover 检测每次变化都会调本函数；只有"状态真的变了"
		# 才改目标，否则反复覆盖会让平滑过渡永远跑不完。
		var target_state: int = 1 if is_hover else 0
		var cur_state: int = int(btn.get_meta("shadow_state", -1))
		if cur_state != target_state:
			btn.set_meta("shadow_state", target_state)
			var card_style: StyleBoxFlat = btn.get_meta("bg_style", null)
			if card_style != null:
				# A1: reflected edge responds to focus; no animation loop or material allocation.
				card_style.border_color = Color(0.72, 0.83, 0.96, 0.45 if target_state == 1 else 0.14)
			if target_state == 1:
				# 悬停：更浅 + 更大更散的投影
				btn.set_meta("shadow_tgt_size", SHADOW_HOVER_SIZE)
				btn.set_meta("shadow_tgt_ox", SHADOW_HOVER_OX)
				btn.set_meta("shadow_tgt_oy", SHADOW_HOVER_OY)
				btn.set_meta("shadow_tgt_alpha", SHADOW_HOVER_ALPHA)
			else:
				# 未悬停：与 _make_grid_cell 的初值同源 → 移开精确回到启动值
				btn.set_meta("shadow_tgt_size", SHADOW_IDLE_SIZE)
				btn.set_meta("shadow_tgt_ox", SHADOW_IDLE_OX)
				btn.set_meta("shadow_tgt_oy", SHADOW_IDLE_OY)
				btn.set_meta("shadow_tgt_alpha", SHADOW_IDLE_ALPHA)

		# 悬停：整体轻微放大（1.03），先快后慢
		var target: float = 1.03 if is_hover else 1.0
		if absf(btn.scale.x - target) >= 0.001:
			# pivot 在底边中心：卡片只往上长，底部不动，阴影不被盖
			btn.pivot_offset = Vector2(btn.size.x * 0.5, btn.size.y)
			if btn.has_meta("scale_tween"):
				var olds: Tween = btn.get_meta("scale_tween")
				if olds != null and olds.is_valid():
					olds.kill()
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2.ONE * target, 0.28)
			btn.set_meta("scale_tween", tw)

		# 悬停：叠一层浅白，亮度增强
		var brightness_layer: ColorRect = btn.get_meta("brightness_layer", null)
		if brightness_layer != null:
			var target_a: float = 0.05 if is_hover else 0.0
			if absf(brightness_layer.color.a - target_a) >= 0.001:
				if btn.has_meta("brightness_tween"):
					var oldt: Tween = btn.get_meta("brightness_tween")
					if oldt != null and oldt.is_valid():
						oldt.kill()
				var tw2 := create_tween()
				tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw2.tween_property(brightness_layer, "color:a", target_a, 0.25)
				btn.set_meta("brightness_tween", tw2)

func _update_shadow_lerp(delta: float) -> void:
	# 阴影平滑过渡：tween_property 对 StyleBoxFlat 的 shadow_* 不生效，
	# 所以每帧手动朝目标值插值。SHADOW_LERP_SPEED 越大越快到位。
	const SHADOW_LERP_SPEED: float = 12.0
	var f: float = 1.0 - exp(-delta * SHADOW_LERP_SPEED)
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var bg: StyleBoxFlat = btn.get_meta("bg_style", null)
		if bg == null:
			continue

		var cur_size: float = float(btn.get_meta("shadow_cur_size", 8.0))
		var cur_ox: float = float(btn.get_meta("shadow_cur_ox", 1.0))
		var cur_oy: float = float(btn.get_meta("shadow_cur_oy", 4.0))
		var cur_alpha: float = float(btn.get_meta("shadow_cur_alpha", 0.5))

		var tgt_size: float = float(btn.get_meta("shadow_tgt_size", 8.0))
		var tgt_ox: float = float(btn.get_meta("shadow_tgt_ox", 1.0))
		var tgt_oy: float = float(btn.get_meta("shadow_tgt_oy", 4.0))
		var tgt_alpha: float = float(btn.get_meta("shadow_tgt_alpha", 0.5))

		cur_size = lerpf(cur_size, tgt_size, f)
		cur_ox = lerpf(cur_ox, tgt_ox, f)
		cur_oy = lerpf(cur_oy, tgt_oy, f)
		cur_alpha = lerpf(cur_alpha, tgt_alpha, f)

		# 收敛判定：差距极小则直接吸附
		if absf(cur_size - tgt_size) < 0.05:
			cur_size = tgt_size
		if absf(cur_ox - tgt_ox) < 0.05:
			cur_ox = tgt_ox
		if absf(cur_oy - tgt_oy) < 0.05:
			cur_oy = tgt_oy
		if absf(cur_alpha - tgt_alpha) < 0.005:
			cur_alpha = tgt_alpha

		btn.set_meta("shadow_cur_size", cur_size)
		btn.set_meta("shadow_cur_ox", cur_ox)
		btn.set_meta("shadow_cur_oy", cur_oy)
		btn.set_meta("shadow_cur_alpha", cur_alpha)

		# 写回 stylebox
		bg.shadow_size = int(round(cur_size))
		bg.shadow_offset = Vector2(cur_ox, cur_oy)
		bg.shadow_color = Color(0, 0, 0, cur_alpha)

func _on_sidebar_pressed(index: int) -> void:
	_select_index(index)
	_enter_detail(index)

func _on_grid_pressed(index: int) -> void:
	if _exit_cooldown:
		return
	
	# 如果在批量模式，点击卡片就切换勾选状态，不进详情页
	if _batch_mode:
		var game_id: String = str(games[index].get("id", ""))
		# 翻转选中状态
		if _batch_selected.has(game_id):
			_batch_selected.erase(game_id)
		else:
			_batch_selected[game_id] = true
		_update_batch_ui()
		return

	# 正常模式：进详情页
	_select_index(index)
	_enter_detail(index)

func _on_grid_input(event: InputEvent, index: int, game: Dictionary) -> void:
	if _exit_cooldown:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		game_context_requested.emit(game, mb.global_position)
		get_viewport().set_input_as_handled()

func _on_blank_area_input(event: InputEvent) -> void:
	# 空白处右键 → 交给 main 弹空白菜单。
	# 用 global_position（和卡片右键一致），因为 show_at() 按屏幕坐标定位。
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		blank_context_requested.emit(mb.global_position)
		get_viewport().set_input_as_handled()

func _enter_detail(index: int) -> void:
	if index < 0 or index >= games.size():
		return
	if _detail_view == null:
		return
	# 进详情页前停掉所有卡片的动图，防止在后台持续播放
	for i in range(_cell_buttons.size()):
		_stop_cell_animation(i)
	_hover_index = -1
	_detail_view.show_game(games[index])
	_detail_view.visible = true
	# 只隐藏滚动内容，侧边栏和 _grid_root 保持存在
	_grid_scroll.visible = false

func _exit_detail() -> void:
	if _detail_view != null:
		_detail_view.visible = false
	_grid_scroll.visible = true
	_hover_index = -1
	_refresh_grid_styles()
	# 鼠标停在原「返回」位置会误触第一行第一张卡片 → 等鼠标松开再解除冷却
	_exit_cooldown = true
	_exit_cooldown_t = 0.0

func _on_detail_back() -> void:
	_exit_detail()

func is_detail_open() -> bool:
	return _detail_view != null and _detail_view.visible

func set_detail_launching(launching: bool) -> void:
	if _detail_view != null:
		_detail_view.set_launching(launching)

func _on_detail_play(_item_id: String) -> void:
	if games.is_empty():
		return
	game_double_clicked.emit(games[selected_index])

func _play_cell_animation(index: int) -> void:
	if index < 0 or index >= _cell_buttons.size():
		return
	var btn: Button = _cell_buttons[index]
	if not is_instance_valid(btn):
		return
	if not btn.has_meta("anim_path"):
		return
	if not btn.has_meta("anim_holder"):
		return
	var holder: Control = btn.get_meta("anim_holder") as Control
	if holder == null or not is_instance_valid(holder):
		return
	var path: String = str(btn.get_meta("anim_path"))
	if not ClassDB.class_exists(&"AnimatedImagePlayer"):
		return
	var anim_tex = _get_animated_texture(path)
	if anim_tex == null:
		return
	var player: Control = null
	if holder.has_meta("player"):
		player = holder.get_meta("player") as Control
	if player == null or not is_instance_valid(player):
		player = ClassDB.instantiate(&"AnimatedImagePlayer") as Control
		if player == null:
			return
		player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		player.set("expand_mode", 1)
		player.set("stretch_mode", 6)
		player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(player)
		holder.set_meta("player", player)
	if player.get("animated_image") != anim_tex:
		player.set("animated_image", anim_tex)
	player.set("playing", true)
	holder.visible = true

func _stop_cell_animation(index: int) -> void:
	if index < 0 or index >= _cell_buttons.size():
		return
	var btn: Button = _cell_buttons[index]
	if not is_instance_valid(btn):
		return
	if not btn.has_meta("anim_holder"):
		return
	var holder: Control = btn.get_meta("anim_holder") as Control
	if holder == null or not is_instance_valid(holder):
		return
	if holder.has_meta("player"):
		var player: Control = holder.get_meta("player") as Control
		if player != null and is_instance_valid(player):
			player.set("playing", false)
	holder.visible = false

func _get_animated_texture(path: String):
	if _animated_cache.has(path):
		return _animated_cache[path]
	if not ClassDB.class_exists(&"AnimatedImageLoader"):
		return null
	var tex = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_file", path)
	if tex != null:
		_animated_cache[path] = tex
	return tex

func _load_animated_poster(path: String) -> Texture2D:
	if ClassDB.class_exists(&"AnimatedImageLoader"):
		return ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_file", path) as Texture2D
	# Godot can still decode a static WebP without the optional native plugin.
	var image := Image.new()
	if image.load(path) != OK or image.is_empty():
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _load_image_smart(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 8:
		return null
	var img := Image.new()
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		if img.load_png_from_buffer(bytes) == OK:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
		return _load_animated_poster(path)
	if bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		if img.load_jpg_from_buffer(bytes) == OK:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
		return _load_animated_poster(path)
	if bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 \
			and bytes.size() >= 12 \
			and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
		return _load_animated_poster(path)
	if bytes[0] == 0x42 and bytes[1] == 0x4D:
		if img.load_bmp_from_buffer(bytes) == OK:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
		return _load_animated_poster(path)
	return _load_animated_poster(path)

func _select_index(new_index: int) -> void:
	if new_index < 0 or new_index >= games.size():
		return
	if new_index == selected_index:
		return
	selected_index = new_index
	_refresh_selection()
	if selected_index < _sidebar_items.size():
		var it: Button = _sidebar_items[selected_index]
		if is_instance_valid(it):
			_sidebar_scroll.ensure_control_visible(it)
	if selected_index < _cell_buttons.size():
		var c: Button = _cell_buttons[selected_index]
		if is_instance_valid(c):
			_grid_scroll.ensure_control_visible(c)
	selection_changed.emit(selected_index, games[selected_index])

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _detail_view != null and _detail_view.visible:
		if event is InputEventKey:
			var ke: InputEventKey = event as InputEventKey
			if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
				_exit_detail()
				get_viewport().set_input_as_handled()
		return

func set_section_visible(v: bool) -> void:
	var was_visible: bool = visible
	visible = v
	if _ui_layer != null:
		_ui_layer.visible = v
	if not v and _detail_view != null:
		# 切出游戏板块时，把详情页也收掉，避免下次切回来还在详情页
		_exit_detail()
	# 从隐藏切回可见 → 卡片弹入（切板块时能看到"弹"的效果）
	if v and not was_visible:
		_pop_cards_in()

func _pop_cards_in() -> void:
	# 给每张卡片一个随机初始偏移 + 速度，弹簧会把它们"弹"到位
	for i in range(_cell_buttons.size()):
		var b: Button = _cell_buttons[i]
		if not is_instance_valid(b):
			continue
		var w: Control = b.get_meta("wrapper", null)
		if w == null or not is_instance_valid(w):
			continue
		var tp: Vector2 = w.get_meta("target_pos", Vector2.ZERO)
		w.position = tp + Vector2(
			randf_range(-CARD_SPRING_JITTER_POS, CARD_SPRING_JITTER_POS),
			randf_range(-CARD_SPRING_JITTER_POS, CARD_SPRING_JITTER_POS)
		)
		w.set_meta("vel", Vector2(
			randf_range(-CARD_SPRING_JITTER_VEL, CARD_SPRING_JITTER_VEL),
			randf_range(-CARD_SPRING_JITTER_VEL, CARD_SPRING_JITTER_VEL)
		))

func jump_to_index(index: int) -> void:
	if games.is_empty():
		return
	_select_index(clampi(index, 0, games.size() - 1))

func get_selected_game() -> Dictionary:
	if selected_index < 0 or selected_index >= games.size():
		return {}
	return games[selected_index]

func toggle_batch_mode(enabled: bool) -> void:
	_batch_mode = enabled
	_batch_selected.clear()
	_batch_bar.visible = enabled
	_update_batch_ui()
	_rebuild_grid()

func _on_card_toggled(index: int, toggled: bool) -> void:
	var game_id: String = str(games[index].get("id", ""))
	if toggled:
		_batch_selected[game_id] = true
	else:
		_batch_selected.erase(game_id)
	_update_batch_ui()

func _update_batch_ui() -> void:
	_batch_delete_btn.text = "删除选中 (%d)" % _batch_selected.size()
	for i in range(_cell_buttons.size()):
		var b: Button = _cell_buttons[i]
		var game_id: String = str(games[i].get("id", ""))
		
		# 1. 控制勾选框
		var check = null
		if b.has_meta("batch_check"):
			check = b.get_meta("batch_check")
		if check != null:
			check.visible = _batch_mode
			check.button_pressed = _batch_selected.has(game_id)
			
		# 2.控制发光层
		if b.has_meta("glow_layer"):
			var glow = b.get_meta("glow_layer")
			if glow != null:
				glow.visible = _batch_mode and _batch_selected.has(game_id)

func _on_batch_select_all() -> void:
	for g in games:
		_batch_selected[str(g.get("id", ""))] = true
	_update_batch_ui()

func _on_batch_delete() -> void:
	if _batch_selected.is_empty():
		return
	# 发出信号，让 main.gd 去调后端删除
	for id in _batch_selected.keys():
		game_removed.emit(id)
	_batch_selected.clear()
	_update_batch_ui()
	# 如果删空了，自动退出批量模式
	await get_tree().create_timer(0.2).timeout
	if _batch_selected.is_empty():
		toggle_batch_mode(false)

func _on_batch_scrape() -> void:
	if _batch_selected.is_empty():
		return
	batch_scrape_requested.emit(_batch_selected.keys())
	toggle_batch_mode(false) # 刮削完自动退出批量模式	

func _on_grid_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_velocity += _scroll_wheel_power
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_velocity -= _scroll_wheel_power
				get_viewport().set_input_as_handled()

func _on_sidebar_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_sidebar_velocity += _sidebar_wheel_power
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_sidebar_velocity -= _sidebar_wheel_power
				get_viewport().set_input_as_handled()

func _load_cover_async(cover_rect: TextureRect, path: String, btn: Button) -> void:
	# 使用 WorkerThreadPool 在后台读文件，防止卡死主线程
	WorkerThreadPool.add_task(_load_cover_task.bind(cover_rect, path, btn))

func _load_cover_task(cover_rect: TextureRect, path: String, btn: Button) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 8:
		return
		
	var img := Image.new()
	var is_std_format := false
	
	# 线程内只处理标准格式的解码（安全且快）
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		if img.load_png_from_buffer(bytes) == OK:
			is_std_format = true
	elif bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		if img.load_jpg_from_buffer(bytes) == OK:
			is_std_format = true
	elif bytes[0] == 0x42 and bytes[1] == 0x4D:
		if img.load_bmp_from_buffer(bytes) == OK:
			is_std_format = true
			
	if is_std_format:
		img.generate_mipmaps()
		call_deferred("_apply_cover_texture", cover_rect, img, path, btn)
	else:
		# WebP 或动图，回主线程交给插件处理
		call_deferred("_apply_cover_texture_plugin", cover_rect, path, btn)

func _apply_cover_texture(cover_rect: TextureRect, img: Image, path: String, btn: Button) -> void:
	if not is_instance_valid(cover_rect):
		return
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_cover_texture_cache[path] = tex  # 写入缓存
	cover_rect.texture = tex
	_check_animated(path, btn)

func _apply_cover_texture_plugin(cover_rect: TextureRect, path: String, btn: Button) -> void:
	if not is_instance_valid(cover_rect):
		return
	var tex: Texture2D = _load_animated_poster(path)
	if tex != null:
		_cover_texture_cache[path] = tex # 写入缓存
		cover_rect.texture = tex
	_check_animated(path, btn)

func _check_animated(path: String, btn: Button) -> void:
	var ext: String = path.get_extension().to_lower()
	if ext == "webp" or ext == "gif" or ext == "apng":
		if not ClassDB.class_exists(&"AnimatedImageLoader"):
			return
		var info = ClassDB.class_call_static(&"AnimatedImageLoader", &"probe_file", path)
		if info != null and bool(info.get("animated", false)):
			btn.set_meta("anim_path", path)
