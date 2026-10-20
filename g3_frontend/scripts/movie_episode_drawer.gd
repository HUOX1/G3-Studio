extends Control
class_name G3MovieEpisodeDrawer

signal episode_clicked(item_id: String, episode_id: String)

# ============ 布局 ============
const HANDLE_WIDTH: float = 22.0
const DRAWER_WIDTH: float = 340.0
const HEIGHT_RATIO: float = 0.78
const OUTSET_FROM_CARD: float = 8.0

# ============ 动画 ============
const EXPAND_DURATION: float = 0.36
const COLLAPSE_DURATION: float = 0.30
const CONTENT_FADE_IN: float = 0.24
const HANDLE_FADE: float = 0.18

# ============ 鼠标互动 ============
const ROW_EXTEND: float = 3.0
const ROW_EXTEND_DURATION: float = 0.16

# ============ 按钮 ============
const BUTTON_HEIGHT: float = 38.0
const BUTTON_GAP: float = 0.0
const DRAWER_PADDING_SIDE: float = 10.0
const DRAWER_PADDING_VERTICAL: float = 16.0
const BUTTON_NUM_WIDTH: float = 36.0

# ============ 季号横向选择条（仅多季时显示）============
const SEASON_BAR_TOP_PADDING: float = 8.0
const SEASON_BAR_HEIGHT: float = 24.0
const SEASON_BAR_BOTTOM_PADDING: float = 6.0
const SEASON_BAR_GAP: float = 4.0
const SEASON_BUTTON_FONT_SIZE: int = 12
const SEASON_BUTTON_PADDING_H: float = 10.0
const SEASON_BUTTON_MIN_WIDTH: float = 58.0
const SEASON_BUTTON_HEIGHT: float = 22.0
const SEASON_BUTTON_ACTIVE_ALPHA: float = 0.30
const SEASON_BUTTON_IDLE_ALPHA: float = 0.06
const SEASON_BUTTON_HOVER_ALPHA: float = 0.18
const SEASON_BUTTON_TEXT_ACTIVE_ALPHA: float = 0.95
const SEASON_BUTTON_TEXT_IDLE_ALPHA: float = 0.50
const SEASON_BAR_WHEEL_STEP: float = 80.0

# ============ 每集简介漂浮窗 ============
const TOOLTIP_SHOW_DELAY: float = 0.35
const TOOLTIP_WIDTH: float = 340.0
const TOOLTIP_MAX_HEIGHT: float = 400.0
const TOOLTIP_MARGIN: float = 14.0
const TOOLTIP_BG: Color = Color(0.05, 0.03, 0.02, 0.95)
const TOOLTIP_BORDER: Color = Color(0.88, 0.66, 0.36, 0.55)
const TOOLTIP_TITLE_COLOR: Color = Color(0.98, 0.94, 0.86)
const TOOLTIP_BODY_COLOR: Color = Color(0.82, 0.80, 0.76)
const TOOLTIP_TITLE_FONT_SIZE: int = 15
const TOOLTIP_BODY_FONT_SIZE: int = 13
const TOOLTIP_GLASS_TINT: Color = Color(0.05, 0.03, 0.02, 0.68)   
const TOOLTIP_GLOW_HEIGHT: float = 4.0                              
const TOOLTIP_GLASS_BLUR: float = 3.0
const TOOLTIP_GLOW_BREATH_SPEED: float = 1.4
const TOOLTIP_GLOW_BREATH_MIN: float = 0.42
const TOOLTIP_GLOW_BREATH_MAX: float = 0.72

# ============ 右下角"共 x 季" ============
const SEASON_COUNT_FONT_SIZE: int = 11
const SEASON_COUNT_DIM: float = 0.55
const SEASON_COUNT_WIDTH: float = 68.0
const SEASON_COUNT_HEIGHT: float = 18.0

# ============ 样式 ============
const CORNER_RADIUS: int = 8

# ============ 毛玻璃 ============
const GLASS_SHADER: Shader = preload("res://shaders/glass_panel.gdshader")
# 与玻璃混合的主题色（深青，用 _accent 时会太重，所以固定）
const GLASS_TINT: Color = Color(0.02, 0.06, 0.09, 0.55)
const GLASS_BLUR: float = 2.5

# ============ 光边（方案 4 + 6）============
const GLOW_SHADER: Shader = preload("res://shaders/edge_glow.gdshader")
const GLOW_HEIGHT: float = 6.0
const GLOW_EDGE_POWER: float = 1.4
const GLOW_IDLE_BRIGHTNESS: float = 0.12
const GLOW_ACTIVE_BRIGHTNESS: float = 0.90
const GLOW_TRIGGER_VELOCITY: float = 100.0
const GLOW_FADE_SPEED: float = 2.5
const GLOW_BUMP_PEAK: float = 0.90
# 衰减速度：越小暴亮保持越久（1.2 比原来的 1.8 慢，看得清）
const GLOW_BUMP_DECAY: float = 1.2
# 形状铺开速度：越小从中心铺到两边越慢
const GLOW_SHAPE_SPREAD_SPEED: float = 4.0
# 形状铺平的最大程度：1.0 = 完全铺满整条边，0.7 = 最亮时两端仍比中心暗
const GLOW_SHAPE_MAX: float = 0.7

const BUTTON_BG_HOVER_ALPHA: float = 0.10
const BUTTON_BORDER_HOVER_ALPHA: float = 0.65
const BUTTON_FONT_SIZE: int = 18
const BUTTON_TITLE_FONT_SIZE: int = 14
const BUTTON_TEXT_COLOR: Color = Color(0.92, 0.92, 0.92)
const BUTTON_TITLE_COLOR: Color = Color(0.72, 0.72, 0.72)

