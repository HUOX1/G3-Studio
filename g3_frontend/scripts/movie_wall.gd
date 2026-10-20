extends Node3D
class_name G3MovieWall3D

signal selection_changed(index: int, movie: Dictionary)
signal main_case_right_clicked(movie: Dictionary, screen_position: Vector2)
signal main_case_double_clicked(movie: Dictionary)

# ============================================================
# 加载 shader（不用改）
# ============================================================
const CINEMA_AMBIENT_SHADER: Shader = preload("res://shaders/cinema_ambient.gdshader")
const MOVIE_BACKDROP_SHADER: Shader = preload("res://shaders/movie_backdrop.gdshader")
const CARD_SHADER: Shader = preload("res://shaders/movie_card.gdshader")
# 离线卡片降到的饱和度（1.0 = 原色，0.0 = 全灰）
const CARD_OFFLINE_SATURATION: float = 0.15
# 私库下卡片的亮度补偿（抵消 AGX 在暗背景上的提亮）
const CARD_BRIGHTNESS_PRIVATE: float = 0.95

# ============================================================
# 卡片布局（左侧滚动区）
# ============================================================

const CARD_WIDTH_DEFAULT: float = 3.8
const CARD_WIDTH_MIN: float = 3.0
const CARD_WIDTH_MAX: float = 4.6
const CARD_HEIGHT: float = 5.2
const CARD_GAP: float = 0.6
const WALL_SCREEN_X: float = 0.18
const WALL_Z: float = 0.5
const SELECTED_Z: float = 1.4
const SELECTED_BOOST: float = 1.12
const UNSELECTED_BRIGHTNESS: float = 0.60
const HOVER_YAW_DEGREES: float = 4.0
const HOVER_PITCH_DEGREES: float = 3.0
const SCROLL_FOLLOW: float = 12.0
const WHEEL_DEBOUNCE_MSEC: int = 60

# ============================================================
# 暖金背景层（CinemaAmbient）
# ============================================================

const AMBIENT_Z: float = -6.0
const AMBIENT_OVERSCAN: float = 1.02

# ============================================================
# 右侧背景图（MovieBackdrop）
# ============================================================

const BACKDROP_Z: float = -3.0
const BACKDROP_SCREEN_RIGHT: float = 1.005
const BACKDROP_MAX_HEIGHT_RATIO: float = 0.58
# 超过这个画幅宽度比 → 右对齐；否则居中
const BACKDROP_WIDE_THRESHOLD: float = 2.1
const BACKDROP_ROTATE_SECONDS: float = 7.0
const BACKDROP_CROSSFADE_SECONDS: float = 1.2
# 已加载背景图缓存的条目数上限
const BACKDROP_CACHE_MAX: int = 8
# 淡入速度（越大越快）
const BACKDROP_FADE_SPEED: float = 10.0
# 停止滚动后延迟多久才刷新背景图（毫秒）
const SCROLL_SETTLE_MSEC: int = 40

# ============================================================

var movies: Array[Dictionary] = []
var selected_index: int = 0
var camera: Camera3D

var _cards: Array[Node3D] = []
var _base_ys: Array[float] = []
var _scale_targets: Array[float] = []
var _z_targets: Array[float] = []
var _ambient_mesh: MeshInstance3D
var _ambient_material: ShaderMaterial
var _backdrop_mesh: MeshInstance3D
var _backdrop_material: ShaderMaterial
var _scroll_offset: float = 0.0
var _last_wheel_msec: int = 0
var _backdrop_aspect: float = 16.0 / 9.0
var _hover_index: int = -1
var _hover_offset: Vector2 = Vector2.ZERO
var _last_backdrop_key: String = ""
var _last_scroll_msec: int = 0
var _pending_backdrop_refresh: bool = false
var _backdrop_alpha: float = 0.0
var _backdrop_alpha_target: float = 0.0
var _backdrop_textures: Array[ImageTexture] = []
var _backdrop_index: int = 0
var _blend_factor: float = 1.0
var _current_backdrop_item_id: String = ""
var _backdrop_states: Dictionary = {}
var _backdrop_cache: Dictionary = {}
var _ui_offset_y: float = 0.0
var _wheel_blocked: bool = false
# 空纹理，用于清屏
var _empty_texture: ImageTexture
# 当前 palette 下的卡片亮度系数
var _card_brightness_scale: float = 1.0

