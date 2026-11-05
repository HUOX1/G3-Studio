extends Node

const EXPECTED_CHECKS: int = 37
const BUILDER: Script = preload("res://scripts/system_home_view_builder.gd")

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

func _on_selected(_index: int, event: String) -> void:
	events.append(event)

func _on_pressed(event: String) -> void:
	events.append(event)

func _run() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	add_child(root)
	var muted: Color = Color(0.37, 0.47, 0.57)
	var sections: Array[String] = ["游戏", "电影", "试验场", "游戏藏品室", "系统"]
	var callbacks: Dictionary = {
		"_on_window_mode_selected": _on_selected.bind("window"),
		"_exit_application": _on_pressed.bind("exit"),
		"_on_fontset_entry_pressed": _on_pressed.bind("fontset"),
		"_on_sfx_entry_pressed": _on_pressed.bind("sfx"),
		"_on_default_start_section_selected": _on_selected.bind("start"),
		"_on_add_movie_lib_pressed": _on_pressed.bind("library"),
		"_on_set_cover_folder_pressed": _on_pressed.bind("cover_set"),
		"_on_clear_cover_folder_pressed": _on_pressed.bind("cover_clear"),
		"_on_match_local_covers_pressed": _on_pressed.bind("cover_match"),
		"_on_open_cover_tool_pressed": _on_pressed.bind("cover_tool"),
		"_on_add_emulator_pressed": _on_pressed.bind("emulator"),
	}
	var nodes: Dictionary = BUILDER.new().build(root, muted, sections, callbacks)
	_check(nodes.size() == 9, "nine stable external references")
	_check((root.get_child(0) as Label).text == "启动窗口模式", "window label first")
	_check(nodes["window_mode_option"] == root.get_child(1), "window selector second")
	_check((root.get_child(2) as Button).text == "退出 G3", "exit button third")
	_check((root.get_child(3) as Label).text == "字体组别", "fontset title fourth")
	_check(nodes["fontset_entry_btn"] == root.get_child(4), "fontset button fifth")
	_check((root.get_child(5) as Button).text == "音效管理…", "SFX entry remains available")
	_check((root.get_child(6) as Label).text == "默认启动板块", "default section title seventh")
	_check(nodes["default_section_option"] == root.get_child(7), "default section selector eighth")
	_check(nodes["_lib_title_label"] == root.get_child(8), "library label in original order")
	_check(nodes["movie_lib_paths_list"] == root.get_child(9), "library list in original order")
	_check((root.get_child(10) as Button).text == "添加文件夹…", "library add button in original order")
	_check(nodes["_cover_folder_title"] == root.get_child(11), "cover title in original order")
	_check(nodes["_cover_folder_label"] == root.get_child(12), "cover label in original order")
	_check(root.get_child(13) is HBoxContainer, "cover buttons remain grouped")
	_check((root.get_child(14) as Button).text == "用封面文件夹匹配当前库", "cover match position")
	_check((root.get_child(15) as Button).text == "封面裁剪工具…", "cover tool position")
	_check((root.get_child(16) as Label).text == "模拟器", "emulator title position")
	_check(nodes["_emulator_list"] == root.get_child(17), "emulator list position")
	_check(root.get_child(18) is Button, "emulator add button position")
	_check((root.get_child(19) as Label).text == "操作说明", "help title position")
	_check(nodes["hint_label"] == root.get_child(20), "help text last")
	_check(root.get_child_count() == 21, "twenty-one top-level system home nodes without theme selector")
	var window: OptionButton = nodes["window_mode_option"] as OptionButton
	var start: OptionButton = nodes["default_section_option"] as OptionButton
	_check(window.item_count == 2, "window choices unchanged")
	_check(window.get_item_text(0) == "窗口（最小尺寸）", "window choice unchanged")
	_check(window.get_item_text(1) == "全屏", "fullscreen choice unchanged")
	_check(start.item_count == 5, "all five section choices unchanged")
	_check(start.get_item_text(3) == "游戏藏品室", "section order unchanged")
	_check(window.custom_minimum_size == Vector2(320.0, 42.0), "window option dimensions unchanged")
	_check((nodes["_cover_folder_label"] as Label).get_theme_color("font_color") == muted, "cover label theme")
	_check((nodes["hint_label"] as Label).get_theme_color("font_color") == muted, "help label theme")
	_check((root.get_child(13) as HBoxContainer).get_child_count() == 2, "cover row retains two buttons")
	window.item_selected.emit(1)
	(root.get_child(2) as Button).pressed.emit()
	(nodes["fontset_entry_btn"] as Button).pressed.emit()
	(root.get_child(5) as Button).pressed.emit()
	start.item_selected.emit(3)
	(root.get_child(10) as Button).pressed.emit()
	((root.get_child(13) as HBoxContainer).get_child(0) as Button).pressed.emit()
	((root.get_child(13) as HBoxContainer).get_child(1) as Button).pressed.emit()
	(root.get_child(14) as Button).pressed.emit()
	(root.get_child(15) as Button).pressed.emit()
	(root.get_child(18) as Button).pressed.emit()
	_check(events == ["window", "exit", "fontset", "sfx", "start", "library", "cover_set", "cover_clear", "cover_match", "cover_tool", "emulator"], "eleven remaining signals preserve callbacks")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("SYSTEM_HOME_VIEW_BUILDER_SCRIPT.new().build("), "main delegates home build")
	_check(main_source.contains("window_mode_option = system_home_nodes[\"window_mode_option\"] as OptionButton"), "main retains selector reference")
	_check(main_source.contains("_emulator_list = system_home_nodes[\"_emulator_list\"] as VBoxContainer"), "main retains emulator list reference")
	_check(not main_source.contains("var window_mode_label := Label.new()"), "old inline home builder removed")
	if failures == 0 and checks == EXPECTED_CHECKS:
		print("SYSTEM HOME VIEW BUILDER CONTRACT PASS: %d checks" % checks)
		get_tree().quit(0)
	else:
		push_error("SYSTEM HOME VIEW BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