const SCROLL_SPEED: float = 600.0
const SCROLL_FRICTION: float = 7.0
const SCROLL_MIN_VELOCITY: float = 5.0

# ============ 状态 ============
var _drawer: Control
var _glass_bg: ColorRect
var _glass_mat: ShaderMaterial

# 光边
var _glow_top: ColorRect
var _glow_bottom: ColorRect
var _glow_top_mat: ShaderMaterial
var _glow_bottom_mat: ShaderMaterial
var _glow_top_brightness: float = GLOW_IDLE_BRIGHTNESS
var _glow_bottom_brightness: float = GLOW_IDLE_BRIGHTNESS
var _bump_top: float = 0.0
var _bump_bottom: float = 0.0
var _shape_top: float = 0.0
var _shape_bottom: float = 0.0

var _handle_label: Label
var _content: Control
var _list: VBoxContainer
var _tween: Tween

# 季号条
var _season_bar_root: Control
var _season_bar_scroll: ScrollContainer
var _season_bar_row: HBoxContainer
var _season_buttons: Dictionary = {}   # season_num -> Button
var _active_season: int = -1
var _has_multi_season: bool = false

var _season_count_label: Label

# 全部集数（原始数据）和季列表（有序）
var _all_episodes: Array[Dictionary] = []
var _seasons: Array[int] = []

var _expanded: bool = false
var _collapsing: bool = false
var _want_hide: bool = false
var _hide_timer: float = 0.0
const HIDE_DELAY: float = 0.45

var _scroll_offset: float = 0.0
var _scroll_velocity: float = 0.0

var _card_right_x: float = 500.0
var _card_center_y: float = 400.0
var _card_height: float = 400.0

var _accent: Color = Color(0.88, 0.66, 0.36)
var _muted: Color = Color(0.75, 0.65, 0.50)
var _item_id: String = ""
var _tooltip: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label
var _tooltip_generation: int = 0
var _tooltip_glass: ColorRect
var _tooltip_glass_mat: ShaderMaterial
var _tooltip_glow_top: ColorRect
var _tooltip_glow_bottom: ColorRect
var _tooltip_glow_top_mat: ShaderMaterial
var _tooltip_glow_bottom_mat: ShaderMaterial
var _tooltip_sep_mat: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)
	_drawer.size = Vector2(HANDLE_WIDTH, 0.0)
	set_process(true)

