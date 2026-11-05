extends Node3D
class_name G3GameSection

signal selection_changed(index: int, game: Dictionary)
signal game_double_clicked(game: Dictionary)
signal add_game_requested()
signal game_context_requested(game: Dictionary, position: Vector2)
signal blank_context_requested(position: Vector2)
signal game_removed(item_id: String)
signal batch_scrape_requested(item_ids: Array)
signal game_theme_requested(item_id: String)
signal game_theme_cleared

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
# 宽度：5 个按钮 × 44 + 4 个间距 × 10 + 左右 padding 16×2 = 292
# 光晕线：TOP_OFFSET 34 + GLOW_Y_OFFSET 3 = 37；抽屉底边：34 + 10 + 64 = 108。
# 影响边界比抽屉本体略宽：上下保留更充足的安全区，左侧增加有限的卡片感应范围。
const NAV_DRAWER_W: float = 292.0
const NAV_DRAWER_GLOW_Y: float = 37.0
const NAV_DRAWER_TOP_CLEARANCE: float = 18.0
const NAV_DRAWER_BOTTOM: float = 108.0
const NAV_DRAWER_GAP: float = 24.0
const NAV_DRAWER_LEFT_INFLUENCE: float = 48.0
const NAV_DRAWER_LEFT_OVERLAP_ALLOWANCE: float = 48.0
# 抽屉完全展开后，左侧卡片再横向让位；距离按卡片与抽屉的实际间隔计算。
const NAV_CARD_PUSH_MIN_DISTANCE: float = 30.0
const NAV_CARD_PUSH_CLEARANCE: float = 12.0
const NAV_CARD_PUSH_MAX_DISTANCE: float = 80.0
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

# Hover Lab V2 · H: stationary focus. CSS box-shadow/filter 230ms ease.
# CSS idle: 0 5px 13px rgba(0,0,0,.30); hover: 0 8px 20px rgba(0,0,0,.45),
# 0 0 0 1px #9ccbd447; filter: brightness(1.055).
const HOVER_H_DURATION: float = 0.230
const HOVER_H_IDLE_SHADOW_SIZE: float = 13.0
const HOVER_H_ACTIVE_SHADOW_SIZE: float = 20.0
const HOVER_H_IDLE_SHADOW_OFFSET: float = 5.0
const HOVER_H_ACTIVE_SHADOW_OFFSET: float = 8.0
const HOVER_H_IDLE_SHADOW_ALPHA: float = 0.30
const HOVER_H_ACTIVE_SHADOW_ALPHA: float = 0.45
# Softer semi-transparent edge aligned to the poster rectangle.
const HOVER_H_ACTIVE_BORDER: Color = Color8(156, 203, 212, 92)
const HOVER_H_BORDER_WIDTH: int = 1
# Lab V2 G: transform 250ms cubic-bezier(.25,.8,.25,1), scale(1.028).
const HOVER_G_DURATION: float = 0.250
const HOVER_G_SCALE: float = 1.028
const HOVER_H_BRIGHTNESS: float = 1.055

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
const CARD_COVER_SHADER: Shader = preload("res://shaders/game_card_flip.gdshader")
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
var _sidebar_detail_highlight: bool = false
var _batch_scrape_btn: Button
var _search_text: String = ""
var _sort_mode: String = "name"

var _ui_layer: CanvasLayer
var _root: Control
var _bg: ColorRect

# 侧边栏
var _sidebar_root: Control
var _sidebar_bg: ColorRect = null
var _sidebar_theme_overlay: ColorRect = null
var _sidebar_theme_material: ShaderMaterial = null
var _sidebar_gradient_tween: Tween = null
var _sidebar_top_divider: ColorRect = null
var _sidebar_divider_theme_tween: Tween = null
var _sidebar_footer_bg: ColorRect = null
var _sidebar_footer_theme_tween: Tween = null
var _add_glow_theme_tween: Tween = null
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
var _cover_geometry_diag_pending: bool = false
var _cover_geometry_diag_last: String = ""
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
# Detail F motion lab: independent of the 0.68s Hero theme color tween.
const DETAIL_F_DURATION: float = 0.50
const DETAIL_F_START_SCALE: float = 0.97
var _detail_f_tween: Tween = null
var _detail_f_exiting: bool = false
var _detail_f_exit_start_alpha: float = 1.0
var _animated_cache: Dictionary = {}
var _animated_probe_cache: Dictionary = {}
# 静态纹理缓存：避免重建卡片时图片消失导致闪烁
static var _cover_texture_cache: Dictionary = {}
# Bound image work so the first cards are not competing with every later card at once.
const MAX_CONCURRENT_COVER_LOADS: int = 2
# Keep GPU texture creation from bunching several completed worker tasks into one frame.
const MAX_COVER_TEXTURE_APPLIES_PER_FRAME: int = 1
# Game covers are displayed small; cap decoded images before GPU upload to reduce upload stalls.
const MAX_COVER_TEXTURE_EDGE: int = 768
var _cover_load_queue: Array[Dictionary] = []
var _cover_apply_queue: Array[Dictionary] = []
var _active_cover_loads: int = 0
var _cover_queue_batching: bool = false
# Separate the first visible reveal from its texture upload by one frame.
var _cover_first_reveal_frame_separated: bool = false
var _cover_reveal_deferred_to_process: bool = false
# Continue scheduling visible card reveals gradually, with at most one new tween per frame.
var _cover_reveal_schedule_pending: bool = false
var _cover_reveal_last_schedule_frame: int = -1
# Stagger visible poster reveals without delaying images that are not ready yet.
var _cover_reveal_next_usec: int = 0
# Temporary animation-flow audit counters. Logging only; no scheduling/visual behavior changes.
var _anim_audit_active_reveals: int = 0
# Keep navigation/layout springs out of the initial cover-load and reveal phase.
var _card_springs_enabled: bool = false
var _cover_reveals_pending: int = 0
var _card_springs_gate_started_usec: int = 0
# Temporary performance diagnostics for the current grid rebuild.
var _perf_grid_generation: int = 0
var _perf_grid_started_msec: int = 0
var _perf_grid_cache_hits: int = 0
var _perf_grid_async_queued: int = 0
var _perf_grid_async_pending: int = 0
var _perf_grid_first_cover_logged: bool = false
var _perf_cover_queue_wait_total_ms: float = 0.0
var _perf_cover_queue_wait_max_ms: float = 0.0
var _perf_cover_file_read_total_ms: float = 0.0
var _perf_cover_file_read_max_ms: float = 0.0
var _perf_cover_decode_total_ms: float = 0.0
var _perf_cover_decode_max_ms: float = 0.0
var _perf_cover_apply_total_ms: float = 0.0
var _perf_cover_apply_max_ms: float = 0.0
var _perf_cover_apply_queue_wait_total_ms: float = 0.0
var _perf_cover_apply_queue_wait_max_ms: float = 0.0
var _perf_cover_image_decode_total_ms: float = 0.0
var _perf_cover_image_decode_max_ms: float = 0.0
var _perf_cover_resize_total_ms: float = 0.0
var _perf_cover_resize_max_ms: float = 0.0
var _perf_cover_mipmap_total_ms: float = 0.0
var _perf_cover_mipmap_max_ms: float = 0.0
var _perf_cover_texture_create_total_ms: float = 0.0
var _perf_cover_texture_create_max_ms: float = 0.0
var _perf_cover_texture_assign_total_ms: float = 0.0
var _perf_cover_texture_assign_max_ms: float = 0.0
var _perf_cover_animated_check_total_ms: float = 0.0
var _perf_cover_animated_check_max_ms: float = 0.0
var _perf_cover_reveal_request_total_ms: float = 0.0
var _perf_cover_reveal_request_max_ms: float = 0.0
var _perf_cover_plugin_load_elapsed_total_ms: float = 0.0
var _perf_cover_plugin_load_elapsed_max_ms: float = 0.0
var _perf_cover_source_pixels_total: int = 0
var _perf_cover_output_pixels_total: int = 0
var _perf_cover_resized_count: int = 0
var _perf_cover_decoded_image_samples: int = 0
var _perf_cover_apply_queue_peak: int = 0
var _perf_cover_stage_detail_logs: int = 0
var _perf_cover_samples: int = 0
var _perf_cover_peak_active: int = 0
# 下一次 _rebuild_grid 是否要弹入（只由排序 / 搜索变化设置）
var _rebuild_should_pop: bool = false
# 首次 _rebuild_grid 已完成。后续增删改刷新不重播封面入场。
var _first_grid_build_done: bool = false

# UI 是否已完成初次布局。就绪之前的所有 viewport 变化都不弹，
# 就绪之后的每一次（用户拖窗口 / 切全屏 / 切窗口）都弹。
var _ui_ready: bool = false
# 导航抽屉是否打开。打开时被它覆盖的卡片下推让位，收回时弹回。
var _nav_opened: bool = false
# 抽屉完全展开后才启用左侧卡片横向让位，确保与上下让位分阶段发生。
var _nav_drawer_revealed: bool = false

# 本次 _relayout 是否要动画（由调用方决定，用完自动重置）
var _animate_layout: bool = false

# 海报墙滚动惯性物理
var _scroll_velocity: float = 0.0
var _scroll_friction: float = 7.0     # 摩擦力（越小滑得越远）
var _scroll_wheel_power: float = 500.0 # 滚轮推力（越大滚得越快）
# 导航抽屉打开时，跟踪滚动偏移；只在偏移变化时刷新卡片目标，不重建布局。
var _last_nav_push_scroll: int = -1
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
	_nav_drawer_revealed = false
	# 第一阶段只更新上下让位目标。抽屉尚未展开时，左侧卡片不横移。
	_animate_layout = true
	_relayout()
	_last_nav_push_scroll = _grid_scroll.scroll_vertical if opened and _grid_scroll != null else -1


func set_nav_drawer_revealed() -> void:
	# 由导航抽屉在展开动画结束后调用，左侧卡片从此刻起才横向让位。
	if not _nav_opened or _nav_drawer_revealed:
		return
	_nav_drawer_revealed = true
	_refresh_nav_push_targets()

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
	_refresh_sidebar_styles()

func _apply_font_to_label(label: Label, key: String) -> void:
	if label == null or _font_manager == null:
		return
	var f: Font = _font_manager.get_font_for(key, "games")
	if f != null:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")
	_font_manager.apply_style_to_control(label, key, "games")

func _font_size(key: String, fallback: int) -> int:
	if _font_manager == null:
		return fallback
	return _font_manager.get_size_for(key, fallback, "games")

func _on_viewport_changed() -> void:
	_compute_scale()
	# 就绪后的任何 viewport 变化都带动画（含全屏 ↔ 窗口切换）
	_animate_layout = _ui_ready
	_relayout()
	_queue_cover_geometry_diag("viewport_changed")

# Read-only cover geometry diagnostic. No layout or texture mutations.
func _queue_cover_geometry_diag(reason: String) -> void:
	if _cover_geometry_diag_pending:
		return
	_cover_geometry_diag_pending = true
	_cover_geometry_diag_after_frame.call_deferred(reason)

