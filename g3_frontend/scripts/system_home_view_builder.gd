extends RefCounted

# UI-S3: 仅构建系统设置首页。主入口仍持有节点引用和全部业务回调。
# 直接向现有 system_home_root 添加节点，保持子节点顺序和样式。
func build(parent: VBoxContainer, muted: Color, section_labels: Array[String], callbacks: Dictionary) -> Dictionary:
	var window_mode_label := Label.new()
	window_mode_label.text = "启动窗口模式"
	window_mode_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(window_mode_label)
	var window_mode_option: OptionButton = OptionButton.new()
	window_mode_option.custom_minimum_size = Vector2(320.0, 42.0)
	window_mode_option.size_flags_horizontal = Control.SIZE_FILL
	window_mode_option.add_item("窗口（最小尺寸）")
	window_mode_option.add_item("全屏")
	window_mode_option.item_selected.connect(callbacks["_on_window_mode_selected"])
	parent.add_child(window_mode_option)

	var exit_button: Button = Button.new()
	exit_button.text = "退出 G3"
	exit_button.custom_minimum_size = Vector2(320.0, 46.0)
	exit_button.size_flags_horizontal = Control.SIZE_FILL
	exit_button.pressed.connect(callbacks["_exit_application"])
	parent.add_child(exit_button)

	# ── 字体组别入口（主 System 页只留一个按钮）──
	var fontset_entry_label := Label.new()
	fontset_entry_label.text = "字体组别"
	fontset_entry_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(fontset_entry_label)

	var fontset_entry_btn: Button = Button.new()
	fontset_entry_btn.text = "字体组别…"
	fontset_entry_btn.custom_minimum_size = Vector2(320.0, 36.0)
	fontset_entry_btn.size_flags_horizontal = Control.SIZE_FILL
	fontset_entry_btn.pressed.connect(callbacks["_on_fontset_entry_pressed"])
	parent.add_child(fontset_entry_btn)

	var sfx_entry_btn := Button.new()
	sfx_entry_btn.text = "音效管理…"
	sfx_entry_btn.custom_minimum_size = Vector2(320.0, 42.0)
	sfx_entry_btn.size_flags_horizontal = Control.SIZE_FILL
	sfx_entry_btn.pressed.connect(callbacks["_on_sfx_entry_pressed"])
	parent.add_child(sfx_entry_btn)

	var start_label := Label.new()
	start_label.text = "默认启动板块"
	start_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(start_label)
	var default_section_option: OptionButton = OptionButton.new()
	default_section_option.custom_minimum_size = Vector2(320.0, 42.0)
	default_section_option.size_flags_horizontal = Control.SIZE_FILL
	for label: String in section_labels:
		default_section_option.add_item(label)
	default_section_option.item_selected.connect(callbacks["_on_default_start_section_selected"])
	parent.add_child(default_section_option)

	var _lib_title_label: Label = Label.new()
	_lib_title_label.text = "影视库文件夹（主库）"
	_lib_title_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(_lib_title_label)

	var movie_lib_paths_list: VBoxContainer = VBoxContainer.new()
	movie_lib_paths_list.add_theme_constant_override("separation", 4)
	parent.add_child(movie_lib_paths_list)

	var add_lib_button := Button.new()
	add_lib_button.text = "添加文件夹…"
	add_lib_button.custom_minimum_size = Vector2(320.0, 36.0)
	add_lib_button.size_flags_horizontal = Control.SIZE_FILL
	add_lib_button.pressed.connect(callbacks["_on_add_movie_lib_pressed"])
	parent.add_child(add_lib_button)

	# ── 封面文件夹（随库切换） ──
	var _cover_folder_title: Label = Label.new()
	_cover_folder_title.text = "封面文件夹（主库）"
	_cover_folder_title.add_theme_font_size_override("font_size", 16)
	parent.add_child(_cover_folder_title)

	var _cover_folder_label: Label = Label.new()
	_cover_folder_label.text = "（未设置）"
	_cover_folder_label.add_theme_font_size_override("font_size", 12)
	_cover_folder_label.add_theme_color_override("font_color", muted)
	_cover_folder_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	parent.add_child(_cover_folder_label)

	var cover_btn_row := HBoxContainer.new()
	cover_btn_row.add_theme_constant_override("separation", 8)
	parent.add_child(cover_btn_row)

	var set_cover_btn := Button.new()
	set_cover_btn.text = "选择封面文件夹…"
	set_cover_btn.custom_minimum_size = Vector2(200.0, 36.0)
	set_cover_btn.pressed.connect(callbacks["_on_set_cover_folder_pressed"])
	cover_btn_row.add_child(set_cover_btn)

	var clear_cover_btn := Button.new()
	clear_cover_btn.text = "清除"
	clear_cover_btn.custom_minimum_size = Vector2(80.0, 36.0)
	clear_cover_btn.pressed.connect(callbacks["_on_clear_cover_folder_pressed"])
	cover_btn_row.add_child(clear_cover_btn)

	var match_cover_btn := Button.new()
	match_cover_btn.text = "用封面文件夹匹配当前库"
	match_cover_btn.custom_minimum_size = Vector2(320.0, 36.0)
	match_cover_btn.size_flags_horizontal = Control.SIZE_FILL
	match_cover_btn.pressed.connect(callbacks["_on_match_local_covers_pressed"])
	parent.add_child(match_cover_btn)

	var cover_tool_btn := Button.new()
	cover_tool_btn.text = "封面裁剪工具…"
	cover_tool_btn.custom_minimum_size = Vector2(320.0, 36.0)
	cover_tool_btn.size_flags_horizontal = Control.SIZE_FILL
	cover_tool_btn.pressed.connect(callbacks["_on_open_cover_tool_pressed"])
	parent.add_child(cover_tool_btn)

	# ── 模拟器 ──
	var emulator_title := Label.new()
	emulator_title.text = "模拟器"
	emulator_title.add_theme_font_size_override("font_size", 16)
	parent.add_child(emulator_title)

	var _emulator_list: VBoxContainer = VBoxContainer.new()
	_emulator_list.add_theme_constant_override("separation", 4)
	_emulator_list.size_flags_horizontal = Control.SIZE_FILL
	parent.add_child(_emulator_list)

	var add_emulator_btn := Button.new()
	add_emulator_btn.text = "+ 添加模拟器"
	add_emulator_btn.custom_minimum_size = Vector2(320.0, 36.0)
	add_emulator_btn.size_flags_horizontal = Control.SIZE_FILL
	add_emulator_btn.pressed.connect(callbacks["_on_add_emulator_pressed"])
	parent.add_child(add_emulator_btn)

	var help_title := Label.new()
	help_title.text = "操作说明"
	help_title.add_theme_font_size_override("font_size", 16)
	parent.add_child(help_title)
	var hint_label: Label = Label.new()
	hint_label.text = "滚轮 / ← → 选择    单击预览    双击播放    右键管理    Ctrl+Q 退出"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", muted)
	parent.add_child(hint_label)

	return {
		"window_mode_option": window_mode_option,
		"fontset_entry_btn": fontset_entry_btn,
		"default_section_option": default_section_option,
		"_lib_title_label": _lib_title_label,
		"movie_lib_paths_list": movie_lib_paths_list,
		"_cover_folder_title": _cover_folder_title,
		"_cover_folder_label": _cover_folder_label,
		"_emulator_list": _emulator_list,
		"hint_label": hint_label,
	}