func _build() -> void:
	_drawer = Control.new()
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.gui_input.connect(_on_drawer_input)
	_drawer.clip_contents = true
	add_child(_drawer)

	# 毛玻璃底层
	_glass_bg = ColorRect.new()
	_glass_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass_bg.color = Color(1, 1, 1, 1)
	_glass_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = GLASS_SHADER
	_glass_mat.set_shader_parameter("tint", GLASS_TINT)
	_glass_mat.set_shader_parameter("blur_amount", GLASS_BLUR)
	_glass_bg.material = _glass_mat
	_drawer.add_child(_glass_bg)

	# 顶部光边
	_glow_top = ColorRect.new()
	_glow_top.anchor_right = 1.0
	_glow_top.offset_bottom = GLOW_HEIGHT
	_glow_top.color = Color(1, 1, 1, 1)
	_glow_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_top_mat = ShaderMaterial.new()
	_glow_top_mat.shader = GLOW_SHADER
	_glow_top_mat.set_shader_parameter("glow_color", _accent)
	_glow_top_mat.set_shader_parameter("brightness", 0.0)
	_glow_top_mat.set_shader_parameter("edge_power", GLOW_EDGE_POWER)
	_glow_top.material = _glow_top_mat
	_drawer.add_child(_glow_top)

	# 底部光边
	_glow_bottom = ColorRect.new()
	_glow_bottom.anchor_top = 1.0
	_glow_bottom.anchor_right = 1.0
	_glow_bottom.anchor_bottom = 1.0
	_glow_bottom.offset_top = -GLOW_HEIGHT
	_glow_bottom.color = Color(1, 1, 1, 1)
	_glow_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_bottom_mat = ShaderMaterial.new()
	_glow_bottom_mat.shader = GLOW_SHADER
	_glow_bottom_mat.set_shader_parameter("glow_color", _accent)
	_glow_bottom_mat.set_shader_parameter("brightness", 0.0)
	_glow_bottom_mat.set_shader_parameter("edge_power", GLOW_EDGE_POWER)
	_glow_bottom.material = _glow_bottom_mat
	_drawer.add_child(_glow_bottom)

	# 把手 ›
	_handle_label = Label.new()
	_handle_label.text = "›"
	_handle_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_handle_label.add_theme_font_size_override("font_size", 22)
	_handle_label.add_theme_color_override("font_color", _muted)
	_handle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.add_child(_handle_label)

	# ── 季号横向选择条 ──
	_season_bar_root = Control.new()
	_season_bar_root.anchor_right = 1.0
	_season_bar_root.offset_left = DRAWER_PADDING_SIDE
	_season_bar_root.offset_right = -DRAWER_PADDING_SIDE
	_season_bar_root.offset_top = GLOW_HEIGHT + SEASON_BAR_TOP_PADDING
	_season_bar_root.offset_bottom = GLOW_HEIGHT + SEASON_BAR_TOP_PADDING + SEASON_BAR_HEIGHT
	_season_bar_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_season_bar_root.gui_input.connect(_on_season_bar_input)
	_season_bar_root.clip_contents = true
	_season_bar_root.visible = false
	_drawer.add_child(_season_bar_root)

	_season_bar_scroll = ScrollContainer.new()
	_season_bar_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_season_bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_season_bar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_season_bar_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_season_bar_root.add_child(_season_bar_scroll)
	_season_bar_scroll.offset_right = -SEASON_COUNT_WIDTH

	# 隐藏横向滚动条
	var hsb: HScrollBar = _season_bar_scroll.get_h_scroll_bar()
	if hsb != null:
		hsb.custom_minimum_size = Vector2(0.0, 0.0)
		var empty_style := StyleBoxEmpty.new()
		hsb.add_theme_stylebox_override("scroll", empty_style)
		hsb.add_theme_stylebox_override("grabber", empty_style)
		hsb.add_theme_stylebox_override("grabber_highlight", empty_style)
		hsb.add_theme_stylebox_override("grabber_pressed", empty_style)

	var season_pad := MarginContainer.new()
	season_pad.add_theme_constant_override("margin_left", 8)
	season_pad.add_theme_constant_override("margin_right", 8)
	season_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_season_bar_scroll.add_child(season_pad)

	_season_bar_row = HBoxContainer.new()
	_season_bar_row.add_theme_constant_override("separation", int(SEASON_BAR_GAP))
	_season_bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	season_pad.add_child(_season_bar_row)

	# ── 内容区（集数列表）──
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = DRAWER_PADDING_SIDE
	_content.offset_top = DRAWER_PADDING_VERTICAL
	_content.offset_right = -DRAWER_PADDING_SIDE
	_content.offset_bottom = -DRAWER_PADDING_VERTICAL
	_content.clip_contents = true
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.visible = false
	_drawer.add_child(_content)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(BUTTON_GAP))
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_list)

	# "共 x 季"——挂在季号条右侧，与季号条共存亡
	_season_count_label = Label.new()
	_season_count_label.anchor_left = 1.0
	_season_count_label.anchor_right = 1.0
	_season_count_label.anchor_top = 0.0
	_season_count_label.anchor_bottom = 0.0
	_season_count_label.offset_left = -SEASON_COUNT_WIDTH
	_season_count_label.offset_right = 0.0
	_season_count_label.offset_top = 0.0
	_season_count_label.offset_bottom = SEASON_BAR_HEIGHT
	_season_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_season_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_season_count_label.add_theme_font_size_override("font_size", SEASON_COUNT_FONT_SIZE)
	_season_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_season_count_label.visible = false
	_season_bar_root.add_child(_season_count_label)

	# ── 每集简介漂浮窗（毛玻璃 + 上下光带）──

	# 毛玻璃层（在 tooltip 主体下面）
	_tooltip_glass = ColorRect.new()
	_tooltip_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_glass.z_index = 198
	_tooltip_glass.visible = false
	_tooltip_glass_mat = ShaderMaterial.new()
	_tooltip_glass_mat.shader = GLASS_SHADER
	_tooltip_glass_mat.set_shader_parameter("tint", TOOLTIP_GLASS_TINT)
	_tooltip_glass_mat.set_shader_parameter("blur_amount", TOOLTIP_GLASS_BLUR)
	_tooltip_glass.material = _tooltip_glass_mat
	add_child(_tooltip_glass)

	# 顶部光带（在 tooltip 主体之上）
	_tooltip_glow_top = ColorRect.new()
	_tooltip_glow_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_glow_top.color = Color(1, 1, 1, 1)
	_tooltip_glow_top.z_index = 201
	_tooltip_glow_top.visible = false
	_tooltip_glow_top_mat = ShaderMaterial.new()
	_tooltip_glow_top_mat.shader = GLOW_SHADER
	_tooltip_glow_top_mat.set_shader_parameter("glow_color", _accent)
	_tooltip_glow_top_mat.set_shader_parameter("brightness", 0.55)
	_tooltip_glow_top_mat.set_shader_parameter("edge_power", 1.5)
	_tooltip_glow_top_mat.set_shader_parameter("vertical_falloff", 1.0)
	_tooltip_glow_top_mat.set_shader_parameter("core_amount", 0.4)
	_tooltip_glow_top_mat.set_shader_parameter("shimmer_amount", 0.15)
	_tooltip_glow_top_mat.set_shader_parameter("shimmer_speed", 1.5)
	_tooltip_glow_top_mat.set_shader_parameter("shape_flat", 0.6)
	_tooltip_glow_top.material = _tooltip_glow_top_mat
	add_child(_tooltip_glow_top)

	# 底部光带
	_tooltip_glow_bottom = ColorRect.new()
	_tooltip_glow_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_glow_bottom.color = Color(1, 1, 1, 1)
	_tooltip_glow_bottom.z_index = 201
	_tooltip_glow_bottom.visible = false
	_tooltip_glow_bottom_mat = ShaderMaterial.new()
	_tooltip_glow_bottom_mat.shader = GLOW_SHADER
	_tooltip_glow_bottom_mat.set_shader_parameter("glow_color", _accent)
	_tooltip_glow_bottom_mat.set_shader_parameter("brightness", 0.55)
	_tooltip_glow_bottom_mat.set_shader_parameter("edge_power", 1.5)
	_tooltip_glow_bottom_mat.set_shader_parameter("vertical_falloff", 1.0)
	_tooltip_glow_bottom_mat.set_shader_parameter("core_amount", 0.4)
	_tooltip_glow_bottom_mat.set_shader_parameter("shimmer_amount", 0.15)
	_tooltip_glow_bottom_mat.set_shader_parameter("shimmer_speed", 1.5)
	_tooltip_glow_bottom_mat.set_shader_parameter("shape_flat", 0.6)
	_tooltip_glow_bottom.material = _tooltip_glow_bottom_mat
	add_child(_tooltip_glow_bottom)

	# tooltip 主体：透明 PanelContainer，只负责内边距和布局
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 200
	_tooltip.visible = false
	var transparent_style := StyleBoxEmpty.new()
	transparent_style.content_margin_left = 18.0
	transparent_style.content_margin_right = 18.0
	transparent_style.content_margin_top = 16.0
	transparent_style.content_margin_bottom = 16.0
	_tooltip.add_theme_stylebox_override("panel", transparent_style)
	add_child(_tooltip)

	var tooltip_vbox := VBoxContainer.new()
	tooltip_vbox.add_theme_constant_override("separation", 8)
	_tooltip.add_child(tooltip_vbox)

	# 标题（视觉重量：大、亮、微暖）
	_tooltip_title = Label.new()
	_tooltip_title.add_theme_font_size_override("font_size", 17)
	_tooltip_title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	_tooltip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_title.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0.0)
	_tooltip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_vbox.add_child(_tooltip_title)

	# 发光分隔线（用 shader，带呼吸）
	var tooltip_sep := ColorRect.new()
	tooltip_sep.custom_minimum_size = Vector2(0.0, 1.5)
	tooltip_sep.color = Color(1, 1, 1, 1)
	tooltip_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_sep_mat = ShaderMaterial.new()
	_tooltip_sep_mat.shader = GLOW_SHADER
	_tooltip_sep_mat.set_shader_parameter("glow_color", _accent)
	_tooltip_sep_mat.set_shader_parameter("brightness", 0.38)
	_tooltip_sep_mat.set_shader_parameter("edge_power", 0.8)
	_tooltip_sep_mat.set_shader_parameter("vertical_falloff", 1.8)
	_tooltip_sep_mat.set_shader_parameter("core_amount", 0.0)
	_tooltip_sep_mat.set_shader_parameter("shimmer_amount", 0.10)
	_tooltip_sep_mat.set_shader_parameter("shimmer_speed", 0.9)
	_tooltip_sep_mat.set_shader_parameter("shape_flat", 0.95)
	tooltip_sep.material = _tooltip_sep_mat
	tooltip_vbox.add_child(tooltip_sep)

	# 简介
	_tooltip_body = Label.new()
	_tooltip_body.add_theme_font_size_override("font_size", 13)
	_tooltip_body.add_theme_color_override("font_color", Color(0.84, 0.82, 0.78, 1.0))
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_body.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0.0)
	_tooltip_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_vbox.add_child(_tooltip_body)

