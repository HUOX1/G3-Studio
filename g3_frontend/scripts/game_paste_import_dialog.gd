extends Window
class_name G3GamePasteImportDialog

signal apply_requested(payload: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

var _paste_edit: TextEdit
var _preview_list: VBoxContainer
var _error_label: Label
var _apply_btn: Button
var _target_item_id: String = ""
var _parsed: Dictionary = {}

func _ready() -> void:
	title = "粘贴游戏资料"
	size = Vector2i(720, 660)
	min_size = Vector2i(560, 520)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "粘贴游戏资料"
	heading.add_theme_font_size_override("font_size", 20)
	root.add_child(heading)

	var note := Label.new()
	note.text = "把 AI 整理好的游戏资料贴到下面。识别「标题：」「年份：」「开发商：」这类前缀。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(note)

	_paste_edit = TextEdit.new()
	_paste_edit.custom_minimum_size = Vector2(0, 220)
	_paste_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_paste_edit.placeholder_text = "标题：战神\n英文名：God of War\n年份：2005\n开发商：SCE Santa Monica\n发行商：Sony\n类型：动作, 冒险\n简介：..."
	_paste_edit.text_changed.connect(_on_paste_changed)
	root.add_child(_paste_edit)

	var preview_head := Label.new()
	preview_head.text = "识别结果"
	preview_head.add_theme_font_size_override("font_size", 14)
	preview_head.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(preview_head)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_preview_list = VBoxContainer.new()
	_preview_list.add_theme_constant_override("separation", 4)
	_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_preview_list)

	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.52))
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	root.add_child(_error_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(hide)
	buttons.add_child(cancel_button)

	_apply_btn = Button.new()
	_apply_btn.text = "应用"
	_apply_btn.disabled = true
	_apply_btn.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_btn)

func show_new() -> void:
	_target_item_id = ""
	title = "粘贴游戏资料"
	_paste_edit.text = ""
	_parsed.clear()
	_rebuild_preview()
	_error_label.visible = false
	popup_centered()

func show_for_item(item_id: String, current_title: String) -> void:
	_target_item_id = item_id
	title = "粘贴游戏资料 · %s" % current_title
	_paste_edit.text = ""
	_parsed.clear()
	_rebuild_preview()
	_error_label.visible = false
	popup_centered()

func _on_paste_changed() -> void:
	_parsed = _parse_paste_text(_paste_edit.text)
	_rebuild_preview()

func _parse_paste_text(text: String) -> Dictionary:
	var result: Dictionary = {}
	if text.strip_edges().is_empty():
		return result

	# 字段前缀映射（中英文都认）
	var field_map: Dictionary = {
		"标题": "title", "名称": "title", "游戏名": "title", "title": "title",
		"英文名": "english_name", "英文标题": "english_name", "english": "english_name", "english_name": "english_name",
		"年份": "release_year", "发行年份": "release_year", "发售年份": "release_year", "发行日期": "release_date", "发售日期": "release_date", "release": "release_date",
		"开发商": "developer", "开发者": "developer", "developer": "developer",
		"发行商": "publisher", "publisher": "publisher",
		"类型": "genres", "genres": "genres", "genre": "genres",
		"标签": "tags", "tags": "tags",
		"平台": "platform", "platform": "platform",
		"简介": "description", "描述": "description", "介绍": "description", "description": "description",
	}

	var lines: Array = text.split("\n")
	var current_field: String = ""
	var current_value: Array = []

	for raw_line in lines:
		var line: String = str(raw_line)
		# 尝试匹配 "前缀：值" 或 "前缀:值"
		var matched: bool = false
		for prefix in field_map.keys():
			var colon_variants: Array = ["：", ":"]
			for colon in colon_variants:
				var head: String = prefix + colon
				if line.strip_edges().begins_with(head):
					# 收尾上一个字段
					if not current_field.is_empty() and not current_value.is_empty():
						result[current_field] = "\n".join(current_value).strip_edges()
					current_field = str(field_map[prefix])
					current_value = [line.strip_edges().substr(head.length()).strip_edges()]
					matched = true
					break
			if matched:
				break
		if matched:
			continue
		# 没有前缀 → 续上一字段（多行简介）
		if not current_field.is_empty():
			current_value.append(line)

	if not current_field.is_empty() and not current_value.is_empty():
		result[current_field] = "\n".join(current_value).strip_edges()
	return result

func _rebuild_preview() -> void:
	for c in _preview_list.get_children():
		c.queue_free()

	if _parsed.is_empty():
		var empty := Label.new()
		empty.text = "（粘贴后自动识别）"
		empty.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		empty.add_theme_font_size_override("font_size", 12)
		_preview_list.add_child(empty)
		_apply_btn.disabled = true
		return

	var labels: Dictionary = {
		"title": "标题",
		"english_name": "英文名",
		"release_year": "年份",
		"release_date": "发售日期",
		"developer": "开发商",
		"publisher": "发行商",
		"genres": "类型",
		"tags": "标签",
		"platform": "平台",
		"description": "简介",
	}
	var order: Array = ["title", "english_name", "release_year", "release_date",
		"developer", "publisher", "genres", "tags", "platform", "description"]

	for key in order:
		if not _parsed.has(key):
			continue
		var value: String = str(_parsed[key])
		if key == "description" and value.length() > 120:
			value = value.substr(0, 120) + "…"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl_key := Label.new()
		lbl_key.text = str(labels.get(key, key)) + "："
		lbl_key.custom_minimum_size.x = 80.0
		lbl_key.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68))
		lbl_key.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl_key)
		var lbl_val := Label.new()
		lbl_val.text = value
		lbl_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_val.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		lbl_val.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl_val)
		_preview_list.add_child(row)

	var has_title: bool = _parsed.has("title") and not str(_parsed["title"]).strip_edges().is_empty()
	if _target_item_id.is_empty() and not has_title:
		_apply_btn.disabled = true
		_error_label.text = "新建条目需要至少识别到「标题：」"
		_error_label.visible = true
	else:
		_apply_btn.disabled = false
		_error_label.visible = false

func _on_apply_pressed() -> void:
	if _parsed.is_empty():
		return
	_parsed["target_item_id"] = _target_item_id
	apply_requested.emit(_parsed)
	hide()