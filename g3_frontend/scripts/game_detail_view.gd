extends Control
class_name G3GameDetailView

signal back_requested()
signal play_requested(item_id: String)

const UI_BASE_W: float = 1920.0
const UI_BASE_H: float = 1080.0
const UI_SCALE_MIN: float = 0.62
const UI_SCALE_MAX: float = 1.30
# 字号单独一条曲线：下限抬高，避免小窗口下字看不清
const FONT_SCALE_MIN: float = 0.90
const FONT_SCALE_MAX: float = 1.30

const HERO_HEIGHT_RATIO: float = 0.55
const LOGO_MAX_W: float = 420.0
const LOGO_MAX_H: float = 160.0

const BG_COLOR: Color = Color(0.075, 0.095, 0.125, 1.0)

# 面板升起
const PANEL_TOP_RATIO_INIT: float = 0.40
const PANEL_TOP_RATIO_MIN: float = 0.10
const PANEL_WHEEL_STEP: float = 0.06
const PANEL_SCROLL_SPEED: float = 12.0
const PANEL_WHEEL_PIXELS: int = 60

# 文字层级
const COLOR_META_KEY: Color = Color(0.55, 0.62, 0.68, 1.0)
const COLOR_META_VAL: Color = Color(0.85, 0.88, 0.92, 1.0)
const COLOR_DESC: Color = Color(0.78, 0.80, 0.84, 1.0)
const COLOR_PLAYTIME: Color = Color(0.62, 0.66, 0.70, 1.0)
const COLOR_NO_CONTENT: Color = Color(0.55, 0.60, 0.65, 1.0)

const META_KEY_W_BASE: float = 60.0
const META_ROW_H_BASE: float = 20.0
const TITLE_H_BASE: float = 50.0
const DESC_LINE_SPACING_BASE: float = 7.5

# LOGO 漂移：面板上方 → 右栏顶部（起点小、终点大）
const LOGO_START_W: float = 400.0
const LOGO_START_H: float = 150.0
const LOGO_END_W: float = 560.0
const LOGO_END_H: float = 210.0
const LOGO_MARGIN_BASE: float = 60.0
const LOGO_START_TOP_GAP_BASE: float = 24.0
const LOGO_END_TOP_GAP_BASE: float = 24.0
const LOGO_END_MAX_RIGHT_RATIO: float = 0.85
const RIGHT_COL_TOP_SPACER_BASE: float = 110.0

# 截图大屏：固定高度，宽度按图片比例
const SHOT_BIG_H: float = 440.0

# 面板顶部羽化渐变
const PANEL_GRADIENT_SHADER: Shader = preload("res://shaders/panel_gradient.gdshader")
const PANEL_COLOR: Color = Color(0.055, 0.065, 0.085, 0.97)
const PANEL_TOP_ALPHA: float = 0.1
const PANEL_GRADIENT_MAX_RATIO: float = 0.50
# 向上延伸的羽化区高度 / 面板实际高度
const PANEL_EXTEND_RATIO: float = 0.85

var _current_game: Dictionary = {}
var _ui_scale: float = 1.0
var _font_scale: float = 1.0
var _font_manager: Node = null

# 面板状态
var _panel_top_ratio: float = PANEL_TOP_RATIO_INIT
var _panel_top_target: float = PANEL_TOP_RATIO_INIT
# 内容滚动的目标位置（实际 scroll_vertical 每帧朝它平滑追）
var _scroll_target: float = 0.0

var _bg: ColorRect
var _hero_rect: TextureRect
var _back_btn: Button
var _hero_hot_zone: Control = null
var _logo_rect: TextureRect
var _logo_alpha: float = 1.0

var _panel: PanelContainer
var _panel_bg: ColorRect = null
var _panel_scroll: ScrollContainer
var _panel_content: HBoxContainer
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _right_top_spacer: Control
var _stage_gap: Control

var _title_wrap: Control
var _title_label: Label

# 评分行节点（独立一行，不参与元数据 60px 列宽）
var _row_metacritic: HBoxContainer
var _meta_mc_label: Label

var _meta_rows: VBoxContainer
var _row_dev: HBoxContainer
var _row_pub: HBoxContainer
var _row_date: HBoxContainer
var _row_genres: HBoxContainer
var _row_tags: HBoxContainer
var _meta_dev_key: Label
var _meta_dev_val: Label
var _meta_pub_key: Label
var _meta_pub_val: Label
var _meta_date_key: Label
var _meta_date_val: Label
var _meta_genres_key: Label
var _meta_genres_val: Label
var _meta_tags_key: Label
var _meta_tags_val: Label

var _play_row: HBoxContainer
var _play_btn: Button
var _playtime_label: RichTextLabel
var _content_container: VBoxContainer
var _no_content_label: Label

# 截图播放器
var _screenshot_paths: Array[String] = []
var _shot_aspects: Array[float] = []
var _shot_index: int = 0
var _screenshots_player: VBoxContainer
var _shot_big_bg: ColorRect
var _shot_big: TextureRect
var _shot_thumbs: HBoxContainer
var _shot_empty: Label

var _image_overlay: Control
var _image_overlay_rect: TextureRect
var _image_overlay_bg: ColorRect
var _overlay_counter: Label
var _overlay_prev_btn: Button
var _overlay_next_btn: Button
var _overlay_paths: Array[String] = []
var _overlay_index: int = 0

func set_font_manager(fm: Node) -> void:
	_font_manager = fm

func apply_fontset() -> void:
	if _font_manager == null:
		return
	_apply_game_fonts()
	_apply_font_sizes(_font_scale)

