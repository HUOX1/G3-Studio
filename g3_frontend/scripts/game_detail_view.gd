extends Control
class_name G3GameDetailView

signal back_requested()
signal play_requested(item_id: String)
signal game_hero_ready(media_key: String, has_hero: bool)
signal save_insights_requested(item_id: String)

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
# Explicit script preload does not rely on global class_name registry refresh.
const DVD_LAUNCH_BUTTON_SCRIPT = preload("res://scripts/dvd_launch_button.gd")
const META_GLYPH_SCRIPT = preload("res://scripts/detail_meta_glyph.gd")
const SAVE_INSIGHTS_VIEW_SCRIPT = preload("res://scripts/game_save_insights_view.gd")
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
# Recheck geometry after the detail view becomes visible for the first time.
var _layout_settle_frames: int = 0
var _media_token: int = 0
# Media decoding is performed off the UI thread. Completed results are committed
# as one batch so Hero, Logo and screenshot components never reveal one by one.
var _media_jobs: Array[Dictionary] = []
var _pending_media_result: Dictionary = {}
var _media_request_key: String = ""
var _current_media_key: String = ""
var _media_apply_delay_frames: int = 0
const MEDIA_TEXTURES_PER_FRAME: int = 2
var _media_texture_build_active: bool = false
var _media_texture_queue: Array[Dictionary] = []
var _media_texture_result: Dictionary = {}
var _media_texture_token: int = -1
var _media_texture_key: String = ""
var _media_hero_first: bool = false
var _prepared_hero_key: String = ""
var _prepared_hero_texture: Texture2D = null

var _bg: ColorRect
var _hero_rect: TextureRect
var _back_btn: Button
var _hero_hot_zone: Control = null
var _logo_rect: TextureRect
var _logo_alpha: float = 1.0

var _panel: PanelContainer
var _panel_bg: ColorRect = null
var _panel_theme_tween: Tween = null
var _panel_theme_top: Color = Color(0.10, 0.16, 0.24, 1.0)
var _panel_theme_bottom: Color = Color(0.08, 0.10, 0.14, 1.0)
var _panel_theme_strength: float = 0.0
var _panel_scroll: ScrollContainer
var _panel_content: HBoxContainer
# Parallel content stage. The existing HBox tree remains untouched.
var _save_scroll: ScrollContainer
var _save_view = null
var _save_toggle_btn: Button
var _save_launch_entry: Button
var _save_mode: bool = false
var _save_requested: bool = false
var _save_tween: Tween
var _save_scroll_target: float = 0.0
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _right_top_spacer: Control
var _left_media_spacer: Control
var _play_row: HBoxContainer

var _title_wrap: Control
var _title_label: Label

# 评分行节点（独立一行，不参与元数据 60px 列宽）
var _row_metacritic: HBoxContainer
var _meta_mc_label: Label
var _meta_mc_key: Label

var _meta_rows: GridContainer
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

# The launch button now lives in the right metadata column, without a drawer.
var _play_btn: Button
var _launch_slot: Control
var _launch_stage: Node2D
var _media_chassis: PanelContainer
var _launch_scale: float = 1.0
var _playtime_label: Label
var _playtime_dock: HBoxContainer
var _local_time_icon: Control
var _psn_time_icon: TextureRect
var _psn_time_label: Label
var _content_container: VBoxContainer
var _no_content_label: Label

# 截图播放器
var _screenshot_paths: Array[String] = []
var _shot_aspects: Array[float] = []
var _shot_index: int = 0
var _shot_big_cached_path: String = ""
var _shot_big_cached_image: Image = null
var _shot_big_cached_texture: Texture2D = null
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
	_apply_description_fontset()
	_update_desc_line_spacing()
	_apply_description_paragraph_spacing()

func _apply_game_fonts() -> void:
	_apply_font_to_label(_title_label, "game_title")
	_apply_font_to_label(_psn_time_label, "game_playtime")
	_apply_font_to_label(_playtime_label, "game_playtime")
	_apply_font_to_label(_no_content_label, "game_meta")
	_apply_font_to_label(_meta_mc_label, "game_meta")
	_apply_font_to_label(_meta_mc_key, "game_meta")
	_apply_font_to_label(_shot_empty, "game_meta")
	for lbl in [_meta_dev_key, _meta_dev_val, _meta_pub_key, _meta_pub_val,
			_meta_date_key, _meta_date_val, _meta_genres_key, _meta_genres_val,
			_meta_tags_key, _meta_tags_val]:
		_apply_font_to_label(lbl, "game_meta")
	_apply_metadata_colors()
	_apply_font_to_button(_back_btn, "ui_default")

func _apply_metadata_colors() -> void:
	if _font_manager == null:
		return
	var settings: Dictionary = _font_manager.get_field_settings("game_meta", "games")
	var label_hex := str(settings.get("label_color", "")).strip_edges()
	var value_hex := str(settings.get("value_color", "")).strip_edges()
	var base_hex := str(settings.get("font_color", "")).strip_edges()
	for lbl in [_meta_mc_key, _meta_dev_key, _meta_pub_key, _meta_date_key, _meta_genres_key, _meta_tags_key]:
		if lbl != null:
			if not label_hex.is_empty():
				lbl.add_theme_color_override("font_color", Color.from_string(label_hex, COLOR_META_KEY))
			elif base_hex.is_empty():
				lbl.add_theme_color_override("font_color", COLOR_META_KEY)
	for lbl in [_meta_dev_val, _meta_pub_val, _meta_date_val, _meta_genres_val, _meta_tags_val]:
		if lbl != null:
			if not value_hex.is_empty():
				lbl.add_theme_color_override("font_color", Color.from_string(value_hex, COLOR_META_VAL))
			elif base_hex.is_empty():
				lbl.add_theme_color_override("font_color", COLOR_META_VAL)

func _apply_description_fontset() -> void:
	if _font_manager == null or _content_container == null:
		return
	for child in _content_container.get_children():
		if child is RichTextLabel:
			_apply_font_to_rich(child as RichTextLabel, "game_desc")
			var settings: Dictionary = _font_manager.get_field_settings("game_desc", "games")
			var color_hex := str(settings.get("font_color", "")).strip_edges()
			var rich := child as RichTextLabel
			if not color_hex.is_empty():
				rich.add_theme_color_override("default_color", Color.from_string(color_hex, COLOR_DESC))
			else:
				rich.add_theme_color_override("default_color", COLOR_DESC)

func _apply_description_paragraph_spacing() -> void:
	if _content_container == null:
		return
	var spacing := 10
	if _font_manager != null:
		var settings: Dictionary = _font_manager.get_field_settings("game_desc", "games")
		spacing = clampi(int(settings.get("paragraph_spacing", 10)), 0, 24)
	_content_container.add_theme_constant_override("separation", int(float(spacing) * _font_scale))

func _apply_font_to_label(label: Label, key: String) -> void:
	if label == null or _font_manager == null:
		return
	var f: Font = _font_manager.get_font_for(key, "games")
	if f != null:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")
	_font_manager.apply_style_to_control(label, key, "games")

func _apply_font_to_rich(rt: RichTextLabel, key: String) -> void:
	if rt == null or _font_manager == null:
		return
	var f: Font = _font_manager.get_font_for(key, "games")
	if f != null:
		rt.add_theme_font_override("normal_font", f)
		rt.add_theme_font_override("bold_font", f)
		rt.add_theme_font_override("italics_font", f)
	else:
		rt.remove_theme_font_override("normal_font")
		rt.remove_theme_font_override("bold_font")
		rt.remove_theme_font_override("italics_font")
	_font_manager.apply_style_to_control(rt, key, "games")

func _apply_font_to_button(btn: Button, key: String) -> void:
	if btn == null or _font_manager == null:
		return
	var f: Font = _font_manager.get_font_for(key, "games")
	if f != null:
		btn.add_theme_font_override("font", f)
	else:
		btn.remove_theme_font_override("font")
	_font_manager.apply_style_to_control(btn, key, "games")

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


