extends Window
class_name G3GameScraperDialog

signal search_requested(query: String)
signal assets_requested(sgdb_id: int, asset_type: String)
signal apply_requested(sgdb_id: int, asset_type: String, url: String)

const ASSET_TYPES: Array[String] = ["grid", "hero", "logo", "icon"]
const ASSET_LABELS: Dictionary = {
	"grid": "封面（竖版）",
	"hero": "壁纸（横版）",
	"logo": "LOGO（透明底）",
	"icon": "图标（侧边栏用）",
}
const THUMB_SIZE: Vector2 = Vector2(198.0, 140.0)

var _item_id: String = ""
var _game_title: String = ""

var _query_field: LineEdit
var _status_label: Label
var _results_list: VBoxContainer
var _apply_button: Button
var _sections_root: VBoxContainer

var _search_results: Array = []
var _selected_sgdb_id: int = 0
var _selected_result_btn: Button = null
var _tab_buttons: Dictionary = {}
var _active_tab: String = "grid"

# asset_type -> { "row": HBoxContainer, "selected_url": String, "loaded": bool }
var _sections: Dictionary = {}
# asset_type -> Dictionary(卡片字典，url -> Button)
var _thumb_cards: Dictionary = {}

func _ready() -> void:
	title = "从 SteamGridDB 获取素材"
	size = Vector2i(780, 760)
	min_size = Vector2i(680, 620)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "从 SteamGridDB 获取素材"
	heading.add_theme_font_size_override("font_size", 18)
	root.add_child(heading)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	root.add_child(search_row)

	_query_field = LineEdit.new()
	_query_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query_field.placeholder_text = "英文名，例如 Rain World"
	_query_field.text_submitted.connect(func(_t): _on_search_pressed())
	search_row.add_child(_query_field)

	var search_btn := Button.new()
	search_btn.text = "搜索"
	search_btn.pressed.connect(_on_search_pressed)
	search_row.add_child(search_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(_status_label)

	var results_scroll := ScrollContainer.new()
	results_scroll.custom_minimum_size = Vector2(0, 150)
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(results_scroll)

	_results_list = VBoxContainer.new()
	_results_list.add_theme_constant_override("separation", 2)
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(_results_list)

	# Tab 栏
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root.add_child(tab_bar)
	for t in ASSET_TYPES:
		var tab_btn := Button.new()
		tab_btn.text = str(ASSET_LABELS.get(t, t))
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.toggle_mode = true
		tab_btn.custom_minimum_size = Vector2(120.0, 32.0)
		tab_btn.pressed.connect(_on_tab_pressed.bind(t))
		tab_bar.add_child(tab_btn)
		_tab_buttons[t] = tab_btn

	# 素材区：每个 section 一个 ScrollContainer，只显示当前 tab
	_sections_root = VBoxContainer.new()
	_sections_root.add_theme_constant_override("separation", 8)
	_sections_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_sections_root)

	for t in ASSET_TYPES:
		_build_section(t)

	_on_tab_pressed("grid")

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(hide)
	buttons.add_child(cancel)

	_apply_button = Button.new()
	_apply_button.text = "应用选中"
	_apply_button.disabled = true
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)

func _build_section(asset_type: String) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.visible = false
	_sections_root.add_child(section)

	var cell: Vector2 = THUMB_SIZE
	if asset_type == "icon":
		cell = Vector2(172.0, 172.0)
	elif asset_type == "hero":
		cell = Vector2(320.0, 172.0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, cell.y + 40.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	section.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)

	_sections[asset_type] = {
		"row": row,
		"selected_url": "",
		"cell": cell,
		"section": section,
	}
	_thumb_cards[asset_type] = {}

func _on_tab_pressed(asset_type: String) -> void:
	_active_tab = asset_type
	for t in _sections.keys():
		var sec: Dictionary = _sections[t]
		var section: VBoxContainer = sec.get("section", null)
		if section != null:
			section.visible = (t == asset_type)
	for t in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t]
		btn.button_pressed = (t == asset_type)

# ---------- 搜索 ----------

func show_for(item_id: String, game_title: String) -> void:
	_item_id = item_id
	_game_title = game_title
	_query_field.text = game_title
	_clear_results()
	_clear_all_sections()
	_status_label.text = "点「搜索」开始"
	_apply_button.disabled = true
	popup_centered_clamped(size, 0.85)