func _apply_visible_state(is_visible: bool) -> void:
	_glass_bg.visible = is_visible
	_glow_top.visible = is_visible
	_glow_bottom.visible = is_visible
	if _season_bar_root != null:
		_season_bar_root.visible = is_visible and _has_multi_season
	if _season_count_label != null:
		# 保险：即使 _season_bar_root 的 visible 因某些原因没生效，也强隐藏
		_season_count_label.visible = is_visible and _has_multi_season

# ---------- 布局 ----------

func _layout() -> void:
	if _drawer == null:
		return
	var h: float = _card_height * HEIGHT_RATIO
	if h < 100.0:
		h = 100.0
	var x: float = _card_right_x + OUTSET_FROM_CARD
	var y: float = _card_center_y - h * 0.5
	_drawer.position = Vector2(x, y)
	_drawer.size.y = h
	if not _expanded and not _collapsing:
		_drawer.size.x = HANDLE_WIDTH
	_update_list_layout()

func _update_list_layout() -> void:
	if _content == null or _list == null:
		return
	var w: float = _content.size.x
	if w < 0.0:
		w = 0.0
	_list.size = Vector2(w, _list.get_combined_minimum_size().y)
	_list.position = Vector2(0.0, _scroll_offset)
	_clamp_scroll()

func update_card_rect(right_x: float, center_y: float, h: float) -> void:
	_card_right_x = right_x
	_card_center_y = center_y
	_card_height = h
	_layout()

# ---------- 悬停 ----------

func set_hover_visible(value: bool) -> void:
	if _expanded or _collapsing:
		return
	if value:
		_want_hide = false
		_hide_timer = 0.0
		visible = true
		_kill_tween()
		if modulate.a < 1.0:
			_tween = create_tween()
			_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "modulate:a", 1.0, HANDLE_FADE)
		return
	if not _want_hide:
		_want_hide = true
		_hide_timer = 0.0

func _process(delta: float) -> void:
	# 兜底：抽屉真正收起时，把除把手外的所有装饰元素强制隐藏
	if not _expanded and not _collapsing and _drawer != null and _drawer.size.x <= HANDLE_WIDTH + 1.0:
		if _glass_bg.visible:
			_glass_bg.visible = false
		if _glow_top.visible:
			_glow_top.visible = false
		if _glow_bottom.visible:
			_glow_bottom.visible = false
		if _content.visible:
			_content.visible = false
		if _season_bar_root.visible:
			_season_bar_root.visible = false
		if _season_count_label.visible:
			_season_count_label.visible = false

	if _expanded and absf(_scroll_velocity) > 0.01:
		_step_scroll(delta)
	# ... 后面是原有的代码，不动 ...
	_update_glow(delta)
	_update_tooltip_breath()
	if _drawer != null and _drawer.size.x > HANDLE_WIDTH + 1.0:
		_update_list_layout()
	if not _want_hide or _expanded or not visible:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if _drawer.get_global_rect().has_point(mouse):
		_want_hide = false
		_hide_timer = 0.0
		return
	_hide_timer += delta
	if _hide_timer >= HIDE_DELAY:
		_want_hide = false
		_hide_timer = 0.0
		_kill_tween()
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, HANDLE_FADE)
		_tween.tween_callback(_on_fade_out_done)

