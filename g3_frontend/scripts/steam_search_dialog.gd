extends Window
class_name G3SteamSearchDialog

signal search_requested(query: String)
signal apply_requested(item_id: String, external_id: int)

var _item_id: String = ""
var _target_title: String = ""

var _query_field: LineEdit
var _status_label: Label
var _results_list: VBoxContainer
var _apply_button: Button
var _selected_external_id: int = 0
var _selected_rows: Dictionary = {}

func _ready() -> void:
	title = "从 Steam 获取资料"
	size = Vector2i(620, 620)
	min_size = Vector2i(520, 500)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "从 Steam 获取资料"
	heading.add_theme_font_size_override("font_size", 20)
	root.add_child(heading)

	var note := Label.new()
	note.text = "输入英文名搜索 Steam 商店。找到后点击选中，再点应用。只填空字段，不覆盖你手填的内容。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(note)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	root.add_child(search_row)

	_query_field = LineEdit.new()
	_query_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query_field.placeholder_text = "英文名，例如 Rain World"
	_query_field.text_submitted.connect(func(_t): _on_search_pressed())
	search_row.add_child(_query_field)

	var search_button := Button.new()
	search_button.text = "搜索"
	search_button.pressed.connect(_on_search_pressed)
	search_row.add_child(search_button)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_results_list = VBoxContainer.new()
	_results_list.add_theme_constant_override("separation", 4)
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_results_list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(hide)
	buttons.add_child(cancel_button)

	_apply_button = Button.new()
	_apply_button.text = "应用"
	_apply_button.disabled = true
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)

func show_for(item_id: String, title_text: String) -> void:
	_item_id = item_id
	_target_title = title_text
	_query_field.text = title_text
	_clear_results()
	_status_label.text = "点「搜索」开始"
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	_apply_button.disabled = true
	_apply_button.text = "应用"
	_selected_external_id = 0
	popup_centered()

func _on_search_pressed() -> void:
	var q: String = _query_field.text.strip_edges()
	if q.is_empty():
		_status_label.text = "请输入搜索词"
		return
	_clear_results()
	_selected_external_id = 0
	_apply_button.disabled = true
	_status_label.text = "搜索中…"
	search_requested.emit(q)

func show_results(results: Array) -> void:
	_clear_results()
	if results.is_empty():
		_status_label.text = "没找到。换英文名再试"
		return
	_status_label.text = "找到 %d 条结果，点击选中后应用" % results.size()
	for raw in results:
		if raw is Dictionary:
			_results_list.add_child(_make_result_row(raw as Dictionary))

func _clear_results() -> void:
	for c in _results_list.get_children():
		c.queue_free()
	_selected_rows.clear()

func _make_result_row(hit: Dictionary) -> Button:
	var ext_id: int = int(hit.get("external_id", 0))
	var name: String = str(hit.get("name", ""))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.04, 0.08, 0.11, 0.65)
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_right = 12.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_bottom = 8.0

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.06, 0.12, 0.16, 0.80)
	hover_style.set_corner_radius_all(6)
	hover_style.border_color = Color(0.55, 0.78, 0.95, 0.55)
	hover_style.set_border_width_all(1)
	hover_style.content_margin_left = 12.0
	hover_style.content_margin_right = 12.0
	hover_style.content_margin_top = 8.0
	hover_style.content_margin_bottom = 8.0

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.20, 0.14, 0.06, 0.85)
	selected_style.set_corner_radius_all(6)
	selected_style.border_color = Color(0.88, 0.66, 0.36, 0.75)
	selected_style.set_border_width_all(1)
	selected_style.content_margin_left = 12.0
	selected_style.content_margin_right = 12.0
	selected_style.content_margin_top = 8.0
	selected_style.content_margin_bottom = 8.0

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	var title_label := Label.new()
	title_label.text = "%s    [Steam %d]" % [name, ext_id]
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.offset_left = 12.0
	title_label.offset_right = -12.0
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(title_label)

	btn.set_meta("normal_style", normal_style)
	btn.set_meta("hover_style", hover_style)
	btn.set_meta("selected_style", selected_style)
	btn.pressed.connect(_on_result_clicked.bind(ext_id, btn))
	_selected_rows[ext_id] = btn
	return btn

func _on_result_clicked(ext_id: int, btn: Button) -> void:
	for other_id in _selected_rows.keys():
		var b: Button = _selected_rows[other_id]
		if int(other_id) == ext_id:
			continue
		var normal_s: StyleBox = b.get_meta("normal_style")
		var hover_s: StyleBox = b.get_meta("hover_style")
		b.add_theme_stylebox_override("normal", normal_s)
		b.add_theme_stylebox_override("hover", hover_s)
		b.add_theme_stylebox_override("pressed", hover_s)
	var selected_s: StyleBox = btn.get_meta("selected_style")
	btn.add_theme_stylebox_override("normal", selected_s)
	btn.add_theme_stylebox_override("hover", selected_s)
	btn.add_theme_stylebox_override("pressed", selected_s)
	_selected_external_id = ext_id
	_apply_button.disabled = false

func _on_apply_pressed() -> void:
	if _selected_external_id <= 0:
		return
	_apply_button.disabled = true
	_apply_button.text = "应用中…"
	_status_label.text = "正在下载素材，约 10~20 秒…"
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.55))
	apply_requested.emit(_item_id, _selected_external_id)

func set_apply_ok() -> void:
	_status_label.text = "✓ 已应用，可以关闭窗口"
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
	_apply_button.text = "应用"
	_apply_button.disabled = false

func set_apply_failed(reason: String) -> void:
	_status_label.text = "✗ 失败：" + reason
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_apply_button.text = "重试"
	_apply_button.disabled = false