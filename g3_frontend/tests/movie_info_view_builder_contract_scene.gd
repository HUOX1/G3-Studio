extends Node

const BUILDER: Script = preload("res://scripts/movie_info_view_builder.gd")
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _run() -> void:
	var ui: Control = Control.new()
	add_child(ui)
	var nodes: Dictionary = BUILDER.new().build(ui)
	var title: Label = nodes["title"] as Label
	var meta: Label = nodes["meta"] as Label
	var genres: Label = nodes["genres"] as Label
	var scroll: ScrollContainer = nodes["scroll"] as ScrollContainer
	var desc: Label = nodes["description"] as Label
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(nodes.size() == 5, "returns five node references")
	_check(title is Label and meta is Label and genres is Label, "three info labels created")
	_check(scroll is ScrollContainer and desc is Label, "scroll and description created")
	_check(ui.get_child_count() == 4, "four direct children")
	_check(ui.get_child(0) == title and ui.get_child(1) == meta, "title and year ordering preserved")
	_check(ui.get_child(2) == genres and ui.get_child(3) == scroll, "genres and scroll ordering preserved")
	_check(not title.visible and not meta.visible and not genres.visible, "initial label visibility preserved")
	_check(title.mouse_filter == Control.MOUSE_FILTER_IGNORE, "title ignores pointer")
	_check(meta.mouse_filter == Control.MOUSE_FILTER_IGNORE and genres.mouse_filter == Control.MOUSE_FILTER_IGNORE, "meta labels ignore pointer")
	_check(title.get_theme_color("font_color") == Color(1, 1, 1, 1), "title color preserved")
	_check(meta.get_theme_color("font_color") == Color(0.68, 0.68, 0.68, 1), "year color preserved")
	_check(genres.get_theme_color("font_color") == Color(0.72, 0.72, 0.72, 1), "genres color preserved")
	_check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "horizontal scrolling disabled")
	_check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "vertical scrolling automatic")
	_check(scroll.mouse_filter == Control.MOUSE_FILTER_PASS, "scroll pointer behavior preserved")
	_check(scroll.get_child_count() >= 1 and desc.get_parent() is VBoxContainer, "description inside vertical layout")
	_check(desc.get_parent().get_parent() == scroll, "description layout belongs to scroll")
	_check(desc.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "smart wrapping preserved")
	_check(desc.get_theme_font_size("font_size") == 16, "description initial font size preserved")
	_check(desc.get_theme_color("font_color") == Color(0.80, 0.80, 0.80, 1), "description color preserved")
	_check(desc.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "description expands horizontally")
	_check(scroll.get_v_scroll_bar() != null, "vertical scrollbar retained")
	_check(scroll.get_v_scroll_bar().get_theme_stylebox("grabber") is StyleBoxEmpty, "scrollbar grabber remains invisible")
	_check(main_source.contains("MOVIE_INFO_VIEW_BUILDER_SCRIPT.new().build(ui)"), "main uses builder")
	_check(main_source.contains("movie_info_title = movie_info_nodes[\"title\"] as Label"), "main keeps title reference")
	_check(main_source.contains("movie_desc_label = movie_info_nodes[\"description\"] as Label"), "main keeps description reference")
	_check(not main_source.contains("movie_info_title = Label.new()"), "inline title creation removed")
	if failures == 0 and checks == 27:
		print("MOVIE INFO VIEW BUILDER CONTRACT PASS: 27 checks")
		get_tree().quit(0)
	else:
		push_error("MOVIE INFO VIEW BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