func _update_tooltip_breath() -> void:
	if _tooltip == null or not _tooltip.visible:
		return
	if _tooltip_glow_top_mat == null or _tooltip_glow_bottom_mat == null:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var phase: float = sin(t * TOOLTIP_GLOW_BREATH_SPEED)
	var breath: float = TOOLTIP_GLOW_BREATH_MIN + (TOOLTIP_GLOW_BREATH_MAX - TOOLTIP_GLOW_BREATH_MIN) * (0.5 + phase * 0.5)
	_tooltip_glow_top_mat.set_shader_parameter("brightness", breath)
	_tooltip_glow_bottom_mat.set_shader_parameter("brightness", breath)
	if _tooltip_sep_mat != null:
		_tooltip_sep_mat.set_shader_parameter("brightness", 0.28 + breath * 0.22)

func _update_glow(delta: float) -> void:
	if not _expanded:
		return
	var f: float = 1.0 - exp(-delta * GLOW_FADE_SPEED)

	var top_target: float = GLOW_IDLE_BRIGHTNESS
	var bottom_target: float = GLOW_IDLE_BRIGHTNESS
	if _scroll_velocity > GLOW_TRIGGER_VELOCITY:
		top_target = GLOW_ACTIVE_BRIGHTNESS
	if _scroll_velocity < -GLOW_TRIGGER_VELOCITY:
		bottom_target = GLOW_ACTIVE_BRIGHTNESS

	if _bump_top > 0.0:
		top_target = maxf(top_target, _bump_top)
	if _bump_bottom > 0.0:
		bottom_target = maxf(bottom_target, _bump_bottom)

	_glow_top_brightness = lerpf(_glow_top_brightness, top_target, f)
	_glow_bottom_brightness = lerpf(_glow_bottom_brightness, bottom_target, f)
	_glow_top_mat.set_shader_parameter("brightness", _glow_top_brightness)
	_glow_bottom_mat.set_shader_parameter("brightness", _glow_bottom_brightness)

	# 形状铺平：独立追踪 bump 值，速度更慢——能看到光从中心铺向两边
	var shape_top_target: float = clampf(_bump_top / GLOW_BUMP_PEAK, 0.0, 1.0)
	var shape_bottom_target: float = clampf(_bump_bottom / GLOW_BUMP_PEAK, 0.0, 1.0)
	var shape_f: float = 1.0 - exp(-delta * GLOW_SHAPE_SPREAD_SPEED)
	_shape_top = lerpf(_shape_top, shape_top_target * GLOW_SHAPE_MAX, shape_f)
	_shape_bottom = lerpf(_shape_bottom, shape_bottom_target * GLOW_SHAPE_MAX, shape_f)
	_glow_top_mat.set_shader_parameter("shape_flat", _shape_top)
	_glow_bottom_mat.set_shader_parameter("shape_flat", _shape_bottom)

	if _bump_top > 0.0:
		_bump_top *= exp(-delta * GLOW_BUMP_DECAY)
		if _bump_top < 0.001:
			_bump_top = 0.0
	if _bump_bottom > 0.0:
		_bump_bottom *= exp(-delta * GLOW_BUMP_DECAY)
		if _bump_bottom < 0.001:
			_bump_bottom = 0.0

func _trigger_glow_bump(top: bool) -> void:
	# 只有 bump 已经衰减到峰值一半以下才重新触发，
	# 避免连续滚动时反复重置，导致形状来不及铺开
	var threshold: float = GLOW_BUMP_PEAK * 0.5
	if top:
		if _bump_top < threshold:
			_bump_top = GLOW_BUMP_PEAK
	else:
		if _bump_bottom < threshold:
			_bump_bottom = GLOW_BUMP_PEAK

func _on_fade_out_done() -> void:
	if not _want_hide and not _expanded:
		visible = false

# ---------- 惯性滚动 ----------

func _step_scroll(delta: float) -> void:
	_scroll_velocity *= exp(-delta * SCROLL_FRICTION)
	if absf(_scroll_velocity) < SCROLL_MIN_VELOCITY:
		_scroll_velocity = 0.0
	_scroll_offset += _scroll_velocity * delta
	_clamp_scroll()
	_list.position.y = _scroll_offset

func _clamp_scroll() -> void:
	if _content == null or _list == null:
		return
	var view_h: float = _content.size.y
	var list_h: float = _list.get_combined_minimum_size().y
	var min_offset: float = minf(0.0, view_h - list_h)
	if _scroll_offset > 0.0:
		_scroll_offset = 0.0
		_scroll_velocity = 0.0
	elif _scroll_offset < min_offset:
		_scroll_offset = min_offset
		_scroll_velocity = 0.0

# ---------- 公开 API ----------

