extends Window
class_name G3GameLaunchDialog

signal save_requested(item_id: String, profile: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

const PROFILE_TYPES: Array[String] = ["direct", "emulator", "launcher"]

var _item_id: String = ""

var _profile_option: OptionButton
var _launch_exe_row: HBoxContainer
var _launch_exe_field: LineEdit
var _content_row: HBoxContainer
var _content_path_field: LineEdit
var _args_row: HBoxContainer
var _args_field: LineEdit
var _working_row: HBoxContainer
var _working_field: LineEdit
var _monitor_row: HBoxContainer
var _monitor_field: LineEdit
var _admin_check: CheckBox
var _error_label: Label

var _launch_exe_dialog: FileDialog
var _content_dialog: FileDialog
var _working_dir_dialog: FileDialog
var _monitor_dialog: FileDialog

func _ready() -> void:
	hide()
	title = "编辑启动设置"
	size = Vector2i(720, 560)
	min_size = Vector2i(560, 460)
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
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	var note := Label.new()
	note.text = "选择启动类型。直接启动 = 游戏自带的 exe；模拟器 = 选模拟器 exe + ROM；启动器 = 通过 launcher 启动。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(note)

	# 启动类型
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 12)
	root.add_child(profile_row)
	var profile_label := Label.new()
	profile_label.text = "启动类型"
	profile_label.custom_minimum_size = Vector2(100.0, 0.0)
	profile_row.add_child(profile_label)
	_profile_option = OptionButton.new()
	_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_option.fit_to_longest_item = false
	_profile_option.add_item("直接启动（游戏 EXE）")
	_profile_option.add_item("模拟器")
	_profile_option.add_item("启动器")
	_profile_option.item_selected.connect(_on_profile_changed)
	profile_row.add_child(_profile_option)

	# 启动 EXE（emulator / launcher 必填）
	_launch_exe_row = _make_path_row("启动 EXE", func(): _open_picker("launch_exe"))
	_launch_exe_field = _launch_exe_row.get_meta("field")
	root.add_child(_launch_exe_row)

	# 内容路径（emulator 必填）
	_content_row = _make_path_row("内容路径", func(): _open_picker("content"))
	_content_path_field = _content_row.get_meta("field")
	root.add_child(_content_row)

	# 启动参数
	_args_row = HBoxContainer.new()
	_args_row.add_theme_constant_override("separation", 12)
	root.add_child(_args_row)
	var args_label := Label.new()
	args_label.text = "启动参数"
	args_label.custom_minimum_size = Vector2(100.0, 0.0)
	_args_row.add_child(args_label)
	_args_field = LineEdit.new()
	_args_field.placeholder_text = "例：--fullscreen 或 -L \"{content}\""
	_args_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_args_row.add_child(_args_field)

	var args_hint := Label.new()
	args_hint.text = "提示：{content} 会被替换为「内容路径」。模拟器如果没写 {content}，会自动追加内容路径。"
	args_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	args_hint.add_theme_font_size_override("font_size", 11)
	args_hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.65))
	root.add_child(args_hint)

	# 工作目录
	_working_row = _make_path_row("工作目录", func(): _open_picker("working"))
	_working_field = _working_row.get_meta("field")
	root.add_child(_working_row)

	# 监视 EXE
	_monitor_row = _make_path_row("监视 EXE", func(): _open_picker("monitor"))
	_monitor_field = _monitor_row.get_meta("field")
	root.add_child(_monitor_row)

	var monitor_hint := Label.new()
	monitor_hint.text = "提示：如果启动后拿不到进程句柄（如管理员启动、启动器退出），会用这个 EXE 名轮询判断游戏是否结束。留空则自动用「启动 EXE」的名字。"
	monitor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monitor_hint.add_theme_font_size_override("font_size", 11)
	monitor_hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.65))
	root.add_child(monitor_hint)

	_admin_check = CheckBox.new()
	_admin_check.text = "以管理员身份启动"
	root.add_child(_admin_check)

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

	_on_profile_changed(0)

func _on_profile_changed(idx: int) -> void:
	var is_direct: bool = (idx == 0)
	var is_emulator: bool = (idx == 1)
	var is_launcher: bool = (idx == 2)
	# 直接启动也需要选 EXE 路径（方便换位置后重新指定）
	_launch_exe_row.visible = true
	_content_row.visible = is_emulator
	_args_row.visible = not is_direct
	_working_row.visible = not is_direct
	_monitor_row.visible = true
	_admin_check.visible = not is_direct

