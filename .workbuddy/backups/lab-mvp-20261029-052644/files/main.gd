extends Node
const WINDOW_POLICY_SCRIPT: Script = preload("res://scripts/window_policy.gd")


const BACKEND_CLIENT_SCRIPT: Script = preload("res://scripts/backend_client.gd")
const BACKEND_ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")
const AUDIO_LOADER: Script = preload("res://scripts/audio_file_loader.gd")
const NAVIGATION_DRAWER_SCRIPT: Script = preload("res://scripts/navigation_drawer.gd")
const WINDOW_CHROME_SCRIPT: Script = preload("res://scripts/window_chrome.gd")
const GAME_AMBIENT_SHADER: Shader = preload("res://shaders/game_ambient.gdshader")
const WORLD_SCENE_BUILDER_SCRIPT: Script = preload("res://scripts/world_scene_builder.gd")
const LOCAL_STARTUP_SETTINGS_READER_SCRIPT: Script = preload("res://scripts/local_startup_settings_reader.gd")
const THEME_POLICY_SCRIPT: Script = preload("res://scripts/theme_policy.gd")
const GAME_BLANK_MENU_SCRIPT: Script = preload("res://scripts/game_blank_menu.gd")
const GAME_DIALOG_ASSEMBLY_BUILDER_SCRIPT: Script = preload("res://scripts/game_dialog_assembly_builder.gd")
const MOVIE_WALL_SCRIPT: Script = preload("res://scripts/movie_wall.gd")
const MOVIE_INFO_VIEW_BUILDER_SCRIPT: Script = preload("res://scripts/movie_info_view_builder.gd")
const MOVIE_BOTTOM_OVERLAY_BUILDER_SCRIPT: Script = preload("res://scripts/movie_bottom_overlay_builder.gd")
const MOVIE_DIALOG_ASSEMBLY_BUILDER_SCRIPT: Script = preload("res://scripts/movie_dialog_assembly_builder.gd")
const GAME_SECTION_SCRIPT: Script = preload("res://scripts/game_section.gd")
const ARCHIVE_GALLERY_SCRIPT: Script = preload("res://scripts/archive_gallery.gd")
const MOVIE_CREATE_DIALOG_SCRIPT: Script = preload("res://scripts/movie_create_dialog.gd")
const MOVIE_MANAGE_MENU_SCRIPT: Script = preload("res://scripts/movie_manage_menu.gd")
const MOVIE_BLANK_MENU_SCRIPT: Script = preload("res://scripts/movie_blank_menu.gd")
const MOVIE_METADATA_DIALOG_SCRIPT: Script = preload("res://scripts/movie_metadata_dialog.gd")
const MOVIE_EPISODE_DRAWER_SCRIPT: Script = preload("res://scripts/movie_episode_drawer.gd")
const TMDB_DIALOG_SCRIPT: Script = preload("res://scripts/tmdb_search_dialog.gd")
const TMDB_POSTER_DIALOG_SCRIPT: Script = preload("res://scripts/tmdb_poster_dialog.gd")
const LIBRARY_SCAN_CONTROLLER_SCRIPT: Script = preload("res://scripts/library_scan_controller.gd")
const LIBRARY_SCAN_PRESENTATION_SCRIPT: Script = preload("res://scripts/library_scan_presentation.gd")
const LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT: Script = preload("res://scripts/library_scan_import_payload_builder.gd")
const GAME_PASTE_PAYLOAD_BUILDER_SCRIPT: Script = preload("res://scripts/game_paste_payload_builder.gd")
const MOVIE_CONTROLLER_SCRIPT: Script = preload("res://scripts/movie_controller.gd")
const GAME_CONTROLLER_SCRIPT: Script = preload("res://scripts/game_controller.gd")
const GAME_THEME_CONTROLLER_SCRIPT: Script = preload("res://scripts/game_theme_controller.gd")
const SYSTEM_SETTINGS_CONTROLLER_SCRIPT: Script = preload("res://scripts/system_settings_controller.gd")
const COVER_TOOL_CONTROLLER_SCRIPT: Script = preload("res://scripts/cover_tool_controller.gd")
const COVER_TOOL_PRESENTATION_SCRIPT: Script = preload("res://scripts/cover_tool_presentation.gd")
const EMULATOR_CONTROLLER_SCRIPT: Script = preload("res://scripts/emulator_controller.gd")
const RENDER_OWNERSHIP_SCRIPT: Script = preload("res://scripts/render_ownership_coordinator.gd")
const STEAM_BATCH_SCRAPE_COORDINATOR_SCRIPT: Script = preload("res://scripts/steam_batch_scrape_coordinator.gd")
const FONT_MANAGER_SCRIPT: Script = preload("res://scripts/font_manager.gd")
const FONTSET_EDITOR_SCRIPT: Script = preload("res://scripts/fontset_editor.gd")
const FONTSET_OVERVIEW_BUILDER_SCRIPT: Script = preload("res://scripts/fontset_overview_builder.gd")
const SYSTEM_HOME_VIEW_BUILDER_SCRIPT: Script = preload("res://scripts/system_home_view_builder.gd")
const COVER_TOOL_DIALOG_SCRIPT: Script = preload("res://scripts/cover_tool_dialog.gd")
const COVER_CROP_DIALOG_SCRIPT: Script = preload("res://scripts/cover_crop_dialog.gd")
const EMULATOR_EDIT_DIALOG_SCRIPT: Script = preload("res://scripts/emulator_edit_dialog.gd")
const EMULATOR_LIST_VIEW_BUILDER_SCRIPT: Script = preload("res://scripts/emulator_list_view_builder.gd")
const MOVIE_LIBRARY_SETTINGS_VIEW_BUILDER_SCRIPT: Script = preload("res://scripts/movie_library_settings_view_builder.gd")
const REMOVE_CONFIRMATION_PRESENTER_SCRIPT: Script = preload("res://scripts/remove_confirmation_presenter.gd")

const XMB_SECTIONS: Array[String] = ["GAMES", "MOVIES", "COMICS", "MUSIC", "SYSTEM"]
const GAME_PLATFORMS: Array[String] = [
	"PC", "Steam", "GOG", "Epic","Rockstar", "Uplay",
	"PS1", "PS2", "PS3", "PS4", "PS5",
	"PSP", "PS Vita",
	"Xbox", "Xbox 360", "Xbox One", "Xbox Series",
	"FC", "SFC", "N64", "NGC", "Wii", "Wii U", "Switch",
	"GB", "GBC", "GBA", "NDS", "3DS",
	"MD", "SS", "DC",
	"Arcade", "其他",
]
const XMB_SECTION_LABELS: Array[String] = ["游戏", "电影", "试验场", "游戏藏品室", "系统"]
const RUNTIME_MESSAGE_HOLD_SECONDS: float = 4.0
const RUNTIME_MESSAGE_FADE_SECONDS: float = 0.35
# 启动遮幕：颜色必须与 project.godot 的 application/boot_splash/bg_color 完全一致，
# 首帧才能与 Boot Splash 无缝衔接。当前取 GAMES 分区背景底色。
const STARTUP_VEIL_COLOR: Color = Color(0.055, 0.070, 0.095, 1.0)
const STARTUP_VEIL_FADE_SECONDS: float = 0.45
# 启动图标：路径与栅格化参数集中在此，替换为 G3 原创 ICON 时只改这两项。
# 当前复用 assets 中已有的彩色 PlayStation 标志，仅作本地临时占位，
# 不作为 G3 正式品牌资产，也不用于公开发行版本。
const STARTUP_ICON_PATH: String = "res://assets/icons/platforms/playstation-logo-colour.svg"
const STARTUP_ICON_RASTER_SCALE: float = 0.16
const STARTUP_ICON_SIZE: Vector2 = Vector2(180.0, 136.0)
# 启动图标三阶段时间轴：进场 → 停留 → 退场。
# 遮幕在这整整一段时间内保持完全不透明，退场结束后才开始原有的 0.45s 淡出，
# 因此主界面不会在图标还在的时候提前透出来。调时长只改下面这几个数。
const STARTUP_ICON_ENTER_SECONDS: float = 0.30   # 0.00 → 0.30：淡入 + 轻微放大
const STARTUP_ICON_HOLD_SECONDS: float = 0.60    # 0.30 → 0.90：完整停留
const STARTUP_ICON_EXIT_SECONDS: float = 0.30    # 0.90 → 1.20：淡出 + 轻微放大
const STARTUP_ICON_START_SCALE: float = 0.85     # 进场起点缩放
const STARTUP_ICON_EXIT_SCALE: float = 1.08      # 退场终点缩放
# 图标动画总时长 = 遮幕开始淡出的延迟；改这三个时间会自动跟着变。
const STARTUP_ICON_TOTAL_SECONDS: float = STARTUP_ICON_ENTER_SECONDS + STARTUP_ICON_HOLD_SECONDS + STARTUP_ICON_EXIT_SECONDS

# ============================================================
# 电影信息区布局（调这里就对了）
# ============================================================

const TARGET_WINDOW_ASPECT: float = 16.0 / 9.0

# 信息区左边界：屏幕宽度的百分之多少（0.33 = 屏幕 33% 处开始）
# 信息区右边界：屏幕右侧留多少像素
# 标题固定位置：屏幕高度的百分之多少（不随预览图高度变化）
# 简介固定位置：距屏幕底部留多少比例
# 年份距标题上方多少像素
# 简介下方保留多少像素（给导航抽屉）
# 右下角热区
const BOTTOM_HOT_ZONE_WIDTH: float = 220.0
const BOTTOM_HOT_ZONE_HEIGHT: float = 140.0
# 隐藏层高度（信息区上滑多少）
const HIDDEN_LAYER_HEIGHT: float = 160.0
# 箭头淡入灵敏度
const ARROW_FADE_SPEED: float = 8.0
# 系统页：以 1600×900 为设计基准，整块 panel 等比缩放
const SYSTEM_BASE_SIZE: Vector2 = Vector2(1600.0, 900.0)
const SYSTEM_BASE_POS: Vector2 = Vector2(78.0, 90.0)
const SYSTEM_BASE_WIDTH: float = 768.0
# 系统页内容占窗口宽度的比例
const SYSTEM_PANEL_WIDTH_RATIO: float = 0.48
# 布局设计基准分辨率（所有位置和字号都是按这个尺寸定的）
const UI_BASE_WIDTH: float = 1600.0
const UI_BASE_HEIGHT: float = 900.0
# ============================================================

var backend
# Temporary startup/list timing diagnostics. Remove after a baseline run.
var _perf_backend_connect_started_msec: int = -1
var _perf_games_list_request_started_msec: int = -1
var _perf_movies_list_request_started_msec: int = -1
var _backend_router
var _library_scan_controller
var _library_scan_presentation: Node
var _movie_controller
var _game_controller
var _game_theme_controller: Node = null
var _system_settings_controller
var _cover_tool_controller
var _cover_tool_presentation
var _emulator_controller
var _render_ownership: Node
var _steam_batch_scrape_coordinator: Node
var collection_world: Node3D
var camera: Camera3D
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var _game_ambient_mesh: MeshInstance3D
var movie_wall
var game_section = null
var archive_gallery = null
var game_blank_menu
var game_create_dialog
var game_paste_import_dialog
var game_scraper_dialog
var steam_search_dialog
var game_manage_menu
var _game_menu_target: Dictionary = {}
var game_metadata_dialog
var game_launch_dialog
var game_remove_confirm: ConfirmationDialog
var playtime_edit_dialog
var emulator_edit_dialog
var emulator_remove_confirm: ConfirmationDialog
var _emulator_list: VBoxContainer
var _emulators: Array = []
var _emulator_remove_target: String = ""
var _emulator_remove_title: String = ""
# 合并后的「扫描游戏库」对话框（5 个 tab）
var library_scan_dialog
var xmb_root: Control
var navigation_drawer
var window_chrome
var default_section_option: OptionButton
var window_mode_option: OptionButton
var section_index: int = 0
var backend_label: Label
var fps_label: Label
var runtime_error_label: Label
var hint_label: Label
var placeholder_label: Label
var system_root: Control
var system_panel: VBoxContainer
var system_pad: MarginContainer
var system_editor_root_ref: VBoxContainer
var _last_window_mode: int = -1
var theme_music_player: AudioStreamPlayer
var _theme_ids: Array[String] = []
var theme_option: OptionButton
var _restore_movie_id: String = ""
var _movies_ready: bool = false
var _state_ready: bool = false
var _fps_accum: float = 0.0
var _theme_music_base_volume: float = 0.35
var _theme_music_enabled: bool = true
var _current_theme: Dictionary = {}
var _theme_text: Color = Color(0.93, 1.0, 1.0, 1.0)
var _theme_muted: Color = Color(0.55, 0.70, 0.72, 1.0)
var _theme_accent: Color = Color(0.20, 0.82, 0.76, 1.0)
var _theme_base_top: Color = Color(0.05, 0.28, 0.32, 1.0)
var _runtime_message_tween: Tween
var _runtime_message_generation: int = 0
var _app_version_label: Label
var fontset_option: OptionButton                # 电影字体组别下拉
var fontset_option_games: OptionButton          # 游戏字体组别下拉
var _fontset_ids: Array[String] = []            # 电影组别 id
var _fontset_ids_games: Array[String] = []      # 游戏组别 id
var movie_info_title: Label
var movie_info_meta: Label
var movie_info_genres: Label
var movie_desc_scroll: ScrollContainer
var movie_desc_label: Label
var movie_create_dialog
var movie_manage_menu
var movie_blank_menu
var _movie_menu_target: Dictionary = {}
var _selected_movie: Dictionary = {}
var _current_movie_scope: String = "main"
var movie_remove_confirm: ConfirmationDialog
var movie_cover_file_dialog: FileDialog
var movie_metadata_dialog
var movie_episode_drawer
var _episode_drawer_generation: int = 0
var movie_backdrop_file_dialog: FileDialog
var _last_drawer_rect: Rect2 = Rect2()
var _movie_library_paths: Array[String] = []
var _movie_library_paths_private: Array[String] = []
var movie_lib_paths_list: VBoxContainer
var _lib_title_label: Label
var _movie_cover_folder_main: String = ""
var _movie_cover_folder_private: String = ""
var _cover_folder_label: Label
var _cover_folder_title: Label
var movie_cover_dir_dialog: FileDialog
var cover_crop_dialog
var cover_tool_dialog
var movie_lib_dir_dialog: FileDialog
var _section_fade: ColorRect
var _section_ready: bool = false
var _pending_section: int = -1
var tmdb_dialog
var tmdb_poster_dialog
var _bottom_hot_zone: Control
var _bottom_arrow: Label
var _hidden_layer: Control
var _info_offset: float = 0.0
var _info_offset_target: float = 0.0
var _info_expanded: bool = false
var _hidden_tagline: Label
var font_manager
var _ui_root: Control
var _fontset_id: String = "default"                 # 电影字体组别
var _fontset_id_games: String = "default"           # 游戏字体组别
var fontset_editor
var _fontset_editor_scope: String = "movies"        # 编辑器当前 scope
var fontset_entry_btn: Button                       # 主系统页"字体组别…"入口
var fontset_home_root: VBoxContainer                # 字体组别总览页
var system_home_root: VBoxContainer
var _fontset_editor_open: bool = false
var _system_fonts: Array = []
var _animated_image_extension: Resource

