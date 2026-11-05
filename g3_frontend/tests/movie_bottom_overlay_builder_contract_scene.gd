extends Node

const EXPECTED_CHECKS: int = 43
const BUILDER: Script = preload("res://scripts/movie_bottom_overlay_builder.gd")

var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _run() -> void:
	var root: Control = Control.new()
	add_child(root)
	var builder = BUILDER.new()
	var nodes: Dictionary = builder.build_bottom(root, 160.0, 220.0, 140.0)
	var layer: Control = nodes["layer"] as Control
	var tagline: Label = nodes["tagline"] as Label
	var hot: Control = nodes["hot_zone"] as Control
	var arrow: Label = nodes["arrow"] as Label
	_check(nodes.size() == 4, "four stable references")
	_check(root.get_child_count() == 3, "three top-level overlay nodes")
	_check(root.get_child(0) == layer, "hidden layer first")
	_check(root.get_child(1) == hot, "hot zone second")
	_check(root.get_child(2) == arrow, "arrow third")
	_check(layer.get_child_count() == 1, "hidden layer contains one tagline")
	_check(tagline.get_parent() == layer, "tagline parent preserved")
	_check(layer.anchor_left == 0.0, "layer left anchor")
	_check(layer.anchor_right == 1.0, "layer right anchor")
	_check(layer.anchor_top == 1.0, "layer top anchor")
	_check(layer.anchor_bottom == 1.0, "layer bottom anchor")
	_check(layer.offset_top == 0.0, "layer top offset")
	_check(layer.offset_bottom == 160.0, "layer height")
	_check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "layer input passthrough")
	_check(tagline.text == "", "tagline starts empty")
	_check(tagline.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "tagline horizontal center")
	_check(tagline.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "tagline vertical center")
	_check(tagline.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "tagline wrapping")
	_check(tagline.get_theme_font_size("font_size") == 22, "tagline font size")
	_check(tagline.get_theme_color("font_color") == Color(1.0, 0.92, 0.78, 0.75), "tagline color")
	_check(tagline.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tagline input passthrough")
	_check(hot.anchor_left == 1.0 and hot.anchor_right == 1.0, "hot zone horizontal anchors")
	_check(hot.anchor_top == 1.0 and hot.anchor_bottom == 1.0, "hot zone vertical anchors")
	_check(hot.offset_left == -220.0 and hot.offset_right == 0.0, "hot zone width and edge")
	_check(hot.offset_top == -140.0 and hot.offset_bottom == 0.0, "hot zone height and edge")
	_check(hot.mouse_filter == Control.MOUSE_FILTER_PASS, "hot zone receives input")
	_check(arrow.text == "⌄", "arrow glyph unchanged")
	_check(arrow.anchor_left == 1.0 and arrow.anchor_right == 1.0, "arrow horizontal anchors")
	_check(arrow.anchor_top == 1.0 and arrow.anchor_bottom == 1.0, "arrow vertical anchors")
	_check(arrow.offset_left == -40.0 and arrow.offset_right == -14.0, "arrow horizontal offsets")
	_check(arrow.offset_top == -34.0 and arrow.offset_bottom == -10.0, "arrow vertical offsets")
	_check(arrow.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "arrow horizontal alignment")
	_check(arrow.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "arrow vertical alignment")
	_check(arrow.get_theme_font_size("font_size") == 20, "arrow font size")
	_check(arrow.modulate.a == 0.0, "arrow initially invisible")
	_check(arrow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "arrow input passthrough")
	var fade_layer: CanvasLayer = builder.create_fade_layer(self)
	var fade: ColorRect = builder.create_fade_rect(fade_layer)
	_check(fade_layer.layer == 110, "fade canvas order unchanged")
	_check(fade.get_parent() == fade_layer, "fade rect parent unchanged")
	_check(fade.color == Color(0.02, 0.04, 0.06, 0.0), "fade default color unchanged")
	_check(not fade.visible and fade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fade initially hidden and input ignored")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("MOVIE_BOTTOM_OVERLAY_BUILDER_SCRIPT.new().build_bottom("), "main delegates bottom overlay")
	_check(main_source.contains("_section_fade = MOVIE_BOTTOM_OVERLAY_BUILDER_SCRIPT.new().create_fade_rect(fade_layer)"), "main retains section fade reference")
	_check(not main_source.contains("_hidden_layer = Control.new()"), "old inline bottom overlay removed")
	if failures == 0 and checks == EXPECTED_CHECKS:
		print("MOVIE BOTTOM OVERLAY BUILDER CONTRACT PASS: %d checks" % checks)
		get_tree().quit(0)
	else:
		push_error("MOVIE BOTTOM OVERLAY BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
