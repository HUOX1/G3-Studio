extends Node3D
class_name G3SpatialGallery

# G3 Spatial Lab A1: asymmetric gravity composition and deliberate focus interaction.

signal game_double_clicked(game: Dictionary)

const BACKGROUND_SHADER: Shader = preload("res://shaders/spatial_gallery_bg.gdshader")
const COVER_SHADER: Shader = preload("res://shaders/spatial_cover.gdshader")
const FLOOR_SHADER: Shader = preload("res://shaders/spatial_gallery_floor.gdshader")
const MAX_CARDS: int = 9
const CARD_CENTER_SIZE: Vector2 = Vector2(2.32, 3.48)
const CARD_FRAME_SIZE: Vector3 = Vector3(2.48, 3.66, 0.13)
const CARD_HIT_SIZE: Vector3 = Vector3(2.56, 3.76, 0.24)
const MOVE_SPEED: float = 5.6

static var _cover_texture_cache: Dictionary = {}

var _camera: Camera3D
var _games: Array[Dictionary] = []
var _cards: Array[Dictionary] = []
var _selected_index: int = 0
var _visible_count: int = 0
var _center_slot: int = 4
var _hover_slot: int = -1
var _initialized: bool = false
var _load_generation: int = 0
var _background_mesh: MeshInstance3D
var _background_material: ShaderMaterial
var _floor_mesh: MeshInstance3D
var _environment_ribbons: Array[MeshInstance3D] = []
var _focus_pulse_elapsed: float = -1.0
var _ui_layer: CanvasLayer
var _ui_root: Control
var _eyebrow_label: Label
var _title_label: Label
var _meta_label: Label
var _count_label: Label
var _hint_label: Label

func configure(camera: Camera3D) -> void:
	_camera = camera
	_build_background()
	_build_floor()
	_build_environment_ribbons()
	_build_cards()
	_build_ui()
	get_viewport().size_changed.connect(_resize_background)
	set_section_visible(false)

func set_section_visible(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	set_process_unhandled_input(enabled)
	if _ui_layer != null:
		_ui_layer.visible = enabled
	if enabled and not _initialized:
		_initialize_cards()
	if enabled:
		_resize_background()
		_refresh_info()

func set_games(items: Array[Dictionary]) -> void:
	_games = items.duplicate()
	_selected_index = clampi(_selected_index, 0, maxi(_games.size() - 1, 0))
	_initialized = false
	if visible:
		_initialize_cards()

func _build_background() -> void:
	_background_mesh = MeshInstance3D.new()
	_background_mesh.name = "SpatialGalleryAtmosphere"
	_background_mesh.position = Vector3(0.0, 0.0, -5.8)
	var quad := QuadMesh.new()
	_background_mesh.mesh = quad
	_background_material = ShaderMaterial.new()
	_background_material.shader = BACKGROUND_SHADER
	_background_mesh.material_override = _background_material
	_background_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_background_mesh)
	_resize_background()

func _resize_background() -> void:
	if _background_mesh == null or _camera == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var distance: float = absf(_camera.global_position.z - _background_mesh.global_position.z)
	var half_height: float = tan(deg_to_rad(_camera.fov * 0.5)) * distance
	var aspect: float = viewport_size.x / viewport_size.y
	var quad := _background_mesh.mesh as QuadMesh
	quad.size = Vector2(half_height * 2.0 * aspect * 1.08, half_height * 2.0 * 1.08)

func _build_floor() -> void:
	_floor_mesh = MeshInstance3D.new()
	_floor_mesh.name = "SpatialGalleryFloor_A1"
	var plane := PlaneMesh.new()
	plane.size = Vector2(38.0, 28.0)
	_floor_mesh.mesh = plane
	# Lower the horizon and let the floor continue into depth; A0's pitch-black slab is removed.
	_floor_mesh.position = Vector3(0.0, -3.0, -2.0)
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	_floor_mesh.material_override = material
	_floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor_mesh)