func set_episodes(item_id: String, episodes: Array) -> void:
	_item_id = item_id
	_all_episodes.clear()
	for ep in episodes:
		if ep is Dictionary:
			_all_episodes.append(ep)

	# 统计季号
	var season_set: Dictionary = {}
	for ep in _all_episodes:
		var s_value: Variant = ep.get("season")
		if s_value != null:
			season_set[int(s_value)] = true

	_seasons.clear()
	for s: Variant in season_set.keys():
		_seasons.append(int(s))
	_seasons.sort()

	_has_multi_season = _seasons.size() > 1

	# 构建季号条
	_rebuild_season_bar()

	# 右下角"共 x 季"
	if _has_multi_season:
		var dim_color: Color = _muted
		dim_color.a = SEASON_COUNT_DIM
		_season_count_label.text = "共 %d 季" % _seasons.size()
		_season_count_label.add_theme_color_override("font_color", dim_color)
		_season_count_label.visible = true
	else:
		_season_count_label.visible = false

	# 内容区顶部：多季时给季号条让位
	if _has_multi_season:
		_content.offset_top = GLOW_HEIGHT + SEASON_BAR_TOP_PADDING + SEASON_BAR_HEIGHT + SEASON_BAR_BOTTOM_PADDING
	else:
		_content.offset_top = DRAWER_PADDING_VERTICAL

	# 显示第一季
	var default_season: int = _seasons[0] if not _seasons.is_empty() else -1
	_display_season(default_season)

func _display_season(season_num: int) -> void:

	# 清空 list —— 用 remove_child + free 立即释放，
	# 避免 queue_free 延迟一帧导致的新旧行共存、列表高度计算错乱
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()


	# 找出该季的集
	var season_episodes: Array[Dictionary] = []
	for ep in _all_episodes:
		var s_value: Variant = ep.get("season")
		var s_key: int = int(s_value) if s_value != null else -1
		if s_key == season_num:
			season_episodes.append(ep)

	# 排序：优先用 episode 号，没有就用 display_order
	season_episodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_v: Variant = a.get("episode")
		var b_v: Variant = b.get("episode")
		var a_n: int = int(a_v) if a_v != null else int(a.get("display_order", 0))
		var b_n: int = int(b_v) if b_v != null else int(b.get("display_order", 0))
		return a_n < b_n
	)

	# 渲染，集号每季从 01 独立计
	var display_num: int = 1
	for ep in season_episodes:
		var ep_copy: Dictionary = ep.duplicate()
		ep_copy["_display_num"] = display_num
		_list.add_child(_make_row(ep_copy))
		display_num += 1

	# 重置滚动
	_scroll_offset = 0.0
	_scroll_velocity = 0.0
	_layout()

	# 高亮对应季按钮
	_set_active_season(season_num)

func clear() -> void:
	_collapse(true)
	if _season_count_label != null:
		_season_count_label.visible = false
	visible = false

func set_theme_colors(accent: Color, muted: Color) -> void:
	_accent = accent
	_muted = muted
	_handle_label.add_theme_color_override("font_color", _muted)
	if _glow_top_mat != null:
		_glow_top_mat.set_shader_parameter("glow_color", _accent)
	if _glow_bottom_mat != null:
		_glow_bottom_mat.set_shader_parameter("glow_color", _accent)
	if _season_count_label != null and _season_count_label.visible:
		var dim_color: Color = _muted
		dim_color.a = SEASON_COUNT_DIM
		_season_count_label.add_theme_color_override("font_color", dim_color)
	for s_key: Variant in _season_buttons.keys():
		var btn: Button = _season_buttons[s_key]
		_update_season_button_style(btn, int(s_key) == _active_season)

# ---------- 季号条 ----------

func _rebuild_season_bar() -> void:
	for child in _season_bar_row.get_children():
		child.queue_free()
	_season_buttons.clear()

	if not _has_multi_season:
		_season_bar_root.visible = false
		return

	for s_num in _seasons:
		var btn: Button = _make_season_button(s_num)
		_season_bar_row.add_child(btn)
		_season_buttons[s_num] = btn
	_season_bar_root.visible = true

func _make_season_button(season_num: int) -> Button:
	var btn := Button.new()
	btn.text = "第 %d 季" % season_num
	btn.custom_minimum_size = Vector2(SEASON_BUTTON_MIN_WIDTH, SEASON_BUTTON_HEIGHT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", SEASON_BUTTON_FONT_SIZE)
	_update_season_button_style(btn, false)
	btn.pressed.connect(_on_season_button_pressed.bind(season_num))
	btn.mouse_entered.connect(func(): _animate_season_button(btn, true))
	btn.mouse_exited.connect(func(): _animate_season_button(btn, false))
	return btn

func _animate_season_button(btn: Button, hovered: bool) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	# pivot 是缩放中心——第一次 hover 时按钮已完成布局，size 可用
	btn.pivot_offset = btn.size * 0.5
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * (1.03 if hovered else 1.0), 0.15)

