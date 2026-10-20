extends Window
class_name G3GameCreateDialog

signal create_requested(payload: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

var _title_field: LineEdit
var _english_name_field: LineEdit
var _platform_option: OptionButton
var _profile_option: OptionButton
var _emulator_row: HBoxContainer
var _emulator_option: OptionButton
var _emulator_readonly_hint: Label
var _video_path: LineEdit
var _launch_exe_row: HBoxContainer
var _launch_exe_field: LineEdit
var _content_row: HBoxContainer
var _content_path_field: LineEdit
var _args_row: HBoxContainer
var _args_field: LineEdit
var _working_row: HBoxContainer
var _working_field: LineEdit
var _admin_check: CheckBox
var _cover_label: Label
var _cover_source: String = ""
var _year_field: LineEdit
var _description: TextEdit
var _error_label: Label

var _video_dialog: FileDialog
var _launch_exe_dialog: FileDialog
var _content_dialog: FileDialog
var _cover_dialog: FileDialog
var _working_dir_dialog: FileDialog

var _platforms: Array[String] = []
var _picking_target: String = ""
var _emulators: Array = []
var _pending_emulators: Array = []
var _platform_auto: bool = true

func _ready() -> void:
	hide()
	title = "添加游戏"
	size = Vector2i(720, 600)
	min_size = Vector2i(560, 480)
	transient = true
	exclusive = false
	close_requested.connect(hide)
	_build_ui()
	_build_file_dialogs()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	call_deferred("_localize_context_menus")

func set_platforms(arr: Array[String]) -> void:
	_platforms = arr
	if _platform_option == null:
		return
	_platform_option.clear()
	for p in _platforms:
		_platform_option.add_item(p)

func set_emulators(arr: Array) -> void:
	_emulators = arr
	if _emulator_option == null:
		_pending_emulators = arr
		return
	_populate_emulators(arr)

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

	var heading := Label.new()
	heading.text = "添加游戏"
	heading.add_theme_font_size_override("font_size", 22)
	root.add_child(heading)

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
	profile_label.text = "启动类型 *"
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

	# 模拟器（仅「模拟器」模式下显示；选项来自系统页已配置的模拟器）
	_emulator_row = HBoxContainer.new()
	_emulator_row.add_theme_constant_override("separation", 12)
	root.add_child(_emulator_row)
	var emulator_label := Label.new()
	emulator_label.text = "模拟器 *"
	emulator_label.custom_minimum_size = Vector2(100.0, 0.0)
	_emulator_row.add_child(emulator_label)
	_emulator_option = OptionButton.new()
	_emulator_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emulator_option.fit_to_longest_item = false
	_emulator_option.item_selected.connect(_on_emulator_selected)
	_emulator_row.add_child(_emulator_option)

	_title_field = LineEdit.new()
	_title_field.placeholder_text = "例如：雨世界"
	_add_control_row(root, "标题 *", _title_field)
	_english_name_field = LineEdit.new()
	_english_name_field.placeholder_text = "例如：Rain World（刮削时优先用它搜索）"
	_add_control_row(root, "英文名", _english_name_field)

	var platform_row := HBoxContainer.new()
	platform_row.add_theme_constant_override("separation", 12)
	root.add_child(platform_row)
	var platform_label := Label.new()
	platform_label.text = "平台 *"
	platform_label.custom_minimum_size = Vector2(100.0, 0.0)
	platform_row.add_child(platform_label)
	_platform_option = OptionButton.new()
	_platform_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_platform_option.fit_to_longest_item = false
	for p in _platforms:
		_platform_option.add_item(p)
	platform_row.add_child(_platform_option)

	# 游戏文件（direct 时是 exe；emulator 时是 ROM；launcher 时可留空）
	_video_path = LineEdit.new()
	_add_path_row(root, "游戏文件 *", _video_path, func(): _open_picker("video"))

	# 启动 EXE（emulator / launcher 必填）
	_launch_exe_row = _make_path_row("启动 EXE *", func(): _open_picker("launch_exe"))
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

	# 只读提示（仅模拟器模式显示）
	_emulator_readonly_hint = Label.new()
	_emulator_readonly_hint.text = "以上「启动 EXE / 启动参数 / 工作目录」从模拟器配置自动填入，不可编辑；要改请到系统页改模拟器配置。"
	_emulator_readonly_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_emulator_readonly_hint.add_theme_font_size_override("font_size", 11)
	_emulator_readonly_hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.65))
	root.add_child(_emulator_readonly_hint)

	_admin_check = CheckBox.new()
	_admin_check.text = "以管理员身份启动"
	root.add_child(_admin_check)

	# 封面
	_add_cover_row(root)

	# 年份
	_year_field = LineEdit.new()
	_year_field.placeholder_text = "例如 2017，可留空"
	_add_control_row(root, "年份", _year_field)

	# 简介
	var desc_label := Label.new()
	desc_label.text = "简介"
	root.add_child(desc_label)
	_description = TextEdit.new()
	_description.custom_minimum_size = Vector2(0, 100)
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

	# 平台下拉：手动改过就不再被模拟器自动覆盖
	_platform_option.item_selected.connect(func(_idx): _platform_auto = false)

	# 若 set_emulators() 在 _build_ui() 之前被调用，这里补上
	if not _pending_emulators.is_empty():
		_populate_emulators(_pending_emulators)
		_pending_emulators = []

	_on_profile_changed(0)

