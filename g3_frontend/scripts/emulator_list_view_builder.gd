extends RefCounted

# UI-S6a: build the System-page emulator list only. No backend operations here.
# Keep node ordering, button signals, and existing remove/queue_free behavior.
func rebuild(parent: VBoxContainer, emulators: Array, muted: Color, on_edit: Callable, on_remove: Callable) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	if emulators.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（尚未添加）"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", muted)
		parent.add_child(empty_label)
		return
	for entry in emulators:
		if entry is Dictionary:
			parent.add_child(_make_emulator_row(entry as Dictionary, muted, on_edit, on_remove))

func _make_emulator_row(emulator: Dictionary, muted: Color, on_edit: Callable, on_remove: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(emulator.get("name", ""))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	info.add_child(name_label)

	var detail_parts: Array[String] = []
	var platform_text: String = str(emulator.get("platform_tag", "")).strip_edges()
	if not platform_text.is_empty():
		detail_parts.append(platform_text)
	var exe_text: String = str(emulator.get("executable", "")).strip_edges()
	detail_parts.append(exe_text if not exe_text.is_empty() else "未配置 EXE")
	var scan_count: int = 0
	var raw_dirs: Variant = emulator.get("scan_dirs", [])
	if raw_dirs is Array:
		scan_count = (raw_dirs as Array).size()
	if scan_count > 0:
		detail_parts.append("%d 个扫描目录" % scan_count)
	var detail := Label.new()
	detail.text = "  ·  ".join(detail_parts)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", muted)
	info.add_child(detail)

	var emulator_id: String = str(emulator.get("id", ""))
	var edit_btn := Button.new()
	edit_btn.text = "编辑"
	edit_btn.custom_minimum_size = Vector2(64.0, 30.0)
	edit_btn.pressed.connect(on_edit.bind(emulator))
	row.add_child(edit_btn)

	var remove_btn := Button.new()
	remove_btn.text = "移除"
	remove_btn.custom_minimum_size = Vector2(64.0, 30.0)
	remove_btn.pressed.connect(on_remove.bind(emulator_id))
	row.add_child(remove_btn)
	return row
