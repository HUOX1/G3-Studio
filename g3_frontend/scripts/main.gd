extends Node

const PRIVATE_ACCENT: Color = Color(0.95, 0.22, 0.72)
const PRIVATE_MUTED: Color = Color(0.78, 0.55, 0.68)
const PRIVATE_BASE_TOP: Color = Color(0.18, 0.04, 0.13)

const BACKEND_CLIENT_SCRIPT: Script = preload("res://scripts/backend_client.gd")
const AUDIO_LOADER: Script = preload("res://scripts/audio_file_loader.gd")
const NAVIGATION_DRAWER_SCRIPT: Script = preload("res://scripts/navigation_drawer.gd")
const WINDOW_CHROME_SCRIPT: Script = preload("res://scripts/window_chrome.gd")
const GAME_AMBIENT_SHADER: Shader = preload("res://shaders/game_ambient.gdshader")
const GAME_BLANK_MENU_SCRIPT: Script = preload("res://scripts/game_blank_menu.gd")
const GAME_CREATE_DIALOG_SCRIPT: Script = preload("res://scripts/game_create_dialog.gd")
const GAME_PASTE_IMPORT_DIALOG_SCRIPT: Script = preload("res://scripts/game_paste_import_dialog.gd")
const MOVIE_WALL_SCRIPT: Script = preload("res://scripts/movie_wall.gd")
const GAME_SECTION_SCRIPT: Script = preload("res://scripts/game_section.gd")
const SPATIAL_GALLERY_SCRIPT: Script = preload("res://scripts/spatial_gallery.gd")
const ARCHIVE_GALLERY_SCRIPT: Script = preload("res://scripts/archive_gallery.gd")
const MOVIE_CREATE_DIALOG_SCRIPT: Script = preload("res://scripts/movie_create_dialog.gd")
const MOVIE_MANAGE_MENU_SCRIPT: Script = preload("res://scripts/movie_manage_menu.gd")
const MOVIE_BLANK_MENU_SCRIPT: Script = preload("res://scripts/movie_blank_menu.gd")
const MOVIE_METADATA_DIALOG_SCRIPT: Script = preload("res://scripts/movie_metadata_dialog.gd")
const MOVIE_EPISODE_DRAWER_SCRIPT: Script = preload("res://scripts/movie_episode_drawer.gd")
const TMDB_DIALOG_SCRIPT: Script = preload("res://scripts/tmdb_search_dialog.gd")
const TMDB_POSTER_DIALOG_SCRIPT: Script = preload("res://scripts/tmdb_poster_dialog.gd")
const GAME_SCRAPER_DIALOG_SCRIPT: Script = preload("res://scripts/game_scraper_dialog.gd")
const LIBRARY_SCAN_DIALOG_SCRIPT: Script = preload("res://scripts/library_scan_dialog.gd")
const STEAM_SEARCH_DIALOG_SCRIPT: Script = preload("res://scripts/steam_search_dialog.gd")
const FONT_MANAGER_SCRIPT: Script = preload("res://scripts/font_manager.gd")
const FONTSET_EDITOR_SCRIPT: Script = preload("res://scripts/fontset_editor.gd")
const COVER_TOOL_DIALOG_SCRIPT: Script = preload("res://scripts/cover_tool_dialog.gd")
const COVER_CROP_DIALOG_SCRIPT: Script = preload("res://scripts/cover_crop_dialog.gd")
const GAME_METADATA_DIALOG_SCRIPT: Script = preload("res://scripts/game_metadata_dialog.gd")
const GAME_LAUNCH_DIALOG_SCRIPT: Script = preload("res://scripts/game_launch_dialog.gd")
const PLAYTIME_EDIT_DIALOG_SCRIPT: Script = preload("res://scripts/playtime_edit_dialog.gd")
const EMULATOR_EDIT_DIALOG_SCRIPT: Script = preload("res://scripts/emulator_edit_dialog.gd")

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
const XMB_SECTION_LABELS: Array[String] = ["游戏", "电影", "空间展厅", "游戏藏品室", "系统"]
const RUNTIME_MESSAGE_HOLD_SECONDS: float = 4.0
const RUNTIME_MESSAGE_FADE_SECONDS: float = 0.35

# ============================================================
# 电影信息区布局（调这里就对了）
# ============================================================

const TARGET_WINDOW_ASPECT: float = 16.0 / 9.0

# 信息区左边界：屏幕宽度的百分之多少（0.33 = 屏幕 33% 处开始）
const MOVIE_INFO_LEFT_RATIO: float = 0.33
# 信息区右边界：屏幕右侧留多少像素
const MOVIE_INFO_RIGHT_MARGIN: float = 60.0
# 标题固定位置：屏幕高度的百分之多少（不随预览图高度变化）
const MOVIE_TITLE_FIXED_RATIO: float = 0.11
# 简介固定位置：距屏幕底部留多少比例
const MOVIE_DESC_FIXED_RATIO: float = 0.20
# 年份距标题上方多少像素
const MOVIE_META_GAP_ABOVE_TITLE: float = 16.0
# 简介下方保留多少像素（给导航抽屉）
const MOVIE_DESC_BOTTOM_RESERVE: float = 20.0
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
var collection_world: Node3D
var camera: Camera3D
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var _game_ambient_mesh: MeshInstance3D
var _game_ambient_material: ShaderMaterial
var movie_wall
var game_section = null
var spatial_gallery = null
var archive_gallery = null
var game_blank_menu
var game_create_dialog
var game_paste_import_dialog
var _pending_paste_create_id: String = ""
var _pending_paste_update_id: String = ""
var _paste_target_item_id: String = ""
var _pending_games_id: String = ""
var _pending_game_create_id: String = ""
var _pending_emulators_for_create_id: String = ""
var _pending_game_play_id: String = ""
var game_scraper_dialog
var steam_search_dialog
var game_manage_menu
var _game_menu_target: Dictionary = {}
var game_metadata_dialog
var game_launch_dialog
var game_remove_confirm: ConfirmationDialog
var _pending_game_metadata_get_id: String = ""
var _pending_game_metadata_target_id: String = ""
var _pending_game_metadata_update_id: String = ""
var _pending_game_launch_get_id: String = ""
var _pending_game_launch_target_id: String = ""
var _pending_game_launch_update_id: String = ""
var _pending_game_remove_request_id: String = ""
var _pending_game_remove_id: String = ""
var playtime_edit_dialog
var _pending_playtime_set_id: String = ""
var _pending_steam_search_id: String = ""
var _pending_steam_apply_id: String = ""
var _steam_target_item_id: String = ""
var emulator_edit_dialog
var emulator_remove_confirm: ConfirmationDialog
var _emulator_list: VBoxContainer
var _emulators: Array = []
var _pending_emulators_list_id: String = ""
var _pending_emulator_save_id: String = ""
var _pending_emulator_delete_id: String = ""
var _emulator_remove_target: String = ""
var _emulator_remove_title: String = ""
var _scan_items_cache: Array = []
var _pending_game_scan_emulator_id: String = ""
var _pending_game_scan_create_ids: Array[String] = []
var _scan_import_total: int = 0
var _scan_import_done: int = 0
var _scan_import_added: int = 0
var _scan_import_errors: int = 0
var _scan_import_skipped: int = 0
var _steam_scan_items_cache: Array = []
var _pending_steam_scan_id: String = ""
var _pending_steam_scan_create_ids: Array[String] = []
var _steam_scan_import_total: int = 0
var _steam_scan_import_done: int = 0
var _steam_scan_import_added: int = 0
var _steam_scan_import_errors: int = 0
var _steam_scan_import_skipped: int = 0
var _gog_scan_items_cache: Array = []
var _pending_gog_scan_id: String = ""
var _pending_gog_scan_create_ids: Array[String] = []
var _gog_scan_import_total: int = 0
var _gog_scan_import_done: int = 0
var _gog_scan_import_added: int = 0
var _gog_scan_import_errors: int = 0
var _gog_scan_import_skipped: int = 0
var _epic_scan_items_cache: Array = []
var _pending_epic_scan_id: String = ""
var _pending_epic_scan_create_ids: Array[String] = []
var _epic_scan_import_total: int = 0
var _epic_scan_import_done: int = 0
var _epic_scan_import_added: int = 0
var _epic_scan_import_errors: int = 0
var _epic_scan_import_skipped: int = 0
var _uplay_scan_items_cache: Array = []
var _pending_uplay_scan_id: String = ""
var _pending_uplay_scan_create_ids: Array[String] = []
var _uplay_scan_import_total: int = 0
var _uplay_scan_import_done: int = 0
var _uplay_scan_import_added: int = 0
var _uplay_scan_import_errors: int = 0
var _uplay_scan_import_skipped: int = 0
var _rockstar_scan_items_cache: Array = []
var _pending_rockstar_scan_id: String = ""
var _pending_rockstar_scan_create_ids: Array[String] = []
var _rockstar_scan_import_total: int = 0
var _rockstar_scan_import_done: int = 0
var _rockstar_scan_import_added: int = 0
var _rockstar_scan_import_errors: int = 0
var _rockstar_scan_import_skipped: int = 0
var _psn_scan_items_cache: Array = []
var _pending_psn_scan_id: String = ""
var _pending_psn_scan_create_ids: Array[String] = []
var _psn_scan_import_total: int = 0
var _psn_scan_import_done: int = 0
var _psn_scan_import_added: int = 0
var _psn_scan_import_errors: int = 0
var _psn_scan_import_skipped: int = 0
# 合并后的「扫描游戏库」对话框（5 个 tab）
var library_scan_dialog
var _pending_sgdb_search_id: String = ""
var _pending_sgdb_assets_ids: Dictionary = {}
var _pending_sgdb_apply_ids: Dictionary = {}
var _sgdb_target_item_id: String = ""
var xmb_buttons: Array[Button] = []
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
var _pending_movies_id: String = ""
var _pending_theme_id: String = ""
var _pending_state_id: String = ""
var _pending_settings_id: String = ""
var _pending_themes_id: String = ""
var _pending_theme_switch_id: String = ""
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
var _theme_secondary: Color = Color(0.25, 0.55, 0.90, 1.0)
var _theme_base_top: Color = Color(0.05, 0.28, 0.32, 1.0)
var _audio_tween: Tween
var _runtime_message_tween: Tween
var _runtime_message_generation: int = 0
var _window_mode_before_gameplay: int = Window.MODE_WINDOWED
var _window_borderless_before_gameplay: bool = true
var _window_size_before_gameplay: Vector2i = Vector2i(1600, 900)
var _window_position_before_gameplay: Vector2i = Vector2i.ZERO
var _app_version_label: Label
var _pending_app_info_id: String = ""
var fontset_option: OptionButton                # 电影字体组别下拉
var fontset_option_games: OptionButton          # 游戏字体组别下拉
var _fontset_ids: Array[String] = []            # 电影组别 id
var _fontset_ids_games: Array[String] = []      # 游戏组别 id
var _pending_fontsets_list_id: String = ""
var _pending_fontset_switch_id: String = ""
var _pending_fontset_switch_id_games: String = ""
var movie_info_title: Label
var movie_info_meta: Label
var movie_info_genres: Label
var movie_desc_scroll: ScrollContainer
var movie_desc_label: Label
var movie_create_dialog
var movie_manage_menu
var movie_blank_menu
var _pending_movie_scan_id: String = ""
var _movie_menu_target: Dictionary = {}
var _selected_movie: Dictionary = {}
var _current_movie_scope: String = "main"
var _pending_movie_remove_request_id: String = ""
var _pending_movie_remove_id: String = ""
var movie_remove_confirm: ConfirmationDialog
var movie_cover_file_dialog: FileDialog
var _pending_movie_cover_request_id: String = ""
var _pending_movie_cover_item_id: String = ""
var movie_metadata_dialog
var movie_episode_drawer
var _episode_drawer_generation: int = 0
var movie_backdrop_file_dialog: FileDialog
var _pending_movie_backdrop_refresh_id: String = ""
var _pending_backdrop_changed: bool = false
var _pending_movie_backdrop_set_id: String = ""
var _pending_movie_backdrop_set_item_id: String = ""
var _pending_movie_metadata_get_id: String = ""
var _pending_movie_metadata_update_id: String = ""
var _pending_movie_metadata_target_id: String = ""
var _force_reload_covers_on_next_list: bool = false
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
var _pending_cover_folder_set_id: String = ""
var _pending_cover_match_id: String = ""
var cover_crop_dialog
var cover_tool_dialog
var _pending_cover_tool_source_id: String = ""
var _pending_cover_tool_scan_id: String = ""
var _pending_cover_tool_apply_ids: Array[String] = []
var _cover_tool_apply_queue: Array = []
var _cover_tool_apply_done: int = 0
var _cover_tool_apply_failed: int = 0
var _pending_set_paths_id: String = ""
var movie_lib_dir_dialog: FileDialog
var _pending_movie_create_id: String = ""
var _pending_movie_play_id: String = ""
var _section_fade: ColorRect
var _section_ready: bool = false
var _pending_section: int = -1
var tmdb_dialog
var _pending_tmdb_search_id: String = ""
var _pending_tmdb_apply_id: String = ""
var _tmdb_target_item_id: String = ""
var tmdb_poster_dialog
var _pending_poster_list_id: String = ""
var _pending_poster_thumb_ids: Dictionary = {}
var _pending_poster_apply_id: String = ""
var _delayed_pause_generation: int = 0
var _bottom_hot_zone: Control
var _bottom_arrow: Label
var _hidden_layer: Control
var _info_offset: float = 0.0
var _info_offset_target: float = 0.0
var _info_expanded: bool = false
var _hidden_tagline: Label
var font_manager
var _ui_root: Control
var _pending_fontset_get_id: String = ""
var _pending_fontset_get_id_games: String = ""
var _fontset_id: String = "default"                 # 电影字体组别
var _fontset_id_games: String = "default"           # 游戏字体组别
var fontset_editor
var fontset_editor_btn: Button                      # "编辑…"（电影，在总览页）
var fontset_editor_btn_games: Button                # "编辑…"（游戏，在总览页）
var fontset_editor_back_btn: Button                 # 编辑器内"← 返回字体组别"
var _fontset_editor_scope: String = "movies"        # 编辑器当前 scope
var fontset_entry_btn: Button                       # 主系统页"字体组别…"入口
var fontset_home_root: VBoxContainer                # 字体组别总览页
var fontset_home_back_btn: Button                   # 总览页"← 返回设置"
var system_home_root: VBoxContainer
var _fontset_editor_open: bool = false
var _pending_fonts_list_id: String = ""
var _pending_fontsets_save_id: String = ""
var _pending_fontsets_save_id_games: String = ""
var _pending_fontsets_create_id: String = ""
var _pending_fontsets_create_id_games: String = ""
var _pending_fontsets_rename_id: String = ""
var _pending_fontsets_rename_id_games: String = ""
var _pending_fontsets_delete_id: String = ""
var _pending_fontsets_delete_id_games: String = ""
var _system_fonts: Array = []
var _fontsets_cache: Array = []
var _batch_scrape_queue: Array = []
var _is_batch_scraping: bool = false
var _current_batch_item: Dictionary = {}

func _ready() -> void:
	var app_window := get_window()
	if app_window != null:
		app_window.borderless = true
		app_window.min_size = Vector2i(1244, 700)
		app_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		app_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		call_deferred("_apply_startup_window_mode")
		app_window.mouse_passthrough = false
		app_window.always_on_top = false
		app_window.unfocusable = false
	_build_3d_world()
	_build_ui()
	_build_backend()
	_set_section(_read_local_start_section())
	_section_ready = true
	backend.connect_backend()
	set_process(true)
	call_deferred("_layout_system_panel")
	get_window().size_changed.connect(_on_window_resized)
	

func _read_local_window_mode() -> String:
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if local_app_data.is_empty():
		return "windowed"
	var path = local_app_data + "/G3/settings.json"
	if not FileAccess.file_exists(path):
		return "windowed"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "windowed"
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return "windowed"
	var mode = str(parsed.get("window_mode", "windowed")).to_lower()
	return "fullscreen" if mode == "fullscreen" else "windowed"

func _apply_startup_window_mode() -> void:
	_apply_window_mode(_read_local_window_mode())

func _apply_window_mode(mode: String) -> void:
	var win := get_window()
	if win == null:
		return
	win.borderless = true
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_set_windowed_size")
	_on_window_mode_changed()

func _set_windowed_size() -> void:
	var win := get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return
	win.size = Vector2i(1244, 700)
	var screen_size := DisplayServer.screen_get_size()
	win.position = Vector2i(
		maxi(0, (screen_size.x - 1244) / 2),
		maxi(0, (screen_size.y - 700) / 2)
	)

func _on_window_mode_changed() -> void:
	var win := get_window()
	if win == null:
		return
	var mode := win.mode
	var is_fullscreen: bool = (
		mode == Window.MODE_FULLSCREEN
		or mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	)
	if window_chrome != null:
		window_chrome.visible = not is_fullscreen