func _on_profile_changed(idx: int) -> void:
	var is_direct: bool = (idx == 0)
	var is_emulator: bool = (idx == 1)
	var is_launcher: bool = (idx == 2)

	# 未配置模拟器时禁用模拟器模式，回落直连
	if is_emulator and _emulators.is_empty():
		_profile_option.select(0)
		is_direct = true
		is_emulator = false
		is_launcher = false
		_show_error("尚未配置模拟器，请先到系统页「模拟器」区添加")

	_emulator_row.visible = is_emulator
	_emulator_readonly_hint.visible = is_emulator
	_launch_exe_row.visible = (is_emulator or is_launcher)
	# 「内容路径」行单独控制，不跟 is_emulator 直接挂钩：
	# - 模拟器模式：游戏文件即内容路径，隐藏这一行（避免重复填写）
	# - direct / launcher：保持原样不显示
	_content_row.visible = false
	_args_row.visible = not is_direct
	_working_row.visible = not is_direct
	_admin_check.visible = not is_direct

	# 模拟器模式下这三个字段只读（来自模拟器配置）
	_set_readonly(_launch_exe_field, is_emulator)
	_set_readonly(_args_field, is_emulator)
	_set_readonly(_working_field, is_emulator)

	if is_emulator:
		_apply_selected_emulator()

func _set_readonly(field: LineEdit, readonly: bool) -> void:
	field.editable = not readonly
	if readonly:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.16, 0.18, 0.21, 1.0)
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		box.content_margin_top = 4.0
		box.content_margin_bottom = 4.0
		field.add_theme_stylebox_override("read_only", box)
		field.add_theme_color_override("font_readonly_color", Color(0.78, 0.84, 0.88))
	else:
		field.remove_theme_stylebox_override("read_only")
		field.remove_theme_color_override("font_readonly_color")

func _populate_emulators(arr: Array) -> void:
	# 只保留字典条目，保证下拉索引与 _emulators 索引一一对应
	var entries: Array = []
	for entry in arr:
		if entry is Dictionary:
			entries.append(entry)
	_emulators = entries
	_emulator_option.clear()
	if _emulators.is_empty():
		_emulator_option.add_item("（未配置模拟器，请先到系统页添加）")
		_emulator_option.disabled = true
		return
	_emulator_option.disabled = false
	for entry in _emulators:
		var emulator: Dictionary = entry as Dictionary
		var name: String = str(emulator.get("name", ""))
		var tag: String = str(emulator.get("platform_tag", "")).strip_edges()
		_emulator_option.add_item(name if tag.is_empty() else "%s（%s）" % [name, tag])
	_emulator_option.select(0)

func _selected_emulator() -> Dictionary:
	if _emulators.is_empty():
		return {}
	var idx: int = _emulator_option.selected
	if idx < 0 or idx >= _emulators.size():
		return {}
	var entry: Variant = _emulators[idx]
	if entry is Dictionary:
		return entry as Dictionary
	return {}

func _on_emulator_selected(_idx: int) -> void:
	_apply_selected_emulator()

func _apply_selected_emulator() -> void:
	var emulator: Dictionary = _selected_emulator()
	if emulator.is_empty():
		return
	_launch_exe_field.text = str(emulator.get("executable", ""))
	var placeholder: String = str(emulator.get("content_placeholder", "")).strip_edges()
	if placeholder.is_empty():
		placeholder = "{content}"
	var args: String = str(emulator.get("default_args", ""))
	if placeholder != "{content}":
		args = args.replace(placeholder, "{content}")
	_args_field.text = args
	_working_field.text = str(emulator.get("working_dir", ""))
	# 平台：仅在用户没手动改过时自动填
	var tag: String = str(emulator.get("platform_tag", "")).strip_edges()
	if _platform_auto and not tag.is_empty():
		var idx: int = _platforms.find(tag)
		if idx >= 0:
			_platform_option.select(idx)

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
	browse.pressed.connect(func(): _open_picker("cover"))
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
		"*.exe ; 可执行文件", "*.lnk ; 快捷方式",
		"*.iso ; 镜像", "*.cue ; CUE", "*.bin ; BIN", "*.chd ; CHD",
		"*.zip ; 压缩包", "*.7z ; 压缩包",
		"* ; 所有文件",
	]))
	_video_dialog.file_selected.connect(_on_video_selected)
	add_child(_video_dialog)

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

	_cover_dialog = _make_file_dialog(PackedStringArray([
		"*.jpg ; JPEG", "*.jpeg ; JPEG", "*.png ; PNG",
		"*.webp ; WebP", "*.bmp ; BMP",
	]))
	_cover_dialog.file_selected.connect(_on_cover_selected)
	add_child(_cover_dialog)

	_working_dir_dialog = FileDialog.new()
	_working_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_working_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_working_dir_dialog.size = Vector2i(800, 560)
	_working_dir_dialog.dir_selected.connect(func(p): _working_field.text = p)
	add_child(_working_dir_dialog)