func configure(cam: Camera3D) -> void:
	camera = cam
	set_process(true)
	set_process_unhandled_input(true)
	_build_ambient()
	_build_backdrop()
	get_viewport().size_changed.connect(_on_viewport_changed)

func set_movies(arr: Array[Dictionary]) -> void:
	var need_rebuild: bool = _movies_list_changed(arr)
	movies = arr
	selected_index = clampi(selected_index, 0, maxi(movies.size() - 1, 0))
	if need_rebuild:
		_rebuild()
	_refresh_backdrop(true)
	if not movies.is_empty():
		selection_changed.emit(selected_index, movies[selected_index])

func _movies_list_changed(arr: Array[Dictionary]) -> bool:
	if arr.size() != movies.size():
		return true
	for i in range(arr.size()):
		var old_id: String = str(movies[i].get("id", ""))
		var new_id: String = str(arr[i].get("id", ""))
		if old_id != new_id:
			return true
		var old_cover: String = str(movies[i].get("cover", ""))
		var new_cover: String = str(arr[i].get("cover", ""))
		if old_cover != new_cover:
			return true
		var old_offline: bool = bool(movies[i].get("offline", false))
		var new_offline: bool = bool(arr[i].get("offline", false))
		if old_offline != new_offline:
			return true
	return false


func _build_ambient() -> void:
	if _ambient_mesh != null:
		return
	_ambient_mesh = MeshInstance3D.new()
	_ambient_mesh.name = "CinemaAmbient"
	_ambient_mesh.position = Vector3(0, 0, AMBIENT_Z)
	var quad = QuadMesh.new()
	_ambient_mesh.mesh = quad
	_ambient_material = ShaderMaterial.new()
	_ambient_material.shader = CINEMA_AMBIENT_SHADER
	_ambient_material.render_priority = -1
	_ambient_mesh.material_override = _ambient_material
	add_child(_ambient_mesh)
	_ambient_mesh.custom_aabb = AABB(
		Vector3(-100.0, -100.0, -1.0),
		Vector3(200.0, 200.0, 2.0)
	)
	_resize_ambient()

func set_ambient_palette(palette: String) -> void:
	if _ambient_material == null:
		return
	if palette == "private":
		_ambient_material.set_shader_parameter("top_color", Color(0.16, 0.04, 0.12))
		_ambient_material.set_shader_parameter("bottom_color", Color(0.02, 0.01, 0.03))
		_ambient_material.set_shader_parameter("gold_color", Color(0.92, 0.24, 0.68))
		_ambient_material.set_shader_parameter("ember_color", Color(0.72, 0.16, 0.40))
		_card_brightness_scale = CARD_BRIGHTNESS_PRIVATE
	else:
		_ambient_material.set_shader_parameter("top_color", Color(0.14, 0.10, 0.06))
		_ambient_material.set_shader_parameter("bottom_color", Color(0.03, 0.02, 0.02))
		_ambient_material.set_shader_parameter("gold_color", Color(0.88, 0.66, 0.36))
		_ambient_material.set_shader_parameter("ember_color", Color(0.72, 0.34, 0.18))
		_card_brightness_scale = 1.0
	_refresh_selection()

func _build_backdrop() -> void:
	if _backdrop_mesh != null:
		return
	# 空纹理（1x1 黑）
	var empty_img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty_img.fill(Color(0, 0, 0, 1))
	_empty_texture = ImageTexture.create_from_image(empty_img)

	_backdrop_mesh = MeshInstance3D.new()
	_backdrop_mesh.name = "MovieBackdrop"
	_backdrop_mesh.position = Vector3(0, 0, BACKDROP_Z)
	var quad = QuadMesh.new()
	_backdrop_mesh.mesh = quad
	_backdrop_material = ShaderMaterial.new()
	_backdrop_material.shader = MOVIE_BACKDROP_SHADER
	_backdrop_material.render_priority = 1
	_backdrop_material.set_shader_parameter("albedo_tex", _empty_texture)
	_backdrop_material.set_shader_parameter("albedo_tex_prev", _empty_texture)
	_backdrop_mesh.material_override = _backdrop_material
	add_child(_backdrop_mesh)
	_backdrop_mesh.visible = false
	_resize_backdrop()

