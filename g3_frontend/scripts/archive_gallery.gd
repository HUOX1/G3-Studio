extends Node3D
class_name G3ArchiveGallery

## Read-only view of library.games.list in the unused MUSIC slot.
## The private viewport isolates lighting/camera changes from every other section.
signal game_launch_requested(game: Dictionary)

const STAGE: PackedScene = preload("res://scenes/archive_stage.tscn")
const COVER: Shader = preload("res://shaders/archive_cover.gdshader")
const GLASS: Shader = preload("res://shaders/archive_glass.gdshader")
const FLOOR: Shader = preload("res://shaders/archive_floor.gdshader")
const VISIBLE_CASES: int = 11
const CACHE_LIMIT: int = 32
const INK: Color = Color("202b2c")
const MUTED: Color = Color("626c6a")
const BRONZE: Color = Color("876442")

var _active: bool = false
var _games: Array[Dictionary] = []
var _selection: int = 0
var _cases: Array[Dictionary] = []
var _layer: CanvasLayer
var _root: Control
var _container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _info: VBoxContainer
var _title: Label
var _meta: Label
var _record: Label
var _counter: Label
var _status: Label
var _hint: Label
var _description: Label
var _description_scroll: ScrollContainer
var _specs: Label
var _open_button: Button
var _back_button: Button
var _launch_button: Button
var _glass_button: Button
var _motion_button: Button
var _index_button: Button
var _previous_button: Button
var _next_button: Button
var _masthead: Label
var _brand: Label
var _footer: Label
var _search: PanelContainer
var _search_input: LineEdit
var _results: ItemList
var _result_ids: Array[int] = []
var _detail: bool = false
var _detail_progress: float = 0.0
var _frosted: bool = false
var _frost_progress: float = 0.0
var _reduced_motion: bool = false
var _snap: bool = false
var _hover: int = -1
var _title_font: SystemFont
var _ui_font: SystemFont
var _font_manager: Node
var _loading: Dictionary = {}
var _cache: Dictionary = {}
var _cache_order: Array[String] = []
var _tasks: Array[int] = []
var _launch_pending: bool = false
var _launch_game_id: String = ""
var _feedback_until: int = 0

func configure(_shared_camera: Camera3D) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	_layer.name = "ArchiveCanvas"
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "sans-serif"])
	var typography := Theme.new()
	typography.default_font = _ui_font
	_root.theme = typography
	_title_font = _ui_font.duplicate() as SystemFont
	_title_font.font_weight = 600
	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.physics_object_picking = false
	_container.add_child(_viewport)
	_world = STAGE.instantiate() as Node3D
	_viewport.add_child(_world)
	_camera = _world.get_node("Camera") as Camera3D
	_build_room()
	_build_cases()
	_build_overlay()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_layer.visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
	set_process_unhandled_input(false)
	set_process_input(false)

func set_section_visible(enabled: bool) -> void:
	if enabled == _active:
		return
	_active = enabled
	_layer.visible = enabled
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	set_process(enabled)
	set_process_unhandled_input(enabled)
	set_process_input(enabled)
	if enabled:
		_resize()
		_bind_cases()
		_update_scene(1.0, true)
	else:
		_search.hide()
		_search_input.release_focus()
		_hover = -1

func set_games(items: Array[Dictionary]) -> void:
	var selected_id: String = str(_games[_selection].get("id", "")) if not _games.is_empty() else ""
	_games = items.duplicate()
	_selection = 0
	var preserved: bool = false
	for i in range(_games.size()):
		if str(_games[i].get("id", "")) == selected_id:
			_selection = i
			preserved = true
			break
	if not preserved:
		_detail = false
		_feedback_until = 0
		if _description_scroll != null:
			_description_scroll.hide()
	if _active:
		_bind_cases()
	if _search != null and _search.visible:
		_filter_index(_search_input.text)

func set_font_manager(manager: Node) -> void:
	_font_manager = manager
	apply_fontset()

func apply_fontset() -> void:
	if _font_manager == null or _title == null:
		return
	var title_font: FontFile = _font_manager.get_font_for("game_title", "games")
	var body_font: FontFile = _font_manager.get_font_for("game_meta", "games")
	if title_font != null:
		_title.add_theme_font_override("font", title_font)
	else:
		_title.add_theme_font_override("font", _title_font)
	for label: Label in [_meta, _description, _specs]:
		if body_font != null:
			label.add_theme_font_override("font", body_font)
		else:
			label.remove_theme_font_override("font")
	_resize()

