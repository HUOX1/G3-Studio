extends RefCounted

# UI-S2: 仅装配字体组别页节点。业务回调、字体状态与页面导航仍由 main.gd 管理。
# 不额外增加父容器，保持 system_panel 的原有子节点顺序。
func build_overview(parent: VBoxContainer, muted: Color,
		on_movie_selected: Callable, on_game_selected: Callable,
		on_movie_edit: Callable, on_game_edit: Callable,
		on_back: Callable) -> Dictionary:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_FILL
	root.visible = false
	parent.add_child(root)

	var title: Label = Label.new()
	title.text = "字体组别"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var hint: Label = Label.new()
	hint.text = "电影和游戏各自独立，一个字体组别只作用于一个版块。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", muted)
	root.add_child(hint)

	var movie_label: Label = Label.new()
	movie_label.text = "电影"
	movie_label.add_theme_font_size_override("font_size", 16)
	root.add_child(movie_label)

	var movie_row: HBoxContainer = HBoxContainer.new()
	movie_row.add_theme_constant_override("separation", 10)
	root.add_child(movie_row)

	var movie_option: OptionButton = OptionButton.new()
	movie_option.custom_minimum_size = Vector2(280.0, 40.0)
	movie_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	movie_option.fit_to_longest_item = false
	movie_option.item_selected.connect(on_movie_selected)
	movie_row.add_child(movie_option)

	var movie_edit: Button = Button.new()
	movie_edit.text = "编辑…"
	movie_edit.custom_minimum_size = Vector2(100.0, 40.0)
	movie_edit.pressed.connect(on_movie_edit)
	movie_row.add_child(movie_edit)

	var game_label: Label = Label.new()
	game_label.text = "游戏"
	game_label.add_theme_font_size_override("font_size", 16)
	root.add_child(game_label)

	var game_row: HBoxContainer = HBoxContainer.new()
	game_row.add_theme_constant_override("separation", 10)
	root.add_child(game_row)

	var game_option: OptionButton = OptionButton.new()
	game_option.custom_minimum_size = Vector2(280.0, 40.0)
	game_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_option.fit_to_longest_item = false
	game_option.item_selected.connect(on_game_selected)
	game_row.add_child(game_option)

	var game_edit: Button = Button.new()
	game_edit.text = "编辑…"
	game_edit.custom_minimum_size = Vector2(100.0, 40.0)
	game_edit.pressed.connect(on_game_edit)
	game_row.add_child(game_edit)

	var back: Button = Button.new()
	back.text = "← 返回设置"
	back.custom_minimum_size = Vector2(320.0, 36.0)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.pressed.connect(on_back)
	root.add_child(back)

	return {
		"root": root,
		"movie_option": movie_option,
		"game_option": game_option,
		"movie_edit": movie_edit,
		"game_edit": game_edit,
		"back": back,
	}


func build_editor(parent: VBoxContainer, font_manager: Node, editor_script: Script,
		on_back: Callable, on_action: Callable) -> Dictionary:
	var back: Button = Button.new()
	back.text = "← 返回字体组别"
	back.custom_minimum_size = Vector2(320.0, 36.0)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.pressed.connect(on_back)
	parent.add_child(back)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(center)

	var editor = editor_script.new()
	editor.set_font_manager(font_manager)
	editor.action_requested.connect(on_action)
	center.add_child(editor)

	return {"back": back, "editor": editor}