func _apply_game_fonts() -> void:
	_apply_font_to_label(_title_label, "game_title")
	if _playtime_label != null and _font_manager != null:
		var f: FontFile = _font_manager.get_font_for("game_playtime", "games")
		if f != null:
			_playtime_label.add_theme_font_override("normal_font", f)
		else:
			_playtime_label.remove_theme_font_override("normal_font")
	_apply_font_to_label(_no_content_label, "game_meta")
	_apply_font_to_label(_meta_mc_label, "game_meta")
	_apply_font_to_label(_shot_empty, "game_meta")
	for lbl in [_meta_dev_key, _meta_dev_val, _meta_pub_key, _meta_pub_val,
			_meta_date_key, _meta_date_val, _meta_genres_key, _meta_genres_val,
			_meta_tags_key, _meta_tags_val]:
		_apply_font_to_label(lbl, "game_meta")
	_apply_font_to_button(_back_btn, "ui_default")
	_apply_font_to_button(_play_btn, "ui_default")

func _apply_font_to_label(label: Label, key: String) -> void:
	if label == null or _font_manager == null:
		return
	var f: FontFile = _font_manager.get_font_for(key, "games")
	if f != null:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")

func _apply_font_to_rich(rt: RichTextLabel, key: String) -> void:
	if rt == null or _font_manager == null:
		return
	var f: FontFile = _font_manager.get_font_for(key, "games")
	if f != null:
		rt.add_theme_font_override("normal_font", f)
		rt.add_theme_font_override("bold_font", f)
		rt.add_theme_font_override("italics_font", f)
	else:
		rt.remove_theme_font_override("normal_font")
		rt.remove_theme_font_override("bold_font")
		rt.remove_theme_font_override("italics_font")

func _apply_font_to_button(btn: Button, key: String) -> void:
	if btn == null or _font_manager == null:
		return
	var f: FontFile = _font_manager.get_font_for(key, "games")
	if f != null:
		btn.add_theme_font_override("font", f)
	else:
		btn.remove_theme_font_override("font")

func _font_size(key: String, fallback: int) -> int:
	if _font_manager == null:
		return fallback
	return _font_manager.get_size_for(key, fallback, "games")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_compute_scale()
	_relayout()
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_on_vp_changed")

func _on_vp_changed() -> void:
	_compute_scale()
	_relayout()
	# 同步刷新右栏比例，避免切窗口后要滚动才重算
	_update_screenshot_sizes()

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
	return 0

# ---------------------------------------------------------------------------
# 元数据行构造辅助

func _make_meta_key(text: String) -> Label:
	var key := Label.new()
	key.text = text
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", COLOR_META_KEY)
	key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.custom_minimum_size = Vector2(META_KEY_W_BASE, 0.0)
	return key

func _make_meta_val() -> Label:
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", COLOR_META_VAL)
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return val

