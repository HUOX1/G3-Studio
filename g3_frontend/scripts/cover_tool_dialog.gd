extends Window
class_name G3CoverToolDialog

signal source_dir_changed(path: String)
signal scan_requested(scope: String, overwrite: bool)
signal apply_all_requested(items: Array)
signal edit_requested(item: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

var _source_field: LineEdit
var _last_saved_source: String = ""
var _summary_label: Label
var _status_label: Label
var _list_vbox: VBoxContainer
var _scan_button: Button
var _apply_button: Button
var _overwrite_check: CheckBox
var _items: Array = []
var _scope: String = "main"

func _ready() -> void:
	title = "封面裁剪工具"
	size = Vector2i(720, 500)
	min_size = Vector2i(600, 440)
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
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "封面裁剪工具"
	heading.add_theme_font_size_override("font_size", 20)
	root.add_child(heading)

	var note := Label.new()
	note.text = "把完整 DVD 封面（Back + Spine + Front）裁出纯 Front，写入 G3 封面目录。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(note)

	# ── 源目录行 ──
	var src_row := HBoxContainer.new()
	src_row.add_theme_constant_override("separation", 8)
	root.add_child(src_row)

	var src_label := Label.new()
	src_label.text = "源封面目录"
	src_label.custom_minimum_size.x = 100.0
	src_row.add_child(src_label)

	_source_field = LineEdit.new()
	_source_field.placeholder_text = "放完整 DVD 封面的文件夹路径"
	_source_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_field.text_submitted.connect(_on_source_field_submitted)
	_source_field.focus_exited.connect(_on_source_field_focus_exited)
	src_row.add_child(_source_field)

	# ── 输出目录提示 ──
	var out_row := HBoxContainer.new()
	out_row.add_theme_constant_override("separation", 8)
	root.add_child(out_row)

	var out_label := Label.new()
	out_label.text = "输出目录"
	out_label.custom_minimum_size.x = 100.0
	out_row.add_child(out_label)

	var out_hint := Label.new()
	out_hint.text = "%LOCALAPPDATA%\\G3\\covers\\movies"
	out_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out_hint.add_theme_color_override("font_color", Color(0.55, 0.60, 0.62))
	out_row.add_child(out_hint)

	# ── 操作行 ──
	var op_row := HBoxContainer.new()
	op_row.add_theme_constant_override("separation", 10)
	root.add_child(op_row)

	_scan_button = Button.new()
	_scan_button.text = "扫描"
	_scan_button.custom_minimum_size = Vector2(120.0, 34.0)
	_scan_button.pressed.connect(_on_scan_pressed)
	op_row.add_child(_scan_button)

	_apply_button = Button.new()
	_apply_button.text = "全部应用"
	_apply_button.custom_minimum_size = Vector2(120.0, 34.0)
	_apply_button.disabled = true
	_apply_button.pressed.connect(_on_apply_all_pressed)
	op_row.add_child(_apply_button)

	_overwrite_check = CheckBox.new()
	_overwrite_check.text = "覆盖已有正式封面"
	op_row.add_child(_overwrite_check)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	op_row.add_child(_status_label)

	# ── 列表 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 2)
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_vbox)

	# ── 统计 ──
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 12)
	_summary_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(_summary_label)

	# ── 底部按钮 ──
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(hide)
	bottom.add_child(close_btn)

	TEXT_MENU_LOCALIZER.localize_tree(self)

func show_for(scope: String, source_dir: String) -> void:
	_scope = scope
	_source_field.text = source_dir
	_last_saved_source = source_dir
	_clear_list()
	_summary_label.text = ""
	_status_label.text = ""
	_apply_button.disabled = true
	_items.clear()
	popup_centered()

func set_source_dir(path: String) -> void:
	_source_field.text = path
	_last_saved_source = path

func set_scan_running() -> void:
	_scan_button.disabled = true
	_status_label.text = "正在扫描…"
	_clear_list()
	_summary_label.text = ""

func show_scan_results(items: Array) -> void:
	_scan_button.disabled = false
	_status_label.text = ""
	_items = items
	_clear_list()

	var counts := {"auto_ok": 0, "needs_review": 0, "has_cover": 0, "not_found": 0, "error": 0}
	var apply_count := 0

	for raw in items:
		if not (raw is Dictionary):
			continue
		var it: Dictionary = raw
		var st: String = str(it.get("status", ""))
		if counts.has(st):
			counts[st] += 1
		if st == "auto_ok":
			apply_count += 1
		_add_row(it)

	_summary_label.text = "总计 %d · 可自动 %d · 待复核 %d · 已有封面 %d · 未找到 %d · 错误 %d" % [
		items.size(),
		counts["auto_ok"],
		counts["needs_review"],
		counts["has_cover"],
		counts["not_found"],
		counts["error"],
	]
	_apply_button.disabled = apply_count == 0

