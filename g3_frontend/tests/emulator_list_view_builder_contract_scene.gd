extends Node

const BUILDER: Script = preload("res://scripts/emulator_list_view_builder.gd")
const EXPECTED_BEFORE_FINAL: int = 37

var checks: int = 0
var failures: int = 0
var edited: Array = []
var removed: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	checks += 1
	if ok:
		print("[PASS] ", name)
	else:
		failures += 1
		push_error("[FAIL] " + name)

func _edit(emulator: Dictionary) -> void:
	edited.append(emulator)

func _remove(emulator_id: String) -> void:
	removed.append(emulator_id)

func _run() -> void:
	var builder: RefCounted = BUILDER.new()
	var parent: VBoxContainer = VBoxContainer.new()
	add_child(parent)
	var muted: Color = Color(0.2, 0.4, 0.6)
	builder.rebuild(null, [], muted, _edit, _remove)
	_check(parent.get_child_count() == 0, "null parent does not affect list")
	builder.rebuild(parent, [], muted, _edit, _remove)
	_check(parent.get_child_count() == 1, "empty list has one child")
	var empty: Label = parent.get_child(0) as Label
	_check(empty != null, "empty placeholder is label")
	_check(empty.text == "（尚未添加）", "empty placeholder text")
	_check(empty.get_theme_font_size("font_size") == 12, "empty font size")
	_check(empty.get_theme_color("font_color") == muted, "empty theme color")
	var emulator: Dictionary = {"id": "emu-1", "name": "My Emulator", "platform_tag": "PS2", "executable": "  C:/bin/emu.exe  ", "scan_dirs": ["C:/roms", "D:/roms"]}
	builder.rebuild(parent, [emulator], muted, _edit, _remove)
	_check(parent.get_child_count() == 1, "one emulator row")
	var row: HBoxContainer = parent.get_child(0) as HBoxContainer
	_check(row != null, "row is HBoxContainer")
	_check(row.get_theme_constant("separation") == 8, "row separation")
	_check(row.get_child_count() == 3, "row has info edit remove")
	var info: VBoxContainer = row.get_child(0) as VBoxContainer
	_check(info != null, "info vertical container")
	_check(info.get_theme_constant("separation") == 0, "info separation")
	_check(info.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "info expands horizontally")
	_check(info.get_child_count() == 2, "info has two labels")
	var name_label: Label = info.get_child(0) as Label
	var detail: Label = info.get_child(1) as Label
	_check(name_label.text == "My Emulator", "name label")
	_check(name_label.get_theme_font_size("font_size") == 14, "name font size")
	_check(name_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "name truncation")
	_check(detail.text == "PS2  ·  C:/bin/emu.exe  ·  2 个扫描目录", "detail text")
	_check(detail.get_theme_font_size("font_size") == 11, "detail font size")
	_check(detail.get_theme_color("font_color") == muted, "detail theme color")
	_check(detail.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "detail truncation")
	var edit_button: Button = row.get_child(1) as Button
	var remove_button: Button = row.get_child(2) as Button
	_check(edit_button.text == "编辑", "edit label")
	_check(remove_button.text == "移除", "remove label")
	_check(edit_button.custom_minimum_size == Vector2(64, 30), "edit button size")
	_check(remove_button.custom_minimum_size == Vector2(64, 30), "remove button size")
	edit_button.pressed.emit()
	remove_button.pressed.emit()
	_check(edited.size() == 1 and edited[0] == emulator, "edit callback gets original dictionary")
	_check(removed == ["emu-1"], "remove callback gets ID")
	builder.rebuild(parent, [{"id": "emu-2", "name": "No exe", "executable": "", "scan_dirs": []}, "invalid"], muted, _edit, _remove)
	_check(parent.get_child_count() == 1, "non-dictionary entries skipped")
	row = parent.get_child(0) as HBoxContainer
	info = row.get_child(0) as VBoxContainer
	detail = info.get_child(1) as Label
	_check(detail.text == "未配置 EXE", "missing executable fallback")
	_check(row.get_child(1).text == "编辑", "edit button remains after rebuild")
	_check(row.get_child(2).text == "移除", "remove button remains after rebuild")
	row.get_child(2).pressed.emit()
	_check(removed == ["emu-1", "emu-2"], "new remove binding after rebuild")
	builder.rebuild(parent, [], muted, _edit, _remove)
	_check(parent.get_child_count() == 1 and parent.get_child(0) is Label, "rebuild restores empty placeholder")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("const EMULATOR_LIST_VIEW_BUILDER_SCRIPT"), "main preloads builder")
	_check(main_source.contains("EMULATOR_LIST_VIEW_BUILDER_SCRIPT.new().rebuild("), "main delegates list building")
	_check(main_source.contains("_on_edit_emulator_pressed, _on_remove_emulator_pressed"), "main retains original callbacks")
	_check(not main_source.contains("func _make_emulator_row("), "old inline row builder removed")
	_check(checks == EXPECTED_BEFORE_FINAL, "expected check count")
	if failures == 0:
		print("EMULATOR LIST VIEW BUILDER CONTRACT PASS: %d checks" % checks)
	else:
		push_error("EMULATOR LIST VIEW BUILDER CONTRACT FAIL: %d/%d failed" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
