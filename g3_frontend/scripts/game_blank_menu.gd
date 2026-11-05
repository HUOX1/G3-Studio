extends "res://scripts/game_menu_overlay.gd"
class_name G3GameBlankMenu

## 空白处右键菜单。WB-04.1-E：与卡片菜单共用毛玻璃浮层外壳，
## 菜单项、顺序与动作分发保持原样。

signal action_requested(action: String)

const MENU_WIDTH: float = 196.0
const ITEM_FONT_SIZE: int = 18

func _ready() -> void:
	name = "GameBlankMenu"
	super()

func _build_content() -> void:
	_add_button("添加游戏…", "add_game")
	_add_button("从文本粘贴资料…", "paste_import")
	_add_button("扫描游戏库…", "scan_library")

func _add_button(label_text: String, action: String) -> void:
	var button: Button = make_item(label_text, ITEM_FONT_SIZE, Vector2(176.0, 28.0))
	button.pressed.connect(func(): _on_action_pressed(action))

func show_at(screen_position: Vector2) -> void:
	show_menu_at(screen_position, MENU_WIDTH)

func _on_action_pressed(action: String) -> void:
	close()
	action_requested.emit(action)