func _ready() -> void:
	var perf_startup_started_msec: int = Time.get_ticks_msec()
	var perf_stage_started_msec: int = perf_startup_started_msec
	var app_window := get_window()
	if app_window != null:
		# 启动几何尺寸由 project.godot 的 override 决定（1244x700 居中），
		# 这里只固定下限与内容缩放，不再改动窗口大小。
		app_window.min_size = Vector2i(1244, 700)
		app_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		app_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		app_window.mouse_passthrough = false
		app_window.always_on_top = false
		call_deferred("_apply_startup_window_mode")
	# 独立运行时不会自动执行 EditorPlugin，需要显式加载 GDExtension。
	_animated_image_extension = load(
		"res://addons/godot_animated_image/bin/godot_animated_image.gdextension"
	)

	if _animated_image_extension == null or not ClassDB.class_exists(&"AnimatedImageLoader"):
		push_error("G3：动态图片扩展加载失败，WebP 封面无法正常解码。")		
	perf_stage_started_msec = Time.get_ticks_msec()
	_build_3d_world()
	perf_stage_started_msec = Time.get_ticks_msec()
	_build_ui()
	perf_stage_started_msec = Time.get_ticks_msec()
	_build_backend()
	perf_stage_started_msec = Time.get_ticks_msec()
	_set_section(_read_local_start_section())
	_section_ready = true
	_perf_backend_connect_started_msec = Time.get_ticks_msec()
	backend.connect_backend()
	set_process(true)
	call_deferred("_layout_system_panel")
	get_window().size_changed.connect(_on_window_resized)
	_start_startup_veil()


