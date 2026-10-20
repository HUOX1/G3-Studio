extends PopupPanel
class_name G3MovieBlankMenu

signal action_requested(action: String)

var _root: VBoxContainer

func _ready() -> void:
    name = "MovieBlankMenu"
    size = Vector2i(196, 84)
    _build_ui()
    hide()

func _build_ui() -> void:
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    add_child(margin)

    _root = VBoxContainer.new()
    _root.add_theme_constant_override("separation", 4)
    margin.add_child(_root)

    _add_button("添加电影…", "add_movie")
    _add_button("扫描影视库", "scan_library")

func _add_button(label_text: String, action: String) -> void:
    var button: Button = Button.new()
    button.text = label_text
    button.flat = true
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(176.0, 28.0)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
    button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
    button.pressed.connect(func(): _on_action_pressed(action))
    _root.add_child(button)

func show_at(screen_position: Vector2) -> void:
    position = Vector2i(int(screen_position.x), int(screen_position.y))
    popup()
    grab_focus()

func _on_action_pressed(action: String) -> void:
    hide()
    action_requested.emit(action)