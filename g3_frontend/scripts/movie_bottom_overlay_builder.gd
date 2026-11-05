extends RefCounted

# UI-S4a: 仅创建电影底部交互节点及过场遮罩。
# 节点添加顺序、父级、锚点、输入过滤和默认透明度保持不变；
# 动画、热区命中判定和页面切换仍由 main.gd 管理。
func build_bottom(parent: Control, hidden_height: float, hot_width: float, hot_height: float) -> Dictionary:
	var layer: Control = Control.new()
	layer.anchor_left = 0.0
	layer.anchor_right = 1.0
	layer.anchor_top = 1.0
	layer.anchor_bottom = 1.0
	layer.offset_top = 0.0
	layer.offset_bottom = hidden_height
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)

	var tagline: Label = Label.new()
	tagline.text = ""
	tagline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78, 0.75))
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tagline)

	var hot_zone: Control = Control.new()
	hot_zone.anchor_left = 1.0
	hot_zone.anchor_right = 1.0
	hot_zone.anchor_top = 1.0
	hot_zone.anchor_bottom = 1.0
	hot_zone.offset_left = -hot_width
	hot_zone.offset_right = 0.0
	hot_zone.offset_top = -hot_height
	hot_zone.offset_bottom = 0.0
	hot_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hot_zone)

	var arrow: Label = Label.new()
	arrow.text = "⌄"
	arrow.anchor_left = 1.0
	arrow.anchor_right = 1.0
	arrow.anchor_top = 1.0
	arrow.anchor_bottom = 1.0
	arrow.offset_left = -40.0
	arrow.offset_right = -14.0
	arrow.offset_top = -34.0
	arrow.offset_bottom = -10.0
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.modulate.a = 0.0
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arrow)

	return {"layer": layer, "tagline": tagline, "hot_zone": hot_zone, "arrow": arrow}


func create_fade_layer(owner: Node) -> CanvasLayer:
	var fade_layer: CanvasLayer = CanvasLayer.new()
	fade_layer.layer = 110
	owner.add_child(fade_layer)
	return fade_layer


func create_fade_rect(fade_layer: CanvasLayer) -> ColorRect:
	var fade: ColorRect = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.02, 0.04, 0.06, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.visible = false
	fade_layer.add_child(fade)
	return fade