func _make_meta_row(key_text: String, key_out: Array, val_out: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y = META_ROW_H_BASE
	var key := _make_meta_key(key_text)
	var val := _make_meta_val()
	row.add_child(key)
	row.add_child(val)
	key_out.append(key)
	val_out.append(val)
	return row

# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_bg.color = BG_COLOR
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.z_index = -1
	add_child(_bg)

	# Hero
	_hero_rect = TextureRect.new()
	_hero_rect.anchor_right = 1.0
	_hero_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_rect.visible = false
	_hero_rect.z_index = 0
	add_child(_hero_rect)

	# LOGO
	_logo_rect = TextureRect.new()
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_rect.visible = false
	_logo_rect.z_index = 15
	add_child(_logo_rect)

	# 返回
	_back_btn = Button.new()
	_back_btn.text = "← 返回"
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_btn.add_theme_font_size_override("font_size", 16)
	_back_btn.pressed.connect(func(): back_requested.emit())
	_back_btn.z_index = 10
	add_child(_back_btn)
	# Hero 区滚轮热区：鼠标在 Hero 上滚动也能升/降面板
	_hero_hot_zone = Control.new()
	_hero_hot_zone.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hero_hot_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	_hero_hot_zone.gui_input.connect(_on_hero_hot_zone_input)
	_hero_hot_zone.z_index = 1
	add_child(_hero_hot_zone)

	# 面板渐变背景
	_panel_bg = ColorRect.new()
	_panel_bg.name = "PanelGradientBg"
	_panel_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_bg.z_index = 4
	_panel_bg.color = Color.WHITE
	if PANEL_GRADIENT_SHADER != null:
		var pg_mat := ShaderMaterial.new()
		pg_mat.shader = PANEL_GRADIENT_SHADER
		pg_mat.set_shader_parameter("panel_color", PANEL_COLOR)
		pg_mat.set_shader_parameter("top_alpha", PANEL_TOP_ALPHA)
		pg_mat.set_shader_parameter("gradient_ratio", 0.0)
		pg_mat.set_shader_parameter("extend_ratio", PANEL_EXTEND_RATIO)
		_panel_bg.material = pg_mat
		_panel_bg.set_meta("mat", pg_mat)
	else:
		push_warning("面板渐变 shader 加载失败：panel_gradient.gdshader")
	add_child(_panel_bg)

	# 面板
	_panel = PanelContainer.new()
	_panel.clip_contents = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_gui_input)
	_panel.z_index = 5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_top = 0
	style.border_color = Color(0.35, 0.45, 0.58, 0.7)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_panel_scroll = ScrollContainer.new()
	_panel_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_scroll.clip_contents = false
	_panel.add_child(_panel_scroll)

	_panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var vsb: VScrollBar = _panel_scroll.get_v_scroll_bar()
	if vsb != null:
		vsb.custom_minimum_size = Vector2.ZERO
		var empty_style := StyleBoxEmpty.new()
		vsb.add_theme_stylebox_override("scroll", empty_style)
		vsb.add_theme_stylebox_override("grabber", empty_style)
		vsb.add_theme_stylebox_override("grabber_highlight", empty_style)
		vsb.add_theme_stylebox_override("grabber_pressed", empty_style)
		vsb.visible = false

	_panel_content = HBoxContainer.new()
	_panel_content.add_theme_constant_override("separation", 32)
	_panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# IGNORE：让滚轮一路冒泡到 _panel（_panel.gui_input 里手动处理）
	_panel_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_scroll.add_child(_panel_content)

	_left_col = VBoxContainer.new()
	_left_col.add_theme_constant_override("separation", 16)
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.size_flags_stretch_ratio = 62.0
	_left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_content.add_child(_left_col)

	_right_col = VBoxContainer.new()
	_right_col.add_theme_constant_override("separation", 8)
	_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_col.size_flags_stretch_ratio = 38.0
	_right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_content.add_child(_right_col)

	# 游玩时长
	_playtime_label = RichTextLabel.new()
	_playtime_label.bbcode_enabled = true
	_playtime_label.fit_content = true
	_playtime_label.scroll_active = false
	_playtime_label.add_theme_font_size_override("normal_font_size", 14)
	_playtime_label.add_theme_color_override("default_color", COLOR_PLAYTIME)
	_playtime_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# --- 终极修复 ---
	# 强制给一个 300 的保底宽度，防止在 HBoxContainer 中被挤压成 0 像素
	_playtime_label.custom_minimum_size = Vector2(300.0, 24.0)
	# 水平方向不要收缩，跟着最小宽度走；垂直居中
	_playtime_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_playtime_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 标题容器
	_title_wrap = Control.new()
	_title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.add_child(_title_wrap)

	# 标题
	_title_label = Label.new()
	_title_label.text = ""
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_label.custom_minimum_size = Vector2.ZERO
	_title_wrap.custom_minimum_size.y = TITLE_H_BASE
	_title_wrap.add_child(_title_label)
	_title_wrap.visible = false

	# 元数据行容器
	var keys: Array = []
	var vals: Array = []
	_meta_rows = VBoxContainer.new()
	_meta_rows.add_theme_constant_override("separation", 6)
	_meta_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 评分行：独立一行 Label（"评分：88 / 100" 整串），不参与元数据列宽
	_row_metacritic = HBoxContainer.new()
	_row_metacritic.add_theme_constant_override("separation", 0)
	_row_metacritic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_metacritic.visible = false

	_meta_mc_label = Label.new()
	_meta_mc_label.add_theme_font_size_override("font_size", 13)
	_meta_mc_label.add_theme_color_override("font_color", COLOR_META_VAL)
	_meta_mc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_metacritic.add_child(_meta_mc_label)

	_row_dev = _make_meta_row("开发商：", keys, vals)
	_meta_dev_key = keys[0]
	_meta_dev_val = vals[0]
	keys.clear()
	vals.clear()
	_row_pub = _make_meta_row("发行商：", keys, vals)
	_meta_pub_key = keys[0]
	_meta_pub_val = vals[0]
	keys.clear()
	vals.clear()
	_row_date = _make_meta_row("发售日期：", keys, vals)
	_meta_date_key = keys[0]
	_meta_date_val = vals[0]
	keys.clear()
	vals.clear()
	_row_genres = _make_meta_row("类型：", keys, vals)
	_meta_genres_key = keys[0]
	_meta_genres_val = vals[0]
	keys.clear()
	vals.clear()
	_row_tags = _make_meta_row("标签：", keys, vals)
	_meta_tags_key = keys[0]
	_meta_tags_val = vals[0]
	_meta_tags_val.max_lines_visible = 2
	_meta_tags_val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_meta_tags_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# GOG 顺序：类型 → 风格 → 发售时间 → 开发商 → 发行商
	_meta_rows.add_child(_row_genres)
	_meta_rows.add_child(_row_tags)
	_meta_rows.add_child(_row_date)
	_meta_rows.add_child(_row_dev)
	_meta_rows.add_child(_row_pub)

	# 启动按钮（按钮 + 游玩时长一排）
	_play_row = HBoxContainer.new()
	_play_row.add_theme_constant_override("separation", 32)
	_play_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_play_row.alignment = BoxContainer.ALIGNMENT_BEGIN	
	_left_col.add_child(_play_row)

	_play_btn = Button.new()
	_play_btn.text = "▶  开始游戏"
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play_btn.add_theme_font_size_override("font_size", 16)
	# 关键修复：让按钮不要垂直填满 HBox，避免被 RichTextLabel 异常高度拉长
	_play_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var play_style := StyleBoxFlat.new()
	play_style.bg_color = Color(0.25, 0.50, 0.80, 0.55)
	play_style.set_corner_radius_all(2)
	play_style.border_color = Color(0.55, 0.75, 1.0, 0.65)
	play_style.set_border_width_all(1)
	play_style.content_margin_left = 22.0
	play_style.content_margin_right = 22.0
	play_style.content_margin_top = 10.0
	play_style.content_margin_bottom = 10.0
	_play_btn.add_theme_stylebox_override("normal", play_style)
	var play_hover := play_style.duplicate() as StyleBoxFlat
	play_hover.bg_color = Color(0.35, 0.62, 0.95, 0.75)
	play_hover.border_color = Color(0.65, 0.85, 1.0, 0.85)
	_play_btn.add_theme_stylebox_override("hover", play_hover)
	_play_btn.add_theme_stylebox_override("pressed", play_hover)
	_play_btn.pressed.connect(_on_play_pressed)
	_play_row.add_child(_play_btn)
	_play_row.add_child(_playtime_label)

	# 开始游戏行与截图播放器之间的间距（把截图 + 元数据整体下推）
	_stage_gap = Control.new()
	_stage_gap.custom_minimum_size.y = 80.0
	_stage_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_col.add_child(_stage_gap)

	# 截图播放器
	_screenshots_player = VBoxContainer.new()
	_screenshots_player.add_theme_constant_override("separation", 8)
	_screenshots_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_col.add_child(_screenshots_player)

	var big_center := HBoxContainer.new()
	big_center.alignment = BoxContainer.ALIGNMENT_CENTER
	big_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screenshots_player.add_child(big_center)

	var big_wrap := PanelContainer.new()
	big_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	big_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_wrap.clip_contents = true
	var big_style := StyleBoxFlat.new()
	big_style.bg_color = Color(0.03, 0.04, 0.06, 1.0)
	big_style.set_corner_radius_all(6)
	big_wrap.add_theme_stylebox_override("panel", big_style)
	big_center.add_child(big_wrap)

	_shot_big_bg = ColorRect.new()
	_shot_big_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot_big_bg.color = Color(0.03, 0.04, 0.06, 1.0)
	_shot_big_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_wrap.add_child(_shot_big_bg)

	_shot_big = TextureRect.new()
	_shot_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shot_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shot_big.mouse_filter = Control.MOUSE_FILTER_STOP
	_shot_big.gui_input.connect(_on_shot_big_gui_input)
	big_wrap.add_child(_shot_big)

	_shot_thumbs = HBoxContainer.new()
	_shot_thumbs.add_theme_constant_override("separation", 6)
	_shot_thumbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screenshots_player.add_child(_shot_thumbs)

	_shot_empty = Label.new()
	_shot_empty.text = "暂无截图"
	_shot_empty.add_theme_font_size_override("font_size", 14)
	_shot_empty.add_theme_color_override("font_color", COLOR_NO_CONTENT)
	_shot_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shot_empty.visible = false
	_screenshots_player.add_child(_shot_empty)

	# 评分行（截图播放器之后、元数据之前）
	_left_col.add_child(_row_metacritic)
	# 元数据 5 行（放在评分行之后）
	_left_col.add_child(_meta_rows)

	# 简介右栏
	_right_top_spacer = Control.new()
	_right_top_spacer.custom_minimum_size.y = RIGHT_COL_TOP_SPACER_BASE
	_right_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_col.add_child(_right_top_spacer)

	# 简介内容块容器（text / video 交替）
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 10)
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_col.add_child(_content_container)

	_no_content_label = Label.new()
	_no_content_label.add_theme_font_size_override("font_size", 14)
	_no_content_label.add_theme_color_override("font_color", COLOR_NO_CONTENT)
	_no_content_label.text = "（暂无详细信息。可在刮削器中获取元数据）"
	_no_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_no_content_label.visible = false
	_left_col.add_child(_no_content_label)

	# 截图放大查看器
	_image_overlay = Control.new()
	_image_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_image_overlay.visible = false
	_image_overlay.z_index = 100
	add_child(_image_overlay)

	_image_overlay_bg = ColorRect.new()
	_image_overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image_overlay_bg.color = Color(0, 0, 0, 0.88)
	_image_overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_image_overlay.add_child(_image_overlay_bg)

	_image_overlay_rect = TextureRect.new()
	_image_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image_overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_overlay_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_overlay.add_child(_image_overlay_rect)

	_image_overlay_bg.gui_input.connect(_on_overlay_input)

	_overlay_counter = Label.new()
	_overlay_counter.anchor_left = 0.5
	_overlay_counter.anchor_right = 0.5
	_overlay_counter.offset_left = -100.0
	_overlay_counter.offset_right = 100.0
	_overlay_counter.offset_top = 18.0
	_overlay_counter.offset_bottom = 50.0
	_overlay_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_counter.add_theme_font_size_override("font_size", 18)
	_overlay_counter.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_overlay_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_overlay.add_child(_overlay_counter)

	_overlay_prev_btn = Button.new()
	_overlay_prev_btn.text = "‹"
	_overlay_prev_btn.anchor_left = 0.0
	_overlay_prev_btn.anchor_right = 0.0
	_overlay_prev_btn.anchor_top = 0.5
	_overlay_prev_btn.anchor_bottom = 0.5
	_overlay_prev_btn.offset_left = 20.0
	_overlay_prev_btn.offset_right = 90.0
	_overlay_prev_btn.offset_top = -50.0
	_overlay_prev_btn.offset_bottom = 50.0
	_overlay_prev_btn.focus_mode = Control.FOCUS_NONE
	_overlay_prev_btn.add_theme_font_size_override("font_size", 56)
	_overlay_prev_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.7))
	_overlay_prev_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	_overlay_prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_overlay_prev_btn.pressed.connect(func(): _step_overlay(-1))
	_image_overlay.add_child(_overlay_prev_btn)

	_overlay_next_btn = Button.new()
	_overlay_next_btn.text = "›"
	_overlay_next_btn.anchor_left = 1.0
	_overlay_next_btn.anchor_right = 1.0
	_overlay_next_btn.anchor_top = 0.5
	_overlay_next_btn.anchor_bottom = 0.5
	_overlay_next_btn.offset_left = -90.0
	_overlay_next_btn.offset_right = -20.0
	_overlay_next_btn.offset_top = -50.0
	_overlay_next_btn.offset_bottom = 50.0
	_overlay_next_btn.focus_mode = Control.FOCUS_NONE
	_overlay_next_btn.add_theme_font_size_override("font_size", 56)
	_overlay_next_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.7))
	_overlay_next_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	_overlay_next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_overlay_next_btn.pressed.connect(func(): _step_overlay(1))
	_image_overlay.add_child(_overlay_next_btn)
	# 返回按钮挪到场景树最后，保证鼠标拾取优先命中它
	_back_btn.move_to_front()