func _build_environment_ribbons() -> void:
	# Thin elliptical arcs sit behind the cases. They imply architecture and scale,
	# but stay dim enough that the artwork remains the emotional focal point.
	_add_environment_arc(8.1, 2.65, -2.72, 0.72, Vector3(0.25, 0.18, -3.55), Color(0.025, 0.105, 0.135, 1.0), 0.42)
	_add_environment_arc(7.0, 2.20, 0.34, 3.72, Vector3(-0.15, -0.08, -3.30), Color(0.020, 0.072, 0.102, 1.0), 0.30)
	_add_environment_arc(9.0, 3.15, 3.82, 5.60, Vector3(0.40, 0.05, -3.90), Color(0.040, 0.085, 0.095, 1.0), 0.20)

func _add_environment_arc(radius_x: float, radius_y: float, start_angle: float, end_angle: float, arc_position: Vector3, color: Color, energy: float) -> void:
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = 96
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, t)
		line_mesh.surface_add_vertex(Vector3(cos(angle) * radius_x, sin(angle) * radius_y, 0.0))
	line_mesh.surface_end()
	var ribbon := MeshInstance3D.new()
	ribbon.name = "SpatialArchitectureArc"
	ribbon.mesh = line_mesh
	ribbon.position = arc_position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, energy)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	_environment_ribbons.append(ribbon)

