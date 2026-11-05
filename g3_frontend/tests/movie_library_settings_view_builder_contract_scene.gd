extends Node

const BUILDER: Script = preload("res://scripts/movie_library_settings_view_builder.gd")
var checks: int = 0
var failures: int = 0
var removed: Array = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[FAIL] " + name)

func _remove(path: String) -> void:
	removed.append(path)

func _run() -> void:
	var builder: RefCounted = BUILDER.new()
	builder.rebuild_cover_folder(null, null, "main", "x", "y")
	_check(true, "null folder safe")
	var cover := Label.new()
	var cover_title := Label.new()
	add_child(cover)
	add_child(cover_title)
	builder.rebuild_cover_folder(cover, cover_title, "main", "A", "B")
	_check(cover.text == "A", "main cover path")
	_check(cover_title.text == "封面文件夹（主库）", "main cover title")
	builder.rebuild_cover_folder(cover, cover_title, "private", "A", "B")
	_check(cover.text == "B", "private cover path")
	_check(cover_title.text == "封面文件夹（私有库）", "private cover title")
	builder.rebuild_cover_folder(cover, cover_title, "private", "A", "")
	_check(cover.text == "（未设置）", "empty cover placeholder")
	builder.rebuild_cover_folder(cover, null, "main", "A", "B")
	_check(cover.text == "A", "null title safe")
	var list_node := VBoxContainer.new()
	var title := Label.new()
	add_child(list_node)
	add_child(title)
	var main_paths: Array[String] = ["C:/one", "D:/two"]
	var private_paths: Array[String] = ["E:/private"]
	var muted := Color(0.2, 0.3, 0.4)
	builder.rebuild_library_paths(null, title, "main", main_paths, private_paths, muted, _remove)
	_check(list_node.get_child_count() == 0, "null list safe")
	builder.rebuild_library_paths(list_node, title, "main", main_paths, private_paths, muted, _remove)
	_check(title.text == "影视库文件夹（主库）", "main library title")
	_check(list_node.get_child_count() == 2, "two main paths")
	var row: HBoxContainer = list_node.get_child(0) as HBoxContainer
	_check(row != null, "row container")
	_check(row.get_theme_constant("separation") == 8, "row spacing")
	_check(row.get_child_count() == 2, "row contains label and button")
	var label: Label = row.get_child(0) as Label
	var button: Button = row.get_child(1) as Button
	_check(label.text == "C:/one", "first path label")
	_check(label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "path label expands")
	_check(label.get_theme_font_size("font_size") == 12, "path font size")
	_check(label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "path wraps")
	_check(button.text == "移除", "button label")
	_check(button.custom_minimum_size == Vector2(60.0, 0.0), "button size")
	_check((list_node.get_child(1) as HBoxContainer).get_child(0).text == "D:/two", "second path")
	button.pressed.emit()
	_check(removed == ["C:/one"], "button forwards first path")
	(list_node.get_child(1) as HBoxContainer).get_child(1).pressed.emit()
	_check(removed == ["C:/one", "D:/two"], "button forwards second path")
	builder.rebuild_library_paths(list_node, title, "private", main_paths, private_paths, muted, _remove)
	_check(title.text == "影视库文件夹（私有库）", "private library title")
	# queue_free is deferred, so count only active children.
	var active: Array = []
	for child in list_node.get_children():
		if not child.is_queued_for_deletion():
			active.append(child)
	_check(active.size() == 1, "one private row")
	_check((active[0] as HBoxContainer).get_child(0).text == "E:/private", "private path label")
	(active[0] as HBoxContainer).get_child(1).pressed.emit()
	_check(removed.back() == "E:/private", "private remove callback")
	var empty_paths: Array[String] = []
	builder.rebuild_library_paths(list_node, title, "main", empty_paths, private_paths, muted, _remove)
	active.clear()
	for child in list_node.get_children():
		if not child.is_queued_for_deletion():
			active.append(child)
	_check(active.size() == 1, "empty paths single placeholder")
	var placeholder: Label = active[0] as Label
	_check(placeholder.text == "（尚未添加）", "empty placeholder wording")
	_check(placeholder.get_theme_font_size("font_size") == 12, "empty placeholder font size")
	_check(placeholder.get_theme_color("font_color") == muted, "empty placeholder color")
	_check(title.text == "影视库文件夹（主库）", "empty main title")
	builder.rebuild_library_paths(list_node, null, "private", main_paths, empty_paths, muted, _remove)
	active.clear()
	for child in list_node.get_children():
		if not child.is_queued_for_deletion():
			active.append(child)
	_check(active.size() == 1, "null title rebuild safe")
	_check((active[0] as Label).text == "（尚未添加）", "private empty placeholder")
	_check(removed.size() == 3, "rebuild has no removal side effects")
	_check((active[0] as Label).get_theme_font_size("font_size") == 12, "private placeholder font")
	_check(checks == 35, "expected prior checks")
	if failures == 0 and checks == 36:
		print("MOVIE LIBRARY SETTINGS VIEW BUILDER CONTRACT PASS: 36 checks")
	else:
		push_error("MOVIE LIBRARY SETTINGS VIEW BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
	get_tree().quit(0 if failures == 0 and checks == 36 else 1)