# ---------------------------------------------------------------------------

func _on_hero_hot_zone_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	# 鼠标位置必须真的在 Hero 区（面板顶边之上）
	if _panel != null and mb.position.y > _panel.position.y:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# 往下滚 → 面板升起（目标 ratio 减小）
		if _panel_top_target > PANEL_TOP_RATIO_MIN + 0.001:
			_panel_top_target = maxf(
				PANEL_TOP_RATIO_MIN,
				_panel_top_target - PANEL_WHEEL_STEP
			)
			get_viewport().set_input_as_handled()
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		# 往上滚 → 面板下降（目标 ratio 增大）
		if _panel_top_target < PANEL_TOP_RATIO_INIT - 0.001:
			_panel_top_target = minf(
				PANEL_TOP_RATIO_INIT,
				_panel_top_target + PANEL_WHEEL_STEP
			)
			get_viewport().set_input_as_handled()
		return

func _on_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var scroll_bar: VScrollBar = _panel_scroll.get_v_scroll_bar()
		var max_scroll: float = maxf(0.0, scroll_bar.max_value - scroll_bar.page)
		if _panel_top_ratio > PANEL_TOP_RATIO_MIN + 0.001:
			_panel_top_target = maxf(
				PANEL_TOP_RATIO_MIN,
				_panel_top_target - PANEL_WHEEL_STEP
			)
		elif _scroll_target < max_scroll - 0.5:
			_scroll_target = minf(_scroll_target + PANEL_WHEEL_PIXELS, max_scroll)
		get_viewport().set_input_as_handled()
		return

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _scroll_target > 0.5:
			_scroll_target = maxf(0.0, _scroll_target - PANEL_WHEEL_PIXELS)
		else:
			_panel_top_target = minf(
				PANEL_TOP_RATIO_INIT,
				_panel_top_target + PANEL_WHEEL_STEP
			)
		get_viewport().set_input_as_handled()
		return

