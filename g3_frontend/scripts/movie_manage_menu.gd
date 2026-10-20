extends PopupPanel
class_name G3MovieManageMenu

signal action_requested(action: String)

const ACTIONS: Array[String] = [
	"edit_metadata",
	"set_cover",
	"select_poster",
	"set_backdrop",
	"refresh_backdrop",
	"tmdb_scrape",
	"remove",
]

var _root: VBoxContainer
var _action_buttons: Array[Button] = []
var _separator: HSeparator

func _ready() -> void:
	name = "MovieManageMenu"
	size = Vector2i(196, 256)
	_build_ui()
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 4)
	margin.add_child(_root)

	_add_action_button("编辑资料", 0)
	_add_action_button("设置封面…", 1)
	_add_action_button("选择海报…", 2)
	_add_action_button("设置背景图…", 3)
	_add_action_button("重新截取预览图", 4)
	_add_action_button("从 TMDB 获取资料…", 5)
	_add_separator()
	_add_action_button("移除", 6)

func _add_action_button(label_text: String, action_id: int) -> void:
	var button := Button.new()
	button.text = label_text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(176.0, 28.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.pressed.connect(_on_action_pressed.bind(action_id))
	_root.add_child(button)
	_action_buttons.append(button)

func _add_separator() -> void:
	_separator = HSeparator.new()
	_root.add_child(_separator)

func show_at(screen_position: Vector2, scope: String = "main") -> void:
	_apply_scope(scope)
	position = Vector2i(int(screen_position.x), int(screen_position.y))
	popup()
	grab_focus()

func _apply_scope(scope: String) -> void:
	# 私有库：隐藏"选择海报…"和"从 TMDB 获取资料…"
	var tmdb_enabled: bool = (scope != "private")
	if _action_buttons.size() >= 7:
		_action_buttons[2].visible = tmdb_enabled   # 选择海报…
		_action_buttons[5].visible = tmdb_enabled   # 从 TMDB 获取资料…

func _on_action_pressed(action_id: int) -> void:
	hide()
	if action_id < 0 or action_id >= ACTIONS.size():
		return
	action_requested.emit(ACTIONS[action_id])