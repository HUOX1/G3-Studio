extends Control

signal pressed

var _accent: Color = Color(0.43, 0.69, 0.76, 1.0)
var _hovered: bool = false
var _expanded: bool = false
var _interactive: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "拉出开始游戏面板"
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_accent(accent: Color) -> void:
	_accent = accent
	queue_redraw()


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	tooltip_text = "收回开始游戏面板" if expanded else "拉出开始游戏面板"
	queue_redraw()


func set_interactive(interactive: bool) -> void:
	_interactive = interactive
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed and _interactive:
			pressed.emit()


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return

	var alpha: float = 1.0 if _interactive else 0.42
	var base := Color(0.026, 0.040, 0.047, 0.98)
	if _hovered and _interactive:
		base = base.lightened(0.12)
	var edge := Color(_accent.r, _accent.g, _accent.b, 0.72 * alpha)
	var edge_dim := Color(_accent.r, _accent.g, _accent.b, 0.24 * alpha)

	# A chamfered metal end cap, mechanically aligned to the loader's left edge.
	var plate := PackedVector2Array([
		Vector2(0.0, 7.0), Vector2(6.0, 1.0),
		Vector2(w, 1.0), Vector2(w, h - 1.0),
		Vector2(6.0, h - 1.0), Vector2(0.0, h - 7.0)
	])
	draw_colored_polygon(plate, base)
	var outline := plate.duplicate()
	outline.append(plate[0])
	draw_polyline(outline, edge, 1.15, true)

	# Recessed grip channel with three machined ribs.
	var channel := Rect2(w * 0.22, h * 0.16, w * 0.48, h * 0.68)
	draw_rect(channel, Color(0.006, 0.014, 0.018, 0.96), true)
	draw_rect(channel, edge_dim, false, 1.0, true)
	for i in range(3):
		var y: float = channel.position.y + channel.size.y * (0.30 + 0.20 * float(i))
		draw_line(Vector2(channel.position.x + 3.0, y), Vector2(channel.end.x - 3.0, y), Color(0.72, 0.80, 0.82, 0.36 * alpha), 1.0, true)
		draw_line(Vector2(channel.position.x + 3.0, y + 1.6), Vector2(channel.end.x - 3.0, y + 1.6), Color(0.0, 0.0, 0.0, 0.62), 0.9, true)

	# A slim seam on the panel-facing side makes the tab feel integrated, not detached.
	draw_line(Vector2(w - 2.0, 8.0), Vector2(w - 2.0, h - 8.0), Color(0.76, 0.82, 0.83, 0.22 * alpha), 1.0, true)
	for y in [h * 0.16, h * 0.84]:
		draw_circle(Vector2(w * 0.82, y), 2.2, Color(0.008, 0.015, 0.018, 1.0))
		draw_circle(Vector2(w * 0.82, y), 1.0, edge_dim)

	var lamp_center := Vector2(w * 0.82, h * 0.50)
	draw_circle(lamp_center, 7.0, Color(_accent.r, _accent.g, _accent.b, 0.055 * alpha))
	draw_circle(lamp_center, 4.0, Color(_accent.r, _accent.g, _accent.b, 0.12 * alpha))
	draw_circle(lamp_center, 1.5, Color(_accent.r, _accent.g, _accent.b, 0.92 * alpha))

	# Small directional mark: pull outward to reveal, push inward to stow.
	var arrow := Vector2(w * 0.50, h * 0.94)
	var arrow_color := Color(0.80, 0.87, 0.89, 0.76 * alpha)
	if _expanded:
		draw_line(arrow + Vector2(-3.0, -2.0), arrow + Vector2(1.0, 0.0), arrow_color, 1.1, true)
		draw_line(arrow + Vector2(1.0, 0.0), arrow + Vector2(-3.0, 2.0), arrow_color, 1.1, true)
	else:
		draw_line(arrow + Vector2(3.0, -2.0), arrow + Vector2(-1.0, 0.0), arrow_color, 1.1, true)
		draw_line(arrow + Vector2(-1.0, 0.0), arrow + Vector2(3.0, 2.0), arrow_color, 1.1, true)