# ---------------------------------------------------------------------------

func _apply_font_sizes(s: float) -> void:
	if _title_label == null:
		return
	var title_base: int = _font_size("game_title", 40)
	var meta_base: int = _font_size("game_meta", 13)
	var playtime_base: int = _font_size("game_playtime", 14)
	var desc_base: int = _font_size("game_desc", 15)
	var ui_base: int = _font_size("ui_default", 16)

	_back_btn.add_theme_font_size_override("font_size", int(float(ui_base) * s))
	_title_label.add_theme_font_size_override("font_size", int(float(title_base) * s))
	_title_label.custom_minimum_size = Vector2.ZERO
	if _title_wrap != null:
		var title_h: float = maxf(float(title_base) * 1.25, 30.0)
		_title_wrap.custom_minimum_size.y = title_h * s
	_play_btn.add_theme_font_size_override("font_size", int(float(ui_base) * s))
	_playtime_label.add_theme_font_size_override("normal_font_size", int(float(playtime_base) * s))
	_no_content_label.add_theme_font_size_override("font_size", int(float(meta_base) * s))
	if _meta_mc_label != null:
		_meta_mc_label.add_theme_font_size_override("font_size", int(float(meta_base) * s))
	for lbl in [_meta_dev_key, _meta_dev_val, _meta_pub_key, _meta_pub_val,
			_meta_date_key, _meta_date_val, _meta_genres_key, _meta_genres_val,
			_meta_tags_key, _meta_tags_val]:
		if lbl != null:
			lbl.add_theme_font_size_override("font_size", int(float(meta_base) * s))
	var key_w: float = META_KEY_W_BASE * s
	var row_h: float = META_ROW_H_BASE * s
	for row in [_row_dev, _row_pub, _row_date, _row_genres, _row_tags]:
		if row != null:
			row.custom_minimum_size.y = row_h
	for key in [_meta_dev_key, _meta_pub_key, _meta_date_key,
			_meta_genres_key, _meta_tags_key]:
		if key != null:
			key.custom_minimum_size.x = key_w
	for state in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = _play_btn.get_theme_stylebox(state) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = 22.0 * s
			sb.content_margin_right = 22.0 * s
			sb.content_margin_top = 10.0 * s
			sb.content_margin_bottom = 10.0 * s

func _update_screenshot_sizes() -> void:
	var s: float = _ui_scale

	var win_w: float = size.x
	var left_ratio: float = 0.62
	if win_w < 1400.0:
		left_ratio = 0.55
	if win_w < 1100.0:
		left_ratio = 0.50
	_left_col.size_flags_stretch_ratio = left_ratio
	_right_col.size_flags_stretch_ratio = 1.0 - left_ratio
	_right_col.custom_minimum_size.x = 320.0 * s
	call_deferred("_refresh_logo_drift")

	if _shot_thumbs == null:
		return
	var count: int = _shot_thumbs.get_child_count()
	if count <= 0:
		return
	var avail_w: float = _left_avail_w()
	var gap: float = 6.0 * s
	var each_w: float = (avail_w - float(count - 1) * gap) / float(count)
	each_w = maxf(each_w, 80.0 * s)
	var each_h: float = each_w * 9.0 / 16.0
	_shot_thumbs.add_theme_constant_override("separation", int(gap))
	for child in _shot_thumbs.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(each_w, each_h)

	if not _shot_aspects.is_empty():
		_apply_shot_big_size(_shot_index, avail_w)

func _left_avail_w() -> float:
	# 直接推算左栏宽，不依赖 _left_col.size.x（第一次进详情页时它是 0）。
	var ratio: float = _left_col.size_flags_stretch_ratio
	var panel_padding: float = 80.0
	var sep: float = 32.0 * _ui_scale
	var content_w: float = size.x - panel_padding - sep
	if content_w <= 0.0:
		return 0.0
	return content_w * ratio

func _update_shot_big() -> void:
	if _shot_big == null:
		return
	if _screenshot_paths.is_empty():
		_shot_big.texture = null
		return
	var i: int = clampi(_shot_index, 0, _screenshot_paths.size() - 1)
	var path: String = _screenshot_paths[i]
	var img := Image.new()
	if img.load(path) != OK:
		return
	_shot_big.texture = ImageTexture.create_from_image(img)
	_apply_shot_big_size(i)

func _apply_shot_big_size(index: int, avail_w: float = -1.0) -> void:
	if _shot_big == null:
		return
	var s: float = _ui_scale
	var aspect: float = 16.0 / 9.0
	if index >= 0 and index < _shot_aspects.size():
		aspect = _shot_aspects[index]
	if aspect <= 0.0:
		aspect = 16.0 / 9.0
	var h: float = SHOT_BIG_H * s
	var w: float = h * aspect

	var limit: float = avail_w
	if limit <= 0.0:
		limit = _left_avail_w()
	if limit > 0.0:
		var max_w: float = limit - 16.0 * s
		if max_w > 0.0 and w > max_w:
			w = max_w
			h = w / aspect
	_shot_big.custom_minimum_size = Vector2(w, h)

func _update_thumb_selection() -> void:
	if _shot_thumbs == null:
		return
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color(0, 0, 0, 0)
	gold.set_corner_radius_all(3)
	gold.border_width_left = 2
	gold.border_width_right = 2
	gold.border_width_top = 2
	gold.border_width_bottom = 2
	gold.border_color = Color(0.88, 0.66, 0.36, 0.9)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0, 0, 0, 0)
	plain.set_corner_radius_all(3)
	for i in range(_shot_thumbs.get_child_count()):
		var b: Button = _shot_thumbs.get_child(i) as Button
		if b == null:
			continue
		var sb: StyleBoxFlat = gold if i == _shot_index else plain
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", sb)