func _make_path_row(label_text: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100.0, 0.0)
	row.add_child(label)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var browse := Button.new()
	browse.text = "浏览…"
	browse.pressed.connect(callback)
	row.add_child(browse)
	row.set_meta("field", field)
	return row

func _build_file_dialogs() -> void:
	_launch_exe_dialog = _make_file_dialog(PackedStringArray(["*.exe ; 可执行文件", "* ; 所有文件"]))
	_launch_exe_dialog.file_selected.connect(func(p): _launch_exe_field.text = p)
	add_child(_launch_exe_dialog)

	_content_dialog = _make_file_dialog(PackedStringArray([
		"*.iso ; 镜像", "*.cue ; CUE", "*.bin ; BIN", "*.chd ; CHD",
		"*.zip ; 压缩包", "*.7z ; 压缩包",
		"* ; 所有文件",
	]))
	_content_dialog.file_mode = FileDialog.FILE_MODE_OPEN_ANY
	_content_dialog.file_selected.connect(func(p): _content_path_field.text = p)
	_content_dialog.dir_selected.connect(func(p): _content_path_field.text = p)
	add_child(_content_dialog)

	_working_dir_dialog = FileDialog.new()
	_working_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_working_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_working_dir_dialog.size = Vector2i(800, 560)
	_working_dir_dialog.dir_selected.connect(func(p): _working_field.text = p)
	add_child(_working_dir_dialog)

	_monitor_dialog = _make_file_dialog(PackedStringArray(["*.exe ; 可执行文件", "* ; 所有文件"]))
	_monitor_dialog.file_selected.connect(func(p): _monitor_field.text = p)
	add_child(_monitor_dialog)

func _make_file_dialog(filters: PackedStringArray) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.size = Vector2i(800, 560)
	return dialog

func _open_picker(target: String) -> void:
	match target:
		"launch_exe":
			_launch_exe_dialog.popup_centered_ratio(0.82)
		"content":
			_content_dialog.popup_centered_ratio(0.82)
		"working":
			_working_dir_dialog.popup_centered_ratio(0.82)
		"monitor":
			_monitor_dialog.popup_centered_ratio(0.82)

func show_profile(item_id: String, profile: Dictionary) -> void:
	_item_id = item_id
	_error_label.visible = false
	var launch_exe_text: String = str(profile.get("launch_exe", ""))
	# 如果 launch_exe 是空的，但它是 direct 类型，就把 source_path 填进去
	if launch_exe_text.is_empty() and str(profile.get("profile_type", "direct")) == "direct":
		launch_exe_text = str(profile.get("source_path", ""))
	_launch_exe_field.text = launch_exe_text
	_content_path_field.text = str(profile.get("content_path", ""))
	_args_field.text = str(profile.get("launch_args", ""))
	_working_field.text = str(profile.get("working_directory", ""))
	_monitor_field.text = str(profile.get("monitor_exe", ""))
	_admin_check.button_pressed = bool(profile.get("run_as_admin", false))
	_profile_option.select(_index_for_profile(str(profile.get("profile_type", "direct"))))
	_on_profile_changed(_profile_option.selected)

	# 自适应父窗口尺寸
	var parent_win: Window = null
	if get_parent() != null:
		parent_win = get_parent().get_window()
	if parent_win != null:
		var target_w: int = mini(720, maxi(560, parent_win.size.x - 80))
		var target_h: int = mini(560, maxi(460, parent_win.size.y - 80))
		size = Vector2i(target_w, target_h)
	popup_centered()

func _index_for_profile(profile_type: String) -> int:
	var idx: int = PROFILE_TYPES.find(profile_type.strip_edges().to_lower())
	return idx if idx >= 0 else 0

func _submit() -> void:
	var p_type: String = "direct"
	if _profile_option.selected >= 0 and _profile_option.selected < PROFILE_TYPES.size():
		p_type = PROFILE_TYPES[_profile_option.selected]

	var launch_exe: String = _launch_exe_field.text.strip_edges()
	var content_path: String = _content_path_field.text.strip_edges()

	if p_type == "direct" and launch_exe.is_empty():
		_show_error("直接启动需要选择游戏 EXE")
		return

	save_requested.emit(
		_item_id,
		{
			"profile_type": p_type,
			"launch_exe": launch_exe,
			"launch_args": _args_field.text.strip_edges(),
			"working_directory": _working_field.text.strip_edges(),
			"content_path": content_path,
			"monitor_exe": _monitor_field.text.strip_edges(),
			"run_as_admin": _admin_check.button_pressed,
		}
	)
	hide()

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true

func _localize_context_menus() -> void:
	TEXT_MENU_LOCALIZER.localize_tree(self)