func _resize_ambient() -> void:
	if _ambient_mesh == null or camera == null:
		return
	var vp = get_viewport().get_visible_rect().size
	if vp.y <= 0:
		return
	var dist = absf(camera.global_position.z - _ambient_mesh.global_position.z)
	var half_h = tan(deg_to_rad(camera.fov * 0.5)) * dist
	var aspect = vp.x / vp.y
	var quad = _ambient_mesh.mesh as QuadMesh
	quad.size = Vector2(half_h * 2.0 * aspect * AMBIENT_OVERSCAN, half_h * 2.0 * AMBIENT_OVERSCAN)
	_ambient_mesh.position.x = camera.global_position.x
	_ambient_mesh.position.y = camera.global_position.y

func _resize_backdrop() -> void:
	if _backdrop_mesh == null or camera == null:
		return
	var vp = get_viewport().get_visible_rect().size
	if vp.y <= 0:
		return
	var dist = absf(camera.global_position.z - _backdrop_mesh.global_position.z)
	var half_h = tan(deg_to_rad(camera.fov * 0.5)) * dist
	var aspect = vp.x / vp.y
	var full_w = half_h * 2.0 * aspect
	var full_h = half_h * 2.0

	# 卡片右边缘的屏幕比例（在屏幕坐标里算，避免 z 不同带来的世界单位混乱）
	var card_z_dist = absf(camera.global_position.z - SELECTED_Z)
	var card_half_h = tan(deg_to_rad(camera.fov * 0.5)) * card_z_dist
	var card_full_w = card_half_h * 2.0 * aspect
	var selected_card_w: float = CARD_WIDTH_DEFAULT
	if selected_index >= 0 and selected_index < _cards.size():
		selected_card_w = float(_cards[selected_index].get_meta("card_width", CARD_WIDTH_DEFAULT))
	var card_half_ratio = (selected_card_w * 0.5 * SELECTED_BOOST) / card_full_w
	var card_right_ratio = WALL_SCREEN_X + card_half_ratio

	# 转回 backdrop 平面的世界坐标
	var avail_left_world = (card_right_ratio - 0.5) * full_w + camera.global_position.x
	var avail_right_world = (BACKDROP_SCREEN_RIGHT - 0.5) * full_w + camera.global_position.x
	var avail_w = avail_right_world - avail_left_world
	if avail_w < 0.5:
		avail_w = 0.5

	# 尺寸：先按最大高度，宽度超了就用可用宽反算
	var max_h: float = full_h * BACKDROP_MAX_HEIGHT_RATIO
	var target_h: float = max_h
	var target_w: float = target_h * _backdrop_aspect
	if target_w > avail_w:
		target_w = avail_w
		target_h = target_w / _backdrop_aspect

	var quad = _backdrop_mesh.mesh as QuadMesh
	quad.size = Vector2(target_w, target_h)

	# 定位
	if _backdrop_aspect >= BACKDROP_WIDE_THRESHOLD:
		# 超宽画幅 → 右对齐（右边缘贴屏幕右侧）
		_backdrop_mesh.position.x = avail_right_world - target_w * 0.5
	else:
		# 其余画幅 → 居中于"卡片右边缘 → 屏幕右边缘"这段可用区
		_backdrop_mesh.position.x = (avail_left_world + avail_right_world) * 0.5

	_backdrop_mesh.position.y = camera.global_position.y
	_apply_backdrop_offset()

func _refresh_backdrop(immediate: bool = false) -> void:
	if not immediate:
		_pending_backdrop_refresh = true
		return
	_pending_backdrop_refresh = false
	_do_refresh_backdrop()

func _do_refresh_backdrop() -> void:
	if _backdrop_material == null or _backdrop_mesh == null:
		return
	var paths: Array = []
	if not movies.is_empty() and selected_index >= 0 and selected_index < movies.size():
		var raw = movies[selected_index].get("backdrop", [])
		if raw is Array:
			paths = raw
	var key: String = "|".join(paths)
	if key == _last_backdrop_key and _backdrop_mesh.visible:
		return
	_last_backdrop_key = key
	_current_backdrop_item_id = ""
	if not movies.is_empty() and selected_index >= 0 and selected_index < movies.size():
		_current_backdrop_item_id = str(movies[selected_index].get("id", ""))

	if paths.is_empty():
		_backdrop_textures.clear()
		_backdrop_material.set_shader_parameter("albedo_tex", _empty_texture)
		_backdrop_material.set_shader_parameter("albedo_tex_prev", _empty_texture)
		_backdrop_mesh.visible = false
		_backdrop_alpha = 0.0
		_backdrop_alpha_target = 0.0
		return

	if _backdrop_cache.has(key):
		_apply_backdrop_from_cache(key)
		return

	WorkerThreadPool.add_task(_load_backdrop_task.bind(paths, key))