func _cover_geometry_diag_after_frame(reason: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_cover_geometry_diag_pending = false
	if _cell_buttons.is_empty():
		return
	var btn: Button = _cell_buttons[0]
	if not is_instance_valid(btn):
		return
	var wrapper: Control = btn.get_meta("wrapper", null)
	var cover_wrap: Control = btn.get_meta("cover_wrap", null)
	var cover_rect: TextureRect = btn.get_meta("cover_rect", null)
	if not is_instance_valid(wrapper) or not is_instance_valid(cover_wrap) or not is_instance_valid(cover_rect):
		return
	var texture_size: Vector2 = cover_rect.texture.get_size() if cover_rect.texture != null else Vector2.ZERO
	var mode: int = DisplayServer.window_get_mode()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var signature: String = "%s|%s|%s|%s|%s|%s|%s" % [mode, vp, wrapper.size, btn.size, cover_wrap.size, cover_rect.size, texture_size]
	if signature == _cover_geometry_diag_last:
		return
	_cover_geometry_diag_last = signature
	var wrap_rect: Rect2 = cover_wrap.get_global_rect()
	var img_rect: Rect2 = cover_rect.get_global_rect()
	var ratio: float = cover_wrap.size.x / cover_wrap.size.y if cover_wrap.size.y > 0.0 else 0.0
	var source_ratio: float = texture_size.x / texture_size.y if texture_size.y > 0.0 else 0.0
	print("[G3 COVER DIAG] reason=", reason, " mode=", mode, " viewport=", vp, " ui_scale=", _ui_scale)
	print("[G3 COVER DIAG] wrapper=", wrapper.size, " button=", btn.size, " cover_wrap=", cover_wrap.size, " cover_rect=", cover_rect.size)
	print("[G3 COVER DIAG] wrap_global=", wrap_rect, " image_global=", img_rect, " texture=", texture_size, " area_ratio=", ratio, " source_ratio=", source_ratio)
	print("[G3 COVER DIAG] clip=", cover_wrap.clip_contents, " stretch_mode=", cover_rect.stretch_mode, " btn_scale=", btn.scale, " wrapper_scale=", wrapper.scale)
	print("[G3 COVER DIAG] btn_anchors=", Vector4(btn.anchor_left, btn.anchor_top, btn.anchor_right, btn.anchor_bottom), " offsets=", Vector4(btn.offset_left, btn.offset_top, btn.offset_right, btn.offset_bottom), " min=", btn.get_minimum_size(), " combined_min=", btn.get_combined_minimum_size(), " wrapper_min=", wrapper.get_combined_minimum_size())

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
	if _cover_reveal_deferred_to_process:
		_cover_reveal_deferred_to_process = false
		_reveal_visible_loaded_covers()
	else:
		_drain_cover_apply_queue()
		if _cover_reveal_schedule_pending:
			_reveal_visible_loaded_covers()
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

	# 抽屉打开期间，滚动会改变当前受遮挡的行。只更新目标位置，
	# 不重跑完整 _relayout，也不重置弹簧速度，保证位移连续。
	if _nav_opened and _grid_scroll != null and is_instance_valid(_grid_scroll):
		var nav_scroll: int = _grid_scroll.scroll_vertical
		if nav_scroll != _last_nav_push_scroll:
			_last_nav_push_scroll = nav_scroll
			_refresh_nav_push_targets()
	else:
		_last_nav_push_scroll = -1

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
	# During F crossfade, the gallery is visible only as a compositing source;
	# do not run its hover/card animation logic underneath the detail view.
	if _detail_f_tween != null and _detail_f_tween.is_running():
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
	# Initial cover loading/reveal owns the presentation until the batch is ready.
	if not _card_springs_enabled:
		return
	# 伪弹性：每张卡片一个目标位置 + 当前位置，用弹簧追目标（不做碰撞检测）
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if wrapper == null or not is_instance_valid(wrapper):
			continue
		# A card's entrance tween owns its transform until the reveal finishes.
		if bool(wrapper.get_meta("cover_reveal_pending", false)) or bool(wrapper.get_meta("anim_audit_active", false)):
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


		# 位置速度极小时视为停止，避免无限抖动。
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

	_sidebar_bg = ColorRect.new()
	_sidebar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sidebar_bg.color = SIDEBAR_BG
	_sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar_root.add_child(_sidebar_bg)

	# Hero-driven ambient tint overlay. It sits above the base color but below all controls.
	_sidebar_theme_overlay = ColorRect.new()
	_sidebar_theme_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sidebar_theme_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar_theme_overlay.color = Color.WHITE
	var sidebar_gradient_shader := Shader.new()
	sidebar_gradient_shader.code = """shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 bottom_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
void fragment() { COLOR = mix(top_color, bottom_color, clamp(UV.y, 0.0, 1.0)); }
"""
	_sidebar_theme_material = ShaderMaterial.new()
	_sidebar_theme_material.shader = sidebar_gradient_shader
	_sidebar_theme_material.set_shader_parameter("top_color", Color(0.0, 0.0, 0.0, 0.0))
	_sidebar_theme_material.set_shader_parameter("bottom_color", Color(0.0, 0.0, 0.0, 0.0))
	_sidebar_theme_overlay.material = _sidebar_theme_material
	_sidebar_root.add_child(_sidebar_theme_overlay)

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

	_sidebar_footer_bg = ColorRect.new()
	_sidebar_footer_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sidebar_footer_bg.color = Color(0.105, 0.130, 0.165, 1.0)  # 和侧边栏同色
	_sidebar_footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar_footer.add_child(_sidebar_footer_bg)

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
		vbar.value_changed.connect(_on_cover_scroll_value_changed)

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

# 以导航抽屉的微弱光晕线作为插入锚点，决定卡片向上或向下让位。
# 返回值是有正负号的位移：负数向上，正数向下。
# 影响边界固定为 [光晕线 - 上安全间距, 抽屉底边 + 下安全间距]，
# 只处理水平重叠明显的列；下方级联位移会被行间距逐步吸收。
func _compute_nav_push_by_col_row(
	cols: int,
	top: float,
	padding: float,
	sidebar_w: float,
	cell_w: float,
	cell_h: float,
	gap: float,
	shadow_h: float
) -> Dictionary:
	var push_by_col_row: Dictionary = {}
	if not _nav_opened or cols <= 0 or _cell_buttons.is_empty():
		return push_by_col_row

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var nav_cx: float = vp.x * 0.5
	var nav_left: float = nav_cx - NAV_DRAWER_W * 0.5
	var nav_right: float = nav_cx + NAV_DRAWER_W * 0.5
	var glow_y: float = NAV_DRAWER_GLOW_Y
	var upper_safe_y: float = glow_y - NAV_DRAWER_TOP_CLEARANCE
	var lower_safe_y: float = NAV_DRAWER_BOTTOM + NAV_DRAWER_GAP
	var scroll_y: float = float(_grid_scroll.scroll_vertical) if _grid_scroll != null else 0.0

	var covered_cols: Array[int] = []
	for col_i in range(cols):
		var col_left_s: float = sidebar_w + padding + float(col_i) * (cell_w + gap)
		var col_right_s: float = col_left_s + cell_w
		var h_ov: float = maxf(0.0, minf(col_right_s, nav_right) - maxf(col_left_s, nav_left))
		if h_ov / maxf(cell_w, 1.0) >= 0.35:
			covered_cols.append(col_i)

	var n_rows: int = (_cell_buttons.size() + cols - 1) / cols
	var row_step: float = cell_h + gap + shadow_h
	for col_i in covered_cols:
		var row_tops: Array[float] = []
		var row_bottoms: Array[float] = []
		var row_offsets: Array[float] = []
		for row_i in range(n_rows):
			# 内容坐标减去滚动偏移，得到卡片当前的基础屏幕位置；不读取已动画的位置，避免位移累加。
			var row_top_s: float = top + padding + float(row_i) * row_step - scroll_y
			row_tops.append(row_top_s)
			row_bottoms.append(row_top_s + cell_h + shadow_h)
			row_offsets.append(0.0)

		# 优先找到光晕线穿过的卡片行。光晕在卡片下三分之一时向上；
		# 在上三分之一时向下；中间区域比较两种位移，选择移动距离更小的一侧。
		var glow_row: int = -1
		for row_i in range(n_rows):
			if row_tops[row_i] <= glow_y and row_bottoms[row_i] >= glow_y:
				glow_row = row_i
				break

		if glow_row >= 0:
			var shift_up: float = maxf(0.0, row_bottoms[glow_row] - upper_safe_y)
			var shift_down: float = maxf(0.0, lower_safe_y - row_tops[glow_row])
			var glow_ratio: float = (glow_y - row_tops[glow_row]) / maxf(cell_h, 1.0)
			var prefer_up: bool = false
			if glow_ratio >= (2.0 / 3.0):
				prefer_up = true
			elif glow_ratio <= (1.0 / 3.0):
				prefer_up = false
			else:
				prefer_up = shift_up <= shift_down

			if prefer_up:
				# 上方是一整个连续行栈，必须同量上移以维持行间距；通常这些行已在视口之外。
				for row_i in range(glow_row + 1):
					row_offsets[row_i] = -shift_up
				# 光晕行以下只有进入抽屉下边界的行才下移，位移通过行间距逐步衰减。
				var up_branch_prev: float = 0.0
				for row_i in range(glow_row + 1, n_rows):
					var up_branch_direct: float = maxf(0.0, lower_safe_y - row_tops[row_i])
					var up_branch_propagated: float = maxf(0.0, up_branch_prev - gap)
					var up_branch_shift: float = maxf(up_branch_direct, up_branch_propagated)
					row_offsets[row_i] = up_branch_shift
					up_branch_prev = up_branch_shift
			else:
				# 光晕位于卡片上部时，将该行及下方行向下让位，不动光晕上方的卡片。
				var down_branch_prev: float = 0.0
				for row_i in range(glow_row, n_rows):
					var down_branch_direct: float = maxf(0.0, lower_safe_y - row_tops[row_i])
					var down_branch_propagated: float = maxf(0.0, down_branch_prev - gap)
					var down_branch_shift: float = maxf(down_branch_direct, down_branch_propagated)
					row_offsets[row_i] = down_branch_shift
					down_branch_prev = down_branch_shift
		else:
			# 光晕线恰好落在两行之间：上方最近的一行清出上边界，下方最近的一行清出下边界。
			var upper_row: int = -1
			for row_i in range(n_rows):
				if row_tops[row_i] < glow_y and row_bottoms[row_i] > upper_safe_y:
					upper_row = row_i
			if upper_row >= 0:
				var gap_shift_up: float = maxf(0.0, row_bottoms[upper_row] - upper_safe_y)
				for row_i in range(upper_row + 1):
					row_offsets[row_i] = -gap_shift_up

			var lower_row: int = -1
			for row_i in range(n_rows):
				if row_tops[row_i] >= glow_y and row_tops[row_i] < lower_safe_y and row_bottoms[row_i] > glow_y:
					lower_row = row_i
					break
			if lower_row >= 0:
				var gap_branch_prev: float = 0.0
				for row_i in range(lower_row, n_rows):
					var gap_branch_direct: float = maxf(0.0, lower_safe_y - row_tops[row_i])
					var gap_branch_propagated: float = maxf(0.0, gap_branch_prev - gap)
					var gap_branch_shift: float = maxf(gap_branch_direct, gap_branch_propagated)
					row_offsets[row_i] = maxf(row_offsets[row_i], gap_branch_shift)
					gap_branch_prev = gap_branch_shift

		for row_i in range(n_rows):
			if absf(row_offsets[row_i]) > 0.01:
				push_by_col_row["%d:%d" % [col_i, row_i]] = row_offsets[row_i]
	return push_by_col_row


# 抽屉完全展开后，只推动左侧最近的一列卡片横向让位。
# 横向位移仍由 _update_card_springs 的位置弹簧驱动，不再旋转卡片。
func _compute_nav_left_push_by_col_row(
	cols: int,
	top: float,
	padding: float,
	sidebar_w: float,
	cell_w: float,
	cell_h: float,
	gap: float,
	shadow_h: float
) -> Dictionary:
	var left_push_by_col_row: Dictionary = {}
	if not _nav_opened or not _nav_drawer_revealed or cols <= 0 or _cell_buttons.is_empty():
		return left_push_by_col_row

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var nav_left: float = vp.x * 0.5 - NAV_DRAWER_W * 0.5
	var left_col: int = -1
	var nearest_gap: float = INF
	for col_i in range(cols):
		var col_left_s: float = sidebar_w + padding + float(col_i) * (cell_w + gap)
		var col_right_s: float = col_left_s + cell_w
		var gap_to_drawer: float = nav_left - col_right_s
		# 只选择抽屉左侧感应范围内最近的一列；不把全屏下更远的列卷入。
		if gap_to_drawer < -NAV_DRAWER_LEFT_OVERLAP_ALLOWANCE:
			continue
		if gap_to_drawer > NAV_DRAWER_LEFT_INFLUENCE:
			continue
		if absf(gap_to_drawer) < absf(nearest_gap):
			nearest_gap = gap_to_drawer
			left_col = col_i

	if left_col < 0:
		return left_push_by_col_row

	var upper_safe_y: float = NAV_DRAWER_GLOW_Y - NAV_DRAWER_TOP_CLEARANCE
	var lower_safe_y: float = NAV_DRAWER_BOTTOM + NAV_DRAWER_GAP
	var scroll_y: float = float(_grid_scroll.scroll_vertical) if _grid_scroll != null else 0.0
	var n_rows: int = (_cell_buttons.size() + cols - 1) / cols
	var row_step: float = cell_h + gap + shadow_h
	var requested_push: float = clampf(
		NAV_CARD_PUSH_CLEARANCE - nearest_gap,
		NAV_CARD_PUSH_MIN_DISTANCE,
		NAV_CARD_PUSH_MAX_DISTANCE
	)
	# 卡片不能被横向推过 ScrollContainer 的左裁切边界。
	var local_x: float = float(left_col) * (cell_w + gap)
	var available_push: float = maxf(0.0, local_x + padding)
	var push_distance: float = minf(requested_push, available_push)
	if push_distance <= 0.01:
		return left_push_by_col_row

	for row_i in range(n_rows):
		var card_top_s: float = top + padding + float(row_i) * row_step - scroll_y
		var card_bottom_s: float = card_top_s + cell_h
		# 只推动实际进入抽屉纵向影响边界的卡片行。
		if card_bottom_s <= upper_safe_y or card_top_s >= lower_safe_y:
			continue
		left_push_by_col_row["%d:%d" % [left_col, row_i]] = push_distance

	return left_push_by_col_row


# 抽屉打开且滚动位置改变时，仅刷新弹簧目标；不改变当前位置、速度或卡片尺寸。
func _refresh_nav_push_targets() -> void:
	if not _nav_opened or _grid == null or _grid_scroll == null or _cell_buttons.is_empty():
		return
	var cols: int = int(_grid.get_meta("cols", 0))
	if cols <= 0:
		return
	var top: float = float(_grid.get_meta("nav_layout_top", _grid_root.offset_top))
	var padding: float = float(_grid.get_meta("nav_padding", 0.0))
	var sidebar_w: float = float(_grid.get_meta("nav_sidebar_w", SIDEBAR_W_BASE * _ui_scale))
	var cell_w: float = float(_grid.get_meta("cell_w", 0.0))
	var cell_h: float = float(_grid.get_meta("cell_h", 0.0))
	var gap: float = float(_grid.get_meta("col_gap", 0.0))
	var shadow_h: float = float(_grid.get_meta("nav_shadow_h", SHADOW_H_BASE * _ui_scale))
	var pushes: Dictionary = _compute_nav_push_by_col_row(
		cols, top, padding, sidebar_w, cell_w, cell_h, gap, shadow_h
	)
	var left_pushes: Dictionary = _compute_nav_left_push_by_col_row(
		cols, top, padding, sidebar_w, cell_w, cell_h, gap, shadow_h
	)
	var row_step: float = cell_h + gap + shadow_h
	var rows: int = (_cell_buttons.size() + cols - 1) / cols
	var base_content_height: float = float(rows) * row_step
	var max_target_bottom: float = base_content_height
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if wrapper == null or not is_instance_valid(wrapper):
			continue
		var row: int = i / cols
		var col: int = i % cols
		var target_x: float = float(col) * (cell_w + gap)
		var target_y: float = float(row) * row_step
		var key: String = "%d:%d" % [col, row]
		if pushes.has(key):
			target_y += float(pushes[key])
		if left_pushes.has(key):
			target_x -= float(left_pushes[key])
		max_target_bottom = maxf(max_target_bottom, target_y + cell_h + shadow_h)
		wrapper.set_meta("target_pos", Vector2(target_x, target_y))
	# 抽屉打开期间只扩展、不缩短滚动内容，避免滚动到最底部时卡片被裁切或反复改变滚动上限。
	var previous_content_height: float = float(_grid.custom_minimum_size.y)
	_grid.custom_minimum_size.y = maxf(previous_content_height, max_target_bottom)


func _relayout() -> void:
	if _sidebar_root == null or _grid_root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s: float = _ui_scale
	var fs: float = _font_scale
	var sidebar_w: float = SIDEBAR_W_BASE * s
	var top: int = _compute_top_offset()

	_relayout_sidebar(s, fs, sidebar_w, top)

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

	# 从 CARD_TIERS 选择卡片档位，保持列数、卡宽和间距的原有判定规则。
	var tier_choice: Dictionary = _choose_grid_card_tier(avail_w_logic)
	var chosen_card_w: float = float(tier_choice["card_w"])
	var chosen_cols: int = int(tier_choice["cols"])
	var chosen_gap: float = float(tier_choice["gap"])

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
	# 保存当前布局几何，供抽屉打开期间的滚动刷新复用，避免每帧完整重排。
	_grid.set_meta("nav_layout_top", float(top))
	_grid.set_meta("nav_padding", float(padding))
	_grid.set_meta("nav_sidebar_w", sidebar_w)
	_grid.set_meta("nav_shadow_h", shadow_h)
	# 本次是否要动画（由调用方设置），用完立即重置
	var should_animate: bool = _animate_layout
	_animate_layout = false
	# ── 抽屉挤压 ──
	# 按当前滚动偏移计算每一行的屏幕位置，只下推实际进入抽屉遮挡范围的卡片。
	var push_by_col_row: Dictionary = _compute_nav_push_by_col_row(
		cols, float(top), float(padding), sidebar_w, cell_w, cell_h, gap, shadow_h
	)
	var left_push_by_col_row: Dictionary = _compute_nav_left_push_by_col_row(
		cols, float(top), float(padding), sidebar_w, cell_w, cell_h, gap, shadow_h
	)

	# 3. 应用
	var max_target_bottom: float = _layout_grid_card_targets(
		cols, cell_w, cell_h, gap, shadow_h, should_animate, push_by_col_row, left_push_by_col_row
	)

	# 内容总高（让 ScrollContainer 能滚）；向下让位超出原内容边界时，确保末尾卡片仍可滚动到。
	if _grid != null:
		var rows: int = (_cell_buttons.size() + cols - 1) / cols
		var base_content_height: float = float(rows) * (cell_h + gap + shadow_h)
		_grid.set_meta("nav_base_content_height", base_content_height)
		_grid.custom_minimum_size.y = maxf(base_content_height, max_target_bottom)

	_relayout_sidebar_items(s, fs)


func _relayout_sidebar(s: float, fs: float, sidebar_w: float, top: int) -> void:
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


func _relayout_sidebar_items(s: float, fs: float) -> void:
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

func _choose_grid_card_tier(avail_w_logic: float) -> Dictionary:
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

	return {"card_w": chosen_card_w, "cols": chosen_cols, "gap": chosen_gap}


func _layout_grid_card_targets(
	cols: int,
	cell_w: float,
	cell_h: float,
	gap: float,
	shadow_h: float,
	should_animate: bool,
	push_by_col_row: Dictionary,
	left_push_by_col_row: Dictionary
) -> float:
	var max_target_bottom: float = 0.0
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
			if left_push_by_col_row.has(key):
				target_x -= float(left_push_by_col_row[key])
			max_target_bottom = maxf(max_target_bottom, target_y + cell_h + shadow_h)

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
		# cover_rect uses PRESET_FULL_RECT and EXPAND_IGNORE_SIZE. Giving it
		# a minimum size propagates through the Button's theme padding,
		# enlarging the Button by 8px and cropping the 2:3 poster.
		var ov: Panel = btn.get_meta("overlay", null)
		if ov != null:
			ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# pivot 在卡片中心：整体放大更自然
		btn.pivot_offset = Vector2(btn.size.x * 0.5, btn.size.y * 0.5)

	return max_target_bottom


# ---------------------------------------------------------------------------
# 数据

func set_games(arr: Array[Dictionary]) -> void:
	var perf_set_games_started_msec: int = Time.get_ticks_msec()
	# Reuse existing cards only when the complete payload is unchanged.
	# Full dictionary comparison preserves updates to playtime, metadata, and cover paths.
	if arr == _all_games:
		return
	_all_games = arr
	_rebuild_view()

func resolve_games_by_ids(item_ids: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for item_id in item_ids:
		for game in _all_games:
			if str(game.get("id")) == str(item_id):
				resolved.append(game)
				break
	return resolved

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

	btn.mouse_entered.connect(func(): btn.set_meta("hovered", not _exit_cooldown); _refresh_sidebar_styles())
	btn.mouse_exited.connect(func(): btn.set_meta("hovered", false); _refresh_sidebar_styles())
	btn.pressed.connect(_on_sidebar_pressed.bind(index))
	return btn

# ---------------------------------------------------------------------------
# 海报墙卡片

func _rebuild_grid() -> void:
	_cover_queue_batching = true
	_card_springs_enabled = false
	_cover_reveals_pending = 0
	_card_springs_gate_started_usec = Time.get_ticks_usec()
	_cover_reveal_next_usec = 0
	_cover_first_reveal_frame_separated = false
	_cover_reveal_deferred_to_process = false
	_cover_reveal_schedule_pending = false
	_cover_reveal_last_schedule_frame = -1
	_anim_audit_active_reveals = 0
	var perf_grid_started_msec: int = Time.get_ticks_msec()
	_perf_grid_generation += 1
	_perf_grid_started_msec = perf_grid_started_msec
	_perf_grid_cache_hits = 0
	_perf_grid_async_queued = 0
	_perf_grid_async_pending = 0
	_perf_grid_first_cover_logged = false
	_perf_cover_queue_wait_total_ms = 0.0
	_perf_cover_queue_wait_max_ms = 0.0
	_perf_cover_file_read_total_ms = 0.0
	_perf_cover_file_read_max_ms = 0.0
	_perf_cover_decode_total_ms = 0.0
	_perf_cover_decode_max_ms = 0.0
	_perf_cover_apply_total_ms = 0.0
	_perf_cover_apply_max_ms = 0.0
	_perf_cover_apply_queue_wait_total_ms = 0.0
	_perf_cover_apply_queue_wait_max_ms = 0.0
	_perf_cover_image_decode_total_ms = 0.0
	_perf_cover_image_decode_max_ms = 0.0
	_perf_cover_resize_total_ms = 0.0
	_perf_cover_resize_max_ms = 0.0
	_perf_cover_mipmap_total_ms = 0.0
	_perf_cover_mipmap_max_ms = 0.0
	_perf_cover_texture_create_total_ms = 0.0
	_perf_cover_texture_create_max_ms = 0.0
	_perf_cover_texture_assign_total_ms = 0.0
	_perf_cover_texture_assign_max_ms = 0.0
	_perf_cover_animated_check_total_ms = 0.0
	_perf_cover_animated_check_max_ms = 0.0
	_perf_cover_reveal_request_total_ms = 0.0
	_perf_cover_reveal_request_max_ms = 0.0
	_perf_cover_plugin_load_elapsed_total_ms = 0.0
	_perf_cover_plugin_load_elapsed_max_ms = 0.0
	_perf_cover_source_pixels_total = 0
	_perf_cover_output_pixels_total = 0
	_perf_cover_resized_count = 0
	_perf_cover_decoded_image_samples = 0
	_perf_cover_apply_queue_peak = _cover_apply_queue.size()
	_perf_cover_stage_detail_logs = 0
	_perf_cover_samples = 0
	_perf_cover_peak_active = 0
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
	_queue_cover_geometry_diag("grid_rebuilt")
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
	_cover_queue_batching = false
	# 封面入场动画只在首次构建、排序 / 搜索变化（pop）时触发；
	# 增删改刷新（如删除一个游戏）不应让整墙卡片重播入场。
	var should_play_cover_reveal: bool = (not _first_grid_build_done) or pop
	if should_play_cover_reveal:
		_reveal_visible_loaded_covers()
	else:
		_mark_loaded_covers_as_revealed()
	_first_grid_build_done = true
	_prioritize_cover_load_queue()
	_pump_cover_load_queue()
	_try_enable_card_springs()

func _make_grid_cell(index: int, game: Dictionary) -> Button:
	# wrapper 是 _grid 里的格子，比卡片高 SHADOW_H_BASE，下面留阴影空间
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.set_meta("game_index", index)

	# 卡片本体：占 wrapper 上部，底部让出 SHADOW_H_BASE 给阴影
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	# The cover is sized by its anchors, not by the Button minimum-size chain.
	# Otherwise the Button grows beyond the 2:3 wrapper by theme margins.
	btn.custom_minimum_size = Vector2.ZERO
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Button is parented to wrapper near the end of this function. Its anchors
	# and offsets are set after parenting so the preset uses the real parent rect.
	btn.set_meta("game_index", index)
	btn.set_meta("wrapper", wrapper)
	# 阴影直接用 StyleBoxFlat 画（带圆角的投影，跟着卡片一起放大）
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.205, 0.245, 0.305, 1.0)
	bg.set_corner_radius_all(6)
	# A1: a hairline edge gives the poster a physical boundary without a glass frame.
	bg.set_border_width_all(0)
	# Prevent the Button theme content margins from expanding the 2:3 cover.
	bg.set_content_margin_all(0.0)
	bg.border_color = Color.TRANSPARENT
	bg.shadow_color = Color(0, 0, 0, HOVER_H_IDLE_SHADOW_ALPHA)
	bg.shadow_size = int(HOVER_H_IDLE_SHADOW_SIZE)
	bg.shadow_offset = Vector2(0.0, HOVER_H_IDLE_SHADOW_OFFSET)
	btn.add_theme_stylebox_override("normal", bg)
	# hover / pressed / focus 都用同一个（悬停时的变化在 _refresh_grid_styles 里做）
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	btn.set_meta("bg_style", bg)
	# Hover transform only affects the card, not its wrapper/layout spring.
	btn.set_meta("hover_h_state", 0)
	btn.set_meta("hover_h_progress", 0.0)
	btn.set_meta("hover_g_progress", 0.0)
	btn.set_meta("click_e_scale", 1.0)
	btn.scale = Vector2.ONE
	btn.position = Vector2.ZERO

	var cover_wrap := Control.new()
	cover_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_wrap.clip_contents = true
	cover_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cover_wrap)
	btn.set_meta("cover_wrap", cover_wrap)

	var cover_rect := TextureRect.new()
	cover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 缩小时启用 mipmap，避免边缘锐利（配合 _load_image_smart 的 generate_mipmaps）
	cover_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 灰度 shader：不可启动的游戏 → 降饱和
	var gray_mat := ShaderMaterial.new()
	gray_mat.shader = CARD_COVER_SHADER
	var is_playable: bool = bool(game.get("playable", true))
	gray_mat.set_shader_parameter(
		"saturation",
		1.0 if is_playable else CARD_UNPLAYABLE_SATURATION
	)
	gray_mat.set_shader_parameter("brightness", 1.0)
	cover_rect.material = gray_mat
	btn.set_meta("gray_mat", gray_mat)
	var cover_path: String = str(game.get("cover", "")).replace("\\", "/")
	btn.set_meta("cover_path", cover_path)
	btn.set_meta("cover_load_pending", false)
	btn.set_meta("cover_loaded", false)
	btn.set_meta("cover_reveal_started", false)
	if not cover_path.is_empty() and FileAccess.file_exists(cover_path):
		# Hide the card shell until its poster is ready, then reveal the whole card.
		wrapper.modulate.a = 0.0
		# 优先从缓存读取，秒出图，防闪烁
		if _cover_texture_cache.has(cover_path):
			_perf_grid_cache_hits += 1
			cover_rect.texture = _cover_texture_cache[cover_path]
			btn.set_meta("cover_loaded", true)
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



	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0)
	ov_style.set_corner_radius_all(0)
	ov_style.set_border_width_all(HOVER_H_BORDER_WIDTH)
	ov_style.border_color = Color(HOVER_H_ACTIVE_BORDER.r, HOVER_H_ACTIVE_BORDER.g, HOVER_H_ACTIVE_BORDER.b, 0.0)
	overlay.add_theme_stylebox_override("panel", ov_style)
	btn.set_meta("hover_outline_style", ov_style)
	btn.add_child(overlay)
	btn.set_meta("overlay", overlay)

	# E click lab: translucent white material flash, separate from the H+G hover overlay.
	var click_flash := ColorRect.new()
	click_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	click_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(click_flash)
	btn.set_meta("click_e_flash", click_flash)

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
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.offset_left = 0.0
	btn.offset_top = 0.0
	btn.offset_right = 0.0
	# Keep the existing bottom space reserved for the card shadow.
	btn.offset_bottom = -SHADOW_H_BASE * _ui_scale

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
			var sidebar_settings: Dictionary = _font_manager.get_field_settings("game_sidebar", "games") if _font_manager != null else {}
			var normal_hex := str(sidebar_settings.get("font_color", "")).strip_edges()
			var selected_hex := str(sidebar_settings.get("selected_color", "")).strip_edges()
			var is_selected := _sidebar_detail_highlight and i == selected_index
			var color := SIDEBAR_TEXT
			if not normal_hex.is_empty():
				color = Color.from_string(normal_hex, SIDEBAR_TEXT)
			if is_selected:
				color = Color.from_string(selected_hex, SIDEBAR_TEXT_SEL) if not selected_hex.is_empty() else SIDEBAR_TEXT_SEL
			elif is_hov:
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