func _read_local_start_section() -> int:
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if local_app_data.is_empty():
		return 0
	var path = local_app_data + "/G3/settings.json"
	if not FileAccess.file_exists(path):
		return 0
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return 0
	var section = str(parsed.get("default_start_section", "games")).to_upper()
	var idx = XMB_SECTIONS.find(section)
	return idx if idx >= 0 else 0

func _build_3d_world() -> void:
	collection_world = Node3D.new()
	collection_world.name = "CollectionWorld"
	add_child(collection_world)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 7.2)
	camera.current = true
	collection_world.add_child(camera)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.46, 0.52, 0.56, 1.0)
	environment.ambient_light_energy = 0.08
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.18
	environment.ssao_intensity = 1.10

	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.8
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 1.0
	environment.glow_hdr_scale = 2.0
	environment.glow_hdr_luminance_cap = 12.0
	environment.set_glow_level(1, 0.0)
	environment.set_glow_level(2, 0.5)
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 1.0)
	environment.set_glow_level(5, 0.5)
	environment.set_glow_level(6, 0.0)
	world_environment.environment = environment
	collection_world.add_child(world_environment)

	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-24.0, -34.0, 0.0)
	key_light.light_energy = 0.38
	key_light.light_color = Color(0.94, 0.98, 1.0, 1.0)
	collection_world.add_child(key_light)

	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-8.0, 38.0, 0.0)
	fill_light.light_energy = 0.18
	fill_light.light_color = Color(0.62, 0.88, 1.0, 1.0)
	collection_world.add_child(fill_light)

	rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(12.0, 148.0, 0.0)
	rim_light.light_energy = 0.38
	rim_light.light_color = _theme_accent.lerp(Color.WHITE, 0.40)
	collection_world.add_child(rim_light)
	# ── 游戏板块背景 ──
	_game_ambient_mesh = MeshInstance3D.new()
	_game_ambient_mesh.name = "GameAmbient"
	_game_ambient_mesh.position = Vector3(0.0, 0.0, -6.0)
	var game_quad := QuadMesh.new()
	_game_ambient_mesh.mesh = game_quad
	_game_ambient_material = ShaderMaterial.new()
	_game_ambient_material.shader = GAME_AMBIENT_SHADER
	_game_ambient_mesh.material_override = _game_ambient_material
	collection_world.add_child(_game_ambient_mesh)
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
	game_section.add_game_requested.connect(_on_add_game_requested)
	game_section.game_context_requested.connect(_on_game_context_requested)
	game_section.blank_context_requested.connect(_on_game_blank_context_requested)
	game_section.game_removed.connect(_on_game_batch_remove)
	game_section.batch_scrape_requested.connect(_on_batch_scrape_requested)

	spatial_gallery = SPATIAL_GALLERY_SCRIPT.new()
	spatial_gallery.name = "SpatialGallery"
	collection_world.add_child(spatial_gallery)
	spatial_gallery.configure(camera)
	spatial_gallery.game_double_clicked.connect(_on_game_double_clicked)
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
	var dist: float = absf(camera.global_position.z - _game_ambient_mesh.global_position.z)
	var half_h: float = tan(deg_to_rad(camera.fov * 0.5)) * dist
	var aspect: float = vp.x / vp.y
	var overscan: float = 1.02
	var quad: QuadMesh = _game_ambient_mesh.mesh as QuadMesh
	quad.size = Vector2(
		half_h * 2.0 * aspect * overscan,
		half_h * 2.0 * overscan
	)

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
		xmb_buttons.append(button)
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

	# ── 字体组别总览页（Level 2）──
	fontset_home_root = VBoxContainer.new()
	fontset_home_root.add_theme_constant_override("separation", 12)
	fontset_home_root.size_flags_horizontal = Control.SIZE_FILL
	fontset_home_root.visible = false
	system_panel.add_child(fontset_home_root)

	var fs_home_title := Label.new()
	fs_home_title.text = "字体组别"
	fs_home_title.add_theme_font_size_override("font_size", 22)
	fontset_home_root.add_child(fs_home_title)

	var fs_home_hint := Label.new()
	fs_home_hint.text = "电影和游戏各自独立，一个字体组别只作用于一个版块。"
	fs_home_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fs_home_hint.add_theme_font_size_override("font_size", 12)
	fs_home_hint.add_theme_color_override("font_color", _theme_muted)
	fontset_home_root.add_child(fs_home_hint)

	# 电影行
	var fs_movie_label := Label.new()
	fs_movie_label.text = "电影"
	fs_movie_label.add_theme_font_size_override("font_size", 16)
	fontset_home_root.add_child(fs_movie_label)

	var fs_movie_row := HBoxContainer.new()
	fs_movie_row.add_theme_constant_override("separation", 10)
	fontset_home_root.add_child(fs_movie_row)

	fontset_option = OptionButton.new()
	fontset_option.custom_minimum_size = Vector2(280.0, 40.0)
	fontset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fontset_option.fit_to_longest_item = false
	fontset_option.item_selected.connect(_on_fontset_selected)
	fs_movie_row.add_child(fontset_option)

	fontset_editor_btn = Button.new()
	fontset_editor_btn.text = "编辑…"
	fontset_editor_btn.custom_minimum_size = Vector2(100.0, 40.0)
	fontset_editor_btn.pressed.connect(_on_fontset_editor_toggle.bind("movies"))
	fs_movie_row.add_child(fontset_editor_btn)

	# 游戏行
	var fs_game_label := Label.new()
	fs_game_label.text = "游戏"
	fs_game_label.add_theme_font_size_override("font_size", 16)
	fontset_home_root.add_child(fs_game_label)

	var fs_game_row := HBoxContainer.new()
	fs_game_row.add_theme_constant_override("separation", 10)
	fontset_home_root.add_child(fs_game_row)

	fontset_option_games = OptionButton.new()
	fontset_option_games.custom_minimum_size = Vector2(280.0, 40.0)
	fontset_option_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fontset_option_games.fit_to_longest_item = false
	fontset_option_games.item_selected.connect(_on_fontset_selected_games)
	fs_game_row.add_child(fontset_option_games)

	fontset_editor_btn_games = Button.new()
	fontset_editor_btn_games.text = "编辑…"
	fontset_editor_btn_games.custom_minimum_size = Vector2(100.0, 40.0)
	fontset_editor_btn_games.pressed.connect(_on_fontset_editor_toggle.bind("games"))
	fs_game_row.add_child(fontset_editor_btn_games)

	# 返回主设置
	fontset_home_back_btn = Button.new()
	fontset_home_back_btn.text = "← 返回设置"
	fontset_home_back_btn.custom_minimum_size = Vector2(320.0, 36.0)
	fontset_home_back_btn.size_flags_horizontal = Control.SIZE_FILL
	fontset_home_back_btn.pressed.connect(_on_fontset_home_back)
	fontset_home_root.add_child(fontset_home_back_btn)

	var system_editor_root := VBoxContainer.new()
	system_editor_root.add_theme_constant_override("separation", 8)
	system_editor_root.size_flags_horizontal = Control.SIZE_FILL
	system_editor_root.visible = false
	system_panel.add_child(system_editor_root)

	var window_mode_label := Label.new()
	window_mode_label.text = "启动窗口模式"
	window_mode_label.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(window_mode_label)
	window_mode_option = OptionButton.new()
	window_mode_option.custom_minimum_size = Vector2(320.0, 42.0)
	window_mode_option.size_flags_horizontal = Control.SIZE_FILL
	window_mode_option.add_item("窗口（最小尺寸）")
	window_mode_option.add_item("全屏")
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	system_home_root.add_child(window_mode_option)

	var exit_button: Button = Button.new()
	exit_button.text = "退出 G3"
	exit_button.custom_minimum_size = Vector2(320.0, 46.0)
	exit_button.size_flags_horizontal = Control.SIZE_FILL
	exit_button.pressed.connect(_exit_application)
	system_home_root.add_child(exit_button)

	var theme_label := Label.new()
	theme_label.text = "主题"
	theme_label.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(theme_label)
	theme_option = OptionButton.new()
	theme_option.custom_minimum_size = Vector2(320.0, 42.0)
	theme_option.size_flags_horizontal = Control.SIZE_FILL
	theme_option.item_selected.connect(_on_theme_selected)
	system_home_root.add_child(theme_option)

	# ── 字体组别入口（主 System 页只留一个按钮）──
	var fontset_entry_label := Label.new()
	fontset_entry_label.text = "字体组别"
	fontset_entry_label.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(fontset_entry_label)

	fontset_entry_btn = Button.new()
	fontset_entry_btn.text = "字体组别…"
	fontset_entry_btn.custom_minimum_size = Vector2(320.0, 36.0)
	fontset_entry_btn.size_flags_horizontal = Control.SIZE_FILL
	fontset_entry_btn.pressed.connect(_on_fontset_entry_pressed)
	system_home_root.add_child(fontset_entry_btn)

	var start_label := Label.new()
	start_label.text = "默认启动板块"
	start_label.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(start_label)
	default_section_option = OptionButton.new()
	default_section_option.custom_minimum_size = Vector2(320.0, 42.0)
	default_section_option.size_flags_horizontal = Control.SIZE_FILL
	for label: String in XMB_SECTION_LABELS:
		default_section_option.add_item(label)
	default_section_option.item_selected.connect(_on_default_start_section_selected)
	system_home_root.add_child(default_section_option)

	_lib_title_label = Label.new()
	_lib_title_label.text = "影视库文件夹（主库）"
	_lib_title_label.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(_lib_title_label)

	movie_lib_paths_list = VBoxContainer.new()
	movie_lib_paths_list.add_theme_constant_override("separation", 4)
	system_home_root.add_child(movie_lib_paths_list)

	var add_lib_button := Button.new()
	add_lib_button.text = "添加文件夹…"
	add_lib_button.custom_minimum_size = Vector2(320.0, 36.0)
	add_lib_button.size_flags_horizontal = Control.SIZE_FILL
	add_lib_button.pressed.connect(_on_add_movie_lib_pressed)
	system_home_root.add_child(add_lib_button)

	# ── 封面文件夹（随库切换） ──
	_cover_folder_title = Label.new()
	_cover_folder_title.text = "封面文件夹（主库）"
	_cover_folder_title.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(_cover_folder_title)

	_cover_folder_label = Label.new()
	_cover_folder_label.text = "（未设置）"
	_cover_folder_label.add_theme_font_size_override("font_size", 12)
	_cover_folder_label.add_theme_color_override("font_color", _theme_muted)
	_cover_folder_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	system_home_root.add_child(_cover_folder_label)

	var cover_btn_row := HBoxContainer.new()
	cover_btn_row.add_theme_constant_override("separation", 8)
	system_home_root.add_child(cover_btn_row)

	var set_cover_btn := Button.new()
	set_cover_btn.text = "选择封面文件夹…"
	set_cover_btn.custom_minimum_size = Vector2(200.0, 36.0)
	set_cover_btn.pressed.connect(_on_set_cover_folder_pressed)
	cover_btn_row.add_child(set_cover_btn)

	var clear_cover_btn := Button.new()
	clear_cover_btn.text = "清除"
	clear_cover_btn.custom_minimum_size = Vector2(80.0, 36.0)
	clear_cover_btn.pressed.connect(_on_clear_cover_folder_pressed)
	cover_btn_row.add_child(clear_cover_btn)

	var match_cover_btn := Button.new()
	match_cover_btn.text = "用封面文件夹匹配当前库"
	match_cover_btn.custom_minimum_size = Vector2(320.0, 36.0)
	match_cover_btn.size_flags_horizontal = Control.SIZE_FILL
	match_cover_btn.pressed.connect(_on_match_local_covers_pressed)
	system_home_root.add_child(match_cover_btn)

	var cover_tool_btn := Button.new()
	cover_tool_btn.text = "封面裁剪工具…"
	cover_tool_btn.custom_minimum_size = Vector2(320.0, 36.0)
	cover_tool_btn.size_flags_horizontal = Control.SIZE_FILL
	cover_tool_btn.pressed.connect(_on_open_cover_tool_pressed)
	system_home_root.add_child(cover_tool_btn)

	# ── 模拟器 ──
	var emulator_title := Label.new()
	emulator_title.text = "模拟器"
	emulator_title.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(emulator_title)

	_emulator_list = VBoxContainer.new()
	_emulator_list.add_theme_constant_override("separation", 4)
	_emulator_list.size_flags_horizontal = Control.SIZE_FILL
	system_home_root.add_child(_emulator_list)

	var add_emulator_btn := Button.new()
	add_emulator_btn.text = "+ 添加模拟器"
	add_emulator_btn.custom_minimum_size = Vector2(320.0, 36.0)
	add_emulator_btn.size_flags_horizontal = Control.SIZE_FILL
	add_emulator_btn.pressed.connect(_on_add_emulator_pressed)
	system_home_root.add_child(add_emulator_btn)

	var help_title := Label.new()
	help_title.text = "操作说明"
	help_title.add_theme_font_size_override("font_size", 16)
	system_home_root.add_child(help_title)
	hint_label = Label.new()
	hint_label.text = "滚轮 / ← → 选择    单击预览    双击播放    右键管理    Ctrl+Q 退出"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", _theme_muted)
	system_home_root.add_child(hint_label)

	fontset_editor_back_btn = Button.new()
	fontset_editor_back_btn.text = "← 返回字体组别"
	fontset_editor_back_btn.custom_minimum_size = Vector2(320.0, 36.0)
	fontset_editor_back_btn.size_flags_horizontal = Control.SIZE_FILL
	fontset_editor_back_btn.pressed.connect(_on_fontset_editor_back)
	system_editor_root.add_child(fontset_editor_back_btn)

	var editor_center := CenterContainer.new()
	editor_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	system_editor_root.add_child(editor_center)

	fontset_editor = FONTSET_EDITOR_SCRIPT.new()
	fontset_editor.set_font_manager(font_manager)
	fontset_editor.action_requested.connect(_on_fontset_manager_action)
	editor_center.add_child(fontset_editor)

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
	ui.add_child(navigation_drawer)

	movie_info_title = Label.new()
	movie_info_title.visible = false
	movie_info_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	movie_info_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(movie_info_title)

	movie_info_meta = Label.new()
	movie_info_meta.visible = false
	movie_info_meta.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68, 1))
	movie_info_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(movie_info_meta)

	movie_info_genres = Label.new()
	movie_info_genres.visible = false
	movie_info_genres.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 1))
	movie_info_genres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(movie_info_genres)

	movie_desc_scroll = ScrollContainer.new()
	movie_desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	movie_desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	movie_desc_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(movie_desc_scroll)

	var vsb: VScrollBar = movie_desc_scroll.get_v_scroll_bar()
	if vsb != null:
		vsb.custom_minimum_size = Vector2(0.0, 0.0)
		var empty_style := StyleBoxEmpty.new()
		vsb.add_theme_stylebox_override("scroll", empty_style)
		vsb.add_theme_stylebox_override("grabber", empty_style)
		vsb.add_theme_stylebox_override("grabber_highlight", empty_style)
		vsb.add_theme_stylebox_override("grabber_pressed", empty_style)

	var desc_vbox: VBoxContainer = VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	movie_desc_scroll.add_child(desc_vbox)

	movie_desc_label = Label.new()
	movie_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movie_desc_label.add_theme_font_size_override("font_size", 16)
	movie_desc_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80, 1))
	movie_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_vbox.add_child(movie_desc_label)

	_hidden_layer = Control.new()
	_hidden_layer.anchor_left = 0.0
	_hidden_layer.anchor_right = 1.0
	_hidden_layer.anchor_top = 1.0
	_hidden_layer.anchor_bottom = 1.0
	_hidden_layer.offset_top = 0.0
	_hidden_layer.offset_bottom = HIDDEN_LAYER_HEIGHT
	_hidden_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_hidden_layer)

	_hidden_tagline = Label.new()
	_hidden_tagline.text = ""
	_hidden_tagline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hidden_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hidden_tagline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hidden_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hidden_tagline.add_theme_font_size_override("font_size", 22)
	_hidden_tagline.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78, 0.75))
	_hidden_tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hidden_layer.add_child(_hidden_tagline)

	_bottom_hot_zone = Control.new()
	_bottom_hot_zone.anchor_left = 1.0
	_bottom_hot_zone.anchor_right = 1.0
	_bottom_hot_zone.anchor_top = 1.0
	_bottom_hot_zone.anchor_bottom = 1.0
	_bottom_hot_zone.offset_left = -BOTTOM_HOT_ZONE_WIDTH
	_bottom_hot_zone.offset_right = 0.0
	_bottom_hot_zone.offset_top = -BOTTOM_HOT_ZONE_HEIGHT
	_bottom_hot_zone.offset_bottom = 0.0
	_bottom_hot_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(_bottom_hot_zone)

	_bottom_arrow = Label.new()
	_bottom_arrow.text = "⌄"
	_bottom_arrow.anchor_left = 1.0
	_bottom_arrow.anchor_right = 1.0
	_bottom_arrow.anchor_top = 1.0
	_bottom_arrow.anchor_bottom = 1.0
	_bottom_arrow.offset_left = -40.0
	_bottom_arrow.offset_right = -14.0
	_bottom_arrow.offset_top = -34.0
	_bottom_arrow.offset_bottom = -10.0
	_bottom_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bottom_arrow.add_theme_font_size_override("font_size", 20)
	_bottom_arrow.modulate.a = 0.0
	_bottom_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_bottom_arrow)

	movie_create_dialog = MOVIE_CREATE_DIALOG_SCRIPT.new()
	movie_create_dialog.create_requested.connect(_on_movie_create_requested)
	add_child(movie_create_dialog)

	game_create_dialog = GAME_CREATE_DIALOG_SCRIPT.new()
	game_create_dialog.set_platforms(GAME_PLATFORMS)
	game_create_dialog.create_requested.connect(_on_game_create_requested)
	add_child(game_create_dialog)
	game_paste_import_dialog = GAME_PASTE_IMPORT_DIALOG_SCRIPT.new()
	game_paste_import_dialog.apply_requested.connect(_on_paste_import_apply)
	add_child(game_paste_import_dialog)

	var fade_layer: CanvasLayer = CanvasLayer.new()
	fade_layer.layer = 110
	add_child(fade_layer)
	movie_manage_menu = MOVIE_MANAGE_MENU_SCRIPT.new()
	movie_manage_menu.action_requested.connect(_on_movie_manage_action_requested)
	ui.add_child(movie_manage_menu)
	movie_blank_menu = MOVIE_BLANK_MENU_SCRIPT.new()
	movie_blank_menu.action_requested.connect(_on_movie_blank_action_requested)
	ui.add_child(movie_blank_menu)
	game_blank_menu = GAME_BLANK_MENU_SCRIPT.new()
	game_blank_menu.action_requested.connect(_on_game_blank_action_requested)
	ui.add_child(game_blank_menu)
	movie_remove_confirm = ConfirmationDialog.new()
	movie_remove_confirm.title = "移除电影档案"
	movie_remove_confirm.ok_button_text = "移除"
	movie_remove_confirm.cancel_button_text = "取消"
	movie_remove_confirm.confirmed.connect(_on_movie_remove_confirmed)
	add_child(movie_remove_confirm)
	movie_cover_file_dialog = FileDialog.new()
	movie_cover_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	movie_cover_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	movie_cover_file_dialog.filters = PackedStringArray([
		"*.jpg ; JPEG", "*.jpeg ; JPEG", "*.png ; PNG",
		"*.webp ; WebP", "*.bmp ; BMP",
	])
	movie_cover_file_dialog.size = Vector2i(920, 620)
	movie_cover_file_dialog.file_selected.connect(_on_movie_cover_file_selected)
	ui.add_child(movie_cover_file_dialog)
	movie_metadata_dialog = MOVIE_METADATA_DIALOG_SCRIPT.new()
	movie_metadata_dialog.save_requested.connect(_on_movie_metadata_save_requested)
	add_child(movie_metadata_dialog)
	movie_backdrop_file_dialog = FileDialog.new()
	movie_backdrop_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	movie_backdrop_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	movie_backdrop_file_dialog.filters = PackedStringArray([
		"*.jpg ; JPEG", "*.jpeg ; JPEG", "*.png ; PNG",
		"*.webp ; WebP", "*.bmp ; BMP",
	])
	movie_backdrop_file_dialog.size = Vector2i(920, 620)
	movie_backdrop_file_dialog.file_selected.connect(_on_movie_backdrop_file_selected)
	ui.add_child(movie_backdrop_file_dialog)
	movie_episode_drawer = MOVIE_EPISODE_DRAWER_SCRIPT.new()
	movie_episode_drawer.episode_clicked.connect(_on_movie_episode_clicked)
	ui.add_child(movie_episode_drawer)
	tmdb_dialog = TMDB_DIALOG_SCRIPT.new()
	tmdb_dialog.search_requested.connect(_on_tmdb_search_requested)
	tmdb_dialog.apply_requested.connect(_on_tmdb_apply_requested)
	add_child(tmdb_dialog)
	tmdb_poster_dialog = TMDB_POSTER_DIALOG_SCRIPT.new()
	tmdb_poster_dialog.poster_list_requested.connect(_on_poster_list_requested)
	tmdb_poster_dialog.thumb_requested.connect(_on_poster_thumb_requested)
	tmdb_poster_dialog.poster_apply_requested.connect(_on_poster_apply_requested)
	add_child(tmdb_poster_dialog)

	game_scraper_dialog = GAME_SCRAPER_DIALOG_SCRIPT.new()
	game_scraper_dialog.search_requested.connect(_on_sgdb_search_requested)
	game_scraper_dialog.assets_requested.connect(_on_sgdb_assets_requested)
	game_scraper_dialog.apply_requested.connect(_on_sgdb_apply_requested)
	add_child(game_scraper_dialog)

	# 旧的 4 个独立扫描对话框不再实例化（脚本保留在 scripts/ 下备用）
	library_scan_dialog = LIBRARY_SCAN_DIALOG_SCRIPT.new()
	library_scan_dialog.scan_requested.connect(_on_library_scan_requested)
	library_scan_dialog.import_requested.connect(_on_library_scan_import_requested)
	library_scan_dialog.closed.connect(_on_library_scan_dialog_closed)
	add_child(library_scan_dialog)

	var game_menu_script: Script = preload("res://scripts/game_manage_menu.gd")
	game_manage_menu = game_menu_script.new()
	game_manage_menu.action_requested.connect(_on_game_manage_action)
	ui.add_child(game_manage_menu)

	steam_search_dialog = STEAM_SEARCH_DIALOG_SCRIPT.new()
	steam_search_dialog.search_requested.connect(_on_steam_search_requested)
	steam_search_dialog.apply_requested.connect(_on_steam_apply_requested)
	add_child(steam_search_dialog)

	game_metadata_dialog = GAME_METADATA_DIALOG_SCRIPT.new()
	game_metadata_dialog.set_platforms(GAME_PLATFORMS)
	game_metadata_dialog.save_requested.connect(_on_game_metadata_save_requested)
	add_child(game_metadata_dialog)

	game_launch_dialog = GAME_LAUNCH_DIALOG_SCRIPT.new()
	game_launch_dialog.save_requested.connect(_on_game_launch_save_requested)
	add_child(game_launch_dialog)

	playtime_edit_dialog = PLAYTIME_EDIT_DIALOG_SCRIPT.new()
	playtime_edit_dialog.save_requested.connect(_on_playtime_save_requested)
	add_child(playtime_edit_dialog)

	game_remove_confirm = ConfirmationDialog.new()
	game_remove_confirm.title = "移除游戏档案"
	game_remove_confirm.ok_button_text = "移除"
	game_remove_confirm.cancel_button_text = "取消"
	game_remove_confirm.confirmed.connect(_on_game_remove_confirmed)
	add_child(game_remove_confirm)
	_section_fade = ColorRect.new()
	_section_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_section_fade.color = Color(0.02, 0.04, 0.06, 0.0)
	_section_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_section_fade.visible = false
	fade_layer.add_child(_section_fade)

