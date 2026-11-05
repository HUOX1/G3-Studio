extends "res://scripts/game_menu_overlay.gd"
class_name G3GameManageMenu

## 游戏卡片右键菜单。WB-04.1-E：改为毛玻璃浮层（见 game_menu_overlay.gd），
## 菜单项、顺序、间距与动作分发保持原样。

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
const MENU_WIDTH: float = 220.0
const ITEM_FONT_SIZE: int = 14

var _action_buttons: Array[Button] = []

func _ready() -> void:
	name = "GameManageMenu"
	super()

func _build_content() -> void:
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
	_add_action_button("移除", 8, true)

func _add_action_button(label_text: String, action_id: int, danger: bool = false) -> void:
	var button: Button = make_item(label_text, ITEM_FONT_SIZE, Vector2(200.0, 30.0), danger)
	button.pressed.connect(_on_action_pressed.bind(action_id))
	_action_buttons.append(button)

func show_at(screen_position: Vector2, can_edit_playtime: bool = true) -> void:
	# 按需隐藏「修改游玩时长…」（Steam 游戏 / 已用完 2 次修改）
	var idx: int = ACTIONS.find("edit_playtime")
	if idx >= 0 and idx < _action_buttons.size():
		_action_buttons[idx].visible = can_edit_playtime
	show_menu_at(screen_position, MENU_WIDTH)

func _on_action_pressed(action_id: int) -> void:
	close()
	if action_id < 0 or action_id >= ACTIONS.size():
		return
	action_requested.emit(ACTIONS[action_id])
