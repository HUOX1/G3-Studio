extends Control
## Experiment A：爆发通电、中心显像、双脉冲 VHS 故障、颗粒光栅、信号锁定与清洁收敛。
## 只使用 game_section 已解码的真实封面；不接触正式 V15 材质或动画。

const LAB_SHADER: Shader = preload("res://shaders/g3_crt_phosphor_scan.gdshader")
const MAX_SAMPLE_CARDS: int = 6
const CARD_ASPECT: float = 2.0 / 3.0
const GRID_GAP: float = 18.0

# Full card entrance: 960ms per card, with a 130ms start offset between cards.
const ENTRY_DURATION_SEC: float = 0.96
const CARD_STAGGER_SEC: float = 0.13
const ENTRY_START_OFFSET_Y: float = 24.0
const ENTRY_START_SCALE: float = 0.97
const DEFAULT_SCAN_SPEED: float = 0.78

# One-shot entrance timeline. Values are normalized to the 960ms card duration.
const PHASE_POWER_START: float = 0.0
const PHASE_POWER_PEAK: float = 0.035
const PHASE_POWER_END: float = 0.105
const PHASE_REVEAL_START: float = 0.065
const PHASE_REVEAL_END: float = 0.35
const PHASE_REVEAL_EDGE_RELEASE_START: float = 0.305
const PHASE_REVEAL_EDGE_RELEASE_END: float = 0.385
const PHASE_GLITCH_ONE: float = 0.285
const PHASE_GLITCH_TWO: float = 0.405
const PHASE_SCAN_START: float = 0.32
const PHASE_SCAN_END: float = 0.68
const PHASE_SCAN_RELEASE_END: float = 0.76
const PHASE_AFTERGLOW_END: float = 0.90
const PHASE_LOCK_START: float = 0.535
const PHASE_LOCK_END: float = 0.735
const PHASE_MOVE_START: float = 0.455
const PHASE_MOVE_END: float = 0.835
const PHASE_CLEAN_START: float = 0.78

# 与 game_section.gd 的窗口缩放及卡片分档保持一致。
const UI_BASE_W: float = 1920.0
const UI_BASE_H: float = 1080.0
const UI_SCALE_MIN: float = 0.62
const UI_SCALE_MAX: float = 1.30
const SIDEBAR_W_BASE: float = 280.0
const GRID_PADDING_BASE: float = 24.0
const GRID_GAP_MIN: float = 12.0
const CARD_TIERS: Array = [
	{"card_w": 150.0, "min_cols": 5, "max_cols": 7, "gap_max": 52.0},
	{"card_w": 200.0, "min_cols": 5, "max_cols": 7, "gap_max": 70.0},
	{"card_w": 290.0, "min_cols": 6, "max_cols": 8, "gap_max": 100.0},
]

# 由当前正式卡片布局推导出的适配边界：1244×700 -> 129.58px；
# UI_SCALE_MAX 1.30 × 最大卡片档 290 -> 377px。
const MIN_REFERENCE_CARD_WIDTH: float = 129.58
const MAX_REFERENCE_CARD_WIDTH: float = 377.0
const PHOSPHOR_PITCH_MIN: Vector2 = Vector2(3.2, 2.4)
const PHOSPHOR_PITCH_MAX: Vector2 = Vector2(1.9, 1.55)

const COLOR_TEXT: Color = Color(0.84, 0.89, 0.96, 1.0)
const COLOR_MUTED: Color = Color(0.57, 0.67, 0.79, 1.0)
const COLOR_WARN: Color = Color(1.0, 0.63, 0.54, 1.0)

var _samples: Array[Dictionary] = []
var _cards: Array[Dictionary] = []
var _sample_signature: String = ""
var _pending_samples: Array[Dictionary] = []
var _pending_signature: String = ""
var _has_pending_samples: bool = false
var _page_active: bool = false
var _playing: bool = false
var _animation_elapsed: float = 0.0
var _card_size: Vector2 = Vector2(129.58, 194.37)
var _phosphor_pitch: Vector2 = PHOSPHOR_PITCH_MIN
var _card_size_progress: float = 0.0