func _on_search_pressed() -> void:
	var q: String = _query_field.text.strip_edges()
	if q.is_empty():
		_status_label.text = "请输入搜索词"
		return
	_clear_results()
	_clear_all_sections()
	_selected_sgdb_id = 0
	_apply_button.disabled = true
	_status_label.text = "搜索中…"
	search_requested.emit(q)

func show_search_results(results: Array) -> void:
	_search_results = results
	_clear_results()
	if results.is_empty():
		_status_label.text = "没找到。试试输入英文名（如 Silent Hill）"
		return
	_status_label.text = "找到 %d 个结果，如需换游戏请点其它条目" % results.size()
	var first_btn: Button = null
	for raw in results:
		if raw is Dictionary:
			var btn := _make_result_row(raw as Dictionary)
			_results_list.add_child(btn)
			if first_btn == null:
				first_btn = btn
	# 自动选中第一个结果：省一步点击，直接进素材列表
	if first_btn != null:
		var sid: int = int(first_btn.get_meta("sgdb_id"))
		_on_result_clicked(sid, first_btn)

func _clear_results() -> void:
	for c in _results_list.get_children():
		c.queue_free()
	_selected_result_btn = null

func _make_result_row(hit: Dictionary) -> Button:
	var id: int = int(hit.get("id", 0))
	var name: String = str(hit.get("name", ""))
	var types: Array = hit.get("types", [])
	var btn := Button.new()
	if types.is_empty():
		btn.text = name
	else:
		btn.text = "%s  [%s]" % [name, ",".join(types)]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 28)
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("sgdb_id", id)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_result_clicked.bind(id, btn))
	return btn

func _on_result_clicked(sgdb_id: int, btn: Button) -> void:
	if _selected_result_btn != null and is_instance_valid(_selected_result_btn):
		_selected_result_btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_selected_result_btn = btn
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_selected_sgdb_id = sgdb_id
	_clear_all_sections()
	_status_label.text = "加载素材中…"
	for t in ASSET_TYPES:
		assets_requested.emit(sgdb_id, t)

# ---------- 素材 ----------

func _clear_all_sections() -> void:
	for t in _sections.keys():
		var sec: Dictionary = _sections[t]
		var row: HBoxContainer = sec["row"]
		for c in row.get_children():
			c.queue_free()
		sec["selected_url"] = ""
		_thumb_cards[t] = {}
	_apply_button.disabled = true

func show_assets(asset_type: String, items: Array) -> void:
	if not _sections.has(asset_type):
		return
	var sec: Dictionary = _sections[asset_type]
	var row: HBoxContainer = sec["row"]
	for c in row.get_children():
		c.queue_free()
	_thumb_cards[asset_type] = {}
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var thumb_local: String = str(item.get("thumb_local", ""))
		var url: String = str(item.get("url", ""))
		if url.is_empty():
			continue
		var card := _make_thumb_card(asset_type, url, thumb_local, item)
		row.add_child(card)
		var cards: Dictionary = _thumb_cards[asset_type]
		cards[url] = card
	_status_label.text = "素材已加载，点击选中后应用"