func _build_cards() -> void:
	for slot in range(MAX_CARDS):
		var holder := Node3D.new()
		holder.name = "SpatialCard_%02d" % slot
		holder.set_meta("slot", slot)
		holder.set_meta("offset", slot - 4)
		holder.set_meta("game_index", -1)
		holder.set_meta("cover_path", "")

		var frame_mesh := MeshInstance3D.new()
		frame_mesh.name = "CardBody"
		var frame := BoxMesh.new()
		frame.size = CARD_FRAME_SIZE
		frame_mesh.mesh = frame
		var frame_material := StandardMaterial3D.new()
		frame_material.albedo_color = Color(0.025, 0.045, 0.072, 1.0)
		frame_material.metallic = 0.24
		frame_material.roughness = 0.34
		frame_material.emission_enabled = true
		frame_material.emission = Color(0.018, 0.052, 0.082, 1.0)
		frame_material.emission_energy_multiplier = 0.30
		frame_mesh.material_override = frame_material
		frame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		holder.add_child(frame_mesh)

		var cover_mesh := MeshInstance3D.new()
		cover_mesh.name = "CoverSurface"
		var cover_quad := QuadMesh.new()
		cover_quad.size = CARD_CENTER_SIZE
		cover_mesh.mesh = cover_quad
		cover_mesh.position = Vector3(0.0, 0.0, CARD_FRAME_SIZE.z * 0.5 + 0.003)
		var cover_material := ShaderMaterial.new()
		cover_material.shader = COVER_SHADER
		cover_material.set_shader_parameter("use_texture", false)
		cover_material.set_shader_parameter("fallback_color", Color(0.08, 0.16, 0.24, 1.0))
		cover_material.set_shader_parameter("sheen_strength", 0.035)
		cover_mesh.material_override = cover_material
		cover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(cover_mesh)

		var area := Area3D.new()
		area.name = "CardHitArea"
		area.input_ray_pickable = true
		area.collision_layer = 1
		area.collision_mask = 0
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = CARD_HIT_SIZE
		shape_node.shape = shape
		area.add_child(shape_node)
		area.input_event.connect(_on_card_input_event.bind(slot))
		area.mouse_entered.connect(_on_card_mouse_entered.bind(slot))
		area.mouse_exited.connect(_on_card_mouse_exited.bind(slot))
		holder.add_child(area)

		add_child(holder)
		_cards.append({
			"holder": holder,
			"frame_material": frame_material,
			"cover_material": cover_material,
			"area": area,
		})

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "SpatialGalleryOverlay"
	_ui_layer.layer = 4
	add_child(_ui_layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_ui_root)

	_eyebrow_label = Label.new()
	_eyebrow_label.position = Vector2(54.0, 74.0)
	_eyebrow_label.size = Vector2(420.0, 20.0)
	_eyebrow_label.text = "G3  /  SPATIAL COLLECTION"
	_eyebrow_label.add_theme_font_size_override("font_size", 11)
	_eyebrow_label.add_theme_color_override("font_color", Color(0.39, 0.72, 0.90, 0.94))
	_eyebrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_eyebrow_label)

	var section_title := Label.new()
	section_title.position = Vector2(52.0, 95.0)
	section_title.size = Vector2(440.0, 42.0)
	section_title.text = "私人游戏展厅"
	section_title.add_theme_font_size_override("font_size", 24)
	section_title.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98, 0.96))
	section_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(section_title)

	var accent_line := ColorRect.new()
	accent_line.position = Vector2(54.0, 145.0)
	accent_line.size = Vector2(42.0, 2.0)
	accent_line.color = Color(0.30, 0.72, 0.94, 0.88)
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(accent_line)

	_title_label = Label.new()
	_title_label.anchor_left = 0.0
	_title_label.anchor_right = 0.0
	_title_label.anchor_top = 1.0
	_title_label.anchor_bottom = 1.0
	_title_label.offset_left = 56.0
	_title_label.offset_right = 405.0
	_title_label.offset_top = -106.0
	_title_label.offset_bottom = -66.0
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_title_label)

	_meta_label = Label.new()
	_meta_label.anchor_left = 0.0
	_meta_label.anchor_right = 0.0
	_meta_label.anchor_top = 1.0
	_meta_label.anchor_bottom = 1.0
	_meta_label.offset_left = 58.0
	_meta_label.offset_right = 455.0
	_meta_label.offset_top = -62.0
	_meta_label.offset_bottom = -38.0
	_meta_label.add_theme_font_size_override("font_size", 14)
	_meta_label.add_theme_color_override("font_color", Color(0.56, 0.69, 0.80, 1.0))
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_meta_label)

	_count_label = Label.new()
	_count_label.anchor_left = 1.0
	_count_label.anchor_right = 1.0
	_count_label.anchor_top = 0.0
	_count_label.anchor_bottom = 0.0
	_count_label.offset_left = -260.0
	_count_label.offset_right = -56.0
	_count_label.offset_top = 74.0
	_count_label.offset_bottom = 102.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", 13)
	_count_label.add_theme_color_override("font_color", Color(0.45, 0.62, 0.75, 0.92))
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_count_label)

	_hint_label = Label.new()
	_hint_label.anchor_left = 1.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = -470.0
	_hint_label.offset_right = -56.0
	_hint_label.offset_top = -54.0
	_hint_label.offset_bottom = -28.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.40, 0.55, 0.67, 0.92))
	_hint_label.text = "滚轮浏览    ·    单击聚焦    ·    Enter 启动"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_hint_label)

func _initialize_cards() -> void:
	if _games.is_empty():
		_initialized = true
		_visible_count = 0
		for entry in _cards:
			(entry["holder"] as Node3D).visible = false
		_title_label.text = "收藏正在等待你"
		_meta_label.text = "游戏库还没有可展示的项目"
		_count_label.text = "0 / 0"
		return

	_visible_count = mini(MAX_CARDS, _games.size())
	_center_slot = int(floor(float(_visible_count) * 0.5))
	_load_generation += 1
	_hover_slot = -1
	for slot in range(_cards.size()):
		var holder: Node3D = _cards[slot]["holder"]
		if slot >= _visible_count:
			holder.visible = false
			continue
		holder.visible = true
		var offset: int = slot - _center_slot
		holder.set_meta("offset", offset)
		holder.position = _position_for_offset(offset)
		holder.rotation = _rotation_for_offset(offset)
		holder.scale = Vector3.ONE * _scale_for_offset(offset)
		var game_index: int = wrapi(_selected_index + offset, 0, _games.size())
		_set_card_game(slot, game_index)
	_refresh_card_styles()
	_refresh_info()
	_initialized = true

