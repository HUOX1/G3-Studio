extends Node

const BUILDER: Script = preload("res://scripts/fontset_overview_builder.gd")
const EDITOR: Script = preload("res://scripts/fontset_editor.gd")
const FONT_MANAGER: Script = preload("res://scripts/font_manager.gd")

var checks: int = 0
var failures: int = 0
var events: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _movie_selected(_index: int) -> void:
	events.append("movie")

func _game_selected(_index: int) -> void:
	events.append("game")

func _movie_edit() -> void:
	events.append("movie_edit")

func _game_edit() -> void:
	events.append("game_edit")

func _back() -> void:
	events.append("back")

func _editor_back() -> void:
	events.append("editor_back")

func _editor_action(_action: String, _payload: Dictionary) -> void:
	events.append("editor_action")

func _run() -> void:
	var panel: VBoxContainer = VBoxContainer.new()
	add_child(panel)
	var muted: Color = Color(0.37, 0.47, 0.57)
	var nodes: Dictionary = BUILDER.new().build_overview(
		panel, muted, _movie_selected, _game_selected,
		_movie_edit, _game_edit, _back
	)
	var root: VBoxContainer = nodes["root"] as VBoxContainer
	var movie: OptionButton = nodes["movie_option"] as OptionButton
	var game: OptionButton = nodes["game_option"] as OptionButton
	var movie_edit: Button = nodes["movie_edit"] as Button
	var game_edit: Button = nodes["game_edit"] as Button
	var back: Button = nodes["back"] as Button
	_check(nodes.size() == 6, "six stable overview references")
	_check(root is VBoxContainer and root.get_parent() == panel, "overview is direct child of system panel")
	_check(panel.get_child_count() == 1, "no extra parent containers")
	_check(not root.visible, "overview initially hidden")
	_check(root.size_flags_horizontal == Control.SIZE_FILL, "overview horizontal size flags")
	_check(root.get_theme_constant("separation") == 12, "overview vertical separation")
	_check(root.get_child_count() == 7, "overview original seven children")
	_check((root.get_child(0) as Label).text == "字体组别", "overview title")
	_check((root.get_child(0) as Label).get_theme_font_size("font_size") == 22, "title font size")
	_check((root.get_child(1) as Label).autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "hint wrap mode")
	_check((root.get_child(1) as Label).get_theme_color("font_color") == muted, "hint uses current muted theme")
	_check((root.get_child(2) as Label).text == "电影", "movie label")
	_check((root.get_child(4) as Label).text == "游戏", "game label")
	_check(movie.get_parent() == root.get_child(3), "movie option stays in movie row")
	_check(game.get_parent() == root.get_child(5), "game option stays in game row")
	_check(movie.get_parent().get_child(1) == movie_edit, "movie edit button order")
	_check(game.get_parent().get_child(1) == game_edit, "game edit button order")
	_check(movie.custom_minimum_size == Vector2(280.0, 40.0), "movie option size")
	_check(game.custom_minimum_size == Vector2(280.0, 40.0), "game option size")
	_check(not movie.fit_to_longest_item and not game.fit_to_longest_item, "option fit mode")
	_check(movie_edit.text == "编辑…" and game_edit.text == "编辑…", "edit button labels")
	_check(back.text == "← 返回设置" and back.get_parent() == root, "back button placement")
	movie.item_selected.emit(0)
	game.item_selected.emit(1)
	movie_edit.pressed.emit()
	game_edit.pressed.emit()
	back.pressed.emit()
	_check(events == ["movie", "game", "movie_edit", "game_edit", "back"], "all five callbacks retain routing")

	var editor_root: VBoxContainer = VBoxContainer.new()
	panel.add_child(editor_root)
	var manager: Node = FONT_MANAGER.new()
	add_child(manager)
	var editor_nodes: Dictionary = BUILDER.new().build_editor(
		editor_root, manager, EDITOR, _editor_back, _editor_action
	)
	var editor_back: Button = editor_nodes["back"] as Button
	var editor: Control = editor_nodes["editor"] as Control
	_check(editor_nodes.size() == 2, "editor exposes two references")
	_check(editor_root.get_child_count() == 2, "editor root child count")
	_check(editor_back == editor_root.get_child(0), "editor back button order")
	_check(editor_back.text == "← 返回字体组别", "editor back label")
	_check(editor_root.get_child(1) is CenterContainer, "editor center retained")
	_check(editor.get_parent() == editor_root.get_child(1), "editor inside center")
	_check(editor is G3FontsetEditor, "real editor script instantiated")
	_check(editor.get("_font_manager") == manager, "font manager injected")
	editor_back.pressed.emit()
	editor.emit_signal("action_requested", "save", {})
	_check(events.slice(5) == ["editor_back", "editor_action"], "editor callback routing")

	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("FONTSET_OVERVIEW_BUILDER_SCRIPT.new().build_overview("), "main delegates overview creation")
	_check(main_source.contains("FONTSET_OVERVIEW_BUILDER_SCRIPT.new().build_editor("), "main delegates editor creation")
	_check(main_source.contains("fontset_option = fontset_nodes[\"movie_option\"] as OptionButton"), "main retains movie option reference")
	_check(main_source.contains("fontset_editor = fontset_editor_nodes[\"editor\"]"), "main retains editor reference")
	_check(not main_source.contains("fs_home_title := Label.new()"), "old inline overview removed")
	_check(not main_source.contains("fontset_editor_back_btn = Button.new()"), "old inline editor removed")
	if failures == 0 and checks == 38:
		print("FONTSET OVERVIEW BUILDER CONTRACT PASS: 38 checks")
		get_tree().quit(0)
	else:
		push_error("FONTSET OVERVIEW BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