func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e5e3db")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ece8da")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("e5e3db")
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.016
	var env := WorldEnvironment.new()
	env.environment = environment
	_world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_color = Color("fff2dc")
	key.light_energy = 0.72
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 45.0
	key.light_size = 1.5
	key.shadow_blur = 2.0
	_world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_color = Color("cbdfe0")
	fill.light_energy = 0.18
	_world.add_child(fill)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_node.mesh = plane
	floor_node.position.y = -3.0
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR
	floor_node.material_override = mat
	_world.add_child(floor_node)
	# One broad, shallow architectural podium with a layered edge.
	_box(_world, Vector3(-1, -2.86, -3.0), Vector3(21, 0.20, 18), Color("a5aaa3"), 0.15)
	_box(_world, Vector3(-1, -2.72, -3.0), Vector3(20.8, 0.08, 17.8), Color("7e8b87"), 0.10)
	for x: float in [-6.0, 1.9]:
		_box(_world, Vector3(x, -2.65, -3.1), Vector3(0.025, 0.018, 14.6), Color("9c8a69"), 0.55)

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.38
	node.material_override = material
	parent.add_child(node)
	return node

func _build_cases() -> void:
	for i in range(VISIBLE_CASES):
		var holder := Node3D.new()
		holder.name = "ArchiveCase_%02d" % i
		holder.set_meta("offset", i - 5)
		holder.set_meta("game_index", -1)
		holder.set_meta("generation", 0)
		_world.add_child(holder)
		_box(holder, Vector3(0, -0.01, -0.08), Vector3(2.83, 4.3, 0.26), Color("b5c1bb"), 0.45)
		_box(holder, Vector3(0, -2.18, -0.04), Vector3(3.05, 0.12, 0.84), Color("8e9b96"), 0.38)
		_box(holder, Vector3(0, -2.10, 0.24), Vector3(2.86, 0.026, 0.13), Color("aa8c5f"), 0.58)
		for x: float in [-1.39, 1.39]:
			_box(holder, Vector3(x, 0, 0.13), Vector3(0.035, 4.25, 0.10), Color("d0dcd5"), 0.65)
		var cover := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.55, 3.8)
		cover.mesh = quad
		cover.position = Vector3(0, 0.06, 0.067)
		var cover_mat := ShaderMaterial.new()
		cover_mat.shader = COVER
		cover.material_override = cover_mat
		cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(cover)
		var glass := MeshInstance3D.new()
		var face := QuadMesh.new()
		face.size = Vector2(2.79, 4.20)
		glass.mesh = face
		glass.position.z = 0.13
		var glass_mat := ShaderMaterial.new()
		glass_mat.shader = GLASS
		glass.material_override = glass_mat
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(glass)
		var number := Label3D.new()
		number.font_size = 36
		number.pixel_size = 0.0026
		number.position = Vector3(-1.14, -2.01, 0.143)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		number.modulate = Color("243335")
		number.outline_size = 0
		holder.add_child(number)
		var fallback := Label3D.new()
		fallback.font = _ui_font
		fallback.font_size = 64
		fallback.pixel_size = 0.0036
		fallback.width = 580
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback.position = Vector3(0, 0.25, 0.08)
		fallback.modulate = Color("e7ece8")
		fallback.outline_size = 0
		holder.add_child(fallback)
		_cases.append({"node":holder, "cover":cover_mat, "glass":glass_mat, "lid":glass, "number":number, "fallback":fallback})