func _set_card_game(slot: int, game_index: int) -> void:
	if slot < 0 or slot >= _cards.size() or game_index < 0 or game_index >= _games.size():
		return
	var entry: Dictionary = _cards[slot]
	var holder: Node3D = entry["holder"]
	var game: Dictionary = _games[game_index]
	var cover_path: String = str(game.get("cover", "")).replace("\\", "/")
	holder.set_meta("game_index", game_index)
	holder.set_meta("cover_path", cover_path)
	var material: ShaderMaterial = entry["cover_material"]
	material.set_shader_parameter("use_texture", false)
	material.set_shader_parameter("fallback_color", _fallback_color(str(game.get("title", ""))))
	material.set_shader_parameter("sheen_strength", 0.035)
	if cover_path.is_empty() or not FileAccess.file_exists(cover_path):
		return
	if _cover_texture_cache.has(cover_path):
		material.set_shader_parameter("cover_texture", _cover_texture_cache[cover_path])
		material.set_shader_parameter("use_texture", true)
		return
	var generation: int = int(holder.get_meta("load_generation", 0)) + 1
	holder.set_meta("load_generation", generation)
	WorkerThreadPool.add_task(_load_cover_task.bind(slot, cover_path, generation))

func _load_cover_task(slot: int, path: String, generation: int) -> void:
	var image := Image.new()
	var error: Error = image.load(path)
	if error == OK:
		call_deferred("_apply_cover_image", slot, path, generation, image)

func _apply_cover_image(slot: int, path: String, generation: int, image: Image) -> void:
	if slot < 0 or slot >= _cards.size() or not is_instance_valid(_cards[slot]["holder"]):
		return
	var holder: Node3D = _cards[slot]["holder"]
	if int(holder.get_meta("load_generation", -1)) != generation:
		return
	if str(holder.get_meta("cover_path", "")) != path:
		return
	if image == null or image.is_empty():
		return
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cover_texture_cache[path] = texture
	var material: ShaderMaterial = _cards[slot]["cover_material"]
	material.set_shader_parameter("cover_texture", texture)
	material.set_shader_parameter("use_texture", true)

func _position_for_offset(offset: int) -> Vector3:
	var distance: int = absi(offset)
	# The hero is deliberately left of center. The two wings use different spacing,
	# heights and depth so the composition feels poised to move rather than evenly tiled.
	var left_x: Array[float] = [0.0, 2.35, 3.88, 5.05, 5.82]
	var right_x: Array[float] = [0.0, 1.68, 2.78, 3.66, 4.38]
	var x_value: float = -1.22
	if offset < 0:
		x_value -= left_x[mini(distance, left_x.size() - 1)]
	elif offset > 0:
		x_value += right_x[mini(distance, right_x.size() - 1)]
	var left_y: Array[float] = [0.06, 0.02, -0.36, 0.48, -0.58]
	var right_y: Array[float] = [0.06, 0.24, -0.42, 0.54, -0.30]
	var y_value: float = left_y[mini(distance, left_y.size() - 1)] if offset <= 0 else right_y[mini(distance, right_y.size() - 1)]
	var z_value: float = 0.52
	if distance > 0:
		z_value -= float(distance) * (0.48 if offset < 0 else 0.61)
	return Vector3(x_value, y_value, z_value)

func _rotation_for_offset(offset: int) -> Vector3:
	var yaw: float = clampf(-float(offset) * 11.0, -42.0, 42.0)
	var roll: float = clampf(-float(offset) * 1.55, -7.0, 7.0)
	var pitch: float = clampf(float(offset) * 1.8, -7.0, 7.0)
	return Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll))

func _scale_for_offset(offset: int) -> float:
	var distance: int = absi(offset)
	if distance == 0:
		return 1.88
	var scales: Array[float] = [1.88, 0.99, 0.80, 0.65, 0.52]
	return scales[mini(distance, scales.size() - 1)]