## 启动遮幕：先以完全不透明的纯色盖住窗口（该帧即为首帧），
## 等首帧真正绘制完成后再淡出，避免 Boot Splash 被整帧替换。
func _start_startup_veil() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var veil: ColorRect = ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = STARTUP_VEIL_COLOR

	# 图标挂在遮幕之上、同一层内，随遮幕一起被 queue_free() 回收。
	# 初始 alpha 为 0，首帧仍是纯色遮幕，不破坏既有首帧验收结论。
	var icon: TextureRect = _build_startup_icon(layer)

	# 遮幕必须先随首帧一起画完，再启动 Tween；
	# 否则 Tween 会在同一帧内推进，首帧就变成半透明，等于露出完整 UI。
	await RenderingServer.frame_post_draw

	# 启动音与图标进场同刻起音：本行位于首帧绘制完成之后、图标 Tween 创建之前，
	# 不引入任何等待，也不改变既有视觉时间轴。音效关闭或素材缺失时 play() 静默返回。
	UISfx.play(&"boot", true)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# 遮幕延迟到图标三阶段全部结束才开始淡出；图标缺失时不留空等。
	var veil_delay: float = STARTUP_ICON_TOTAL_SECONDS if icon != null else 0.0
	tween.tween_property(veil, "color:a", 0.0, STARTUP_VEIL_FADE_SECONDS).set_delay(veil_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if icon != null:
		# 进场 0.00→0.30s：透明度 0→1，缩放 0.85→1.00。
		tween.tween_property(icon, "modulate:a", 1.0, STARTUP_ICON_ENTER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "scale", Vector2.ONE, STARTUP_ICON_ENTER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# 停留 0.30→0.90s：不挂 Tween，靠退场的 delay 保持完整显示。
		# 退场 0.90→1.20s：透明度 1→0，缩放 1.00→1.08，与进场同曲线反向。
		var icon_exit_delay: float = STARTUP_ICON_ENTER_SECONDS + STARTUP_ICON_HOLD_SECONDS
		tween.tween_property(icon, "modulate:a", 0.0, STARTUP_ICON_EXIT_SECONDS).set_delay(icon_exit_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "scale", Vector2.ONE * STARTUP_ICON_EXIT_SCALE, STARTUP_ICON_EXIT_SECONDS).set_delay(icon_exit_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(layer.queue_free)


## 启动图标：把 assets 中已有的彩色 PlayStation 标志栅格化为纹理并居中摆放。
## 与 game_detail_view 保持一致，不走 ResourceLoader.load() 直读原始 SVG。
func _build_startup_icon(layer: CanvasLayer) -> TextureRect:
	if not FileAccess.file_exists(STARTUP_ICON_PATH):
		return null
	var svg_bytes: PackedByteArray = FileAccess.get_file_as_bytes(STARTUP_ICON_PATH)
	if svg_bytes.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_svg_from_buffer(svg_bytes, STARTUP_ICON_RASTER_SCALE) != OK:
		return null
	image.generate_mipmaps()

	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon: TextureRect = TextureRect.new()
	icon.texture = ImageTexture.create_from_image(image)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = STARTUP_ICON_SIZE
	icon.pivot_offset = STARTUP_ICON_SIZE * 0.5
	icon.scale = Vector2(STARTUP_ICON_START_SCALE, STARTUP_ICON_START_SCALE)
	icon.modulate.a = 0.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	return icon


func _read_local_window_mode() -> String:
	return LOCAL_STARTUP_SETTINGS_READER_SCRIPT.read_window_mode()

func _apply_startup_window_mode() -> void:
	# 启动阶段只在保存模式为全屏时切换模式；窗口模式不做任何 resize，
	# 尺寸与居中已由 project.godot 的 override 与引擎初始位置决定。
	if _read_local_window_mode() == "fullscreen":
		_apply_window_mode("fullscreen")
	else:
		_on_window_mode_changed()

func _apply_window_mode(mode: String) -> void:
	var win := get_window()
	if win == null:
		return
	WINDOW_POLICY_SCRIPT.apply_mode(mode, win)
	if mode != "fullscreen":
		call_deferred("_set_windowed_size")
	_on_window_mode_changed()

func _set_windowed_size() -> void:
	var win := get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return
	win.size = Vector2i(1244, 700)
	win.position = WINDOW_POLICY_SCRIPT.centered_position(DisplayServer.screen_get_size())

func _on_window_mode_changed() -> void:
	var win := get_window()
	if win == null:
		return
	WINDOW_POLICY_SCRIPT.apply_chrome_visibility(win, window_chrome)

func _read_local_start_section() -> int:
	return LOCAL_STARTUP_SETTINGS_READER_SCRIPT.read_start_section(XMB_SECTIONS)

func _build_3d_world() -> void:
	var scene_nodes: Dictionary = WORLD_SCENE_BUILDER_SCRIPT.build(self, GAME_AMBIENT_SHADER, _theme_accent)
	collection_world = scene_nodes["world"]
	camera = scene_nodes["camera"]
	key_light = scene_nodes["key_light"]
	fill_light = scene_nodes["fill_light"]
	rim_light = scene_nodes["rim_light"]
	_game_ambient_mesh = scene_nodes["ambient_mesh"]
	_resize_game_ambient()
	get_viewport().size_changed.connect(_resize_game_ambient)

	movie_wall = MOVIE_WALL_SCRIPT.new()
	collection_world.add_child(movie_wall)
	movie_wall.configure(camera)
	movie_wall.selection_changed.connect(_on_movie_selection_changed)
	movie_wall.main_case_right_clicked.connect(_on_movie_right_clicked)
	movie_wall.main_case_double_clicked.connect(_on_movie_double_clicked)
	movie_wall.visible = false

	game_section = GAME_SECTION_SCRIPT.new()
	collection_world.add_child(game_section)
	game_section.configure(camera)
	game_section.game_double_clicked.connect(_on_game_double_clicked)
	game_section.game_theme_requested.connect(_on_game_theme_requested)
	game_section.game_theme_cleared.connect(_on_game_theme_cleared)
	game_section.add_game_requested.connect(_on_add_game_requested)
	game_section.game_context_requested.connect(_on_game_context_requested)
	game_section.blank_context_requested.connect(_on_game_blank_context_requested)
	game_section.game_removed.connect(_on_game_batch_remove)
	game_section.batch_scrape_requested.connect(_on_batch_scrape_requested)
	# UI 音效：只订阅 game_section 新增的专用进/出信号，
	# 不复用 game_theme_cleared（它在"进入无主题 ID 的游戏"时也会发射）。
	game_section.detail_entered.connect(_on_detail_entered)
	game_section.detail_exited.connect(_on_detail_exited)

	archive_gallery = ARCHIVE_GALLERY_SCRIPT.new()
	archive_gallery.name = "ArchiveGallery"
	collection_world.add_child(archive_gallery)
	archive_gallery.configure(camera)
	archive_gallery.game_launch_requested.connect(_on_archive_launch_requested)

func _resize_game_ambient() -> void:
	if _game_ambient_mesh == null or camera == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return
	var quad: QuadMesh = _game_ambient_mesh.mesh as QuadMesh
	quad.size = WORLD_SCENE_BUILDER_SCRIPT.quad_size(vp, camera.fov, camera.global_position.z, _game_ambient_mesh.global_position.z)

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var ui: Control = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_ui_root = ui

	font_manager = FONT_MANAGER_SCRIPT.new()
	add_child(font_manager)
	# 游戏板块在 _ui_root 子树外（自建 CanvasLayer），显式把引用传进去
	if game_section != null:
		game_section.set_font_manager(font_manager)
	if archive_gallery != null:
		archive_gallery.set_font_manager(font_manager)

	xmb_root = Control.new()
	xmb_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xmb_root.visible = false
	ui.add_child(xmb_root)
	var x: float = 62.0
	for i: int in range(XMB_SECTIONS.size()):
		var button: Button = Button.new()
		button.position = Vector2(x, 46.0)
		button.size = Vector2(144.0, 48.0)
		button.text = XMB_SECTION_LABELS[i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_xmb_pressed.bind(i))
		xmb_root.add_child(button)
		x += 148.0

	backend_label = Label.new()
	backend_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	backend_label.position = Vector2(-340.0, 60.0)
	backend_label.size = Vector2(220.0, 28.0)
	backend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	backend_label.text = "后端连接中"
	backend_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(backend_label)

	fps_label = Label.new()
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-110.0, 60.0)
	fps_label.size = Vector2(72.0, 28.0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(fps_label)

	runtime_error_label = Label.new()
	runtime_error_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	runtime_error_label.position = Vector2(48.0, 52.0)
	runtime_error_label.size = Vector2(700.0, 40.0)
	runtime_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	runtime_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	runtime_error_label.add_theme_font_size_override("font_size", 13)
	runtime_error_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.52))
	runtime_error_label.visible = false
	runtime_error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(runtime_error_label)

	theme_music_player = AudioStreamPlayer.new()
	add_child(theme_music_player)

	placeholder_label = Label.new()
	placeholder_label.position = Vector2(78.0, 240.0)
	placeholder_label.size = Vector2(980.0, 100.0)
	placeholder_label.add_theme_font_size_override("font_size", 20)
	placeholder_label.add_theme_color_override("font_color", _theme_muted)
	placeholder_label.visible = false
	ui.add_child(placeholder_label)

	# ── 系统页 ──
	system_root = Control.new()
	system_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	system_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	system_root.visible = false
	ui.add_child(system_root)

	var system_scroll := ScrollContainer.new()
	system_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	system_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	system_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	system_root.add_child(system_scroll)

	var system_center := CenterContainer.new()
	system_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	system_scroll.add_child(system_center)

	system_pad = MarginContainer.new()
	system_pad.custom_minimum_size.x = SYSTEM_BASE_WIDTH
	system_pad.add_theme_constant_override("margin_left", 0)
	system_pad.add_theme_constant_override("margin_top", 90)
	system_pad.add_theme_constant_override("margin_right", 0)
	system_pad.add_theme_constant_override("margin_bottom", 40)
	system_center.add_child(system_pad)

	system_panel = VBoxContainer.new()
	system_panel.add_theme_constant_override("separation", 8)
	system_panel.size_flags_horizontal = Control.SIZE_FILL
	system_pad.add_child(system_panel)

	system_home_root = VBoxContainer.new()
	system_home_root.add_theme_constant_override("separation", 8)
	system_home_root.size_flags_horizontal = Control.SIZE_FILL
	system_panel.add_child(system_home_root)

	# UI-S2：字体组别总览的节点构建交给独立模块，保留原有回调与引用。
	var fontset_nodes: Dictionary = FONTSET_OVERVIEW_BUILDER_SCRIPT.new().build_overview(
		system_panel, _theme_muted,
		_on_fontset_selected, _on_fontset_selected_games,
		_on_fontset_editor_toggle.bind("movies"), _on_fontset_editor_toggle.bind("games"),
		_on_fontset_home_back
	)
	fontset_home_root = fontset_nodes["root"] as VBoxContainer
	fontset_option = fontset_nodes["movie_option"] as OptionButton
	fontset_option_games = fontset_nodes["game_option"] as OptionButton

	var system_editor_root := VBoxContainer.new()
	system_editor_root.add_theme_constant_override("separation", 8)
	system_editor_root.size_flags_horizontal = Control.SIZE_FILL
	system_editor_root.visible = false
	system_panel.add_child(system_editor_root)

	# UI-S3：系统设置首页仅委托创建；所有业务回调仍由 main.gd 处理。
	var system_home_nodes: Dictionary = SYSTEM_HOME_VIEW_BUILDER_SCRIPT.new().build(
		system_home_root, _theme_muted, XMB_SECTION_LABELS, {
			"_on_window_mode_selected": _on_window_mode_selected,
			"_exit_application": _exit_application,
			"_on_theme_selected": _on_theme_selected,
			"_on_fontset_entry_pressed": _on_fontset_entry_pressed,
			"_on_default_start_section_selected": _on_default_start_section_selected,
			"_on_add_movie_lib_pressed": _on_add_movie_lib_pressed,
			"_on_set_cover_folder_pressed": _on_set_cover_folder_pressed,
			"_on_clear_cover_folder_pressed": _on_clear_cover_folder_pressed,
			"_on_match_local_covers_pressed": _on_match_local_covers_pressed,
			"_on_open_cover_tool_pressed": _on_open_cover_tool_pressed,
			"_on_add_emulator_pressed": _on_add_emulator_pressed,
		}
	)
	window_mode_option = system_home_nodes["window_mode_option"] as OptionButton
	theme_option = system_home_nodes["theme_option"] as OptionButton
	fontset_entry_btn = system_home_nodes["fontset_entry_btn"] as Button
	default_section_option = system_home_nodes["default_section_option"] as OptionButton
	_lib_title_label = system_home_nodes["_lib_title_label"] as Label
	movie_lib_paths_list = system_home_nodes["movie_lib_paths_list"] as VBoxContainer
	_cover_folder_title = system_home_nodes["_cover_folder_title"] as Label
	_cover_folder_label = system_home_nodes["_cover_folder_label"] as Label
	_emulator_list = system_home_nodes["_emulator_list"] as VBoxContainer
	hint_label = system_home_nodes["hint_label"] as Label

	# UI-S2：字体编辑器节点由同一字体页面构建模块装配。
	var fontset_editor_nodes: Dictionary = FONTSET_OVERVIEW_BUILDER_SCRIPT.new().build_editor(
		system_editor_root, font_manager, FONTSET_EDITOR_SCRIPT,
		_on_fontset_editor_back, _on_fontset_manager_action
	)
	fontset_editor = fontset_editor_nodes["editor"]

	_app_version_label = Label.new()
	_app_version_label.text = "G3"
	_app_version_label.add_theme_font_size_override("font_size", 13)
	_app_version_label.add_theme_color_override("font_color", _theme_muted)
	system_home_root.add_child(_app_version_label)

	system_editor_root_ref = system_editor_root

	movie_lib_dir_dialog = FileDialog.new()
	movie_lib_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	movie_lib_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	movie_lib_dir_dialog.size = Vector2i(900, 620)
	movie_lib_dir_dialog.dir_selected.connect(_on_movie_lib_dir_selected)
	add_child(movie_lib_dir_dialog)

	movie_cover_dir_dialog = FileDialog.new()
	movie_cover_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	movie_cover_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	movie_cover_dir_dialog.size = Vector2i(900, 620)
	movie_cover_dir_dialog.dir_selected.connect(_on_cover_folder_dir_selected)
	add_child(movie_cover_dir_dialog)

	cover_tool_dialog = COVER_TOOL_DIALOG_SCRIPT.new()
	cover_tool_dialog.source_dir_changed.connect(_on_cover_tool_source_changed)
	cover_tool_dialog.scan_requested.connect(_on_cover_tool_scan)
	cover_tool_dialog.apply_all_requested.connect(_on_cover_tool_apply_all)
	cover_tool_dialog.edit_requested.connect(_on_cover_tool_edit)
	add_child(cover_tool_dialog)

	cover_crop_dialog = COVER_CROP_DIALOG_SCRIPT.new()
	cover_crop_dialog.apply_requested.connect(_on_cover_crop_apply)
	add_child(cover_crop_dialog)

	emulator_edit_dialog = EMULATOR_EDIT_DIALOG_SCRIPT.new()
	emulator_edit_dialog.set_platforms(GAME_PLATFORMS)
	emulator_edit_dialog.save_requested.connect(_on_emulator_save_requested)
	add_child(emulator_edit_dialog)

	emulator_remove_confirm = ConfirmationDialog.new()
	emulator_remove_confirm.title = "移除模拟器配置"
	emulator_remove_confirm.ok_button_text = "移除"
	emulator_remove_confirm.cancel_button_text = "取消"
	emulator_remove_confirm.confirmed.connect(_on_emulator_remove_confirmed)
	add_child(emulator_remove_confirm)

	get_viewport().size_changed.connect(_layout_system_panel)

	window_chrome = WINDOW_CHROME_SCRIPT.new()
	ui.add_child(window_chrome)
	window_chrome.set_theme_colors(_theme_text, _theme_muted, _theme_accent, Color(0.025, 0.085, 0.105, 1.0))

	navigation_drawer = NAVIGATION_DRAWER_SCRIPT.new()
	navigation_drawer.section_requested.connect(_on_navigation_section_requested)
	navigation_drawer.section_long_pressed.connect(_on_navigation_section_long_pressed)
	navigation_drawer.opened_changed.connect(_on_navigation_opened_changed)
	navigation_drawer.drawer_revealed.connect(_on_navigation_drawer_revealed)
	ui.add_child(navigation_drawer)

	# 电影信息展示节点由独立构建器负责；保留五个引用供原布局/主题/动画代码使用。
	var movie_info_nodes: Dictionary = MOVIE_INFO_VIEW_BUILDER_SCRIPT.new().build(ui)
	movie_info_title = movie_info_nodes["title"] as Label
	movie_info_meta = movie_info_nodes["meta"] as Label
	movie_info_genres = movie_info_nodes["genres"] as Label
	movie_desc_scroll = movie_info_nodes["scroll"] as ScrollContainer
	movie_desc_label = movie_info_nodes["description"] as Label

	# UI-S4a：底部隐藏层、热区和箭头的节点结构由独立模块创建。
	var bottom_nodes: Dictionary = MOVIE_BOTTOM_OVERLAY_BUILDER_SCRIPT.new().build_bottom(
		ui, HIDDEN_LAYER_HEIGHT, BOTTOM_HOT_ZONE_WIDTH, BOTTOM_HOT_ZONE_HEIGHT
	)
	_hidden_layer = bottom_nodes["layer"] as Control
	_hidden_tagline = bottom_nodes["tagline"] as Label
	_bottom_hot_zone = bottom_nodes["hot_zone"] as Control
	_bottom_arrow = bottom_nodes["arrow"] as Label
	movie_create_dialog = MOVIE_CREATE_DIALOG_SCRIPT.new()
	movie_create_dialog.create_requested.connect(_on_movie_create_requested)
	add_child(movie_create_dialog)

	# UI-S4c：游戏创建与粘贴导入弹窗保持原来的装配顺序。
	var game_entry_nodes: Dictionary = GAME_DIALOG_ASSEMBLY_BUILDER_SCRIPT.new().build_entry(self, GAME_PLATFORMS, {
		"_on_game_create_requested": _on_game_create_requested,
		"_on_paste_import_apply": _on_paste_import_apply,
	})
	game_create_dialog = game_entry_nodes["game_create_dialog"]
	game_paste_import_dialog = game_entry_nodes["game_paste_import_dialog"]

	var fade_layer: CanvasLayer = MOVIE_BOTTOM_OVERLAY_BUILDER_SCRIPT.new().create_fade_layer(self)
	# UI-S4b：电影管理、素材选择及 TMDB 弹窗的节点创建和信号连接交给独立模块。
	var movie_dialog_nodes: Dictionary = MOVIE_DIALOG_ASSEMBLY_BUILDER_SCRIPT.new().build(self, ui, {
		"_on_movie_manage_action_requested": _on_movie_manage_action_requested,
		"_on_movie_blank_action_requested": _on_movie_blank_action_requested,
		"_on_game_blank_action_requested": _on_game_blank_action_requested,
		"_on_movie_remove_confirmed": _on_movie_remove_confirmed,
		"_on_movie_cover_file_selected": _on_movie_cover_file_selected,
		"_on_movie_metadata_save_requested": _on_movie_metadata_save_requested,
		"_on_movie_backdrop_file_selected": _on_movie_backdrop_file_selected,
		"_on_movie_episode_clicked": _on_movie_episode_clicked,
		"_on_tmdb_search_requested": _on_tmdb_search_requested,
		"_on_tmdb_apply_requested": _on_tmdb_apply_requested,
		"_on_poster_list_requested": _on_poster_list_requested,
		"_on_poster_thumb_requested": _on_poster_thumb_requested,
		"_on_poster_apply_requested": _on_poster_apply_requested,
	})
	movie_manage_menu = movie_dialog_nodes["movie_manage_menu"]
	movie_blank_menu = movie_dialog_nodes["movie_blank_menu"]
	game_blank_menu = movie_dialog_nodes["game_blank_menu"]
	movie_remove_confirm = movie_dialog_nodes["movie_remove_confirm"]
	movie_cover_file_dialog = movie_dialog_nodes["movie_cover_file_dialog"]
	movie_metadata_dialog = movie_dialog_nodes["movie_metadata_dialog"]
	movie_backdrop_file_dialog = movie_dialog_nodes["movie_backdrop_file_dialog"]
	movie_episode_drawer = movie_dialog_nodes["movie_episode_drawer"]
	tmdb_dialog = movie_dialog_nodes["tmdb_dialog"]
	tmdb_poster_dialog = movie_dialog_nodes["tmdb_poster_dialog"]

	# UI-S4c：游戏管理、刮削、扫描及编辑弹窗的创建与信号连接由独立模块完成。
	var game_dialog_nodes: Dictionary = GAME_DIALOG_ASSEMBLY_BUILDER_SCRIPT.new().build_management(self, ui, GAME_PLATFORMS, {
		"_on_sgdb_search_requested": _on_sgdb_search_requested,
		"_on_sgdb_assets_requested": _on_sgdb_assets_requested,
		"_on_sgdb_asset_info_requested": _on_sgdb_asset_info_requested,
		"_on_sgdb_apply_requested": _on_sgdb_apply_requested,
		"_on_library_scan_requested": _on_library_scan_requested,
		"_on_library_scan_import_requested": _on_library_scan_import_requested,
		"_on_library_scan_dialog_closed": _on_library_scan_dialog_closed,
		"_on_game_manage_action": _on_game_manage_action,
		"_on_steam_search_requested": _on_steam_search_requested,
		"_on_steam_apply_requested": _on_steam_apply_requested,
		"_on_game_metadata_save_requested": _on_game_metadata_save_requested,
		"_on_game_launch_save_requested": _on_game_launch_save_requested,
		"_on_playtime_save_requested": _on_playtime_save_requested,
		"_on_game_remove_confirmed": _on_game_remove_confirmed,
	})
	game_scraper_dialog = game_dialog_nodes["game_scraper_dialog"]
	library_scan_dialog = game_dialog_nodes["library_scan_dialog"]
	game_manage_menu = game_dialog_nodes["game_manage_menu"]
	steam_search_dialog = game_dialog_nodes["steam_search_dialog"]
	game_metadata_dialog = game_dialog_nodes["game_metadata_dialog"]
	game_launch_dialog = game_dialog_nodes["game_launch_dialog"]
	playtime_edit_dialog = game_dialog_nodes["playtime_edit_dialog"]
	game_remove_confirm = game_dialog_nodes["game_remove_confirm"]

	_section_fade = MOVIE_BOTTOM_OVERLAY_BUILDER_SCRIPT.new().create_fade_rect(fade_layer)

func _layout_system_panel() -> void:
	if system_panel == null:
		return
	SYSTEM_HOME_VIEW_BUILDER_SCRIPT.new().layout_panel(system_panel, system_pad, get_viewport().get_visible_rect().size, SYSTEM_BASE_SIZE, SYSTEM_BASE_WIDTH)


func _on_window_resized() -> void:
	call_deferred("_enforce_window_aspect")

func _enforce_window_aspect() -> void:
	var win: Window = get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return
	var target_size: Vector2i = WINDOW_POLICY_SCRIPT.constrained_size(win.size, TARGET_WINDOW_ASPECT)
	if target_size != win.size:
		win.size = target_size

func _build_backend() -> void:
	# Session ownership is independent of backend requests and UI controllers.
	_render_ownership = RENDER_OWNERSHIP_SCRIPT.new()
	add_child(_render_ownership)
	backend = BACKEND_CLIENT_SCRIPT.new()
	add_child(backend)
	_backend_router = BACKEND_ROUTER_SCRIPT.new()
	add_child(_backend_router)
	_backend_router.attach(backend)
	_game_theme_controller = GAME_THEME_CONTROLLER_SCRIPT.new()
	add_child(_game_theme_controller)
	_game_theme_controller.configure(_backend_router)
	_game_theme_controller.palette_changed.connect(_on_game_theme_palette_changed)
	_game_theme_controller.theme_cleared.connect(_on_game_theme_palette_cleared)
	_emulator_controller = EMULATOR_CONTROLLER_SCRIPT.new()
	add_child(_emulator_controller)
	_emulator_controller.configure(_backend_router)
	_emulator_controller.list_completed.connect(_on_emulators_list_response)
	_emulator_controller.game_create_list_completed.connect(_on_emulators_for_game_create_response)
	_emulator_controller.save_completed.connect(_on_emulator_save_response)
	_emulator_controller.delete_completed.connect(_on_emulator_delete_response)
	_system_settings_controller = SYSTEM_SETTINGS_CONTROLLER_SCRIPT.new()
	add_child(_system_settings_controller)
	_system_settings_controller.configure(_backend_router)
	_system_settings_controller.state_completed.connect(_on_state_get_response)
	_system_settings_controller.settings_completed.connect(_on_settings_get_response)
	_system_settings_controller.fonts_completed.connect(_on_fonts_list_response)
	_system_settings_controller.fontsets_list_completed.connect(_on_fontsets_list_response)
	_system_settings_controller.fontset_completed.connect(_on_fontset_get_response)
	_system_settings_controller.fontset_action_completed.connect(_on_fontset_action_completed)
	_system_settings_controller.theme_switch_completed.connect(_on_theme_switch_response)
	_system_settings_controller.fontset_switch_completed.connect(_on_fontset_switch_completed)
	_system_settings_controller.movie_paths_completed.connect(_on_movie_paths_set_completed)
	_system_settings_controller.movie_cover_folder_completed.connect(_on_cover_folder_set_response)
	_system_settings_controller.cover_tool_source_completed.connect(_on_cover_tool_source_set_completed)
	_system_settings_controller.theme_current_completed.connect(_on_theme_current_response)
	_system_settings_controller.themes_list_completed.connect(_on_themes_list_response)
	_system_settings_controller.app_info_completed.connect(_on_app_info_response)
	_cover_tool_controller = COVER_TOOL_CONTROLLER_SCRIPT.new()
	add_child(_cover_tool_controller)
	_cover_tool_controller.configure(_backend_router)
	_cover_tool_presentation = COVER_TOOL_PRESENTATION_SCRIPT.new()
	_cover_tool_presentation.configure(cover_tool_dialog, cover_crop_dialog)
	_cover_tool_presentation.runtime_error_requested.connect(_show_runtime_error)
	_cover_tool_presentation.batch_reload_requested.connect(_on_cover_tool_batch_reload_requested)
	_cover_tool_controller.scan_completed.connect(_on_cover_tool_scan_completed)
	_cover_tool_controller.batch_progress.connect(_on_cover_tool_batch_progress)
	_cover_tool_controller.batch_finished.connect(_on_cover_tool_batch_finished)
	_game_controller = GAME_CONTROLLER_SCRIPT.new()
	add_child(_game_controller)
	_game_controller.configure(_backend_router)
	_game_controller.list_completed.connect(_on_game_list_completed)
	_game_controller.metadata_completed.connect(_on_game_metadata_completed)
	_game_controller.launch_metadata_completed.connect(_on_game_launch_metadata_completed)
	_game_controller.metadata_update_completed.connect(_on_game_metadata_update_completed)
	_game_controller.paste_update_completed.connect(_on_game_paste_update_completed)
	_game_controller.launch_update_completed.connect(_on_game_launch_update_completed)
	_game_controller.playtime_completed.connect(_on_game_playtime_completed)
	_game_controller.remove_completed.connect(_on_game_remove_completed)
	_game_controller.create_completed.connect(_on_game_create_completed)
	_game_controller.paste_create_completed.connect(_on_game_paste_create_completed)
	_game_controller.play_completed.connect(_on_game_play_completed)
	_game_controller.steam_manual_search_completed.connect(_on_steam_manual_search_completed)
	_game_controller.steam_manual_apply_completed.connect(_on_steam_manual_apply_completed)
	_game_controller.steam_batch_search_completed.connect(_on_steam_batch_search_completed)
	_game_controller.steam_batch_apply_completed.connect(_on_steam_batch_apply_completed)
	_steam_batch_scrape_coordinator = STEAM_BATCH_SCRAPE_COORDINATOR_SCRIPT.new()
	add_child(_steam_batch_scrape_coordinator)
	_steam_batch_scrape_coordinator.search_requested.connect(_on_steam_batch_search_requested)
	_steam_batch_scrape_coordinator.apply_requested.connect(_on_steam_batch_apply_requested)
	_steam_batch_scrape_coordinator.finished.connect(_on_steam_batch_finished)
	_game_controller.sgdb_search_completed.connect(_on_sgdb_search_completed)
	_game_controller.sgdb_assets_completed.connect(_on_sgdb_assets_completed)
	_game_controller.sgdb_asset_info_completed.connect(_on_sgdb_asset_info_completed)
	_game_controller.sgdb_apply_completed.connect(_on_sgdb_apply_completed)
	_movie_controller = MOVIE_CONTROLLER_SCRIPT.new()
	add_child(_movie_controller)
	_movie_controller.configure(_backend_router)
	_movie_controller.list_completed.connect(_on_movie_list_completed)
	_movie_controller.metadata_completed.connect(_on_movie_metadata_completed)
	_movie_controller.backdrop_refresh_completed.connect(_on_movie_backdrop_refresh_completed)
	_movie_controller.create_completed.connect(_on_movie_create_completed)
	_movie_controller.remove_completed.connect(_on_movie_remove_completed)
	_movie_controller.metadata_update_completed.connect(_on_movie_metadata_update_completed)
	_movie_controller.cover_set_completed.connect(_on_movie_cover_set_completed)
	_movie_controller.backdrop_set_completed.connect(_on_movie_backdrop_set_completed)
	_movie_controller.scan_completed.connect(_on_movie_scan_completed)
	_movie_controller.tmdb_search_completed.connect(_on_tmdb_search_completed)
	_movie_controller.tmdb_apply_completed.connect(_on_tmdb_apply_completed)
	_movie_controller.poster_list_completed.connect(_on_poster_list_completed)
	_movie_controller.poster_thumb_completed.connect(_on_poster_thumb_completed)
	_movie_controller.poster_apply_completed.connect(_on_poster_apply_completed)
	_movie_controller.play_completed.connect(_on_movie_play_completed)
	_movie_controller.covers_match_completed.connect(_on_covers_match_completed)
	_library_scan_controller = LIBRARY_SCAN_CONTROLLER_SCRIPT.new()
	add_child(_library_scan_controller)
	_library_scan_controller.configure(_backend_router)
	_library_scan_presentation = LIBRARY_SCAN_PRESENTATION_SCRIPT.new()
	add_child(_library_scan_presentation)
	_library_scan_presentation.configure(_library_scan_controller, backend, library_scan_dialog, backend_label)
	_library_scan_presentation.runtime_error_requested.connect(_show_runtime_error)
	_library_scan_presentation.runtime_error_clear_requested.connect(_clear_runtime_error)
	_library_scan_presentation.games_refresh_requested.connect(_request_games_list)
	_library_scan_controller.scan_completed.connect(_library_scan_presentation.on_scan_completed)
	_library_scan_controller.emulator_import_progress.connect(_library_scan_presentation.on_emulator_import_progress)
	_library_scan_controller.emulator_import_finished.connect(_library_scan_presentation.on_emulator_import_finished)
	_library_scan_controller.platform_import_progress.connect(_library_scan_presentation.on_platform_import_progress)
	_library_scan_controller.platform_import_finished.connect(_library_scan_presentation.on_platform_import_finished)
	backend.connected.connect(_on_backend_connected)
	backend.disconnected.connect(_on_backend_disconnected)
	_backend_router.legacy_response_received.connect(_on_backend_response)
	_backend_router.legacy_event_received.connect(_on_backend_event)

func _process(delta: float) -> void:
	var win := get_window()
	if win != null and win.mode != _last_window_mode:
		_last_window_mode = win.mode
		_on_window_mode_changed()

	_update_bottom_hot_zone(delta)

	_fps_accum += delta
	if _fps_accum >= 0.25:
		_fps_accum = 0.0
		if fps_label != null:
			fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if section_index == 1 and movie_wall != null:
		_update_movie_info_layout()
		_update_episode_drawer_rect()
		movie_wall.set_wheel_blocked(_is_mouse_in_movie_info_zone())

func _update_bottom_hot_zone(delta: float) -> void:
	if _bottom_hot_zone == null:
		return
	if section_index != 1:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()

	var zone := Rect2(
		vp - Vector2(BOTTOM_HOT_ZONE_WIDTH + 80.0, BOTTOM_HOT_ZONE_HEIGHT + 80.0),
		Vector2(BOTTOM_HOT_ZONE_WIDTH + 80.0, BOTTOM_HOT_ZONE_HEIGHT + 80.0)
	)
	var target_a: float = 0.35 if zone.has_point(mouse) else 0.0
	_bottom_arrow.modulate.a = lerpf(
		_bottom_arrow.modulate.a, target_a, 1.0 - exp(-delta * ARROW_FADE_SPEED)
	)

	var in_hot: bool = _bottom_hot_zone.get_global_rect().has_point(mouse)
	if _info_expanded and not in_hot:
		_info_expanded = false
		_info_offset_target = 0.0

	_info_offset = lerpf(_info_offset, _info_offset_target, 1.0 - exp(-delta * 10.0))
	if movie_wall != null:
		movie_wall.set_ui_offset_y(_info_offset)

	if _hidden_layer != null:
		_hidden_layer.offset_top = _info_offset
		_hidden_layer.offset_bottom = HIDDEN_LAYER_HEIGHT + _info_offset

	var t: float = clampf(-_info_offset / HIDDEN_LAYER_HEIGHT, 0.0, 1.0)
	var title_alpha: float = 1.0 - t * 0.85
	if movie_info_title != null:
		movie_info_title.modulate.a = title_alpha
	if movie_info_meta != null:
		movie_info_meta.modulate.a = title_alpha
	if movie_info_genres != null:
		movie_info_genres.modulate.a = title_alpha

func _update_episode_drawer_rect() -> void:
	if movie_episode_drawer == null:
		return
	var media_type: String = str(_selected_movie.get("media_type", "movie"))
	if media_type != "series":
		movie_episode_drawer.set_hover_visible(false)
		_last_drawer_rect = Rect2()
		return
	var rect: Rect2 = movie_wall.get_selected_card_screen_rect()
	if rect.size.x < 1.0:
		return
	if rect != _last_drawer_rect:
		_last_drawer_rect = rect
		var right_x: float = rect.position.x + rect.size.x
		var center_y: float = rect.position.y + rect.size.y * 0.5
		var h: float = rect.size.y
		movie_episode_drawer.update_card_rect(right_x, center_y, h)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var on_card: bool = rect.has_point(mouse)
	movie_episode_drawer.set_hover_visible(on_card)

func _unhandled_input(event: InputEvent) -> void:
	# Ctrl+M：UI 音效总开关（主题音乐不受影响）。放在最前面，但不吞其它输入。
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.ctrl_pressed and key_event.keycode == KEY_M:
			var now_enabled: bool = UISfx.toggle_enabled()
			print("G3 UISfx ", "enabled" if now_enabled else "muted")
			get_viewport().set_input_as_handled()
			return
	if section_index == 1 and event is InputEventMouseButton and _bottom_hot_zone != null:
		var mb_hot: InputEventMouseButton = event as InputEventMouseButton
		if mb_hot.pressed:
			var vp_hot: Vector2 = get_viewport().get_visible_rect().size
			var hot_zone := Rect2(
				vp_hot - Vector2(BOTTOM_HOT_ZONE_WIDTH, BOTTOM_HOT_ZONE_HEIGHT),
				Vector2(BOTTOM_HOT_ZONE_WIDTH, BOTTOM_HOT_ZONE_HEIGHT)
			)
			if hot_zone.has_point(mb_hot.position):
				if mb_hot.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_info_expanded = true
					_info_offset_target = -HIDDEN_LAYER_HEIGHT
					get_viewport().set_input_as_handled()
					return
				elif mb_hot.button_index == MOUSE_BUTTON_WHEEL_UP:
					_info_expanded = false
					_info_offset_target = 0.0
					get_viewport().set_input_as_handled()
					return
	if _pending_section >= 0:
		return
	if event is InputEventMouseButton:
		var mb_close: InputEventMouseButton = event as InputEventMouseButton
		if mb_close.pressed and movie_manage_menu != null and movie_manage_menu.visible:
			movie_manage_menu.hide()
			get_viewport().set_input_as_handled()
			return
	if section_index == 1 and event is InputEventMouseButton:
		var mb1: InputEventMouseButton = event as InputEventMouseButton
		if mb1.pressed and mb1.button_index == MOUSE_BUTTON_RIGHT:
			movie_blank_menu.show_at(mb1.position)
			get_viewport().set_input_as_handled()
			return
	if section_index == 0 and event is InputEventMouseButton:
		var mb_g: InputEventMouseButton = event as InputEventMouseButton
		if mb_g.pressed and mb_g.button_index == MOUSE_BUTTON_RIGHT:
			_on_game_blank_context_requested(mb_g.position)
			get_viewport().set_input_as_handled()
			return

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.ctrl_pressed and key.keycode == KEY_Q:
		_exit_application()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		_set_section((section_index + 1) % XMB_SECTIONS.size())
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F11:
		_toggle_window_mode()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_B and section_index == 0:
		if game_section != null:
			game_section.toggle_batch_mode(not game_section.is_batch_mode())
		get_viewport().set_input_as_handled()

func _on_xmb_pressed(index: int) -> void:
	_set_section(index)

func _set_section(index: int) -> void:
	var target: int = clampi(index, 0, XMB_SECTIONS.size() - 1)
	if not _section_ready or target == section_index:
		_apply_section_now(target)
		return
	_transition_to_section(target)

func _apply_section_now(index: int) -> void:
	section_index = clampi(index, 0, XMB_SECTIONS.size() - 1)
	var section: String = XMB_SECTIONS[section_index]
	if _game_ambient_mesh != null:
		_game_ambient_mesh.visible = section == "SYSTEM"
	var is_movies: bool = (section == "MOVIES")
	var is_games: bool = (section == "GAMES")
	movie_wall.visible = is_movies
	if game_section != null:
		game_section.set_section_visible(is_games)
	if archive_gallery != null:
		archive_gallery.set_section_visible(section == "MUSIC")
	system_root.visible = section == "SYSTEM"

	if _bottom_hot_zone != null:
		_bottom_hot_zone.visible = is_movies
	if _bottom_arrow != null:
		_bottom_arrow.visible = is_movies
	if _hidden_layer != null:
		_hidden_layer.visible = is_movies
	placeholder_label.visible = section == "COMICS"
	backend_label.visible = section == "SYSTEM"
	fps_label.visible = section == "SYSTEM"
	hint_label.visible = section == "SYSTEM"
	runtime_error_label.visible = section == "SYSTEM" and not runtime_error_label.text.is_empty()
	THEME_POLICY_SCRIPT.apply_navigation_colors(
		navigation_drawer, section, _current_movie_scope, _theme_accent, _theme_muted
	)
	if placeholder_label.visible:
		placeholder_label.text = _section_label(section) + "  /  当前仅保留模块入口"
	_refresh_movie_info_visibility()
	THEME_POLICY_SCRIPT.apply_window_colors(
		window_chrome, section, _current_movie_scope,
		_theme_text, _theme_muted, _theme_accent, _theme_base_top
	)
	THEME_POLICY_SCRIPT.apply_world_colors(
		movie_wall, collection_world, key_light, fill_light, rim_light,
		navigation_drawer, section, _current_movie_scope, _theme_accent
	)
	if section != "SYSTEM":
		if _fontset_editor_open:
			_on_fontset_editor_back()
		# 收掉字体组别总览页，下次切回 System 停在主页面
		if fontset_home_root != null and fontset_home_root.visible:
			fontset_home_root.visible = false
			system_home_root.visible = true
	if section == "SYSTEM":
		_refresh_emulators()

func _switch_movie_scope(new_scope: String) -> void:
	if new_scope == _current_movie_scope:
		return
	_current_movie_scope = new_scope
	if movie_wall != null:
		var empty: Array[Dictionary] = []
		movie_wall.set_movies(empty)
	# 清掉信息区残留（片名 / 年份 / 元数据 / 简介 / 隐藏层）
	_selected_movie = {}
	if movie_info_title != null:
		movie_info_title.text = ""
	if movie_info_meta != null:
		movie_info_meta.text = ""
	if movie_info_genres != null:
		movie_info_genres.text = ""
	if movie_desc_label != null:
		movie_desc_label.text = ""
	if _hidden_tagline != null:
		_hidden_tagline.text = ""
	if movie_episode_drawer != null:
		movie_episode_drawer.clear()
	_refresh_movie_info_visibility()
	if backend != null and backend.is_connected_to_backend():
		_request_movies_list()
	# 重建 System 页的路径列表 + 封面文件夹
	_rebuild_movie_lib_paths_ui()
	_rebuild_cover_folder_ui()
	# 重新应用当前板块配色（私有库用不同的强调色）
	_apply_section_now(section_index)

func _transition_to_section(target: int) -> void:
	if _pending_section >= 0:
		return
	_pending_section = target
	_section_fade.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_section_fade, "color:a", 1.0, 0.25)
	tween.tween_callback(_on_section_fade_done.bind(target))