func _label(parent: Node, text: String, size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, solid: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("f1f0e9") if solid else INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE if solid else BRONZE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE if solid else BRONZE)
	button.add_theme_color_override("font_disabled_color", Color("838b83"))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (Color("253637") if solid else Color(0.9, 0.9, 0.85, 0.72))
		if state == "hover":
			style.bg_color = Color("3c4a46") if solid else Color("f1eee5")
		elif state == "pressed":
			style.bg_color = Color("64523b") if solid else Color("d5c6ac")
		style.border_color = Color("9eaa9f")
		style.border_width_bottom = 1
		style.content_margin_left = 14
		style.content_margin_right = 14
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_overlay() -> void:
	_masthead = _label(_root, "G3   /   THE PRIVATE COLLECTION", 13, MUTED)
	_brand = _label(_root, "游戏藏品室", 30)
	_brand.add_theme_font_override("font", _title_font)
	_footer = _label(_root, "PERSONAL ARCHIVE     /     SPACE STUDY 02", 11, MUTED)
	_counter = _label(_root, "000", 60)
	_record = _label(_root, "", 12, MUTED)
	_previous_button = _button(_root, "←  上一件", _shift.bind(-1))
	_next_button = _button(_root, "下一件  →", _shift.bind(1))
	_index_button = _button(_root, "⌕  藏品索引", _open_index)
	_glass_button = _button(_root, "玻璃 · 清晰", _toggle_glass)
	_motion_button = _button(_root, "动态 · 开", _toggle_motion)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 16)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_info)
	_meta = _label(_info, "", 12, BRONZE)
	_title = _label(_info, "", 38)
	_title.add_theme_font_override("font", _title_font)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 3
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", Color("9ba29a"))
	_info.add_child(rule)
	_specs = _label(_info, "", 14, MUTED)
	_specs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_scroll = ScrollContainer.new()
	_description_scroll.custom_minimum_size.y = 160
	_description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info.add_child(_description_scroll)
	_description = _label(_description_scroll, "", 16)
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_scroll.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_info.add_child(actions)
	_open_button = _button(actions, "打开档案  ↗", _set_detail.bind(true), true)
	_back_button = _button(actions, "←  返回阵列", _set_detail.bind(false))
	_back_button.hide()
	_launch_button = _button(actions, "启动游戏  ↗", _request_launch, true)
	_launch_button.hide()
	_status = _label(_info, "", 13, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(_root, "滚轮 / ← → 浏览    单击聚焦    双击 / Space 档案    Enter 启动", 12, MUTED)
	_build_index()

func _build_index() -> void:
	_search = PanelContainer.new()
	_search.hide()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eeece4")
	style.border_color = Color("a4aca3")
	style.set_border_width_all(1)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_search.add_theme_stylebox_override("panel", style)
	_root.add_child(_search)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	_search.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var title := _label(heading, "COLLECTION INDEX   /   藏品索引", 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "关闭  Esc", _close_index)
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索游戏、英文名、平台或来源"
	_search_input.custom_minimum_size.y = 44
	_search_input.add_theme_font_size_override("font_size", 18)
	_search_input.add_theme_color_override("font_color", INK)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("faf8ef")
	input_style.border_width_bottom = 1
	input_style.border_color = MUTED
	input_style.content_margin_left = 10
	_search_input.add_theme_stylebox_override("normal", input_style)
	_search_input.add_theme_stylebox_override("focus", input_style)
	_search_input.text_changed.connect(_filter_index)
	_search_input.text_submitted.connect(func(_text: String): _activate_result(0))
	stack.add_child(_search_input)
	_results = ItemList.new()
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.add_theme_color_override("font_color", INK)
	_results.add_theme_color_override("font_selected_color", Color("f6f4ed"))
	_results.add_theme_font_size_override("font_size", 17)
	_results.add_theme_constant_override("v_separation", 14)
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color("eeece4")
	_results.add_theme_stylebox_override("panel", list_style)
	_results.item_clicked.connect(func(index: int, _at: Vector2, button: int):
		if button == MOUSE_BUTTON_LEFT: _activate_result(index))
	_results.item_activated.connect(_activate_result)
	stack.add_child(_results)
	_label(stack, "按游戏名称排序  /  点击结果聚焦，不启动游戏", 12, MUTED)

func _resize() -> void:
	if _root == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Only the 3D surface may reduce resolution; text stays at window resolution.
	_container.stretch_shrink = 2 if vp.x * vp.y > 2560.0 * 1440.0 else 1
	var s: float = clampf(vp.y / 900.0, 0.77, 1.3)
	var margin: float = 48.0 * s
	_masthead.position = Vector2(margin, 78 * s)
	_brand.position = Vector2(margin, 100 * s)
	_footer.position = Vector2(margin, vp.y - 40 * s)
	_index_button.position = Vector2(vp.x - margin - 405, 78 * s)
	_glass_button.position = Vector2(vp.x - margin - 265, 78 * s)
	_motion_button.position = Vector2(vp.x - margin - 125, 78 * s)
	_counter.position = Vector2(margin, vp.y - 210 * s)
	_counter.add_theme_font_size_override("font_size", roundi(60 * s))
	_record.position = Vector2(margin + 4, vp.y - 130 * s)
	_previous_button.position = Vector2(margin, vp.y - 100 * s)
	_next_button.position = Vector2(margin + 134, vp.y - 100 * s)
	_info.size.x = vp.x * 0.30
	var font_scale: float = clampf(s, 0.90, 1.15)
	_title.add_theme_font_size_override("font_size", roundi(38 * font_scale))
	_description_scroll.custom_minimum_size.y = minf(170 * s, vp.y * 0.20)
	_hint.position = Vector2(vp.x * 0.51, vp.y - 40 * s)
	_hint.size.x = vp.x * 0.46
	_hint.text = "← → / 滚轮 浏览   双击 / Space 档案   Enter 启动" if vp.x < 1400 else "滚轮 / ← → 浏览    单击聚焦    双击 / Space 档案    Enter 启动"
	_hint.add_theme_font_size_override("font_size", 11 if vp.x < 1400 else 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_search.position = Vector2(vp.x * 0.19, vp.y * 0.20)
	_search.size = Vector2(vp.x * 0.62, vp.y * 0.62)
	_update_scene(1.0, true)

func _bind_cases() -> void:
	_hover = -1
	var count: int = mini(VISIBLE_CASES, _games.size())
	var center: int = count / 2
	for slot in range(_cases.size()):
		var node: Node3D = _cases[slot]["node"]
		node.visible = slot < count
		if slot >= count:
			continue
		var offset: int = slot - center
		node.set_meta("offset", offset)
		_bind_game(slot, wrapi(_selection + offset, 0, _games.size()))
		_set_case_pose(slot, 1.0, true)
	_refresh_info()

func _bind_game(slot: int, game_index: int) -> void:
	var c: Dictionary = _cases[slot]
	var node: Node3D = c["node"]
	var game: Dictionary = _games[game_index]
	var path: String = str(game.get("cover", "")).replace("\\", "/")
	var token: int = int(node.get_meta("generation")) + 1
	node.set_meta("generation", token)
	node.set_meta("game_index", game_index)
	node.set_meta("path", path)
	(c["number"] as Label3D).text = "G3 / %s" % str(game.get("id", game_index + 1)).pad_zeros(4)
	(c["fallback"] as Label3D).text = str(game.get("title", "未命名藏品")) + "\n\n封面待入藏"
	(c["fallback"] as Label3D).visible = true
	(c["cover"] as ShaderMaterial).set_shader_parameter("use_texture", false)
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var stamp: int = FileAccess.get_modified_time(path)
	if _cache.has(path) and int(_cache[path]["stamp"]) == stamp:
		_show_texture(slot, _cache[path]["texture"] as Texture2D)
		return
	var listener: Dictionary = {"slot": slot, "token": token}
	if _loading.has(path):
		(_loading[path] as Array).append(listener)
	else:
		_loading[path] = [listener]
		_tasks.append(WorkerThreadPool.add_task(_read_cover.bind(path, stamp)))

func _read_cover(path: String, stamp: int) -> void:
	# Same background decode / main-thread texture upload pattern as game_section.
	var image := Image.new()
	var result: Error = image.load(path)
	if result == OK and not image.is_empty():
		if maxi(image.get_width(), image.get_height()) > 1200:
			var factor: float = 1200.0 / maxi(image.get_width(), image.get_height())
			image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		call_deferred("_finish_cover", path, stamp, image)
	else:
		call_deferred("_finish_cover", path, stamp, null)

func _finish_cover(path: String, stamp: int, image: Image) -> void:
	var texture: Texture2D
	if image != null:
		texture = ImageTexture.create_from_image(image)
	elif ClassDB.class_exists(&"AnimatedImageLoader"):
		texture = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_file", path) as Texture2D
	var listeners: Array = _loading.get(path, [])
	_loading.erase(path)
	if texture == null:
		return
	if _cache_order.has(path):
		_cache_order.erase(path)
	_cache_order.append(path)
	_cache[path] = {"texture":texture, "stamp":stamp}
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	for listener: Dictionary in listeners:
		var slot: int = int(listener["slot"])
		var node: Node3D = _cases[slot]["node"]
		if int(node.get_meta("generation")) == int(listener["token"]) and str(node.get_meta("path")) == path:
			_show_texture(slot, texture)

func _show_texture(slot: int, texture: Texture2D) -> void:
	var material: ShaderMaterial = _cases[slot]["cover"]
	material.set_shader_parameter("cover_texture", texture)
	material.set_shader_parameter("image_aspect", float(texture.get_width()) / maxf(1.0, texture.get_height()))
	material.set_shader_parameter("use_texture", true)
	(_cases[slot]["fallback"] as Label3D).visible = false

func _pose(offset: int) -> Vector3:
	if offset == 0:
		return Vector3(-2.7, 0.33, 2.6).lerp(Vector3(-2.8, 0.95, 3.1), _detail_progress)
	var depth: float = float(absi(offset) - 1)
	if offset < 0:
		return Vector3(-8.0 - depth * 0.15, -0.68, 0.2 - depth * 1.7)
	return Vector3(-0.8 - depth * 0.25, -0.68, -3.4 - depth * 1.5)

func _set_case_pose(slot: int, alpha: float, snap: bool) -> void:
	var c: Dictionary = _cases[slot]
	var node: Node3D = c["node"]
	var offset: int = int(node.get_meta("offset", 0))
	var selected: bool = offset == 0
	var target: Vector3 = _pose(offset)
	if slot == _hover and not _detail:
		target.y += 0.055
	var a: float = 1.0 if snap else alpha
	node.position = node.position.lerp(target, a)
	var yaw: float = lerpf(12.0, 20.0, _detail_progress) if selected else 3.0
	node.rotation = node.rotation.lerp(Vector3(0, deg_to_rad(yaw), 0), a)
	var size: float = lerpf(1.34, 1.43, _detail_progress) if selected else 0.89
	node.scale = node.scale.lerp(Vector3.ONE * size, a)
	(c["cover"] as ShaderMaterial).set_shader_parameter("frosted", _frost_progress if selected else 0.0)
	(c["cover"] as ShaderMaterial).set_shader_parameter("distance_fade", 0.0 if selected else minf(0.72, 0.20 + absi(offset) * 0.075 + _detail_progress * 0.22))
	(c["glass"] as ShaderMaterial).set_shader_parameter("selected", 1.0 if selected or slot == _hover else 0.0)
	(c["glass"] as ShaderMaterial).set_shader_parameter("frosted", _frost_progress if selected else 0.0)
	(c["lid"] as MeshInstance3D).position.z = 0.13 + (0.16 * _detail_progress if selected else 0.0)

func _process(delta: float) -> void:
	var alpha: float = 1.0 - exp(-18.0 * minf(delta, 0.1))
	_update_scene(alpha, _reduced_motion or _snap)
	_snap = false
	if not _search.visible:
		_hover = _pick_case(get_viewport().get_mouse_position())
	for i in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_tasks[i])
			_tasks.remove_at(i)
	if _feedback_until > 0 and Time.get_ticks_msec() > _feedback_until:
		_feedback_until = 0
		_refresh_info()

func _update_scene(alpha: float, snap: bool) -> void:
	if _camera == null:
		return
	var a: float = 1.0 if snap else alpha
	_detail_progress = lerpf(_detail_progress, 1.0 if _detail else 0.0, a)
	_frost_progress = lerpf(_frost_progress, 1.0 if _frosted else 0.0, a)
	_camera.position = Vector3(7.0, 5.4, 19.0).lerp(Vector3(6.2, 4.2, 18.0), _detail_progress)
	_camera.look_at(Vector3(-0.2, 0.3, 0))
	for slot in range(_cases.size()):
		if (_cases[slot]["node"] as Node3D).visible:
			_set_case_pose(slot, alpha, snap)
	if _info != null:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_info.position = Vector2(vp.x * 0.666, vp.y * lerpf(0.37, 0.23, _detail_progress))

func _shift(direction: int) -> void:
	if _games.size() < 2 or _search.visible:
		return
	_select(wrapi(_selection + direction, 0, _games.size()))

func _select(index: int) -> void:
	if index < 0 or index >= _games.size() or index == _selection:
		return
	_selection = index
	_feedback_until = 0
	_detail = false
	_description_scroll.hide()
	_description_scroll.scroll_vertical = 0
	var count: int = mini(VISIBLE_CASES, _games.size())
	var center: int = count / 2
	var missing_offsets: Array[int] = []
	var free_slots: Array[int] = []
	for offset in range(-center, count - center):
		var wanted: int = wrapi(index + offset, 0, _games.size())
		var found: bool = false
		for slot in range(count):
			var node: Node3D = _cases[slot]["node"]
			if int(node.get_meta("game_index")) == wanted:
				node.set_meta("offset", offset)
				found = true
				break
		if not found:
			missing_offsets.append(offset)
	for slot in range(count):
		var node: Node3D = _cases[slot]["node"]
		var relative: int = wrapi(int(node.get_meta("game_index")) - index + center, 0, _games.size()) - center
		if relative < -center or relative >= count - center:
			free_slots.append(slot)
	# Preserve existing identities. Only recycle objects outside the new window.
	for i in range(free_slots.size()):
		var slot: int = free_slots[i]
		var offset: int = missing_offsets[i]
		var node: Node3D = _cases[slot]["node"]
		node.set_meta("offset", offset)
		_bind_game(slot, wrapi(index + offset, 0, _games.size()))
		node.position = _pose(offset) + Vector3(0, 0, -1.5)
	_hover = -1
	_refresh_info()

func _set_detail(enabled: bool) -> void:
	if _games.is_empty():
		return
	_detail = enabled
	_description_scroll.visible = enabled
	_description_scroll.scroll_vertical = 0
	_refresh_info()

func _refresh_info() -> void:
	if _title == null:
		return
	var empty: bool = _games.is_empty()
	_previous_button.disabled = _games.size() < 2
	_next_button.disabled = _games.size() < 2
	_open_button.visible = not _detail
	_open_button.disabled = empty
	_back_button.visible = _detail
	_launch_button.visible = _detail
	if empty:
		_title.text = "等待第一件藏品"
		_meta.text = "YOUR COLLECTION STARTS HERE"
		_specs.text = "在游戏版块添加游戏后，档案将在这里陈列。"
		_record.text = "NO RECORDS"
		_counter.text = "000"
		_status.text = "空档案室 / 可从顶部导航返回游戏库"
		_launch_button.disabled = true
		return
	var game: Dictionary = _games[_selection]
	_title.text = str(game.get("title", "未命名藏品"))
	_title.tooltip_text = _title.text
	var platform: String = str(game.get("platform", "")).strip_edges()
	var source: String = str(game.get("source", "manual")).to_upper()
	_meta.text = (platform.to_upper() + "   /   " if not platform.is_empty() and platform.to_upper() != source else "") + source
	_counter.text = "%03d" % (_selection + 1)
	_record.text = "/ %03d   COLLECTION RECORDS" % _games.size()
	var hours: float = float(game.get("playtime_seconds", 0)) / 3600.0
	_specs.text = "累计游玩   %.1f h" % hours
	var genres: String = str(game.get("genres", "")).strip_edges()
	if _detail and not genres.is_empty():
		_specs.text += "\n" + genres
	_description.text = str(game.get("description", "")).strip_edges()
	if _description.text.is_empty():
		_description.text = "这件藏品尚未录入简介。可在游戏版块补充资料；此处保留原始收藏记录。"
	var playable: bool = bool(game.get("playable", true))
	var launching: bool = _launch_pending and str(game.get("id", "")) == _launch_game_id
	_launch_button.disabled = not playable or _launch_pending
	_launch_button.text = "请求启动中…" if launching else "启动游戏  ↗"
	if launching:
		_status.text = "正在请求后端启动…"
	elif _feedback_until == 0:
		_status.text = "Enter 启动 / Esc 返回" if _detail else "已聚焦 / 打开档案以阅读"
		if not playable:
			_status.text = "尚未配置启动方式，请在游戏版块设置"

func _request_launch() -> void:
	if not _active or _games.is_empty() or _launch_pending or _search.visible:
		return
	var game: Dictionary = _games[_selection]
	if not bool(game.get("playable", true)):
		return
	_launch_pending = true
	_launch_game_id = str(game.get("id", ""))
	_status.text = "正在请求后端启动…"
	_refresh_info()
	game_launch_requested.emit(game)

func set_launch_result(ok: bool, message: String = "") -> void:
	if not _launch_pending:
		return
	_launch_pending = false
	if _games.is_empty() or str(_games[_selection].get("id", "")) != _launch_game_id:
		_refresh_info()
		return
	_feedback_until = Time.get_ticks_msec() + 5000
	_status.text = "启动请求已接受" if ok else "启动失败：" + message
	_refresh_info()

func _toggle_glass() -> void:
	_frosted = not _frosted
	_glass_button.text = "玻璃 · 磨砂" if _frosted else "玻璃 · 清晰"

func _toggle_motion() -> void:
	_reduced_motion = not _reduced_motion
	_motion_button.text = "动态 · 减少" if _reduced_motion else "动态 · 开"
	_snap = true

func _open_index() -> void:
	_search.show()
	_search_input.text = ""
	_filter_index("")
	_search_input.grab_focus()

func _close_index() -> void:
	_search.hide()
	_search_input.release_focus()
	_results.release_focus()

func _filter_index(query: String) -> void:
	_results.clear()
	_result_ids.clear()
	var needle: String = query.strip_edges().to_lower()
	for i in range(_games.size()):
		var game: Dictionary = _games[i]
		var haystack: String = (str(game.get("title", "")) + " " + str(game.get("english_name", "")) + " " + str(game.get("platform", "")) + " " + str(game.get("source", ""))).to_lower()
		if needle.is_empty() or haystack.contains(needle):
			_result_ids.append(i)
			_results.add_item("%03d    %s    /    %s" % [i + 1, str(game.get("title", "")), str(game.get("platform", ""))])
	if _result_ids.is_empty():
		_results.add_item("没有匹配的藏品")
		_results.set_item_disabled(0, true)

func _activate_result(index: int) -> void:
	if index < 0 or index >= _result_ids.size():
		return
	var target: int = _result_ids[index]
	_close_index()
	_selection = target
	_feedback_until = 0
	_detail = false
	_description_scroll.hide()
	_bind_cases()
	_update_scene(1.0, true)

func _pick_case(screen_position: Vector2) -> int:
	if _games.is_empty() or _search.visible:
		return -1
	var window: Vector2 = get_viewport().get_visible_rect().size
	var pixel: Vector2 = screen_position * Vector2(_viewport.size) / window
	var origin: Vector3 = _camera.project_ray_origin(pixel)
	var ray: Vector3 = _camera.project_ray_normal(pixel)
	var nearest: float = INF
	var hit: int = -1
	for slot in range(_cases.size()):
		var node: Node3D = _cases[slot]["node"]
		if not node.visible:
			continue
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_ray: Vector3 = inverse.basis * ray
		if absf(local_ray.z) < 0.00001:
			continue
		var distance: float = (0.14 - local_origin.z) / local_ray.z
		var at: Vector3 = local_origin + local_ray * distance
		if distance > 0 and absf(at.x) < 1.43 and absf(at.y) < 2.16:
			var world_distance: float = origin.distance_to(node.global_transform * at)
			if world_distance < nearest:
				nearest = world_distance
				hit = slot
	return hit

func _input(event: InputEvent) -> void:
	# A focused LineEdit consumes ui_cancel before _unhandled_input. Close this
	# modal at the input stage and stop Escape from reaching the underlying scene.
	if _active and _search.visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_close_index()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _search.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_index()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_shift(1)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_shift(-1)
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			var slot: int = _pick_case(mouse.position)
			if slot < 0:
				return
			var index: int = int((_cases[slot]["node"] as Node3D).get_meta("game_index"))
			if mouse.double_click and index == _selection:
				_set_detail(true)
			else:
				_select(index)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return
		match key.keycode:
			KEY_LEFT, KEY_UP: _shift(-1)
			KEY_RIGHT, KEY_DOWN: _shift(1)
			KEY_SPACE: _set_detail(not _detail)
			KEY_ESCAPE: _set_detail(false)
			KEY_ENTER, KEY_KP_ENTER: _request_launch()
			KEY_G: _toggle_glass()
			KEY_SLASH: _open_index()
			_: return
		# Keyboard operations settle immediately, with no queued animation.
		_snap = true
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Bound callables must finish before their owning Node is released.
	for id: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