func _on_thumb_pressed(index: int) -> void:
	_shot_index = index
	_update_shot_big()
	_update_thumb_selection()

func _on_shot_big_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
		_open_image_overlay_for_current()
		get_viewport().set_input_as_handled()

func _open_image_overlay_for_current() -> void:
	if _screenshot_paths.is_empty():
		return
	_overlay_paths.clear()
	for p in _screenshot_paths:
		_overlay_paths.append(p)
	_overlay_index = clampi(_shot_index, 0, _screenshot_paths.size() - 1)
	_show_overlay_image()
	_image_overlay.visible = true
	_image_overlay.move_to_front()

func _rebuild_content_blocks(blocks: Array) -> void:
	if _content_container == null:
		return
	for c in _content_container.get_children():
		_content_container.remove_child(c)
		c.free()
	if blocks.is_empty():
		_content_container.visible = false
		return
	_content_container.visible = true

	var desc_base: int = _font_size("game_desc", 15)
	var desc_size: int = int(float(desc_base) * _font_scale)
	var line_spacing: int = int(DESC_LINE_SPACING_BASE * _font_scale)

	for raw in blocks:
		if not (raw is Dictionary):
			continue
		var b: Dictionary = raw
		var btype: String = str(b.get("type", ""))
		if btype == "text":
			var content: String = str(b.get("content", ""))
			if content.strip_edges().is_empty():
				continue
			var rt := RichTextLabel.new()
			rt.bbcode_enabled = true
			rt.fit_content = true
			rt.scroll_active = false
			rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rt.add_theme_font_size_override("normal_font_size", desc_size)
			rt.add_theme_color_override("default_color", COLOR_DESC)
			rt.add_theme_constant_override("line_separation", line_spacing)
			rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _font_manager != null:
				var f: FontFile = _font_manager.get_font_for("game_desc", "games")
				if f != null:
					rt.add_theme_font_override("normal_font", f)
					rt.add_theme_font_override("bold_font", f)
					rt.add_theme_font_override("italics_font", f)
			rt.append_text(content)
			_content_container.add_child(rt)
		elif btype == "video":
			var path_str: String = str(b.get("path", ""))
			if path_str.is_empty() or not FileAccess.file_exists(path_str):
				continue
			if not ClassDB.class_exists(&"AnimatedImageLoader") or not ClassDB.class_exists(&"AnimatedImagePlayer"):
				continue
			var anim = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_file", path_str)
			if anim == null:
				continue
			var win_w: float = size.x
			var left_ratio: float = 0.62
			if win_w < 1400.0:
				left_ratio = 0.55
			if win_w < 1100.0:
				left_ratio = 0.50
			var right_w: float = (win_w - 80.0 - 32.0) * (1.0 - left_ratio)
			if right_w < 100.0:
				right_w = 300.0
			var video_h: float = right_w * 9.0 / 16.0
			var wrap := Control.new()
			wrap.custom_minimum_size = Vector2(0.0, video_h)
			wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content_container.add_child(wrap)
			var player := ClassDB.instantiate(&"AnimatedImagePlayer") as Control
			if player == null:
				wrap.queue_free()
				continue
			player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player.set("expand_mode", 1)
			player.set("stretch_mode", 5)
			player.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player.set("animated_image", anim)
			player.set("playing", true)
			wrap.add_child(player)

func _update_desc_line_spacing() -> void:
	var spacing: int = int(DESC_LINE_SPACING_BASE * _font_scale)
	if _content_container == null:
		return
	for c in _content_container.get_children():
		if c is RichTextLabel:
			(c as RichTextLabel).add_theme_constant_override("line_separation", spacing)

func _relayout() -> void:
	if _hero_rect == null:
		return
	var s: float = _ui_scale
	var top_offset: int = _compute_top_offset()
	_apply_font_sizes(_font_scale)
	_update_desc_line_spacing()

	var vp := get_viewport().get_visible_rect().size
	var hero_h: float = vp.y * HERO_HEIGHT_RATIO
	_hero_rect.offset_left = 0.0
	_hero_rect.offset_right = 0.0
	_hero_rect.offset_top = top_offset
	_hero_rect.offset_bottom = int(float(top_offset) + hero_h)

	_back_btn.position = Vector2(24.0 * s, float(top_offset) + 16.0 * s)
	_back_btn.custom_minimum_size = Vector2(120.0 * s, 36.0 * _font_scale)
	# Hero 热区只覆盖 Hero 区域（面板顶边之上），避免抢面板的滚轮
	if _hero_hot_zone != null:
		var hero_top: float = float(top_offset)
		var hero_bottom: float = float(top_offset) + vp.y * HERO_HEIGHT_RATIO
		_hero_hot_zone.position = Vector2(0.0, hero_top)
		_hero_hot_zone.size = Vector2(size.x, hero_bottom - hero_top)

	_panel_content.add_theme_constant_override("separation", int(32.0 * s))
	_left_col.add_theme_constant_override("separation", int(16.0 * s))
	_right_col.add_theme_constant_override("separation", int(8.0 * s))
	_play_row.add_theme_constant_override("separation", int(32.0 * s))
	_play_row.custom_minimum_size.y = 40.0 * _font_scale
	_play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_screenshots_player.add_theme_constant_override("separation", int(8.0 * s))
	if _stage_gap != null:
		_stage_gap.custom_minimum_size.y = 80.0 * s
	if _right_top_spacer != null:
		_right_top_spacer.custom_minimum_size.y = (LOGO_END_H + LOGO_END_TOP_GAP_BASE) * s

	_apply_panel_layout()
	# 延后一帧：此刻 _left_col.size.x 还没算好，直接调会拿到小值
	call_deferred("_update_screenshot_sizes")

