extends Window
class_name G3TMDBPosterDialog

signal poster_list_requested(tmdb_id: int, media_type: String)
signal thumb_requested(file_path: String)
signal poster_apply_requested(file_path: String)

const GRID_COLUMNS: int = 4
const CELL_SIZE: Vector2 = Vector2(190.0, 290.0)
const BATCH_SIZE: int = 30
const MAX_CONCURRENT_THUMBS: int = 6

var _item_id: String = ""
var _tmdb_id: int = 0
var _media_type: String = "movie"

var _title_label: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _status_label: Label
var _apply_button: Button
var _filter_buttons: Dictionary = {}

var _all_posters: Array = []
var _visible_posters: Array = []
var _filter_mode: String = "all"

var _cells: Dictionary = {}
var _thumb_queue: Array = []
var _thumb_queued: Dictionary = {}
var _thumb_in_flight: Dictionary = {}
var _selected_file_path: String = ""
var _rendered_count: int = 0

func _ready() -> void:
	title = "选择海报"
	size = Vector2i(860, 720)
	min_size = Vector2i(760, 560)
	transient = true
	exclusive = true
	close_requested.connect(_on_close_requested)
	_build_ui()
	hide()

func _on_close_requested() -> void:
	# 关窗即停：清空队列，正在飞的 1~6 个请求让它跑完，不再发新的
	_thumb_queue.clear()
	_thumb_queued.clear()
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.text = "选择海报"
	_title_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_title_label)

	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 6)
	root.add_child(filter_bar)
	_add_filter_button(filter_bar, "all", "全部")
	_add_filter_button(filter_bar, "zh", "中文")
	_add_filter_button(filter_bar, "en", "英文")
	_add_filter_button(filter_bar, "textless", "无文字")

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	root.add_child(_scroll)

	var grid_wrap := MarginContainer.new()
	grid_wrap.add_theme_constant_override("margin_left", 4)
	grid_wrap.add_theme_constant_override("margin_right", 4)
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(grid_wrap)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.add_child(_grid)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(hide)
	buttons.add_child(cancel)

	_apply_button = Button.new()
	_apply_button.text = "应用"
	_apply_button.disabled = true
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)

func _add_filter_button(parent: HBoxContainer, mode: String, label_text: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = (mode == "all")
	btn.pressed.connect(_on_filter_pressed.bind(mode))
	parent.add_child(btn)
	_filter_buttons[mode] = btn

func show_for(item_id: String, tmdb_id: int, media_type: String, title_text: String) -> void:
	_item_id = item_id
	_tmdb_id = tmdb_id
	_media_type = media_type
	_title_label.text = "为《%s》选择海报" % title_text

	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_all_posters.clear()
	_visible_posters.clear()
	_thumb_queue.clear()
	_thumb_queued.clear()
	_thumb_in_flight.clear()
	_selected_file_path = ""
	_rendered_count = 0
	_apply_button.disabled = true
	_status_label.text = "正在获取海报列表…"
	_filter_mode = "all"
	for mode in _filter_buttons.keys():
		var b: Button = _filter_buttons[mode]
		b.button_pressed = (str(mode) == "all")

	popup_centered()
	poster_list_requested.emit(_tmdb_id, _media_type)

func show_poster_list(posters: Array) -> void:
	_all_posters = posters
	_status_label.text = "找到 %d 张海报" % posters.size()
	_apply_filter()

func _on_filter_pressed(mode: String) -> void:
	for m in _filter_buttons.keys():
		var b: Button = _filter_buttons[m]
		b.button_pressed = (str(m) == mode)
	_filter_mode = mode
	_apply_filter()

func _apply_filter() -> void:
	_visible_posters.clear()
	for p in _all_posters:
		if not (p is Dictionary):
			continue
		var lang: String = str(p.get("language", ""))
		var match_filter: bool = false
		if _filter_mode == "all":
			match_filter = true
		elif _filter_mode == "zh":
			match_filter = (lang == "zh" or lang == "cn")
		elif _filter_mode == "en":
			match_filter = (lang == "en")
		elif _filter_mode == "textless":
			match_filter = lang.is_empty()
		if match_filter:
			_visible_posters.append(p)

	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_thumb_queue.clear()
	_thumb_queued.clear()
	_thumb_in_flight.clear()
	_rendered_count = 0

	_status_label.text = "显示 %d / %d 张" % [_visible_posters.size(), _all_posters.size()]

	var initial: int = mini(BATCH_SIZE, _visible_posters.size())
	for i in range(initial):
		_add_cell(_visible_posters[i])
	_rendered_count = initial

	_queue_missing_thumbs()

func _add_cell(poster: Dictionary) -> void:
	var file_path: String = str(poster.get("file_path", ""))
	if file_path.is_empty():
		return
	var p_w: int = int(poster.get("width", 0))
	var p_h: int = int(poster.get("height", 0))
	var p_lang: String = str(poster.get("language", ""))
	var p_vote: float = float(poster.get("vote_average", 0.0))

	var cell := Button.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.08, 0.11, 0.65)
	normal.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("normal", normal)
	cell.add_theme_stylebox_override("hover", normal)
	cell.add_theme_stylebox_override("pressed", normal)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(vbox)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(CELL_SIZE.x - 8.0, CELL_SIZE.y - 46.0)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tex)

	var info := Label.new()
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.68, 0.80, 0.82))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lang_text: String = p_lang if not p_lang.is_empty() else "无文字"
	info.text = "%d×%d · %s · ★%.1f" % [p_w, p_h, lang_text, p_vote]
	vbox.add_child(info)

	cell.pressed.connect(_on_cell_pressed.bind(file_path))
	_grid.add_child(cell)

	_cells[file_path] = {
		"button": cell,
		"texture_rect": tex,
		"loaded": false,
	}

