extends Control
## G3 Material Lab · isolated CanvasItem material studies for the hidden Slim Loader.
## All previews are procedural and do not alter production materials or project rendering settings.


class AcrylicTestBed extends Control:
	var environment_mode: int = 0

	func set_environment_mode(mode: int) -> void:
		environment_mode = mode
		queue_redraw()

	var elapsed: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w < 2.0 or h < 2.0:
			return
		var k: float = h / 160.0
		var muted := Color(0.46, 0.62, 0.61, 0.82)
		var trace := Color(0.18, 0.48, 0.43, 0.96)
		var copper := Color(0.68, 0.43, 0.22, 0.95)
		var white := Color(0.82, 0.87, 0.81, 0.92)
		var amber := Color(1.0, 0.57, 0.19, 1.0)
		var cyan := Color(0.28, 0.82, 0.82, 1.0)

		# Optical calibration scale and readable markings.
		# Environment modes change the backdrop, not the glass shader parameters.
		var substrate := Color(0.025, 0.045, 0.043, 0.92)
		if environment_mode == 0:
			substrate = Color(0.025, 0.045, 0.043, 0.65)
		elif environment_mode == 1:
			substrate = Color(0.055, 0.065, 0.072, 0.78)
		else:
			substrate = Color(0.015, 0.015, 0.015, 1.0)
		draw_rect(Rect2(Vector2(10.0 * k, 9.0 * k), Vector2(w - 20.0 * k, h - 18.0 * k)), substrate, true)
		if environment_mode == 2:
			for bar in range(8):
				var patch := Rect2(Vector2(w * 0.05 + float(bar) * w * 0.105, h * 0.78), Vector2(w * 0.105, h * 0.115))
				draw_rect(patch, Color.WHITE if bar % 2 == 0 else Color.BLACK, true)
		draw_string(ThemeDB.fallback_font, Vector2(18.0 * k, 23.0 * k), "G3  /  OPTICAL TRANSMISSION TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.0 * k), white)
		draw_string(ThemeDB.fallback_font, Vector2(18.0 * k, h - 13.0 * k), "CAL 01   02   04   08   16       GLASS SURFACE / SUBVIEWPORT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8.0 * k), muted)
		for i in range(33):
			var x: float = 18.0 * k + float(i) * (w - 36.0 * k) / 32.0
			var tick_h: float = (11.0 if i % 4 == 0 else 5.0) * k
			draw_line(Vector2(x, 29.0 * k), Vector2(x, 29.0 * k + tick_h), Color(white, 0.65), maxf(0.7, 0.8 * k))
		draw_string(ThemeDB.fallback_font, Vector2(18.0 * k, 48.0 * k), "B  /  GLASS SURFACE TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * k), white)
		draw_string(ThemeDB.fallback_font, Vector2(18.0 * k, 61.0 * k), "ABCDEFGHIJKLMNOPQRSTUVWXYZ  0123456789", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8.0 * k), Color(0.78, 0.84, 0.80, 0.90))
		draw_string(ThemeDB.fallback_font, Vector2(18.0 * k, 73.0 * k), "Fine line / 0.25 mm     Contrast / 7:1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(7.0 * k), muted)

		# High-contrast resolution bars.
		var bar_x: float = w * 0.43
		for i in range(12):
			var bw: float = (2.0 + float(i % 3)) * k
			draw_rect(Rect2(Vector2(bar_x + float(i) * 5.0 * k, 39.0 * k), Vector2(bw, 28.0 * k)), white if i % 2 == 0 else Color(0.055, 0.09, 0.085, 1.0), true)

		# PCB substrate, IC package, fine traces and copper pads.
		var pcb_x: float = w * 0.53
		var pcb_y: float = h * 0.35
		var pcb_w: float = w * 0.28
		var pcb_h: float = h * 0.43
		draw_rect(Rect2(Vector2(pcb_x, pcb_y), Vector2(pcb_w, pcb_h)), Color(0.035, 0.13, 0.105, 0.96), true)
		draw_rect(Rect2(Vector2(pcb_x, pcb_y), Vector2(pcb_w, pcb_h)), Color(0.30, 0.49, 0.37, 0.75), false, maxf(0.8, k))
		var chip := Rect2(Vector2(pcb_x + pcb_w * 0.34, pcb_y + pcb_h * 0.24), Vector2(pcb_w * 0.30, pcb_h * 0.46))
		draw_rect(chip, Color(0.025, 0.035, 0.038, 1.0), true)
		draw_rect(chip, Color(0.43, 0.52, 0.47, 0.9), false, maxf(0.8, k))
		for i in range(6):
			var yy: float = chip.position.y + (float(i) + 0.5) * chip.size.y / 6.0
			draw_line(Vector2(chip.position.x - 5.0 * k, yy), Vector2(chip.position.x, yy), copper, maxf(0.8, k))
			draw_line(Vector2(chip.end.x, yy), Vector2(chip.end.x + 5.0 * k, yy), copper, maxf(0.8, k))
		var traces := [
			[Vector2(pcb_x, pcb_y + pcb_h * 0.20), Vector2(pcb_x + pcb_w * 0.18, pcb_y + pcb_h * 0.20), Vector2(pcb_x + pcb_w * 0.18, pcb_y + pcb_h * 0.37), Vector2(chip.position.x, pcb_y + pcb_h * 0.37)],
			[Vector2(chip.end.x, pcb_y + pcb_h * 0.60), Vector2(pcb_x + pcb_w * 0.84, pcb_y + pcb_h * 0.60), Vector2(pcb_x + pcb_w * 0.84, pcb_y + pcb_h * 0.82), Vector2(pcb_x + pcb_w, pcb_y + pcb_h * 0.82)],
			[Vector2(pcb_x + pcb_w * 0.48, pcb_y), Vector2(pcb_x + pcb_w * 0.48, chip.position.y)],
			[Vector2(pcb_x + pcb_w * 0.12, pcb_y + pcb_h), Vector2(pcb_x + pcb_w * 0.12, pcb_y + pcb_h * 0.70), Vector2(chip.position.x, pcb_y + pcb_h * 0.70)]
		]
		for path in traces:
			for j in range(path.size() - 1):
				draw_line(path[j], path[j + 1], trace, maxf(1.0, 1.3 * k), true)
		for point in [Vector2(pcb_x + pcb_w * 0.18, pcb_y + pcb_h * 0.20), Vector2(pcb_x + pcb_w * 0.84, pcb_y + pcb_h * 0.82), Vector2(pcb_x + pcb_w * 0.48, pcb_y + pcb_h * 0.12), Vector2(pcb_x + pcb_w * 0.12, pcb_y + pcb_h * 0.70)]:
			draw_circle(point, 3.0 * k, copper)
			draw_circle(point, 1.2 * k, Color(0.94, 0.72, 0.42, 1.0))

		# Amber and cyan indicators; pulse softly so haze and diffusion are visible.
		var led_y: float = h * 0.48
		var amber_center := Vector2(w * 0.88, led_y)
		var cyan_center := Vector2(w * 0.88, h * 0.70)
		var pulse: float = 0.72 + 0.28 * sin(elapsed * 2.4)
		for item in [[amber_center, amber, pulse], [cyan_center, cyan, 0.76 + 0.24 * sin(elapsed * 1.8 + 1.0)]]:
			var center: Vector2 = item[0]
			var color: Color = item[1]
			var strength: float = item[2]
			draw_circle(center, 12.0 * k, Color(color.r, color.g, color.b, 0.10 * strength))
			draw_circle(center, 6.0 * k, Color(color.r, color.g, color.b, 0.24 * strength))
			draw_circle(center, 2.8 * k, Color(color.r, color.g, color.b, strength))
			draw_circle(center, 1.0 * k, Color(1.0, 0.94, 0.76, strength))
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.83, h * 0.88), "PWR  /  DATA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(7.0 * k), muted)


class AcrylicReflectionEnvironment extends Control:
	var environment_mode: int = 0

	func set_environment_mode(mode: int) -> void:
		environment_mode = mode
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w < 2.0 or h < 2.0:
			return
		var k: float = h / 384.0
		if environment_mode == 0:
			# Match the production game atmosphere with its actual Shader resource.
			# A wide source and a narrow strip supply diagnostic reflection energy.
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.17, 0.23, 1.0), true)
		elif environment_mode == 1:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.085, 0.095, 1.0), true)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.005, 0.005, 1.0), true)
			for i in range(10):
				var band := Rect2(Vector2(float(i) * w * 0.1, 0.0), Vector2(w * 0.1, h))
				draw_rect(band, Color(0.95, 0.95, 0.95, 1.0) if i % 2 == 0 else Color(0.012, 0.012, 0.012, 1.0), true)
			return

		# Broad photography softbox: readable even under low Fresnel weights.
		var panel := Rect2(Vector2(w * 0.15, h * 0.08), Vector2(w * 0.33, h * 0.17))
		for i in range(9, 0, -1):
			var grow := float(i) * 5.0 * k
			draw_rect(panel.grow(grow), Color(0.80, 0.88, 0.98, 0.013), true)
		draw_rect(panel, Color(0.84, 0.90, 1.0, 0.92 if environment_mode == 1 else 0.65), true)
		var strip := Rect2(Vector2(w * 0.78, h * 0.17), Vector2(w * 0.045, h * 0.53))
		draw_rect(strip, Color(0.96, 0.96, 0.91, 0.88), true)

		# Long overhead softbox reflected as a feathered light streak.
		var light_a := Vector2(w * 0.12, h * 0.12)
		var light_b := Vector2(w * 0.50, h * 0.19)
		for layer in range(14, 0, -1):
			var width: float = (float(layer) * 2.8 + 3.0) * k
			var alpha: float = 0.0025 + float(14 - layer) * 0.0010
			draw_line(light_a, light_b, Color(0.76, 0.86, 0.81, alpha), width, true)
		draw_line(light_a, light_b, Color(0.86, 0.93, 0.88, 0.24), maxf(1.8, 3.0 * k), true)

		# A second, narrower vertical source gives the sheet a different reflection axis.
		var light_c := Vector2(w * 0.79, h * 0.18)
		var light_d := Vector2(w * 0.77, h * 0.73)
		for layer in range(10, 0, -1):
			var width: float = (float(layer) * 2.0 + 2.0) * k
			var alpha: float = 0.002 + float(10 - layer) * 0.0010
			draw_line(light_c, light_d, Color(0.67, 0.80, 0.77, alpha), width, true)
		draw_line(light_c, light_d, Color(0.82, 0.91, 0.86, 0.18), maxf(1.5, 2.5 * k), true)

		# Dim structural reflections keep the environment from reading as isolated lines.
		for i in range(5):
			var y: float = h * (0.80 + float(i) * 0.035)
			draw_line(
				Vector2(w * 0.08, y),
				Vector2(w * 0.92, y),
				Color(0.31, 0.42, 0.40, 0.025),
				maxf(0.7, k),
				true
			)

