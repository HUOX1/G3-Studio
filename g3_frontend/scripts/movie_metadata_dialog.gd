extends Window
class_name G3MovieMetadataDialog

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

signal save_requested(item_id: String, metadata: Dictionary)

var _item_id: String = ""
var _title_field: LineEdit
var _year_field: LineEdit
var _tagline_field: LineEdit
var _description: TextEdit

func _ready() -> void:
	title = "编辑电影资料"
	size = Vector2i(700, 560)
	min_size = Vector2i(600, 480)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	call_deferred("_localize_context_menus")
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title_field = LineEdit.new()
	_add_control_row(root, "标题", _title_field)

	_year_field = LineEdit.new()
	_year_field.placeholder_text = "例如 1982，可留空"
	_add_control_row(root, "年份", _year_field)

	_tagline_field = LineEdit.new()
	_tagline_field.placeholder_text = "一句标语，会显示在隐藏层里"
	_add_control_row(root, "标语", _tagline_field)

	var desc_label := Label.new()
	desc_label.text = "简介"
	root.add_child(desc_label)

	_description = TextEdit.new()
	_description.custom_minimum_size = Vector2(0, 220)
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(_description)

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
	_title_field.text = str(metadata.get("title", ""))
	var year_raw = metadata.get("release_year", "")
	var year_text: String = ""
	if year_raw != null:
		year_text = str(year_raw).strip_edges()
		if year_text.ends_with(".0"):
			year_text = year_text.substr(0, year_text.length() - 2)
		if year_text == "0" or year_text == "None":
			year_text = ""
	_year_field.text = year_text
	_tagline_field.text = str(metadata.get("tagline", ""))
	_description.text = str(metadata.get("description", ""))
	popup_centered()

func _save() -> void:
	var clean_title: String = _title_field.text.strip_edges()
	if clean_title.is_empty():
		return
	save_requested.emit(
		_item_id,
		{
			"title": clean_title,
			"release_year": _year_field.text.strip_edges(),
			"tagline": _tagline_field.text.strip_edges(),
			"description": _description.text.strip_edges(),
		}
	)
	hide()

func _localize_context_menus() -> void:
	TEXT_MENU_LOCALIZER.localize_tree(self)