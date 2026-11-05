extends Button
## Isolated optical-drive front-panel prototype. Clicking only previews the mechanism;
## it never calls the real game-launch pipeline.

signal demo_state_changed(state: String)

const HI_FI_DECK: int = 0
const SLIM_LOADER: int = 1
const DESIGN_SCALE: float = 1.3
const DESIGN_HEIGHT: float = 104.0
const DISC_RADIUS: float = 28.0
const SLOT_HEIGHT: float = 72.0

var _variant: int = HI_FI_DECK
var _panel_width: float = 400.0
var _disc_x: float = 0.0:
	set(value):
		_disc_x = value
		queue_redraw()
var _disc_rotation: float = 0.0
var _circuit_time: float = 0.0
var _tray_offset_x: float = 0.0:
	set(value):
		_tray_offset_x = value
		queue_redraw()
var _internal_reveal: float = 0.0:
	set(value):
		_internal_reveal = clampf(value, 0.0, 1.0)
		queue_redraw()
var _theme_accent: Color = Color(0.78, 0.57, 0.30, 1.0):
	set(value):
		_theme_accent = value
		queue_redraw()
var _theme_tint_enabled: bool = false
var _hovered: bool = false
var _busy: bool = false
var _spinning: bool = false
var _state: String = "READY"
var _demo_tween: Tween = null
var _hover_tween: Tween = null
var _theme_tween: Tween = null

func _ready() -> void:
	text = ""
	tooltip_text = "点击模拟光盘吸入、读取与退盘；不会启动真实游戏"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(_panel_width * DESIGN_SCALE, DESIGN_HEIGHT * DESIGN_SCALE)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(animate_insert)
	_disc_x = _rest_disc_x()
	set_process(false)

func set_drive_variant(variant: int) -> void:
	_variant = clampi(variant, HI_FI_DECK, SLIM_LOADER)
	queue_redraw()

func set_theme_accent(accent: Color, transition_seconds: float = 0.68) -> void:
	if _theme_tween != null and _theme_tween.is_running():
		_theme_tween.kill()
	_theme_tint_enabled = true
	if transition_seconds <= 0.0:
		_theme_accent = accent
		return
	_theme_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_theme_tween.tween_property(self, "_theme_accent", accent, transition_seconds)

func apply_game_theme_palette(palette: Dictionary) -> void:
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent_value: Variant = colors.get("accent", "")
	if typeof(accent_value) == TYPE_COLOR:
		set_theme_accent(accent_value)
	elif not str(accent_value).strip_edges().is_empty():
		set_theme_accent(Color.from_string(str(accent_value), _theme_accent))

func reset_game_theme_palette() -> void:
	if _theme_tween != null and _theme_tween.is_running():
		_theme_tween.kill()
	_theme_tint_enabled = true
	_theme_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_theme_tween.tween_property(self, "_theme_accent", _default_variant_accent(), 0.68)
	_theme_tween.tween_callback(_finish_theme_reset)

func _finish_theme_reset() -> void:
	_theme_tint_enabled = false
	queue_redraw()

func set_panel_width(width: float) -> void:
	if _busy:
		reset_demo()
	_kill_hover_tween()
	_panel_width = clampf(width / DESIGN_SCALE, 380.0, 520.0)
	custom_minimum_size.x = _panel_width * DESIGN_SCALE
	if not _busy:
		_disc_x = _rest_disc_x()
	queue_redraw()

func reset_demo() -> void:
	_kill_hover_tween()
	if _demo_tween != null and _demo_tween.is_running():
		_demo_tween.kill()
	_demo_tween = null
	_busy = false
	_spinning = false
	_hovered = false
	_disc_rotation = 0.0
	_circuit_time = 0.0
	_disc_x = _rest_disc_x()
	_tray_offset_x = 0.0
	_internal_reveal = 0.0
	_set_state("READY")
	set_process(false)