const SHADER_GAME_BACKGROUND: Shader = preload("res://shaders/game_background.gdshader")
const SHADER_GUNMETAL: Shader = preload("res://shaders/g3_material_aged_gunmetal.gdshader")
const SHADER_ACRYLIC: Shader = preload("res://shaders/g3_material_smoked_acrylic.gdshader") # Legacy colour-overlay reference.
const SHADER_REFRACTION_A: Shader = preload("res://shaders/g3_material_refraction_a.gdshader") # Archived displacement-only A test.
const SHADER_GLASS_SURFACE_B: Shader = preload("res://shaders/g3_material_glass_surface_b.gdshader")
const SHADER_PHOSPHOR: Shader = preload("res://shaders/g3_material_amber_phosphor.gdshader")
const SHADER_PCB: Shader = preload("res://shaders/g3_material_internal_pcb.gdshader")

const COLOR_TEXT := Color(0.84, 0.88, 0.91, 1.0)
const COLOR_MUTED := Color(0.57, 0.66, 0.72, 1.0)
const COLOR_PANEL := Color(0.065, 0.082, 0.088, 1.0)
const PREVIEW_ASPECT_RATIO: float = 2.5
const PREVIEW_MIN_HEIGHT: float = 160.0

var _accent: Color = Color(0.76, 0.48, 0.20, 1.0)
var _accent_picker: ColorPickerButton
var _cards: Dictionary = {}
var _active: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func set_page_active(active: bool) -> void:
	_active = active
	set_process(active)