func _make_thumb_card(asset_type: String, url: String, thumb_local: String, item: Dictionary) -> Button:
	var btn := Button.new()
	var cell: Vector2 = THUMB_SIZE
	if _sections.has(asset_type):
		cell = _sections[asset_type].get("cell", THUMB_SIZE)
	btn.custom_minimum_size = cell
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("asset_url", url)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	bg.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)

	var thumb_loaded: bool = false
	if not thumb_local.is_empty() and FileAccess.file_exists(thumb_local):
		var img := Image.new()
		if img.load(thumb_local) == OK:
			var tex_rect := TextureRect.new()
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.texture = ImageTexture.create_from_image(img)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tex_rect)
			thumb_loaded = true
	if not thumb_loaded:
		# 没缩略图:显示占位文字,让用户知道这是可点的按钮
		var ph := Label.new()
		ph.text = "无预览"
		ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.add_theme_font_size_override("font_size", 11)
		ph.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(ph)

	var w: int = int(item.get("width", 0))
	var h: int = int(item.get("height", 0))
	var size_text: String = "%dx%d" % [w, h] if w > 0 else "—"
	var info := Label.new()
	info.text = size_text
	info.anchor_left = 0.0
	info.anchor_right = 1.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_top = -18.0
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(info)

	# 动图标记：只在 is_animated 为 true 时加，放右上角
	if bool(item.get("is_animated", false)):
		var badge_wrap := PanelContainer.new()
		badge_wrap.anchor_left = 1.0
		badge_wrap.anchor_right = 1.0
		badge_wrap.anchor_top = 0.0
		badge_wrap.anchor_bottom = 0.0
		badge_wrap.offset_left = -72.0
		badge_wrap.offset_right = -6.0
		badge_wrap.offset_top = 6.0
		badge_wrap.offset_bottom = 28.0
		badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wrap_style := StyleBoxFlat.new()
		wrap_style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
		wrap_style.set_corner_radius_all(3)
		wrap_style.content_margin_left = 4.0
		wrap_style.content_margin_right = 4.0
		wrap_style.content_margin_top = 1.0
		wrap_style.content_margin_bottom = 1.0
		badge_wrap.add_theme_stylebox_override("panel", wrap_style)
		var badge_label := Label.new()
		badge_label.text = "▶ 动图"
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", 11)
		badge_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_wrap.add_child(badge_label)
		btn.add_child(badge_wrap)

	# 覆盖层：画在最上层，边框/高亮不会被缩略图遮住
	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0)
	ov_style.set_corner_radius_all(4)
	overlay.add_theme_stylebox_override("panel", ov_style)
	btn.add_child(overlay)
	btn.set_meta("overlay", overlay)
	btn.set_meta("selected", false)

	btn.mouse_entered.connect(_on_thumb_hover.bind(btn))
	btn.mouse_exited.connect(_on_thumb_unhover.bind(btn))

	btn.pressed.connect(_on_thumb_clicked.bind(asset_type, url))
	return btn

func _on_thumb_hover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if bool(btn.get_meta("selected", false)):
		return
	if not btn.has_meta("overlay"):
		return
	var ov: Panel = btn.get_meta("overlay")
	if ov == null:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.62, 0.86, 1.0, 0.20)
	s.border_color = Color(0.62, 0.86, 1.0, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	ov.add_theme_stylebox_override("panel", s)

func _on_thumb_unhover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if bool(btn.get_meta("selected", false)):
		return
	if not btn.has_meta("overlay"):
		return
	var ov: Panel = btn.get_meta("overlay")
	if ov == null:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_corner_radius_all(4)
	ov.add_theme_stylebox_override("panel", s)

func _on_thumb_clicked(asset_type: String, url: String) -> void:
	if not _sections.has(asset_type):
		return
	var sec: Dictionary = _sections[asset_type]
	var cards: Dictionary = _thumb_cards.get(asset_type, {})
	for key in cards.keys():
		var c: Button = cards[key]
		if not is_instance_valid(c):
			continue
		c.set_meta("selected", false)
		if not c.has_meta("overlay"):
			continue
		var ov: Panel = c.get_meta("overlay")
		if ov == null:
			continue
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0)
		s.set_corner_radius_all(4)
		ov.add_theme_stylebox_override("panel", s)
	# 高亮选中的
	var sel: Button = cards.get(url, null)
	if sel != null:
		sel.set_meta("selected", true)
		if sel.has_meta("overlay"):
			var sov: Panel = sel.get_meta("overlay")
			if sov != null:
				var ss := StyleBoxFlat.new()
				ss.bg_color = Color(0.88, 0.66, 0.36, 0.15)
				ss.border_color = Color(0.88, 0.66, 0.36, 1.0)
				ss.set_border_width_all(2)
				ss.set_corner_radius_all(4)
				sov.add_theme_stylebox_override("panel", ss)
	sec["selected_url"] = url
	_update_apply_button()

func _update_apply_button() -> void:
	var any: bool = false
	for t in _sections.keys():
		var sec: Dictionary = _sections[t]
		if not str(sec["selected_url"]).is_empty():
			any = true
			break
	_apply_button.disabled = not any

# ---------- 应用 ----------

func _on_apply_pressed() -> void:
	if _selected_sgdb_id <= 0:
		return
	# 立即反馈：禁用按钮 + 提示
	_apply_button.disabled = true
	_apply_button.text = "应用中…"
	_status_label.text = "正在下载大图，请稍候…"
	for t in ASSET_TYPES:
		var sec: Dictionary = _sections.get(t, {})
		var url: String = str(sec.get("selected_url", ""))
		if url.is_empty():
			continue
		apply_requested.emit(_selected_sgdb_id, t, url)

func set_apply_done() -> void:
	_status_label.text = "已应用"
	_apply_button.text = "应用选中"