func _process(delta: float) -> void:
	if not _initialized or _games.is_empty():
		return
	var blend: float = 1.0 - exp(-delta * MOVE_SPEED)
	if _focus_pulse_elapsed >= 0.0:
		_focus_pulse_elapsed += delta * 2.8
		if _focus_pulse_elapsed >= 1.0:
			_focus_pulse_elapsed = -1.0
	var focus_pulse: float = sin(clampf(_focus_pulse_elapsed, 0.0, 1.0) * PI) if _focus_pulse_elapsed >= 0.0 else 0.0
	for slot in range(_visible_count):
		var entry: Dictionary = _cards[slot]
		var holder: Node3D = entry["holder"]
		if not holder.visible:
			continue
		var offset: int = int(holder.get_meta("offset", 0))
		var target_position: Vector3 = _position_for_offset(offset)
		var target_rotation: Vector3 = _rotation_for_offset(offset)
		var target_scale: float = _scale_for_offset(offset)
		if offset == 0:
			target_position.z += focus_pulse * 0.24
			target_scale *= 1.0 + focus_pulse * 0.075
		if slot == _hover_slot:
			target_position.y += 0.10
			target_position.z += 0.12
			target_scale *= 1.025
			target_rotation.x -= deg_to_rad(0.8)
		holder.position = holder.position.lerp(target_position, blend)
		holder.rotation.x = lerp_angle(holder.rotation.x, target_rotation.x, blend)
		holder.rotation.y = lerp_angle(holder.rotation.y, target_rotation.y, blend)
		holder.rotation.z = lerp_angle(holder.rotation.z, target_rotation.z, blend)
		holder.scale = holder.scale.lerp(Vector3.ONE * target_scale, blend)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _games.size() <= 1:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_shift_selection(1)
			get_viewport().set_input_as_handled()
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_shift_selection(-1)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_RIGHT:
			_shift_selection(1)
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_LEFT:
			_shift_selection(-1)
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if _selected_index >= 0 and _selected_index < _games.size():
				game_double_clicked.emit(_games[_selected_index])
			get_viewport().set_input_as_handled()

func _on_card_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, slot: int) -> void:
	if not visible or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Godot reports a double-click as a second mouse-down event. Ignore that second
	# event so a double-click cannot accidentally select the next card or launch a game.
	if mouse_event.double_click:
		get_viewport().set_input_as_handled()
		return
	if slot < 0 or slot >= _cards.size():
		return
	var game_index: int = int((_cards[slot]["holder"] as Node3D).get_meta("game_index", -1))
	if game_index < 0 or game_index >= _games.size():
		return
	if game_index == _selected_index:
		# Clicking the current hero gives visible confirmation; launching is explicit via Enter.
		_focus_pulse_elapsed = 0.0
		_refresh_card_styles()
	else:
		_select_game(game_index)
	get_viewport().set_input_as_handled()

func _on_card_mouse_entered(slot: int) -> void:
	_hover_slot = slot
	_refresh_card_styles()

func _on_card_mouse_exited(slot: int) -> void:
	if _hover_slot == slot:
		_hover_slot = -1
	_refresh_card_styles()

func _select_game(target_index: int) -> void:
	if _games.is_empty():
		return
	var target: int = wrapi(target_index, 0, _games.size())
	if target == _selected_index:
		return
	var forward_steps: int = wrapi(target - _selected_index, 0, _games.size())
	var backward_steps: int = forward_steps - _games.size()
	var steps: int = forward_steps if absi(forward_steps) <= absi(backward_steps) else backward_steps
	if absi(steps) <= 3:
		var direction: int = 1 if steps > 0 else -1
		for _i in range(absi(steps)):
			_shift_selection(direction)
	else:
		_selected_index = target
		_initialize_cards()
	_refresh_info()