func apply_game_theme_palette(palette: Dictionary) -> void:
	var colors_value: Variant = palette.get("colors", palette)
	var colors: Dictionary = colors_value as Dictionary if colors_value is Dictionary else {}
	var accent_value: Variant = colors.get("accent", "")
	if typeof(accent_value) == TYPE_COLOR:
		_set_accent(accent_value)
	elif not str(accent_value).strip_edges().is_empty():
		_set_accent(Color.from_string(str(accent_value), _accent))

func reset_game_theme_palette() -> void:
	_set_accent(Color(0.76, 0.48, 0.20, 1.0))

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	heading.add_child(_label("MATERIAL LAB · 复古工业材质", 17, COLOR_TEXT))
	heading.add_child(_label("四套独立 CanvasItem Shader · 程序化纹理 · 可调参数 · 不修改正式 Slim Loader", 11, COLOR_MUTED))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	header.add_child(_label("主题强调色", 11, COLOR_MUTED))
	_accent_picker = ColorPickerButton.new()
	_accent_picker.color = _accent
	_accent_picker.custom_minimum_size = Vector2(38.0, 26.0)
	_accent_picker.color_changed.connect(_on_accent_changed)
	header.add_child(_accent_picker)

	var note := _label("材质说明：M02-B 将 SubViewport 作为透射底图，以低幅微折射保留内部结构，再叠加环境软箱反射、边缘 Fresnel、轻微烟熏吸收与表面粗糙度。", 10, COLOR_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	grid.add_child(_build_material_card(
		"M01", "AGED GUNMETAL", "旧化拉丝金属",
		"方向性拉丝、细微划痕、边缘磨损与机加工高光。噪声按低频 / 高频分层，避免整块金属变成随机脏点。",
		SHADER_GUNMETAL, "拉丝与磨损强度", "grain_amount", 0.0, 1.0, 0.42
	))
	grid.add_child(_build_material_card(
		"M02", "SMOKED ACRYLIC", "烟熏半透明塑料",
		"B 实验：以独立 SubViewport 作为透射底图。微折射控制在像素级，叠加软箱环境反射、边缘 Fresnel 与轻微烟熏吸收；不再使用周期性水波扭曲。",
		SHADER_GLASS_SURFACE_B, "微折射上限 (px)", "refraction_strength_px", 0.0, 2.0, 0.75
	))
	grid.add_child(_build_material_card(
		"M03", "AMBER PHOSPHOR", "琥珀荧光指示灯",
		"灯芯、透镜环、近场光晕和远场柔光分层。Shader 内部提供柔光模拟；真正的屏幕 Bloom 仍由项目后处理决定。",
		SHADER_PHOSPHOR, "荧光强度", "glow_strength", 0.0, 2.0, 1.0
	))
	grid.add_child(_build_material_card(
		"M04", "INTERNAL PCB", "透明外壳下的电路板",
		"正交线路、焊盘、细线路与移动信号脉冲。重点观察线路亮度、信号速度和小尺寸下的细节保留。",
		SHADER_PCB, "信号流动速度", "pulse_speed", 0.0, 4.0, 0.72
	))

func _build_material_card(
	code: String,
	title: String,
	local_title: String,
	description: String,
	shader: Shader,
	control_label: String,
	parameter: String,
	minimum: float,
	maximum: float,
	default_value: float
) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(460.0, 370.0) if code == "M02" else Vector2(460.0, 202.0)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = Color(0.22, 0.29, 0.30, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 9
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	top.add_child(_label(code, 10, _accent))
	top.add_child(_label(title, 12, COLOR_TEXT))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	top.add_child(_label(local_title, 10, COLOR_MUTED))

	var preview_back := Control.new()
	preview_back.custom_minimum_size = Vector2(0.0, PREVIEW_MIN_HEIGHT)
	preview_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_back.clip_contents = true
	column.add_child(preview_back)

	var material := ShaderMaterial.new()
	material.shader = shader
	if code != "M02":
		material.set_shader_parameter("accent_color", _accent)

	var preview: Control
	var source_viewport: SubViewport = null
	var reflection_viewport: SubViewport = null
	if code == "M02":
		# Transmission and environment reflection are rendered separately.
		# The glass shader combines both textures; it never distorts the source alone.
		source_viewport = SubViewport.new()
		source_viewport.name = "AcrylicTransmissionSource"
		source_viewport.size = Vector2i(960, 384)
		source_viewport.transparent_bg = false
		source_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		preview_back.add_child(source_viewport)

		# Production atmosphere behind the diagnostic test objects.
		var game_back := ColorRect.new()
		game_back.name = "GameAtmosphereReference"
		game_back.color = Color.WHITE
		var background_material := ShaderMaterial.new()
		background_material.shader = SHADER_GAME_BACKGROUND
		game_back.material = background_material
		game_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		game_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source_viewport.add_child(game_back)

		var test_bed := AcrylicTestBed.new()
		test_bed.name = "AcrylicTransmissionTestBed"
		test_bed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		test_bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source_viewport.add_child(test_bed)

		reflection_viewport = SubViewport.new()
		reflection_viewport.name = "AcrylicEnvironmentReflection"
		reflection_viewport.size = Vector2i(960, 384)
		reflection_viewport.transparent_bg = false
		reflection_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		preview_back.add_child(reflection_viewport)

		var reflection_environment := AcrylicReflectionEnvironment.new()
		reflection_environment.name = "AcrylicSoftboxEnvironment"
		reflection_environment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		reflection_viewport.add_child(reflection_environment)

		var texture_preview := TextureRect.new()
		texture_preview.name = "AcrylicRefractionPreview"
		texture_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_preview.stretch_mode = TextureRect.STRETCH_SCALE
		texture_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_preview.material = material
		texture_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		preview = texture_preview
		call_deferred("_bind_viewport_textures", texture_preview, source_viewport, reflection_viewport, material)

		# All three modes share exactly the same material and parameter sliders.
		var environment_row := HBoxContainer.new()
		environment_row.name = "M02EnvironmentSelector"
		environment_row.add_theme_constant_override("separation", 8)
		column.add_child(environment_row)
		environment_row.add_child(_label("测试环境", 10, COLOR_MUTED))
		var environment_select := OptionButton.new()
		environment_select.name = "M02EnvironmentModes"
		environment_select.add_item("A · 游戏背景", 0)
		environment_select.add_item("B · 摄影棚软箱", 1)
		environment_select.add_item("C · 黑白诊断", 2)
		environment_select.selected = 0
		environment_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		environment_row.add_child(environment_select)
		environment_select.item_selected.connect(func(index: int) -> void:
			test_bed.set_environment_mode(index)
			reflection_environment.set_environment_mode(index)
			game_back.visible = index == 0
		)
		var env_help := _label("仅切换透射底图和反射环境；玻璃 Shader 与所有滑块值保持不变。", 9, COLOR_MUTED)
		env_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(env_help)
	else:
		var dark_field := ColorRect.new()
		dark_field.color = Color(0.035, 0.048, 0.052, 1.0)
		dark_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dark_field.anchor_right = 0.5
		dark_field.offset_right = 0.0
		dark_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_back.add_child(dark_field)
		var light_field := ColorRect.new()
		light_field.color = Color(0.30, 0.34, 0.32, 1.0)
		light_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		light_field.anchor_left = 0.5
		light_field.offset_left = 0.0
		light_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_back.add_child(light_field)
		var field_divider := ColorRect.new()
		field_divider.color = Color(0.72, 0.76, 0.69, 0.55)
		field_divider.anchor_left = 0.5
		field_divider.anchor_right = 0.5
		field_divider.offset_left = -0.5
		field_divider.offset_right = 0.5
		field_divider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field_divider.anchor_left = 0.5
		field_divider.anchor_right = 0.5
		field_divider.offset_left = -0.5
		field_divider.offset_right = 0.5
		field_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_back.add_child(field_divider)
		var color_preview := ColorRect.new()
		color_preview.color = Color.WHITE
		color_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview = color_preview

	preview_back.add_child(preview)
	_cards[code] = material
	# Keep a controlled 2.5:1 preview ratio. M02 scales its independent render
	# target with the displayed preview to keep the sampled ViewportTexture crisp.
	preview_back.resized.connect(_sync_preview_dimensions.bind(preview_back, material, source_viewport, reflection_viewport))
	call_deferred("_sync_preview_dimensions", preview_back, material, source_viewport, reflection_viewport)

	var description_label := _label(description, 10, COLOR_MUTED)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description_label)

	_add_parameter_slider(column, material, control_label, parameter, minimum, maximum, default_value)
	if code == "M02":
		var helper := _label("B 实验：内部物体保持基本清晰，只允许轻微位移。观察环境反射和边缘高光是否让人感到表面有一层独立玻璃；参数彼此独立。", 9, COLOR_MUTED)
		helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(helper)
		_add_parameter_slider(column, material, "微表面尺度", "surface_frequency", 0.5, 2.5, 1.1)
		_add_parameter_slider(column, material, "环境反射", "reflection_strength", 0.0, 0.8, 0.42)
		_add_parameter_slider(column, material, "烟熏吸收", "smoke_density", 0.0, 0.35, 0.10)
		_add_parameter_slider(column, material, "表面粗糙度", "surface_roughness", 0.0, 1.0, 0.12)
		_add_parameter_slider(column, material, "边缘 Fresnel", "edge_reflection", 0.0, 1.0, 0.55)
		var toggle_row := HBoxContainer.new()
		toggle_row.add_theme_constant_override("separation", 8)
		column.add_child(toggle_row)
		var glass_toggle := CheckButton.new()
		glass_toggle.text = "玻璃表面开启"
		glass_toggle.button_pressed = true
		glass_toggle.toggled.connect(func(enabled: bool) -> void:
			preview.material = material if enabled else null
		)
		toggle_row.add_child(glass_toggle)
		toggle_row.add_child(_label("开启 / 原始 SubViewport 对照", 9, COLOR_MUTED))
	return card


func _add_parameter_slider(
	parent: VBoxContainer,
	material: ShaderMaterial,
	control_label: String,
	parameter: String,
	minimum: float,
	maximum: float,
	default_value: float
) -> void:
	var parameter_row := HBoxContainer.new()
	parameter_row.add_theme_constant_override("separation", 8)
	parent.add_child(parameter_row)
	parameter_row.add_child(_label(control_label, 10, COLOR_MUTED))
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = default_value
	slider.custom_minimum_size.y = 18.0
	slider.value_changed.connect(func(value: float) -> void:
		material.set_shader_parameter(parameter, value)
	)
	parameter_row.add_child(slider)
	var value_label := _label(_format_parameter(default_value), 10, COLOR_TEXT)
	value_label.custom_minimum_size.x = 38.0
	parameter_row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _format_parameter(value)
	)