func animate_insert() -> void:
	if _busy:
		return
	_kill_hover_tween()
	if _demo_tween != null and _demo_tween.is_running():
		_demo_tween.kill()
	_busy = true
	_spinning = false
	_disc_rotation = 0.0
	_circuit_time = 0.0
	_disc_x = _rest_disc_x()
	_tray_offset_x = 0.0
	_internal_reveal = 0.0
	_set_state("INSERTING")
	set_process(true)
	_demo_tween = create_tween()
	# Stage 1: the disc approaches the mouth by itself; the tray remains extended.
	_demo_tween.tween_interval(0.05)
	_demo_tween.tween_property(self, "_disc_x", _approach_disc_x(), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_demo_tween.tween_interval(0.045)
	# Stage 2: the same visible disc and its tray retract together through the slot.
	var retract_distance: float = _inserted_disc_x() - _approach_disc_x()
	_demo_tween.tween_property(self, "_disc_x", _inserted_disc_x(), 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_demo_tween.parallel().tween_property(self, "_tray_offset_x", retract_distance, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	# Only after the disc has fully entered do the inner chassis and electronics appear.
	_demo_tween.tween_property(self, "_internal_reveal", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_demo_tween.tween_callback(_begin_reading)
	_demo_tween.tween_interval(0.72)
	_demo_tween.tween_callback(_begin_booting)

func animate_eject() -> void:
	if _state == "READY":
		return
	_kill_hover_tween()
	if _demo_tween != null and _demo_tween.is_running():
		_demo_tween.kill()
	_busy = true
	_spinning = false
	_set_state("EJECTING")
	set_process(true)
	_demo_tween = create_tween()
	_demo_tween.tween_property(self, "_disc_x", _rest_disc_x(), 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_demo_tween.parallel().tween_property(self, "_tray_offset_x", 0.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_demo_tween.parallel().tween_property(self, "_internal_reveal", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_demo_tween.tween_callback(_finish_demo)

func _begin_reading() -> void:
	_spinning = true
	_set_state("READING")

func _begin_booting() -> void:
	# Hold the loaded disc and the internal chassis view until the user resets/ejects the demo.
	_spinning = true
	_busy = true
	_set_state("BOOTING")

func _finish_demo() -> void:
	_busy = false
	_spinning = false
	_disc_rotation = 0.0
	_circuit_time = 0.0
	_disc_x = _rest_disc_x()
	_tray_offset_x = 0.0
	_internal_reveal = 0.0
	_set_state("READY")
	set_process(false)

func get_demo_state() -> String:
	return _state

func _set_state(value: String) -> void:
	if _state == value:
		return
	_state = value
	demo_state_changed.emit(_state)
	queue_redraw()

func _process(delta: float) -> void:
	if _spinning:
		_disc_rotation = fposmod(_disc_rotation + delta * 8.0, TAU)
	if _internal_reveal > 0.001:
		_circuit_time += delta
	if _spinning or _internal_reveal > 0.001:
		queue_redraw()

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()
	if not _busy:
		_kill_hover_tween()
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "_disc_x", _rest_disc_x() - 6.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()
	if not _busy:
		_kill_hover_tween()
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "_disc_x", _rest_disc_x(), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _kill_hover_tween() -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = null

func _drive_width() -> float:
	return maxf(_panel_width, size.x / DESIGN_SCALE)

func _slot_x() -> float:
	return _drive_width() - 145.0

func _rest_disc_x() -> float:
	return _slot_x() + DISC_RADIUS + 26.0

func _approach_disc_x() -> float:
	return _slot_x() + DISC_RADIUS + 2.0

func _inserted_disc_x() -> float:
	# The disc is fully captured behind the faceplate; the slot mouth remains visible.
	return _slot_x() - DISC_RADIUS - 18.0

func _draw_cut_panel(points: PackedVector2Array, fill: Color, border: Color) -> void:
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border, 1.0, false)

func _draw_disc(center: Vector2, radius: float, accent: Color) -> void:
	# Keep the disc silhouette and center hub, not any bright concentric outlines.
	# The previous tray well and reflective draw_arc rings read as a separate white circle.
	draw_circle(center, radius, Color(0.44, 0.47, 0.48, 1.0))
	draw_circle(center, radius - 3.0, Color(0.50, 0.53, 0.53, 0.84))
	draw_circle(center, radius * 0.57, Color(0.46, 0.49, 0.50, 0.42))
	for mark_index in range(8):
		var angle: float = _disc_rotation + float(mark_index) * TAU / 8.0
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * 9.0
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * 15.0
		draw_line(inner, outer, Color(0.22, 0.26, 0.27, 0.28), 0.75, true)
	draw_circle(center, 5.4, Color(0.075, 0.09, 0.10, 1.0))
	draw_circle(center, 1.5, accent.darkened(0.20))

func _default_variant_accent() -> Color:
	return Color(0.78, 0.57, 0.30, 1.0) if _variant == HI_FI_DECK else Color(0.43, 0.69, 0.76, 1.0)

func _effective_accent() -> Color:
	return _theme_accent if _theme_tint_enabled else _default_variant_accent()

func _draw_internal_chassis(slot_x: float, height: float, accent: Color) -> void:
	# Smoked translucent electronics window is INSIDE the chassis on the LEFT of the slot.
	# The body window, PCB and components appear only after the single animated disc
	# has completed its travel. There is no second, independently drawn "internal disc".
	var reveal: float = _internal_reveal
	if reveal <= 0.001:
		return
	var left: float = maxf(112.0, slot_x - 108.0)
	var right: float = slot_x - 13.0
	var span: float = right - left
	if span < 16.0:
		return
	var top: float = 21.0
	var bottom: float = height - 21.0
	if span < 35.0:
		return
	# A small populated PCB under the translucent resin: chips, solder pads and copper traces.
	var board_alpha: float = 0.30 * reveal
	draw_rect(Rect2(left + 5.0, top + 8.0, span - 10.0, bottom - top - 16.0), Color(0.045, 0.095, 0.089, board_alpha), true)
	var center_y: float = height * 0.5
	var board_left: float = left + 8.0
	var board_right: float = right - 7.0
	var trace_color: Color = Color(0.30, 0.48, 0.42, 0.26 * reveal)
	var upper_path := PackedVector2Array([
		Vector2(board_left, center_y - 16.0),
		Vector2(board_left + span * 0.36, center_y - 16.0),
		Vector2(board_left + span * 0.36, center_y - 6.0),
		Vector2(board_right, center_y - 6.0),
	])
	var lower_path := PackedVector2Array([
		Vector2(board_left, center_y + 16.0),
		Vector2(board_left + span * 0.62, center_y + 16.0),
		Vector2(board_left + span * 0.62, center_y + 6.0),
		Vector2(board_right, center_y + 6.0),
	])
	draw_polyline(upper_path, trace_color, 1.05, true)
	draw_polyline(lower_path, trace_color, 1.05, true)
	# Exposed components are intentionally small and flat, rather than visible mechanics.
	draw_rect(Rect2(left + 12.0, center_y - 5.0, 16.0, 11.0), Color(0.035, 0.060, 0.068, 0.76 * reveal), true)
	draw_rect(Rect2(left + 14.0, center_y - 3.0, 12.0, 7.0), Color(0.12, 0.20, 0.21, 0.42 * reveal), true)
	draw_rect(Rect2(right - 22.0, center_y - 16.0, 11.0, 8.0), Color(0.035, 0.060, 0.070, 0.62 * reveal), true)
	# Three surface-mounted LEDs blink at different phases after the disc is captured.
	for led_index in range(3):
		var led_x: float = board_left + (float(led_index) + 0.7) * (span - 18.0) / 3.0
		var led_y: float = center_y + (11.0 if led_index == 1 else -12.0)
		var brightness: float = 0.22 + 0.78 * pow(0.5 + 0.5 * sin(_circuit_time * (4.2 + float(led_index)) + float(led_index) * 2.1), 3.0)
		var light_alpha: float = reveal * brightness
		# Wide, low-opacity bloom is the light diffusing through smoked transparent plastic.
		draw_circle(Vector2(led_x, led_y), 16.0, Color(accent.r, accent.g, accent.b, 0.035 * light_alpha))
		draw_circle(Vector2(led_x, led_y), 11.0, Color(accent.r, accent.g, accent.b, 0.065 * light_alpha))
		draw_circle(Vector2(led_x, led_y), 6.0, Color(accent.r, accent.g, accent.b, 0.13 * light_alpha))
		draw_circle(Vector2(led_x, led_y), 2.2, Color(accent.r, accent.g, accent.b, 0.90 * light_alpha))
		draw_circle(Vector2(led_x, led_y), 0.9, Color(0.94, 0.98, 1.0, 0.72 * light_alpha))
	# A moving data pulse travels along each circuit trace, not across the entire glass cover.
	var signal_1: float = fposmod(_circuit_time * 0.72, 1.0)
	var signal_2: float = fposmod(_circuit_time * 0.72 + 0.49, 1.0)
	_draw_circuit_pulse(upper_path, signal_1, accent, reveal)
	_draw_circuit_pulse(lower_path, signal_2, accent, reveal)

func _draw_chassis_glass_overlay(slot_x: float, height: float, accent: Color) -> void:
	if _internal_reveal <= 0.001:
		return
	var left: float = maxf(112.0, slot_x - 108.0)
	# Extend the smoked cover into the optical bezel. The bezel is drawn afterwards,
	# so both pieces share one physical seam instead of reading as separate modules.
	var right: float = slot_x - 8.0
	var top: float = 21.0
	var bottom: float = height - 21.0
	var span: float = right - left
	if span < 35.0:
		return
	var reveal: float = clampf(_internal_reveal, 0.0, 1.0)
	# One continuous smoked-plastic cover; its right edge tucks under the slot bezel.
	var shell := PackedVector2Array([
		Vector2(left + 5.0, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left + 5.0, bottom),
		Vector2(left, bottom - 5.0),
		Vector2(left, top + 5.0)
	])
	draw_colored_polygon(shell, Color(0.095, 0.135, 0.145, 0.36 * reveal))
	# A second, very light smoked veil increases the acrylic haze without hiding the disc.
	draw_colored_polygon(shell, Color(0.17, 0.205, 0.21, 0.055 * reveal))
	# The cover's top and bottom reflections run directly into the bezel, visually joining them.
	draw_line(Vector2(left + 8.0, top + 1.0), Vector2(right + 1.0, top + 1.0), Color(0.62, 0.73, 0.74, 0.24 * reveal), 1.0, false)
	draw_line(Vector2(left + 8.0, bottom - 1.0), Vector2(right + 1.0, bottom - 1.0), Color(accent.r, accent.g, accent.b, 0.10 * reveal), 1.0, false)
	# Left seam and soft internal reflection; no separate right seam at the joined interface.
	draw_line(Vector2(left + 1.0, top + 8.0), Vector2(left + 1.0, bottom - 8.0), Color(0.48, 0.60, 0.62, 0.24 * reveal), 1.0, false)
	draw_rect(Rect2(left + 7.0, top + 8.0, 2.0, bottom - top - 16.0), Color(0.78, 0.88, 0.88, 0.06 * reveal), true)

func _draw_circuit_pulse(path: PackedVector2Array, progress: float, accent: Color, reveal: float) -> void:
	if path.size() < 2:
		return
	var segment_f: float = progress * float(path.size() - 1)
	var segment: int = mini(int(segment_f), path.size() - 2)
	var position_on_trace: Vector2 = path[segment].lerp(path[segment + 1], segment_f - float(segment))
	draw_circle(position_on_trace, 11.0, Color(accent.r, accent.g, accent.b, 0.035 * reveal))
	draw_circle(position_on_trace, 7.0, Color(accent.r, accent.g, accent.b, 0.075 * reveal))
	draw_circle(position_on_trace, 3.2, Color(accent.r, accent.g, accent.b, 0.22 * reveal))
	draw_circle(position_on_trace, 1.5, Color(0.94, 0.98, 1.0, 0.82 * reveal))

func _draw_dvd_tray(slot_x: float, height: float) -> void:
	var center_y: float = height * 0.5
	var left: float = slot_x + 4.0 + _tray_offset_x
	var right: float = _rest_disc_x() + DISC_RADIUS - 6.0 + _tray_offset_x
	if right <= left:
		return
	var shadow := PackedVector2Array([
		Vector2(left + 2.0, center_y - 17.0), Vector2(right - 7.0, center_y - 17.0),
		Vector2(right + 3.0, center_y - 8.0), Vector2(right + 3.0, center_y + 19.0),
		Vector2(right - 8.0, center_y + 27.0), Vector2(left + 8.0, center_y + 27.0),
		Vector2(left, center_y + 18.0), Vector2(left, center_y - 10.0)
	])
	var shadow_shifted := shadow.duplicate()
	for index in range(shadow_shifted.size()):
		shadow_shifted[index] += Vector2(0.0, 3.0)
	draw_colored_polygon(shadow_shifted, Color(0.0, 0.0, 0.0, 0.48))
	draw_colored_polygon(shadow, Color(0.12, 0.15, 0.17, 0.98))
	var inset := PackedVector2Array([
		Vector2(left + 5.0, center_y - 13.0), Vector2(right - 9.0, center_y - 13.0),
		Vector2(right - 3.0, center_y - 7.0), Vector2(right - 3.0, center_y + 14.0),
		Vector2(right - 11.0, center_y + 21.0), Vector2(left + 11.0, center_y + 21.0),
		Vector2(left + 5.0, center_y + 15.0)
	])
	draw_colored_polygon(inset, Color(0.19, 0.23, 0.25, 0.96))
	draw_polyline(PackedVector2Array([shadow[0], shadow[1], shadow[2], shadow[3]]), Color(0.72, 0.77, 0.77, 0.42), 1.0, true)
	draw_line(Vector2(left + 8.0, center_y - 10.0), Vector2(right - 12.0, center_y - 10.0), Color(0.75, 0.80, 0.80, 0.22), 1.0, true)
	draw_line(Vector2(left + 11.0, center_y + 17.0), Vector2(right - 14.0, center_y + 17.0), Color(0.015, 0.022, 0.026, 0.82), 1.2, true)
	# No disc-sized well outline: it previously appeared as an unwanted white circle behind the disc.
	draw_line(Vector2(left + 13.0, center_y - 5.0), Vector2(left + 13.0, center_y + 11.0), Color(0.72, 0.77, 0.77, 0.28), 1.0, true)
	draw_line(Vector2(right - 14.0, center_y - 5.0), Vector2(right - 14.0, center_y + 11.0), Color(0.02, 0.03, 0.035, 0.70), 1.0, true)

func _draw_slot_bezel(slot_x: float, height: float, accent: Color) -> void:
	var top: float = 10.0
	var bottom: float = height - 10.0
	# Compact front bezel: one restrained raised face, one recessed throat,
	# and two asymmetric inner edges. No detached black backing/shadow block.
	var outer := PackedVector2Array([
		Vector2(slot_x - 9.0, top + 3.0),
		Vector2(slot_x - 6.0, top),
		Vector2(slot_x + 6.0, top),
		Vector2(slot_x + 9.0, top + 3.0),
		Vector2(slot_x + 9.0, bottom - 3.0),
		Vector2(slot_x + 6.0, bottom),
		Vector2(slot_x - 6.0, bottom),
		Vector2(slot_x - 9.0, bottom - 3.0)
	])
	_draw_cut_panel(outer, Color(0.105, 0.13, 0.14, 1.0), Color(0.34, 0.41, 0.42, 0.72))
	# A single narrow dark channel sits inside the metal lip.
	draw_rect(Rect2(slot_x - 3.0, top + 5.0, 6.0, bottom - top - 10.0), Color(0.008, 0.013, 0.016, 1.0), true)
	# Left inner wall catches a little light; right wall stays darker to imply depth.
	draw_line(Vector2(slot_x - 4.0, top + 7.0), Vector2(slot_x - 4.0, bottom - 7.0), Color(0.58, 0.66, 0.67, 0.42), 1.0, false)
	draw_line(Vector2(slot_x + 3.0, top + 7.0), Vector2(slot_x + 3.0, bottom - 7.0), Color(0.0, 0.0, 0.0, 0.88), 1.0, false)
	# Minimal lower lip reflection ties the recess to the faceplate.
	draw_line(Vector2(slot_x - 2.0, bottom - 7.0), Vector2(slot_x + 2.0, bottom - 7.0), Color(accent.r, accent.g, accent.b, 0.16), 1.0, false)

func _draw_slot_glow(slot_x: float, height: float, accent: Color) -> void:
	var glow_level: float = 0.28 if not _hovered and not _busy else (0.82 if _hovered and not _busy else 1.0)
	if _busy:
		glow_level *= 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.009))
	draw_rect(Rect2(slot_x - 5.0, 15.0, 10.0, height - 30.0), Color(accent.r, accent.g, accent.b, 0.045 * glow_level), true)
	draw_rect(Rect2(slot_x - 2.0, 18.0, 4.0, height - 36.0), Color(accent.r, accent.g, accent.b, 0.11 * glow_level), true)
	draw_line(Vector2(slot_x, 17.0), Vector2(slot_x, height - 17.0), Color(accent.r, accent.g, accent.b, 0.52 * glow_level), 1.4, true)
	draw_line(Vector2(slot_x + 1.0, 22.0), Vector2(slot_x + 1.0, height - 22.0), Color(0.94, 0.97, 1.0, 0.30 * glow_level), 0.7, true)

func _draw_status_lamp(center: Vector2, accent: Color, glow_level: float) -> void:
	var pulse: float = 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.012)) if _busy else 1.0
	var intensity: float = glow_level * pulse
	draw_circle(center, 12.0, Color(accent.r, accent.g, accent.b, 0.045 * intensity))
	draw_circle(center, 8.0, Color(accent.r, accent.g, accent.b, 0.085 * intensity))
	draw_circle(center, 5.0, Color(accent.r, accent.g, accent.b, 0.17 * intensity))
	draw_arc(center, 7.0, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.48 * intensity), 0.9, true)
	draw_circle(center, 2.5, Color(accent.r, accent.g, accent.b, 0.98 if _busy else 0.76))
	draw_circle(center, 1.0, Color(1.0, 0.98, 0.90, 0.68 * intensity))

func _draw() -> void:
	# Keep the mechanical geometry in one logical grid at a restrained 1.3x display scale.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(DESIGN_SCALE, DESIGN_SCALE))
	var width: float = _drive_width()
	var height: float = DESIGN_HEIGHT
	var slot_x: float = _slot_x()
	var accent: Color = _effective_accent()
	var panel_bg: Color = Color(0.075, 0.091, 0.098, 0.98)
	var panel_border: Color = Color(0.34, 0.40, 0.41, 0.90 if _hovered else 0.62)
	if _variant == HI_FI_DECK:
		var cut := PackedVector2Array([
			Vector2(8, 1), Vector2(width - 8, 1), Vector2(width - 1, 8),
			Vector2(width - 1, height - 8), Vector2(width - 8, height - 1),
			Vector2(8, height - 1), Vector2(1, height - 8), Vector2(1, 8)
		])
		_draw_cut_panel(cut, panel_bg, panel_border)
		draw_line(Vector2(10, 4), Vector2(width - 10, 4), Color(0.72, 0.76, 0.72, 0.13), 1.0, true)
		draw_line(Vector2(10, height - 4), Vector2(width - 10, height - 4), Color(0.015, 0.025, 0.029, 0.9), 1.0, true)
	else:
		draw_rect(Rect2(1, 5, width - 2, height - 10), Color(0.055, 0.071, 0.078, 0.98), true)
		draw_rect(Rect2(1, 5, width - 2, height - 10), panel_border, false, 1.0, true)
		draw_line(Vector2(8, 8), Vector2(width - 8, 8), Color(0.72, 0.79, 0.80, 0.20), 1.0, true)
		draw_line(Vector2(8, height - 8), Vector2(width - 8, height - 8), Color(0.01, 0.02, 0.025, 0.95), 1.0, true)

	# Reveal the body-side PCB only after the disc has fully entered.
	_draw_internal_chassis(slot_x, height, accent)

	# One disc instance travels continuously from the outside tray into the body.
	# No opaque fascia is painted over it and no duplicate disc is spawned inside.
	_draw_dvd_tray(slot_x, height)
	_draw_disc(Vector2(_disc_x, height * 0.5), DISC_RADIUS, accent)
	_draw_chassis_glass_overlay(slot_x, height, accent)

	# Recessed, bevelled optical mouth: front metal face, inner walls and dark throat.
	_draw_slot_bezel(slot_x, height, accent)
	_draw_slot_glow(slot_x, height, accent)

	# The right side is intentionally reserved for the status lamp; no text crowds the disc.
	var led_alpha: float = 0.62 if not _hovered and not _busy else 1.0
	_draw_status_lamp(Vector2(width - 24.0, 50.0), accent, led_alpha)
	draw_line(Vector2(width - 34.0, 18), Vector2(width - 12.0, 18), Color(0.58, 0.64, 0.63, 0.20), 1.0, false)

	if _hovered:
		draw_line(Vector2(12, height - 2), Vector2(width - 12, height - 2), Color(accent.r, accent.g, accent.b, 0.60), 1.0, true)

	# Draw text at its final pixel size with an identity transform. Geometry above remains
	# vector-drawn at the final canvas resolution; no low-resolution bitmap is enlarged.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font: Font = ThemeDB.fallback_font
	var scale_px: float = DESIGN_SCALE
	var title_color := Color(0.88, 0.90, 0.86, 0.96)
	var state_text: String = "READY"
	match _state:
		"INSERTING", "READING":
			state_text = "LOADING"
		"BOOTING":
			state_text = "BOOTING"
		"EJECTING":
			state_text = "EJECTING"
	draw_string(font, Vector2(22.0 * scale_px, 30.0 * scale_px), state_text, HORIZONTAL_ALIGNMENT_LEFT, 104.0 * scale_px, 15, accent.lightened(0.10))
	var action_text: String = "开始游戏"
	match _state:
		"INSERTING", "READING":
			action_text = "载入中..."
		"BOOTING":
			action_text = "启动中..."
		"EJECTING":
			action_text = "退盘中..."
	draw_string(font, Vector2(22.0 * scale_px, 58.0 * scale_px), action_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, title_color)
	draw_string(font, Vector2(22.0 * scale_px, 80.0 * scale_px), "DISC LOADING SYSTEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.48, 0.56, 0.57, 0.72))
