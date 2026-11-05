extends Control
## COMICS lab page for evaluating the optical-drive launch control in detail-page context.
## The prototype is visual-only and never launches a real game.

const DRAWER_SCRIPT: Script = preload("res://scripts/hidden_slim_loader_drawer_experiment.gd")

const COLOR_TEXT := Color(0.84, 0.88, 0.91, 1.0)
const COLOR_MUTED := Color(0.57, 0.66, 0.72, 1.0)
const COLOR_PANEL := Color(0.085, 0.105, 0.115, 1.0)
const COLOR_CONTENT := Color(0.105, 0.125, 0.12, 1.0)

var _drawer_preview: Control
var _status_label: Label
var _width_slider: HSlider
var _width_value: Label
var _variant_a: Button
var _variant_b: Button
var _theme_picker: ColorPickerButton
var _hero_preview: ColorRect
var _hero_tint_overlay: ColorRect
var _theme_accent: Color = Color(0.78, 0.57, 0.30, 1.0)
var _theme_override_active: bool = false
var _active_variant: int = 0
var _syncing_theme_picker: bool = false
var _active: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func set_page_active(active: bool) -> void:
	_active = active
	if not active and _drawer_preview != null:
		_drawer_preview.call("reset_demo")

func apply_game_theme_palette(palette: Dictionary) -> void:
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent_value: Variant = colors.get("accent", "")
	if typeof(accent_value) == TYPE_COLOR:
		_apply_theme_accent(accent_value)
	elif not str(accent_value).strip_edges().is_empty():
		_apply_theme_accent(Color.from_string(str(accent_value), _theme_accent))

func reset_game_theme_palette() -> void:
	_theme_override_active = false
	_theme_accent = _default_variant_accent()
	if _drawer_preview != null:
		_drawer_preview.call("reset_game_theme_palette")
	_set_theme_picker_color(_theme_accent)
	if _hero_tint_overlay != null:
		_hero_tint_overlay.color = Color(_theme_accent.r, _theme_accent.g, _theme_accent.b, 0.0)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	root.add_child(heading)
	var heading_text := VBoxContainer.new()
	heading_text.add_theme_constant_override("separation", 2)
	heading.add_child(heading_text)
	heading_text.add_child(_label("启动装置 · HIDDEN SLIM LOADER", 16, COLOR_TEXT))
	heading_text.add_child(_label("实验隐藏式抽拉模块：默认只露出外部把手，点击后把 520 px 的 Slim Loader 从详情页内部抽出。", 11, COLOR_MUTED))

	var heading_spacer := Control.new()
	heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_spacer)
	heading.add_child(_label("VISUAL EXPERIMENT  /  NO REAL LAUNCH", 9, COLOR_MUTED))

	root.add_child(_build_controls())
	root.add_child(_build_detail_context())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	_status_label = _label("收纳态 · 默认只露出把手；点击外露把手展开面板。展开后，点击面板执行入盘演示。不会启动真实游戏。", 11, COLOR_MUTED)
	footer.add_child(_status_label)

func _build_controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	_variant_a = _control_button("01  HI-FI DECK", func() -> void: _select_variant(0))
	_variant_b = _control_button("02  SLIM LOADER", func() -> void: _select_variant(1))
	_variant_a.button_pressed = true
	row.add_child(_variant_a)
	row.add_child(_variant_b)

	var theme_label := _label("Hero 染色", 11, COLOR_MUTED)
	row.add_child(theme_label)
	_theme_picker = ColorPickerButton.new()
	_theme_picker.color = _theme_accent
	_theme_picker.custom_minimum_size = Vector2(34.0, 24.0)
	_theme_picker.tooltip_text = "模拟详情页 Hero 提取的主题强调色；同步影响光驱接口灯与右侧提示灯。"
	_theme_picker.color_changed.connect(_on_theme_color_changed)
	row.add_child(_theme_picker)

	var separator := VSeparator.new()
	row.add_child(separator)
	row.add_child(_label("面板宽度（1.5×）", 11, COLOR_MUTED))
	_width_slider = HSlider.new()
	_width_slider.min_value = 494.0
	_width_slider.max_value = 676.0
	_width_slider.step = 10.0
	_width_slider.value = 520.0
	_width_slider.custom_minimum_size = Vector2(180.0, 22.0)
	_width_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_width_slider.value_changed.connect(_on_width_changed)
	row.add_child(_width_slider)
	_width_value = _label("520 px", 11, COLOR_TEXT)
	_width_value.custom_minimum_size.x = 56.0
	row.add_child(_width_value)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_control_button("重置演示", func() -> void: _reset_demo()))
	return row