func _shift_selection(direction: int) -> void:
	if _games.size() <= 1 or _visible_count <= 1:
		return
	_selected_index = wrapi(_selected_index + direction, 0, _games.size())
	var min_offset: int = -_center_slot
	var max_offset: int = _visible_count - 1 - _center_slot
	var recycle_slot: int = -1
	for slot in range(_visible_count):
		var offset: int = int((_cards[slot]["holder"] as Node3D).get_meta("offset", 0))
		if direction > 0 and offset == min_offset:
			recycle_slot = slot
		elif direction < 0 and offset == max_offset:
			recycle_slot = slot
	if recycle_slot < 0:
		_initialize_cards()
		return

	var recycled_holder: Node3D = _cards[recycle_slot]["holder"]
	var new_offset: int = max_offset if direction > 0 else min_offset
	var outside_offset: int = max_offset + 1 if direction > 0 else min_offset - 1
	recycled_holder.position = _position_for_offset(outside_offset)
	recycled_holder.rotation = _rotation_for_offset(outside_offset)
	recycled_holder.scale = Vector3.ONE * _scale_for_offset(outside_offset)
	for slot in range(_visible_count):
		if slot == recycle_slot:
			continue
		var holder: Node3D = _cards[slot]["holder"]
		holder.set_meta("offset", int(holder.get_meta("offset", 0)) - direction)
	recycled_holder.set_meta("offset", new_offset)
	var new_game_index: int = wrapi(_selected_index + new_offset, 0, _games.size())
	_set_card_game(recycle_slot, new_game_index)
	_refresh_card_styles()
	_refresh_info()

func _refresh_card_styles() -> void:
	for slot in range(_cards.size()):
		var entry: Dictionary = _cards[slot]
		var holder: Node3D = entry["holder"]
		var frame_material: StandardMaterial3D = entry["frame_material"]
		var offset: int = int(holder.get_meta("offset", 0))
		if offset == 0:
			frame_material.albedo_color = Color(0.038, 0.072, 0.092, 1.0)
			frame_material.emission = Color(0.018, 0.070, 0.092, 1.0)
			frame_material.emission_energy_multiplier = 0.40
			(entry["cover_material"] as ShaderMaterial).set_shader_parameter("sheen_strength", 0.065 if slot == _hover_slot else 0.052)
		else:
			frame_material.albedo_color = Color(0.018, 0.032, 0.052, 1.0)
			frame_material.emission = Color(0.010, 0.025, 0.040, 1.0)
			frame_material.emission_energy_multiplier = 0.22
			(entry["cover_material"] as ShaderMaterial).set_shader_parameter("sheen_strength", 0.025 if slot == _hover_slot else 0.018)

func _refresh_info() -> void:
	if not is_instance_valid(_title_label):
		return
	if _games.is_empty():
		_title_label.text = "收藏正在等待你"
		_meta_label.text = "游戏库还没有可展示的项目"
		_count_label.text = "0 / 0"
		return
	_selected_index = clampi(_selected_index, 0, _games.size() - 1)
	var game: Dictionary = _games[_selected_index]
	_title_label.text = str(game.get("title", "未命名游戏"))
	var platform: String = str(game.get("platform", "")).strip_edges()
	var source: String = str(game.get("source", "")).strip_edges()
	var playtime: int = int(game.get("playtime_seconds", 0))
	var parts: PackedStringArray = []
	if not platform.is_empty():
		parts.append(platform)
	if not source.is_empty() and source.to_lower() != "manual":
		parts.append(source.to_upper())
	if playtime > 0:
		parts.append("已游玩 %.1f 小时" % (float(playtime) / 3600.0))
	if parts.is_empty():
		parts.append("私人收藏")
	_meta_label.text = "  ·  ".join(parts)
	_count_label.text = "%02d  /  %02d" % [_selected_index + 1, _games.size()]

func _fallback_color(title: String) -> Color:
	var hue: float = float(abs(hash(title)) % 360) / 360.0
	return Color.from_hsv(hue, 0.36, 0.30, 1.0)
