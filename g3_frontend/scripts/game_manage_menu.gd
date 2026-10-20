extends PopupPanel
class_name G3GameManageMenu

signal action_requested(action: String)

const ACTIONS: Array[String] = [
	"scrape_sgdb",
	"steam_metadata",
	"edit_metadata",
	"paste_import",
	"browse_game_dir",
	"browse_assets_dir",
	"edit_launch",
	"edit_playtime",
	"remove",
]

var _root: VBoxContainer
var _action_buttons: Array[Button] = []

func _ready() -> void:
	name = "GameManageMenu"
	size = Vector2i(220, 256)
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

	_add_action_button("从 SteamGridDB 获取素材…", 0)
	_add_action_button("从 Steam 获取资料…", 1)
	_add_action_button("编辑资料…", 2)
	_add_action_button("从文本粘贴资料…", 3)
	_add_action_button("浏览游戏目录…", 4)
	_add_action_button("浏览素材文件夹…", 5)
	_add_action_button("编辑启动设置…", 6)
	_add_action_button("修改游玩时长…", 7)
	var sep := HSeparator.new()
	_root.add_child(sep)
	_add_action_button("移除", 8)

func _add_action_button(label_text: String, action_id: int) -> void:
	var button := Button.new()
	button.text = label_text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(200.0, 30.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.pressed.connect(_on_action_pressed.bind(action_id))
	_root.add_child(button)
	_action_buttons.append(button)

func show_at(screen_position: Vector2, can_edit_playtime: bool = true) -> void:
	# 按需隐藏「修改游玩时长…」（Steam 游戏 / 已用完 2 次修改）
	var idx: int = ACTIONS.find("edit_playtime")
	if idx >= 0 and idx < _action_buttons.size():
		_action_buttons[idx].visible = can_edit_playtime
	position = Vector2i(int(screen_position.x), int(screen_position.y))
	popup()
	grab_focus()

func _on_action_pressed(action_id: int) -> void:
	hide()
	if action_id < 0 or action_id >= ACTIONS.size():
		return
	action_requested.emit(ACTIONS[action_id])