func _build_detail_context() -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = COLOR_PANEL
	frame_style.border_color = Color(0.25, 0.31, 0.32, 0.9)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.add_theme_constant_override("content_margin_left", 0)
	frame.add_theme_constant_override("content_margin_right", 0)
	frame.add_theme_constant_override("content_margin_top", 0)
	frame.add_theme_constant_override("content_margin_bottom", 0)

	var context := VBoxContainer.new()
	context.add_theme_constant_override("separation", 0)
	frame.add_child(context)

	_hero_preview = ColorRect.new()
	_hero_preview.color = Color(0.12, 0.16, 0.13, 1.0)
	_hero_preview.custom_minimum_size.y = 62.0
	_hero_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context.add_child(_hero_preview)
	_hero_tint_overlay = ColorRect.new()
	_hero_tint_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_tint_overlay.color = Color(_theme_accent.r, _theme_accent.g, _theme_accent.b, 0.18)
	_hero_tint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_preview.add_child(_hero_tint_overlay)
	var hero_label := _label("HERO AREA   ·   保持原有位置 / 不放置启动装置", 10, Color(0.69, 0.74, 0.66, 0.68))
	_hero_preview.add_child(hero_label)
	hero_label.position = Vector2(18, 22)

	var content_panel := ColorRect.new()
	content_panel.color = COLOR_CONTENT
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 18)
	content_margin.add_theme_constant_override("margin_right", 18)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	content_panel.add_child(content_margin)

	var preview_scroll := ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_margin.add_child(preview_scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.custom_minimum_size = Vector2(886.0, 0.0)
	body.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_scroll.add_child(body)

	var drawer_stage := Control.new()
	drawer_stage.custom_minimum_size = Vector2(846.0, 152.0)
	drawer_stage.clip_contents = false
	body.add_child(drawer_stage)

	var drawer_hint := _label("DETAIL PANEL EDGE  ·  默认收纳，仅保留外露把手；展开时不挤压下面的截图与简介布局。", 10, Color(0.69, 0.74, 0.66, 0.68))
	drawer_stage.add_child(drawer_hint)
	drawer_hint.position = Vector2(8, 4)

	_drawer_preview = DRAWER_SCRIPT.new()
	_drawer_preview.name = "HiddenSlimLoaderDrawerExperiment"
	_drawer_preview.position = Vector2(8.0, 14.0)
	_drawer_preview.connect("demo_state_changed", _on_demo_state_changed)
	drawer_stage.add_child(_drawer_preview)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	body.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.custom_minimum_size.x = 420.0
	left.add_theme_constant_override("separation", 24)
	columns.add_child(left)

	var screenshot := _build_screenshot_mock()
	screenshot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	screenshot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_child(screenshot)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.custom_minimum_size.x = 340.0
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	var right_spacer := Control.new()
	right_spacer.custom_minimum_size.y = 18.0
	right.add_child(right_spacer)
	var description := _label("《Sifu》是一款强调近身格斗与动作节奏的游戏。这里模拟详情页原有的简介和资料栏，观察启动装置是否自然融入内容布局。", 12, Color(0.70, 0.78, 0.78, 1.0))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(description)

	var metadata := GridContainer.new()
	metadata.columns = 2
	metadata.add_theme_constant_override("h_separation", 22)
	metadata.add_theme_constant_override("v_separation", 12)
	right.add_child(metadata)
	metadata.add_child(_meta_item("评分", "81 / 100"))
	metadata.add_child(_meta_item("发售日期", "2023.03.28"))
	metadata.add_child(_meta_item("开发商", "Sloclap"))
	metadata.add_child(_meta_item("发行商", "Sloclap"))

	return frame

func _build_screenshot_mock() -> Control:
	var shell := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.045, 1.0)
	style.border_color = Color(0.23, 0.28, 0.26, 0.9)
	style.set_border_width_all(1)
	shell.add_theme_stylebox_override("panel", style)
	shell.custom_minimum_size = Vector2(420.0, 236.0)

	var art := Control.new()
	art.custom_minimum_size = Vector2(420.0, 236.0)
	shell.add_child(art)
	var background := ColorRect.new()
	background.color = Color(0.22, 0.18, 0.12, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(background)

	var back_light := ColorRect.new()
	back_light.color = Color(0.65, 0.36, 0.15, 0.42)
	back_light.anchor_left = 0.05
	back_light.anchor_top = 0.12
	back_light.anchor_right = 0.95
	back_light.anchor_bottom = 0.78
	art.add_child(back_light)

	for index in range(5):
		var pillar := ColorRect.new()
		pillar.color = Color(0.08, 0.09, 0.08, 0.62)
		pillar.anchor_left = 0.08 + float(index) * 0.19
		pillar.anchor_right = pillar.anchor_left + 0.025
		pillar.anchor_top = 0.10
		pillar.anchor_bottom = 0.86
		art.add_child(pillar)

	var silhouette := ColorRect.new()
	silhouette.color = Color(0.035, 0.045, 0.04, 0.96)
	silhouette.anchor_left = 0.42
	silhouette.anchor_top = 0.35
	silhouette.anchor_right = 0.58
	silhouette.anchor_bottom = 0.94
	art.add_child(silhouette)

	var caption := _label("截图预览  /  GAME SCREENSHOT  /  16:9", 9, Color(0.90, 0.83, 0.72, 0.72))
	caption.position = Vector2(12, 10)
	art.add_child(caption)
	return shell

func _meta_item(key: String, value: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(key, 9, Color(0.55, 0.66, 0.70, 1.0)))
	box.add_child(_label(value, 11, Color(0.80, 0.85, 0.85, 1.0)))
	return box

func _on_theme_color_changed(color: Color) -> void:
	if _syncing_theme_picker:
		return
	_apply_theme_accent(color)

func _set_theme_picker_color(color: Color) -> void:
	if _theme_picker == null or _theme_picker.color == color:
		return
	_syncing_theme_picker = true
	_theme_picker.color = color
	_syncing_theme_picker = false

func _default_variant_accent() -> Color:
	return Color(0.78, 0.57, 0.30, 1.0) if _active_variant == 0 else Color(0.43, 0.69, 0.76, 1.0)

func _apply_theme_accent(color: Color) -> void:
	_theme_override_active = true
	_theme_accent = color
	if _drawer_preview != null:
		_drawer_preview.call("set_theme_accent", color)
	_set_theme_picker_color(color)
	if _hero_tint_overlay != null:
		_hero_tint_overlay.color = Color(color.r, color.g, color.b, 0.20)

func _select_variant(variant: int) -> void:
	if _drawer_preview == null:
		return
	_active_variant = variant
	_drawer_preview.call("reset_demo")
	_drawer_preview.call("set_drive_variant", variant)
	if not _theme_override_active:
		_theme_accent = _default_variant_accent()
		_set_theme_picker_color(_theme_accent)
		if _hero_tint_overlay != null:
			_hero_tint_overlay.color = Color(_theme_accent.r, _theme_accent.g, _theme_accent.b, 0.0)
	_variant_a.button_pressed = variant == 0
	_variant_b.button_pressed = variant == 1
	_status_label.text = "方案 %s · %s" % ["01" if variant == 0 else "02", "Hi-Fi Deck" if variant == 0 else "Slim Loader"]

func _on_width_changed(value: float) -> void:
	if _drawer_preview != null:
		_drawer_preview.call("set_panel_width", value)
	if _width_value != null:
		_width_value.text = "%d px" % int(round(value))

func _on_demo_state_changed(state: String) -> void:
	if _status_label == null:
		return
	var messages := {
		"READY": "待机 · 面板已展开；点击面板后光盘先靠近接口，再由托盘与光盘一起收入机身。",
		"INSERTING": "载入中 · 光盘先靠近接口，随后托盘与光盘同步收入。",
		"READING": "载入中 · 光盘已进入机身，抽拉面板保持展开，内部机芯与读取灯持续工作。",
		"BOOTING": "启动中 · 光盘已锁定，隐藏式抽拉面板保持展开；点击重置演示可退盘并收回。",
		"EJECTING": "退盘中 · 托盘与光盘同步退出机身。",
	}
	_status_label.text = str(messages.get(state, state))

func _reset_demo() -> void:
	if _drawer_preview == null:
		return
	if str(_drawer_preview.call("get_demo_state")) == "READY":
		_drawer_preview.call("reset_demo")
		if _status_label != null:
			_status_label.text = "已复位 · 光盘与托盘处于待机位置。"
		return
	_drawer_preview.call("animate_eject")
	if _status_label != null:
		_status_label.text = "退盘中 · 托盘与光盘正在同步退出。"

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _control_button(text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.toggle_mode = text_value.begins_with("01") or text_value.begins_with("02")
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(action)
	return button