var _parameters: Dictionary = {
	"power_intensity": 1.85,
	"phosphor_strength": 0.72,
	"reveal_edge_intensity": 1.55,
	"glitch_intensity": 0.92,
	"scan_intensity": 1.35,
	"scan_width_scale": 1.0,
	"lock_intensity": 1.15,
	"afterglow_strength": 0.55,
	"breakup_strength": 0.38,
	"scan_speed": 0.78,
}
var _grid: GridContainer
var _status: Label
var _geometry_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_card_geometry()
	_build_ui()
	visible = false
	call_deferred("_refresh_card_geometry")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_refresh_card_geometry")


func set_page_active(active: bool) -> void:
	_page_active = active
	visible = active
	if not active:
		_stop_scan()
	else:
		_refresh_card_geometry()
		_update_status()


func set_game_samples(samples: Array[Dictionary]) -> void:
	var valid_samples: Array[Dictionary] = []
	for sample in samples:
		var sample_texture: Texture2D = sample.get("texture") as Texture2D
		if sample_texture == null:
			continue
		valid_samples.append(sample)
		if valid_samples.size() >= MAX_SAMPLE_CARDS:
			break

	var signature_parts: PackedStringArray = []
	for sample in valid_samples:
		var signature_texture: Texture2D = sample.get("texture") as Texture2D
		signature_parts.append("%s:%s:%s:%s" % [
			str(sample.get("id", "")),
			str(sample.get("title", "")),
			str(sample.get("platform", "")),
			str(signature_texture.get_instance_id()),
		])
	var next_signature: String = "|".join(signature_parts)
	if next_signature == _sample_signature:
		return
	if _has_pending_samples and next_signature == _pending_signature:
		return
	if _playing:
		_pending_samples = valid_samples
		_pending_signature = next_signature
		_has_pending_samples = true
		_set_status("游戏封面列表有更新；当前入场结束或停止后刷新样本。")
		return
	_apply_sample_snapshot(valid_samples, next_signature)


func _apply_sample_snapshot(samples: Array[Dictionary], signature: String) -> void:
	_playing = false
	_animation_elapsed = 0.0
	_samples = samples
	_sample_signature = signature
	_pending_samples.clear()
	_pending_signature = ""
	_has_pending_samples = false
	_rebuild_cards()
	_update_status()


