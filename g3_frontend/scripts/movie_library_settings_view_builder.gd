extends RefCounted

# UI-S6c: view-only builder for the movie library and cover folder settings.
# Persistence, backend requests and removal decisions stay in main.gd.
func rebuild_cover_folder(folder_label: Label, title_label: Label, scope: String, main_folder: String, private_folder: String) -> void:
	if folder_label == null:
		return
	if title_label != null:
		title_label.text = "封面文件夹（私有库）" if scope == "private" else "封面文件夹（主库）"
	var folder: String = private_folder if scope == "private" else main_folder
	folder_label.text = folder if not folder.is_empty() else "（未设置）"

func rebuild_library_paths(paths_list: Node, title_label: Label, scope: String, main_paths: Array[String], private_paths: Array[String], muted: Color, remove_callback: Callable) -> void:
	if paths_list == null:
		return
	for child in paths_list.get_children():
		child.queue_free()
	if title_label != null:
		title_label.text = "影视库文件夹（私有库）" if scope == "private" else "影视库文件夹（主库）"
	var source: Array[String] = private_paths if scope == "private" else main_paths
	if source.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（尚未添加）"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", muted)
		paths_list.add_child(empty_label)
		return
	for path in source:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = path
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		row.add_child(label)
		var remove_btn := Button.new()
		remove_btn.text = "移除"
		remove_btn.custom_minimum_size = Vector2(60.0, 0.0)
		remove_btn.pressed.connect(remove_callback.bind(path))
		row.add_child(remove_btn)
		paths_list.add_child(row)