func _apply_panel_layout() -> void:
	if _panel == null or _bg == null:
		return
	var panel_top_y: float = size.y * _panel_top_ratio
	_bg.position = Vector2.ZERO
	_bg.size = size
	_panel.position = Vector2(0.0, panel_top_y)
	_panel.size = Vector2(size.x, size.y - panel_top_y)
	if _panel_bg != null:
		var panel_h: float = _panel.size.y
		var extend_h: float = panel_h * PANEL_EXTEND_RATIO
		_panel_bg.position = Vector2(_panel.position.x, _panel.position.y - extend_h)
		_panel_bg.size = Vector2(_panel.size.x, panel_h + extend_h)
	var t: float = clampf(
		(PANEL_TOP_RATIO_INIT - _panel_top_ratio)
		/ (PANEL_TOP_RATIO_INIT - PANEL_TOP_RATIO_MIN),
		0.0, 1.0
	)
	if _panel_bg != null:
		var pg_mat: ShaderMaterial = _panel_bg.material as ShaderMaterial
		if pg_mat != null:
			pg_mat.set_shader_parameter("gradient_ratio", t * PANEL_GRADIENT_MAX_RATIO)
	_apply_logo_drift(t)

func _apply_logo_drift(t: float) -> void:
	if _logo_rect == null or not _logo_rect.visible:
		return
	var s: float = _ui_scale

	var start_w: float = LOGO_START_W * s
	var start_h: float = LOGO_START_H * s
	var start_x: float = size.x - start_w - LOGO_MARGIN_BASE * s
	var init_panel_top: float = size.y * PANEL_TOP_RATIO_INIT
	var start_y: float = init_panel_top - start_h - LOGO_START_TOP_GAP_BASE * s

	var end_w: float = LOGO_END_W * s
	var end_h: float = LOGO_END_H * s
	var right_col_w: float = _right_col.size.x
	if _right_col != null and right_col_w > 0.0:
		var max_end_w: float = right_col_w * LOGO_END_MAX_RIGHT_RATIO
		if end_w > max_end_w:
			end_w = max_end_w
			end_h = end_w / (LOGO_END_W / LOGO_END_H)
	var right_col_x: float = _right_col_origin_x()
	var end_x: float = right_col_x + (right_col_w - end_w) * 0.5
	var end_y: float = _panel.position.y + LOGO_END_TOP_GAP_BASE * s

	var cur_w: float = lerpf(start_w, end_w, t)
	var cur_h: float = lerpf(start_h, end_h, t)
	var cur_x: float = lerpf(start_x, end_x, t)
	var cur_y: float = lerpf(start_y, end_y, t)

	_logo_rect.position = Vector2(cur_x, cur_y)
	_logo_rect.size = Vector2(cur_w, cur_h)

func _right_col_origin_x() -> float:
	if _right_col == null:
		return 0.0
	return _right_col.global_position.x - global_position.x

func _refresh_logo_drift() -> void:
	if _logo_rect == null or not _logo_rect.visible:
		return
	var t: float = clampf(
		(PANEL_TOP_RATIO_INIT - _panel_top_ratio)
		/ (PANEL_TOP_RATIO_INIT - PANEL_TOP_RATIO_MIN),
		0.0, 1.0
	)
	_apply_logo_drift(t)