func _on_section_fade_done(target: int) -> void:
	_apply_section_now(target)
	_pending_section = -1
	var tween2: Tween = create_tween()
	tween2.tween_property(_section_fade, "color:a", 0.0, 0.35)
	tween2.tween_callback(_hide_section_fade)

func _hide_section_fade() -> void:
	_section_fade.visible = false

func _on_backend_connected() -> void:
	backend_label.text = "后端已连接"
	_system_settings_controller.request_state()
	_request_movies_list()
	_request_games_list()
	_system_settings_controller.request_theme_current()
	_system_settings_controller.request_settings()
	_system_settings_controller.request_themes_list()
	_request_emulators_list()
	_system_settings_controller.request_app_info()
	_request_fontsets_list()
	_system_settings_controller.request_fonts()

func _on_backend_disconnected(code: int, reason: String) -> void:
	if _steam_batch_scrape_coordinator != null:
		_steam_batch_scrape_coordinator.cancel()
	if _game_controller != null:
		_game_controller.clear_sgdb_pending()
	if game_scraper_dialog != null:
		game_scraper_dialog.set_connection_lost()
	if _movie_controller != null:
		_movie_controller.clear_playback_exit_history()
	print("[G3DIAG] frontend backend disconnected code=", code, " reason=", reason)
	if archive_gallery != null:
		archive_gallery.set_launch_result(false, "后端连接已断开")
	# All sessions from the old backend connection are invalid now.
	_render_ownership.reset_on_disconnect()
	RenderingServer.render_loop_enabled = true
	if _game_controller != null:
		_game_controller.clear_pending_play()
	if game_section != null:
		game_section.set_detail_launching(false)
	backend_label.text = "后端离线  %d" % code
	if not reason.is_empty():
		backend_label.text = "后端离线  %d  %s" % [code, reason]

func _request_emulators_list() -> void:
	_emulator_controller.request_list()

func _on_emulators_list_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Array:
		_emulators = data as Array
	else:
		_emulators = []
		if not ok:
			_show_runtime_error("读取模拟器配置失败", _error_message(error))
	_rebuild_emulator_list()