func _update_season_button_style(btn: Button, active: bool) -> void:
	# normal：选中亮，未选中暗淡
	var normal_bg: Color = _accent
	normal_bg.a = SEASON_BUTTON_ACTIVE_ALPHA if active else SEASON_BUTTON_IDLE_ALPHA

	# hover：未选中时明显提亮，选中时再亮一点
	var hover_bg: Color = _accent
	if active:
		hover_bg.a = minf(SEASON_BUTTON_ACTIVE_ALPHA + 0.12, 1.0)
	else:
		hover_bg.a = SEASON_BUTTON_HOVER_ALPHA

	# pressed：更亮
	var pressed_bg: Color = _accent
	pressed_bg.a = minf(SEASON_BUTTON_ACTIVE_ALPHA + 0.22, 1.0)

	# 三种状态各自的 StyleBox
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = normal_bg
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = SEASON_BUTTON_PADDING_H
	normal_style.content_margin_right = SEASON_BUTTON_PADDING_H

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = hover_bg
	hover_style.set_corner_radius_all(4)
	hover_style.content_margin_left = SEASON_BUTTON_PADDING_H
	hover_style.content_margin_right = SEASON_BUTTON_PADDING_H
	# hover 时加一圈主题色描边
	hover_style.border_color = _accent
	hover_style.border_color.a = 0.55
	hover_style.set_border_width_all(1)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = pressed_bg
	pressed_style.set_corner_radius_all(4)
	pressed_style.content_margin_left = SEASON_BUTTON_PADDING_H
	pressed_style.content_margin_right = SEASON_BUTTON_PADDING_H

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# 文字亮度：normal 暗淡，hover/pressed 都到 1.0
	var normal_text: Color = _muted
	normal_text.a = SEASON_BUTTON_TEXT_ACTIVE_ALPHA if active else SEASON_BUTTON_TEXT_IDLE_ALPHA
	var full_text: Color = _muted
	full_text.a = 1.0

	btn.add_theme_color_override("font_color", normal_text)
	btn.add_theme_color_override("font_hover_color", full_text)
	btn.add_theme_color_override("font_pressed_color", full_text)
	btn.add_theme_color_override("font_hover_pressed_color", full_text)

func _on_season_button_pressed(season_num: int) -> void:
	if season_num == _active_season:
		return
	_display_season(season_num)
	get_viewport().set_input_as_handled()

func _set_active_season(season_num: int) -> void:
	_active_season = season_num
	for s_key: Variant in _season_buttons.keys():
		var btn: Button = _season_buttons[s_key]
		_update_season_button_style(btn, int(s_key) == season_num)

func _on_season_bar_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_season_bar(-1.0)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_season_bar(1.0)
		get_viewport().set_input_as_handled()

func _scroll_season_bar(direction: float) -> void:
	if _season_bar_scroll == null:
		return
	var max_scroll: int = int(_season_bar_scroll.get_h_scroll_bar().max_value)
	var current: int = _season_bar_scroll.scroll_horizontal
	var next: int = int(clampf(
		float(current) + direction * SEASON_BAR_WHEEL_STEP,
		0.0,
		float(maxi(0, max_scroll))
	))
	_season_bar_scroll.scroll_horizontal = next

# ---------- 行 ----------

func _make_row(ep: Dictionary) -> MarginContainer:
	var wrapper := MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("margin_left", 0)
	wrapper.add_theme_constant_override("margin_right", 0)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW

	var empty_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)

	var hover_style := StyleBoxFlat.new()
	var hover_bg: Color = _accent
	hover_bg.a = BUTTON_BG_HOVER_ALPHA
	hover_style.bg_color = hover_bg
	var border_color: Color = _accent
	border_color.a = BUTTON_BORDER_HOVER_ALPHA
	hover_style.border_color = border_color
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	var pressed_bg: Color = _accent
	pressed_bg.a = BUTTON_BG_HOVER_ALPHA * 1.6
	pressed_style.bg_color = pressed_bg
	pressed_style.border_color = border_color
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12.0
	hbox.offset_right = -12.0
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var num_label := Label.new()
	var num_value: Variant = ep.get("_display_num", 1)
	num_label.text = "%02d" % int(num_value)
	num_label.custom_minimum_size = Vector2(BUTTON_NUM_WIDTH, 0.0)
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	num_label.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	num_label.add_theme_color_override("font_color", BUTTON_TEXT_COLOR)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(num_label)

	var title_label := Label.new()
	var title_text: String = str(ep.get("title", "")).strip_edges()
	title_label.text = title_text
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", BUTTON_TITLE_FONT_SIZE)
	title_label.add_theme_color_override("font_color", BUTTON_TITLE_COLOR)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title_label)

	btn.mouse_entered.connect(_on_episode_hover_start.bind(wrapper, ep))
	btn.mouse_exited.connect(_on_episode_hover_end.bind(wrapper))
	btn.pressed.connect(_on_episode_pressed.bind(ep))

	wrapper.add_child(btn)
	return wrapper

func _on_episode_hover_start(wrapper: MarginContainer, ep: Dictionary) -> void:
	_animate_row(wrapper, int(ROW_EXTEND))
	_tooltip_generation += 1
	var gen: int = _tooltip_generation
	await get_tree().create_timer(TOOLTIP_SHOW_DELAY).timeout
	if gen != _tooltip_generation or not _expanded:
		return
	_show_episode_tooltip(ep)

func _on_episode_hover_end(wrapper: MarginContainer) -> void:
	_animate_row(wrapper, 0)
	_tooltip_generation += 1
	_hide_episode_tooltip()