func _compute_backdrop_key_for_index(i: int) -> String:
	if i < 0 or i >= movies.size():
		return ""
	var raw = movies[i].get("backdrop", [])
	if not (raw is Array):
		return ""
	return "|".join(raw)

func _apply_backdrop_from_cache(key: String) -> void:
	var entry: Dictionary = _backdrop_cache.get(key, {})
	var textures: Array = entry.get("textures", [])
	var aspect: float = float(entry.get("aspect", 16.0 / 9.0))
	if textures.is_empty():
		_backdrop_textures.clear()
		_backdrop_material.set_shader_parameter("albedo_tex", _empty_texture)
		_backdrop_material.set_shader_parameter("albedo_tex_prev", _empty_texture)
		_backdrop_mesh.visible = false
		return
	_backdrop_textures.clear()
	for t in textures:
		_backdrop_textures.append(t)
	_backdrop_aspect = aspect
	_blend_factor = 1.0
	var now_msec: int = Time.get_ticks_msec()
	var total: int = _backdrop_textures.size()
	var state: Dictionary = _backdrop_states.get(_current_backdrop_item_id, {})
	var base_index: int = int(state.get("index", 0))
	var last_msec: int = int(state.get("last_rotate_msec", now_msec))
	var elapsed_sec: float = float(now_msec - last_msec) / 1000.0
	var steps: int = int(elapsed_sec / BACKDROP_ROTATE_SECONDS)
	_backdrop_index = (base_index + steps) % total
	var remainder_msec: int = int(
		(elapsed_sec - float(steps) * BACKDROP_ROTATE_SECONDS) * 1000.0
	)
	_backdrop_states[_current_backdrop_item_id] = {
		"index": _backdrop_index,
		"last_rotate_msec": now_msec - remainder_msec,
	}
	_backdrop_material.set_shader_parameter("albedo_tex", _backdrop_textures[_backdrop_index])
	_backdrop_material.set_shader_parameter("albedo_tex_prev", _backdrop_textures[_backdrop_index])
	_backdrop_material.set_shader_parameter("blend_factor", 1.0)
	_resize_backdrop()
	_backdrop_mesh.visible = true
	_backdrop_alpha = 0.0
	_backdrop_alpha_target = 1.0

func _load_backdrop_task(paths: Array, key: String) -> void:
	var images: Array = []
	var aspect: float = 16.0 / 9.0
	for p in paths:
		var pstr: String = str(p)
		if pstr.is_empty() or not FileAccess.file_exists(pstr):
			continue
		var img = Image.new()
		if img.load(pstr) != OK:
			continue
		var iw: int = img.get_width()
		var ih: int = img.get_height()
		if iw > 1280:
			var new_h: int = int(float(ih) * (1280.0 / float(iw)))
			img.resize(1280, new_h, Image.INTERPOLATE_LANCZOS)
		images.append(img)
		if images.size() == 1 and ih > 0:
			aspect = float(iw) / float(ih)
	call_deferred("_on_backdrop_loaded", images, aspect, key)

func _on_backdrop_loaded(images: Array, aspect: float, key: String) -> void:
	if _backdrop_mesh == null or _backdrop_material == null:
		return

	if images.is_empty():
		# 只有是当前该显示的才清屏
		if key == _last_backdrop_key:
			_backdrop_textures.clear()
			_backdrop_material.set_shader_parameter("albedo_tex", _empty_texture)
			_backdrop_material.set_shader_parameter("albedo_tex_prev", _empty_texture)
			_backdrop_mesh.visible = false
			_backdrop_alpha = 0.0
			_backdrop_alpha_target = 0.0
		return

	# 存缓存（不覆盖已存在）
	if not _backdrop_cache.has(key):
		var textures: Array = []
		for img in images:
			textures.append(ImageTexture.create_from_image(img))
		_backdrop_cache[key] = {"textures": textures, "aspect": aspect}
		# LRU 淘汰，不动当前显示的
		while _backdrop_cache.size() > BACKDROP_CACHE_MAX:
			var erased: bool = false
			for old_key in _backdrop_cache.keys():
				if str(old_key) == _last_backdrop_key:
					continue
				_backdrop_cache.erase(old_key)
				erased = true
				break
			if not erased:
				break

	# 只有是当前该显示的才应用到屏幕
	if key == _last_backdrop_key:
		_apply_backdrop_from_cache(key)