func _request_fontsets_list() -> void:
	_system_settings_controller.request_fontsets_list()

func _on_fontsets_list_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if not ok or not (data is Array):
		return
	var catalog: Dictionary = _system_settings_controller.normalize_fontsets_catalog(
		data as Array, _fontset_id, _fontset_id_games
	)
	_fontset_ids.assign(catalog.get("movie_ids", []))
	_fontset_ids_games.assign(catalog.get("game_ids", []))
	fontset_option.clear()
	for fs_name in catalog.get("movie_names", []):
		fontset_option.add_item(str(fs_name))
	fontset_option_games.clear()
	for fs_name in catalog.get("game_names", []):
		fontset_option_games.add_item(str(fs_name))
	if not _fontset_ids.is_empty():
		fontset_option.select(int(catalog.get("movie_index", 0)))
	if not _fontset_ids_games.is_empty():
		fontset_option_games.select(int(catalog.get("game_index", 0)))

func _on_app_info_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		var info: Dictionary = data as Dictionary
		_app_version_label.text = "G3  %s" % str(info.get("display", "?"))

func _on_theme_current_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		_current_theme = data as Dictionary
		_apply_theme(_current_theme)

func _on_themes_list_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if not ok or not (data is Array):
		return
	_theme_ids.clear()
	theme_option.clear()
	var current_index: int = 0
	for i in range((data as Array).size()):
		var entry_value: Variant = (data as Array)[i]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var theme_id: String = str(entry.get("id", ""))
		if theme_id.is_empty():
			continue
		_theme_ids.append(theme_id)
		theme_option.add_item(str(entry.get("name", theme_id)))
		if bool(entry.get("active", false)):
			current_index = _theme_ids.size() - 1
	if _theme_ids.size() > 0:
		theme_option.select(current_index)

func _on_fonts_list_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if not ok or not (data is Array):
		return
	_system_fonts = data as Array
	if fontset_editor != null:
		fontset_editor.set_system_fonts(_system_fonts)

func _on_state_get_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		var state: Dictionary = data as Dictionary
		var key: String = "last_movie_id_private" if _current_movie_scope == "private" else "last_movie_id_main"
		_restore_movie_id = str(state.get(key, ""))
	_state_ready = true
	_try_restore_movie()