func _bind_viewport_textures(
	preview: TextureRect,
	transmission_viewport: SubViewport,
	reflection_viewport: SubViewport,
	material: ShaderMaterial
) -> void:
	if not is_instance_valid(preview) or not is_instance_valid(transmission_viewport):
		return
	if not is_instance_valid(reflection_viewport) or not is_instance_valid(material):
		return
	preview.texture = transmission_viewport.get_texture()
	material.set_shader_parameter("reflection_texture", reflection_viewport.get_texture())


func _sync_preview_dimensions(
	preview_back: Control,
	material: ShaderMaterial,
	source_viewport: SubViewport = null,
	reflection_viewport: SubViewport = null
) -> void:
	if not is_instance_valid(preview_back) or not is_instance_valid(material):
		return
	var preview_width: float = preview_back.size.x
	if preview_width < 1.0:
		return
	var preview_height: float = maxf(PREVIEW_MIN_HEIGHT, preview_width / PREVIEW_ASPECT_RATIO)
	if absf(preview_back.custom_minimum_size.y - preview_height) > 0.75:
		preview_back.custom_minimum_size = Vector2(0.0, preview_height)
	var shader_size := Vector2(preview_width, preview_height)
	if source_viewport != null and is_instance_valid(source_viewport):
		var render_width: int = clampi(roundi(preview_width * 1.5), 640, 2048)
		var render_height: int = maxi(256, roundi(float(render_width) / PREVIEW_ASPECT_RATIO))
		var render_size := Vector2i(render_width, render_height)
		if source_viewport.size != render_size:
			source_viewport.size = render_size
		if reflection_viewport != null and is_instance_valid(reflection_viewport):
			if reflection_viewport.size != render_size:
				reflection_viewport.size = render_size
		shader_size = Vector2(render_size)
	material.set_shader_parameter("panel_size", shader_size)

func _set_accent(color: Color) -> void:
	_accent = color
	if _accent_picker != null:
		_accent_picker.color = color
	for code in _cards:
		var material: ShaderMaterial = _cards[code]
		if material != null and code != "M02":
			material.set_shader_parameter("accent_color", color)

func _on_accent_changed(color: Color) -> void:
	_set_accent(color)

func _format_parameter(value: float) -> String:
	return "%.2f" % value

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