func _layout_system_panel() -> void:
	if system_panel == null:
		return
	var win_size: Vector2 = get_viewport().get_visible_rect().size
	if win_size.x <= 0.0 or win_size.y <= 0.0:
		return
	var raw: float = min(win_size.x / SYSTEM_BASE_SIZE.x,
						 win_size.y / SYSTEM_BASE_SIZE.y)
	var scale_factor: float = clampf(raw, 0.62, 1.30)
	var font_factor: float = clampf(raw, 0.90, 1.30)
	var panel_w: float = SYSTEM_BASE_WIDTH * scale_factor
	if system_pad != null:
		system_pad.custom_minimum_size.x = panel_w
	_rescale_system_fonts(scale_factor, font_factor)

func _rescale_system_fonts(scale_factor: float, font_factor: float) -> void:
	for child in system_panel.get_children():
		_rescale_node(child, scale_factor, font_factor)

func _rescale_node(node: Node, scale_factor: float, font_factor: float) -> void:
	if node is Control:
		var ctrl := node as Control
		# 只有第一次才记录基准尺寸，防止动态加入的节点被反复缩放
		if not ctrl.has_meta("base_min_size"):
			ctrl.set_meta("base_min_size", ctrl.custom_minimum_size)
		var base_size: Vector2 = ctrl.get_meta("base_min_size")
		ctrl.custom_minimum_size = base_size * scale_factor

		if ctrl is Label:
			var lbl := ctrl as Label
			var base_font: int = lbl.get_meta("base_font_size", lbl.get_theme_font_size("font_size"))
			lbl.set_meta("base_font_size", base_font)
			lbl.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is Button:
			var btn := ctrl as Button
			var base_font: int = btn.get_meta("base_font_size", btn.get_theme_font_size("font_size"))
			btn.set_meta("base_font_size", base_font)
			btn.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is OptionButton:
			var opt := ctrl as OptionButton
			var base_font: int = opt.get_meta("base_font_size", opt.get_theme_font_size("font_size"))
			opt.set_meta("base_font_size", base_font)
			opt.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is LineEdit:
			var le := ctrl as LineEdit
			var base_font: int = le.get_meta("base_font_size", le.get_theme_font_size("font_size"))
			le.set_meta("base_font_size", base_font)
			le.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))

	for child in node.get_children():
		_rescale_node(child, scale_factor, font_factor)

func _on_window_resized() -> void:
	call_deferred("_enforce_window_aspect")

func _enforce_window_aspect() -> void:
	var win: Window = get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return
	var sz: Vector2i = win.size
	if sz.y <= 0:
		return
	var current_ratio: float = float(sz.x) / float(sz.y)
	if absf(current_ratio - TARGET_WINDOW_ASPECT) < 0.005:
		return
	var new_height: int = int(round(float(sz.x) / TARGET_WINDOW_ASPECT))
	if new_height < 400:
		new_height = 400
	win.size = Vector2i(sz.x, new_height)

func _build_backend() -> void:
	backend = BACKEND_CLIENT_SCRIPT.new()
	add_child(backend)
	backend.connected.connect(_on_backend_connected)
	backend.disconnected.connect(_on_backend_disconnected)
	backend.response_received.connect(_on_backend_response)
	backend.event_received.connect(_on_backend_event)

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
			game_section.toggle_batch_mode(not game_section._batch_mode)
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
	if spatial_gallery != null:
		spatial_gallery.set_section_visible(section == "COMICS")
	if archive_gallery != null:
		archive_gallery.set_section_visible(section == "MUSIC")
	system_root.visible = section == "SYSTEM"

	if _bottom_hot_zone != null:
		_bottom_hot_zone.visible = is_movies
	if _bottom_arrow != null:
		_bottom_arrow.visible = is_movies
	if _hidden_layer != null:
		_hidden_layer.visible = is_movies
	placeholder_label.visible = false
	backend_label.visible = section == "SYSTEM"
	fps_label.visible = section == "SYSTEM"
	hint_label.visible = section == "SYSTEM"
	runtime_error_label.visible = section == "SYSTEM" and not runtime_error_label.text.is_empty()
	var is_movies_main: bool = (section == "MOVIES") and (_current_movie_scope == "main")
	var is_movies_private: bool = (section == "MOVIES") and (_current_movie_scope == "private")
	if navigation_drawer != null:
		navigation_drawer.set_active_section(section)
		if is_movies_main:
			navigation_drawer.set_theme_colors(
				Color(0.88, 0.66, 0.36),
				Color(0.75, 0.65, 0.50)
			)
		elif is_movies_private:
			navigation_drawer.set_theme_colors(PRIVATE_ACCENT, PRIVATE_MUTED)
		elif is_games:
			navigation_drawer.set_theme_colors(
				Color(0.50, 0.72, 0.95),
				Color(0.55, 0.65, 0.78)
			)
		else:
			navigation_drawer.set_theme_colors(_theme_accent, _theme_muted)
	if placeholder_label.visible:
		placeholder_label.text = _section_label(section) + "  /  当前仅保留模块入口"
	_refresh_movie_info_visibility()
	if window_chrome != null:
		if is_movies_main:
			window_chrome.set_theme_colors(
				_theme_text,
				Color(0.75, 0.65, 0.50),
				Color(0.88, 0.66, 0.36),
				Color(0.08, 0.05, 0.03)
			)
		elif is_movies_private:
			window_chrome.set_theme_colors(
				_theme_text,
				PRIVATE_MUTED,
				PRIVATE_ACCENT,
				PRIVATE_BASE_TOP
			)
		elif is_games:
			window_chrome.set_theme_colors(
				_theme_text,
				Color(0.55, 0.65, 0.78),    # muted：灰蓝
				Color(0.50, 0.72, 0.95),    # accent：亮蓝
				Color(0.08, 0.12, 0.18)     # base：明显的深蓝灰
			)
		else:
			window_chrome.set_theme_colors(
				_theme_text,
				_theme_muted,
				_theme_accent,
				_theme_base_top
			)
	if movie_wall != null:
		movie_wall.set_ambient_palette("private" if is_movies_private else "main")
	# 私库下关闭 glow + 暖色调光，避免品红背景衬得卡片发白
	if collection_world != null:
		var env_node: WorldEnvironment = null
		for child in collection_world.get_children():
			if child is WorldEnvironment:
				env_node = child
				break
		if env_node != null and env_node.environment != null:
			env_node.environment.glow_enabled = not is_movies_private
	# 灯光：私库用暖白/品红，主库用冷白/青
	if key_light != null:
		if is_movies_private:
			key_light.light_color = Color(1.0, 0.85, 0.90)
		else:
			key_light.light_color = Color(0.94, 0.98, 1.0)
	if fill_light != null:
		if is_movies_private:
			fill_light.light_color = Color(0.95, 0.60, 0.75)
		else:
			fill_light.light_color = Color(0.62, 0.88, 1.0)
	if rim_light != null:
		if is_movies_private:
			rim_light.light_color = Color(0.92, 0.40, 0.70)
		else:
			rim_light.light_color = _theme_accent.lerp(Color.WHITE, 0.55)
	if navigation_drawer != null and navigation_drawer.has_method("set_long_press_color"):
		if _current_movie_scope == "main":
			navigation_drawer.set_long_press_color(PRIVATE_ACCENT)
		else:
			navigation_drawer.set_long_press_color(Color(0.88, 0.66, 0.36))
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
		_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
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
	_pending_state_id = backend.request("state.get", {})
	_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
	_pending_games_id = backend.request("library.games.list", {})
	_pending_theme_id = backend.request("theme.current", {})
	_pending_settings_id = backend.request("settings.get", {})
	_pending_themes_id = backend.request("themes.list", {})
	_pending_emulators_list_id = backend.request("emulators.list", {})
	_pending_app_info_id = backend.request("app.info", {})
	_pending_fontsets_list_id = backend.request("fontsets.list", {})
	_pending_fonts_list_id = backend.request("fonts.list", {})

func _on_backend_disconnected(code: int, reason: String) -> void:
	if archive_gallery != null:
		archive_gallery.set_launch_result(false, "后端连接已断开")
	# Invalidate pending pauses: a lost backend cannot send game.exited.
	_delayed_pause_generation += 1
	RenderingServer.render_loop_enabled = true
	_pending_game_play_id = ""
	_pending_movie_play_id = ""
	if game_section != null:
		game_section.set_detail_launching(false)
	backend_label.text = "后端离线  %d" % code
	if not reason.is_empty():
		backend_label.text = "后端离线  %d  %s" % [code, reason]

