extends Window
class_name G3EmulatorEditDialog

signal save_requested(payload: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

const DEFAULT_PLACEHOLDER: String = "{content}"

var _item_id: String = ""
var _pending_changes: Dictionary = {}

var _name_field: LineEdit
var _executable_field: LineEdit
var _working_dir_field: LineEdit
var _args_field: LineEdit
var _placeholder_field: LineEdit
var _platform_option: OptionButton
var _scan_list: VBoxContainer
var _empty_label: Label
var _error_label: Label

var _platforms: Array[String] = []
var _scan_dirs: Array[String] = []

var _executable_dialog: FileDialog
var _working_dir_dialog: FileDialog
var _scan_dir_dialog: FileDialog

var _warn_dialog: ConfirmationDialog

func _ready() -> void:
	hide()
	title = "模拟器配置"
	size = Vector2i(720, 660)
	min_size = Vector2i(580, 520)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	_build_file_dialogs()
	_build_warn_dialog()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	call_deferred("_localize_context_menus")

func set_platforms(arr: Array[String]) -> void:
	_platforms = arr

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "例如：RPCS3"
	_add_control_row(root, "名称", _name_field)

	_executable_field = LineEdit.new()
	_executable_field.placeholder_text = "模拟器 exe 完整路径"
	_add_path_row(root, "启动 EXE", _executable_field, func(): _open_picker("executable"))

	_working_dir_field = LineEdit.new()
	_working_dir_field.placeholder_text = "留空则用 exe 所在目录"
	_add_path_row(root, "工作目录", _working_dir_field, func(): _open_picker("working"))

	_args_field = LineEdit.new()
	_args_field.placeholder_text = "例如：-g \"{content}\""
	_add_control_row(root, "默认参数", _args_field)

	var hint_panel := PanelContainer.new()
	hint_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(hint_panel)
	# 内边距由 MarginContainer 负责，Label 本身没有 margin 属性
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 10)
	hint_margin.add_theme_constant_override("margin_top", 6)
	hint_margin.add_theme_constant_override("margin_right", 10)
	hint_margin.add_theme_constant_override("margin_bottom", 6)
	hint_panel.add_child(hint_margin)
	var hint := Label.new()
	hint.text = "{content} 会替换为游戏文件路径；默认参数里没写占位符时，模拟器启动会自动追加内容路径。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint_margin.add_child(hint)

	_placeholder_field = LineEdit.new()
	_placeholder_field.placeholder_text = DEFAULT_PLACEHOLDER
	_add_control_row(root, "占位符", _placeholder_field)

	var platform_row := HBoxContainer.new()
	platform_row.add_theme_constant_override("separation", 12)
	root.add_child(platform_row)
	var platform_label := Label.new()
	platform_label.text = "平台标签"
	platform_label.custom_minimum_size = Vector2(90.0, 0.0)
	platform_row.add_child(platform_label)
	_platform_option = OptionButton.new()
	_platform_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_platform_option.fit_to_longest_item = false
	platform_row.add_child(_platform_option)

	var scan_label := Label.new()
	scan_label.text = "扫描目录"
	root.add_child(scan_label)

	_scan_list = VBoxContainer.new()
	_scan_list.add_theme_constant_override("separation", 4)
	_scan_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_scan_list)

	_empty_label = Label.new()
	_empty_label.text = "（尚未添加扫描目录）"
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70))
	_scan_list.add_child(_empty_label)

	var add_dir_btn := Button.new()
	add_dir_btn.text = "+ 添加目录"
	add_dir_btn.custom_minimum_size = Vector2(200.0, 32.0)
	add_dir_btn.pressed.connect(func(): _open_picker("scan"))
	root.add_child(add_dir_btn)

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

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_submit)
	buttons.add_child(save_button)