func _make_file_dialog(filters: PackedStringArray) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.size = Vector2i(800, 560)
	return dialog

func _open_picker(target: String) -> void:
	_picking_target = target
	match target:
		"video":
			_video_dialog.popup_centered_ratio(0.82)
		"launch_exe":
			_launch_exe_dialog.popup_centered_ratio(0.82)
		"content":
			_content_dialog.popup_centered_ratio(0.82)
		"cover":
			_cover_dialog.popup_centered_ratio(0.82)
		"working":
			_working_dir_dialog.popup_centered_ratio(0.82)

func _on_cover_selected(path: String) -> void:
	_cover_source = path
	_cover_label.text = path.get_file()

# 模拟器模式下「游戏文件」= 内容路径，同时写入两个字段
func _on_video_selected(path: String) -> void:
	_video_path.text = path
	if _profile_option.selected == 1:
		_content_path_field.text = path

func show_dialog(emulators: Array = []) -> void:
	_title_field.text = ""
	_english_name_field.text = ""	
	if _platform_option.item_count > 0:
		_platform_option.select(0)
	_platform_auto = true
	_profile_option.select(0)
	# 每次都重建下拉，避免上一次打开留下的过期选项
	_populate_emulators(emulators)
	_video_path.text = ""
	_launch_exe_field.text = ""
	_content_path_field.text = ""
	_args_field.text = ""
	_working_field.text = ""
	_admin_check.button_pressed = false
	_cover_source = ""
	_cover_label.text = "未选择"
	_year_field.text = ""
	_description.text = ""
	_error_label.visible = false
	_on_profile_changed(0)

	# 自适应父窗口尺寸
	var parent_win: Window = null
	if get_parent() != null:
		parent_win = get_parent().get_window()
	if parent_win != null:
		var target_w: int = mini(720, maxi(560, parent_win.size.x - 80))
		var target_h: int = mini(600, maxi(480, parent_win.size.y - 80))
		size = Vector2i(target_w, target_h)
	popup_centered()

func _submit() -> void:
	var title_text: String = _title_field.text.strip_edges()
	if title_text.is_empty():
		_show_error("请输入游戏标题")
		return
	var video_text: String = _video_path.text.strip_edges()
	var profile_idx: int = _profile_option.selected
	var p_type: String = "direct"
	if profile_idx == 1:
		p_type = "emulator"
	elif profile_idx == 2:
		p_type = "launcher"

	if p_type == "direct" and video_text.is_empty():
		_show_error("直接启动需要选择游戏 EXE")
		return
	if p_type == "emulator":
		if _emulators.is_empty():
			_show_error("尚未配置模拟器，请先到系统页「模拟器」区添加")
			return
		if _selected_emulator().is_empty():
			_show_error("请选择一个模拟器")
			return
		if video_text.is_empty():
			_show_error("模拟器需要选择 ROM/镜像")
			return
		if _launch_exe_field.text.strip_edges().is_empty():
			_show_error("所选模拟器没有配置启动 EXE，请先到系统页补上")
			return
	if p_type == "launcher" and _launch_exe_field.text.strip_edges().is_empty():
		_show_error("启动器模式需要选择 launcher EXE")
		return

	var platform_text: String = ""
	if _platform_option.item_count > 0 and _platform_option.selected >= 0:
		platform_text = _platform_option.get_item_text(_platform_option.selected)

	# 模拟器模式：游戏文件即内容路径
	var content_text: String = _content_path_field.text.strip_edges()
	if p_type == "emulator":
		content_text = video_text

	var payload: Dictionary = {
		"title": title_text,
		"english_name": _english_name_field.text.strip_edges(),		
		"platform": platform_text,
		"profile_type": p_type,
		"video_path": video_text,
		"launch_exe": _launch_exe_field.text.strip_edges(),
		"content_path": content_text,
		"launch_args": _args_field.text.strip_edges(),
		"working_directory": _working_field.text.strip_edges(),
		"run_as_admin": _admin_check.button_pressed,
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