func _rebuild() -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	_base_ys.clear()
	_scale_targets.clear()
	_z_targets.clear()
	_scroll_offset = 0.0

	if movies.is_empty():
		return

	var step = CARD_HEIGHT + CARD_GAP
	var wall_x = _world_x_for_screen_ratio(WALL_SCREEN_X, WALL_Z)

	for i in range(movies.size()):
		var card = _make_card(movies[i])
		add_child(card)
		var base_y = -float(i) * step
		card.position = Vector3(wall_x, base_y, WALL_Z)
		_cards.append(card)
		_base_ys.append(base_y)
		_scale_targets.append(1.0)
		_z_targets.append(WALL_Z)

	_scroll_offset = float(selected_index) * step
	_refresh_selection()

func _make_card(movie: Dictionary) -> Node3D:
	var holder = Node3D.new()
	var quad = QuadMesh.new()

	# 先读封面，确定卡片宽度
	var cover = str(movie.get("cover", ""))
	var card_w: float = CARD_WIDTH_DEFAULT
	var loaded_img: Image = null
	if not cover.is_empty() and FileAccess.file_exists(cover):
		var img = Image.new()
		if img.load(cover) == OK:
			loaded_img = img
			var iw: int = img.get_width()
			var ih: int = img.get_height()
			if ih > 0:
				var aspect: float = float(iw) / float(ih)
				card_w = clampf(CARD_HEIGHT * aspect, CARD_WIDTH_MIN, CARD_WIDTH_MAX)

	quad.size = Vector2(card_w, CARD_HEIGHT)
	holder.set_meta("card_width", card_w)

	var mesh = MeshInstance3D.new()
	mesh.mesh = quad
	holder.add_child(mesh)

	var mat = ShaderMaterial.new()
	mat.shader = CARD_SHADER
	mat.set_shader_parameter("brightness", 1.0)

	var offline: bool = bool(movie.get("offline", false))
	mat.set_shader_parameter(
		"saturation", CARD_OFFLINE_SATURATION if offline else 1.0
	)

	if loaded_img != null:
		loaded_img.generate_mipmaps()
		mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(loaded_img))
		mat.set_shader_parameter("use_tex", 1.0)
	else:
		var base_color = _fallback_color(str(movie.get("title", "")))
		mat.set_shader_parameter("tint", base_color)
		mat.set_shader_parameter("use_tex", 0.0)

	mesh.material_override = mat
	holder.set_meta("offline", offline)
	return holder

func reload_covers() -> void:
	for i in range(_cards.size()):
		if i >= movies.size():
			continue
		var card = _cards[i]
		var movie = movies[i]
		var cover = str(movie.get("cover", ""))
		var offline: bool = bool(movie.get("offline", false))
		var mesh = _first_mesh(card)
		if mesh == null:
			continue
		var mat = mesh.material_override as ShaderMaterial
		if mat == null:
			continue
		var loaded: bool = false
		var card_w: float = CARD_WIDTH_DEFAULT
		if not cover.is_empty() and FileAccess.file_exists(cover):
			var img = Image.new()
			if img.load(cover) == OK:
				img.generate_mipmaps()
				mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
				mat.set_shader_parameter("use_tex", 1.0)
				loaded = true
				var iw: int = img.get_width()
				var ih: int = img.get_height()
				if ih > 0:
					var aspect: float = float(iw) / float(ih)
					card_w = clampf(CARD_HEIGHT * aspect, CARD_WIDTH_MIN, CARD_WIDTH_MAX)
		if not loaded:
			var base_color = _fallback_color(str(movie.get("title", "")))
			mat.set_shader_parameter("tint", base_color)
			mat.set_shader_parameter("use_tex", 0.0)
		# 更新卡片宽度
		var quad = mesh.mesh as QuadMesh
		if quad != null:
			quad.size = Vector2(card_w, CARD_HEIGHT)
		card.set_meta("card_width", card_w)
		mat.set_shader_parameter(
			"saturation", CARD_OFFLINE_SATURATION if offline else 1.0
		)
		card.set_meta("offline", offline)
	_refresh_selection()

func force_refresh_backdrop() -> void:
	# 完全重置背景图系统（清缓存 + 清 inflight 状态 + 清纹理）
	_backdrop_cache.clear()
	_last_backdrop_key = ""
	if not _current_backdrop_item_id.is_empty():
		_backdrop_states.erase(_current_backdrop_item_id)
	_refresh_backdrop(true)