func _show_episode_tooltip(ep: Dictionary) -> void:
	if _tooltip == null:
		return
	var title: String = str(ep.get("title", "")).strip_edges()
	var overview: String = str(ep.get("overview", "")).strip_edges()

	if title.is_empty() and overview.is_empty():
		_hide_episode_tooltip()
		return

	_tooltip_title.text = title if not title.is_empty() else "（无标题）"
	_tooltip_body.text = overview if not overview.is_empty() else "（暂无简介）"

	# 限制高度
	var max_body_h: float = TOOLTIP_MAX_HEIGHT - 80.0
	_tooltip_body.custom_minimum_size.y = 0.0
	_tooltip_body.clip_contents = false
	# 让 Godot 先算一遍高度
	_tooltip.reset_size()
	var body_h: float = _tooltip_body.get_minimum_size().y
	if body_h > max_body_h:
		_tooltip_body.custom_minimum_size.y = max_body_h
		_tooltip_body.clip_contents = true
	else:
		_tooltip_body.custom_minimum_size.y = 0.0

	_tooltip.visible = true
	_tooltip.reset_size()

	# 位置：鼠标右侧 + 下方偏移，超屏自动贴边
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tip_size: Vector2 = _tooltip.size
	var pos_x: float = mouse.x + TOOLTIP_MARGIN
	var pos_y: float = mouse.y + TOOLTIP_MARGIN
	if pos_x + tip_size.x > vp.x - 8.0:
		pos_x = mouse.x - tip_size.x - TOOLTIP_MARGIN
	if pos_y + tip_size.y > vp.y - 8.0:
		pos_y = vp.y - tip_size.y - 8.0
	if pos_y < 8.0:
		pos_y = 8.0
	_tooltip.position = Vector2(pos_x, pos_y)

	# 同步毛玻璃和上下光带的位置和尺寸
	_tooltip_glass.position = Vector2(pos_x, pos_y)
	_tooltip_glass.size = tip_size
	_tooltip_glass.visible = true

	_tooltip_glow_top.position = Vector2(pos_x, pos_y)
	_tooltip_glow_top.size = Vector2(tip_size.x, TOOLTIP_GLOW_HEIGHT)
	_tooltip_glow_top.visible = true

	_tooltip_glow_bottom.position = Vector2(pos_x, pos_y + tip_size.y - TOOLTIP_GLOW_HEIGHT)
	_tooltip_glow_bottom.size = Vector2(tip_size.x, TOOLTIP_GLOW_HEIGHT)
	_tooltip_glow_bottom.visible = true

func _hide_episode_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false
	if _tooltip_glass != null:
		_tooltip_glass.visible = false
	if _tooltip_glow_top != null:
		_tooltip_glow_top.visible = false
	if _tooltip_glow_bottom != null:
		_tooltip_glow_bottom.visible = false

func _animate_row(wrapper: MarginContainer, target: int) -> void:
	if wrapper.has_meta("row_tween"):
		var old: Tween = wrapper.get_meta("row_tween")
		if old != null and old.is_valid():
			old.kill()
	var current: int = wrapper.get_theme_constant("margin_left")
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(v: float) -> void:
			wrapper.add_theme_constant_override("margin_left", int(v)),
		float(current),
		float(target),
		ROW_EXTEND_DURATION
	)
	wrapper.set_meta("row_tween", tw)

# ---------- 交互 ----------

func _on_drawer_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if not _expanded:
			_expand()
			get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _expanded:
			if _scroll_offset >= -1.0:
				_trigger_glow_bump(true)
			_scroll_velocity += SCROLL_SPEED
			get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _expanded:
			var list_h: float = _list.get_combined_minimum_size().y
			var view_h: float = _content.size.y
			var min_offset: float = minf(0.0, view_h - list_h)
			if _scroll_offset <= min_offset + 1.0:
				_trigger_glow_bump(false)
			_scroll_velocity -= SCROLL_SPEED
			get_viewport().set_input_as_handled()

func _expand() -> void:
	_expanded = true
	_collapsing = false
	_want_hide = false
	_hide_timer = 0.0
	_kill_tween()
	_apply_visible_state(true)
	_content.visible = true
	_content.modulate.a = 0.0
	_handle_label.visible = false
	modulate.a = 1.0
	visible = true
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_drawer, "size:x", DRAWER_WIDTH, EXPAND_DURATION)
	_tween.tween_property(_content, "modulate:a", 1.0, CONTENT_FADE_IN)
	if _has_multi_season:
		_tween.tween_property(_season_bar_root, "modulate:a", 1.0, CONTENT_FADE_IN)

func _collapse(instant: bool = false) -> void:
	_hide_episode_tooltip()
	_tooltip_generation += 1
	_expanded = false
	_collapsing = true
	_kill_tween()
	_apply_visible_state(false)
	if _season_count_label != null:
		_season_count_label.visible = false
	if _season_bar_root != null:
		_season_bar_root.visible = false
	_scroll_velocity = 0.0
	_bump_top = 0.0
	_bump_bottom = 0.0
	_shape_top = 0.0
	_shape_bottom = 0.0
	if instant:
		_drawer.size.x = HANDLE_WIDTH
		_content.visible = false
		_content.modulate.a = 1.0
		_handle_label.visible = true
		_collapsing = false
		_layout()
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_drawer, "size:x", HANDLE_WIDTH, COLLAPSE_DURATION)
	_tween.tween_property(_content, "modulate:a", 0.0, COLLAPSE_DURATION * 0.7)
	if _has_multi_season:
		_tween.tween_property(_season_bar_root, "modulate:a", 0.0, COLLAPSE_DURATION * 0.7)
	_tween.chain().tween_callback(func():
		_collapsing = false
		if not _expanded:
			_content.visible = false
			_content.modulate.a = 1.0
			_handle_label.visible = true
			_layout()
	)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

func _on_episode_pressed(ep: Dictionary) -> void:
	var ep_id: String = str(ep.get("id", ""))
	if ep_id.is_empty():
		return
	episode_clicked.emit(_item_id, ep_id)

func _unhandled_input(event: InputEvent) -> void:
	if not _expanded or _collapsing:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		if not _drawer.get_global_rect().has_point(mouse_pos):
			_collapse(false)
			get_viewport().set_input_as_handled()