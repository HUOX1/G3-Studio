extends Window
class_name G3PlaytimeEditDialog

signal save_requested(item_id: String, seconds: int)

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

const COLOR_ERROR: Color = Color(0.95, 0.45, 0.42)

var _item_id: String = ""
var _hours_field: LineEdit
var _hint_label: Label
var _error_label: Label

func _ready() -> void:
	title = "修改游玩时长"
	size = Vector2i(460, 240)
	min_size = Vector2i(400, 220)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var head := Label.new()
	head.text = "修改游玩时长"
	head.add_theme_font_size_override("font_size", 15)
	root.add_child(head)

	_hint_label = Label.new()
	_hint_label.text = "输入小时数，支持小数（如 812.35）"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_hint_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	_hours_field = LineEdit.new()
	_hours_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hours_field.text_submitted.connect(_on_text_submitted)
	row.add_child(_hours_field)

	var unit := Label.new()
	unit.text = "小时"
	unit.custom_minimum_size = Vector2(48.0, 0.0)
	row.add_child(unit)

	_error_label = Label.new()
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.add_theme_color_override("font_color", COLOR_ERROR)
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

func show_for(item_id: String, current_seconds: int) -> void:
	_item_id = item_id
	_hours_field.text = "%.2f" % (float(current_seconds) / 3600.0)
	_error_label.visible = false
	popup_centered()
	_hours_field.grab_focus()
	_hours_field.select_all()

func _on_text_submitted(_text: String) -> void:
	_save()

func _save() -> void:
	var text: String = _hours_field.text.strip_edges()
	if text.is_empty():
		_show_error("请输入小时数")
		return
	# 用 is_valid_float 判定，避免 "abc" 被 to_float() 静默当成 0
	if not text.is_valid_float():
		_show_error("请输入有效的数字")
		return
	var hours: float = text.to_float()
	if hours < 0.0:
		_show_error("不能为负数")
		return
	var seconds: int = int(round(hours * 3600.0))
	save_requested.emit(_item_id, seconds)
	hide()

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true