func _process(delta: float) -> void:
	if not _page_active or not _playing:
		return

	_animation_elapsed += delta
	var scan_speed: float = float(_parameters["scan_speed"])
	var all_cards_entered: bool = true

	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var local_elapsed: float = _animation_elapsed - float(index) * CARD_STAGGER_SEC
		if local_elapsed < 0.0:
			all_cards_entered = false
			continue

		if local_elapsed < ENTRY_DURATION_SEC:
			all_cards_entered = false
			var progress: float = clampf(local_elapsed / ENTRY_DURATION_SEC, 0.0, 1.0)
			_update_card_entry(card, progress, scan_speed)
		else:
			_set_card_to_rest(card)

	if all_cards_entered:
		_playing = false
		_animation_elapsed = 0.0
		if _has_pending_samples:
			_apply_pending_samples()
		else:
			_set_status("完整入场完成 · 所有入场特效已清除，恢复原始封面。")


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	root.add_child(heading)
	heading.add_child(_make_label("CRT / VHS 完整入场实验", 18, COLOR_TEXT))
	heading.add_child(_make_label("Experiment A · Power Burst × Phosphor Raster × Signal Lock", 11, COLOR_MUTED))
	_geometry_label = _make_label("", 11, COLOR_MUTED)
	_geometry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_geometry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(_geometry_label)

	var controls := GridContainer.new()
	controls.columns = 3
	controls.add_theme_constant_override("h_separation", 16)
	controls.add_theme_constant_override("v_separation", 4)
	root.add_child(controls)
	_add_parameter_slider(controls, "通电爆发", "power_intensity", 0.5, 2.6, 0.02, 1.85)
	_add_parameter_slider(
		controls, "颗粒显色强度", "phosphor_strength", 0.0, 1.0, 0.01, 0.72,
		"调节 RGB 荧光颗粒的亮度与色彩响应；不改变透明度、颗粒数量或排列间距。"
	)
	_add_parameter_slider(
		controls, "展开边缘磷光", "reveal_edge_intensity", 0.0, 2.4, 0.02, 1.55,
		"控制中心展开时两条显像边缘的白色核心，以及青色 / 品红色荧光晕。"
	)
	_add_parameter_slider(controls, "信号故障", "glitch_intensity", 0.0, 1.5, 0.02, 0.92)
	_add_parameter_slider(controls, "扫光强度", "scan_intensity", 0.4, 2.2, 0.02, 1.35)
	_add_parameter_slider(controls, "光带宽度", "scan_width_scale", 0.55, 1.65, 0.01, 1.0)
	_add_parameter_slider(controls, "锁定高光", "lock_intensity", 0.0, 2.0, 0.02, 1.15)
	_add_parameter_slider(controls, "颗粒余辉", "afterglow_strength", 0.0, 1.0, 0.01, 0.55)
	_add_parameter_slider(controls, "噪声破碎", "breakup_strength", 0.0, 1.0, 0.01, 0.38)
	_add_parameter_slider(controls, "扫描速度", "scan_speed", 0.20, 1.60, 0.02, 0.78)
	var controls_note := _make_label(
		"荧光颗粒响应强度只调节亮度 / 色彩，不调节透明度或数量；颗粒大小由点形状决定，排列间距仍按卡片尺寸自动适配。",
		10, COLOR_MUTED
	)
	controls_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(controls_note)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var play_button := Button.new()
	play_button.text = "播放完整入场"
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.pressed.connect(_start_scan)
	actions.add_child(play_button)
	var stop_button := Button.new()
	stop_button.text = "停止"
	stop_button.focus_mode = Control.FOCUS_NONE
	stop_button.pressed.connect(_stop_scan)
	actions.add_child(stop_button)
	actions.add_child(_make_label("单卡 960ms · 相邻错峰 130ms · 播放完成后全部入场特效归零。", 11, COLOR_MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = MAX_SAMPLE_CARDS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(GRID_GAP))
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	_status = _make_label("等待游戏封面…", 11, COLOR_MUTED)
	root.add_child(_status)
	call_deferred("_update_grid_columns")


func _add_parameter_slider(
	parent: GridContainer,
	label_text: String,
	parameter: String,
	minimum: float,
	maximum: float,
	step: float,
	default_value: float,
	help_text: String = ""
) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var label := _make_label(label_text, 11, COLOR_MUTED)
	label.custom_minimum_size.x = 76.0 if parameter in ["phosphor_strength", "reveal_edge_intensity"] else 64.0
	if not help_text.is_empty():
		label.tooltip_text = help_text
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = default_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 90.0
	slider.focus_mode = Control.FOCUS_NONE
	if not help_text.is_empty():
		slider.tooltip_text = help_text
	row.add_child(slider)

	var value_label := _make_label("%.2f" % default_value, 11, COLOR_TEXT)
	value_label.custom_minimum_size.x = 38.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	_parameters[parameter] = default_value
	slider.value_changed.connect(func(value: float) -> void:
		_parameters[parameter] = value
		value_label.text = "%.2f" % value
		_apply_settings_to_cards()
	)


func _refresh_card_geometry() -> void:
	if get_viewport() == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var next_size: Vector2 = _calculate_game_card_size(viewport_size)
	var next_size_progress: float = _calculate_card_size_progress(next_size.x)
	var next_pitch: Vector2 = _calculate_phosphor_pitch(next_size.x)
	var changed: bool = not next_size.is_equal_approx(_card_size) or not next_pitch.is_equal_approx(_phosphor_pitch)
	_card_size = next_size
	_card_size_progress = next_size_progress
	_phosphor_pitch = next_pitch
	if changed:
		for card in _cards:
			var slot: Control = card.get("slot") as Control
			var poster_stage: Control = card.get("poster_stage") as Control
			var title: Label = card.get("title") as Label
			var platform_label: Label = card.get("platform_label") as Label
			var motion: Control = card.get("motion") as Control
			if is_instance_valid(slot):
				slot.custom_minimum_size = Vector2(_card_size.x, _get_card_slot_height(is_instance_valid(platform_label)))
			if is_instance_valid(poster_stage):
				poster_stage.custom_minimum_size = _card_size
			if is_instance_valid(title):
				title.custom_minimum_size.x = _card_size.x
			if is_instance_valid(motion):
				motion.pivot_offset = Vector2(_card_size.x * 0.5, _get_card_slot_height(is_instance_valid(platform_label)) * 0.5)
			_apply_settings_to_card(card)
		call_deferred("_sync_card_motion_pivots")
	_update_geometry_label()
	_update_grid_columns()


func _get_card_slot_height(has_platform: bool) -> float:
	var height: float = _card_size.y + 5.0 + 18.0
	if has_platform:
		height += 15.0 + 5.0
	return height


func _sync_card_motion_pivots() -> void:
	for card in _cards:
		var motion: Control = card.get("motion") as Control
		if is_instance_valid(motion) and motion.size.x > 0.0 and motion.size.y > 0.0:
			motion.pivot_offset = motion.size * 0.5


func _calculate_game_card_size(viewport_size: Vector2) -> Vector2:
	var raw_scale: float = minf(viewport_size.x / UI_BASE_W, viewport_size.y / UI_BASE_H)
	var ui_scale: float = clampf(raw_scale, UI_SCALE_MIN, UI_SCALE_MAX)
	var sidebar_width: float = SIDEBAR_W_BASE * ui_scale
	var padding: int = int(GRID_PADDING_BASE * ui_scale)
	var available_width: float = viewport_size.x - sidebar_width - 2.0 * float(padding)
	if available_width < 100.0:
		return Vector2(80.0 * ui_scale, 120.0 * ui_scale)
	var available_logic_width: float = available_width / maxf(ui_scale, 0.0001)
	var chosen_card_width: float = float(CARD_TIERS[0]["card_w"])

	for index in range(CARD_TIERS.size()):
		var tier: Dictionary = CARD_TIERS[index]
		var card_width: float = float(tier["card_w"])
		var min_columns: int = int(tier["min_cols"])
		var max_columns: int = int(tier["max_cols"])
		var max_gap: float = float(tier["gap_max"])
		var n_max: int = floori((available_logic_width + GRID_GAP_MIN) / (card_width + GRID_GAP_MIN))
		var columns: int = clampi(n_max, min_columns, max_columns)
		var tier_gap: float = 0.0
		if columns > 1:
			tier_gap = (available_logic_width - float(columns) * card_width) / float(columns - 1)
		var is_last: bool = index == CARD_TIERS.size() - 1

		if n_max < min_columns:
			chosen_card_width = maxf(
				80.0,
				(available_logic_width - float(min_columns - 1) * GRID_GAP_MIN) / float(min_columns)
			)
			break
		if n_max <= max_columns and tier_gap <= max_gap:
			chosen_card_width = card_width
			break
		if is_last:
			chosen_card_width = card_width
			break

	var actual_width: float = chosen_card_width * ui_scale
	return Vector2(actual_width, actual_width / CARD_ASPECT)


func _calculate_card_size_progress(card_width: float) -> float:
	return clampf(
		(card_width - MIN_REFERENCE_CARD_WIDTH) / (MAX_REFERENCE_CARD_WIDTH - MIN_REFERENCE_CARD_WIDTH),
		0.0,
		1.0
	)


func _calculate_phosphor_pitch(card_width: float) -> Vector2:
	var size_progress: float = _calculate_card_size_progress(card_width)
	return PHOSPHOR_PITCH_MIN.lerp(PHOSPHOR_PITCH_MAX, size_progress)


func _update_geometry_label() -> void:
	if _geometry_label == null:
		return
	_geometry_label.text = "卡片 %.1f×%.1f px · 颗粒间距 %.2f×%.2f px" % [
		_card_size.x, _card_size.y, _phosphor_pitch.x, _phosphor_pitch.y,
	]


func _update_grid_columns() -> void:
	if _grid == null:
		return
	var available_width: float = _grid.size.x
	var columns: int = floori((available_width + GRID_GAP) / (_card_size.x + GRID_GAP))
	_grid.columns = clampi(columns, 1, MAX_SAMPLE_CARDS)


func _rebuild_cards() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	for sample in _samples:
		var texture: Texture2D = sample.get("texture") as Texture2D
		if texture == null:
			continue
		var platform: String = str(sample.get("platform", "")).strip_edges()
		var has_platform: bool = not platform.is_empty()
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(_card_size.x, _get_card_slot_height(has_platform))
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.size_flags_vertical = Control.SIZE_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(slot)

		var motion := Control.new()
		motion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		motion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		motion.pivot_offset = Vector2(_card_size.x * 0.5, _get_card_slot_height(has_platform) * 0.5)
		slot.add_child(motion)

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("separation", 5)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		motion.add_child(content)

		var poster_stage := Control.new()
		poster_stage.custom_minimum_size = _card_size
		poster_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		poster_stage.clip_contents = false
		poster_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(poster_stage)

		var poster := TextureRect.new()
		poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		poster.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		poster.texture = texture
		var material := ShaderMaterial.new()
		material.shader = LAB_SHADER
		material.set_shader_parameter("reveal_progress", 1.0)
		material.set_shader_parameter("scan_progress", -1.0)
		material.set_shader_parameter("power_envelope", 0.0)
		material.set_shader_parameter("phosphor_activity", 0.0)
		material.set_shader_parameter("glitch_strength", 0.0)
		material.set_shader_parameter("scan_envelope", 0.0)
		material.set_shader_parameter("afterglow_envelope", 0.0)
		material.set_shader_parameter("lock_envelope", 0.0)
		poster.material = material
		poster_stage.add_child(poster)

		var title := _make_label(str(sample.get("title", "未命名游戏")), 11, COLOR_TEXT)
		title.custom_minimum_size = Vector2(_card_size.x, 18.0)
		title.clip_text = true
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(title)
		var platform_label: Label = null
		if has_platform:
			platform_label = _make_label(platform, 10, COLOR_MUTED)
			platform_label.custom_minimum_size.y = 15.0
			platform_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(platform_label)

		var entry := {
			"id": str(sample.get("id", "")),
			"slot": slot,
			"motion": motion,
			"poster_stage": poster_stage,
			"poster": poster,
			"title": title,
			"platform_label": platform_label,
			"material": material,
			"effect_state": _get_clean_effect_state(),
		}
		_cards.append(entry)
		_apply_settings_to_card(entry)
		_set_card_motion_state(entry, 0.0, 1.0)
		_set_card_label_alpha(entry, 1.0)

	_update_grid_columns()
	call_deferred("_sync_card_motion_pivots")


func _apply_settings_to_cards() -> void:
	for card in _cards:
		_apply_settings_to_card(card)


func _apply_settings_to_card(card: Dictionary) -> void:
	var material: ShaderMaterial = card.get("material") as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("card_size", _card_size)
	material.set_shader_parameter("phosphor_pitch", _phosphor_pitch)
	material.set_shader_parameter("card_size_progress", _card_size_progress)
	material.set_shader_parameter("power_intensity", float(_parameters["power_intensity"]))
	material.set_shader_parameter("phosphor_strength", float(_parameters["phosphor_strength"]))
	material.set_shader_parameter("reveal_edge_intensity", float(_parameters["reveal_edge_intensity"]))
	material.set_shader_parameter("glitch_intensity", float(_parameters["glitch_intensity"]))
	material.set_shader_parameter("scan_intensity", float(_parameters["scan_intensity"]))
	material.set_shader_parameter("scan_width_scale", float(_parameters["scan_width_scale"]))
	material.set_shader_parameter("lock_intensity", float(_parameters["lock_intensity"]))
	material.set_shader_parameter("afterglow_strength", float(_parameters["afterglow_strength"]))
	material.set_shader_parameter("breakup_strength", float(_parameters["breakup_strength"]))
	_set_card_shader_state(card, card.get("effect_state", _get_clean_effect_state()))


func _start_scan() -> void:
	if not _page_active:
		return
	if _cards.is_empty():
		_set_status("没有可播放的真实封面；请先在游戏板块等待封面解码。", true)
		return
	_animation_elapsed = 0.0
	_playing = true
	for card in _cards:
		_prepare_card_for_entry(card)
	_set_status("完整入场播放中 · %d 张真实封面 · 单卡 960ms · 错峰 130ms。" % _cards.size())


func _stop_scan(update_status: bool = true) -> void:
	_playing = false
	_animation_elapsed = 0.0
	for card in _cards:
		_set_card_to_rest(card)
	if _has_pending_samples:
		_apply_pending_samples()
	elif update_status:
		_update_status()


func _update_card_entry(card: Dictionary, progress: float, scan_speed: float) -> void:
	var move_progress: float = _smoothstep(PHASE_MOVE_START, PHASE_MOVE_END, progress)
	var move_eased: float = 1.0 - pow(1.0 - move_progress, 3.0)
	var y_offset: float = lerpf(ENTRY_START_OFFSET_Y, 0.0, move_eased)
	var scale_value: float = lerpf(ENTRY_START_SCALE, 1.0, move_eased)
	_set_card_motion_state(card, y_offset, scale_value)
	_set_card_label_alpha(card, _smoothstep(0.54, 0.76, progress))
	_set_card_shader_state(card, _get_entry_effect_state(progress, scan_speed))


func _get_entry_effect_state(progress: float, scan_speed: float) -> Dictionary:
	var clean_factor: float = 1.0 - _smoothstep(PHASE_CLEAN_START, PHASE_AFTERGLOW_END, progress)
	var power_progress: float = _smoothstep(PHASE_POWER_START, PHASE_POWER_PEAK, progress)
	var power_decay: float = PHASE_POWER_END - PHASE_POWER_START - 0.028
	var power_envelope: float = _pulse_envelope(progress, PHASE_POWER_START, 0.014, 0.014, power_decay)
	var reveal_progress: float = _smoothstep(PHASE_REVEAL_START, PHASE_REVEAL_END, progress)
	# The power line and the reveal edge share one center position. The edge glow
	# inherits the tail of the power burst, then follows the two expanding fronts.
	var reveal_edge_envelope: float = _smoothstep(
		PHASE_REVEAL_START - 0.006, PHASE_REVEAL_START + 0.03, progress
	)
	reveal_edge_envelope *= 1.0 - _smoothstep(
		PHASE_REVEAL_EDGE_RELEASE_START, PHASE_REVEAL_EDGE_RELEASE_END, progress
	)
	reveal_edge_envelope = maxf(power_envelope * 0.88, reveal_edge_envelope)
	reveal_edge_envelope *= clean_factor

	var glitch_one: float = _pulse_envelope(progress, PHASE_GLITCH_ONE, 0.008, 0.012, 0.052)
	var glitch_two: float = _pulse_envelope(progress, PHASE_GLITCH_TWO, 0.006, 0.010, 0.055)
	var glitch_strength: float = maxf(glitch_one * 0.72, glitch_two)
	glitch_strength = clampf(glitch_strength, 0.0, 1.5) * clean_factor

	var scan_progress: float = -1.0
	if progress >= PHASE_SCAN_START and progress <= PHASE_AFTERGLOW_END:
		var scan_t: float = clampf((progress - PHASE_SCAN_START) / (PHASE_SCAN_END - PHASE_SCAN_START), 0.0, 1.0)
		var speed_exponent: float = clampf(DEFAULT_SCAN_SPEED / maxf(scan_speed, 0.01), 0.35, 2.5)
		scan_progress = pow(scan_t, speed_exponent)
		if progress > PHASE_SCAN_END:
			scan_progress = 1.0

	var scan_envelope: float = _smoothstep(PHASE_SCAN_START - 0.03, PHASE_SCAN_START + 0.035, progress)
	scan_envelope *= 1.0 - _smoothstep(PHASE_SCAN_END, PHASE_SCAN_RELEASE_END, progress)
	scan_envelope *= clean_factor
	var afterglow_envelope: float = _smoothstep(PHASE_SCAN_START, PHASE_SCAN_START + 0.075, progress)
	afterglow_envelope *= 1.0 - _smoothstep(PHASE_CLEAN_START, PHASE_AFTERGLOW_END, progress)
	var reveal_activity: float = _smoothstep(0.16, 0.34, progress)
	var scan_activity: float = _smoothstep(PHASE_SCAN_START, PHASE_SCAN_START + 0.07, progress)
	var phosphor_activity: float = maxf(reveal_activity * 0.48, scan_activity) * clean_factor

	var lock_progress: float = clampf(
		(progress - PHASE_LOCK_START) / (PHASE_LOCK_END - PHASE_LOCK_START),
		0.0,
		1.0
	)
	var lock_envelope: float = _smoothstep(PHASE_LOCK_START - 0.025, PHASE_LOCK_START + 0.025, progress)
	lock_envelope *= 1.0 - _smoothstep(PHASE_LOCK_END - 0.015, PHASE_LOCK_END + 0.055, progress)
	lock_envelope *= clean_factor

	return {
		"power_progress": power_progress,
		"power_envelope": power_envelope * clean_factor,
		"reveal_progress": reveal_progress,
		"reveal_edge_activity": reveal_edge_envelope,
		"phosphor_activity": phosphor_activity,
		"glitch_strength": glitch_strength,
		"glitch_phase": progress * 96.0,
		"scan_progress": scan_progress,
		"scan_envelope": scan_envelope,
		"afterglow_envelope": afterglow_envelope,
		"lock_progress": lock_progress,
		"lock_envelope": lock_envelope,
	}


func _pulse_envelope(progress: float, start: float, attack: float, hold: float, decay: float) -> float:
	var attack_end: float = start + attack
	var release_start: float = attack_end + hold
	var release_end: float = release_start + decay
	if progress < start or progress >= release_end:
		return 0.0
	var attack_value: float = _smoothstep(start, attack_end, progress)
	var release_value: float = 1.0 - _smoothstep(release_start, release_end, progress)
	return clampf(attack_value * release_value, 0.0, 1.0)


func _get_clean_effect_state() -> Dictionary:
	return {
		"power_progress": 0.0,
		"power_envelope": 0.0,
		"reveal_progress": 1.0,
		"reveal_edge_activity": 0.0,
		"phosphor_activity": 0.0,
		"glitch_strength": 0.0,
		"glitch_phase": 0.0,
		"scan_progress": -1.0,
		"scan_envelope": 0.0,
		"afterglow_envelope": 0.0,
		"lock_progress": 0.0,
		"lock_envelope": 0.0,
	}


func _get_initial_effect_state() -> Dictionary:
	var state: Dictionary = _get_clean_effect_state()
	state["reveal_progress"] = 0.0
	return state


func _prepare_card_for_entry(card: Dictionary) -> void:
	_set_card_motion_state(card, ENTRY_START_OFFSET_Y, ENTRY_START_SCALE)
	_set_card_label_alpha(card, 0.0)
	_set_card_shader_state(card, _get_initial_effect_state())


func _set_card_to_rest(card: Dictionary) -> void:
	_set_card_motion_state(card, 0.0, 1.0)
	_set_card_label_alpha(card, 1.0)
	_set_card_shader_state(card, _get_clean_effect_state())


func _set_card_motion_state(card: Dictionary, y_offset: float, scale_value: float) -> void:
	var motion: Control = card.get("motion") as Control
	if not is_instance_valid(motion):
		return
	motion.offset_top = y_offset
	motion.offset_bottom = y_offset
	motion.scale = Vector2.ONE * scale_value
	motion.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _set_card_label_alpha(card: Dictionary, alpha: float) -> void:
	var safe_alpha: float = clampf(alpha, 0.0, 1.0)
	var title: Label = card.get("title") as Label
	var platform_label: Label = card.get("platform_label") as Label
	if is_instance_valid(title):
		title.modulate = Color(1.0, 1.0, 1.0, safe_alpha)
	if is_instance_valid(platform_label):
		platform_label.modulate = Color(1.0, 1.0, 1.0, safe_alpha)


func _set_card_shader_state(card: Dictionary, effect_state: Dictionary) -> void:
	card["effect_state"] = effect_state.duplicate()
	var material: ShaderMaterial = card.get("material") as ShaderMaterial
	if material == null:
		return
	for parameter in effect_state:
		material.set_shader_parameter(StringName(str(parameter)), effect_state[parameter])


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	var t: float = clampf((value - edge_start) / maxf(edge_end - edge_start, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _apply_pending_samples() -> void:
	var samples: Array[Dictionary] = _pending_samples.duplicate()
	var signature: String = _pending_signature
	_apply_sample_snapshot(samples, signature)


func _update_status() -> void:
	if _status == null:
		return
	if _samples.is_empty():
		_set_status("正在等待游戏板块解码真实封面；封面就绪后会自动复制到这里。")
	else:
		_set_status("已复制 %d / %d 张真实游戏封面 · 当前卡片 %.1f×%.1f px · RGB 颗粒间距 %.2f×%.2f px。" % [
			_samples.size(), MAX_SAMPLE_CARDS,
			_card_size.x, _card_size.y,
			_phosphor_pitch.x, _phosphor_pitch.y,
		])


func _set_status(message: String, warn: bool = false) -> void:
	if _status == null:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", COLOR_WARN if warn else COLOR_MUTED)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _exit_tree() -> void:
	_pending_samples.clear()
	_pending_signature = ""
	_has_pending_samples = false
	_stop_scan(false)
