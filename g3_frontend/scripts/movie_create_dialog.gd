extends Window
class_name G3MovieCreateDialog

signal create_requested(payload: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

var _title_field: LineEdit
var _video_path: LineEdit
var _cover_label: Label
var _cover_source: String = ""
var _year_field: LineEdit
var _description: TextEdit
var _error_label: Label

var _video_dialog: FileDialog
var _cover_dialog: FileDialog

func _ready() -> void:
	hide()
	title = "添加电影"
	size = Vector2i(760, 660)
	min_size = Vector2i(680, 580)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	_build_file_dialogs()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	call_deferred("_localize_context_menus")

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "添加电影"
	heading.add_theme_font_size_override("font_size", 22)
	root.add_child(heading)

	var note := Label.new()
	note.text = "填写标题并选择视频文件。之后可在右键菜单中修改资料、更换封面。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(note)

	_title_field = LineEdit.new()
	_title_field.placeholder_text = "例如：银翼杀手 1982"
	_add_control_row(root, "标题 *", _title_field)

	_video_path = LineEdit.new()
	_add_path_row(root, "视频文件 *", _video_path, _open_video_dialog)

	_add_cover_row(root)

	_year_field = LineEdit.new()
	_year_field.placeholder_text = "例如 1982，可留空"
	_add_control_row(root, "年份", _year_field)

	var desc_label := Label.new()
	desc_label.text = "简介"
	root.add_child(desc_label)

	_description = TextEdit.new()
	_description.custom_minimum_size = Vector2(0, 130)
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(_description)

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

	var create_button := Button.new()
	create_button.text = "添加"
	create_button.pressed.connect(_submit)
	buttons.add_child(create_button)

func _add_control_row(root: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func _add_path_row(root: VBoxContainer, label_text: String, field: LineEdit, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100.0, 0.0)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var browse := Button.new()
	browse.text = "浏览…"
	browse.pressed.connect(callback)
	row.add_child(browse)

func _add_cover_row(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var label := Label.new()
	label.text = "封面"
	label.custom_minimum_size = Vector2(100.0, 0.0)
	row.add_child(label)
	_cover_label = Label.new()
	_cover_label.text = "未选择"
	_cover_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_cover_label.add_theme_color_override("font_color", Color(0.68, 0.80, 0.82))
	_cover_label.add_theme_font_size_override("font_size", 12)
	_cover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_cover_label)
	var browse := Button.new()
	browse.text = "选择…"
	browse.pressed.connect(_open_cover_dialog)
	row.add_child(browse)
	var clear := Button.new()
	clear.text = "清除"
	clear.pressed.connect(func():
		_cover_source = ""
		_cover_label.text = "未选择"
	)
	row.add_child(clear)

func _build_file_dialogs() -> void:
	_video_dialog = _make_file_dialog(PackedStringArray([
		"*.mp4 ; MP4", "*.mkv ; MKV", "*.avi ; AVI", "*.mov ; MOV",
		"*.wmv ; WMV", "*.m4v ; M4V", "*.ts ; TS", "*.webm ; WebM",
		"* ; 所有文件",
	]))
	_video_dialog.file_selected.connect(func(p): _video_path.text = p)
	add_child(_video_dialog)

	_cover_dialog = _make_file_dialog(PackedStringArray([
		"*.jpg ; JPEG", "*.jpeg ; JPEG", "*.png ; PNG",
		"*.webp ; WebP", "*.bmp ; BMP",
	]))
	_cover_dialog.file_selected.connect(_on_cover_selected)
	add_child(_cover_dialog)

func _make_file_dialog(filters: PackedStringArray) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.size = Vector2i(900, 620)
	return dialog

func _open_video_dialog() -> void:
	_video_dialog.popup_centered_ratio(0.82)

func _open_cover_dialog() -> void:
	_cover_dialog.popup_centered_ratio(0.82)

func _on_cover_selected(path: String) -> void:
	_cover_source = path
	_cover_label.text = path.get_file()

func show_dialog() -> void:
	_title_field.text = ""
	_video_path.text = ""
	_cover_source = ""
	_cover_label.text = "未选择"
	_year_field.text = ""
	_description.text = ""
	_error_label.visible = false
	popup_centered()

func _submit() -> void:
	var title_text: String = _title_field.text.strip_edges()
	var video_text: String = _video_path.text.strip_edges()

	if title_text.is_empty():
		_show_error("请输入电影标题")
		return
	if video_text.is_empty():
		_show_error("请选择视频文件")
		return

	var payload: Dictionary = {
		"title": title_text,
		"video_path": video_text,
		"cover_source": _cover_source,
		"release_year": _year_field.text.strip_edges(),
		"description": _description.text.strip_edges(),
	}
	create_requested.emit(payload)
	hide()

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true

func _localize_context_menus() -> void:
	TEXT_MENU_LOCALIZER.localize_tree(self)