# Invert CSS cubic-bezier x(t) so the Godot tween follows the same time curve.
func _hover_css_bezier(fraction: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var low: float = 0.0
	var high: float = 1.0
	for _iteration in range(20):
		var t: float = (low + high) * 0.5
		var inv: float = 1.0 - t
		var curve_x: float = 3.0 * inv * inv * t * x1 + 3.0 * inv * t * t * x2 + t * t * t
		if curve_x < fraction:
			low = t
		else:
			high = t
	var t: float = (low + high) * 0.5
	var inv: float = 1.0 - t
	return 3.0 * inv * inv * t * y1 + 3.0 * inv * t * t * y2 + t * t * t

func _hover_h_ease(fraction: float) -> float:
	return _hover_css_bezier(fraction, 0.25, 0.1, 0.25, 1.0)

func _hover_g_ease(fraction: float) -> float:
	return _hover_css_bezier(fraction, 0.25, 0.8, 0.25, 1.0)

func _hover_g_apply(progress: float, btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.set_meta("hover_g_progress", progress)
	# CSS transform-origin: 50% 50%, scale only; no translateY.
	btn.pivot_offset = btn.size * 0.5
	var factor: float = lerpf(1.0, HOVER_G_SCALE, progress) * float(btn.get_meta("click_e_scale", 1.0))
	btn.scale = Vector2(factor, factor)

func _hover_g_animate(fraction: float, btn: Button, start: float, finish: float) -> void:
	_hover_g_apply(lerpf(start, finish, _hover_g_ease(fraction)), btn)

func _hover_h_apply(progress: float, btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.set_meta("hover_h_progress", progress)
	var bg: StyleBoxFlat = btn.get_meta("bg_style", null)
	if bg != null:
		bg.shadow_size = int(round(lerpf(HOVER_H_IDLE_SHADOW_SIZE, HOVER_H_ACTIVE_SHADOW_SIZE, progress) * _ui_scale))
		bg.shadow_offset = Vector2(0.0, lerpf(HOVER_H_IDLE_SHADOW_OFFSET, HOVER_H_ACTIVE_SHADOW_OFFSET, progress) * _ui_scale)
		bg.shadow_color = Color(0.0, 0.0, 0.0, lerpf(HOVER_H_IDLE_SHADOW_ALPHA, HOVER_H_ACTIVE_SHADOW_ALPHA, progress))
	var outline: StyleBoxFlat = btn.get_meta("hover_outline_style", null)
	if outline != null:
		outline.border_color = Color(HOVER_H_ACTIVE_BORDER.r, HOVER_H_ACTIVE_BORDER.g, HOVER_H_ACTIVE_BORDER.b, HOVER_H_ACTIVE_BORDER.a * progress)
	var mat: ShaderMaterial = btn.get_meta("gray_mat", null)
	if mat != null:
		mat.set_shader_parameter("brightness", lerpf(1.0, HOVER_H_BRIGHTNESS, progress) * float(btn.get_meta("click_e_brightness", 1.0)))

func _hover_h_animate(fraction: float, btn: Button, start: float, finish: float) -> void:
	_hover_h_apply(lerpf(start, finish, _hover_h_ease(fraction)), btn)

func _refresh_grid_styles() -> void:
	for i in range(_cell_buttons.size()):
		var btn: Button = _cell_buttons[i]
		if not is_instance_valid(btn):
			continue
		var target_state: int = 1 if i == _hover_index else 0
		if int(btn.get_meta("hover_h_state", 0)) == target_state:
			continue
		btn.set_meta("hover_h_state", target_state)
		# H (230ms) and G (250ms) have independent CSS timings.
		var old_g: Tween = null
		if btn.has_meta("hover_g_tween"):
			old_g = btn.get_meta("hover_g_tween")
		if old_g != null and old_g.is_valid():
			old_g.kill()
		var g_start: float = float(btn.get_meta("hover_g_progress", 0.0))
		var g_tween: Tween = create_tween()
		g_tween.tween_method(_hover_g_animate.bind(btn, g_start, float(target_state)), 0.0, 1.0, HOVER_G_DURATION).set_trans(Tween.TRANS_LINEAR)
		btn.set_meta("hover_g_tween", g_tween)
		# Stop the previous transition to maintain continuity on fast enter/exit.
		var previous: Tween = null
		if btn.has_meta("hover_h_tween"):
			previous = btn.get_meta("hover_h_tween")
		if previous != null and previous.is_valid():
			previous.kill()
		var from_value: float = float(btn.get_meta("hover_h_progress", 0.0))
		var to_value: float = float(target_state)
		var tween: Tween = create_tween()
		tween.tween_method(_hover_h_animate.bind(btn, from_value, to_value), 0.0, 1.0, HOVER_H_DURATION).set_trans(Tween.TRANS_LINEAR)
		btn.set_meta("hover_h_tween", tween)

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

	# E material click feedback: play in place before the existing detail action.
	# The existing hover H+G remains active; no other cards are animated.
	if index < 0 or index >= _cell_buttons.size():
		return
	var btn: Button = _cell_buttons[index]
	if not is_instance_valid(btn):
		return
	if bool(btn.get_meta("click_e_pending", false)):
		return
	# Start media decoding during the existing 360ms click feedback so the
	# detail transition can begin with a prepared, consistent media set.
	if _detail_view != null and _detail_view.has_method("prepare_game_media"):
		_detail_view.call("prepare_game_media", games[index])
	btn.set_meta("click_e_pending", true)
	var tween: Tween = create_tween()
	tween.tween_method(_click_e_frame.bind(btn), 0.0, 1.0, 0.36).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(_click_e_complete.bind(btn, index))

func _click_e_frame(fraction: float, btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	# Exact HTML E keyframe timing: press at 23%, material brightness at 20%, flash at 18%.
	var scale_value: float = lerpf(1.0, 0.975, _hover_css_bezier(fraction / 0.23, 0.22, 0.85, 0.25, 1.0)) if fraction < 0.23 else lerpf(0.975, 1.0, _hover_css_bezier((fraction - 0.23) / 0.77, 0.22, 0.85, 0.25, 1.0))
	btn.set_meta("click_e_scale", scale_value)
	_hover_g_apply(float(btn.get_meta("hover_g_progress", 0.0)), btn)
	var brightness: float = lerpf(1.0, 1.24, fraction / 0.2) if fraction < 0.2 else lerpf(1.24, 1.0, (fraction - 0.2) / 0.8)
	btn.set_meta("click_e_brightness", brightness)
	_hover_h_apply(float(btn.get_meta("hover_h_progress", 0.0)), btn)
	var flash: ColorRect = btn.get_meta("click_e_flash", null)
	if is_instance_valid(flash):
		var flash_fraction: float = minf(fraction * (0.36 / 0.35), 1.0)
		var alpha: float = lerpf(0.0, 0.18, flash_fraction / 0.18) if flash_fraction < 0.18 else lerpf(0.18, 0.0, (flash_fraction - 0.18) / 0.82)
		flash.color.a = maxf(alpha, 0.0)

func _click_e_complete(btn: Button, index: int) -> void:
	if not is_instance_valid(btn):
		return
	btn.set_meta("click_e_scale", 1.0)
	btn.set_meta("click_e_brightness", 1.0)
	btn.set_meta("click_e_pending", false)
	_hover_g_apply(float(btn.get_meta("hover_g_progress", 0.0)), btn)
	_hover_h_apply(float(btn.get_meta("hover_h_progress", 0.0)), btn)
	var flash: ColorRect = btn.get_meta("click_e_flash", null)
	if is_instance_valid(flash):
		flash.color.a = 0.0
	if index >= 0 and index < games.size() and not _exit_cooldown and not _batch_mode:
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
	# The E material click feedback (360ms) has already completed before this call.
	# F: gallery opacity 1 -> 0; detail opacity 0 -> 1, scale 0.97 -> 1.
	_detail_f_stop()
	_detail_f_exiting = false
	# show_game preserves a matching media preload started during click feedback,
	# and invalidates/replaces it only when the selected game differs.
	_detail_view.show_game(games[index])
	_detail_view.visible = true
	_detail_view.pivot_offset = _detail_view.size * 0.5
	_detail_view.scale = Vector2.ONE * DETAIL_F_START_SCALE
	_detail_view.modulate.a = 0.0
	_grid_scroll.visible = true
	_grid_scroll.modulate.a = 1.0
	_grid_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The detail view is on top of the gallery; it must intercept clicks even
	# while transparent, otherwise the card beneath it can be clicked again.
	_detail_view.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_item_id: String = str(games[index].get("id", "")).strip_edges()
	if not theme_item_id.is_empty():
		game_theme_requested.emit(theme_item_id)
	else:
		game_theme_cleared.emit()
	_sidebar_detail_highlight = true
	_refresh_sidebar_styles()
	# Keep both surfaces visible during the 500ms crossfade; only hide the
	# gallery after the animation ends. Sidebar and grid root never move.
	_detail_f_enter_frame(0.0)
	_detail_f_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_detail_f_tween.tween_method(_detail_f_enter_frame, 0.0, 1.0, DETAIL_F_DURATION)
	_detail_f_tween.finished.connect(_detail_f_enter_complete)

func _exit_detail(instant: bool = false) -> void:
	if _detail_view == null:
		return
	# Switching sections must always settle immediately, even if an exit is
	# already in progress. The previous guard left a fading panel visible.
	if instant:
		_detail_view.cancel_pending_game_media()
		_detail_f_stop()
		_detail_f_exit_complete()
		return
	if not _detail_view.visible or _detail_f_exiting:
		return
	# Invalidate in-flight media before the view starts leaving, so assets cannot
	# appear midway through the exit transition.
	_detail_view.cancel_pending_game_media()
	# If back is pressed during entry, reverse from the CURRENT opacity,
	# instead of jumping the panel back to fully opaque.
	var current_alpha: float = clampf(_detail_view.modulate.a, 0.0, 1.0)
	_detail_f_stop()
	_detail_f_exiting = true
	game_theme_cleared.emit()
	_sidebar_detail_highlight = false
	# Drop stale hover state from the detail view's back-button position.
	for item in _sidebar_items:
		if is_instance_valid(item):
			item.set_meta("hovered", false)
	_refresh_sidebar_styles()
	_hover_index = -1
	_refresh_grid_styles()
	# Prevent accidental selection of the first card beneath the back button.
	_exit_cooldown = true
	_exit_cooldown_t = 0.0
	_grid_scroll.visible = true
	_grid_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_view.mouse_filter = Control.MOUSE_FILTER_STOP
	# Reverse the F curve from the actual current alpha to zero. Tween a normalized
	# 0..1 progress and interpolate the captured alpha once; never ease an already
	# eased opacity value a second time.
	_detail_f_exit_frame(0.0, current_alpha)
	if current_alpha <= 0.001:
		_detail_f_exit_complete()
		return
	_detail_f_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_detail_f_tween.tween_method(
		_detail_f_exit_frame.bind(current_alpha),
		0.0, 1.0, DETAIL_F_DURATION * current_alpha
	)
	_detail_f_tween.finished.connect(_detail_f_exit_complete)

func _detail_f_stop() -> void:
	if _detail_f_tween != null and _detail_f_tween.is_valid():
		_detail_f_tween.kill()
	_detail_f_tween = null

func _detail_f_progress(fraction: float) -> float:
	# Match the HTML F lab: cubic-bezier(.22, .78, .2, 1).
	return _hover_css_bezier(clampf(fraction, 0.0, 1.0), 0.22, 0.78, 0.20, 1.0)

func _detail_f_enter_frame(fraction: float) -> void:
	if not is_instance_valid(_detail_view) or not is_instance_valid(_grid_scroll):
		return
	var t: float = _detail_f_progress(fraction)
	_grid_scroll.modulate.a = 1.0 - t
	_detail_view.modulate.a = t
	_detail_view.scale = Vector2.ONE * lerpf(DETAIL_F_START_SCALE, 1.0, t)
	_detail_view.call("set_transition_alpha", t)

func _detail_f_enter_complete() -> void:
	_detail_f_tween = null
	_detail_f_enter_frame(1.0)
	if not is_instance_valid(_detail_view) or not is_instance_valid(_grid_scroll):
		return
	_detail_view.scale = Vector2.ONE
	_detail_view.modulate.a = 1.0
	_detail_view.mouse_filter = Control.MOUSE_FILTER_STOP
	# Media decoding runs concurrently with the F transition and is applied as one
	# batch; do not append Hero/Logo/screenshots after the transition has finished.
	_grid_scroll.modulate.a = 0.0
	_grid_scroll.visible = false
	_grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

func _detail_f_exit_frame(fraction: float, start_alpha: float) -> void:
	if not is_instance_valid(_detail_view) or not is_instance_valid(_grid_scroll):
		return
	var t: float = _detail_f_progress(fraction)
	# Interpolate from the captured visible alpha to zero using one easing pass.
	var alpha: float = lerpf(clampf(start_alpha, 0.0, 1.0), 0.0, t)
	_grid_scroll.modulate.a = 1.0 - alpha
	_detail_view.modulate.a = alpha
	_detail_view.scale = Vector2.ONE * lerpf(DETAIL_F_START_SCALE, 1.0, alpha)
	_detail_view.call("set_transition_alpha", alpha)

func _detail_f_exit_complete() -> void:
	_detail_f_stop()
	if is_instance_valid(_detail_view):
		_detail_view.cancel_pending_game_media()
		_detail_view.call("set_transition_alpha", 1.0)
		_detail_view.visible = false
		_detail_view.modulate.a = 1.0
		_detail_view.scale = Vector2.ONE
		_detail_view.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_grid_scroll):
		_grid_scroll.visible = true
		_grid_scroll.modulate.a = 1.0
		_grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_detail_f_exiting = false

func apply_game_theme_palette(palette: Dictionary) -> void:
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent: Color = _resolve_game_theme_color(colors, "accent", Color(0.30, 0.48, 0.66))
	var ambient: Color = _resolve_game_theme_color(colors, "ambient", SIDEBAR_BG)
	# Keep the base neutral; use a transparent Hero-derived gradient to make hue changes visible.
	var top_tint: Color = accent.darkened(0.30)
	top_tint.a = 0.52
	var bottom_tint: Color = ambient
	bottom_tint.a = 0.28
	_transition_sidebar_gradient(top_tint, bottom_tint)
	# Fade the footer's opaque plate out so the shared sidebar gradient continues behind the add button.
	_transition_sidebar_footer(Color(0.105, 0.130, 0.165, 0.0))
	# Keep the add affordance themed, but subtler than the surrounding ambient tint.
	_transition_add_glow_color(Color(0.50, 0.72, 0.95).lerp(accent, 0.42))
	if _detail_view != null and _detail_view.has_method("apply_game_theme_palette"):
		_detail_view.apply_game_theme_palette(palette)

func reset_game_theme_palette() -> void:
	_transition_sidebar_gradient(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0))
	_transition_sidebar_footer(Color(0.105, 0.130, 0.165, 1.0))
	_transition_add_glow_color(Color(0.50, 0.72, 0.95))
	if _detail_view != null and _detail_view.has_method("reset_game_theme_palette"):
		_detail_view.reset_game_theme_palette()

func _transition_sidebar_gradient(target_top: Color, target_bottom: Color) -> void:
	if _sidebar_theme_material == null or not is_instance_valid(_sidebar_theme_material):
		return
	if _sidebar_gradient_tween != null and _sidebar_gradient_tween.is_valid():
		_sidebar_gradient_tween.kill()
	var start_top: Color = _sidebar_theme_material.get_shader_parameter("top_color")
	var start_bottom: Color = _sidebar_theme_material.get_shader_parameter("bottom_color")
	_sidebar_gradient_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sidebar_gradient_tween.tween_method(Callable(self, "_set_sidebar_gradient_progress").bind(start_top, start_bottom, target_top, target_bottom), 0.0, 1.0, 0.68)

func _set_sidebar_gradient_progress(progress: float, start_top: Color, start_bottom: Color, target_top: Color, target_bottom: Color) -> void:
	if _sidebar_theme_material == null or not is_instance_valid(_sidebar_theme_material):
		return
	_sidebar_theme_material.set_shader_parameter("top_color", start_top.lerp(target_top, progress))
	_sidebar_theme_material.set_shader_parameter("bottom_color", start_bottom.lerp(target_bottom, progress))

func _transition_sidebar_footer(target: Color) -> void:
	if _sidebar_footer_bg == null or not is_instance_valid(_sidebar_footer_bg):
		return
	if _sidebar_footer_theme_tween != null and _sidebar_footer_theme_tween.is_valid():
		_sidebar_footer_theme_tween.kill()
	_sidebar_footer_theme_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sidebar_footer_theme_tween.tween_property(_sidebar_footer_bg, "color", target, 0.68)

func _transition_add_glow_color(target: Color) -> void:
	if _add_btn == null or not is_instance_valid(_add_btn):
		return
	var glow_bg: ColorRect = _add_btn.get_meta("glow_bg", null)
	if glow_bg == null or not is_instance_valid(glow_bg):
		return
	var mat: ShaderMaterial = glow_bg.material as ShaderMaterial
	if mat == null:
		return
	if _add_glow_theme_tween != null and _add_glow_theme_tween.is_valid():
		_add_glow_theme_tween.kill()
	var current_value: Variant = mat.get_shader_parameter("glow_color")
	var start: Color = current_value if current_value is Color else Color(0.50, 0.72, 0.95)
	_add_glow_theme_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_add_glow_theme_tween.tween_method(Callable(self, "_set_add_glow_theme_color").bind(mat), start, target, 0.68)

func _set_add_glow_theme_color(value: Color, mat: ShaderMaterial) -> void:
	if mat != null and is_instance_valid(mat):
		mat.set_shader_parameter("glow_color", value)

func _resolve_game_theme_color(colors: Dictionary, key: String, fallback: Color) -> Color:
	var value: String = str(colors.get(key, "")).strip_edges()
	if value.is_empty():
		return fallback
	return Color.from_string(value, fallback)

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
	if not btn.has_meta("anim_holder"):
		return
	var holder: Control = btn.get_meta("anim_holder") as Control
	if holder == null or not is_instance_valid(holder):
		return
	var path: String = str(btn.get_meta("anim_path", ""))
	if path.is_empty():
		path = str(btn.get_meta("cover_path", ""))
		if path.is_empty():
			return
		_check_animated(path, btn)
		path = str(btn.get_meta("anim_path", ""))
		if path.is_empty():
			return
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
	# 插件文档使用 play() 启动；保留属性回退以兼容旧版扩展。
	if player.has_method("play"):
		player.call("play")
	else:
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
			if player.has_method("stop"):
				player.call("stop")
			else:
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
		var poster = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_file", path) as Texture2D
		if poster != null:
			return poster
		var animated = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_file", path)
		if animated != null:
			if animated.has_method("set_frame"):
				animated.call("set_frame", 0)
			if animated.has_method("get_frame_texture"):
				var first_frame = animated.call("get_frame_texture", 0) as Texture2D
				if first_frame != null:
					return first_frame
			if animated.has_method("get_poster_texture"):
				var fallback_poster = animated.call("get_poster_texture") as Texture2D
				if fallback_poster != null:
					return fallback_poster

	# 与藏品室一致：直接走 WebP buffer API 兜底，彻底避开 Image.load(path) 触发底层报错
	if path.get_extension().to_lower() == "webp":
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var bytes: PackedByteArray = file.get_buffer(file.get_length())
			file.close()
			if not bytes.is_empty():
				var image := Image.new()
				if image.load_webp_from_buffer(bytes) == OK and not image.is_empty():
					image.generate_mipmaps()
					return ImageTexture.create_from_image(image)
		return null

	# 非 WebP 格式走常规加载
	var image := Image.new()
	var error: Error = image.load(path)
	if error != OK or image.is_empty():
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
		_exit_detail(true)
	# 从隐藏切回可见 → 卡片弹入（切板块时能看到"弹"的效果）
	if v and not was_visible:
		_pop_cards_in()

func _pop_cards_in() -> void:
	# Do not inject random spring offsets while cover loading/reveals own the layout.
	if not _card_springs_enabled:
		return
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

func is_batch_mode() -> bool:
	return _batch_mode

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
	# The grid is built in display order, so FIFO starts with the earliest cards.
	# A bounded worker count prevents all covers from competing for disk/CPU at once.
	btn.set_meta("perf_cover_generation", _perf_grid_generation)
	btn.set_meta("cover_load_pending", true)
	_perf_grid_async_queued += 1
	_perf_grid_async_pending += 1
	_cover_load_queue.append({
		"cover_rect": cover_rect,
		"path": path,
		"btn": btn,
		"generation": _perf_grid_generation,
		"queued_usec": Time.get_ticks_usec(),
	})
	_pump_cover_load_queue()

func _pump_cover_load_queue() -> void:
	if _cover_queue_batching:
		return
	while _active_cover_loads < MAX_CONCURRENT_COVER_LOADS and not _cover_load_queue.is_empty():
		var item: Dictionary = _cover_load_queue.pop_front()
		var cover_rect: TextureRect = item.get("cover_rect")
		var btn: Button = item.get("btn")
		var generation: int = int(item.get("generation", -1))
		if not is_instance_valid(cover_rect) or not is_instance_valid(btn):
			continue
		if generation != _perf_grid_generation:
			continue
		var queue_wait_ms: float = float(Time.get_ticks_usec() - int(item.get("queued_usec", Time.get_ticks_usec()))) / 1000.0
		_active_cover_loads += 1
		_perf_cover_peak_active = maxi(_perf_cover_peak_active, _active_cover_loads)
		WorkerThreadPool.add_task(_load_cover_task.bind(cover_rect, str(item.get("path", "")), btn, queue_wait_ms))

func _on_cover_scroll_value_changed(_value: float) -> void:
	if _cover_queue_batching:
		return
	_reveal_visible_loaded_covers()
	_prioritize_cover_load_queue()
	_pump_cover_load_queue()

func _reveal_visible_loaded_covers() -> void:
	if _cell_buttons.is_empty():
		_cover_reveal_schedule_pending = false
		return
	var current_frame: int = Engine.get_process_frames()
	if _cover_reveal_last_schedule_frame == current_frame:
		_cover_reveal_schedule_pending = true
		return
	var viewport_rect: Rect2
	var has_viewport: bool = _grid_scroll != null and is_instance_valid(_grid_scroll)
	if has_viewport:
		viewport_rect = _grid_scroll.get_global_rect()
		if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
			has_viewport = false
	for btn in _cell_buttons:
		if not is_instance_valid(btn):
			continue
		if not bool(btn.get_meta("cover_loaded", false)):
			continue
		if bool(btn.get_meta("cover_reveal_started", false)):
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if not is_instance_valid(wrapper):
			continue
		if has_viewport and not wrapper.get_global_rect().intersects(viewport_rect):
			continue
		var cover_rect: TextureRect = btn.get_meta("cover_rect", null)
		if not is_instance_valid(cover_rect):
			wrapper.modulate.a = 1.0
			btn.set_meta("cover_reveal_started", true)
			continue
		var crt_material: ShaderMaterial = cover_rect.material as ShaderMaterial
		if crt_material == null:
			wrapper.modulate.a = 1.0
			btn.set_meta("cover_reveal_started", true)
			continue
		btn.set_meta("cover_reveal_started", true)
		_cover_reveal_last_schedule_frame = current_frame
		_cover_reveal_schedule_pending = true
		var now_usec: int = Time.get_ticks_usec()
		var reveal_generation: int = _perf_grid_generation
		var delay_usec: int = maxi(0, _cover_reveal_next_usec - now_usec)
		# CRT entrance timing: 1000 ms per card, staggered by 180 ms.
		_cover_reveal_next_usec = maxi(now_usec, _cover_reveal_next_usec) + 180000
		var cover_size: Vector2 = cover_rect.size
		if cover_size.x <= 0.0 or cover_size.y <= 0.0:
			cover_size = wrapper.size
		crt_material.set_shader_parameter("card_size", cover_size)
		crt_material.set_shader_parameter("crt_progress", 0.0)
		crt_material.set_shader_parameter("crt_scan_progress", 0.0)
		crt_material.set_shader_parameter("crt_strength", 0.65)
		crt_material.set_shader_parameter("crt_active", true)
		wrapper.set_meta("cover_reveal_pending", true)
		_cover_reveals_pending += 1
		var reveal_tween: Tween = wrapper.create_tween()
		if delay_usec > 0:
			reveal_tween.tween_interval(float(delay_usec) / 1000000.0)
		reveal_tween.tween_callback(func():
			if not is_instance_valid(wrapper) or reveal_generation != _perf_grid_generation:
				return
			wrapper.modulate.a = 1.0
			wrapper.scale = Vector2.ONE
			wrapper.rotation_degrees = 0.0
			wrapper.set_meta("vel", Vector2.ZERO)
			wrapper.set_meta("anim_audit_active", true)
			wrapper.set_meta("anim_audit_started_usec", Time.get_ticks_usec())
			_anim_audit_active_reveals += 1
		)
		var set_crt_progress: Callable = func(value: float) -> void:
			if is_instance_valid(crt_material):
				crt_material.set_shader_parameter("crt_progress", value)
		var set_crt_scan_progress: Callable = func(value: float) -> void:
			if is_instance_valid(crt_material):
				crt_material.set_shader_parameter("crt_scan_progress", value)
		reveal_tween.tween_method(set_crt_progress, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal_tween.parallel().tween_method(set_crt_scan_progress, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		reveal_tween.finished.connect(func():
			if not is_instance_valid(wrapper):
				return
			if is_instance_valid(crt_material):
				crt_material.set_shader_parameter("crt_progress", 1.0)
				crt_material.set_shader_parameter("crt_scan_progress", 1.0)
				crt_material.set_shader_parameter("crt_active", false)
			if is_instance_valid(cover_rect):
				cover_rect.position = Vector2.ZERO
				cover_rect.scale = Vector2.ONE
			wrapper.scale = Vector2.ONE
			wrapper.rotation_degrees = 0.0
			wrapper.modulate.a = 1.0
			wrapper.set_meta("cover_reveal_pending", false)
			if reveal_generation != _perf_grid_generation:
				return
			var started_usec: int = int(wrapper.get_meta("anim_audit_started_usec", 0))
			wrapper.set_meta("anim_audit_active", false)
			if started_usec > 0:
				_anim_audit_active_reveals = maxi(0, _anim_audit_active_reveals - 1)
			_cover_reveals_pending = maxi(0, _cover_reveals_pending - 1)
			_try_enable_card_springs()
		)
		# Only one visible cover entrance is scheduled per process frame.
		return
	_cover_reveal_schedule_pending = false

func _mark_loaded_covers_as_revealed() -> void:
	# 已加载好纹理但还没播入场动画的卡片 → 直接标记为已入场，立即显示。
	# 用于增删改刷新时避免整墙重播动画；新卡片（异步加载的）仍会走正常入场。
	for btn in _cell_buttons:
		if not is_instance_valid(btn):
			continue
		if not bool(btn.get_meta("cover_loaded", false)):
			continue
		if bool(btn.get_meta("cover_reveal_started", false)):
			continue
		btn.set_meta("cover_reveal_started", true)
		var wrapper: Control = btn.get_meta("wrapper", null)
		if is_instance_valid(wrapper):
			wrapper.modulate.a = 1.0
		var cover_rect: TextureRect = btn.get_meta("cover_rect", null)
		if is_instance_valid(cover_rect):
			var crt_material: ShaderMaterial = cover_rect.material as ShaderMaterial
			if crt_material != null:
				crt_material.set_shader_parameter("crt_active", false)
				crt_material.set_shader_parameter("crt_progress", 1.0)
				crt_material.set_shader_parameter("crt_scan_progress", 1.0)

func _try_enable_card_springs() -> void:
	if _card_springs_enabled or _cover_queue_batching:
		return
	if _has_pending_visible_cover_work() or _cover_reveals_pending > 0:
		return
	_card_springs_enabled = true
	var waited_ms: float = 0.0
	if _card_springs_gate_started_usec > 0:
		waited_ms = float(Time.get_ticks_usec() - _card_springs_gate_started_usec) / 1000.0
	_card_springs_gate_started_usec = 0

func _has_pending_visible_cover_work() -> bool:
	if _grid_scroll == null or not is_instance_valid(_grid_scroll):
		return _perf_grid_async_pending > 0
	var viewport_rect: Rect2 = _grid_scroll.get_global_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		# Before layout settles, keep the conservative all-cover gate.
		return _perf_grid_async_pending > 0
	for btn in _cell_buttons:
		if not is_instance_valid(btn):
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if not is_instance_valid(wrapper) or not wrapper.get_global_rect().intersects(viewport_rect):
			continue
		if bool(btn.get_meta("cover_load_pending", false)):
			return true
		if bool(btn.get_meta("cover_loaded", false)) and not bool(btn.get_meta("cover_reveal_started", false)):
			return true
	return false

func _prioritize_cover_load_queue() -> void:
	if _cover_load_queue.is_empty() or _grid_scroll == null or not is_instance_valid(_grid_scroll):
		return
	var viewport_rect: Rect2 = _grid_scroll.get_global_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return
	var preload_rect: Rect2 = viewport_rect.grow_individual(0.0, viewport_rect.size.y, 0.0, viewport_rect.size.y)
	var visible_items: Array[Dictionary] = []
	var nearby_items: Array[Dictionary] = []
	var background_items: Array[Dictionary] = []
	for item in _cover_load_queue:
		var btn: Button = item.get("btn")
		if not is_instance_valid(btn):
			continue
		if int(item.get("generation", -1)) != _perf_grid_generation:
			continue
		var wrapper: Control = btn.get_meta("wrapper", null)
		if not is_instance_valid(wrapper):
			continue
		var card_rect: Rect2 = wrapper.get_global_rect()
		if card_rect.intersects(viewport_rect):
			visible_items.append(item)
		elif card_rect.intersects(preload_rect):
			nearby_items.append(item)
		else:
			background_items.append(item)
	_cover_load_queue.clear()
	_cover_load_queue.append_array(visible_items)
	_cover_load_queue.append_array(nearby_items)
	_cover_load_queue.append_array(background_items)

func _load_cover_task(cover_rect: TextureRect, path: String, btn: Button, queue_wait_ms: float) -> void:
	var read_started_usec: int = Time.get_ticks_usec()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		call_deferred("_perf_cover_finish_with_metrics", btn, false, queue_wait_ms, float(Time.get_ticks_usec() - read_started_usec) / 1000.0, 0.0, 0.0)
		return
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var file_read_ms: float = float(Time.get_ticks_usec() - read_started_usec) / 1000.0
	if bytes.size() < 8:
		call_deferred("_perf_cover_finish_with_metrics", btn, false, queue_wait_ms, file_read_ms, 0.0, 0.0)
		return
		
	var img := Image.new()
	var is_std_format := false
	var decode_started_usec: int = Time.get_ticks_usec()
	var image_decode_ms: float = 0.0
	var resize_ms: float = 0.0
	var mipmap_ms: float = 0.0
	var source_width: int = 0
	var source_height: int = 0
	var output_width: int = 0
	var output_height: int = 0
	
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
	elif bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 \
			and bytes.size() >= 12 \
			and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
		pass # WebP 交给主线程处理，避免在 WorkerThreadPool 尝试解析动态 WebP 导致底层报错
			
	if is_std_format:
		image_decode_ms = float(Time.get_ticks_usec() - decode_started_usec) / 1000.0
		source_width = img.get_width()
		source_height = img.get_height()
		# Measure resize independently from codec decode and mipmap generation.
		var resize_started_usec: int = Time.get_ticks_usec()
		var longest_edge: int = maxi(source_width, source_height)
		if longest_edge > MAX_COVER_TEXTURE_EDGE:
			var resize_scale: float = float(MAX_COVER_TEXTURE_EDGE) / float(longest_edge)
			var resized_width: int = maxi(1, roundi(float(source_width) * resize_scale))
			var resized_height: int = maxi(1, roundi(float(source_height) * resize_scale))
			img.resize(resized_width, resized_height, Image.INTERPOLATE_LANCZOS)
		resize_ms = float(Time.get_ticks_usec() - resize_started_usec) / 1000.0
		output_width = img.get_width()
		output_height = img.get_height()
		var mipmap_started_usec: int = Time.get_ticks_usec()
		img.generate_mipmaps()
		mipmap_ms = float(Time.get_ticks_usec() - mipmap_started_usec) / 1000.0
		# Preserve the historical decode_ms meaning: total worker-side image preparation.
		var decode_ms: float = float(Time.get_ticks_usec() - decode_started_usec) / 1000.0
		call_deferred("_enqueue_cover_texture_apply", cover_rect, img, path, btn, queue_wait_ms, file_read_ms, decode_ms, image_decode_ms, resize_ms, mipmap_ms, source_width, source_height, output_width, output_height)
	else:
		# WebP/animated formats use the existing plugin path, but their main-thread application is queued too.
		call_deferred("_enqueue_cover_plugin_apply", cover_rect, path, btn, queue_wait_ms, file_read_ms, 0.0)

func _enqueue_cover_texture_apply(cover_rect: TextureRect, img: Image, path: String, btn: Button, queue_wait_ms: float, file_read_ms: float, decode_ms: float, image_decode_ms: float, resize_ms: float, mipmap_ms: float, source_width: int, source_height: int, output_width: int, output_height: int) -> void:
	_cover_apply_queue.append({
		"kind": "image",
		"cover_rect": cover_rect,
		"image": img,
		"path": path,
		"btn": btn,
		"queue_wait_ms": queue_wait_ms,
		"file_read_ms": file_read_ms,
		"decode_ms": decode_ms,
		"image_decode_ms": image_decode_ms,
		"resize_ms": resize_ms,
		"mipmap_ms": mipmap_ms,
		"source_width": source_width,
		"source_height": source_height,
		"output_width": output_width,
		"output_height": output_height,
		"generation": int(btn.get_meta("perf_cover_generation", -1)) if is_instance_valid(btn) else -1,
		"queued_usec": Time.get_ticks_usec(),
	})
	_perf_cover_apply_queue_peak = maxi(_perf_cover_apply_queue_peak, _cover_apply_queue.size())

func _enqueue_cover_plugin_apply(cover_rect: TextureRect, path: String, btn: Button, queue_wait_ms: float, file_read_ms: float, decode_ms: float) -> void:
	_cover_apply_queue.append({
		"kind": "plugin",
		"cover_rect": cover_rect,
		"path": path,
		"btn": btn,
		"queue_wait_ms": queue_wait_ms,
		"file_read_ms": file_read_ms,
		"decode_ms": decode_ms,
		"generation": int(btn.get_meta("perf_cover_generation", -1)) if is_instance_valid(btn) else -1,
		"queued_usec": Time.get_ticks_usec(),
	})
	_perf_cover_apply_queue_peak = maxi(_perf_cover_apply_queue_peak, _cover_apply_queue.size())

func _drain_cover_apply_queue() -> void:
	# At most one texture is created/applied per rendered frame. Worker decode stays parallel.
	for _apply_index in range(MAX_COVER_TEXTURE_APPLIES_PER_FRAME):
		if _cover_apply_queue.is_empty():
			return
		var item: Dictionary = _cover_apply_queue.pop_front()
		var kind: String = str(item.get("kind", "image"))
		var cover_rect: TextureRect = item.get("cover_rect")
		var path: String = str(item.get("path", ""))
		var btn: Button = item.get("btn")
		var queue_wait_ms: float = float(item.get("queue_wait_ms", 0.0))
		var file_read_ms: float = float(item.get("file_read_ms", 0.0))
		var decode_ms: float = float(item.get("decode_ms", 0.0))
		var image_decode_ms: float = float(item.get("image_decode_ms", 0.0))
		var resize_ms: float = float(item.get("resize_ms", 0.0))
		var mipmap_ms: float = float(item.get("mipmap_ms", 0.0))
		var source_width: int = int(item.get("source_width", 0))
		var source_height: int = int(item.get("source_height", 0))
		var output_width: int = int(item.get("output_width", 0))
		var output_height: int = int(item.get("output_height", 0))
		var item_generation: int = int(item.get("generation", -1))
		if item_generation != _perf_grid_generation or not is_instance_valid(cover_rect) or not is_instance_valid(btn):
			_perf_cover_finish_with_metrics(btn, false, queue_wait_ms, file_read_ms, decode_ms, 0.0)
			continue
		var apply_queue_wait_ms: float = float(Time.get_ticks_usec() - int(item.get("queued_usec", Time.get_ticks_usec()))) / 1000.0
		_perf_cover_apply_queue_wait_total_ms += apply_queue_wait_ms
		_perf_cover_apply_queue_wait_max_ms = maxf(_perf_cover_apply_queue_wait_max_ms, apply_queue_wait_ms)
		if kind == "plugin":
			_apply_cover_texture_plugin(cover_rect, path, btn, queue_wait_ms, file_read_ms, decode_ms)
		else:
			var img: Image = item.get("image")
			_apply_cover_texture(cover_rect, img, path, btn, queue_wait_ms, file_read_ms, decode_ms, image_decode_ms, resize_ms, mipmap_ms, source_width, source_height, output_width, output_height)

func _apply_cover_texture(cover_rect: TextureRect, img: Image, path: String, btn: Button, queue_wait_ms: float, file_read_ms: float, decode_ms: float, image_decode_ms: float, resize_ms: float, mipmap_ms: float, source_width: int, source_height: int, output_width: int, output_height: int) -> void:
	if not is_instance_valid(cover_rect):
		_perf_cover_finish_with_metrics(btn, false, queue_wait_ms, file_read_ms, decode_ms, 0.0)
		return
	var apply_started_usec: int = Time.get_ticks_usec()
	var texture_create_started_usec: int = Time.get_ticks_usec()
	var tex: Texture2D = ImageTexture.create_from_image(img)
	var texture_create_ms: float = float(Time.get_ticks_usec() - texture_create_started_usec) / 1000.0
	_cover_texture_cache[path] = tex  # 写入缓存
	var texture_assign_started_usec: int = Time.get_ticks_usec()
	cover_rect.texture = tex
	var texture_assign_ms: float = float(Time.get_ticks_usec() - texture_assign_started_usec) / 1000.0
	btn.set_meta("cover_loaded", true)
	var reveal_request_started_usec: int = Time.get_ticks_usec()
	_request_cover_reveal_after_apply()
	var reveal_request_ms: float = float(Time.get_ticks_usec() - reveal_request_started_usec) / 1000.0
	var apply_ms: float = float(Time.get_ticks_usec() - apply_started_usec) / 1000.0
	_perf_cover_finish_with_metrics(btn, true, queue_wait_ms, file_read_ms, decode_ms, apply_ms, image_decode_ms, resize_ms, mipmap_ms, source_width, source_height, output_width, output_height, texture_create_ms, texture_assign_ms, 0.0, reveal_request_ms)

func _apply_cover_texture_plugin(cover_rect: TextureRect, path: String, btn: Button, queue_wait_ms: float, file_read_ms: float, decode_ms: float) -> void:
	if not is_instance_valid(cover_rect) or not is_instance_valid(btn):
		_perf_cover_finish_with_metrics(btn, false, queue_wait_ms, file_read_ms, decode_ms, 0.0)
		return
	var plugin_load_started_usec: int = Time.get_ticks_usec()
	if ClassDB.class_exists(&"AnimatedImageLoader") and ClassDB.class_has_method(&"AnimatedImageLoader", &"load_from_file_async"):
		var callback: Callable = _on_cover_plugin_loaded.bind(cover_rect, path, btn, queue_wait_ms, file_read_ms, decode_ms, plugin_load_started_usec)
		ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_file_async", path, callback)
		return
	# Compatibility fallback for older extension builds without the asynchronous API.
	var tex: Texture2D = _load_animated_poster(path)
	var plugin_load_elapsed_ms: float = float(Time.get_ticks_usec() - plugin_load_started_usec) / 1000.0
	_finish_cover_plugin_apply(tex, cover_rect, path, btn, queue_wait_ms, file_read_ms, decode_ms, plugin_load_elapsed_ms, plugin_load_elapsed_ms)

func _on_cover_plugin_loaded(loaded_resource: Variant, cover_rect: TextureRect, path: String, btn: Button, queue_wait_ms: float, file_read_ms: float, decode_ms: float, plugin_load_started_usec: int) -> void:
	var plugin_load_elapsed_ms: float = float(Time.get_ticks_usec() - plugin_load_started_usec) / 1000.0
	if not is_instance_valid(cover_rect) or not is_instance_valid(btn) or int(btn.get_meta("perf_cover_generation", -1)) != _perf_grid_generation:
		_perf_cover_finish_with_metrics(btn, false, queue_wait_ms, file_read_ms, decode_ms, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, plugin_load_elapsed_ms)
		return
	var tex: Texture2D = _extract_cover_poster_texture(loaded_resource)
	var sync_fallback_ms: float = 0.0
	if tex == null:
		# Rare compatibility fallback if async decoding cannot produce a poster.
		var fallback_started_usec: int = Time.get_ticks_usec()
		tex = _load_animated_poster(path)
		sync_fallback_ms = float(Time.get_ticks_usec() - fallback_started_usec) / 1000.0
		plugin_load_elapsed_ms = float(Time.get_ticks_usec() - plugin_load_started_usec) / 1000.0
	_finish_cover_plugin_apply(tex, cover_rect, path, btn, queue_wait_ms, file_read_ms, decode_ms, plugin_load_elapsed_ms, sync_fallback_ms)

func _extract_cover_poster_texture(loaded_resource: Variant) -> Texture2D:
	if loaded_resource == null or not (loaded_resource is Object):
		return null
	var loaded_object: Object = loaded_resource
	if loaded_object.has_method("get_poster_texture"):
		var poster: Texture2D = loaded_object.call("get_poster_texture") as Texture2D
		if poster != null:
			return poster
	if loaded_object.has_method("get_frame_texture"):
		var first_frame: Texture2D = loaded_object.call("get_frame_texture", 0) as Texture2D
		if first_frame != null:
			return first_frame
	return loaded_resource as Texture2D

func _finish_cover_plugin_apply(tex: Texture2D, cover_rect: TextureRect, path: String, btn: Button, queue_wait_ms: float, file_read_ms: float, decode_ms: float, plugin_load_elapsed_ms: float, sync_fallback_ms: float = 0.0) -> void:
	if not is_instance_valid(cover_rect) or not is_instance_valid(btn):
		_perf_cover_finish_with_metrics(btn, false, queue_wait_ms, file_read_ms, decode_ms, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, plugin_load_elapsed_ms)
		return
	var apply_started_usec: int = Time.get_ticks_usec()
	var perf_cover_loaded: bool = tex != null
	var texture_create_ms: float = 0.0
	if tex == null:
		# 兜底：插件与原生解码均失败时，生成占位纹理防止卡片空白
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.15, 0.18, 0.22, 1.0))
		var texture_create_started_usec: int = Time.get_ticks_usec()
		tex = ImageTexture.create_from_image(img)
		texture_create_ms = float(Time.get_ticks_usec() - texture_create_started_usec) / 1000.0
	_cover_texture_cache[path] = tex
	var texture_assign_started_usec: int = Time.get_ticks_usec()
	cover_rect.texture = tex
	var texture_assign_ms: float = float(Time.get_ticks_usec() - texture_assign_started_usec) / 1000.0
	btn.set_meta("cover_loaded", true)
	var reveal_request_started_usec: int = Time.get_ticks_usec()
	_request_cover_reveal_after_apply()
	var reveal_request_ms: float = float(Time.get_ticks_usec() - reveal_request_started_usec) / 1000.0
	var apply_ms: float = sync_fallback_ms + float(Time.get_ticks_usec() - apply_started_usec) / 1000.0
	_perf_cover_finish_with_metrics(btn, perf_cover_loaded, queue_wait_ms, file_read_ms, decode_ms, apply_ms, 0.0, 0.0, 0.0, 0, 0, 0, 0, texture_create_ms, texture_assign_ms, 0.0, reveal_request_ms, plugin_load_elapsed_ms)

func _request_cover_reveal_after_apply() -> void:
	# Give the first GPU texture upload a frame of separation before the first visible tween starts.
	if not _cover_first_reveal_frame_separated and _cover_reveals_pending == 0 and _anim_audit_active_reveals == 0:
		_cover_first_reveal_frame_separated = true
		_cover_reveal_deferred_to_process = true
		return
	_reveal_visible_loaded_covers()

func _perf_cover_finish_with_metrics(btn: Button, loaded: bool, queue_wait_ms: float, file_read_ms: float, decode_ms: float, apply_ms: float, image_decode_ms: float = 0.0, resize_ms: float = 0.0, mipmap_ms: float = 0.0, source_width: int = 0, source_height: int = 0, output_width: int = 0, output_height: int = 0, texture_create_ms: float = 0.0, texture_assign_ms: float = 0.0, animated_check_ms: float = 0.0, reveal_request_ms: float = 0.0, plugin_load_elapsed_ms: float = 0.0) -> void:
	if not is_instance_valid(btn) or int(btn.get_meta("perf_cover_generation", -1)) != _perf_grid_generation:
		_perf_cover_finished(btn, loaded)
		return
	_perf_cover_samples += 1
	_perf_cover_queue_wait_total_ms += queue_wait_ms
	_perf_cover_queue_wait_max_ms = maxf(_perf_cover_queue_wait_max_ms, queue_wait_ms)
	_perf_cover_file_read_total_ms += file_read_ms
	_perf_cover_file_read_max_ms = maxf(_perf_cover_file_read_max_ms, file_read_ms)
	_perf_cover_decode_total_ms += decode_ms
	_perf_cover_decode_max_ms = maxf(_perf_cover_decode_max_ms, decode_ms)
	_perf_cover_apply_total_ms += apply_ms
	_perf_cover_apply_max_ms = maxf(_perf_cover_apply_max_ms, apply_ms)
	_perf_cover_image_decode_total_ms += image_decode_ms
	_perf_cover_image_decode_max_ms = maxf(_perf_cover_image_decode_max_ms, image_decode_ms)
	_perf_cover_resize_total_ms += resize_ms
	_perf_cover_resize_max_ms = maxf(_perf_cover_resize_max_ms, resize_ms)
	_perf_cover_mipmap_total_ms += mipmap_ms
	_perf_cover_mipmap_max_ms = maxf(_perf_cover_mipmap_max_ms, mipmap_ms)
	_perf_cover_texture_create_total_ms += texture_create_ms
	_perf_cover_texture_create_max_ms = maxf(_perf_cover_texture_create_max_ms, texture_create_ms)
	_perf_cover_texture_assign_total_ms += texture_assign_ms
	_perf_cover_texture_assign_max_ms = maxf(_perf_cover_texture_assign_max_ms, texture_assign_ms)
	_perf_cover_animated_check_total_ms += animated_check_ms
	_perf_cover_animated_check_max_ms = maxf(_perf_cover_animated_check_max_ms, animated_check_ms)
	_perf_cover_reveal_request_total_ms += reveal_request_ms
	_perf_cover_reveal_request_max_ms = maxf(_perf_cover_reveal_request_max_ms, reveal_request_ms)
	_perf_cover_plugin_load_elapsed_total_ms += plugin_load_elapsed_ms
	_perf_cover_plugin_load_elapsed_max_ms = maxf(_perf_cover_plugin_load_elapsed_max_ms, plugin_load_elapsed_ms)
	if source_width > 0 and source_height > 0 and output_width > 0 and output_height > 0:
		_perf_cover_decoded_image_samples += 1
		_perf_cover_source_pixels_total += source_width * source_height
		_perf_cover_output_pixels_total += output_width * output_height
		if source_width != output_width or source_height != output_height:
			_perf_cover_resized_count += 1
	var slow_stage_ms: float = maxf(file_read_ms, maxf(decode_ms, maxf(apply_ms, maxf(image_decode_ms, maxf(resize_ms, maxf(mipmap_ms, maxf(texture_create_ms, maxf(texture_assign_ms, maxf(animated_check_ms, reveal_request_ms)))))))))
	if _perf_cover_stage_detail_logs < 8 and (_perf_cover_samples <= 3 or slow_stage_ms >= 12.0):
		_perf_cover_stage_detail_logs += 1
	_perf_cover_finished(btn, loaded)

func _perf_cover_finished(btn: Button, loaded: bool) -> void:
	_active_cover_loads = maxi(0, _active_cover_loads - 1)
	_pump_cover_load_queue()
	if not is_instance_valid(btn):
		return
	btn.set_meta("cover_load_pending", false)
	if int(btn.get_meta("perf_cover_generation", -1)) != _perf_grid_generation:
		return
	if not loaded and not bool(btn.get_meta("cover_loaded", false)):
		var failed_wrapper: Control = btn.get_meta("wrapper", null)
		if is_instance_valid(failed_wrapper):
			failed_wrapper.modulate.a = 1.0
			btn.set_meta("cover_reveal_started", true)
	_perf_grid_async_pending = maxi(0, _perf_grid_async_pending - 1)
	if loaded and not _perf_grid_first_cover_logged:
		_perf_grid_first_cover_logged = true

	_try_enable_card_springs()

func _check_animated(path: String, btn: Button) -> void:
	var ext: String = path.get_extension().to_lower()
	if ext != "webp" and ext != "gif" and ext != "apng":
		return
	if _animated_probe_cache.has(path):
		if bool(_animated_probe_cache[path]):
			btn.set_meta("anim_path", path)
		return
	var is_animated: bool = false
	if ClassDB.class_exists(&"AnimatedImageLoader"):
		var info = ClassDB.class_call_static(&"AnimatedImageLoader", &"probe_file", path)
		if info != null:
			is_animated = bool(info.get("animated", false))
	_animated_probe_cache[path] = is_animated
	if is_animated:
		btn.set_meta("anim_path", path)