func show_apply_progress(done: int, total: int) -> void:
	_status_label.text = "应用 %d / %d" % [done, total]

func show_apply_done(written: int, failed: int) -> void:
	if failed == 0:
		_status_label.text = "完成 · 已写入 %d 张" % written
	else:
		_status_label.text = "完成 · 写入 %d 张，失败 %d 张" % [written, failed]

func _clear_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()

func _add_row(item: Dictionary) -> void:
	var status: String = str(item.get("status", ""))
	var title: String = str(item.get("matched_title", ""))
	var filename: String = str(item.get("filename", ""))
	var reason: String = str(item.get("reason", ""))
	var fw: int = int(item.get("front_start_px", 0))
	var w: int = int(item.get("width", 0))
	var h: int = int(item.get("height", 0))

	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.11, 0.55)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	row.add_theme_stylebox_override("panel", style)
	_list_vbox.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var status_colors := {
		"auto_ok": Color(0.40, 0.85, 0.55),
		"needs_review": Color(0.95, 0.75, 0.35),
		"has_cover": Color(0.55, 0.75, 0.95),
		"not_found": Color(0.55, 0.58, 0.60),
		"error": Color(0.95, 0.45, 0.45),
	}
	var status_text := {
		"auto_ok": "可自动",
		"needs_review": "待复核",
		"has_cover": "已有封面",
		"not_found": "未找到",
		"error": "错误",
	}
	var sc: Color = status_colors.get(status, Color.WHITE)
	var st_text: String = status_text.get(status, status)

	var status_lbl := Label.new()
	status_lbl.text = st_text
	status_lbl.custom_minimum_size.x = 80.0
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", sc)
	hbox.add_child(status_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.custom_minimum_size.x = 180.0
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(title_lbl)

	var file_lbl := Label.new()
	file_lbl.text = filename if not filename.is_empty() else "—"
	file_lbl.custom_minimum_size.x = 180.0
	file_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_lbl.add_theme_font_size_override("font_size", 12)
	file_lbl.add_theme_color_override("font_color", Color(0.70, 0.74, 0.76))
	hbox.add_child(file_lbl)

	var size_lbl := Label.new()
	if w > 0:
		size_lbl.text = "%dx%d · Front %d" % [w, h, fw]
	else:
		size_lbl.text = "—"
	size_lbl.custom_minimum_size.x = 160.0
	size_lbl.add_theme_font_size_override("font_size", 12)
	size_lbl.add_theme_color_override("font_color", Color(0.70, 0.74, 0.76))
	hbox.add_child(size_lbl)

	var reason_lbl := Label.new()
	reason_lbl.text = reason
	reason_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason_lbl.add_theme_font_size_override("font_size", 12)
	reason_lbl.add_theme_color_override("font_color", Color(0.62, 0.66, 0.68))
	hbox.add_child(reason_lbl)

	# 有源封面的行都能"调整"（包括已有封面的）
	var file_path: String = str(item.get("file_path", ""))
	if not file_path.is_empty():
		var edit_btn := Button.new()
		edit_btn.text = "调整"
		edit_btn.custom_minimum_size = Vector2(60.0, 26.0)
		edit_btn.pressed.connect(func(): edit_requested.emit(item))
		hbox.add_child(edit_btn)

func _on_source_field_submitted(new_text: String) -> void:
	var clean: String = new_text.strip_edges()
	if clean == _last_saved_source:
		return
	_last_saved_source = clean
	source_dir_changed.emit(clean)

func _on_source_field_focus_exited() -> void:
	_on_source_field_submitted(_source_field.text)

func _on_scan_pressed() -> void:
	scan_requested.emit(_scope, _overwrite_check.button_pressed)

func _on_apply_all_pressed() -> void:
	if _items.is_empty():
		return
	# 只把 auto_ok 的交给 main
	var to_apply: Array = []
	for it in _items:
		if it is Dictionary and str(it.get("status", "")) == "auto_ok":
			to_apply.append(it)
	apply_all_requested.emit(to_apply)