func _queue_missing_thumbs() -> void:
	for fp in _cells.keys():
		var key: String = str(fp)
		var c: Dictionary = _cells[key]
		if c["loaded"]:
			continue
		if _thumb_queued.has(key) or _thumb_in_flight.has(key):
			continue
		_thumb_queue.append(key)
		_thumb_queued[key] = true
	_send_next_thumb()

func _send_next_thumb() -> void:
	while _thumb_in_flight.size() < MAX_CONCURRENT_THUMBS:
		if _thumb_queue.is_empty():
			return
		var file_path: String = str(_thumb_queue.pop_front())
		_thumb_queued.erase(file_path)
		if _thumb_in_flight.has(file_path):
			continue
		_thumb_in_flight[file_path] = true
		thumb_requested.emit(file_path)

func on_thumb_response(file_path: String, local_path: String) -> void:
	if not _thumb_in_flight.has(file_path):
		return
	_thumb_in_flight.erase(file_path)
	var c: Dictionary = _cells.get(file_path, {})
	if not c.is_empty() and not local_path.is_empty() and FileAccess.file_exists(local_path):
		var img := Image.new()
		if img.load(local_path) == OK:
			var tex: TextureRect = c["texture_rect"]
			tex.texture = ImageTexture.create_from_image(img)
			c["loaded"] = true
	_send_next_thumb()

func _on_cell_pressed(file_path: String) -> void:
	for fp in _cells.keys():
		var c: Dictionary = _cells[fp]
		var btn: Button = c["button"]
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.04, 0.08, 0.11, 0.65)
		normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", normal)
		btn.add_theme_stylebox_override("pressed", normal)

	_selected_file_path = file_path
	_apply_button.disabled = false

	var sel: Dictionary = _cells.get(file_path, {})
	if sel.is_empty():
		return
	var sel_btn: Button = sel["button"]
	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color = Color(0.20, 0.14, 0.06, 0.85)
	sel_style.set_corner_radius_all(4)
	sel_style.border_color = Color(0.88, 0.66, 0.36, 0.85)
	sel_style.set_border_width_all(2)
	sel_btn.add_theme_stylebox_override("normal", sel_style)
	sel_btn.add_theme_stylebox_override("hover", sel_style)
	sel_btn.add_theme_stylebox_override("pressed", sel_style)

func _on_scroll_changed(value: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	if bar == null:
		return
	if value >= bar.max_value - bar.page - 200.0:
		_load_more()

func _load_more() -> void:
	if _rendered_count >= _visible_posters.size():
		return
	var next: int = mini(_rendered_count + BATCH_SIZE, _visible_posters.size())
	for i in range(_rendered_count, next):
		_add_cell(_visible_posters[i])
	_rendered_count = next
	_queue_missing_thumbs()

func _on_apply_pressed() -> void:
	if _selected_file_path.is_empty():
		return
	poster_apply_requested.emit(_selected_file_path)

func set_apply_done() -> void:
	_on_close_requested()