func _fallback_color(seed_text: String) -> Color:
	var h = float(absi(seed_text.hash() % 10000)) / 10000.0
	return Color.from_hsv(h, 0.35, 0.45)

func _world_x_for_screen_ratio(ratio: float, z_value: float) -> float:
	if camera == null:
		return 0.0
	var vp = get_viewport().get_visible_rect().size
	if vp.y <= 0:
		return 0.0
	var dist = absf(camera.global_position.z - z_value)
	var half_h = tan(deg_to_rad(camera.fov * 0.5)) * dist
	var half_w = half_h * (vp.x / vp.y)
	return camera.global_position.x + (ratio - 0.5) * 2.0 * half_w

func _refresh_selection() -> void:
	for i in range(_cards.size()):
		var card = _cards[i]
		var selected = (i == selected_index)
		var b = (1.0 if selected else UNSELECTED_BRIGHTNESS) * _card_brightness_scale
		_scale_targets[i] = SELECTED_BOOST if selected else 1.0
		_z_targets[i] = SELECTED_Z if selected else WALL_Z
		var mesh = _first_mesh(card)
		if mesh != null and mesh.material_override is ShaderMaterial:
			var mat = mesh.material_override as ShaderMaterial
			mat.set_shader_parameter("brightness", b)

func _first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null

func _hit_test_card(screen_pos: Vector2) -> int:
	if camera == null or _cards.is_empty():
		return -1
	for i in range(_cards.size()):
		var card = _cards[i]
		var center: Vector3 = card.global_position
		if camera.is_position_behind(center):
			continue
		var w: float = float(card.get_meta("card_width", CARD_WIDTH_DEFAULT))
		var half_w: float = w * 0.5 * card.scale.x
		var half_h: float = CARD_HEIGHT * 0.5 * card.scale.y
		var tl: Vector2 = camera.unproject_position(center + Vector3(-half_w, half_h, 0.0))
		var br: Vector2 = camera.unproject_position(center + Vector3(half_w, -half_h, 0.0))
		var rect: Rect2 = Rect2(tl, br - tl)
		if rect.has_point(screen_pos):
			return i
	return -1

func _update_hover() -> void:
	if camera == null or _cards.is_empty():
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# 卡片列在屏幕 18% 处，最宽不超过 45% —— 鼠标在 45% 之外不可能碰到卡片
	if vp.x > 0.0 and mouse.x > vp.x * 0.45:
		_hover_index = -1
		_hover_offset = Vector2.ZERO
		return
	var found: int = -1
	var found_offset: Vector2 = Vector2.ZERO
	for i in range(_cards.size()):
		var card = _cards[i]
		var center: Vector3 = card.global_position
		if camera.is_position_behind(center):
			continue
		var w: float = float(card.get_meta("card_width", CARD_WIDTH_DEFAULT))
		var half_w: float = w * 0.5 * card.scale.x
		var half_h: float = CARD_HEIGHT * 0.5 * card.scale.y
		var tl: Vector2 = camera.unproject_position(center + Vector3(-half_w, half_h, 0.0))
		var br: Vector2 = camera.unproject_position(center + Vector3(half_w, -half_h, 0.0))
		var rect: Rect2 = Rect2(tl, br - tl)
		if rect.has_point(mouse):
			found = i
			var rect_center: Vector2 = (tl + br) * 0.5
			var half_size: Vector2 = (br - tl) * 0.5
			found_offset = Vector2(
				clampf((mouse.x - rect_center.x) / maxf(half_size.x, 1.0), -1.0, 1.0),
				clampf((mouse.y - rect_center.y) / maxf(half_size.y, 1.0), -1.0, 1.0)
			)
			break
	_hover_index = found
	_hover_offset = found_offset