# UI-S6f: 系统页缩放计算和递归字体/尺寸更新，由 Builder 管理。
func layout_panel(system_panel: Control, system_pad: Control, win_size: Vector2, base_size: Vector2, base_width: float) -> float:
	if system_panel == null:
		return 1.0
	if win_size.x <= 0.0 or win_size.y <= 0.0:
		return 1.0
	var raw: float = min(win_size.x / base_size.x,
						 win_size.y / base_size.y)
	var scale_factor: float = clampf(raw, 0.62, 1.30)
	var font_factor: float = clampf(raw, 0.90, 1.30)
	var panel_w: float = base_width * scale_factor
	if system_pad != null:
		system_pad.custom_minimum_size.x = panel_w
	_rescale_system_fonts(system_panel, scale_factor, font_factor)
	return scale_factor

func _rescale_system_fonts(system_panel: Control, scale_factor: float, font_factor: float) -> void:
	for child in system_panel.get_children():
		_rescale_node(child, scale_factor, font_factor)

func _rescale_node(node: Node, scale_factor: float, font_factor: float) -> void:
	if node is Control:
		var ctrl := node as Control
		# 只有第一次才记录基准尺寸，防止动态加入的节点被反复缩放
		if not ctrl.has_meta("base_min_size"):
			ctrl.set_meta("base_min_size", ctrl.custom_minimum_size)
		var base_size: Vector2 = ctrl.get_meta("base_min_size")
		ctrl.custom_minimum_size = base_size * scale_factor

		if ctrl is Label:
			var lbl := ctrl as Label
			var base_font: int = lbl.get_meta("base_font_size", lbl.get_theme_font_size("font_size"))
			lbl.set_meta("base_font_size", base_font)
			lbl.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is Button:
			var btn := ctrl as Button
			var base_font: int = btn.get_meta("base_font_size", btn.get_theme_font_size("font_size"))
			btn.set_meta("base_font_size", base_font)
			btn.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is OptionButton:
			var opt := ctrl as OptionButton
			var base_font: int = opt.get_meta("base_font_size", opt.get_theme_font_size("font_size"))
			opt.set_meta("base_font_size", base_font)
			opt.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is SpinBox:
			var spin := ctrl as SpinBox
			var base_font: int = spin.get_meta("base_font_size", spin.get_theme_font_size("font_size"))
			spin.set_meta("base_font_size", base_font)
			spin.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is CheckButton:
			var check := ctrl as CheckButton
			var base_font: int = check.get_meta("base_font_size", check.get_theme_font_size("font_size"))
			check.set_meta("base_font_size", base_font)
			check.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))
		elif ctrl is LineEdit:
			var le := ctrl as LineEdit
			var base_font: int = le.get_meta("base_font_size", le.get_theme_font_size("font_size"))
			le.set_meta("base_font_size", base_font)
			le.add_theme_font_size_override("font_size", int(float(base_font) * font_factor))

	for child in node.get_children():
		_rescale_node(child, scale_factor, font_factor)