func _on_settings_get_response(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if not ok or not (data is Dictionary):
		return
	var settings: Dictionary = _system_settings_controller.normalize_settings_payload(data as Dictionary, XMB_SECTIONS)
	_theme_music_enabled = bool(settings.get("theme_music_enabled", true))
	_theme_music_base_volume = float(settings.get("theme_music_base_volume", 0.35))
	# UI 音效与主题音乐各自独立：这里只调整 UISfx，不触碰 theme_music_player。
	UISfx.set_volume(float(settings.get("ui_sfx_volume", 0.6)))
	UISfx.set_enabled(bool(settings.get("ui_sfx_enabled", true)))
	_movie_library_paths.assign(settings.get("movie_library_paths", []))
	_movie_library_paths_private.assign(settings.get("movie_library_paths_private", []))
	_movie_cover_folder_main = str(settings.get("movie_cover_folder_main", ""))
	_movie_cover_folder_private = str(settings.get("movie_cover_folder_private", ""))
	_cover_tool_source_dir_cached = str(settings.get("cover_tool_source_dir", ""))
	_rebuild_cover_folder_ui()

	# 暂时不处理，等 E 阶段做本地封面匹配时再加界面
	_rebuild_movie_lib_paths_ui()
	var start_index: int = int(settings.get("default_section_index", 0))
	default_section_option.select(start_index)
	_set_section(start_index)
	var wm: String = str(settings.get("window_mode", "windowed"))
	if window_mode_option != null:
		window_mode_option.select(0 if wm != "fullscreen" else 1)
	if not _current_theme.is_empty():
		_apply_theme_audio(_current_theme)
	_fontset_id = str(settings.get("fontset_id", "default"))
	_request_fontset_get("movies", _fontset_id)
	_fontset_id_games = str(settings.get("fontset_id_games", "default"))
	_request_fontset_get("games", _fontset_id_games)

# Each scope keeps its own latest-pending slot, as in the legacy handler.
func _request_fontset_get(scope: String, fontset_id: String) -> void:
	_system_settings_controller.request_fontset_get(scope, fontset_id)

func _on_fontset_get_response(_request_id: String, ok: bool, data: Variant, _error: Variant, scope: String) -> void:
	if ok and data is Dictionary:
		_apply_fontset(scope, data as Dictionary)

func _request_movies_list() -> void:
	if _perf_movies_list_request_started_msec < 0:
		_perf_movies_list_request_started_msec = Time.get_ticks_msec()
	_movie_controller.request_list(_current_movie_scope)

func _on_movie_list_completed(scope: String, ok: bool, data: Variant, _error: Variant) -> void:
	var perf_callback_started_msec: int = Time.get_ticks_msec()
	if _perf_movies_list_request_started_msec >= 0:
		var perf_movie_item_count: int = -1
		if data is Array:
			perf_movie_item_count = (data as Array).size()
		_perf_movies_list_request_started_msec = -1
	# A list response must never repaint the other movie library.
	if scope != _current_movie_scope:
		return
	var perf_accepted_movie_count: int = 0
	if ok and data is Array:
		var movies: Array[Dictionary] = []
		for value: Variant in data as Array:
			if value is Dictionary:
				movies.append(value as Dictionary)
		perf_accepted_movie_count = movies.size()
		movie_wall.set_movies(movies)
		if movie_wall.consume_cover_reload_after_list():
			movie_wall.reload_covers()
		if movie_wall.consume_backdrop_refresh_after_list():
			movie_wall.force_refresh_backdrop()
	_movies_ready = true
	_try_restore_movie()
	return


func _request_games_list() -> void:
	if _game_controller != null:
		if _perf_games_list_request_started_msec < 0:
			_perf_games_list_request_started_msec = Time.get_ticks_msec()
		_game_controller.request_list()

func _on_game_list_completed(ok: bool, data: Variant, _error: Variant) -> void:
	var perf_callback_started_msec: int = Time.get_ticks_msec()
	if _perf_games_list_request_started_msec >= 0:
		var perf_game_item_count: int = -1
		if data is Array:
			perf_game_item_count = (data as Array).size()
		_perf_games_list_request_started_msec = -1
	# Legacy semantics: only successful Array responses repaint the two views.
	if not ok or not (data is Array):
		return
	var games: Array[Dictionary] = []
	for value: Variant in data as Array:
		if value is Dictionary:
			games.append(value as Dictionary)
	if game_section != null:
		game_section.set_games(games)
		if archive_gallery != null:
			archive_gallery.set_games(games)

func _on_game_metadata_completed(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary and not item_id.is_empty():
		game_metadata_dialog.show_metadata(item_id, data as Dictionary)
	else:
		_show_runtime_error("读取游戏资料失败", _error_message(error))

func _on_game_launch_metadata_completed(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary and not item_id.is_empty():
		game_launch_dialog.show_profile(item_id, data as Dictionary)
	else:
		_show_runtime_error("读取启动设置失败", _error_message(error))

func _on_game_metadata_update_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "游戏资料已保存"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("保存游戏资料失败", _error_message(error))

func _on_game_paste_update_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "已从文本更新资料"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("更新失败", _error_message(error))

func _on_game_launch_update_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "启动设置已保存"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("保存启动设置失败", _error_message(error))

func _on_game_playtime_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "游玩时长已更新"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("保存失败", _error_message(error))

func _on_game_remove_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "游戏已移除"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("移除失败", _error_message(error))

func _on_game_create_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "游戏已添加"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("添加游戏失败", _error_message(error))

func _on_game_paste_create_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "已从文本创建游戏"
		_clear_runtime_error()
		_request_games_list()
	else:
		_show_runtime_error("创建失败", _error_message(error))

func _on_steam_manual_search_completed(ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Array:
		steam_search_dialog.show_results(data as Array)
	else:
		steam_search_dialog.show_results([])

func _on_steam_manual_apply_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "Steam 资料已应用"
		_clear_runtime_error()
		steam_search_dialog.hide()
		_request_games_list()
	else:
		steam_search_dialog.set_apply_failed(_error_message(error))

func _on_steam_batch_search_completed(generation: int, item_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	_steam_batch_scrape_coordinator.on_search_result(generation, item_id, ok, data)

func _on_steam_batch_apply_completed(generation: int, item_id: String, ok: bool, _data: Variant, _error: Variant) -> void:
	# Only the current apply may update the UI; late callbacks are ignored.
	if not _steam_batch_scrape_coordinator.is_active() or generation != _steam_batch_scrape_coordinator.generation() or _steam_batch_scrape_coordinator.phase() != "apply" or item_id != _steam_batch_scrape_coordinator.current_id():
		return
	if ok:
		backend_label.text = "Steam 资料已应用"
		_clear_runtime_error()
		steam_search_dialog.hide()
	_steam_batch_scrape_coordinator.on_apply_result(generation, item_id)

func _on_sgdb_search_completed(ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Array:
		game_scraper_dialog.show_search_results(data as Array)
	else:
		game_scraper_dialog.show_search_results([])

func _on_sgdb_assets_completed(asset_tag: String, batch_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		var items_raw = (data as Dictionary).get("items", [])
		var items: Array = items_raw if items_raw is Array else []
		game_scraper_dialog.show_assets(asset_tag, items, batch_id)
	else:
		game_scraper_dialog.show_assets(asset_tag, [], batch_id)

func _on_sgdb_asset_info_completed(ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		game_scraper_dialog.show_asset_info(data as Dictionary)

func _on_sgdb_apply_completed(asset_tag: String, operation_id: String, _remaining: int, ok: bool, data: Variant, error: Variant) -> void:
	var all_done: bool = game_scraper_dialog.on_apply_result(asset_tag, operation_id, ok, data)
	if ok:
		backend_label.text = "素材已应用（%s）" % asset_tag
		_clear_runtime_error()
		if all_done:
			_request_games_list()
			game_scraper_dialog.set_apply_done()
	else:
		_show_runtime_error("应用素材失败", _error_message(error))

func _on_game_play_completed(ok: bool, data: Variant, error: Variant) -> void:
	# A game launch response is not proof of a running process.
	# Only a session-correlated game.running event may claim ownership.
	if archive_gallery != null:
		archive_gallery.set_launch_result(ok, "" if ok else _error_message(error))
	if not ok:
		_resume_render_if_unowned()
		_show_runtime_error("启动失败", _error_message(error))
		_reset_launch_button_after(1.5)
		return
	var game_monitorable: bool = true
	if data is Dictionary:
		game_monitorable = bool((data as Dictionary).get("monitorable", true))
	if not game_monitorable:
		_resume_render_if_unowned()
		_reset_launch_button_after(0.1)

func _on_movie_paths_set_completed(_request_id: String, ok: bool, data: Variant, error: Variant, scope: String) -> void:
	if ok and data is Dictionary:
		var response: Dictionary = data as Dictionary
		# Preserve the original per-scope values when a reply arrives after a
		# user switches between the main and private movie libraries.
		var raw: Variant = response.get("movie_library_paths", [])
		if scope == "private":
			raw = response.get("movie_library_paths_private", raw)
		var target: Array[String] = []
		if raw is Array:
			for p in raw:
				target.append(str(p))
		if scope == "private":
			_movie_library_paths_private = target
		else:
			_movie_library_paths = target
		_rebuild_movie_lib_paths_ui()
	else:
		_show_runtime_error("保存库路径失败", _error_message(error))

func _on_cover_tool_source_set_completed(_request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		_cover_tool_source_dir_cached = str((data as Dictionary).get("cover_tool_source_dir", _cover_tool_source_dir_cached))

func _on_cover_tool_scan_completed(ok: bool, data: Variant, error: Variant) -> void:
	_cover_tool_presentation.show_scan_completed(ok, data, _error_message(error) if not (ok and data is Dictionary) else "")

func _on_cover_tool_batch_progress(done: int, total: int) -> void:
	_cover_tool_presentation.show_batch_progress(done, total)

func _on_cover_tool_batch_finished(succeeded: int, failed: int) -> void:
	_cover_tool_presentation.show_batch_finished(succeeded, failed)

func _on_cover_tool_batch_reload_requested() -> void:
	movie_wall.mark_cover_reload_after_list()
	_request_movies_list()

func _on_backend_response(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
		
	# All cover-tool requests now use BackendRouter callbacks.
	# (Legacy replies from unrelated modules are intentionally ignored.)
		
	pass




			

	
func _on_backend_event(event_type: String, payload: Dictionary) -> void:
	if event_type == "sgdb.thumb_ready":
		game_scraper_dialog.show_thumb_progress(payload)
		return
	if event_type == "sgdb.apply.progress":
		game_scraper_dialog.show_apply_progress(payload)
		return
	# Only events stamped by the active backend socket may change playback
	# ownership. This also rejects untagged events from legacy connections.
	if event_type == "movie.exited" or event_type == "game.running" or event_type == "game.exited":
		if backend == null or not backend.event_epoch_matches(payload):
			return
	if event_type == "library.changed":
		var media_type: String = str(payload.get("media_type", ""))
		if bool(payload.get("backdrop_changed", false)):
			movie_wall.mark_backdrop_refresh_after_list()
		if media_type == "movie" or media_type.is_empty():
			_request_movies_list()
		elif media_type == "game":
			_request_games_list()
	elif event_type == "movie.exited":
		_movie_controller.observe_playback_exit(payload)
		var movie_session_id: String = str(payload.get("play_session_id", ""))
		var released_movie: bool = false
		if not movie_session_id.is_empty():
			_render_ownership.note_exit("movie", movie_session_id)
			released_movie = _render_ownership.release("movie", movie_session_id)
		# Legacy/no-ID exits cannot release a different identified session.
		if released_movie:
			_refresh_render_after_release()
		else:
			_resume_render_if_unowned()
	elif event_type == "game.running":
		var running_session_id: String = str(payload.get("play_session_id", ""))
		print("[G3DIAG] frontend received game.running item=", str(payload.get("item_id", "")), " session=", running_session_id)
		if _render_ownership.claim("game", running_session_id):
			_delayed_pause_render()
	elif event_type == "game.exited":
		var exited_session_id: String = str(payload.get("play_session_id", ""))
		print("[G3DIAG] frontend received game.exited item=", str(payload.get("item_id", "")), " session=", exited_session_id, " elapsed=", payload.get("elapsed_seconds", -1))
		var released_game: bool = false
		if not exited_session_id.is_empty():
			_render_ownership.note_exit("game", exited_session_id)
			released_game = _render_ownership.release("game", exited_session_id)
		if released_game:
			_refresh_render_after_release()
		else:
			_resume_render_if_unowned()
			# An unrelated/early exit must not reset the current launch UI.
			if backend != null and backend.is_connected_to_backend():
				_request_games_list()
			return
		_reset_launch_button_after(0.1)		
		if backend != null and backend.is_connected_to_backend():
			_request_games_list()

func _on_movie_selection_changed(index: int, movie: Dictionary) -> void:
	_selected_movie = movie
	_update_movie_info_content(movie)
	_ensure_movie_backdrop(movie)
	_schedule_episode_drawer_refresh(movie)
	var item_id: String = str(movie.get("id", ""))
	if not item_id.is_empty() and backend != null and backend.is_connected_to_backend():
		var state_key: String = "last_movie_id_private" if _current_movie_scope == "private" else "last_movie_id_main"
		_system_settings_controller.update_state(state_key, item_id)

func _schedule_episode_drawer_refresh(movie: Dictionary) -> void:
	_episode_drawer_generation += 1
	var gen: int = _episode_drawer_generation
	var media_type: String = str(movie.get("media_type", "movie"))
	if media_type != "series":
		if movie_episode_drawer != null:
			movie_episode_drawer.clear()
		return
	if movie_episode_drawer != null:
		movie_episode_drawer.clear()
	await get_tree().create_timer(0.35).timeout
	if gen != _episode_drawer_generation:
		return
	_refresh_episode_drawer(movie)

func _refresh_episode_drawer(movie: Dictionary) -> void:
	if movie_episode_drawer == null:
		return
	var media_type: String = str(movie.get("media_type", "movie"))
	if media_type != "series":
		movie_episode_drawer.clear()
		return
	var episodes_value: Variant = movie.get("episodes", [])
	var episodes: Array = episodes_value if episodes_value is Array else []
	var item_id: String = str(movie.get("id", ""))
	if episodes.is_empty():
		movie_episode_drawer.clear()
		return
	movie_episode_drawer.set_episodes(item_id, episodes)
	THEME_POLICY_SCRIPT.apply_episode_drawer_colors(movie_episode_drawer, _current_movie_scope)

func _ensure_movie_backdrop(movie: Dictionary) -> void:
	var item_id: String = str(movie.get("id", ""))
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		return
	_movie_controller.request_backdrop_ensure(item_id)

func _update_movie_info_content(movie: Dictionary) -> void:
	if movie_info_title == null:
		return
	var info: Dictionary = MOVIE_INFO_VIEW_BUILDER_SCRIPT.new().format_content(movie)
	movie_info_title.text = info["title"]
	movie_info_meta.text = info["year"]
	movie_info_genres.text = info["meta_line"]
	movie_desc_label.text = info["description"]
	if _hidden_tagline != null:
		_hidden_tagline.text = info["tagline"]
	_refresh_movie_info_visibility()

func _refresh_movie_info_visibility() -> void:
	var is_movie: bool = section_index == 1
	movie_info_title.visible = is_movie and not movie_info_title.text.is_empty()
	movie_info_meta.visible = is_movie and not movie_info_meta.text.is_empty()
	movie_info_genres.visible = is_movie and not movie_info_genres.text.is_empty()
	var desc_visible: bool = is_movie and not movie_desc_label.text.is_empty()
	movie_desc_scroll.visible = desc_visible

func _apply_theme(theme: Dictionary) -> void:
	var colors: Dictionary = THEME_POLICY_SCRIPT.read_colors(theme)
	_theme_text = THEME_POLICY_SCRIPT.resolve(colors, "text", Color(0.93, 1.0, 1.0, 1.0))
	_theme_muted = THEME_POLICY_SCRIPT.resolve(colors, "muted_text", Color(0.55, 0.70, 0.72, 1.0))
	_theme_accent = THEME_POLICY_SCRIPT.resolve(colors, "accent", Color(0.20, 0.82, 0.76, 1.0))
	_theme_base_top = THEME_POLICY_SCRIPT.resolve(colors, "base_top", Color(0.05, 0.28, 0.32, 1.0))
	var top_color: Color = _theme_base_top
	if rim_light != null:
		rim_light.light_color = _theme_accent.lerp(Color.WHITE, 0.55)
	if _hidden_tagline != null:
		_hidden_tagline.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78, 0.75))
	if window_chrome != null:
		window_chrome.set_theme_colors(_theme_text, _theme_muted, _theme_accent, top_color)

	# 切主题不播黑场过渡，只重新应用当前板块配色
	_apply_section_now(section_index)
	_apply_theme_audio(theme)


func _error_message(error: Variant) -> String:
	return BACKEND_ROUTER_SCRIPT.format_error_message(error)

func _show_runtime_error(prefix: String, message: String) -> void:
	_runtime_message_generation += 1
	var generation: int = _runtime_message_generation
	if _runtime_message_tween != null and _runtime_message_tween.is_valid():
		_runtime_message_tween.kill()
	runtime_error_label.modulate.a = 1.0
	runtime_error_label.text = "%s · %s" % [prefix, message]
	runtime_error_label.visible = true
	_dismiss_runtime_message_after_delay(generation)

func _dismiss_runtime_message_after_delay(generation: int) -> void:
	await get_tree().create_timer(RUNTIME_MESSAGE_HOLD_SECONDS).timeout
	if generation != _runtime_message_generation or runtime_error_label.text.is_empty():
		return
	_runtime_message_tween = create_tween()
	_runtime_message_tween.tween_property(runtime_error_label, "modulate:a", 0.0, RUNTIME_MESSAGE_FADE_SECONDS)
	await _runtime_message_tween.finished
	if generation != _runtime_message_generation:
		return
	runtime_error_label.visible = false
	runtime_error_label.text = ""
	runtime_error_label.modulate.a = 1.0

func _clear_runtime_error() -> void:
	_runtime_message_generation += 1
	if _runtime_message_tween != null and _runtime_message_tween.is_valid():
		_runtime_message_tween.kill()
	runtime_error_label.visible = false
	runtime_error_label.text = ""
	runtime_error_label.modulate.a = 1.0

func _apply_theme_audio(theme: Dictionary) -> void:
	THEME_POLICY_SCRIPT.apply(theme, theme_music_player, _theme_music_enabled, _theme_music_base_volume)

func _on_navigation_section_requested(section_id: String) -> void:
	var index: int = XMB_SECTIONS.find(section_id)
	if index >= 0:
		_set_section(index)

func _on_navigation_opened_changed(opened: bool) -> void:
	if game_section != null:
		game_section.set_nav_opened(opened)


func _on_navigation_drawer_revealed() -> void:
	if game_section != null:
		game_section.set_nav_drawer_revealed()


func _on_navigation_section_long_pressed(section_id: String) -> void:
	if section_id != "MOVIES":
		return
	# 长按电影图标：切到另一个库
	var new_scope: String = "main" if _current_movie_scope == "private" else "private"
	_switch_movie_scope(new_scope)
	var idx: int = XMB_SECTIONS.find("MOVIES")
	if idx >= 0:
		_set_section(idx)

func _on_default_start_section_selected(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	var section_id: String = XMB_SECTIONS[clampi(index, 0, XMB_SECTIONS.size() - 1)].to_lower()
	_system_settings_controller.update_setting("default_start_section", section_id)

func _on_theme_selected(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	if index < 0 or index >= _theme_ids.size():
		return
	var theme_id: String = _theme_ids[index]
	if theme_id == str(_current_theme.get("id", "")):
		return
	_system_settings_controller.request_theme_switch(theme_id)

# Preserve the legacy theme-switch single pending slot. Only the latest
# settings.update(current_theme) response can trigger the theme refresh.
func _on_theme_switch_response(_request_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "主题已切换"
		_clear_runtime_error()
		_system_settings_controller.request_theme_current()
	else:
		_show_runtime_error("主题切换失败", _error_message(error))

func _on_window_mode_selected(index: int) -> void:
	var mode := "windowed" if index == 0 else "fullscreen"
	_apply_window_mode(mode)
	if backend != null and backend.is_connected_to_backend():
		_system_settings_controller.update_setting("window_mode", mode)

func _on_fontset_selected(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	if index < 0 or index >= _fontset_ids.size():
		return
	var fs_id: String = _fontset_ids[index]
	if fs_id == _fontset_id:
		return
	_fontset_id = fs_id
	_system_settings_controller.request_fontset_switch("movies", fs_id)

func _on_fontset_selected_games(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	if index < 0 or index >= _fontset_ids_games.size():
		return
	var fs_id: String = _fontset_ids_games[index]
	if fs_id == _fontset_id_games:
		return
	_fontset_id_games = fs_id
	_system_settings_controller.request_fontset_switch("games", fs_id)

func _on_fontset_switch_completed(scope: String, _request_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if scope == "games":
		_on_fontset_switch_games_response(_request_id, ok, _data, error)
	else:
		_on_fontset_switch_movies_response(_request_id, ok, _data, error)

func _on_fontset_switch_movies_response(_request_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		_clear_runtime_error()
		_request_fontset_get("movies", _fontset_id)
	else:
		_show_runtime_error("字体切换失败", _error_message(error))

func _on_fontset_switch_games_response(_request_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		_clear_runtime_error()
		_request_fontset_get("games", _fontset_id_games)
	else:
		_show_runtime_error("游戏字体切换失败", _error_message(error))

func _on_fontset_editor_toggle(scope: String) -> void:
	_fontset_editor_scope = scope
	_fontset_editor_open = true
	system_home_root.visible = false
	if fontset_home_root != null:
		fontset_home_root.visible = false
	if system_editor_root_ref != null:
		system_editor_root_ref.visible = true
	fontset_editor.set_system_fonts(_system_fonts)
	if backend == null or not backend.is_connected_to_backend():
		return
	var fs_id: String = _fontset_id if scope == "movies" else _fontset_id_games
	_request_fontset_get(scope, fs_id)

func _on_fontset_editor_back() -> void:
	_fontset_editor_open = false
	system_home_root.visible = false
	if fontset_home_root != null:
		fontset_home_root.visible = true
	if system_editor_root_ref != null:
		system_editor_root_ref.visible = false

func _on_fontset_entry_pressed() -> void:
	system_home_root.visible = false
	if fontset_home_root != null:
		fontset_home_root.visible = true
	if system_editor_root_ref != null:
		system_editor_root_ref.visible = false

func _on_fontset_home_back() -> void:
	if fontset_home_root != null:
		fontset_home_root.visible = false
	system_home_root.visible = true

func _on_fontset_manager_action(action: String, payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		fontset_editor.set_status("后端未连接")
		return
	_system_settings_controller.request_fontset_action(action, payload)

func _on_fontset_action_completed(action: String, scope: String, _request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	var is_games: bool = (scope == "games")
	match action:
		"save":
			if ok and data is Dictionary:
				fontset_editor.set_status("已保存")
				_request_fontsets_list()
				if is_games:
					_request_fontset_get("games", _fontset_id_games)
				else:
					_request_fontset_get("movies", _fontset_id)
			else:
				fontset_editor.set_status("保存失败：%s" % _error_message(error))
		"create":
			if ok and data is Dictionary:
				var new_fs: Dictionary = data as Dictionary
				var new_id: String = str(new_fs.get("id", ""))
				if is_games:
					_fontset_id_games = new_id
				else:
					_fontset_id = new_id
				if fontset_editor != null:
					fontset_editor.set_status("已创建并应用")
				if is_games:
					_system_settings_controller.update_setting("fontset_id_games", new_id)
				else:
					_system_settings_controller.update_setting("fontset_id", new_id)
				_request_fontsets_list()
				_request_fontset_get(scope, new_id)
			else:
				if fontset_editor != null:
					fontset_editor.set_status("创建失败：%s" % _error_message(error))
		"rename":
			if ok and data is Dictionary:
				fontset_editor.set_status("已重命名")
				_request_fontsets_list()
			else:
				fontset_editor.set_status("重命名失败：%s" % _error_message(error))
		"delete":
			if ok:
				fontset_editor.set_status("已删除")
				_request_fontsets_list()
			else:
				fontset_editor.set_status("删除失败：%s" % _error_message(error))

func _toggle_window_mode() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.borderless = true
	if window.mode == Window.MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_on_window_mode_changed()

func _section_label(section: String) -> String:
	return G3NavigationDrawer.resolve_section_label(section, XMB_SECTIONS, XMB_SECTION_LABELS)

func _refresh_render_after_release() -> void:
	# Releasing one of several owners invalidates a pending pause token.
	# If rendering is still enabled, schedule a fresh pause for survivors.
	if _render_ownership != null and _render_ownership.has_owners():
		if RenderingServer.render_loop_enabled:
			_delayed_pause_render()
	else:
		_resume_render_if_unowned()

func _resume_render_if_unowned() -> void:
	# Unknown/duplicate exits and failed launches must not resume rendering
	# while another game or movie session still owns the render pause.
	if _render_ownership != null and _render_ownership.has_owners():
		return
	if _render_ownership != null:
		_render_ownership.invalidate_pending_pause()
	RenderingServer.render_loop_enabled = true

func _delayed_pause_render() -> void:
	if _render_ownership == null or not _render_ownership.has_owners():
		return
	var token: int = _render_ownership.pause_token()
	print("[G3DIAG] frontend pause scheduled token=", token)
	await get_tree().create_timer(0.6).timeout
	if not _render_ownership.should_pause_for_token(token):
		print("[G3DIAG] frontend pause cancelled token=", token)
		return
	RenderingServer.render_loop_enabled = false
	print("[G3DIAG] frontend render paused token=", token)

func _exit_application() -> void:
	get_tree().quit()

func _apply_fontset(scope: String, fontset: Dictionary) -> void:
	if font_manager == null:
		return
	font_manager.set_fontset(scope, fontset)

	# 编辑器打开着且 scope 匹配 → 重刷编辑器
	if fontset_editor != null and fontset_editor.visible and _fontset_editor_scope == scope:
		fontset_editor.open_for(scope, fontset)

	# 电影 scope：应用到电影信息区 + 全局 UI 主题
	if scope == "movies":
		_apply_font_to_label(movie_info_title, "movie_title", "movies")
		_apply_font_to_label(movie_info_meta, "movie_year", "movies")
		_apply_font_to_label(movie_info_genres, "movie_meta", "movies")
		_apply_font_to_label(movie_desc_label, "movie_desc", "movies")
		_apply_font_to_label(_hidden_tagline, "movie_tagline", "movies")

		if _ui_root == null:
			return
		var ui_font: Font = font_manager.get_font_for("ui_default", "movies")
		var ui_size: int = font_manager.get_size_for("ui_default", 15, "movies")
		var t: Theme = _ui_root.theme
		if t == null:
			t = Theme.new()
			_ui_root.theme = t
		if ui_font != null:
			t.default_font = ui_font
		else:
			t.default_font = null
		t.default_font_size = ui_size
		var ui_settings: Dictionary = font_manager.get_field_settings("ui_default", "movies")
		var ui_color_hex := str(ui_settings.get("font_color", "")).strip_edges()
		if ui_color_hex.is_empty():
			# Theme.clear_color() errors if the Label theme type/color has never been defined.
			if t.has_color("font_color", "Label"):
				t.clear_color("font_color", "Label")
		else:
			t.set_color("font_color", "Label", Color.from_string(ui_color_hex, Color.WHITE))
		t.set_constant("line_spacing", "Label", int(ui_settings.get("line_spacing", 0)))
	# games scope：游戏板块不在 _ui_root 子树下，显式通知它应用
	else:
		if game_section != null:
			game_section.set_font_manager(font_manager)
			game_section.apply_fontset()
		if archive_gallery != null:
			archive_gallery.apply_fontset()

func _apply_font_to_label(label: Label, key: String, scope: String = "movies") -> void:
	if label == null or font_manager == null:
		return
	var f: Font = font_manager.get_font_for(key, scope)
	if f != null:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")
	font_manager.apply_style_to_control(label, key, scope)

func _update_movie_info_layout() -> void:
	if movie_wall == null or movie_info_title == null:
		return
	MOVIE_INFO_VIEW_BUILDER_SCRIPT.new().update_layout(
		get_viewport().get_visible_rect().size,
		font_manager,
		movie_info_title,
		movie_info_meta,
		movie_info_genres,
		movie_desc_label,
		movie_desc_scroll,
		_info_offset
	)

func _is_mouse_in_movie_info_zone() -> bool:
	if section_index != 1:
		return false
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if movie_desc_scroll == null or not movie_desc_scroll.visible:
		return false
	var info_top: float = movie_info_title.position.y - 10.0
	var scroll_screen_pos: Vector2 = movie_desc_scroll.position
	var info_rect: Rect2 = Rect2(
		scroll_screen_pos.x - 20.0,
		info_top,
		vp.x - scroll_screen_pos.x + 20.0,
		vp.y - info_top
	)
	return info_rect.has_point(mouse)

func _on_movie_create_requested(payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("添加电影失败", "后端未连接")
		return
	var scoped_payload: Dictionary = payload.duplicate()
	scoped_payload["scope"] = _current_movie_scope
	_movie_controller.request_create(scoped_payload)

func _open_movie_create_dialog() -> void:
	movie_create_dialog.show_dialog()

func _on_movie_right_clicked(movie: Dictionary, screen_position: Vector2) -> void:
	_movie_menu_target = movie
	movie_manage_menu.show_at(screen_position, _current_movie_scope)

func _on_movie_create_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "电影已添加"
		_clear_runtime_error()
		_request_movies_list()
	else:
		_show_runtime_error("添加电影失败", _error_message(error))

func _on_movie_remove_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "电影已移除"
		_clear_runtime_error()
		_request_movies_list()
	else:
		_show_runtime_error("移除失败", _error_message(error))

func _on_movie_metadata_update_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "电影资料已保存"
		_clear_runtime_error()
		_request_movies_list()
	else:
		_show_runtime_error("保存电影资料失败", _error_message(error))

func _on_movie_metadata_completed(item_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary and not item_id.is_empty():
		movie_metadata_dialog.show_metadata(item_id, data as Dictionary)
	else:
		_show_runtime_error("读取电影资料失败", _error_message(error))

func _on_movie_backdrop_refresh_completed(_item_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "正在重新截取预览图…"
	else:
		_show_runtime_error("重新截取失败", _error_message(error))

func _on_movie_manage_action_requested(action: String) -> void:
	var plan: Dictionary = _movie_controller.resolve_manage_action(
		action, _movie_menu_target, _current_movie_scope
	)
	if plan.is_empty():
		return
	var item_id: String = str(plan.get("item_id", ""))
	match str(plan.get("kind", "")):
		"request_metadata":
			_movie_controller.request_metadata(item_id)
		"set_cover":
			_movie_controller.set_pending_cover_file_target(item_id)
			movie_cover_file_dialog.popup_centered_ratio(0.82)
		"set_backdrop":
			_movie_controller.set_pending_backdrop_file_target(item_id)
			movie_backdrop_file_dialog.popup_centered_ratio(0.82)
		"refresh_backdrop":
			if backend == null or not backend.is_connected_to_backend():
				_show_runtime_error("重新截取失败", "后端未连接")
				return
			backend_label.text = "正在重新截取…"
			_movie_controller.request_backdrop_refresh(item_id)
		"error":
			_show_runtime_error(str(plan.get("title", "")), str(plan.get("message", "")))
		"select_poster":
			tmdb_poster_dialog.show_for(
				item_id,
				int(plan.get("tmdb_id", 0)),
				str(plan.get("media_type", "movie")),
				str(plan.get("title", ""))
			)
		"tmdb_scrape":
			tmdb_dialog.show_for(item_id, str(plan.get("title", "")))
		"scrape_sgdb":
			game_scraper_dialog.show_for(item_id, str(plan.get("title", "")))
		"remove":
			_movie_controller.set_pending_remove_target(item_id)
			REMOVE_CONFIRMATION_PRESENTER_SCRIPT.new().show_movie_remove(
				movie_remove_confirm, str(plan.get("title", "Untitled"))
			)

func _on_movie_remove_confirmed() -> void:
	if not _movie_controller.has_pending_remove_target() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("移除失败", "后端未连接")
		return
	_movie_controller.request_pending_remove()

func _on_movie_cover_file_selected(path: String) -> void:
	if not _movie_controller.has_pending_cover_file_target() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("设置封面失败", "后端未连接")
		return
	_movie_controller.request_pending_cover_set(path)

func _on_movie_cover_set_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "封面已更新"
		_clear_runtime_error()
		movie_wall.mark_cover_reload_after_list()
		_request_movies_list()
	else:
		_show_runtime_error("设置封面失败", _error_message(error))

func _on_movie_metadata_save_requested(item_id: String, metadata: Dictionary) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("保存电影资料失败", "后端未连接")
		return
	var payload: Dictionary = metadata.duplicate(true)
	payload["id"] = item_id
	_movie_controller.request_metadata_update(payload)

func _on_movie_play_completed(ok: bool, data: Variant, error: Variant) -> void:
	# The MovieController marks a reply already_exited when the matching
	# movie.exited arrived before the movie.play response.
	if not ok:
		_resume_render_if_unowned()
		_show_runtime_error("播放失败", _error_message(error))
		return
	if not (data is Dictionary):
		_resume_render_if_unowned()
		return
	var response: Dictionary = data as Dictionary
	var movie_session_id: String = str(response.get("play_session_id", ""))
	if bool(response.get("monitorable", true)) and not bool(response.get("already_exited", false)):
		if _render_ownership.claim("movie", movie_session_id):
			_delayed_pause_render()
		else:
			_resume_render_if_unowned()
	else:
		_resume_render_if_unowned()

func _on_movie_double_clicked(movie: Dictionary) -> void:
	var item_id: String = str(movie.get("id", ""))
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("播放失败", "后端未连接")
		return
	_movie_controller.request_play(item_id)

func _on_archive_launch_requested(game: Dictionary) -> void:
	if str(game.get("id", "")).is_empty():
		archive_gallery.set_launch_result(false, "档案编号缺失")
		return
	if backend == null or not backend.is_connected_to_backend():
		archive_gallery.set_launch_result(false, "后端未连接")
		return
	if _game_controller.has_pending_play():
		archive_gallery.set_launch_result(false, "已有启动请求正在处理")
		return
	_on_game_double_clicked(game)
	if not _game_controller.has_pending_play():
		archive_gallery.set_launch_result(false, "请求未发送，请重试")

func _on_game_theme_requested(item_id: String) -> void:
	if _game_theme_controller != null:
		_game_theme_controller.activate_game(item_id)

func _on_game_theme_cleared() -> void:
	if _game_theme_controller != null:
		_game_theme_controller.clear_active_theme()
	elif game_section != null:
		game_section.reset_game_theme_palette()

# ── UI 音效（独立于主题音乐，可整体关闭）──
# 绑定的是详情页真正的进/出状态变化，不是鼠标事件，也不是 360ms 点击反馈。
func _on_detail_entered() -> void:
	UISfx.play(&"detail_in")

func _on_detail_exited() -> void:
	UISfx.play(&"detail_out")

func _on_game_theme_palette_changed(item_id: String, palette: Dictionary) -> void:
	if game_section == null or not game_section.is_detail_open():
		return
	if _game_theme_controller == null or _game_theme_controller.get_active_item_id() != item_id:
		return
	game_section.apply_game_theme_palette(palette)
	if window_chrome != null and window_chrome.has_method("apply_game_theme_palette"):
		window_chrome.apply_game_theme_palette(palette)

func _on_game_theme_palette_cleared() -> void:
	if game_section != null:
		game_section.reset_game_theme_palette()
	if window_chrome != null and window_chrome.has_method("reset_game_theme_palette"):
		window_chrome.reset_game_theme_palette()

func _on_game_double_clicked(game: Dictionary) -> void:
	var item_id: String = str(game.get("id", ""))
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("启动失败", "后端未连接")
		return
	# 等后台确认目标游戏进程（game.running）后才暂停渲染；
	# 不能把 Steam/Epic/Uplay 的启动壳当成游戏本体。
	# 详情页开着的话，先给按钮一个"启动中…"的即时反馈
	if game_section != null and game_section.is_detail_open():
		game_section.set_detail_launching(true)
	_game_controller.request_play(item_id)

func _reset_launch_button_after(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if game_section != null:
		game_section.set_detail_launching(false)

func _on_add_game_requested() -> void:
	if game_create_dialog == null:
		return
	if backend == null or not backend.is_connected_to_backend():
		# 后端未连接时仍然打开对话框（模拟器列表为空 → 模拟器模式被禁用）
		game_create_dialog.show_dialog([])
		return
	_emulator_controller.request_game_create_list()

func _on_emulators_for_game_create_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	var emus: Array = []
	if ok and data is Array:
		emus = data as Array
	else:
		_show_runtime_error("读取模拟器配置失败", _error_message(error))
	game_create_dialog.show_dialog(emus)

func _on_game_context_requested(game: Dictionary, position: Vector2) -> void:
	_game_menu_target = game
	if game_manage_menu != null:
		# Steam 游戏的时长从 Steam 读，手动改会被覆盖 → 不显示该项
		# 改满 2 次后也隐藏
		var source: String = str(game.get("source", "manual"))
		var edit_count: int = int(game.get("playtime_edit_count", 0))
		var can_edit: bool = (source != "steam") and (edit_count < 2)
		game_manage_menu.show_at(position, can_edit)

func _on_game_blank_context_requested(position: Vector2) -> void:
	if game_blank_menu != null:
		game_blank_menu.show_at(position)

func _on_game_manage_action(action: String) -> void:
	var game: Dictionary = _game_menu_target
	var plan: Dictionary = _game_controller.resolve_manage_action(action, _game_menu_target)
	if plan.is_empty():
		return
	var item_id: String = str(plan.get("item_id", ""))
	match str(plan.get("kind", "")):
		"scrape_sgdb":
			game_scraper_dialog.show_for(item_id, str(plan.get("query", "")))
		"steam_metadata":
			steam_search_dialog.show_for(item_id, str(plan.get("query", "")))
		"edit_metadata":
			if backend == null or not backend.is_connected_to_backend():
				_show_runtime_error("编辑资料失败", "后端未连接")
				return
			_game_controller.request_metadata(item_id)
		"paste_import":
			game_paste_import_dialog.show_for_item(item_id, str(game.get("title", "")))			
		"browse_game_dir":
			var dir: String = str(plan.get("path", ""))
			if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
				_show_runtime_error("浏览失败", "找不到游戏目录")
			else:
				OS.shell_open("file:///" + dir.replace("\\", "/").lstrip("/"))
			return
		"browse_assets_dir":
			var cover_dir: String = str(plan.get("path", ""))
			if cover_dir.is_empty() or not DirAccess.dir_exists_absolute(cover_dir):
				_show_runtime_error("浏览失败", "素材文件夹不存在（可能还没刮削素材）")
			else:
				OS.shell_open("file:///" + cover_dir.replace("\\", "/").lstrip("/"))
			return
		"edit_launch":
			if backend == null or not backend.is_connected_to_backend():
				_show_runtime_error("编辑启动设置失败", "后端未连接")
				return
			_game_controller.request_launch_metadata(item_id)
		"edit_playtime":
			playtime_edit_dialog.show_for(item_id, int(plan.get("playtime_seconds", 0)))
		"remove":
			_game_controller.set_pending_remove_target(item_id)
			REMOVE_CONFIRMATION_PRESENTER_SCRIPT.new().show_game_remove(
				game_remove_confirm, str(plan.get("title", "Untitled"))
			)

func _on_game_metadata_save_requested(item_id: String, metadata: Dictionary) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("保存游戏资料失败", "后端未连接")
		return
	var payload: Dictionary = metadata.duplicate(true)
	payload["id"] = item_id
	_game_controller.request_metadata_update(payload)

func _on_game_launch_save_requested(item_id: String, profile: Dictionary) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("保存启动设置失败", "后端未连接")
		return
	var payload: Dictionary = profile.duplicate(true)
	payload["id"] = item_id
	_game_controller.request_launch_update(payload)

func _on_playtime_save_requested(item_id: String, seconds: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("保存失败", "后端未连接")
		return
	_game_controller.request_playtime(item_id, seconds)

func _on_game_remove_confirmed() -> void:
	if not _game_controller.has_pending_remove_target() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("移除失败", "后端未连接")
		return
	_game_controller.request_pending_remove()

func _on_steam_search_requested(query: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("Steam 搜索失败", "后端未连接")
		return
	_game_controller.request_steam_manual_search(query)

func _on_steam_apply_requested(item_id: String, external_id: int) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	_game_controller.request_steam_manual_apply(item_id, external_id)

func _on_sgdb_search_requested(query: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		game_scraper_dialog.show_search_results([])
		_show_runtime_error("搜索失败", "后端未连接")
		return
	_game_controller.request_sgdb_search(query)

func _on_sgdb_assets_requested(sgdb_id: int, asset_type: String, batch_id: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		game_scraper_dialog.show_assets(asset_type, [], batch_id)
		return
	_game_controller.request_sgdb_assets(sgdb_id, asset_type, batch_id)

func _on_sgdb_asset_info_requested(url: String) -> void:
	if backend != null and backend.is_connected_to_backend():
		_game_controller.request_sgdb_asset_info(url)

func _on_sgdb_apply_requested(item_id: String, sgdb_id: int, asset_type: String, url: String, operation_id: String) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		game_scraper_dialog.on_apply_result(asset_type, operation_id, false, null)
		_show_runtime_error("应用素材失败", "后端未连接")
		return
	_game_controller.request_sgdb_apply(item_id, sgdb_id, asset_type, url, operation_id)

func _on_add_movie_lib_pressed() -> void:
	movie_lib_dir_dialog.popup_centered_ratio(0.82)

func _on_movie_lib_dir_selected(path: String) -> void:
	if path.is_empty():
		return
	if _current_movie_scope == "private":
		for existing in _movie_library_paths_private:
			if existing == path:
				return
		_movie_library_paths_private.append(path)
	else:
		for existing in _movie_library_paths:
			if existing == path:
				return
		_movie_library_paths.append(path)
	_save_movie_lib_paths()

func _on_remove_movie_lib(path: String) -> void:
	if _current_movie_scope == "private":
		var next_private: Array[String] = []
		for p in _movie_library_paths_private:
			if p != path:
				next_private.append(p)
		_movie_library_paths_private = next_private
	else:
		var next: Array[String] = []
		for p in _movie_library_paths:
			if p != path:
				next.append(p)
		_movie_library_paths = next
	_save_movie_lib_paths()

func _on_set_cover_folder_pressed() -> void:
	movie_cover_dir_dialog.popup_centered_ratio(0.82)

func _on_clear_cover_folder_pressed() -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	_system_settings_controller.request_movie_cover_folder(_current_movie_scope, "")

func _on_cover_folder_dir_selected(path: String) -> void:
	if path.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		return
	_system_settings_controller.request_movie_cover_folder(_current_movie_scope, path)

func _on_cover_folder_set_response(_request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary:
		var settings_data: Dictionary = data as Dictionary
		_movie_cover_folder_main = str(settings_data.get("movie_cover_folder_main", ""))
		_movie_cover_folder_private = str(settings_data.get("movie_cover_folder_private", ""))
		_rebuild_cover_folder_ui()
	else:
		_show_runtime_error("设置封面文件夹失败", _error_message(error))

func _on_covers_match_completed(ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary:
		var n: int = int((data as Dictionary).get("matched", 0))
		backend_label.text = "匹配完成 · %d 部" % n
		_clear_runtime_error()
		_request_movies_list()
	else:
		_show_runtime_error("匹配封面失败", _error_message(error))

func _on_match_local_covers_pressed() -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("匹配失败", "后端未连接")
		return
	_movie_controller.request_covers_match(_current_movie_scope)
	backend_label.text = "正在匹配封面…"

func _rebuild_cover_folder_ui() -> void:
	MOVIE_LIBRARY_SETTINGS_VIEW_BUILDER_SCRIPT.new().rebuild_cover_folder(
		_cover_folder_label, _cover_folder_title, _current_movie_scope,
		_movie_cover_folder_main, _movie_cover_folder_private
	)

# ---------------------------------------------------------------------------
# 模拟器配置

func _refresh_emulators() -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	_request_emulators_list()

func _rebuild_emulator_list() -> void:
	EMULATOR_LIST_VIEW_BUILDER_SCRIPT.new().rebuild(
		_emulator_list, _emulators, _theme_muted,
		_on_edit_emulator_pressed, _on_remove_emulator_pressed
	)

func _on_add_emulator_pressed() -> void:
	if emulator_edit_dialog != null:
		emulator_edit_dialog.show_new()

func _on_edit_emulator_pressed(emulator: Dictionary) -> void:
	if emulator_edit_dialog != null:
		emulator_edit_dialog.show_emulator(emulator)

func _on_emulator_save_requested(payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("保存模拟器配置失败", "后端未连接")
		return
	_emulator_controller.request_save(payload)

func _on_emulator_save_response(_request_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "模拟器配置已保存"
		_clear_runtime_error()
		_request_emulators_list()
	else:
		_show_runtime_error("保存模拟器配置失败", _error_message(error))

func _on_remove_emulator_pressed(emulator_id: String) -> void:
	if emulator_id.is_empty() or emulator_remove_confirm == null:
		return
	_emulator_remove_target = emulator_id
	_emulator_remove_title = emulator_id
	for entry in _emulators:
		if entry is Dictionary:
			var emulator: Dictionary = entry as Dictionary
			if str(emulator.get("id", "")) == emulator_id:
				_emulator_remove_title = str(emulator.get("name", emulator_id))
				break
	emulator_remove_confirm.dialog_text = (
		"确定移除模拟器配置《%s》吗？\n\n"
		+ "只会删除 G3 里的这条配置，不会删除模拟器本体或游戏文件。"
	) % _emulator_remove_title
	emulator_remove_confirm.popup_centered()

func _on_emulator_remove_confirmed() -> void:
	if _emulator_remove_target.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("移除模拟器配置失败", "后端未连接")
		return
	var emulator_id: String = _emulator_remove_target
	_emulator_remove_target = ""
	_emulator_remove_title = ""
	_emulator_controller.request_delete(emulator_id)

func _on_emulator_delete_response(_request_id: String, ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "模拟器配置已移除"
		_clear_runtime_error()
		_request_emulators_list()
	else:
		_show_runtime_error("移除模拟器配置失败", _error_message(error))

func _on_open_cover_tool_pressed() -> void:
	if cover_tool_dialog == null:
		return
	cover_tool_dialog.show_for(_current_movie_scope, _cover_tool_source_dir())

func _cover_tool_source_dir() -> String:
	# 源目录存在 settings 里。main 侧暂时用变量缓存，等 settings 加载后再同步
	return _cover_tool_source_dir_cached

var _cover_tool_source_dir_cached: String = ""

func _on_cover_tool_source_changed(path: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	_cover_tool_source_dir_cached = path
	_system_settings_controller.request_cover_tool_source(path)

func _on_cover_tool_scan(scope: String, overwrite: bool) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("扫描失败", "后端未连接")
		return
	var source_dir: String = _cover_tool_source_dir_cached
	if source_dir.is_empty():
		_show_runtime_error("扫描失败", "请先选择源封面目录")
		return
	if cover_tool_dialog != null:
		cover_tool_dialog.set_scan_running()
	if _cover_tool_controller.request_scan(scope, source_dir, overwrite).is_empty():
		_on_cover_tool_scan_completed(false, null, {"message": "请求发送失败"})

func _on_cover_tool_apply_all(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	if items.is_empty():
		return
	_cover_tool_controller.start_batch(items)

func _on_cover_tool_edit(item: Dictionary) -> void:
	_cover_tool_presentation.show_crop_editor(item)

func _on_cover_crop_apply(source_path: String, title: String, front_start_px: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	if _cover_tool_controller.request_crop_apply(source_path, title, front_start_px).is_empty():
		_show_runtime_error("应用失败", "请求发送失败")

func _save_movie_lib_paths() -> void:
	if backend == null or not backend.is_connected_to_backend():
		_rebuild_movie_lib_paths_ui()
		return
	var source: Array[String] = _movie_library_paths_private if _current_movie_scope == "private" else _movie_library_paths
	var payload: Array = []
	for p in source:
		payload.append(p)
	_system_settings_controller.request_movie_paths(_current_movie_scope, payload)
	_rebuild_movie_lib_paths_ui()

func _rebuild_movie_lib_paths_ui() -> void:
	MOVIE_LIBRARY_SETTINGS_VIEW_BUILDER_SCRIPT.new().rebuild_library_paths(
		movie_lib_paths_list, _lib_title_label, _current_movie_scope,
		_movie_library_paths, _movie_library_paths_private, _theme_muted,
		_on_remove_movie_lib
	)

func _on_movie_blank_action_requested(action: String) -> void:
	match action:
		"add_movie":
			_open_movie_create_dialog()
		"scan_library":
			_start_movie_scan()

func _on_game_blank_action_requested(action: String) -> void:
	match action:
		"add_game":
			_on_add_game_requested()
		"paste_import":
			game_paste_import_dialog.show_new()
		"scan_library":
			_open_library_scan_dialog()

func _open_library_scan_dialog() -> void:
	if library_scan_dialog == null:
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("扫描游戏库失败", "后端未连接")
		return
	_clear_runtime_error()
	library_scan_dialog.show_dialog()

func _on_library_scan_requested(tab_id: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("扫描游戏库失败", "后端未连接")
		return
	var label_text: String = ""
	match tab_id:
		"emulator":
			label_text = "正在扫描模拟器游戏…"
		"steam":
			label_text = "正在扫描 Steam 库…"
		"gog":
			label_text = "正在扫描 GOG 库…"
		"epic":
			label_text = "正在扫描 Epic 库…"
		"uplay":
			label_text = "正在扫描 Uplay 库…"
		"rockstar":
			label_text = "正在扫描 Rockstar 库…"
		"psn":
			label_text = "正在扫描 PSN 库…"					
		_:
			return
	var req_id: String = _library_scan_controller.start_scan(tab_id)
	if req_id.is_empty():
		return
	backend_label.text = label_text

func _on_library_scan_dialog_closed() -> void:
	# 对话框内部会自己清空 4 个 tab 的缓存
	pass

func _on_library_scan_import_requested(tab_id: String, items: Array) -> void:
	if tab_id == "emulator":
		_on_emulator_scan_import_requested(items)
		return
	if not ["steam", "gog", "epic", "uplay", "rockstar", "psn"].has(tab_id):
		return
	_on_platform_scan_import_requested(tab_id, items)

func _on_emulator_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var payloads: Array[Dictionary] = LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT.build("emulator", items)
	var skipped_existing: int = LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT.count_existing(items)

	var created: int = _library_scan_controller.start_emulator_import(payloads, skipped_existing)
	if created > 0:
		backend_label.text = "正在导入 %d 个游戏…" % created

func _on_platform_scan_import_requested(platform: String, items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		if platform != "psn":
			_show_runtime_error("导入失败", "后端未连接")
		return

	var payloads: Array[Dictionary] = LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT.build(platform, items)
	var skipped_existing: int = LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT.count_existing(items)
	var created: int = _library_scan_controller.start_platform_import(platform, payloads, skipped_existing)
	_library_scan_presentation.on_platform_import_started(platform, created)

func _on_paste_import_apply(payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("粘贴失败", "后端未连接")
		return
	var target: String = str(payload.get("target_item_id", ""))
	if target.is_empty():
		_game_controller.request_paste_create(GAME_PASTE_PAYLOAD_BUILDER_SCRIPT.build_create(payload))
	else:
		_game_controller.request_paste_update(GAME_PASTE_PAYLOAD_BUILDER_SCRIPT.build_update(payload))


func _on_game_create_requested(payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("添加游戏失败", "后端未连接")
		return
	_game_controller.request_create(payload)

func _start_movie_scan() -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("扫描失败", "后端未连接")
		return
	if _movie_library_paths.is_empty():
		_show_runtime_error("扫描失败", "未配置影视库文件夹（前往系统页面添加）")
		return
	backend_label.text = "正在扫描影视库…"
	_movie_controller.request_scan(_current_movie_scope)

func _on_movie_scan_completed(_scope: String, ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Dictionary:
		var r: Dictionary = data as Dictionary
		var added := int(r.get("added", 0))
		var updated := int(r.get("updated", 0))
		var offline := int(r.get("offline", 0))
		var total := int(r.get("total_found", 0))
		var msg := "发现 %d · 新增 %d · 更新 %d · 离线 %d" % [total, added, updated, offline]
		_show_runtime_error("扫描完成", msg)
		backend_label.text = "后端已连接"
		_request_movies_list()
	else:
		_show_runtime_error("扫描失败", _error_message(error))

func _on_tmdb_search_completed(ok: bool, data: Variant, error: Variant) -> void:
	if ok and data is Array:
		tmdb_dialog.show_results(data as Array)
	else:
		tmdb_dialog.show_results([])
		_show_runtime_error("TMDB 搜索失败", _error_message(error))

func _on_movie_backdrop_file_selected(path: String) -> void:
	if not _movie_controller.has_pending_backdrop_file_target() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("设置背景图失败", "后端未连接")
		return
	_movie_controller.request_pending_backdrop_set(path)

func _on_movie_backdrop_set_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "背景图已更新"
		_clear_runtime_error()
		_request_movies_list()
	else:
		_show_runtime_error("设置背景图失败", _error_message(error))

func _on_movie_episode_clicked(item_id: String, episode_id: String) -> void:
	if item_id.is_empty() or episode_id.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("播放失败", "后端未连接")
		return
	_movie_controller.request_play(item_id, episode_id)

func _try_restore_movie() -> void:
	if not (_movies_ready and _state_ready):
		return
	var rid: String = _restore_movie_id
	_restore_movie_id = ""
	if rid.is_empty():
		return
	var index: int = movie_wall.find_index_by_id(rid)
	if index >= 0:
		movie_wall.jump_to_index(index)

func _on_tmdb_search_requested(query: String, media_type: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("TMDB 搜索失败", "后端未连接")
		return
	_movie_controller.request_tmdb_search(query, media_type)

func _on_tmdb_apply_requested(item_id: String, tmdb_id: int, media_type: String) -> void:
	if item_id.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	_movie_controller.request_tmdb_apply(item_id, tmdb_id, media_type)

func _on_poster_list_requested(tmdb_id: int, media_type: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("读取海报列表失败", "后端未连接")
		return
	_movie_controller.request_poster_list(tmdb_id, media_type)

func _on_poster_thumb_requested(file_path: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		tmdb_poster_dialog.on_thumb_response(file_path, "")
		return
	var req_id: String = _movie_controller.request_poster_thumb(file_path)
	if req_id.is_empty():
		tmdb_poster_dialog.on_thumb_response(file_path, "")

func _on_poster_apply_requested(file_path: String) -> void:
	var item_id: String = str(_movie_menu_target.get("id", ""))
	if item_id.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用海报失败", "后端未连接")
		return
	_movie_controller.request_poster_apply(item_id, file_path)

func _on_tmdb_apply_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "TMDB 资料已应用"
		_clear_runtime_error()
		tmdb_dialog.hide()
		_request_movies_list()
	else:
		_show_runtime_error("应用失败", _error_message(error))

func _on_poster_list_completed(ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		var posters_raw = (data as Dictionary).get("posters", [])
		var posters: Array = posters_raw if posters_raw is Array else []
		tmdb_poster_dialog.show_poster_list(posters)
	else:
		tmdb_poster_dialog.show_poster_list([])

func _on_poster_thumb_completed(file_path: String, ok: bool, data: Variant, _error: Variant) -> void:
	if ok and data is Dictionary:
		var local_path: String = str((data as Dictionary).get("path", ""))
		tmdb_poster_dialog.on_thumb_response(file_path, local_path)
	else:
		tmdb_poster_dialog.on_thumb_response(file_path, "")

func _on_poster_apply_completed(ok: bool, _data: Variant, error: Variant) -> void:
	if ok:
		backend_label.text = "海报已更新"
		_clear_runtime_error()
		movie_wall.mark_cover_reload_after_list()
		tmdb_poster_dialog.set_apply_done()
		_request_movies_list()
	else:
		_show_runtime_error("应用海报失败", _error_message(error))

		
func _on_game_batch_remove(item_id: String) -> void:
	if backend != null and backend.is_connected_to_backend():
		_game_controller.request_batch_remove(item_id)

func _on_batch_scrape_requested(item_ids: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("批量刮削失败", "后端未连接")
		return
	
	var items: Array = []
	items = game_section.resolve_games_by_ids(item_ids)
				

		
		
	
	backend_label.text = "开始批量刮削 %d 个游戏…" % items.size()
	_steam_batch_scrape_coordinator.start(items)

func _on_steam_batch_search_requested(generation: int, item_id: String, title: String, remaining: int) -> void:
	backend_label.text = "正在搜索：%s（剩余 %d）" % [title, remaining]
	var request_id: String = _game_controller.request_steam_batch_search(title, item_id, generation)
	if request_id.is_empty():
		_steam_batch_scrape_coordinator.dispatch_failed(generation, item_id, "search")

func _on_steam_batch_apply_requested(generation: int, item_id: String, external_id: int) -> void:
	var request_id: String = _game_controller.request_steam_batch_apply(item_id, external_id, generation)
	if request_id.is_empty():
		_steam_batch_scrape_coordinator.dispatch_failed(generation, item_id, "apply")

func _on_steam_batch_finished(_generation: int) -> void:
	backend_label.text = "批量刮削完成！"
	_clear_runtime_error()
	_request_games_list()