# 元数据卡片沿用已有 key/value Label，保留字体集和颜色设置能力。
func _wrap_meta_card(row: HBoxContainer, kind: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Borderless archive display: image glyph + two typographic levels.
	card.custom_minimum_size.y = 52.0
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(0)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)
	var labels: Array[Node] = row.get_children()
	for lbl in labels:
		row.remove_child(lbl)
	row.add_theme_constant_override("separation", 8)
	var glyph: Control = META_GLYPH_SCRIPT.new()
	glyph.set("kind", kind)
	glyph.custom_minimum_size = Vector2(20.0, 20.0)
	# Anchor the glyph to the first text line, not the entire two-line card.
	# The default FILL height centers the glyph inside the card and drifts with resizing.
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	for lbl in labels:
		texts.add_child(lbl)
		if lbl is Label:
			(lbl as Label).custom_minimum_size.x = 0.0
	row.add_child(texts)
	card.add_child(row)
	return card

func _set_card_visible(row: HBoxContainer, is_visible: bool) -> void:
	if row == null:
		return
	row.visible = is_visible
	var card: Control = row.get_parent() as Control
	if card != null:
		card.visible = is_visible

# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_build_hero_layer()
	_build_panel_frame()
	_build_detail_header_and_metadata()
	_build_launch_and_screenshots()
	_build_right_column()
	_build_playtime_footer()
	_build_save_stage()
	_build_image_overlay()

func _build_hero_layer() -> void:
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

func _build_panel_frame() -> void:
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
		pg_mat.set_shader_parameter("theme_top_color", _panel_theme_top)
		pg_mat.set_shader_parameter("theme_bottom_color", _panel_theme_bottom)
		pg_mat.set_shader_parameter("theme_strength", _panel_theme_strength)
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
	_panel_content.clip_contents = false
	_panel_content.add_theme_constant_override("separation", 32)
	_panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# IGNORE：让滚轮一路冒泡到 _panel（_panel.gui_input 里手动处理）
	_panel_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_scroll.add_child(_panel_content)

	_left_col = VBoxContainer.new()
	_left_col.clip_contents = false
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

func _build_save_stage() -> void:
	# A second direct child of the existing panel uses the same panel margins.
	# No new child is added to _panel_content, so the accepted 62/38 layout is stable.
	_save_scroll = ScrollContainer.new()
	_save_scroll.name = "SaveInsightsStage"
	_save_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_save_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_save_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_save_scroll.visible = false
	_panel.add_child(_save_scroll)
	_save_view = SAVE_INSIGHTS_VIEW_SCRIPT.new()
	_save_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_scroll.add_child(_save_view)

	# The visible entrance is a slim extension of the accepted launch device.
	# It lives in the same transformed stage, without touching its 504x120 internals.
	_save_launch_entry = Button.new()
	_save_launch_entry.name = "SaveArchiveLaunchExtension"
	_save_launch_entry.text = "游戏档案    /    SAVE ARCHIVE    ↗"
	_save_launch_entry.position = Vector2(0.0, -39.0)
	_save_launch_entry.custom_minimum_size = Vector2(504.0, 32.0)
	_save_launch_entry.size = Vector2(504.0, 32.0)
	_save_launch_entry.focus_mode = Control.FOCUS_NONE
	_save_launch_entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_save_launch_entry.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_launch_entry.add_theme_font_size_override("font_size", 15)
	_save_launch_entry.add_theme_color_override("font_color", Color(0.75, 0.86, 0.86))
	_save_launch_entry.add_theme_color_override("font_hover_color", Color(0.96, 0.98, 0.97))
	var entry_style := StyleBoxFlat.new()
	entry_style.bg_color = Color(0.055, 0.075, 0.085, 0.94)
	entry_style.border_color = Color(0.31, 0.45, 0.47, 0.85)
	entry_style.set_border_width_all(1)
	entry_style.set_corner_radius_all(3)
	entry_style.content_margin_left = 18
	entry_style.content_margin_right = 18
	_save_launch_entry.add_theme_stylebox_override("normal", entry_style)
	var hover_style := entry_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.105, 0.15, 0.16, 0.98)
	_save_launch_entry.add_theme_stylebox_override("hover", hover_style)
	_save_launch_entry.add_theme_stylebox_override("pressed", hover_style)
	_save_launch_entry.visible = false
	_save_launch_entry.pressed.connect(_on_save_stage_toggle)
	_launch_stage.add_child(_save_launch_entry)

	# The archive has a return affordance, but the original page has no floating tab.
	_save_toggle_btn = Button.new()
	_save_toggle_btn.name = "SaveInsightsReturn"
	_save_toggle_btn.text = "← 游戏资料  /  GAME DETAIL"
	_save_toggle_btn.focus_mode = Control.FOCUS_NONE
	_save_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_save_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_toggle_btn.add_theme_font_size_override("font_size", 13)
	_save_toggle_btn.add_theme_color_override("font_color", Color(0.77, 0.87, 0.88))
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.055, 0.075, 0.085, 0.83)
	back_style.set_corner_radius_all(3)
	back_style.set_content_margin_all(7)
	_save_toggle_btn.add_theme_stylebox_override("normal", back_style)
	_save_toggle_btn.add_theme_stylebox_override("hover", back_style)
	_save_toggle_btn.z_index = 11
	_save_toggle_btn.visible = false
	_save_toggle_btn.pressed.connect(_on_save_stage_toggle)
	add_child(_save_toggle_btn)

func _can_read_save(game: Dictionary) -> bool:
	if int(game.get("steam_appid", 0)) == 1245620:
		return true
	var title: String = str(game.get("title", "")).to_lower()
	var english: String = str(game.get("english_name", "")).to_lower()
	return title.contains("艾尔登法环") or title.contains("艾爾登法環") or title.contains("elden ring") or english.contains("elden ring")

func _on_save_stage_toggle() -> void:
	if _save_toggle_btn.disabled:
		return
	if _save_mode:
		_save_requested = false
		_animate_save_stage(false)
	else:
		var item_id: String = str(_current_game.get("id", ""))
		if item_id.is_empty():
			return
		_save_scroll_target = 0.0
		_save_scroll.scroll_vertical = 0
		_save_view.set_state({"status": "loading"})
		_save_requested = true
		_animate_save_stage(true)
		save_insights_requested.emit(item_id)

func set_save_insights(item_id: String, payload: Dictionary) -> void:
	# Async backend replies must never appear on a different game's detail view.
	if str(_current_game.get("id", "")) != item_id or not _save_requested:
		return
	if _save_view != null:
		_save_view.set_state(payload)
		_save_view.set_compact(_save_scroll.size.x < 850.0)