func _on_backend_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	if request_id == _pending_app_info_id:
		_pending_app_info_id = ""
		if ok and data is Dictionary:
			var info: Dictionary = data as Dictionary
			_app_version_label.text = "G3  %s" % str(info.get("display", "?"))
		return

	if request_id == _pending_state_id:
		_pending_state_id = ""
		if ok and data is Dictionary:
			var state: Dictionary = data as Dictionary
			var key: String = "last_movie_id_private" if _current_movie_scope == "private" else "last_movie_id_main"
			_restore_movie_id = str(state.get(key, ""))
		_state_ready = true
		_try_restore_movie()
		return

	if request_id == _pending_movies_id:
		_pending_movies_id = ""
		if ok and data is Array:
			var movies: Array[Dictionary] = []
			for value: Variant in data as Array:
				if value is Dictionary:
					movies.append(value as Dictionary)
			movie_wall.set_movies(movies)
			if _force_reload_covers_on_next_list:
				_force_reload_covers_on_next_list = false
				movie_wall.reload_covers()
			if _pending_backdrop_changed:
				_pending_backdrop_changed = false
				movie_wall.force_refresh_backdrop()
		_movies_ready = true
		_try_restore_movie()
		return

	if request_id == _pending_games_id:
		_pending_games_id = ""
		if ok and data is Array:
			var games: Array[Dictionary] = []
			for value: Variant in data as Array:
				if value is Dictionary:
					games.append(value as Dictionary)
			if game_section != null:
				game_section.set_games(games)
				if spatial_gallery != null:
					spatial_gallery.set_games(game_section.games)
				if archive_gallery != null:
					archive_gallery.set_games(games)
		return

	if request_id == _pending_steam_search_id:
		_pending_steam_search_id = ""
		
		# 如果是批量刮削触发的搜索
		if _is_batch_scraping:
			if ok and data is Array and not (data as Array).is_empty():
				# 取第一个结果直接应用
				var first_result: Dictionary = (data as Array)[0]
				var ext_id: int = int(first_result.get("external_id", 0))
				if ext_id > 0:
					_pending_steam_apply_id = backend.request("game.scrape.apply", {
						"id": str(_current_batch_item.get("id", "")),
						"source": "steam",
						"external_id": ext_id,
					})
					return
			# 没搜到或者出错，跳过这个，继续下一个
			_process_next_batch_scrape()
		else:
			# 正常的手动搜索
			if ok and data is Array:
				steam_search_dialog.show_results(data as Array)
			else:
				steam_search_dialog.show_results([])
		return

	if request_id == _pending_steam_apply_id:
		_pending_steam_apply_id = ""
		if ok:
			backend_label.text = "Steam 资料已应用"
			_clear_runtime_error()
			steam_search_dialog.hide()
			# 如果是批量，就继续下一个，不要刷新整个列表（等全部结束再刷）
			if _is_batch_scraping:
				_process_next_batch_scrape()
			else:
				_pending_games_id = backend.request("library.games.list", {})
		else:
			var reason: String = _error_message(error)
			if _is_batch_scraping:
				_process_next_batch_scrape()
			else:
				steam_search_dialog.set_apply_failed(reason)
		return

	if request_id == _pending_game_metadata_get_id:
		_pending_game_metadata_get_id = ""
		var meta_target: String = _pending_game_metadata_target_id
		_pending_game_metadata_target_id = ""
		if ok and data is Dictionary and not meta_target.is_empty():
			game_metadata_dialog.show_metadata(meta_target, data as Dictionary)
		else:
			_show_runtime_error("读取游戏资料失败", _error_message(error))
		return

	if request_id == _pending_game_metadata_update_id:
		_pending_game_metadata_update_id = ""
		if ok:
			backend_label.text = "游戏资料已保存"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("保存游戏资料失败", _error_message(error))
		return

	if request_id == _pending_game_launch_get_id:
		_pending_game_launch_get_id = ""
		var launch_target: String = _pending_game_launch_target_id
		_pending_game_launch_target_id = ""
		if ok and data is Dictionary and not launch_target.is_empty():
			game_launch_dialog.show_profile(launch_target, data as Dictionary)
		else:
			_show_runtime_error("读取启动设置失败", _error_message(error))
		return

	if request_id == _pending_game_launch_update_id:
		_pending_game_launch_update_id = ""
		if ok:
			backend_label.text = "启动设置已保存"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("保存启动设置失败", _error_message(error))
		return

	if request_id == _pending_playtime_set_id:
		_pending_playtime_set_id = ""
		if ok:
			backend_label.text = "游玩时长已更新"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("保存失败", _error_message(error))
		return

	if request_id == _pending_game_remove_request_id:
		_pending_game_remove_request_id = ""
		_pending_game_remove_id = ""
		if ok:
			backend_label.text = "游戏已移除"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("移除失败", _error_message(error))
		return

	if request_id == _pending_sgdb_search_id:
		_pending_sgdb_search_id = ""
		if ok and data is Array:
			game_scraper_dialog.show_search_results(data as Array)
		else:
			game_scraper_dialog.show_search_results([])
		return

	if _pending_sgdb_assets_ids.has(request_id):
		var tag: String = str(_pending_sgdb_assets_ids[request_id])
		_pending_sgdb_assets_ids.erase(request_id)
		if ok and data is Dictionary:
			var items_raw = (data as Dictionary).get("items", [])
			var items: Array = items_raw if items_raw is Array else []
			game_scraper_dialog.show_assets(tag, items)
		else:
			game_scraper_dialog.show_assets(tag, [])
		return

	if _pending_sgdb_apply_ids.has(request_id):
		var asset_tag: String = str(_pending_sgdb_apply_ids[request_id])
		_pending_sgdb_apply_ids.erase(request_id)
		if ok:
			backend_label.text = "素材已应用（%s）" % asset_tag
			_clear_runtime_error()
			if _pending_sgdb_apply_ids.is_empty():
				game_scraper_dialog.set_apply_done()
				# 立即刷新列表让卡片更新（不用等对话框关闭）
				_pending_games_id = backend.request("library.games.list", {})
				# 关掉对话框——用户看到卡片刷新
				game_scraper_dialog.hide()
		else:
			_show_runtime_error("应用素材失败", _error_message(error))
			game_scraper_dialog.set_apply_done()
		return

	if request_id == _pending_paste_create_id:
		_pending_paste_create_id = ""
		if ok:
			backend_label.text = "已从文本创建游戏"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("创建失败", _error_message(error))
		return

	if request_id == _pending_paste_update_id:
		_pending_paste_update_id = ""
		if ok:
			backend_label.text = "已从文本更新资料"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("更新失败", _error_message(error))
		return

	if request_id == _pending_game_create_id:
		_pending_game_create_id = ""
		if ok:
			backend_label.text = "游戏已添加"
			_clear_runtime_error()
			_pending_games_id = backend.request("library.games.list", {})
		else:
			_show_runtime_error("添加游戏失败", _error_message(error))
		return

	if request_id == _pending_emulators_for_create_id:
		_pending_emulators_for_create_id = ""
		var emus: Array = []
		if ok and data is Array:
			emus = data as Array
		else:
			_show_runtime_error("读取模拟器配置失败", _error_message(error))
		game_create_dialog.show_dialog(emus)
		return

	# 启动失败：作废在途的「暂停渲染」，否则 0.6 秒后画面永久冻结
	# （成功时不动渲染——那时靠 game.exited / movie.exited 恢复）
	if request_id == _pending_game_play_id:
		if archive_gallery != null:
			archive_gallery.set_launch_result(ok, "" if ok else _error_message(error))
		_pending_game_play_id = ""
		if not ok:
			# 启动彻底失败（如找不到文件）
			_delayed_pause_generation += 1
			RenderingServer.render_loop_enabled = true
			_show_runtime_error("启动失败", _error_message(error))
			_reset_launch_button_after(1.5)
			return
		
		# Unmonitorable launchers have no reliable exit event. Restore the
		# interface immediately; do not invent an exit time or play duration.
		var game_monitorable: bool = true
		if data is Dictionary:
			game_monitorable = bool((data as Dictionary).get("monitorable", true))
		if not game_monitorable:
			_delayed_pause_generation += 1
			RenderingServer.render_loop_enabled = true
			_reset_launch_button_after(0.1)
		return

	if request_id == _pending_movie_play_id:
		_pending_movie_play_id = ""
		if not ok:
			_delayed_pause_generation += 1
			RenderingServer.render_loop_enabled = true
			_show_runtime_error("播放失败", _error_message(error))
		else:
			var movie_monitorable: bool = true
			if data is Dictionary:
				movie_monitorable = bool((data as Dictionary).get("monitorable", true))
			if movie_monitorable:
				_delayed_pause_render()
		return

	if request_id == _pending_game_scan_emulator_id:
		_pending_game_scan_emulator_id = ""
		if ok and data is Dictionary:
			var scan_data: Dictionary = data as Dictionary
			var raw_items: Variant = scan_data.get("items", [])
			_scan_items_cache = raw_items if raw_items is Array else []
			_prepare_library_scan_tab("emulator")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("emulator", _scan_items_cache)
			backend_label.text = "扫描完成"
		else:
			_scan_items_cache = []
			_show_library_scan_error("emulator", _error_message(error))
			_show_runtime_error("扫描模拟器游戏失败", _error_message(error))
		return

	# 批量导入：逐个 game.create，全部回包后汇总
	if _pending_game_scan_create_ids.has(request_id):
		_pending_game_scan_create_ids.erase(request_id)
		_scan_import_done += 1
		if ok:
			_scan_import_added += 1
		else:
			_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress(
				"emulator", _scan_import_done, _scan_import_total
			)
		if _scan_import_done >= _scan_import_total:
			_finish_scan_import()
		return

	if request_id == _pending_steam_scan_id:
		_pending_steam_scan_id = ""
		if ok and data is Dictionary:
			var steam_data: Dictionary = data as Dictionary
			var raw_steam_items: Variant = steam_data.get("items", [])
			_steam_scan_items_cache = raw_steam_items if raw_steam_items is Array else []
			_prepare_library_scan_tab("steam")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("steam", _steam_scan_items_cache)
			backend_label.text = "Steam 库扫描完成"
		else:
			_steam_scan_items_cache = []
			_show_library_scan_error("steam", _error_message(error))
			_show_runtime_error("扫描 Steam 库失败", _error_message(error))
		return

	# Steam 批量导入：逐个 game.create，全部回包后汇总
	if _pending_steam_scan_create_ids.has(request_id):
		_pending_steam_scan_create_ids.erase(request_id)
		_steam_scan_import_done += 1
		if ok:
			_steam_scan_import_added += 1
		else:
			_steam_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress(
				"steam", _steam_scan_import_done, _steam_scan_import_total
			)
		if _steam_scan_import_done >= _steam_scan_import_total:
			_finish_steam_scan_import()
		return

	if request_id == _pending_gog_scan_id:
		_pending_gog_scan_id = ""
		if ok and data is Dictionary:
			var gog_data: Dictionary = data as Dictionary
			var raw_gog_items: Variant = gog_data.get("items", [])
			_gog_scan_items_cache = raw_gog_items if raw_gog_items is Array else []
			_prepare_library_scan_tab("gog")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("gog", _gog_scan_items_cache)
			backend_label.text = "GOG 库扫描完成"
		else:
			_gog_scan_items_cache = []
			_show_library_scan_error("gog", _error_message(error))
			_show_runtime_error("扫描 GOG 库失败", _error_message(error))
		return

	# GOG 批量导入：逐个 game.create，全部回包后汇总
	if _pending_gog_scan_create_ids.has(request_id):
		_pending_gog_scan_create_ids.erase(request_id)
		_gog_scan_import_done += 1
		if ok:
			_gog_scan_import_added += 1
		else:
			_gog_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress(
				"gog", _gog_scan_import_done, _gog_scan_import_total
			)
		if _gog_scan_import_done >= _gog_scan_import_total:
			_finish_gog_scan_import()
		return

	if request_id == _pending_epic_scan_id:
		_pending_epic_scan_id = ""
		if ok and data is Dictionary:
			var epic_data: Dictionary = data as Dictionary
			var raw_epic_items: Variant = epic_data.get("items", [])
			_epic_scan_items_cache = raw_epic_items if raw_epic_items is Array else []
			_prepare_library_scan_tab("epic")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("epic", _epic_scan_items_cache)
			backend_label.text = "Epic 库扫描完成"
		else:
			_epic_scan_items_cache = []
			_show_library_scan_error("epic", _error_message(error))
			_show_runtime_error("扫描 Epic 库失败", _error_message(error))
		return

	# Epic 批量导入：逐个 game.create，全部回包后汇总
	if _pending_epic_scan_create_ids.has(request_id):
		_pending_epic_scan_create_ids.erase(request_id)
		_epic_scan_import_done += 1
		if ok:
			_epic_scan_import_added += 1
		else:
			_epic_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress(
				"epic", _epic_scan_import_done, _epic_scan_import_total
			)
		if _epic_scan_import_done >= _epic_scan_import_total:
			_finish_epic_scan_import()
		return

	if request_id == _pending_uplay_scan_id:
		_pending_uplay_scan_id = ""
		if ok and data is Dictionary:
			var uplay_data: Dictionary = data as Dictionary
			var raw_uplay_items: Variant = uplay_data.get("items", [])
			_uplay_scan_items_cache = raw_uplay_items if raw_uplay_items is Array else []
			_prepare_library_scan_tab("uplay")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("uplay", _uplay_scan_items_cache)
			backend_label.text = "Uplay 库扫描完成"
		else:
			_uplay_scan_items_cache = []
			_show_library_scan_error("uplay", _error_message(error))
			_show_runtime_error("扫描 Uplay 库失败", _error_message(error))
		return

	# Uplay 批量导入：逐个 game.create，全部回包后汇总
	if _pending_uplay_scan_create_ids.has(request_id):
		_pending_uplay_scan_create_ids.erase(request_id)
		_uplay_scan_import_done += 1
		if ok:
			_uplay_scan_import_added += 1
		else:
			_uplay_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress(
				"uplay", _uplay_scan_import_done, _uplay_scan_import_total
			)
		if _uplay_scan_import_done >= _uplay_scan_import_total:
			_finish_uplay_scan_import()
		return

	if request_id == _pending_rockstar_scan_id:
		_pending_rockstar_scan_id = ""
		if ok and data is Dictionary:
			var rockstar_data: Dictionary = data as Dictionary
			var raw_rockstar_items: Variant = rockstar_data.get("items", [])
			_rockstar_scan_items_cache = raw_rockstar_items if raw_rockstar_items is Array else []
			_prepare_library_scan_tab("rockstar")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("rockstar", _rockstar_scan_items_cache)
			backend_label.text = "Rockstar 库扫描完成"
		else:
			_rockstar_scan_items_cache = []
			_show_library_scan_error("rockstar", _error_message(error))
			_show_runtime_error("扫描 Rockstar 库失败", _error_message(error))
		return

	# Rockstar 批量导入：逐个 game.create，全部回包后汇总
	if _pending_rockstar_scan_create_ids.has(request_id):
		_pending_rockstar_scan_create_ids.erase(request_id)
		_rockstar_scan_import_done += 1
		if ok:
			_rockstar_scan_import_added += 1
		else:
			_rockstar_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress(
				"rockstar", _rockstar_scan_import_done, _rockstar_scan_import_total
			)
		if _rockstar_scan_import_done >= _rockstar_scan_import_total:
			_finish_rockstar_scan_import()
		return

	if request_id == _pending_psn_scan_id:
		_pending_psn_scan_id = ""
		if ok and data is Dictionary:
			var psn_data: Dictionary = data as Dictionary
			var raw_psn_items: Variant = psn_data.get("items", [])
			_psn_scan_items_cache = raw_psn_items if raw_psn_items is Array else []
			_prepare_library_scan_tab("psn")
			if library_scan_dialog != null:
				library_scan_dialog.show_scan_results("psn", _psn_scan_items_cache)
			backend_label.text = "PSN 库扫描完成"
		else:
			_psn_scan_items_cache = []
			_show_library_scan_error("psn", _error_message(error))
			_show_runtime_error("扫描 PSN 库失败", _error_message(error))
		return

	if _pending_psn_scan_create_ids.has(request_id):
		_pending_psn_scan_create_ids.erase(request_id)
		_psn_scan_import_done += 1
		if ok:
			_psn_scan_import_added += 1
		else:
			_psn_scan_import_errors += 1
		if library_scan_dialog != null:
			library_scan_dialog.set_import_progress("psn", _psn_scan_import_done, _psn_scan_import_total)
		if _psn_scan_import_done >= _psn_scan_import_total:
			_finish_psn_scan_import()
		return

	if request_id == _pending_movie_create_id:
		_pending_movie_create_id = ""
		if ok:
			backend_label.text = "电影已添加"
			_clear_runtime_error()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("添加电影失败", _error_message(error))
		return

	if request_id == _pending_movie_remove_request_id:
		_pending_movie_remove_request_id = ""
		_pending_movie_remove_id = ""
		if ok:
			backend_label.text = "电影已移除"
			_clear_runtime_error()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("移除失败", _error_message(error))
		return

	if request_id == _pending_movie_cover_request_id:
		_pending_movie_cover_request_id = ""
		_pending_movie_cover_item_id = ""
		if ok:
			backend_label.text = "封面已更新"
			_clear_runtime_error()
			_force_reload_covers_on_next_list = true
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("设置封面失败", _error_message(error))
		return

	if request_id == _pending_movie_metadata_get_id:
		_pending_movie_metadata_get_id = ""
		var meta_target: String = _pending_movie_metadata_target_id
		_pending_movie_metadata_target_id = ""
		if ok and data is Dictionary and not meta_target.is_empty():
			movie_metadata_dialog.show_metadata(meta_target, data as Dictionary)
		else:
			_show_runtime_error("读取电影资料失败", _error_message(error))
		return

	if request_id == _pending_movie_metadata_update_id:
		_pending_movie_metadata_update_id = ""
		if ok:
			backend_label.text = "电影资料已保存"
			_clear_runtime_error()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("保存电影资料失败", _error_message(error))
		return

	if request_id == _pending_set_paths_id:
		_pending_set_paths_id = ""
		if ok and data is Dictionary:
			var s: Dictionary = data as Dictionary
			var raw = s.get("movie_library_paths", [])
			_movie_library_paths.clear()
			if raw is Array:
				for p in raw:
					_movie_library_paths.append(str(p))
			_rebuild_movie_lib_paths_ui()
		else:
			_show_runtime_error("保存库路径失败", _error_message(error))
		return

	if request_id == _pending_cover_folder_set_id:
		_pending_cover_folder_set_id = ""
		if ok and data is Dictionary:
			var s: Dictionary = data as Dictionary
			_movie_cover_folder_main = str(s.get("movie_cover_folder_main", ""))
			_movie_cover_folder_private = str(s.get("movie_cover_folder_private", ""))
			_rebuild_cover_folder_ui()
		else:
			_show_runtime_error("设置封面文件夹失败", _error_message(error))
		return

	if request_id == _pending_cover_match_id:
		_pending_cover_match_id = ""
		if ok and data is Dictionary:
			var n: int = int((data as Dictionary).get("matched", 0))
			backend_label.text = "匹配完成 · %d 部" % n
			_clear_runtime_error()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("匹配封面失败", _error_message(error))
		return

	if request_id == _pending_cover_tool_source_id:
		_pending_cover_tool_source_id = ""
		if ok and data is Dictionary:
			_cover_tool_source_dir_cached = str((data as Dictionary).get("cover_tool_source_dir", _cover_tool_source_dir_cached))
		return

	if request_id == _pending_cover_tool_scan_id:
		_pending_cover_tool_scan_id = ""
		if ok and data is Dictionary:
			var items_raw = (data as Dictionary).get("items", [])
			var items: Array = items_raw if items_raw is Array else []
			if cover_tool_dialog != null:
				cover_tool_dialog.show_scan_results(items)
		else:
			if cover_tool_dialog != null:
				cover_tool_dialog.show_scan_results([])
			_show_runtime_error("扫描失败", _error_message(error))
		return

	if _pending_cover_tool_apply_ids.has(request_id):
		_pending_cover_tool_apply_ids.erase(request_id)
		if ok:
			_cover_tool_apply_done += 1
		else:
			_cover_tool_apply_failed += 1
		if cover_tool_dialog != null:
			cover_tool_dialog.show_apply_progress(
				_cover_tool_apply_done + _cover_tool_apply_failed,
				_cover_tool_apply_done + _cover_tool_apply_failed + _cover_tool_apply_queue.size()
			)
		_dispatch_next_cover_tool_apply()
		return

	if request_id == _pending_movie_scan_id:
		_pending_movie_scan_id = ""
		if ok and data is Dictionary:
			var r: Dictionary = data as Dictionary
			var added := int(r.get("added", 0))
			var updated := int(r.get("updated", 0))
			var offline := int(r.get("offline", 0))
			var total := int(r.get("total_found", 0))
			var msg := "发现 %d · 新增 %d · 更新 %d · 离线 %d" % [total, added, updated, offline]
			_show_runtime_error("扫描完成", msg)
			backend_label.text = "后端已连接"
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("扫描失败", _error_message(error))
		return

	if request_id == _pending_movie_backdrop_refresh_id:
		_pending_movie_backdrop_refresh_id = ""
		if ok:
			backend_label.text = "正在重新截取预览图…"
		else:
			_show_runtime_error("重新截取失败", _error_message(error))
		return

	if request_id == _pending_movie_backdrop_set_id:
		_pending_movie_backdrop_set_id = ""
		_pending_movie_backdrop_set_item_id = ""
		if ok:
			backend_label.text = "背景图已更新"
			_clear_runtime_error()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("设置背景图失败", _error_message(error))
		return

	if request_id == _pending_tmdb_search_id:
		_pending_tmdb_search_id = ""
		if ok and data is Array:
			tmdb_dialog.show_results(data as Array)
		else:
			tmdb_dialog.show_results([])
			_show_runtime_error("TMDB 搜索失败", _error_message(error))
		return

	if request_id == _pending_tmdb_apply_id:
		_pending_tmdb_apply_id = ""
		if ok:
			backend_label.text = "TMDB 资料已应用"
			_clear_runtime_error()
			tmdb_dialog.hide()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("应用失败", _error_message(error))
		return

	if request_id == _pending_poster_list_id:
		_pending_poster_list_id = ""
		if ok and data is Dictionary:
			var posters_raw = (data as Dictionary).get("posters", [])
			var posters: Array = posters_raw if posters_raw is Array else []
			tmdb_poster_dialog.show_poster_list(posters)
		else:
			tmdb_poster_dialog.show_poster_list([])
		return

	if _pending_poster_thumb_ids.has(request_id):
		var fp: String = str(_pending_poster_thumb_ids[request_id])
		_pending_poster_thumb_ids.erase(request_id)
		if ok and data is Dictionary:
			var local_path: String = str((data as Dictionary).get("path", ""))
			tmdb_poster_dialog.on_thumb_response(fp, local_path)
		else:
			tmdb_poster_dialog.on_thumb_response(fp, "")
		return

	if request_id == _pending_poster_apply_id:
		_pending_poster_apply_id = ""
		if ok:
			backend_label.text = "海报已更新"
			_clear_runtime_error()
			_force_reload_covers_on_next_list = true
			tmdb_poster_dialog.set_apply_done()
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		else:
			_show_runtime_error("应用海报失败", _error_message(error))
		return

	if request_id == _pending_theme_id:
		_pending_theme_id = ""
		if ok and data is Dictionary:
			_current_theme = data as Dictionary
			_apply_theme(_current_theme)
		return

	if request_id == _pending_themes_id:
		_pending_themes_id = ""
		if ok and data is Array:
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
		return

	if request_id == _pending_emulators_list_id:
		_pending_emulators_list_id = ""
		if ok and data is Array:
			_emulators = data as Array
		else:
			_emulators = []
			if not ok:
				_show_runtime_error("读取模拟器配置失败", _error_message(error))
		_rebuild_emulator_list()
		return

	if request_id == _pending_emulator_save_id:
		_pending_emulator_save_id = ""
		if ok:
			backend_label.text = "模拟器配置已保存"
			_clear_runtime_error()
			_pending_emulators_list_id = backend.request("emulators.list", {})
		else:
			_show_runtime_error("保存模拟器配置失败", _error_message(error))
		return

	if request_id == _pending_emulator_delete_id:
		_pending_emulator_delete_id = ""
		if ok:
			backend_label.text = "模拟器配置已移除"
			_clear_runtime_error()
			_pending_emulators_list_id = backend.request("emulators.list", {})
		else:
			_show_runtime_error("移除模拟器配置失败", _error_message(error))
		return

	if request_id == _pending_fonts_list_id:
		_pending_fonts_list_id = ""
		if ok and data is Array:
			_system_fonts = data as Array
			if fontset_editor != null:
				fontset_editor.set_system_fonts(_system_fonts)
		return

	if request_id == _pending_fontsets_list_id:
		_pending_fontsets_list_id = ""
		if ok and data is Array:
			_fontset_ids.clear()
			_fontset_ids_games.clear()
			fontset_option.clear()
			fontset_option_games.clear()
			_fontsets_cache.clear()
			var cur_idx_movie: int = 0
			var cur_idx_game: int = 0
			for i in range((data as Array).size()):
				var entry_value: Variant = (data as Array)[i]
				if not (entry_value is Dictionary):
					continue
				var entry: Dictionary = entry_value as Dictionary
				var fs_id: String = str(entry.get("id", ""))
				if fs_id.is_empty():
					continue
				var fs_scope: String = str(entry.get("scope", "movies"))
				var fs_name: String = str(entry.get("name", fs_id))
				_fontsets_cache.append(entry)
				if fs_scope == "games":
					_fontset_ids_games.append(fs_id)
					fontset_option_games.add_item(fs_name)
					if fs_id == _fontset_id_games:
						cur_idx_game = _fontset_ids_games.size() - 1
				else:
					_fontset_ids.append(fs_id)
					fontset_option.add_item(fs_name)
					if fs_id == _fontset_id:
						cur_idx_movie = _fontset_ids.size() - 1
			if _fontset_ids.size() > 0:
				fontset_option.select(cur_idx_movie)
			if _fontset_ids_games.size() > 0:
				fontset_option_games.select(cur_idx_game)
		return

	if request_id == _pending_fontset_switch_id:
		_pending_fontset_switch_id = ""
		if ok:
			_clear_runtime_error()
			_pending_fontset_get_id = backend.request(
				"fontsets.get", {"id": _fontset_id, "scope": "movies"}
			)
		else:
			_show_runtime_error("字体切换失败", _error_message(error))
		return

	if request_id == _pending_fontset_switch_id_games:
		_pending_fontset_switch_id_games = ""
		if ok:
			_clear_runtime_error()
			_pending_fontset_get_id_games = backend.request(
				"fontsets.get", {"id": _fontset_id_games, "scope": "games"}
			)
		else:
			_show_runtime_error("游戏字体切换失败", _error_message(error))
		return

	if request_id == _pending_theme_switch_id:
		_pending_theme_switch_id = ""
		if ok:
			backend_label.text = "主题已切换"
			_clear_runtime_error()
			_pending_theme_id = backend.request("theme.current", {})
		else:
			_show_runtime_error("主题切换失败", _error_message(error))
		return

	if request_id == _pending_settings_id:
		_pending_settings_id = ""
		if ok and data is Dictionary:
			var settings: Dictionary = data as Dictionary
			_theme_music_enabled = bool(settings.get("theme_music", true))
			_theme_music_base_volume = clampf(float(settings.get("theme_music_volume", 0.35)), 0.0, 1.0)
			var default_section: String = str(settings.get("default_start_section", "games")).to_upper()
			var start_index: int = XMB_SECTIONS.find(default_section)
			if start_index < 0:
				start_index = 0
			var raw_paths = settings.get("movie_library_paths", [])
			_movie_library_paths.clear()
			if raw_paths is Array:
				for p in raw_paths:
					_movie_library_paths.append(str(p))
			var raw_paths_private = settings.get("movie_library_paths_private", [])
			_movie_library_paths_private.clear()
			if raw_paths_private is Array:
				for p in raw_paths_private:
					_movie_library_paths_private.append(str(p))
			_movie_cover_folder_main = str(settings.get("movie_cover_folder_main", ""))
			_movie_cover_folder_private = str(settings.get("movie_cover_folder_private", ""))
			_cover_tool_source_dir_cached = str(settings.get("cover_tool_source_dir", ""))
			_rebuild_cover_folder_ui()
			
			# 暂时不处理，等 E 阶段做本地封面匹配时再加界面
			_rebuild_movie_lib_paths_ui()
			default_section_option.select(start_index)
			_set_section(start_index)
			var wm := str(settings.get("window_mode", "windowed")).to_lower()
			if window_mode_option != null:
				window_mode_option.select(0 if wm != "fullscreen" else 1)
			if not _current_theme.is_empty():
				_apply_theme_audio(_current_theme)
			var fs_id: String = str(settings.get("fontset_id", "default")).strip_edges()
			if fs_id.is_empty():
				fs_id = "default"
			_fontset_id = fs_id
			_pending_fontset_get_id = backend.request(
				"fontsets.get", {"id": fs_id, "scope": "movies"}
			)
			var fs_id_games: String = str(settings.get("fontset_id_games", "default")).strip_edges()
			if fs_id_games.is_empty():
				fs_id_games = "default"
			_fontset_id_games = fs_id_games
			_pending_fontset_get_id_games = backend.request(
				"fontsets.get", {"id": fs_id_games, "scope": "games"}
			)
		return

	if request_id == _pending_fontset_get_id:
		_pending_fontset_get_id = ""
		if ok and data is Dictionary:
			_apply_fontset("movies", data as Dictionary)
		return

	if request_id == _pending_fontset_get_id_games:
		_pending_fontset_get_id_games = ""
		if ok and data is Dictionary:
			_apply_fontset("games", data as Dictionary)
		return

	if request_id == _pending_fontsets_save_id:
		_pending_fontsets_save_id = ""
		if ok and data is Dictionary:
			fontset_editor.set_status("已保存")
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
			_pending_fontset_get_id = backend.request(
				"fontsets.get", {"id": _fontset_id, "scope": "movies"}
			)
		else:
			fontset_editor.set_status("保存失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_save_id_games:
		_pending_fontsets_save_id_games = ""
		if ok and data is Dictionary:
			fontset_editor.set_status("已保存")
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
			_pending_fontset_get_id_games = backend.request(
				"fontsets.get", {"id": _fontset_id_games, "scope": "games"}
			)
		else:
			fontset_editor.set_status("保存失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_create_id:
		_pending_fontsets_create_id = ""
		if ok and data is Dictionary:
			var new_fs: Dictionary = data as Dictionary
			var new_id: String = str(new_fs.get("id", ""))
			_fontset_id = new_id
			if fontset_editor != null:
				fontset_editor.set_status("已创建并应用")
			backend.request("settings.update", {"fontset_id": new_id})
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
			_pending_fontset_get_id = backend.request(
				"fontsets.get", {"id": new_id, "scope": "movies"}
			)
		else:
			if fontset_editor != null:
				fontset_editor.set_status("创建失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_create_id_games:
		_pending_fontsets_create_id_games = ""
		if ok and data is Dictionary:
			var new_fs: Dictionary = data as Dictionary
			var new_id: String = str(new_fs.get("id", ""))
			_fontset_id_games = new_id
			if fontset_editor != null:
				fontset_editor.set_status("已创建并应用")
			backend.request("settings.update", {"fontset_id_games": new_id})
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
			_pending_fontset_get_id_games = backend.request(
				"fontsets.get", {"id": new_id, "scope": "games"}
			)
		else:
			if fontset_editor != null:
				fontset_editor.set_status("创建失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_rename_id:
		_pending_fontsets_rename_id = ""
		if ok and data is Dictionary:
			fontset_editor.set_status("已重命名")
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
		else:
			fontset_editor.set_status("重命名失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_rename_id_games:
		_pending_fontsets_rename_id_games = ""
		if ok and data is Dictionary:
			fontset_editor.set_status("已重命名")
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
		else:
			fontset_editor.set_status("重命名失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_delete_id:
		_pending_fontsets_delete_id = ""
		if ok:
			fontset_editor.set_status("已删除")
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
		else:
			fontset_editor.set_status("删除失败：%s" % _error_message(error))
		return

	if request_id == _pending_fontsets_delete_id_games:
		_pending_fontsets_delete_id_games = ""
		if ok:
			fontset_editor.set_status("已删除")
			_pending_fontsets_list_id = backend.request("fontsets.list", {})
		else:
			fontset_editor.set_status("删除失败：%s" % _error_message(error))
		return

	

func _on_backend_event(event_type: String, payload: Dictionary) -> void:
	if event_type == "library.changed":
		var media_type: String = str(payload.get("media_type", ""))
		if bool(payload.get("backdrop_changed", false)):
			_pending_backdrop_changed = true
		if media_type == "movie" or media_type.is_empty():
			_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		elif media_type == "game":
			_pending_games_id = backend.request("library.games.list", {})
	elif event_type == "movie.exited":
		_delayed_pause_generation += 1
		RenderingServer.render_loop_enabled = true
	elif event_type == "game.exited":
		_delayed_pause_generation += 1
		RenderingServer.render_loop_enabled = true
		_reset_launch_button_after(0.1)		
		if backend != null and backend.is_connected_to_backend():
			_pending_games_id = backend.request("library.games.list", {})

func _on_movie_selection_changed(index: int, movie: Dictionary) -> void:
	_selected_movie = movie
	_update_movie_info_content(movie)
	_ensure_movie_backdrop(movie)
	_schedule_episode_drawer_refresh(movie)
	var item_id: String = str(movie.get("id", ""))
	if not item_id.is_empty() and backend != null and backend.is_connected_to_backend():
		var state_key: String = "last_movie_id_private" if _current_movie_scope == "private" else "last_movie_id_main"
		backend.request("state.update", {state_key: item_id})

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
	if _current_movie_scope == "private":
		movie_episode_drawer.set_theme_colors(PRIVATE_ACCENT, PRIVATE_MUTED)
	else:
		movie_episode_drawer.set_theme_colors(
			Color(0.88, 0.66, 0.36),
			Color(0.75, 0.65, 0.50)
		)

func _ensure_movie_backdrop(movie: Dictionary) -> void:
	var item_id: String = str(movie.get("id", ""))
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		return
	backend.request("movie.backdrop.ensure", {"id": item_id})

func _update_movie_info_content(movie: Dictionary) -> void:
	if movie_info_title == null:
		return
	var title: String = str(movie.get("title", ""))
	var year_raw = movie.get("release_year", "")
	var year: String = ""
	if year_raw != null:
		year = str(year_raw).strip_edges()
		if year.ends_with(".0"):
			year = year.substr(0, year.length() - 2)
	var desc: String = str(movie.get("description", "")).strip_edges()
	movie_info_title.text = title
	movie_info_meta.text = year
	movie_info_genres.text = _format_movie_meta_line(movie)
	movie_desc_label.text = desc
	if _hidden_tagline != null:
		var tagline: String = str(movie.get("tagline", "")).strip_edges()
		_hidden_tagline.text = "“%s”" % tagline if not tagline.is_empty() else ""
	_refresh_movie_info_visibility()

func _format_movie_meta_line(movie: Dictionary) -> String:
	var parts: Array[String] = []

	var genres_str: String = str(movie.get("genres", "")).strip_edges()
	if not genres_str.is_empty():
		parts.append("▸ " + genres_str)

	var runtime_min: int = int(movie.get("runtime_minutes", 0))
	var media_type: String = str(movie.get("media_type", "movie"))
	if runtime_min > 0:
		var runtime_text: String
		if media_type == "series":
			runtime_text = "%d分钟/集" % runtime_min
		else:
			var hours: int = runtime_min / 60
			var mins: int = runtime_min % 60
			if hours > 0 and mins > 0:
				runtime_text = "%d小时%d分" % [hours, mins]
			elif hours > 0:
				runtime_text = "%d小时" % hours
			else:
				runtime_text = "%d分钟" % mins
		parts.append("◷ " + runtime_text)

	var vote: float = float(movie.get("vote_average", 0.0))
	if vote > 0.05:
		parts.append("★ %.1f" % vote)
	else:
		parts.append("★ —")

	return " · ".join(parts)

func _refresh_movie_info_visibility() -> void:
	var is_movie: bool = section_index == 1
	movie_info_title.visible = is_movie and not movie_info_title.text.is_empty()
	movie_info_meta.visible = is_movie and not movie_info_meta.text.is_empty()
	movie_info_genres.visible = is_movie and not movie_info_genres.text.is_empty()
	var desc_visible: bool = is_movie and not movie_desc_label.text.is_empty()
	movie_desc_scroll.visible = desc_visible

func _apply_theme(theme: Dictionary) -> void:
	var colors_value: Variant = theme.get("colors", {})
	var colors: Dictionary = {}
	if colors_value is Dictionary:
		colors = colors_value as Dictionary
	_theme_text = _theme_color(colors, "text", Color(0.93, 1.0, 1.0, 1.0))
	_theme_muted = _theme_color(colors, "muted_text", Color(0.55, 0.70, 0.72, 1.0))
	_theme_accent = _theme_color(colors, "accent", Color(0.20, 0.82, 0.76, 1.0))
	_theme_secondary = _theme_color(colors, "accent_secondary", Color(0.25, 0.55, 0.90, 1.0))
	_theme_base_top = _theme_color(colors, "base_top", Color(0.05, 0.28, 0.32, 1.0))
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


func _theme_color(colors: Dictionary, key: String, fallback: Color) -> Color:
	var value: String = str(colors.get(key, ""))
	if value.is_empty():
		return fallback
	return Color.from_string(value, fallback)

func _error_message(error: Variant) -> String:
	if error is Dictionary:
		var payload: Dictionary = error as Dictionary
		return str(payload.get("message", payload))
	return str(error)

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
	if theme_music_player == null:
		return
	var audio_value: Variant = theme.get("audio", {})
	if not (audio_value is Dictionary):
		theme_music_player.stop()
		theme_music_player.stream = null
		return
	var audio: Dictionary = audio_value as Dictionary
	var music_rel: String = str(audio.get("music", ""))
	var theme_dir: String = str(theme.get("directory", ""))
	if not _theme_music_enabled or music_rel.is_empty() or theme_dir.is_empty():
		theme_music_player.stop()
		theme_music_player.stream = null
		return
	var music_path: String = theme_dir.path_join(music_rel)
	var stream: AudioStream = AUDIO_LOADER.load_audio(music_path, bool(audio.get("loop", true)))
	if stream == null:
		theme_music_player.stop()
		theme_music_player.stream = null
		return
	theme_music_player.stream = stream
	theme_music_player.volume_db = linear_to_db(maxf(_theme_music_base_volume, 0.0001))
	theme_music_player.play()

func _on_navigation_section_requested(section_id: String) -> void:
	var index: int = XMB_SECTIONS.find(section_id)
	if index >= 0:
		_set_section(index)

func _on_navigation_opened_changed(opened: bool) -> void:
	if game_section != null:
		game_section.set_nav_opened(opened)

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
	backend.request("settings.update", {"default_start_section": section_id})

func _on_theme_selected(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	if index < 0 or index >= _theme_ids.size():
		return
	var theme_id: String = _theme_ids[index]
	if theme_id == str(_current_theme.get("id", "")):
		return
	_pending_theme_switch_id = backend.request("settings.update", {"current_theme": theme_id})

func _on_window_mode_selected(index: int) -> void:
	var mode := "windowed" if index == 0 else "fullscreen"
	_apply_window_mode(mode)
	if backend != null and backend.is_connected_to_backend():
		backend.request("settings.update", {"window_mode": mode})

func _on_fontset_selected(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	if index < 0 or index >= _fontset_ids.size():
		return
	var fs_id: String = _fontset_ids[index]
	if fs_id == _fontset_id:
		return
	_fontset_id = fs_id
	_pending_fontset_switch_id = backend.request("settings.update", {"fontset_id": fs_id})

func _on_fontset_selected_games(index: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	if index < 0 or index >= _fontset_ids_games.size():
		return
	var fs_id: String = _fontset_ids_games[index]
	if fs_id == _fontset_id_games:
		return
	_fontset_id_games = fs_id
	_pending_fontset_switch_id_games = backend.request(
		"settings.update", {"fontset_id_games": fs_id}
	)

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
	var req_id: String = backend.request("fontsets.get", {"id": fs_id, "scope": scope})
	if scope == "movies":
		_pending_fontset_get_id = req_id
	else:
		_pending_fontset_get_id_games = req_id

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
	var scope: String = str(payload.get("scope", "movies"))
	var is_games: bool = (scope == "games")
	var req: String = ""
	match action:
		"save":
			req = backend.request("fontsets.save", payload)
			if is_games:
				_pending_fontsets_save_id_games = req
			else:
				_pending_fontsets_save_id = req
		"create":
			req = backend.request("fontsets.create", payload)
			if is_games:
				_pending_fontsets_create_id_games = req
			else:
				_pending_fontsets_create_id = req
		"rename":
			req = backend.request("fontsets.rename", payload)
			if is_games:
				_pending_fontsets_rename_id_games = req
			else:
				_pending_fontsets_rename_id = req
		"delete":
			req = backend.request("fontsets.delete", payload)
			if is_games:
				_pending_fontsets_delete_id_games = req
			else:
				_pending_fontsets_delete_id = req

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
	var index: int = XMB_SECTIONS.find(section)
	if index >= 0 and index < XMB_SECTION_LABELS.size():
		return XMB_SECTION_LABELS[index]
	return section

func _delayed_pause_render() -> void:
	_delayed_pause_generation += 1
	var gen: int = _delayed_pause_generation
	await get_tree().create_timer(0.6).timeout
	if gen != _delayed_pause_generation:
		return
	RenderingServer.render_loop_enabled = false

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
		var ui_font: FontFile = font_manager.get_font_for("ui_default", "movies")
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
	var f: FontFile = font_manager.get_font_for(key, scope)
	if f != null:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")

func _update_movie_info_layout() -> void:
	if movie_wall == null or movie_info_title == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var raw: float = min(vp.x / UI_BASE_WIDTH, vp.y / UI_BASE_HEIGHT)
	var ui_scale: float = clampf(raw, 0.70, 1.30)
	var font_scale: float = clampf(raw, 0.90, 1.30)
	var base_title := 34
	var base_year := 14
	var base_meta := 14
	var base_desc := 16
	if font_manager != null:
		base_title = font_manager.get_size_for("movie_title", 34)
		base_year = font_manager.get_size_for("movie_year", 14)
		base_meta = font_manager.get_size_for("movie_meta", 14)
		base_desc = font_manager.get_size_for("movie_desc", 16)

	movie_info_title.add_theme_font_size_override("font_size", int(float(base_title) * font_scale))
	movie_info_meta.add_theme_font_size_override("font_size", int(float(base_year) * font_scale))
	movie_info_genres.add_theme_font_size_override("font_size", int(float(base_meta) * font_scale))
	movie_desc_label.add_theme_font_size_override("font_size", int(float(base_desc) * font_scale))

	var info_left: float = vp.x * MOVIE_INFO_LEFT_RATIO
	var right_ratio: float = MOVIE_INFO_RIGHT_MARGIN / UI_BASE_WIDTH
	var info_right: float = vp.x * (1.0 - right_ratio)
	var block_width: float = info_right - info_left

	var title_y: float = vp.y * MOVIE_TITLE_FIXED_RATIO
	var desc_y: float = vp.y * (1.0 - MOVIE_DESC_FIXED_RATIO)

	# 容器高度 / 文字间距跟字号曲线走（小窗口下 ui_scale 会缩得过小，装不下字）
	var title_h: float = 50.0 * font_scale
	var meta_box_h: float = 24.0 * font_scale
	var meta_gap: float = MOVIE_META_GAP_ABOVE_TITLE * font_scale

	movie_info_title.position = Vector2(info_left, title_y)
	movie_info_title.size = Vector2(block_width, title_h)
	movie_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var font: Font = movie_info_title.get_theme_font("font")
	var font_size: int = movie_info_title.get_theme_font_size("font_size")
	var title_text: String = movie_info_title.text
	var measured: Vector2 = Vector2.ZERO
	if font != null and not title_text.is_empty():
		measured = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var title_left_x: float = info_left + block_width - measured.x
	if title_left_x < info_left:
		title_left_x = info_left

	movie_info_meta.position = Vector2(title_left_x, title_y - meta_gap)
	movie_info_meta.size = Vector2(block_width, meta_box_h)
	movie_info_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	movie_info_genres.position = Vector2(info_left, title_y + title_h)
	movie_info_genres.size = Vector2(block_width, meta_box_h)
	movie_info_genres.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var desc_height: float = vp.y - desc_y - MOVIE_DESC_BOTTOM_RESERVE * font_scale
	# 至少放得下一行（行高 ≈ 1.6 倍字号）
	var desc_font: int = movie_desc_label.get_theme_font_size("font_size")
	var min_desc: float = 1.6 * float(maxi(desc_font, 1))
	if desc_height < min_desc:
		desc_height = min_desc
	if movie_desc_scroll != null:
		movie_desc_scroll.position = Vector2(info_left, desc_y + _info_offset)
		movie_desc_scroll.size = Vector2(block_width, desc_height)
	movie_desc_label.custom_minimum_size = Vector2(block_width - 14.0 * ui_scale, 0.0)
	movie_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

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
	_pending_movie_create_id = backend.request("movie.create", scoped_payload)

func _open_movie_create_dialog() -> void:
	movie_create_dialog.show_dialog()

func _on_movie_right_clicked(movie: Dictionary, screen_position: Vector2) -> void:
	_movie_menu_target = movie
	movie_manage_menu.show_at(screen_position, _current_movie_scope)

func _on_movie_manage_action_requested(action: String) -> void:
	if _movie_menu_target.is_empty():
		return
	match action:
		"edit_metadata":
			var meta_id: String = str(_movie_menu_target.get("id", ""))
			if meta_id.is_empty():
				return
			_pending_movie_metadata_target_id = meta_id
			_pending_movie_metadata_get_id = backend.request(
				"movie.metadata.get", {"id": meta_id}
			)
		"set_cover":
			var cover_id: String = str(_movie_menu_target.get("id", ""))
			if cover_id.is_empty():
				return
			_pending_movie_cover_item_id = cover_id
			movie_cover_file_dialog.popup_centered_ratio(0.82)
		"set_backdrop":
			var bd_id: String = str(_movie_menu_target.get("id", ""))
			if bd_id.is_empty():
				return
			_pending_movie_backdrop_set_item_id = bd_id
			movie_backdrop_file_dialog.popup_centered_ratio(0.82)
		"refresh_backdrop":
			var rf_id: String = str(_movie_menu_target.get("id", ""))
			if rf_id.is_empty():
				return
			if backend == null or not backend.is_connected_to_backend():
				_show_runtime_error("重新截取失败", "后端未连接")
				return
			backend_label.text = "正在重新截取…"
			_pending_movie_backdrop_refresh_id = backend.request(
				"movie.backdrop.refresh", {"id": rf_id}
			)
		"select_poster":
			if _current_movie_scope == "private":
				_show_runtime_error("选择海报失败", "私有库已禁用 TMDB 功能")
				return
			var poster_item_id: String = str(_movie_menu_target.get("id", ""))
			if poster_item_id.is_empty():
				return
			var poster_tmdb_id: int = int(_movie_menu_target.get("tmdb_id", 0))
			if poster_tmdb_id <= 0:
				_show_runtime_error("选择海报失败", "该作品还没有 TMDB ID，请先使用「从 TMDB 获取资料」")
				return
			var poster_media_type: String = str(_movie_menu_target.get("media_type", "movie"))
			var poster_title: String = str(_movie_menu_target.get("title", ""))
			tmdb_poster_dialog.show_for(poster_item_id, poster_tmdb_id, poster_media_type, poster_title)
		"tmdb_scrape":
			if _current_movie_scope == "private":
				_show_runtime_error("从 TMDB 获取资料失败", "私有库已禁用 TMDB 功能")
				return
			var tmdb_id: String = str(_movie_menu_target.get("id", ""))
			if tmdb_id.is_empty():
				return
			_tmdb_target_item_id = tmdb_id
			var tmdb_title: String = str(_movie_menu_target.get("title", ""))
			tmdb_dialog.show_for(tmdb_id, tmdb_title)
		"scrape_sgdb":
			var sgdb_id: String = str(_movie_menu_target.get("id", ""))
			if sgdb_id.is_empty():
				return
			_sgdb_target_item_id = sgdb_id
			var sgdb_title: String = str(_movie_menu_target.get("title", ""))
			game_scraper_dialog.show_for(sgdb_id, sgdb_title)
		"remove":
			var remove_id: String = str(_movie_menu_target.get("id", ""))
			if remove_id.is_empty():
				return
			_pending_movie_remove_id = remove_id
			var remove_title: String = str(_movie_menu_target.get("title", "Untitled"))
			movie_remove_confirm.dialog_text = (
				"确定从 G3 中移除《%s》的档案吗？\n\n"
				+ "不会删除视频文件、封面图片或其他本地资源。"
			) % remove_title
			movie_remove_confirm.popup_centered()

func _on_movie_remove_confirmed() -> void:
	if _pending_movie_remove_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("移除失败", "后端未连接")
		return
	_pending_movie_remove_request_id = backend.request(
		"movie.remove", {"id": _pending_movie_remove_id}
	)

func _on_movie_cover_file_selected(path: String) -> void:
	if _pending_movie_cover_item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("设置封面失败", "后端未连接")
		return
	_pending_movie_cover_request_id = backend.request(
		"movie.cover.set",
		{"id": _pending_movie_cover_item_id, "source": path},
	)

func _on_movie_metadata_save_requested(item_id: String, metadata: Dictionary) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("保存电影资料失败", "后端未连接")
		return
	var payload: Dictionary = metadata.duplicate(true)
	payload["id"] = item_id
	_pending_movie_metadata_update_id = backend.request("movie.metadata.update", payload)

func _on_movie_double_clicked(movie: Dictionary) -> void:
	var item_id: String = str(movie.get("id", ""))
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("播放失败", "后端未连接")
		return
	_pending_movie_play_id = backend.request("movie.play", {"id": item_id})

func _on_archive_launch_requested(game: Dictionary) -> void:
	if str(game.get("id", "")).is_empty():
		archive_gallery.set_launch_result(false, "档案编号缺失")
		return
	if backend == null or not backend.is_connected_to_backend():
		archive_gallery.set_launch_result(false, "后端未连接")
		return
	if not _pending_game_play_id.is_empty():
		archive_gallery.set_launch_result(false, "已有启动请求正在处理")
		return
	_on_game_double_clicked(game)
	if _pending_game_play_id.is_empty():
		archive_gallery.set_launch_result(false, "请求未发送，请重试")

func _on_game_double_clicked(game: Dictionary) -> void:
	var item_id: String = str(game.get("id", ""))
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("启动失败", "后端未连接")
		return
	# Steam 游戏走 URL 启动，拿不到进程句柄也不知道何时退出 → 不暂停渲染
	# Epic 走 exe 启动（拿得到句柄），所以要暂停渲染，靠 exited 事件恢复
	var source: String = str(game.get("source", "manual")).to_lower()
	if source != "steam":
		_delayed_pause_render()
	# 详情页开着的话，先给按钮一个"启动中…"的即时反馈
	if game_section != null and game_section.is_detail_open():
		game_section.set_detail_launching(true)
	_pending_game_play_id = backend.request("game.play", {"id": item_id})

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
	_pending_emulators_for_create_id = backend.request("emulators.list", {})

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
	var item_id: String = str(game.get("id", ""))
	if item_id.is_empty():
		return
	match action:
		"scrape_sgdb":
			_sgdb_target_item_id = item_id
			var sgdb_query: String = str(game.get("english_name", "")).strip_edges()
			if sgdb_query.is_empty():
				sgdb_query = str(game.get("title", ""))
			game_scraper_dialog.show_for(item_id, sgdb_query)
		"steam_metadata":
			_steam_target_item_id = item_id
			var steam_query: String = str(game.get("english_name", "")).strip_edges()
			if steam_query.is_empty():
				steam_query = str(game.get("title", ""))
			steam_search_dialog.show_for(item_id, steam_query)
		"edit_metadata":
			if backend == null or not backend.is_connected_to_backend():
				_show_runtime_error("编辑资料失败", "后端未连接")
				return
			_pending_game_metadata_target_id = item_id
			_pending_game_metadata_get_id = backend.request(
				"game.metadata.get", {"id": item_id}
			)
		"paste_import":
			_paste_target_item_id = item_id
			game_paste_import_dialog.show_for_item(item_id, str(game.get("title", "")))			
		"browse_game_dir":
			var dir: String = ""
			var launch_exe: String = str(game.get("launch_exe", "")).strip_edges()
			if not launch_exe.is_empty():
				dir = launch_exe.get_base_dir()
			else:
				var sp: String = str(game.get("source_path", "")).strip_edges()
				if not sp.is_empty():
					dir = sp.get_base_dir()
			if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
				_show_runtime_error("浏览失败", "找不到游戏目录")
			else:
				OS.shell_open("file:///" + dir.replace("\\", "/").lstrip("/"))
			return
		"browse_assets_dir":
			var cover_dir: String = str(game.get("cover_dir", "")).strip_edges()
			if cover_dir.is_empty() or not DirAccess.dir_exists_absolute(cover_dir):
				_show_runtime_error("浏览失败", "素材文件夹不存在（可能还没刮削素材）")
			else:
				OS.shell_open("file:///" + cover_dir.replace("\\", "/").lstrip("/"))
			return
		"edit_launch":
			if backend == null or not backend.is_connected_to_backend():
				_show_runtime_error("编辑启动设置失败", "后端未连接")
				return
			_pending_game_launch_target_id = item_id
			_pending_game_launch_get_id = backend.request(
				"game.metadata.get", {"id": item_id}
			)
		"edit_playtime":
			var pe_item_id: String = str(_game_menu_target.get("id", ""))
			if pe_item_id.is_empty():
				return
			var cur_secs: int = int(_game_menu_target.get("playtime_seconds", 0))
			playtime_edit_dialog.show_for(pe_item_id, cur_secs)
		"remove":
			_pending_game_remove_id = item_id
			var remove_title: String = str(game.get("title", "Untitled"))
			game_remove_confirm.dialog_text = (
				"确定从 G3 中移除《%s》的档案吗？\n\n"
				+ "不会删除游戏本体、封面图片、媒体素材或存档。"
			) % remove_title
			game_remove_confirm.popup_centered()

func _on_game_metadata_save_requested(item_id: String, metadata: Dictionary) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("保存游戏资料失败", "后端未连接")
		return
	var payload: Dictionary = metadata.duplicate(true)
	payload["id"] = item_id
	_pending_game_metadata_update_id = backend.request("game.metadata.update", payload)

func _on_game_launch_save_requested(item_id: String, profile: Dictionary) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("保存启动设置失败", "后端未连接")
		return
	var payload: Dictionary = profile.duplicate(true)
	payload["id"] = item_id
	_pending_game_launch_update_id = backend.request("game.launch_profile.update", payload)

func _on_playtime_save_requested(item_id: String, seconds: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("保存失败", "后端未连接")
		return
	_pending_playtime_set_id = backend.request(
		"game.playtime.set",
		{"id": item_id, "seconds": seconds},
	)

func _on_game_remove_confirmed() -> void:
	if _pending_game_remove_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("移除失败", "后端未连接")
		return
	_pending_game_remove_request_id = backend.request(
		"game.remove", {"id": _pending_game_remove_id}
	)

func _on_steam_search_requested(query: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("Steam 搜索失败", "后端未连接")
		return
	_pending_steam_search_id = backend.request("game.scrape.search", {"query": query})

func _on_steam_apply_requested(item_id: String, external_id: int) -> void:
	if item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	_pending_steam_apply_id = backend.request("game.scrape.apply", {
		"id": item_id,
		"source": "steam",
		"external_id": external_id,
	})

func _on_sgdb_search_requested(query: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("搜索失败", "后端未连接")
		return
	_pending_sgdb_search_id = backend.request("sgdb.search", {"query": query})

func _on_sgdb_assets_requested(sgdb_id: int, asset_type: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	var req_id: String = backend.request("sgdb.assets", {
		"sgdb_id": sgdb_id,
		"asset_type": asset_type,
	})
	if req_id.is_empty():
		return
	_pending_sgdb_assets_ids[req_id] = asset_type

func _on_sgdb_apply_requested(sgdb_id: int, asset_type: String, url: String) -> void:
	if _sgdb_target_item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("应用素材失败", "后端未连接")
		return
	var req_id: String = backend.request("sgdb.apply", {
		"id": _sgdb_target_item_id,
		"sgdb_id": sgdb_id,
		"asset_type": asset_type,
		"url": url,
	})
	if req_id.is_empty():
		return
	_pending_sgdb_apply_ids[req_id] = asset_type

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
	_pending_cover_folder_set_id = backend.request(
		"settings.set_movie_cover_folder",
		{"folder": "", "scope": _current_movie_scope}
	)

func _on_cover_folder_dir_selected(path: String) -> void:
	if path.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		return
	_pending_cover_folder_set_id = backend.request(
		"settings.set_movie_cover_folder",
		{"folder": path, "scope": _current_movie_scope}
	)

func _on_match_local_covers_pressed() -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("匹配失败", "后端未连接")
		return
	_pending_cover_match_id = backend.request(
		"movie.covers.match_local",
		{"scope": _current_movie_scope}
	)
	backend_label.text = "正在匹配封面…"

func _rebuild_cover_folder_ui() -> void:
	if _cover_folder_label == null:
		return
	if _cover_folder_title != null:
		_cover_folder_title.text = "封面文件夹（私有库）" if _current_movie_scope == "private" else "封面文件夹（主库）"
	var folder: String = _movie_cover_folder_private if _current_movie_scope == "private" else _movie_cover_folder_main
	_cover_folder_label.text = folder if not folder.is_empty() else "（未设置）"

# ---------------------------------------------------------------------------
# 模拟器配置

func _refresh_emulators() -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	_pending_emulators_list_id = backend.request("emulators.list", {})

func _rebuild_emulator_list() -> void:
	if _emulator_list == null:
		return
	for child in _emulator_list.get_children():
		_emulator_list.remove_child(child)
		child.queue_free()
	if _emulators.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（尚未添加）"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", _theme_muted)
		_emulator_list.add_child(empty_label)
		return
	for entry in _emulators:
		if entry is Dictionary:
			_emulator_list.add_child(_make_emulator_row(entry as Dictionary))

func _make_emulator_row(emulator: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(emulator.get("name", ""))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	info.add_child(name_label)

	var detail_parts: Array[String] = []
	var platform_text: String = str(emulator.get("platform_tag", "")).strip_edges()
	if not platform_text.is_empty():
		detail_parts.append(platform_text)
	var exe_text: String = str(emulator.get("executable", "")).strip_edges()
	detail_parts.append(exe_text if not exe_text.is_empty() else "未配置 EXE")
	var scan_count: int = 0
	var raw_dirs: Variant = emulator.get("scan_dirs", [])
	if raw_dirs is Array:
		scan_count = (raw_dirs as Array).size()
	if scan_count > 0:
		detail_parts.append("%d 个扫描目录" % scan_count)
	var detail := Label.new()
	detail.text = "  ·  ".join(detail_parts)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", _theme_muted)
	info.add_child(detail)

	var emulator_id: String = str(emulator.get("id", ""))
	var edit_btn := Button.new()
	edit_btn.text = "编辑"
	edit_btn.custom_minimum_size = Vector2(64.0, 30.0)
	edit_btn.pressed.connect(_on_edit_emulator_pressed.bind(emulator))
	row.add_child(edit_btn)

	var remove_btn := Button.new()
	remove_btn.text = "移除"
	remove_btn.custom_minimum_size = Vector2(64.0, 30.0)
	remove_btn.pressed.connect(_on_remove_emulator_pressed.bind(emulator_id))
	row.add_child(remove_btn)
	return row

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
	_pending_emulator_save_id = backend.request("emulators.save", payload)

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
	_pending_emulator_delete_id = backend.request("emulators.delete", {"id": emulator_id})

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
	_pending_cover_tool_source_id = backend.request(
		"settings.set_cover_tool_source", {"folder": path}
	)

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
	_pending_cover_tool_scan_id = backend.request(
		"cover_tool.scan",
		{"scope": scope, "source_dir": source_dir, "overwrite": overwrite}
	)

func _on_cover_tool_apply_all(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	if items.is_empty():
		return
	_cover_tool_apply_queue = items.duplicate()
	_cover_tool_apply_done = 0
	_cover_tool_apply_failed = 0
	_dispatch_next_cover_tool_apply()

func _on_cover_tool_edit(item: Dictionary) -> void:
	if cover_crop_dialog == null:
		return
	var source_path: String = str(item.get("file_path", ""))
	var title: String = str(item.get("matched_title", ""))
	var initial_front_px: int = int(item.get("front_start_px", 0))
	if source_path.is_empty() or title.is_empty():
		return
	cover_crop_dialog.show_for(source_path, title, initial_front_px)

func _on_cover_crop_apply(source_path: String, title: String, front_start_px: int) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	var req_id: String = backend.request("cover_tool.apply_one", {
		"source_path": source_path,
		"title": title,
		"front_start_px": front_start_px,
	})
	if req_id.is_empty():
		_show_runtime_error("应用失败", "请求发送失败")
		return
	_pending_cover_tool_apply_ids.append(req_id)

func _dispatch_next_cover_tool_apply() -> void:
	if _cover_tool_apply_queue.is_empty():
		if cover_tool_dialog != null:
			cover_tool_dialog.show_apply_done(_cover_tool_apply_done, _cover_tool_apply_failed)
		_force_reload_covers_on_next_list = true
		_pending_movies_id = backend.request("library.movies.list", {"scope": _current_movie_scope})
		return
	var it: Dictionary = _cover_tool_apply_queue.pop_front()
	var source_path: String = str(it.get("file_path", ""))
	var title: String = str(it.get("matched_title", ""))
	var front_start_px: int = int(it.get("front_start_px", 0))
	if source_path.is_empty() or title.is_empty():
		_cover_tool_apply_failed += 1
		_dispatch_next_cover_tool_apply()
		return
	var req_id: String = backend.request("cover_tool.apply_one", {
		"source_path": source_path,
		"title": title,
		"front_start_px": front_start_px,
	})
	if req_id.is_empty():
		_cover_tool_apply_failed += 1
		_dispatch_next_cover_tool_apply()
		return
	_pending_cover_tool_apply_ids.append(req_id)

func _save_movie_lib_paths() -> void:
	if backend == null or not backend.is_connected_to_backend():
		_rebuild_movie_lib_paths_ui()
		return
	var source: Array[String] = _movie_library_paths_private if _current_movie_scope == "private" else _movie_library_paths
	var payload: Array = []
	for p in source:
		payload.append(p)
	_pending_set_paths_id = backend.request(
		"settings.set_movie_paths",
		{"paths": payload, "scope": _current_movie_scope}
	)
	_rebuild_movie_lib_paths_ui()

func _rebuild_movie_lib_paths_ui() -> void:
	if movie_lib_paths_list == null:
		return
	for child in movie_lib_paths_list.get_children():
		child.queue_free()

	# 标题跟随当前库
	if _lib_title_label != null:
		_lib_title_label.text = "影视库文件夹（私有库）" if _current_movie_scope == "private" else "影视库文件夹（主库）"

	var source: Array[String] = _movie_library_paths_private if _current_movie_scope == "private" else _movie_library_paths
	if source.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（尚未添加）"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", _theme_muted)
		movie_lib_paths_list.add_child(empty_label)
		return
	for path in source:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = path
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		row.add_child(label)
		var remove_btn := Button.new()
		remove_btn.text = "移除"
		remove_btn.custom_minimum_size = Vector2(60.0, 0.0)
		remove_btn.pressed.connect(_on_remove_movie_lib.bind(path))
		row.add_child(remove_btn)
		movie_lib_paths_list.add_child(row)

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
			_paste_target_item_id = ""
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
	var command: String = ""
	var label_text: String = ""
	match tab_id:
		"emulator":
			command = "game.scan_emulator"
			label_text = "正在扫描模拟器游戏…"
		"steam":
			command = "game.scan_steam_library"
			label_text = "正在扫描 Steam 库…"
		"gog":
			command = "game.scan_gog_library"
			label_text = "正在扫描 GOG 库…"
		"epic":
			command = "game.scan_epic_library"
			label_text = "正在扫描 Epic 库…"
		"uplay":
			command = "game.scan_uplay_library"
			label_text = "正在扫描 Uplay 库…"
		"rockstar":
			command = "game.scan_rockstar_library"
			label_text = "正在扫描 Rockstar 库…"
		"psn":
			command = "game.scan_psn_library"
			label_text = "正在扫描 PSN 库…"					
		_:
			return
	var req_id: String = backend.request(command, {})
	if req_id.is_empty():
		return
	# 响应处理仍按原来的 _pending_xxx_scan_id 分发，所以这里也要记一份
	match tab_id:
		"emulator":
			_pending_game_scan_emulator_id = req_id
		"steam":
			_pending_steam_scan_id = req_id
		"gog":
			_pending_gog_scan_id = req_id
		"epic":
			_pending_epic_scan_id = req_id
		"uplay":
			_pending_uplay_scan_id = req_id
		"rockstar":
			_pending_rockstar_scan_id = req_id
		"psn":
			_pending_psn_scan_id = req_id
	backend_label.text = label_text

func _on_library_scan_dialog_closed() -> void:
	# 对话框内部会自己清空 4 个 tab 的缓存
	pass

func _prepare_library_scan_tab(tab_id: String) -> void:
	if library_scan_dialog != null:
		library_scan_dialog.begin_scan(tab_id)

func _show_library_scan_error(tab_id: String, message: String) -> void:
	if library_scan_dialog != null:
		library_scan_dialog.show_scan_error(tab_id, message)

func _on_library_scan_import_requested(tab_id: String, items: Array) -> void:
	match tab_id:
		"emulator":
			_on_emulator_scan_import_requested(items)
		"steam":
			_on_steam_scan_import_requested(items)
		"gog":
			_on_gog_scan_import_requested(items)
		"epic":
			_on_epic_scan_import_requested(items)
		"uplay":
			_on_uplay_scan_import_requested(items)
		"rockstar":
			_on_rockstar_scan_import_requested(items)
		"psn":
			_on_psn_scan_import_requested(items)

func _on_emulator_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var created: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("suggested_title", "")).strip_edges()
		var rom_path: String = str(item.get("rom_path", "")).strip_edges()
		if title.is_empty() or rom_path.is_empty():
			continue
		var req_id: String = backend.request("game.create", {
			"title": title,
			"platform": str(item.get("platform_tag", "")),
			"profile_type": "emulator",
			"video_path": rom_path,
			"content_path": rom_path,
			"launch_exe": str(item.get("launch_exe", "")),
			"launch_args": str(item.get("launch_args", "")),
			"working_directory": str(item.get("working_directory", "")),
			"cover_source": "",
		})
		if req_id.is_empty():
			continue
		_pending_game_scan_create_ids.append(req_id)
		created += 1

	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1

	_scan_import_total = created
	_scan_import_done = 0
	_scan_import_added = 0
	_scan_import_errors = 0
	_scan_import_skipped = skipped_existing
	if created == 0:
		_finish_scan_import()
	else:
		backend_label.text = "正在导入 %d 个游戏…" % created

func _on_steam_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var created: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("name", "")).strip_edges()
		# 注意：GDScript 的 `x or default` 返回 bool，不能用来给默认值
		var appid: int = int(item.get("steam_appid", 0))
		if title.is_empty() or appid <= 0:
			continue
		var req_id: String = backend.request("game.create", {
			"title": title,
			"platform": "Steam",
			"profile_type": "direct",
			"launch_exe": "",
			"video_path": "",
			"content_path": "",
			"source": "steam",
			"steam_appid": appid,
			"cover_source": "",
		})
		if req_id.is_empty():
			continue
		_pending_steam_scan_create_ids.append(req_id)
		created += 1

	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1

	_steam_scan_import_total = created
	_steam_scan_import_done = 0
	_steam_scan_import_added = 0
	_steam_scan_import_errors = 0
	_steam_scan_import_skipped = skipped_existing
	if created == 0:
		_finish_steam_scan_import()
	else:
		backend_label.text = "正在导入 %d 个 Steam 游戏…" % created

func _on_gog_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var created: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var game_id: String = str(item.get("game_id", "")).strip_edges()
		if title.is_empty() or game_id.is_empty():
			continue
		var req_id: String = backend.request("game.create", {
			"title": title,
			"platform": "GOG",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"working_directory": str(item.get("working_directory", "")),
			"video_path": "",
			"content_path": "",
			"source": "gog",
			"external_id": game_id,
			"cover_source": "",
		})
		if req_id.is_empty():
			continue
		_pending_gog_scan_create_ids.append(req_id)
		created += 1

	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1

	_gog_scan_import_total = created
	_gog_scan_import_done = 0
	_gog_scan_import_added = 0
	_gog_scan_import_errors = 0
	_gog_scan_import_skipped = skipped_existing
	if created == 0:
		_finish_gog_scan_import()
	else:
		backend_label.text = "正在导入 %d 个 GOG 游戏…" % created

func _on_epic_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var created: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var app_name: String = str(item.get("app_name", "")).strip_edges()
		if title.is_empty() or app_name.is_empty():
			continue
		var req_id: String = backend.request("game.create", {
			"title": title,
			"platform": "Epic",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"video_path": "",
			"content_path": "",
			"source": "epic",
			"external_id": app_name,
			"namespace_id": str(item.get("namespace_id", "")),
			"artifact_id": str(item.get("artifact_id", "")),
			"cover_source": "",
		})
		if req_id.is_empty():
			continue
		_pending_epic_scan_create_ids.append(req_id)
		created += 1

	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1

	_epic_scan_import_total = created
	_epic_scan_import_done = 0
	_epic_scan_import_added = 0
	_epic_scan_import_errors = 0
	_epic_scan_import_skipped = skipped_existing
	if created == 0:
		_finish_epic_scan_import()
	else:
		backend_label.text = "正在导入 %d 个 Epic 游戏…" % created

func _finish_epic_scan_import() -> void:
	var added: int = _epic_scan_import_added
	var errors: int = _epic_scan_import_errors
	var skipped: int = _epic_scan_import_skipped
	_epic_scan_import_total = 0
	_epic_scan_import_done = 0
	_epic_scan_import_added = 0
	_epic_scan_import_errors = 0
	_epic_scan_import_skipped = 0
	_pending_epic_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		_clear_runtime_error()
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("epic", added, skipped, errors)
	# 刷新游戏列表
	_pending_games_id = backend.request("library.games.list", {})

func _on_uplay_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var created: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		# 用户即使勾了「已存在」也跳过，不覆盖老条目
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var game_id: String = str(item.get("game_id", "")).strip_edges()
		if title.is_empty() or game_id.is_empty():
			continue
		var req_id: String = backend.request("game.create", {
			"title": title,
			"platform": "Uplay",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"working_directory": str(item.get("working_directory", "")),
			"video_path": "",
			"content_path": "",
			"source": "uplay",
			"external_id": game_id,
			"cover_source": "",
		})
		if req_id.is_empty():
			continue
		_pending_uplay_scan_create_ids.append(req_id)
		created += 1

	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1

	_uplay_scan_import_total = created
	_uplay_scan_import_done = 0
	_uplay_scan_import_added = 0
	_uplay_scan_import_errors = 0
	_uplay_scan_import_skipped = skipped_existing
	if created == 0:
		_finish_uplay_scan_import()
	else:
		backend_label.text = "正在导入 %d 个 Uplay 游戏…" % created

func _finish_uplay_scan_import() -> void:
	var added: int = _uplay_scan_import_added
	var errors: int = _uplay_scan_import_errors
	var skipped: int = _uplay_scan_import_skipped
	_uplay_scan_import_total = 0
	_uplay_scan_import_done = 0
	_uplay_scan_import_added = 0
	_uplay_scan_import_errors = 0
	_uplay_scan_import_skipped = 0
	_pending_uplay_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		_clear_runtime_error()
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("uplay", added, skipped, errors)
	# 刷新游戏列表
	_pending_games_id = backend.request("library.games.list", {})

func _on_rockstar_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("导入失败", "后端未连接")
		return

	var created: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		if bool(item.get("already_exists", false)):
			continue
		var title: String = str(item.get("title", "")).strip_edges()
		var game_id: String = str(item.get("game_id", "")).strip_edges()
		if title.is_empty() or game_id.is_empty():
			continue
		var req_id: String = backend.request("game.create", {
			"title": title,
			"platform": "Rockstar",
			"profile_type": "direct",
			"launch_exe": str(item.get("launch_exe", "")),
			"working_directory": str(item.get("working_directory", "")),
			"video_path": "",
			"content_path": "",
			"source": "rockstar",
			"external_id": game_id,
			"cover_source": "",
		})
		if req_id.is_empty():
			continue
		_pending_rockstar_scan_create_ids.append(req_id)
		created += 1

	var skipped_existing: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped_existing += 1

	_rockstar_scan_import_total = created
	_rockstar_scan_import_done = 0
	_rockstar_scan_import_added = 0
	_rockstar_scan_import_errors = 0
	_rockstar_scan_import_skipped = skipped_existing
	if created == 0:
		_finish_rockstar_scan_import()
	else:
		backend_label.text = "正在导入 %d 个 Rockstar 游戏…" % created

func _finish_rockstar_scan_import() -> void:
	var added: int = _rockstar_scan_import_added
	var errors: int = _rockstar_scan_import_errors
	var skipped: int = _rockstar_scan_import_skipped
	_rockstar_scan_import_total = 0
	_rockstar_scan_import_done = 0
	_rockstar_scan_import_added = 0
	_rockstar_scan_import_errors = 0
	_rockstar_scan_import_skipped = 0
	_pending_rockstar_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		_clear_runtime_error()
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("rockstar", added, skipped, errors)
	# 刷新游戏列表
	_pending_games_id = backend.request("library.games.list", {})

func _finish_gog_scan_import() -> void:
	var added: int = _gog_scan_import_added
	var errors: int = _gog_scan_import_errors
	var skipped: int = _gog_scan_import_skipped
	_gog_scan_import_total = 0
	_gog_scan_import_done = 0
	_gog_scan_import_added = 0
	_gog_scan_import_errors = 0
	_gog_scan_import_skipped = 0
	_pending_gog_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		_clear_runtime_error()
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("gog", added, skipped, errors)
	# 刷新游戏列表
	_pending_games_id = backend.request("library.games.list", {})

func _finish_steam_scan_import() -> void:
	var added: int = _steam_scan_import_added
	var errors: int = _steam_scan_import_errors
	var skipped: int = _steam_scan_import_skipped
	_steam_scan_import_total = 0
	_steam_scan_import_done = 0
	_steam_scan_import_added = 0
	_steam_scan_import_errors = 0
	_steam_scan_import_skipped = 0
	_pending_steam_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		_clear_runtime_error()
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("steam", added, skipped, errors)
	# 刷新游戏列表
	_pending_games_id = backend.request("library.games.list", {})

func _finish_scan_import() -> void:
	var added: int = _scan_import_added
	var errors: int = _scan_import_errors
	var skipped: int = _scan_import_skipped
	_scan_import_total = 0
	_scan_import_done = 0
	_scan_import_added = 0
	_scan_import_errors = 0
	_scan_import_skipped = 0
	_pending_game_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过已存在 %d · 失败 %d" % [
			added, skipped, errors
		])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过已存在 %d" % [added, skipped]
		_clear_runtime_error()
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("emulator", added, skipped, errors)
	# 刷新游戏列表
	_pending_games_id = backend.request("library.games.list", {})

func _on_paste_import_apply(payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("粘贴失败", "后端未连接")
		return
	var target: String = str(payload.get("target_item_id", ""))
	var parsed: Dictionary = payload.duplicate()
	parsed.erase("target_item_id")

	# 年份：优先 release_year，没有就 release_date。GDScript 的 `or` 返回 bool，要显式判空
	var year_value: String = str(parsed.get("release_year", "")).strip_edges()
	if year_value.is_empty():
		year_value = str(parsed.get("release_date", "")).strip_edges()

	if target.is_empty():
		# 新建：标题 + 元数据一起提交
		var create_payload: Dictionary = {
			"title": str(parsed.get("title", "")),
			"english_name": str(parsed.get("english_name", "")),
			"platform": str(parsed.get("platform", "")),
			"developer": str(parsed.get("developer", "")),
			"publisher": str(parsed.get("publisher", "")),
			"genres": str(parsed.get("genres", "")),
			"tags": str(parsed.get("tags", "")),
			"profile_type": "direct",
			"video_path": "",
			"launch_exe": "",
			"content_path": "",
			"launch_args": "",
			"working_directory": "",
			"cover_source": "",
			"release_year": year_value,
			"description": str(parsed.get("description", "")),
		}
		_pending_paste_create_id = backend.request("game.create", create_payload)
	else:
		# 更新已有条目
		var update_payload: Dictionary = {
			"id": target,
			"title": str(parsed.get("title", "")),
			"english_name": str(parsed.get("english_name", "")),
			"platform": str(parsed.get("platform", "")),
			"developer": str(parsed.get("developer", "")),
			"publisher": str(parsed.get("publisher", "")),
			"release_year": year_value,
			"genres": str(parsed.get("genres", "")),
			"tags": str(parsed.get("tags", "")),
			"description": str(parsed.get("description", "")),
		}
		_pending_paste_update_id = backend.request("game.metadata.update", update_payload)


func _on_game_create_requested(payload: Dictionary) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("添加游戏失败", "后端未连接")
		return
	_pending_game_create_id = backend.request("game.create", payload)

func _start_movie_scan() -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("扫描失败", "后端未连接")
		return
	if _movie_library_paths.is_empty():
		_show_runtime_error("扫描失败", "未配置影视库文件夹（前往系统页面添加）")
		return
	backend_label.text = "正在扫描影视库…"
	_pending_movie_scan_id = backend.request("library.scan_movies", {"scope": _current_movie_scope})

func _on_movie_backdrop_file_selected(path: String) -> void:
	if _pending_movie_backdrop_set_item_id.is_empty() or backend == null:
		return
	if not backend.is_connected_to_backend():
		_show_runtime_error("设置背景图失败", "后端未连接")
		return
	_pending_movie_backdrop_set_id = backend.request(
		"movie.backdrop.set",
		{"id": _pending_movie_backdrop_set_item_id, "source": path},
	)

func _on_movie_episode_clicked(item_id: String, episode_id: String) -> void:
	if item_id.is_empty() or episode_id.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("播放失败", "后端未连接")
		return
	_pending_movie_play_id = backend.request(
		"movie.play", {"id": item_id, "episode_id": episode_id}
	)

func _try_restore_movie() -> void:
	if not (_movies_ready and _state_ready):
		return
	var rid: String = _restore_movie_id
	_restore_movie_id = ""
	if rid.is_empty():
		return
	for i in range(movie_wall.movies.size()):
		if str(movie_wall.movies[i].get("id", "")) == rid:
			movie_wall.jump_to_index(i)
			return

func _on_tmdb_search_requested(query: String, media_type: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("TMDB 搜索失败", "后端未连接")
		return
	_pending_tmdb_search_id = backend.request("tmdb.search", {
		"query": query,
		"media_type": media_type,
	})

func _on_tmdb_apply_requested(tmdb_id: int, media_type: String) -> void:
	if _tmdb_target_item_id.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用失败", "后端未连接")
		return
	_pending_tmdb_apply_id = backend.request("tmdb.apply", {
		"id": _tmdb_target_item_id,
		"tmdb_id": tmdb_id,
		"media_type": media_type,
	})

func _on_poster_list_requested(tmdb_id: int, media_type: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("读取海报列表失败", "后端未连接")
		return
	_pending_poster_list_id = backend.request("tmdb.poster.list", {
		"tmdb_id": tmdb_id,
		"media_type": media_type,
	})

func _on_poster_thumb_requested(file_path: String) -> void:
	if backend == null or not backend.is_connected_to_backend():
		tmdb_poster_dialog.on_thumb_response(file_path, "")
		return
	var req_id: String = backend.request("tmdb.poster.thumb", {
		"file_path": file_path,
	})
	if req_id.is_empty():
		tmdb_poster_dialog.on_thumb_response(file_path, "")
		return
	_pending_poster_thumb_ids[req_id] = file_path

func _on_poster_apply_requested(file_path: String) -> void:
	var item_id: String = str(_movie_menu_target.get("id", ""))
	if item_id.is_empty():
		return
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("应用海报失败", "后端未连接")
		return
	_pending_poster_apply_id = backend.request("tmdb.poster.apply", {
		"id": item_id,
		"file_path": file_path,
	})

func _on_psn_scan_import_requested(items: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		return
	var created: int = 0
	for raw in items:
		if not (raw is Dictionary): continue
		var item: Dictionary = raw as Dictionary
		if bool(item.get("already_exists", false)): continue
		
		var req_id: String = backend.request("game.create", {
			"title": str(item.get("title", "")),
			"english_name": str(item.get("english_name", "")), # 👈 确保加上这行
			"platform": str(item.get("platform", "")),
			"profile_type": "direct",
			"launch_exe": "",
			"video_path": "",
			"content_path": "",
			"source": "psn",
			"external_id": str(item.get("external_id", "")),
			"psn_playtime_seconds": int(item.get("psn_playtime_seconds", 0)),
		})
		if not req_id.is_empty():
			_pending_psn_scan_create_ids.append(req_id)
			created += 1

	var skipped: int = 0
	for raw in items:
		if raw is Dictionary and bool((raw as Dictionary).get("already_exists", false)):
			skipped += 1

	_psn_scan_import_total = created
	_psn_scan_import_done = 0
	_psn_scan_import_added = 0
	_psn_scan_import_errors = 0
	_psn_scan_import_skipped = skipped
	if created == 0:
		_finish_psn_scan_import()
	else:
		backend_label.text = "正在导入 %d 个 PSN 游戏…" % created

func _finish_psn_scan_import() -> void:
	var added: int = _psn_scan_import_added
	var errors: int = _psn_scan_import_errors
	var skipped: int = _psn_scan_import_skipped
	_psn_scan_import_total = 0
	_psn_scan_import_done = 0
	_psn_scan_import_added = 0
	_psn_scan_import_errors = 0
	_psn_scan_import_skipped = 0
	_pending_psn_scan_create_ids.clear()
	if errors > 0:
		_show_runtime_error("导入完成", "新增 %d · 跳过 %d · 失败 %d" % [added, skipped, errors])
	else:
		backend_label.text = "导入完成：新增 %d · 跳过 %d" % [added, skipped]
	if library_scan_dialog != null:
		library_scan_dialog.set_import_done("psn", added, skipped, errors)
	_pending_games_id = backend.request("library.games.list", {})

func _on_game_batch_remove(item_id: String) -> void:
	if backend != null and backend.is_connected_to_backend():
		backend.request("game.remove", {"id": item_id})

func _on_batch_scrape_requested(item_ids: Array) -> void:
	if backend == null or not backend.is_connected_to_backend():
		_show_runtime_error("批量刮削失败", "后端未连接")
		return
	
	_batch_scrape_queue.clear()
	for id in item_ids:
		# 从当前游戏列表中提取完整数据
		for g in game_section._all_games:
			if str(g.get("id")) == str(id):
				_batch_scrape_queue.append(g)
				break
				
	_is_batch_scraping = true
	backend_label.text = "开始批量刮削 %d 个游戏…" % _batch_scrape_queue.size()
	_process_next_batch_scrape()

func _process_next_batch_scrape() -> void:
	if _batch_scrape_queue.is_empty():
		_is_batch_scraping = false
		backend_label.text = "批量刮削完成！"
		_clear_runtime_error()
		_pending_games_id = backend.request("library.games.list", {})
		return
		
	var game = _batch_scrape_queue.pop_front()
	_current_batch_item = game
	var title = str(game.get("english_name", ""))
	if title.is_empty():
		title = str(game.get("title", ""))
		
	backend_label.text = "正在搜索：%s（剩余 %d）" % [title, _batch_scrape_queue.size()]
	
	# 调 Steam 搜索
	_pending_steam_search_id = backend.request("game.scrape.search", {"query": title})