func show_game(game: Dictionary) -> void:
	_current_game = game
	_title_label.text = str(game.get("title", ""))

	# Hero
	var backdrop: Array = game.get("backdrop", [])
	var hero_loaded: bool = false
	if backdrop.size() > 0:
		var hero_path: String = str(backdrop[0]).replace("\\", "/")
		if FileAccess.file_exists(hero_path):
			var img := Image.new()
			if img.load(hero_path) == OK:
				_hero_rect.texture = ImageTexture.create_from_image(img)
				hero_loaded = true
	_hero_rect.visible = hero_loaded

	# LOGO
	var logo_path: String = str(game.get("logo", "")).replace("\\", "/")
	var logo_loaded: bool = false
	if not logo_path.is_empty() and FileAccess.file_exists(logo_path):
		var limg := Image.new()
		if limg.load(logo_path) == OK:
			limg.generate_mipmaps()
			_logo_rect.texture = ImageTexture.create_from_image(limg)
			logo_loaded = true
	_logo_rect.visible = logo_loaded

	# MC 评分
	var mc_score: int = int(game.get("metacritic", 0))
	if mc_score > 0:
		_meta_mc_label.text = "评分：%d / 100" % mc_score
		_row_metacritic.visible = true
	else:
		_row_metacritic.visible = false

	# 元数据 5 行
	var dev: String = str(game.get("developer", "")).strip_edges()
	var pub: String = str(game.get("publisher", "")).strip_edges()
	var release_date: String = str(game.get("release_date", "")).strip_edges()
	if release_date.is_empty():
		var yv: Variant = game.get("release_year")
		if yv != null:
			release_date = str(yv).strip_edges()
			if release_date.ends_with(".0"):
				release_date = release_date.substr(0, release_date.length() - 2)
			if release_date == "0" or release_date == "None":
				release_date = ""
	var genres: String = str(game.get("genres", "")).strip_edges()
	var tags: String = str(game.get("tags", "")).strip_edges()

	_meta_dev_val.text = dev
	_row_dev.visible = not dev.is_empty()
	_meta_pub_val.text = pub
	_row_pub.visible = not pub.is_empty()
	_meta_date_val.text = release_date
	_row_date.visible = not release_date.is_empty()
	_meta_genres_val.text = genres
	_row_genres.visible = not genres.is_empty()
	_meta_tags_val.text = tags
	_row_tags.visible = not tags.is_empty()

	# 游玩时长
	var secs: int = int(game.get("playtime_seconds", 0))
	var psn_secs: int = int(game.get("psn_playtime_seconds", 0))
	
	# 经典 PlayStation 蓝
	var ps_blue: String = "#0070D1"
	
	var parts: Array[String] = []
	if secs > 0:
		parts.append("G3 " + _fmt_playtime(secs))
	if psn_secs > 0:
		parts.append("[color=%s]PSN[/color] " % ps_blue + _fmt_playtime(psn_secs))
	
	if parts.is_empty():
		_playtime_label.text = "未游玩"
	else:
		_playtime_label.text = "  |  ".join(parts)
		
	# 强制触发一次尺寸重算，防止 RichTextLabel 在 HBox 中塌陷成 0 宽或异常高
	_playtime_label.update_minimum_size()

	# 截图播放器
	for c in _shot_thumbs.get_children():
		_shot_thumbs.remove_child(c)
		c.free()
	_screenshot_paths.clear()
	_shot_aspects.clear()
	_shot_index = 0

	var screenshots: Array = game.get("screenshots", [])
	var s_count: int = 0
	var limit: int = mini(screenshots.size(), 8)
	for i in range(limit):
		var sp: String = str(screenshots[i]).replace("\\", "/")
		if not FileAccess.file_exists(sp):
			continue
		var img := Image.new()
		if img.load(sp) != OK:
			continue
		var iw: int = img.get_width()
		var ih: int = img.get_height()
		var aspect: float = 16.0 / 9.0
		if iw > 0 and ih > 0:
			aspect = float(iw) / float(ih)
		var thumb_w: int = 160
		var thumb_img: Image = img.duplicate() as Image
		if thumb_img != null:
			var tw: int = img.get_width()
			var th: int = img.get_height()
			if tw > thumb_w:
				var nh: int = int(float(th) * float(thumb_w) / float(tw))
				thumb_img.resize(thumb_w, maxi(nh, 1), Image.INTERPOLATE_BILINEAR)

		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.clip_contents = true

		var tr := TextureRect.new()
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if thumb_img != null:
			tr.texture = ImageTexture.create_from_image(thumb_img)
		else:
			tr.texture = ImageTexture.create_from_image(img)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tr)

		btn.set_meta("screenshot_path", sp)
		btn.pressed.connect(_on_thumb_pressed.bind(s_count))
		_shot_thumbs.add_child(btn)
		_screenshot_paths.append(sp)
		_shot_aspects.append(aspect)
		s_count += 1

	var has_shots: bool = s_count > 0
	_shot_big.visible = has_shots
	_shot_thumbs.visible = has_shots
	_shot_empty.visible = not has_shots
	_screenshots_player.visible = true
	if has_shots:
		_update_shot_big()
		_update_thumb_selection()

	# 简介：纯文字（不再用图文混合）
	var desc: String = str(game.get("description", "")).strip_edges()
	var desc_blocks: Array = []
	if not desc.is_empty():
		desc_blocks.append({"type": "text", "content": desc})
	call_deferred("_rebuild_content_blocks", desc_blocks)

	# 无内容提示
	var has_content: bool = (not desc.is_empty()) or (s_count > 0)
	has_content = has_content or (not dev.is_empty()) or (not pub.is_empty())
	has_content = has_content or (not release_date.is_empty())
	has_content = has_content or (not genres.is_empty()) or (not tags.is_empty())
	_no_content_label.visible = not has_content

	# 复位面板状态
	_panel_top_ratio = PANEL_TOP_RATIO_INIT
	_panel_top_target = PANEL_TOP_RATIO_INIT
	_scroll_target = 0.0
	_logo_alpha = 1.0
	if _panel_scroll != null:
		_panel_scroll.scroll_vertical = 0
	if _logo_rect != null:
		_logo_rect.modulate.a = 1.0

	_relayout()
	_update_screenshot_sizes()

func _fmt_playtime(seconds: int) -> String:
	if seconds <= 0:
		return "未游玩"
	if seconds < 60:
		return "< 1 分钟"
	if seconds < 3600:
		return "%d 分钟" % (seconds / 60)
	return "%.1f 小时" % (float(seconds) / 3600.0)

func _show_overlay_image() -> void:
	if _overlay_index < 0 or _overlay_index >= _overlay_paths.size():
		return
	var path: String = _overlay_paths[_overlay_index]
	var img := Image.new()
	if img.load(path) != OK:
		return
	_image_overlay_rect.texture = ImageTexture.create_from_image(img)
	_overlay_counter.text = "%d / %d" % [_overlay_index + 1, _overlay_paths.size()]
	_overlay_prev_btn.visible = (_overlay_index > 0)
	_overlay_next_btn.visible = (_overlay_index < _overlay_paths.size() - 1)

func _step_overlay(delta: int) -> void:
	var ni: int = _overlay_index + delta
	if ni < 0 or ni >= _overlay_paths.size():
		return
	_overlay_index = ni
	_show_overlay_image()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_image_overlay.visible = false
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step_overlay(-1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step_overlay(1)
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if _image_overlay == null or not _image_overlay.visible:
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_LEFT:
		_step_overlay(-1)
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_RIGHT:
		_step_overlay(1)
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE:
		_image_overlay.visible = false
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	var follow: float = 1.0 - exp(-delta * PANEL_SCROLL_SPEED)
	var prev: float = _panel_top_ratio
	_panel_top_ratio = lerpf(_panel_top_ratio, _panel_top_target, follow)
	if absf(_panel_top_ratio - prev) > 0.0005:
		_apply_panel_layout()
	# 内容滚动平滑追目标（避免离散跳跃）
	if _panel_scroll != null:
		var cur: int = _panel_scroll.scroll_vertical
		var target: int = int(_scroll_target)
		if cur != target:
			var diff: float = float(target - cur)
			if absf(diff) < 1.0:
				_panel_scroll.scroll_vertical = target
			else:
				var step: float = diff * follow * 1.6
				if absf(step) < 1.0:
					step = sign(diff)
				_panel_scroll.scroll_vertical = cur + int(round(step))

func set_launching(launching: bool) -> void:
	if _play_btn == null:
		return
	if launching:
		_play_btn.text = "启动中…"
		_play_btn.disabled = true
	else:
		_play_btn.text = "▶  开始游戏"
		_play_btn.disabled = false

func _on_play_pressed() -> void:
	var item_id: String = str(_current_game.get("id", ""))
	if item_id.is_empty():
		return
	set_launching(true)
	play_requested.emit(item_id)
