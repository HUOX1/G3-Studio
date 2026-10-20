extends Window
class_name G3GameMetadataDialog

signal save_requested(item_id: String, metadata: Dictionary)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

const DEFAULT_PLATFORMS: Array[String] = [
	"PC", "Steam", "GOG", "Epic",
	"PS1", "PS2", "PS3", "PS4", "PS5",
	"PSP", "PS Vita",
	"Xbox", "Xbox 360", "Xbox One", "Xbox Series",
	"FC", "SFC", "N64", "NGC", "Wii", "Wii U", "Switch",
	"GB", "GBC", "GBA", "NDS", "3DS",
	"MD", "SS", "DC",
	"Arcade", "其他",
]

var _item_id: String = ""
var _platforms: Array[String] = []

var _title_field: LineEdit
var _english_name_field: LineEdit
var _platform_option: OptionButton
var _developer_field: LineEdit
var _publisher_field: LineEdit
var _year_field: LineEdit
var _tags_field: LineEdit
var _genres_field: LineEdit
var _description: TextEdit
var _error_label: Label

func _ready() -> void:
	title = "编辑资料"
	size = Vector2i(700, 600)
	min_size = Vector2i(580, 500)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	call_deferred("_localize_context_menus")
	hide()

# 平台候选：外部（main.gd 的 GAME_PLATFORMS）传入时优先用外部的。
func set_platforms(arr: Array[String]) -> void:
	_platforms = arr

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_title_field = LineEdit.new()
	_title_field.placeholder_text = "例如：雨世界"
	_add_control_row(root, "标题", _title_field)
	_english_name_field = LineEdit.new()
	_english_name_field.placeholder_text = "例如：Rain World（刮削时优先用它搜索）"
	_add_control_row(root, "英文名", _english_name_field)

	var platform_row := HBoxContainer.new()
	platform_row.add_theme_constant_override("separation", 12)
	root.add_child(platform_row)
	var platform_label := Label.new()
	platform_label.text = "平台"
	platform_label.custom_minimum_size = Vector2(90.0, 0.0)
	platform_row.add_child(platform_label)
	_platform_option = OptionButton.new()
	_platform_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_platform_option.fit_to_longest_item = false
	platform_row.add_child(_platform_option)

	_developer_field = LineEdit.new()
	_developer_field.placeholder_text = "可留空"
	_add_control_row(root, "开发商", _developer_field)

	_publisher_field = LineEdit.new()
	_publisher_field.placeholder_text = "可留空"
	_add_control_row(root, "发行商", _publisher_field)

	_year_field = LineEdit.new()
	_year_field.placeholder_text = "例如 2017，可留空"
	_add_control_row(root, "发行年份", _year_field)

	_tags_field = LineEdit.new()
	_tags_field.placeholder_text = "用逗号分隔，例如：生存, 平台, 探索"
	_add_control_row(root, "标签", _tags_field)

	_genres_field = LineEdit.new()
	_genres_field.placeholder_text = "用逗号分隔，例如：动作, 角色扮演"
	_add_control_row(root, "类型", _genres_field)

	var desc_label := Label.new()
	desc_label.text = "简介"
	root.add_child(desc_label)

	_description = TextEdit.new()
	_description.custom_minimum_size = Vector2(0, 200)
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

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_save)
	buttons.add_child(save_button)

func _add_control_row(root: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func show_metadata(item_id: String, metadata: Dictionary) -> void:
	_item_id = item_id
	_error_label.visible = false
	_title_field.text = str(metadata.get("title", ""))
	_english_name_field.text = str(metadata.get("english_name", ""))
	_rebuild_platforms(str(metadata.get("platform", "")))
	_developer_field.text = str(metadata.get("developer", ""))
	_publisher_field.text = str(metadata.get("publisher", ""))
	_year_field.text = _format_year(metadata.get("release_year"))
	_tags_field.text = str(metadata.get("tags", ""))
	_genres_field.text = str(metadata.get("genres", ""))	
	_description.text = str(metadata.get("description", ""))

	# 自适应父窗口尺寸
	var parent_win: Window = null
	if get_parent() != null:
		parent_win = get_parent().get_window()
	if parent_win != null:
		var target_w: int = mini(700, maxi(580, parent_win.size.x - 80))
		var target_h: int = mini(600, maxi(500, parent_win.size.y - 80))
		size = Vector2i(target_w, target_h)
	popup_centered()

func _rebuild_platforms(current: String) -> void:
	var options: Array[String] = _platforms
	if options.is_empty():
		options = DEFAULT_PLATFORMS
	_platform_option.clear()
	for p in options:
		_platform_option.add_item(p)
	var clean: String = current.strip_edges()
	if clean.is_empty():
		return
	if _platform_option.item_count > 0:
		_platform_option.select(0)
	var idx: int = options.find(clean)
	if idx >= 0:
		_platform_option.select(idx)
	else:
		# 库里存的平台不在候选表里：追加一项，避免保存时被改写
		_platform_option.add_item(clean)
		_platform_option.select(_platform_option.item_count - 1)

func _format_year(raw: Variant) -> String:
	if raw == null:
		return ""
	var text: String = str(raw).strip_edges()
	if text.ends_with(".0"):
		text = text.substr(0, text.length() - 2)
	if text == "0" or text == "None":
		return ""
	return text

func _save() -> void:
	var clean_title: String = _title_field.text.strip_edges()
	if clean_title.is_empty():
		_show_error("请输入标题")
		return
	var platform_text: String = ""
	if _platform_option.item_count > 0 and _platform_option.selected >= 0:
		platform_text = _platform_option.get_item_text(_platform_option.selected)
	save_requested.emit(
		_item_id,
		{
			"title": clean_title,
			"english_name": _english_name_field.text.strip_edges(),			
			"platform": platform_text,
			"developer": _developer_field.text.strip_edges(),
			"publisher": _publisher_field.text.strip_edges(),
			"release_year": _year_field.text.strip_edges(),
			"tags": _tags_field.text.strip_edges(),
			"genres": _genres_field.text.strip_edges(),
			"description": _description.text.strip_edges(),
		}
	)
	hide()

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true

func _localize_context_menus() -> void:
	TEXT_MENU_LOCALIZER.localize_tree(self)