func _add_control_row(root: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func _add_path_row(
	root: VBoxContainer, label_text: String, field: LineEdit, callback: Callable
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var browse := Button.new()
	browse.text = "浏览…"
	browse.pressed.connect(callback)
	row.add_child(browse)

func _build_file_dialogs() -> void:
	_executable_dialog = _make_file_dialog(
		PackedStringArray(["*.exe ; 可执行文件", "* ; 所有文件"])
	)
	_executable_dialog.file_selected.connect(func(p): _executable_field.text = p)
	add_child(_executable_dialog)

	_working_dir_dialog = FileDialog.new()
	_working_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_working_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_working_dir_dialog.size = Vector2i(800, 560)
	_working_dir_dialog.dir_selected.connect(func(p): _working_dir_field.text = p)
	add_child(_working_dir_dialog)

	_scan_dir_dialog = FileDialog.new()
	_scan_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_scan_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_scan_dir_dialog.size = Vector2i(800, 560)
	_scan_dir_dialog.dir_selected.connect(_on_scan_dir_selected)
	add_child(_scan_dir_dialog)

func _make_file_dialog(filters: PackedStringArray) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.size = Vector2i(800, 560)
	return dialog

func _build_warn_dialog() -> void:
	_warn_dialog = ConfirmationDialog.new()
	_warn_dialog.title = "模拟器配置"
	_warn_dialog.ok_button_text = "仍然保存"
	_warn_dialog.cancel_button_text = "返回修改"
	_warn_dialog.confirmed.connect(_emit_save)
	add_child(_warn_dialog)

func _open_picker(target: String) -> void:
	match target:
		"executable":
			_executable_dialog.popup_centered_ratio(0.82)
		"working":
			_working_dir_dialog.popup_centered_ratio(0.82)
		"scan":
			_scan_dir_dialog.popup_centered_ratio(0.82)

# ---------------------------------------------------------------------------
# 对外

func show_new() -> void:
	_item_id = ""
	_pending_changes = {}
	_name_field.text = ""
	_executable_field.text = ""
	_working_dir_field.text = ""
	_args_field.text = ""
	_placeholder_field.text = DEFAULT_PLACEHOLDER
	_scan_dirs.clear()
	_rebuild_scan_list()
	_rebuild_platforms("")
	_finish_show("添加模拟器")

func show_emulator(emulator: Dictionary) -> void:
	_item_id = str(emulator.get("id", ""))
	_pending_changes = {}
	_name_field.text = str(emulator.get("name", ""))
	_executable_field.text = str(emulator.get("executable", ""))
	_working_dir_field.text = str(emulator.get("working_dir", ""))
	_args_field.text = str(emulator.get("default_args", ""))
	var placeholder: String = str(emulator.get("content_placeholder", "")).strip_edges()
	_placeholder_field.text = placeholder if not placeholder.is_empty() else DEFAULT_PLACEHOLDER
	_scan_dirs.clear()
	var raw_dirs: Variant = emulator.get("scan_dirs", [])
	if raw_dirs is Array:
		for entry in (raw_dirs as Array):
			var path: String = _clean_path(str(entry))
			if not path.is_empty() and not _scan_dirs.has(path):
				_scan_dirs.append(path)
	_rebuild_scan_list()
	_rebuild_platforms(str(emulator.get("platform_tag", "")))
	_finish_show("编辑模拟器")

func _finish_show(dialog_title: String) -> void:
	title = dialog_title
	_error_label.visible = false

	# 自适应父窗口尺寸
	var parent_win: Window = null
	if get_parent() != null:
		parent_win = get_parent().get_window()
	if parent_win != null:
		var target_w: int = mini(720, maxi(580, parent_win.size.x - 80))
		var target_h: int = mini(660, maxi(520, parent_win.size.y - 80))
		size = Vector2i(target_w, target_h)
	popup_centered()

# ---------------------------------------------------------------------------
# 内部

func _clean_path(value: String) -> String:
	return value.strip_edges().replace("\\", "/")

func _rebuild_platforms(current: String) -> void:
	var options: Array[String] = _platforms
	_platform_option.clear()
	_platform_option.add_item("（不指定）")
	for p in options:
		_platform_option.add_item(p)
	_platform_option.select(0)
	var clean: String = current.strip_edges()
	if clean.is_empty():
		return
	var idx: int = options.find(clean)
	if idx >= 0:
		_platform_option.select(idx + 1)
	else:
		# 库里存的平台不在候选表里：追加一项，避免保存时被改写
		_platform_option.add_item(clean)
		_platform_option.select(_platform_option.item_count - 1)

func _rebuild_scan_list() -> void:
	for child in _scan_list.get_children():
		if child != _empty_label:
			_scan_list.remove_child(child)
			child.queue_free()
	_empty_label.visible = _scan_dirs.is_empty()
	for i in range(_scan_dirs.size()):
		_scan_list.add_child(_make_scan_row(i, _scan_dirs[i]))

func _make_scan_row(index: int, path: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = path
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var remove_btn := Button.new()
	remove_btn.text = "移除"
	remove_btn.custom_minimum_size = Vector2(72.0, 28.0)
	remove_btn.pressed.connect(_on_remove_scan_dir.bind(index))
	row.add_child(remove_btn)
	return row

func _on_scan_dir_selected(path: String) -> void:
	var clean: String = _clean_path(path)
	if clean.is_empty():
		return
	if not _scan_dirs.has(clean):
		_scan_dirs.append(clean)
	_rebuild_scan_list()

func _on_remove_scan_dir(index: int) -> void:
	if index < 0 or index >= _scan_dirs.size():
		return
	_scan_dirs.remove_at(index)
	_rebuild_scan_list()

func _build_payload() -> Dictionary:
	var platform_text: String = ""
	if _platform_option.selected > 0 and _platform_option.selected < _platform_option.item_count:
		platform_text = _platform_option.get_item_text(_platform_option.selected)
	var placeholder: String = _placeholder_field.text.strip_edges()
	if placeholder.is_empty():
		placeholder = DEFAULT_PLACEHOLDER
	return {
		"id": _item_id,
		"name": _name_field.text.strip_edges(),
		"executable": _clean_path(_executable_field.text),
		"working_dir": _clean_path(_working_dir_field.text),
		"default_args": _args_field.text.strip_edges(),
		"content_placeholder": placeholder,
		"scan_dirs": _scan_dirs.duplicate(),
		"platform_tag": platform_text,
		"icon_path": "",
	}

func _submit() -> void:
	var payload: Dictionary = _build_payload()
	if str(payload.get("name", "")).is_empty():
		_show_error("请输入模拟器名称")
		return
	if str(payload.get("executable", "")).is_empty():
		# 不强制拦截：提示一次，允许继续保存
		_pending_changes = payload
		_warn_dialog.dialog_text = (
			"未配置启动 EXE，保存后需手动补上才能启动游戏。\n\n"
			+ "确定要现在保存吗？"
		)
		_warn_dialog.popup_centered()
		return
	_emit_payload(payload)

func _emit_save() -> void:
	if _pending_changes.is_empty():
		return
	_emit_payload(_pending_changes)

func _emit_payload(payload: Dictionary) -> void:
	_pending_changes = {}
	save_requested.emit(payload)
	hide()

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true

func _localize_context_menus() -> void:
	TEXT_MENU_LOCALIZER.localize_tree(self)