func _animate_save_stage(show_save: bool) -> void:
	if _save_tween != null and _save_tween.is_running():
		_save_tween.kill()
	var from_stage: Control = _save_scroll if not show_save else _panel_scroll
	var to_stage: Control = _panel_scroll if not show_save else _save_scroll
	_save_toggle_btn.disabled = true
	_save_launch_entry.disabled = true
	from_stage.pivot_offset = from_stage.size * 0.5
	_save_tween = create_tween()
	_save_tween.tween_property(from_stage, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_save_tween.parallel().tween_property(from_stage, "scale", Vector2.ONE * 0.987, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_save_tween.tween_callback(func() -> void:
		from_stage.visible = false
		from_stage.modulate.a = 1.0
		from_stage.scale = Vector2.ONE
		_save_mode = show_save
		to_stage.visible = true
		to_stage.pivot_offset = to_stage.size * 0.5
		to_stage.scale = Vector2.ONE * 0.982
		to_stage.modulate.a = 0.0
		_save_toggle_btn.visible = show_save
	)
	_save_tween.tween_property(to_stage, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_save_tween.parallel().tween_property(to_stage, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_save_tween.tween_callback(func() -> void:
		_save_toggle_btn.disabled = false
		_save_launch_entry.disabled = false
	)

func _reset_save_stage(game: Dictionary) -> void:
	if _save_tween != null and _save_tween.is_running():
		_save_tween.kill()
	_save_mode = false
	_save_requested = false
	_save_scroll_target = 0.0
	_panel_scroll.visible = true
	_panel_scroll.scale = Vector2.ONE
	_panel_scroll.modulate.a = 1.0
	_save_scroll.visible = false
	_save_scroll.scale = Vector2.ONE
	_save_scroll.modulate.a = 1.0
	_save_toggle_btn.disabled = false
	_save_toggle_btn.visible = false
	_save_launch_entry.disabled = false
	_save_launch_entry.visible = _can_read_save(game)

func _build_detail_header_and_metadata() -> void:

	# 游玩时长（右下角固定定位；布局在末尾构建）
	# A plain Label shares the same font metrics and vertical alignment as PSN time.
	# RichTextLabel's paragraph margins differ at window/fullscreen font scales.
	_playtime_label = Label.new()
	_playtime_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_playtime_label.add_theme_font_size_override("font_size", 14)
	_playtime_label.add_theme_color_override("font_color", COLOR_PLAYTIME)
	_playtime_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 给右下角时长保留最小宽度，防止 RichTextLabel 在容器中塌陷
	_playtime_label.custom_minimum_size = Vector2(210.0, 24.0)
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
	_meta_rows = GridContainer.new()
	_meta_rows.columns = 2
	_meta_rows.add_theme_constant_override("h_separation", 17)
	_meta_rows.add_theme_constant_override("v_separation", 11)
	_meta_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 评分行：独立一行 Label（"评分：88 / 100" 整串），不参与元数据列宽
	_row_metacritic = HBoxContainer.new()
	_row_metacritic.add_theme_constant_override("separation", 0)
	_row_metacritic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_metacritic.visible = false

	_meta_mc_key = _make_meta_key("评分")
	_row_metacritic.add_child(_meta_mc_key)
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

	# 档案卡片：评分、发售日期、开发商、发行商；类型仅保留这一处。
	_meta_rows.add_child(_wrap_meta_card(_row_metacritic, "score"))
	_meta_rows.add_child(_wrap_meta_card(_row_date, "date"))
	_meta_rows.add_child(_wrap_meta_card(_row_dev, "developer"))
	_meta_rows.add_child(_wrap_meta_card(_row_pub, "publisher"))
	_meta_rows.add_child(_wrap_meta_card(_row_genres, "genre"))

func _build_launch_and_screenshots() -> void:
	# Reserve only the media/intro alignment space; no left-side launcher remains.
	_play_row = HBoxContainer.new()
	_play_row.add_theme_constant_override("separation", 32)
	_play_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_row.clip_contents = false
	_play_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_play_row.alignment = BoxContainer.ALIGNMENT_BEGIN	
	_play_row.name = "MediaTopSpacer"
	_play_row.custom_minimum_size.y = 190.0
	_left_col.add_child(_play_row)
	_left_media_spacer = _play_row

	# 截图播放器
	_screenshots_player = VBoxContainer.new()
	_screenshots_player.add_theme_constant_override("separation", 8)
	_screenshots_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_col.add_child(_screenshots_player)

	# One physical media module houses the screen AND its thumbnail controls.
	# A centered shell keeps the legacy left-column layout intact.
	var media_center := HBoxContainer.new()
	media_center.alignment = BoxContainer.ALIGNMENT_CENTER
	media_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screenshots_player.add_child(media_center)
	var media_chassis := PanelContainer.new()
	_media_chassis = media_chassis
	media_chassis.name = "MediaDisplayChassis"
	media_chassis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chassis_style := StyleBoxFlat.new()
	chassis_style.bg_color = Color(0.035, 0.048, 0.056, 0.95)
	chassis_style.set_corner_radius_all(5)
	chassis_style.set_border_width_all(1)
	chassis_style.border_color = Color(0.25, 0.34, 0.38, 0.83)
	chassis_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	chassis_style.shadow_size = 5
	chassis_style.content_margin_left = 10.0
	chassis_style.content_margin_right = 10.0
	chassis_style.content_margin_top = 7.0
	chassis_style.content_margin_bottom = 9.0
	media_chassis.add_theme_stylebox_override("panel", chassis_style)
	media_center.add_child(media_chassis)
	var media_stack := VBoxContainer.new()
	media_stack.add_theme_constant_override("separation", 7)
	media_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media_chassis.add_child(media_stack)
	var media_header := HBoxContainer.new()
	media_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media_stack.add_child(media_header)
	var media_title := Label.new()
	media_title.text = "MEDIA DISPLAY"
	media_title.add_theme_font_size_override("font_size", 10)
	media_title.add_theme_color_override("font_color", Color(0.59, 0.70, 0.75, 0.84))
	media_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media_header.add_child(media_title)
	var media_header_space := Control.new()
	media_header_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media_header_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media_header.add_child(media_header_space)
	var media_indicator := Label.new()
	media_indicator.text = "●  VIEW"
	media_indicator.add_theme_font_size_override("font_size", 10)
	media_indicator.add_theme_color_override("font_color", Color(0.47, 0.67, 0.70, 0.76))
	media_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media_header.add_child(media_indicator)
	var big_center := HBoxContainer.new()
	big_center.alignment = BoxContainer.ALIGNMENT_CENTER
	big_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media_stack.add_child(big_center)

	var big_wrap := PanelContainer.new()
	big_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	big_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_wrap.clip_contents = true
	var big_style := StyleBoxFlat.new()
	# Phase 2.0: inset graphite media well, using the same restrained metal
	# language as Slim Loader without adding padding or changing screenshot size.
	big_style.bg_color = Color(0.045, 0.061, 0.073, 1.0)
	big_style.set_corner_radius_all(4)
	big_style.set_border_width_all(2)
	big_style.border_color = Color(0.29, 0.36, 0.39, 0.82)
	big_style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	big_style.shadow_size = 3
	# A zero-content-margin frame preserves the original image dimensions.
	big_style.content_margin_left = 0.0
	big_style.content_margin_right = 0.0
	big_style.content_margin_top = 0.0
	big_style.content_margin_bottom = 0.0
	big_wrap.add_theme_stylebox_override("panel", big_style)
	big_center.add_child(big_wrap)

	_shot_big_bg = ColorRect.new()
	_shot_big_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot_big_bg.color = Color(0.035, 0.048, 0.058, 1.0)
	_shot_big_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_wrap.add_child(_shot_big_bg)

	_shot_big = TextureRect.new()
	_shot_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shot_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shot_big.mouse_filter = Control.MOUSE_FILTER_STOP
	_shot_big.gui_input.connect(_on_shot_big_gui_input)
	big_wrap.add_child(_shot_big)
	# Empty-state text belongs to the inset screen, not below the media chassis.
	_shot_empty = Label.new()
	_shot_empty.text = "暂无截图"
	_shot_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shot_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shot_empty.add_theme_font_size_override("font_size", 14)
	_shot_empty.add_theme_color_override("font_color", COLOR_NO_CONTENT)
	_shot_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shot_empty.visible = false
	big_wrap.add_child(_shot_empty)
	# Foreground frame stays visible above the screenshot without intercepting clicks.
	var media_bezel := Panel.new()
	media_bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	media_bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bezel_style := StyleBoxFlat.new()
	bezel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bezel_style.set_corner_radius_all(4)
	bezel_style.set_border_width_all(2)
	bezel_style.border_color = Color(0.34, 0.43, 0.47, 0.86)
	media_bezel.add_theme_stylebox_override("panel", bezel_style)
	big_wrap.add_child(media_bezel)

	# The thumbnails are recessed controls inside the same chassis, not loose images.
	var thumb_tray := PanelContainer.new()
	thumb_tray.name = "MediaThumbnailTray"
	thumb_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray_style := StyleBoxFlat.new()
	tray_style.bg_color = Color(0.015, 0.023, 0.029, 0.95)
	tray_style.set_corner_radius_all(3)
	tray_style.set_border_width_all(1)
	tray_style.border_color = Color(0.14, 0.22, 0.26, 0.78)
	tray_style.content_margin_left = 4.0
	tray_style.content_margin_right = 4.0
	tray_style.content_margin_top = 5.0
	tray_style.content_margin_bottom = 5.0
	thumb_tray.add_theme_stylebox_override("panel", tray_style)
	media_stack.add_child(thumb_tray)
	_shot_thumbs = HBoxContainer.new()
	_shot_thumbs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shot_thumbs.add_theme_constant_override("separation", 6)
	_shot_thumbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_tray.add_child(_shot_thumbs)


func _build_right_column() -> void:
	# 右侧简介与档案资料同列，不重复出现在截图下方。
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

	# 右侧档案：只显示类型、发售日期、开发商、发行商及评分。
	# 标签数据仍保留于 game_metadata，但不在详情页重复显示。
	var archive_spacer := Control.new()
	archive_spacer.custom_minimum_size.y = 24.0
	archive_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_col.add_child(archive_spacer)
	_right_col.add_child(_meta_rows)

	_no_content_label = Label.new()
	_no_content_label.add_theme_font_size_override("font_size", 14)
	_no_content_label.add_theme_color_override("font_color", COLOR_NO_CONTENT)
	_no_content_label.text = "（暂无详细信息。可在刮削器中获取元数据）"
	_no_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_no_content_label.visible = false
	_right_col.add_child(_no_content_label)

	# The launcher remains in the right column, but is drawn at one uniform
	# scale. Its internal 504x120 layout, animation and hit targets are untouched.
	# VBox reserves only the required screen-space height. The stage is a
	# Node2D sibling, so the fixed-design button never participates in VBox sizing.
	_launch_slot = Control.new()
	_launch_slot.name = "LaunchLayoutReserve"
	_launch_slot.custom_minimum_size = Vector2(0.0, 120.0)
	_launch_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launch_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_col.add_child(_launch_slot)
	_launch_stage = Node2D.new()
	_launch_stage.name = "LaunchVisualStage"
	# Parent the transformed button to its reserved layout slot, not the VBox.
	# This keeps the rendering origin attached to the actual metadata flow.
	_launch_slot.add_child(_launch_stage)
	_play_btn = DVD_LAUNCH_BUTTON_SCRIPT.new()
	_play_btn.name = "DvdLaunchButton"
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play_btn.custom_minimum_size = Vector2(504.0, 120.0)
	_play_btn.size = Vector2(504.0, 120.0)
	_play_btn.pressed.connect(_on_play_pressed)
	_launch_stage.add_child(_play_btn)

func _build_playtime_footer() -> void:
	# 游戏时间是面板内容的一部分，随截图和元数据一同滚动。
	# 左栏弹性留白使时间自然落在档案末尾的左下角。
	var footer_space := Control.new()
	footer_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer_space.custom_minimum_size.y = 18.0
	_left_col.add_child(footer_space)
	_playtime_dock = HBoxContainer.new()
	_playtime_dock.name = "PlaytimeFooter"
	_playtime_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playtime_dock.add_theme_constant_override("separation", 6)
	_playtime_dock.alignment = BoxContainer.ALIGNMENT_BEGIN
	_playtime_dock.modulate.a = 0.0 # Never change visibility; avoid HBox relayout jitter.
	var time_glyph: Control = META_GLYPH_SCRIPT.new()
	time_glyph.set("kind", "time")
	time_glyph.custom_minimum_size = Vector2(18.0, 18.0)
	time_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_playtime_dock.add_child(time_glyph)
	_local_time_icon = time_glyph
	_playtime_label.custom_minimum_size = Vector2(105.0, 20.0)
	_playtime_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_playtime_dock.add_child(_playtime_label)
	_psn_time_icon = TextureRect.new()
	_psn_time_icon.name = "PlayStationLogo"
	_psn_time_icon.custom_minimum_size = Vector2(20.0, 16.0)
	_psn_time_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_psn_time_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_psn_time_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_psn_time_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_psn_time_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Do not call ResourceLoader.load() on the raw SVG path: Godot may not have
	# a loader registered for that resource. Rasterize the source bytes directly.
	var ps_svg_path: String = "res://assets/icons/platforms/playstation-logo-colour.svg"
	var ps_svg: PackedByteArray = FileAccess.get_file_as_bytes(ps_svg_path) if FileAccess.file_exists(ps_svg_path) else PackedByteArray()
	if not ps_svg.is_empty():
		var ps_img := Image.new()
		if ps_img.load_svg_from_buffer(ps_svg, 0.25) == OK:
			ps_img.generate_mipmaps()
			_psn_time_icon.texture = ImageTexture.create_from_image(ps_img)
	_playtime_dock.add_child(_psn_time_icon)
	_psn_time_label = Label.new()
	_psn_time_label.add_theme_font_size_override("font_size", 14)
	_psn_time_label.add_theme_color_override("font_color", COLOR_PLAYTIME)
	_psn_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_psn_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playtime_dock.add_child(_psn_time_label)
	_left_col.add_child(_playtime_dock)
	_left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _build_image_overlay() -> void:
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
		var scroll_bar: VScrollBar = (_save_scroll if _save_mode else _panel_scroll).get_v_scroll_bar()
		var max_scroll: float = maxf(0.0, scroll_bar.max_value - scroll_bar.page)
		if _panel_top_ratio > PANEL_TOP_RATIO_MIN + 0.001:
			_panel_top_target = maxf(
				PANEL_TOP_RATIO_MIN,
				_panel_top_target - PANEL_WHEEL_STEP
			)
		elif _save_mode and _save_scroll_target < max_scroll - 0.5:
			_save_scroll_target = minf(_save_scroll_target + PANEL_WHEEL_PIXELS, max_scroll)
		elif not _save_mode and _scroll_target < max_scroll - 0.5:
			_scroll_target = minf(_scroll_target + PANEL_WHEEL_PIXELS, max_scroll)
		get_viewport().set_input_as_handled()
		return

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _save_mode and _save_scroll_target > 0.5:
			_save_scroll_target = maxf(0.0, _save_scroll_target - PANEL_WHEEL_PIXELS)
		elif not _save_mode and _scroll_target > 0.5:
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
	if _save_toggle_btn != null:
		_save_toggle_btn.add_theme_font_size_override("font_size", int(13.0 * s))
	_title_label.add_theme_font_size_override("font_size", int(float(title_base) * s))
	_title_label.custom_minimum_size = Vector2.ZERO
	if _title_wrap != null:
		var title_h: float = maxf(float(title_base) * 1.25, 30.0)
		_title_wrap.custom_minimum_size.y = title_h * s
	_playtime_label.add_theme_font_size_override("font_size", int(float(playtime_base) * s))
	if _psn_time_label != null:
		_psn_time_label.add_theme_font_size_override("font_size", int(float(playtime_base) * s))
	_no_content_label.add_theme_font_size_override("font_size", int(float(meta_base) * s))
	if _meta_mc_label != null:
		_meta_mc_label.add_theme_font_size_override("font_size", int(float(meta_base + 2) * s))
	if _meta_mc_key != null:
		_meta_mc_key.add_theme_font_size_override("font_size", int(float(meta_base) * s))
	for lbl in [_meta_dev_key, _meta_dev_val, _meta_pub_key, _meta_pub_val,
			_meta_date_key, _meta_date_val, _meta_genres_key, _meta_genres_val,
			_meta_tags_key, _meta_tags_val]:
		if lbl != null:
			lbl.add_theme_font_size_override("font_size", int(float(meta_base) * s))
	var key_w: float = META_KEY_W_BASE * s
	var row_h: float = META_ROW_H_BASE * s
	for row in [_row_dev, _row_pub, _row_date, _row_genres, _row_tags]:
		if row != null:
			row.custom_minimum_size.y = maxf(row_h, 33.0 * s)
	for key in [_meta_mc_key, _meta_dev_key, _meta_pub_key, _meta_date_key,
			_meta_genres_key, _meta_tags_key]:
		if key != null:
			key.custom_minimum_size.x = 0.0
	if _play_btn != null:
		_play_btn.custom_minimum_size = Vector2(504.0, 120.0)

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
	if _meta_rows != null:
		# Five metadata entries should occupy three compact rows at 1244x700,
		# not become five oversized full-width cards.
		_meta_rows.columns = 2
	call_deferred("_sync_logo_clearance")
	call_deferred("_sync_launch_media_bottom")

	if _shot_thumbs == null:
		return
	var count: int = _shot_thumbs.get_child_count()
	if count <= 0:
		return
	var avail_w: float = _left_avail_w()
	# The main screenshot can be narrower than the left column because its
	# height is capped and its aspect ratio is preserved. Size the strip from
	# that actual displayed width, not from the entire column width.
	if not _shot_aspects.is_empty():
		_apply_shot_big_size(_shot_index, avail_w)
	var strip_w: float = _shot_big.custom_minimum_size.x if _shot_big != null else avail_w
	if strip_w <= 0.0:
		return
	var gap: int = maxi(0, int(6.0 * s))
	var each_w: float = maxf(1.0, (strip_w - float(count - 1) * float(gap)) / float(count))
	var each_h: float = each_w * 9.0 / 16.0
	_shot_thumbs.add_theme_constant_override("separation", gap)
	for child in _shot_thumbs.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(each_w, each_h)

func _media_intro_logo_spacer() -> float:
	# Use the original logo-clearance formula, not the current spacer height.
	# Reading an already adjusted spacer would make repeated relayouts drift.
	var s: float = _ui_scale
	var usable_w: float = maxf(180.0, _right_col.size.x) * LOGO_END_MAX_RIGHT_RATIO
	var logo_h: float = minf(LOGO_END_H * s, usable_w * LOGO_END_H / LOGO_END_W)
	return logo_h + (LOGO_END_TOP_GAP_BASE + 12.0) * s


func _sync_media_intro_alignment() -> void:
	if _right_col == null or _right_top_spacer == null or _left_media_spacer == null:
		return
	if _right_col.size.x < 100.0 or _left_col.size.x < 100.0:
		return
	# Both columns reserve the same start baseline. Never read back the
	# already-adjusted media spacer as input (avoids layout feedback drift).
	var right_top: float = _media_intro_logo_spacer()
	if absf(_right_top_spacer.custom_minimum_size.y - right_top) > 0.5:
		_right_top_spacer.custom_minimum_size.y = right_top
	var right_sep: float = float(_right_col.get_theme_constant("separation"))
	var left_sep: float = float(_left_col.get_theme_constant("separation"))
	var media_top: float = right_top + right_sep - left_sep
	if absf(_left_media_spacer.custom_minimum_size.y - media_top) > 0.5:
		_left_media_spacer.custom_minimum_size.y = maxf(0.0, media_top)


func _sync_launch_media_bottom() -> void:
	if _launch_stage == null or _launch_slot == null or _media_chassis == null or _right_col == null:
		return
	var available: float = _right_col.size.x
	if available < 100.0 or not is_finite(available):
		return
	# A single fixed-design parent transform scales the complete device.
	# The VBox sees only the explicit screen-space reserve, not the 504px child.
	var compact_blend: float = smoothstep(440.0, 600.0, available)
	var compact_multiplier: float = lerpf(0.90, 1.0, compact_blend)
	var factor: float = minf(1.0, maxf(0.1, available - 8.0) / 504.0) * compact_multiplier
	var scaled_h: float = 120.0 * factor
	# Compare both layout surfaces in the same global canvas coordinate system.
	# The stage itself is parented to the slot and uses only slot-local coordinates.
	var media_bottom: float = _media_chassis.get_global_rect().end.y
	var slot_top: float = _launch_slot.get_global_rect().position.y
	# Reserve space ABOVE the device for its archive access rail. The device's
	# bottom still follows the media display whenever the available gap allows.
	var entry_extra: float = 39.0 * factor if _save_launch_entry.visible else 0.0
	var desired_bottom: float = maxf(media_bottom, slot_top + scaled_h + entry_extra)
	var reserve_height: float = desired_bottom - slot_top
	if absf(_launch_slot.custom_minimum_size.y - reserve_height) > 0.5:
		_launch_slot.custom_minimum_size.y = reserve_height
	# VBox ignores Node2D, so this transform is independent of layout.
	# Place its bottom at the same baseline as the Media Display when possible.
	# Stage is a child of the slot: its coordinates must be slot-local.
	_launch_stage.position = Vector2(0.0, reserve_height - scaled_h)
	_launch_stage.scale = Vector2.ONE * factor
	_launch_scale = factor


func _sync_logo_clearance() -> void:
	# Container widths are only valid after the viewport layout pass.
	if _right_col == null or _right_top_spacer == null:
		return
	var s: float = _ui_scale
	# When opened for the first time, the hidden view may not have a valid
	# right-column width yet. Never replace the reserved logo height with a
	# near-zero spacer based on that transient width.
	if _right_col.size.x < 100.0:
		return
	_sync_media_intro_alignment()
	call_deferred("_sync_launch_media_bottom")
	_refresh_logo_drift()

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
	if path == _shot_big_cached_path and _shot_big_cached_texture != null:
		_shot_big.texture = _shot_big_cached_texture
		_apply_shot_big_size(i)
		return
	var img := Image.new()
	if img.load(path) != OK:
		return
	_shot_big_cached_path = path
	_shot_big_cached_image = img
	_shot_big_cached_texture = ImageTexture.create_from_image(img)
	_shot_big.texture = _shot_big_cached_texture
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
		var max_w: float = limit - 40.0 * s
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
	gold.set_border_width_all(2)
	# Shared detail accent, but keep the selected shot less luminous than
	# the mechanical launch control.
	gold.border_color = Color(0.66, 0.74, 0.77, 0.90)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0.022, 0.033, 0.040, 0.30)
	plain.set_corner_radius_all(3)
	plain.set_border_width_all(1)
	plain.border_color = Color(0.26, 0.33, 0.36, 0.65)
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
	_update_screenshot_sizes()
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
				var f: Font = _font_manager.get_font_for("game_desc", "games")
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
			if player.has_method("play"):
				player.call("play")
			else:
				player.set("playing", true)
			wrap.add_child(player)
	_apply_description_fontset()
	_apply_description_paragraph_spacing()
	_update_desc_line_spacing()

func _update_desc_line_spacing() -> void:
	if _content_container == null:
		return
	var extra_spacing := 0
	if _font_manager != null:
		var settings: Dictionary = _font_manager.get_field_settings("game_desc", "games")
		extra_spacing = clampi(int(settings.get("line_spacing", 0)), 0, 8)
	var spacing: int = int((DESC_LINE_SPACING_BASE + float(extra_spacing)) * _font_scale)
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
	_apply_description_paragraph_spacing()

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
	_screenshots_player.add_theme_constant_override("separation", int(8.0 * s))
	if _right_top_spacer != null:
		# Temporary base reservation until this frame's containers lay out.
		_right_top_spacer.custom_minimum_size.y = _media_intro_logo_spacer()

	_apply_panel_layout()
	if _save_view != null:
		_save_view.set_visual_scale(_ui_scale)
		_save_view.set_compact(_save_scroll.size.x < 850.0)
	# 延后一帧：此刻容器宽度还未布局完成。
	call_deferred("_update_screenshot_sizes")
	call_deferred("_sync_media_intro_alignment")

func _apply_panel_layout() -> void:
	if _panel == null or _bg == null:
		return
	var panel_top_y: float = size.y * _panel_top_ratio
	_bg.position = Vector2.ZERO
	_bg.size = size
	_panel.position = Vector2(0.0, panel_top_y)
	_panel.size = Vector2(size.x, size.y - panel_top_y)
	if _save_toggle_btn != null:
		_save_toggle_btn.position = Vector2(52.0 * _ui_scale, panel_top_y + 4.0 * _ui_scale)
		_save_toggle_btn.custom_minimum_size = Vector2(215.0 * _ui_scale, 30.0 * _font_scale)
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
	# Once the panel reaches the end position, its content continues scrolling.
	# Keep the logo attached to the introduction (same scroll offset), otherwise
	# the text will slide through a fixed logo at minimum window size.
	var logo_scroll: ScrollContainer = _save_scroll if _save_mode else _panel_scroll
	var scroll_offset: float = float(logo_scroll.scroll_vertical) if logo_scroll != null else 0.0
	var end_y: float = _panel.position.y + LOGO_END_TOP_GAP_BASE * s - scroll_offset

	var cur_w: float = lerpf(start_w, end_w, t)
	var cur_h: float = lerpf(start_h, end_h, t)
	var cur_x: float = lerpf(start_x, end_x, t)
	var cur_y: float = lerpf(start_y, end_y, t)

	_logo_rect.position = Vector2(cur_x, cur_y)
	_logo_rect.size = Vector2(cur_w, cur_h)
	# Fade when the whole moving logo passes above the panel viewport.
	# In the initial Hero pose the logo is ABOVE the panel by design.
	# Only fade it when content is actually scrolling past the panel top.
	if t < 0.999:
		_logo_rect.modulate.a = 1.0
	else:
		_logo_rect.modulate.a = clampf((cur_y + cur_h - _panel.position.y) / maxf(1.0, cur_h * 0.4), 0.0, 1.0)

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

func apply_game_theme_palette(palette: Dictionary) -> void:
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent_hex: String = str(colors.get("accent", "")).strip_edges()
	var ambient_hex: String = str(colors.get("ambient", "")).strip_edges()
	var surface_hex: String = str(colors.get("surface", "")).strip_edges()
	var accent: Color = Color.from_string(accent_hex, Color(0.20, 0.34, 0.48)) if not accent_hex.is_empty() else Color(0.20, 0.34, 0.48)
	var ambient: Color = Color.from_string(ambient_hex, Color(0.08, 0.12, 0.17)) if not ambient_hex.is_empty() else Color(0.08, 0.12, 0.17)
	var surface: Color = Color.from_string(surface_hex, PANEL_COLOR) if not surface_hex.is_empty() else PANEL_COLOR
	# Use a darkened accent at the top and the generated ambient/surface near the bottom.
	if _play_btn != null:
		_play_btn.call("apply_game_theme_palette", palette)
	if OS.get_environment("G3_THEME_COLOR_MODE").to_lower() == "legacy":
		_transition_panel_theme(accent.darkened(0.24), ambient.lerp(surface, 0.24), 0.94)
	else:
		# Preserve the approved Hero-driven panel tint (28% Accent).
		_transition_panel_theme(ambient.lerp(accent, 0.28), ambient.lerp(surface, 0.24), 0.94)

func reset_game_theme_palette() -> void:
	if _play_btn != null:
		_play_btn.call("reset_game_theme_palette")
	_transition_panel_theme(Color(0.10, 0.16, 0.24, 1.0), Color(0.08, 0.10, 0.14, 1.0), 0.0)

# The panel gradient shader writes COLOR directly and therefore does not inherit
# the parent Control's modulate alpha. Drive its base alpha explicitly during F.
func set_transition_alpha(alpha: float) -> void:
	if _panel_bg == null or not is_instance_valid(_panel_bg):
		return
	var pg_mat: ShaderMaterial = _panel_bg.material as ShaderMaterial
	if pg_mat == null:
		return
	var panel_color: Color = PANEL_COLOR
	panel_color.a = PANEL_COLOR.a * clampf(alpha, 0.0, 1.0)
	pg_mat.set_shader_parameter("panel_color", panel_color)

func _transition_panel_theme(target_top: Color, target_bottom: Color, target_strength: float) -> void:
	if _panel_theme_tween != null and _panel_theme_tween.is_valid():
		_panel_theme_tween.kill()
	_panel_theme_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_theme_tween.tween_method(
		Callable(self, "_set_panel_theme_state").bind(_panel_theme_top, _panel_theme_bottom, _panel_theme_strength, target_top, target_bottom, target_strength),
		0.0, 1.0, 0.68
	)

func _set_panel_theme_state(progress: float, start_top: Color, start_bottom: Color, start_strength: float, target_top: Color, target_bottom: Color, target_strength: float) -> void:
	_panel_theme_top = start_top.lerp(target_top, progress)
	_panel_theme_bottom = start_bottom.lerp(target_bottom, progress)
	_panel_theme_strength = lerpf(start_strength, target_strength, progress)
	if _panel_bg == null or not is_instance_valid(_panel_bg):
		return
	var pg_mat: ShaderMaterial = _panel_bg.material as ShaderMaterial
	if pg_mat != null:
		pg_mat.set_shader_parameter("theme_top_color", _panel_theme_top)
		pg_mat.set_shader_parameter("theme_bottom_color", _panel_theme_bottom)
		pg_mat.set_shader_parameter("theme_strength", _panel_theme_strength)

func show_game(game: Dictionary) -> void:
	if _play_btn != null:
		_play_btn.call("reset_disc")
		_play_btn.disabled = false
	_current_game = game
	_reset_save_stage(game)
	_current_media_key = _game_media_key(game)
	_title_label.text = str(game.get("title", ""))

	# A sidebar selection may have waited for this exact Hero to be decoded.
	# Preserve that prepared texture so the first visible detail frame already
	# contains its backdrop; otherwise clear the previous game's Hero.
	if _prepared_hero_key == _current_media_key:
		_hero_rect.texture = _prepared_hero_texture
		_hero_rect.visible = _prepared_hero_texture != null
	else:
		_hero_rect.texture = null
		_hero_rect.visible = false
	_logo_rect.texture = null
	_logo_rect.visible = false

	# MC 评分
	var mc_score: int = int(game.get("metacritic", 0))
	if mc_score > 0:
		_meta_mc_label.text = "%d / 100" % mc_score
		_set_card_visible(_row_metacritic, true)
	else:
		_set_card_visible(_row_metacritic, false)

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
	_set_card_visible(_row_dev, not dev.is_empty())
	_meta_pub_val.text = pub
	_set_card_visible(_row_pub, not pub.is_empty())
	_meta_date_val.text = release_date
	_set_card_visible(_row_date, not release_date.is_empty())
	_meta_genres_val.text = genres
	_set_card_visible(_row_genres, not genres.is_empty())
	_meta_tags_val.text = tags
	_row_tags.visible = false # 元数据保留，仅从详情页隐藏重复标签

	# Game time: clock + local time; PlayStation logo + PSN time share one row.
	var secs: int = int(game.get("playtime_seconds", 0))
	var psn_secs: int = int(game.get("psn_playtime_seconds", 0))
	
	
	
		
	_playtime_label.text = _fmt_playtime(secs) if secs > 0 else ("" if psn_secs > 0 else "未游玩")
	_playtime_label.visible = not _playtime_label.text.is_empty()
	_local_time_icon.visible = secs > 0 or psn_secs <= 0
	_psn_time_icon.visible = psn_secs > 0
	_psn_time_label.visible = psn_secs > 0
	_psn_time_label.text = _fmt_playtime(psn_secs) if psn_secs > 0 else ""
	_playtime_label.update_minimum_size()
	_playtime_dock.modulate.a = 0.0

	# Clear the previous game's media and keep the screenshot slot reserved.
	# The replacement media set is decoded off-thread and committed in one frame.
	for c in _shot_thumbs.get_children():
		_shot_thumbs.remove_child(c)
		c.free()
	_screenshot_paths.clear()
	_shot_aspects.clear()
	_shot_index = 0
	_shot_big_cached_path = ""
	_shot_big_cached_image = null
	_shot_big_cached_texture = null
	_shot_big.texture = null
	_shot_big.visible = false
	_shot_thumbs.visible = false
	_shot_empty.visible = false
	_screenshots_player.visible = true
	var screenshots: Array = game.get("screenshots", [])
	var s_count: int = screenshots.size()
	# Reserve the screenshot slot during the fade so late media never reflows the
	# page after the transition. The actual controls are committed as one batch.
	_screenshots_player.custom_minimum_size.y = (SHOT_BIG_H + 60.0) * _ui_scale if s_count > 0 else 0.0
	if s_count == 0:
		_shot_empty.visible = true
		_shot_big.get_parent().custom_minimum_size = Vector2(420.0, 236.0)
		_shot_thumbs.get_parent().visible = false
	else:
		_shot_big.get_parent().custom_minimum_size = Vector2.ZERO
		_shot_thumbs.get_parent().visible = true

	# 简介：纯文字（不再用图文混合）
	var desc: String = str(game.get("description", "")).strip_edges()
	var desc_blocks: Array = []
	if not desc.is_empty():
		desc_blocks.append({"type": "text", "content": desc})
	# Defer RichTextLabel creation to the idle frame; the detail root is already
	# at alpha zero before drawing, so the whole text block participates in F.
	call_deferred("_rebuild_content_blocks", desc_blocks)

	# 无内容提示
	var has_content: bool = (not desc.is_empty()) or (s_count > 0)
	has_content = has_content or (not dev.is_empty()) or (not pub.is_empty())
	has_content = has_content or (not release_date.is_empty())
	has_content = has_content or (not genres.is_empty()) or mc_score > 0
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
	# Width-dependent spacers need a second pass after the view is shown.
	_layout_settle_frames = 3
	var pending_matches: bool = (
		not _pending_media_result.is_empty()
		and int(_pending_media_result.get("token", -1)) == _media_token
		and str(_pending_media_result.get("key", "")) == _current_media_key
	)
	if pending_matches:
		# Let the first F animation frame render before committing already-decoded
		# textures; they will inherit the page's current fade alpha.
		_media_apply_delay_frames = 1
	elif _media_request_key != _current_media_key:
		_start_game_media_load(game)

func _game_media_key(game: Dictionary) -> String:
	var parts := PackedStringArray()
	parts.append(str(game.get("id", "")))
	parts.append(str(game.get("logo", "")))
	var backdrop: Array = game.get("backdrop", [])
	for path in backdrop:
		parts.append(str(path))
	var screenshots: Array = game.get("screenshots", [])
	for path in screenshots:
		parts.append(str(path))
	return "|".join(parts)

# Grid clicks preload during their 360ms material feedback. Sidebar navigation
# opts into Hero-first mode and waits for the Hero texture before entering detail.
func prepare_game_media(game: Dictionary, hero_first: bool = false) -> String:
	var key: String = _game_media_key(game)
	if key == _prepared_hero_key:
		return key
	if key == _media_request_key:
		# A sidebar request can upgrade an in-flight grid preload to Hero-first
		# without changing the normal grid path's all-media batch behavior.
		if hero_first and not _media_hero_first:
			_start_game_media_load(game, true)
		return key
	_start_game_media_load(game, hero_first)
	return key

func is_game_hero_prepared(media_key: String) -> bool:
	return not media_key.is_empty() and _prepared_hero_key == media_key

func _start_game_media_load(game: Dictionary, hero_first: bool = false) -> void:
	var key: String = _game_media_key(game)
	_media_token += 1
	var token: int = _media_token
	_media_request_key = key
	_media_hero_first = hero_first
	if _prepared_hero_key != key:
		_prepared_hero_key = ""
		_prepared_hero_texture = null
	_pending_media_result.clear()
	_media_apply_delay_frames = 0
	_media_texture_build_active = false
	_media_texture_queue.clear()
	_media_texture_result = {}
	_media_texture_token = -1
	_media_texture_key = ""
	var backdrop_paths: Array = game.get("backdrop", [])
	var screenshot_paths: Array = game.get("screenshots", [])
	var request: Dictionary = {
		"backdrop": backdrop_paths.duplicate(),
		"logo": str(game.get("logo", "")),
		"screenshots": screenshot_paths.duplicate()
	}
	var thread := Thread.new()
	var err: Error = thread.start(Callable(self, "_load_game_media_worker").bind(request, token, key, hero_first))
	if err != OK:
		push_warning("Unable to start background game media loading; keeping media hidden.")
		if hero_first:
			_prepared_hero_key = key
			_prepared_hero_texture = null
			game_hero_ready.emit(key, false)
		_media_hero_first = false
		_pending_media_result = {
			"token": token,
			"key": key,
			"result": {
				"hero_texture": null, "logo_texture": null,
				"shots": [], "first_big_texture": null, "first_big_image": null
			}
		}
		return
	_media_jobs.append({"thread": thread, "token": token, "key": key})

# Worker thread: file reads and Image decoding only. It never touches scene nodes
# or creates GPU textures; all visual changes are committed on the main thread.
func _load_game_media_worker(request: Dictionary, token: int, key: String, hero_first: bool) -> Dictionary:
	var hero_image: Image = null
	var backdrop: Array = request.get("backdrop", [])
	if not backdrop.is_empty():
		var hero_path: String = str(backdrop[0]).replace("\\", "/")
		if not hero_path.is_empty() and FileAccess.file_exists(hero_path):
			var hero_candidate := Image.new()
			if hero_candidate.load(hero_path) == OK:
				hero_image = hero_candidate
	# Sidebar navigation opts into Hero-first preparation. The regular grid
	# path keeps its original all-media batch commit behavior.
	if hero_first:
		call_deferred("_on_game_hero_image_decoded", hero_image, token, key)
		hero_image = null

	var logo_image: Image = null
	var logo_path: String = str(request.get("logo", "")).replace("\\", "/")
	if not logo_path.is_empty() and FileAccess.file_exists(logo_path):
		var logo_candidate := Image.new()
		if logo_candidate.load(logo_path) == OK:
			logo_candidate.generate_mipmaps()
			logo_image = logo_candidate

	var shots_out: Array[Dictionary] = []
	var first_big_image: Image = null
	var screenshots: Array = request.get("screenshots", [])
	var limit: int = mini(screenshots.size(), 8)
	for i in range(limit):
		var path: String = str(screenshots[i]).replace("\\", "/")
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var img := Image.new()
		if img.load(path) != OK:
			continue
		var iw: int = img.get_width()
		var ih: int = img.get_height()
		var aspect: float = float(iw) / float(ih) if iw > 0 and ih > 0 else 16.0 / 9.0
		if first_big_image == null:
			first_big_image = img.duplicate() as Image
		var thumb_img: Image = img.duplicate() as Image
		if thumb_img != null:
			var tw: int = thumb_img.get_width()
			var th: int = thumb_img.get_height()
			if tw > 160:
				var nh: int = int(float(th) * 160.0 / float(tw))
				thumb_img.resize(160, maxi(nh, 1), Image.INTERPOLATE_BILINEAR)
		shots_out.append({"path": path, "aspect": aspect, "thumb_image": thumb_img})
	return {
		"hero_image": hero_image,
		"logo_image": logo_image,
		"shots": shots_out,
		"first_big_image": first_big_image
	}

func _on_game_hero_image_decoded(hero_image: Image, token: int, key: String) -> void:
	if token != _media_token or key != _media_request_key:
		return
	var hero_texture: Texture2D = ImageTexture.create_from_image(hero_image) if hero_image != null else null
	_prepared_hero_key = key
	_prepared_hero_texture = hero_texture
	if _current_media_key == key and is_instance_valid(_hero_rect):
		_hero_rect.texture = hero_texture
		_hero_rect.visible = hero_texture != null
	game_hero_ready.emit(key, hero_texture != null)

func _poll_game_media_jobs() -> void:
	for i in range(_media_jobs.size() - 1, -1, -1):
		var job: Dictionary = _media_jobs[i]
		var thread: Thread = job.get("thread") as Thread
		if thread == null:
			_media_jobs.remove_at(i)
			continue
		if thread.is_alive():
			continue
		var result: Variant = thread.wait_to_finish()
		_media_jobs.remove_at(i)
		var token: int = int(job.get("token", -1))
		var key: String = str(job.get("key", ""))
		if token != _media_token or key != _media_request_key or not (result is Dictionary):
			continue
		_begin_media_texture_build(result as Dictionary, token, key)

func _begin_media_texture_build(result: Dictionary, token: int, key: String) -> void:
	_media_texture_queue.clear()
	_media_texture_result = result
	_media_texture_token = token
	_media_texture_key = key
	_media_texture_build_active = true
	var hero_image: Image = result.get("hero_image") as Image
	if hero_image != null:
		_media_texture_queue.append({"slot": "hero", "image": hero_image})
	var logo_image: Image = result.get("logo_image") as Image
	if logo_image != null:
		_media_texture_queue.append({"slot": "logo", "image": logo_image})
	var first_big_image: Image = result.get("first_big_image") as Image
	if first_big_image != null:
		_media_texture_queue.append({"slot": "first_big", "image": first_big_image})
	var shots: Array = result.get("shots", [])
	for i in range(shots.size()):
		var entry_value: Variant = shots[i]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var thumb_image: Image = entry.get("thumb_image") as Image
		if thumb_image != null:
			_media_texture_queue.append({"slot": "thumb", "index": i, "image": thumb_image})
	if _media_texture_queue.is_empty():
		_finish_media_texture_build()

func _process_media_texture_build() -> void:
	if not _media_texture_build_active:
		return
	if _media_texture_token != _media_token or _media_texture_key != _media_request_key:
		_media_texture_build_active = false
		_media_texture_queue.clear()
		_media_texture_result = {}
		return
	var build_count: int = mini(MEDIA_TEXTURES_PER_FRAME, _media_texture_queue.size())
	for _i in range(build_count):
		if _media_texture_queue.is_empty():
			break
		var job: Dictionary = _media_texture_queue.pop_front()
		var image: Image = job.get("image") as Image
		if image == null:
			continue
		var texture: Texture2D = ImageTexture.create_from_image(image)
		match str(job.get("slot", "")):
			"hero":
				_media_texture_result["hero_texture"] = texture
				_media_texture_result["hero_image"] = null
			"logo":
				_media_texture_result["logo_texture"] = texture
				_media_texture_result["logo_image"] = null
			"first_big":
				_media_texture_result["first_big_texture"] = texture
			"thumb":
				var shots: Array = _media_texture_result.get("shots", [])
				var index: int = int(job.get("index", -1))
				if index >= 0 and index < shots.size() and shots[index] is Dictionary:
					var entry: Dictionary = shots[index]
					entry["thumb_texture"] = texture
					entry["thumb_image"] = null
					shots[index] = entry
					_media_texture_result["shots"] = shots
	if _media_texture_queue.is_empty():
		_finish_media_texture_build()

func _finish_media_texture_build() -> void:
	var token: int = _media_texture_token
	var key: String = _media_texture_key
	var result: Dictionary = _media_texture_result
	_media_texture_build_active = false
	_media_texture_queue.clear()
	_media_texture_result = {}
	_media_texture_token = -1
	_media_texture_key = ""
	_media_hero_first = false
	if token != _media_token or key != _media_request_key:
		return
	_pending_media_result = {"token": token, "key": key, "result": result}
	if visible and key == _current_media_key:
		# Let the page fade run for another frame before the batch becomes visible.
		_media_apply_delay_frames = 1

func _apply_pending_media_for_current_game() -> void:
	if _pending_media_result.is_empty():
		return
	if int(_pending_media_result.get("token", -1)) != _media_token:
		_pending_media_result.clear()
		return
	if str(_pending_media_result.get("key", "")) != _current_media_key:
		return
	var result: Variant = _pending_media_result.get("result", {})
	_pending_media_result.clear()
	_media_apply_delay_frames = 0
	if result is Dictionary:
		_apply_game_media_result(result as Dictionary)

func _apply_game_media_result(result: Dictionary) -> void:
	if not is_inside_tree() or _current_media_key.is_empty():
		return
	# Logo and screenshot textures are committed together in small per-frame
	# batches. Sidebar Hero-first mode may already have committed the Hero above.
	var hero_texture: Texture2D = result.get("hero_texture") as Texture2D
	if hero_texture != null:
		_prepared_hero_key = _current_media_key
		_prepared_hero_texture = hero_texture
		_hero_rect.texture = hero_texture
		_hero_rect.visible = true
	elif _prepared_hero_key != _current_media_key:
		_hero_rect.texture = null
		_hero_rect.visible = false

	var logo_texture: Texture2D = result.get("logo_texture") as Texture2D
	_logo_rect.texture = logo_texture
	_logo_rect.visible = logo_texture != null

	for child in _shot_thumbs.get_children():
		_shot_thumbs.remove_child(child)
		child.free()
	_screenshot_paths.clear()
	_shot_aspects.clear()
	_shot_index = 0
	_shot_big_cached_path = ""
	_shot_big_cached_image = null
	_shot_big_cached_texture = null
	_shot_big.texture = null

	var shot_entries: Array = result.get("shots", [])
	for entry_value in shot_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var path: String = str(entry.get("path", ""))
		var thumb_texture: Texture2D = entry.get("thumb_texture") as Texture2D
		if path.is_empty() or thumb_texture == null:
			continue
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.clip_contents = true
		var tr := TextureRect.new()
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = thumb_texture
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tr)
		btn.set_meta("screenshot_path", path)
		btn.pressed.connect(_on_thumb_pressed.bind(_screenshot_paths.size()))
		_shot_thumbs.add_child(btn)
		_screenshot_paths.append(path)
		_shot_aspects.append(float(entry.get("aspect", 16.0 / 9.0)))

	var first_big_texture: Texture2D = result.get("first_big_texture") as Texture2D
	var first_big_image: Image = result.get("first_big_image") as Image
	if not _screenshot_paths.is_empty() and first_big_texture != null:
		_shot_big_cached_path = _screenshot_paths[0]
		_shot_big_cached_image = first_big_image
		_shot_big_cached_texture = first_big_texture
		_shot_big.texture = first_big_texture
	var has_shots: bool = not _screenshot_paths.is_empty()
	_shot_big.visible = has_shots
	_shot_thumbs.visible = has_shots
	_shot_empty.visible = not has_shots
	_shot_big.get_parent().custom_minimum_size = Vector2.ZERO if has_shots else Vector2(420.0, 236.0)
	_shot_thumbs.get_parent().visible = has_shots
	_screenshots_player.custom_minimum_size.y = 0.0
	_screenshots_player.visible = true
	if has_shots:
		_apply_shot_big_size(0)
		_update_thumb_selection()
	_update_screenshot_sizes()
	_sync_logo_clearance()
	_media_apply_delay_frames = 0
	# Empty means no worker is outstanding for this key. A later request to open
	# the same game again will reload if show_game has cleared its visual state.
	_media_request_key = ""

func cancel_pending_game_media() -> void:
	_media_token += 1
	_media_request_key = ""
	_pending_media_result.clear()
	_media_apply_delay_frames = 0
	_media_texture_build_active = false
	_media_texture_queue.clear()
	_media_texture_result = {}
	_media_texture_token = -1
	_media_texture_key = ""
	_media_hero_first = false

func _exit_tree() -> void:
	# Always join workers before this node is destroyed; workers never touch UI nodes.
	for job in _media_jobs:
		var thread: Thread = job.get("thread") as Thread
		if thread != null and thread.is_started():
			thread.wait_to_finish()
	_media_jobs.clear()

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
	_poll_game_media_jobs()
	_process_media_texture_build()
	if not visible:
		return
	if not _pending_media_result.is_empty():
		if _media_apply_delay_frames > 0:
			_media_apply_delay_frames -= 1
		else:
			_apply_pending_media_for_current_game()
	if _layout_settle_frames > 0:
		_layout_settle_frames -= 1
		if _layout_settle_frames == 1:
			_update_screenshot_sizes()
		elif _layout_settle_frames == 0:
			_sync_logo_clearance()
	# Media dimensions and column geometry can settle after asynchronous loads.
	# The guard inside this method avoids writes once both bottoms align.
	if not _save_mode:
		_sync_launch_media_bottom()
	var follow: float = 1.0 - exp(-delta * PANEL_SCROLL_SPEED)
	var prev: float = _panel_top_ratio
	_panel_top_ratio = lerpf(_panel_top_ratio, _panel_top_target, follow)
	if absf(_panel_top_ratio - prev) > 0.0005:
		_apply_panel_layout()
	# Each stage keeps its own scroll position; the original detail stage is never rebuilt.
	var active_scroll: ScrollContainer = _save_scroll if _save_mode else _panel_scroll
	if active_scroll != null:
		var cur: int = active_scroll.scroll_vertical
		var target: int = int(_save_scroll_target if _save_mode else _scroll_target)
		if cur != target:
			var diff: float = float(target - cur)
			if absf(diff) < 1.0:
				active_scroll.scroll_vertical = target
			else:
				var step: float = diff * follow * 1.6
				if absf(step) < 1.0:
					step = sign(diff)
				active_scroll.scroll_vertical = cur + int(round(step))
		# Stable geometry: footer opacity changes without hiding/reshaping its row.
		if not _save_mode and _playtime_dock != null:
			var sb: VScrollBar = _panel_scroll.get_v_scroll_bar()
			var max_scroll: float = maxf(0.0, sb.max_value - sb.page)
			var risen: bool = _panel_top_ratio <= PANEL_TOP_RATIO_MIN + 0.001 and _panel_top_target <= PANEL_TOP_RATIO_MIN + 0.001
			# Fade linearly over the final stretch of actual scroll distance.
			# Keep the footer in the layout to avoid moving nearby controls.
			var fade_distance: float = maxf(1.0, 150.0 * _ui_scale)
			var scroll_progress: float = clampf((float(_panel_scroll.scroll_vertical) - (max_scroll - fade_distance)) / fade_distance, 0.0, 1.0)
			# Some window sizes fit all content after the panel rises (max_scroll == 0).
			# In that case fade with the panel movement rather than hiding forever.
			var panel_progress: float = clampf((PANEL_TOP_RATIO_INIT - _panel_top_ratio) / maxf(0.0001, PANEL_TOP_RATIO_INIT - PANEL_TOP_RATIO_MIN), 0.0, 1.0)
			var fade_start: float = 0.78
			var panel_fade: float = clampf((panel_progress - fade_start) / (1.0 - fade_start), 0.0, 1.0)
			_playtime_dock.modulate.a = (scroll_progress * panel_fade) if max_scroll > 1.0 else panel_fade
		# Scrolled content and the logo must update in the same frame.
		_refresh_logo_drift()

func show_launch_failure() -> void:
	if _play_btn != null and _play_btn.has_method("show_launch_failure"):
		_play_btn.call("show_launch_failure")

func set_launching(launching: bool) -> void:
	if _play_btn == null:
		return
	_play_btn.disabled = launching
	if not launching:
		_play_btn.call("animate_eject")

func _on_play_pressed() -> void:
	var item_id: String = str(_current_game.get("id", ""))
	if item_id.is_empty():
		return
	set_launching(true)
	UISfx.play(&"game_launch")
	# 完整播放 DVD 载入动画，再交给已有的后端启动流程。
	var insertion: Tween = _play_btn.call("animate_insert") as Tween
	if insertion != null:
		await insertion.finished
	if not is_inside_tree() or not visible:
		return
	if str(_current_game.get("id", "")) != item_id:
		return
	play_requested.emit(item_id)