func _process(delta: float) -> void:
	if not visible or movies.is_empty():
		return
	if _pending_backdrop_refresh:
		var now_msec: int = Time.get_ticks_msec()
		if now_msec - _last_scroll_msec >= SCROLL_SETTLE_MSEC:
			_pending_backdrop_refresh = false
			_do_refresh_backdrop()
	if _backdrop_mesh != null and _backdrop_mesh.visible and _backdrop_material != null:
		if _backdrop_textures.size() > 1:
			var now_msec: int = Time.get_ticks_msec()
			var state: Dictionary = _backdrop_states.get(_current_backdrop_item_id, {})
			var last_msec: int = int(state.get("last_rotate_msec", now_msec))
			var elapsed_sec: float = float(now_msec - last_msec) / 1000.0
			if elapsed_sec >= BACKDROP_ROTATE_SECONDS:
				var prev_index: int = _backdrop_index
				_backdrop_index = (_backdrop_index + 1) % _backdrop_textures.size()
				_backdrop_material.set_shader_parameter(
					"albedo_tex_prev", _backdrop_textures[prev_index]
				)
				_backdrop_material.set_shader_parameter(
					"albedo_tex", _backdrop_textures[_backdrop_index]
				)
				_blend_factor = 0.0
				_backdrop_states[_current_backdrop_item_id] = {
					"index": _backdrop_index,
					"last_rotate_msec": now_msec,
				}
		if _blend_factor < 1.0:
			_blend_factor = minf(1.0, _blend_factor + delta / BACKDROP_CROSSFADE_SECONDS)
			_backdrop_material.set_shader_parameter("blend_factor", _blend_factor)
		_backdrop_alpha = lerpf(
			_backdrop_alpha, _backdrop_alpha_target, 1.0 - exp(-delta * BACKDROP_FADE_SPEED)
		)
		_backdrop_material.set_shader_parameter("backdrop_alpha", _backdrop_alpha)
	_update_hover()
	var step = CARD_HEIGHT + CARD_GAP
	var target_offset = float(selected_index) * step
	var scroll_follow = 1.0 - exp(-delta * SCROLL_FOLLOW)
	_scroll_offset = lerpf(_scroll_offset, target_offset, scroll_follow)
	var scale_follow = 1.0 - exp(-delta * 10.0)
	var z_follow = 1.0 - exp(-delta * 12.0)
	var rot_follow: float = 1.0 - exp(-delta * 14.0)
	for i in range(_cards.size()):
		var card = _cards[i]
		var target_y = _base_ys[i] + _scroll_offset
		var cur_z: float = lerpf(card.position.z, _z_targets[i], z_follow)
		var target_x: float = _world_x_for_screen_ratio(WALL_SCREEN_X, cur_z)
		card.position = Vector3(
			target_x,
			lerpf(card.position.y, target_y, scroll_follow),
			cur_z
		)
		var ts = _scale_targets[i]
		card.scale = card.scale.lerp(Vector3.ONE * ts, scale_follow)

		var target_yaw: float = 0.0
		var target_pitch: float = 0.0
		if i == _hover_index:
			target_yaw = _hover_offset.x * HOVER_YAW_DEGREES
			target_pitch = _hover_offset.y * HOVER_PITCH_DEGREES
		var cur_rot = card.rotation_degrees
		card.rotation_degrees = Vector3(
			lerpf(cur_rot.x, target_pitch, rot_follow),
			lerpf(cur_rot.y, target_yaw, rot_follow),
			0.0
		)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or movies.is_empty():
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			var idx: int = _hit_test_card(mb.position)
			if idx >= 0:
				if idx != selected_index:
					selected_index = idx
					_refresh_selection()
					_refresh_backdrop(true)
					selection_changed.emit(selected_index, movies[selected_index])
				main_case_right_clicked.emit(movies[selected_index], mb.position)
				get_viewport().set_input_as_handled()
				return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var lidx: int = _hit_test_card(mb.position)
			if lidx >= 0:
				if lidx != selected_index:
					selected_index = lidx
					_refresh_selection()
					_refresh_backdrop(true)
					selection_changed.emit(selected_index, movies[selected_index])
					get_viewport().set_input_as_handled()
					return
				if mb.double_click:
					main_case_double_clicked.emit(movies[selected_index])
					get_viewport().set_input_as_handled()
					return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _wheel_blocked:
				return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _wheel_allowed():
				_step_selection(1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _wheel_allowed():
				_step_selection(-1)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var ke = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_DOWN:
				_step_selection(1)
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_UP:
				_step_selection(-1)
				get_viewport().set_input_as_handled()

func _wheel_allowed() -> bool:
	var now = Time.get_ticks_msec()
	if now - _last_wheel_msec < WHEEL_DEBOUNCE_MSEC:
		return false
	_last_wheel_msec = now
	return true

func _step_selection(delta: int) -> void:
	var ni = clampi(selected_index + delta, 0, movies.size() - 1)
	if ni == selected_index:
		return
	selected_index = ni
	_last_scroll_msec = Time.get_ticks_msec()
	_refresh_selection()
	var target_key: String = _compute_backdrop_key_for_index(ni)
	if not target_key.is_empty() and _backdrop_cache.has(target_key):
		_refresh_backdrop(true)
	else:
		_refresh_backdrop()
	selection_changed.emit(selected_index, movies[selected_index])

func _on_viewport_changed() -> void:
	_resize_ambient()
	_resize_backdrop()
	if movies.is_empty():
		return
	for i in range(_cards.size()):
		var cur_z: float = _cards[i].position.z
		_cards[i].position.x = _world_x_for_screen_ratio(WALL_SCREEN_X, cur_z)

func get_backdrop_top_left_screen() -> Vector2:
	if _backdrop_mesh == null or camera == null or not _backdrop_mesh.is_inside_tree():
		return Vector2(-9999.0, -9999.0)
	var quad: QuadMesh = _backdrop_mesh.mesh as QuadMesh
	if quad == null:
		return Vector2(-9999.0, -9999.0)
	var half_w: float = quad.size.x * 0.5
	var half_h: float = quad.size.y * 0.5
	var pos: Vector3 = _backdrop_mesh.global_position
	pos.y = camera.global_position.y
	return camera.unproject_position(pos + Vector3(-half_w, half_h, 0.0))

func get_backdrop_bottom_screen() -> float:
	if _backdrop_mesh == null or camera == null or not _backdrop_mesh.visible:
		return -9999.0
	var quad: QuadMesh = _backdrop_mesh.mesh as QuadMesh
	if quad == null:
		return -9999.0
	var half_h: float = quad.size.y * 0.5
	var pos: Vector3 = _backdrop_mesh.global_position
	pos.y = camera.global_position.y
	return camera.unproject_position(pos + Vector3(0.0, -half_h, 0.0)).y

func get_backdrop_right_screen() -> float:
	if _backdrop_mesh == null or camera == null or not _backdrop_mesh.visible:
		return -9999.0
	var quad: QuadMesh = _backdrop_mesh.mesh as QuadMesh
	if quad == null:
		return -9999.0
	var half_w: float = quad.size.x * 0.5
	var pos: Vector3 = _backdrop_mesh.global_position
	return camera.unproject_position(pos + Vector3(half_w, 0.0, 0.0)).x

func get_selected_card_screen_rect() -> Rect2:
	if camera == null or _cards.is_empty():
		return Rect2()
	if selected_index < 0 or selected_index >= _cards.size():
		return Rect2()
	var card: Node3D = _cards[selected_index]
	var center: Vector3 = card.global_position
	if camera.is_position_behind(center):
		return Rect2()
	var w: float = float(card.get_meta("card_width", CARD_WIDTH_DEFAULT))
	var half_w: float = w * 0.5 * card.scale.x
	var half_h: float = CARD_HEIGHT * 0.5 * card.scale.y
	var tl: Vector2 = camera.unproject_position(center + Vector3(-half_w, half_h, 0.0))
	var br: Vector2 = camera.unproject_position(center + Vector3(half_w, -half_h, 0.0))
	return Rect2(tl, br - tl)

func jump_to_index(index: int) -> void:
	if movies.is_empty():
		return
	var target: int = clampi(index, 0, movies.size() - 1)
	selected_index = target
	_scroll_offset = float(target) * (CARD_HEIGHT + CARD_GAP)
	_refresh_selection()
	_refresh_backdrop(true)
	selection_changed.emit(selected_index, movies[selected_index])

func set_wheel_blocked(value: bool) -> void:
	_wheel_blocked = value

func set_ui_offset_y(y: float) -> void:
	if is_equal_approx(_ui_offset_y, y):
		return
	_ui_offset_y = y
	_apply_backdrop_offset()

func _apply_backdrop_offset() -> void:
	if _backdrop_material == null or _backdrop_mesh == null or camera == null:
		return
	var vp = get_viewport().get_visible_rect().size
	if vp.y <= 0:
		return
	var dist = absf(camera.global_position.z - _backdrop_mesh.global_position.z)
	var half_h = tan(deg_to_rad(camera.fov * 0.5)) * dist
	var full_h = half_h * 2.0
	var px_to_world = full_h / vp.y
	_backdrop_material.set_shader_parameter(
		"cull_offset_y", -_ui_offset_y * px_to_world
	)

func _exit_tree() -> void:
	pass