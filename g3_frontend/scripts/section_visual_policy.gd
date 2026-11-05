extends RefCounted

# Static section-specific visual rules. This is not a selectable theme system.
const PRIVATE_ACCENT: Color = Color(0.95, 0.22, 0.72)
const PRIVATE_MUTED: Color = Color(0.78, 0.55, 0.68)
const PRIVATE_BASE_TOP: Color = Color(0.18, 0.04, 0.13)
# WB-04.1-B：游戏版块侧边栏顶部底色（与 game_section.SIDEBAR_BG 同值 #111923）。
# 菜单栏与侧边栏顶部共边，必须共用同一个底色，否则交界处会出现色差。
const GAME_SIDEBAR_TOP: Color = Color(0.0666667, 0.0980392, 0.1372549, 1.0)

# Section-specific presentation remains local to the existing board visual rules.
# main.gd still owns section activation, visibility, transitions, and system refresh.
static func apply_navigation_colors(navigation_drawer: Variant, section: String, movie_scope: String, ui_accent: Color, ui_muted: Color) -> void:
	var is_movies_main: bool = (section == "MOVIES") and (movie_scope == "main")
	var is_movies_private: bool = (section == "MOVIES") and (movie_scope == "private")
	var is_games: bool = (section == "GAMES")
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
			navigation_drawer.set_theme_colors(ui_accent, ui_muted)

static func apply_window_colors(window_chrome: Variant, section: String, movie_scope: String, ui_text: Color, ui_muted: Color, ui_accent: Color, ui_base_top: Color) -> void:
	var is_movies_main: bool = (section == "MOVIES") and (movie_scope == "main")
	var is_movies_private: bool = (section == "MOVIES") and (movie_scope == "private")
	var is_games: bool = (section == "GAMES")
	if window_chrome != null:
		if is_movies_main:
			window_chrome.set_theme_colors(
				ui_text,
				Color(0.75, 0.65, 0.50),
				Color(0.88, 0.66, 0.36),
				Color(0.08, 0.05, 0.03)
			)
		elif is_movies_private:
			window_chrome.set_theme_colors(
				ui_text,
				PRIVATE_MUTED,
				PRIVATE_ACCENT,
				PRIVATE_BASE_TOP
			)
		elif is_games:
			window_chrome.set_theme_colors(
				ui_text,
				Color(0.55, 0.65, 0.78),    # muted：灰蓝
				Color(0.50, 0.72, 0.95),    # accent：亮蓝
				GAME_SIDEBAR_TOP            # base：与侧边栏顶部同底色
			)
		else:
			window_chrome.set_theme_colors(
				ui_text,
				ui_muted,
				ui_accent,
				ui_base_top
			)
		# WB-04.1-B：GAMES 由侧边栏广播实际合成色接管；其他板块恢复默认算法。
		if is_games:
			window_chrome.set_bar_color(GAME_SIDEBAR_TOP)
		else:
			window_chrome.set_bar_color(Color(0.0, 0.0, 0.0, 0.0))

static func apply_world_colors(movie_wall: Variant, collection_world: Node3D, key_light: DirectionalLight3D, fill_light: DirectionalLight3D, rim_light: DirectionalLight3D, navigation_drawer: Variant, section: String, movie_scope: String, ui_accent: Color) -> void:
	var is_movies_private: bool = (movie_scope == "private") and (section == "MOVIES")
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
			rim_light.light_color = ui_accent.lerp(Color.WHITE, 0.55)
	if navigation_drawer != null and navigation_drawer.has_method("set_long_press_color"):
		if movie_scope == "main":
			navigation_drawer.set_long_press_color(PRIVATE_ACCENT)
		else:
			navigation_drawer.set_long_press_color(Color(0.88, 0.66, 0.36))

static func apply_episode_drawer_colors(movie_episode_drawer: Variant, movie_scope: String) -> void:
	if movie_scope == "private":
		movie_episode_drawer.set_theme_colors(PRIVATE_ACCENT, PRIVATE_MUTED)
	else:
		movie_episode_drawer.set_theme_colors(
			Color(0.88, 0.66, 0.36),
			Color(0.75, 0.65, 0.50)
		)
