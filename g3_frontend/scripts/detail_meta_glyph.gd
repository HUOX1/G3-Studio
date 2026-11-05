extends Control

# Vector pictograms: independent from text fonts, tintable with one color.
var kind: String = "time"
const INK: Color = Color(0.55, 0.66, 0.77, 0.94)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	# Clock glyph optical center sits slightly above the text-line center.
	if kind == "time":
		center.y -= 1.5
	var scale_factor: float = minf(size.x, size.y) / 24.0
	draw_set_transform(center, 0.0, Vector2(scale_factor, scale_factor))
	match kind:
		"time":
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 48, INK, 1.9, true)
			draw_line(Vector2.ZERO, Vector2(0.0, -5.5), INK, 1.8, true)
			draw_line(Vector2.ZERO, Vector2(4.0, 2.5), INK, 1.8, true)
		"score":
			var pts := PackedVector2Array()
			for i in range(10):
				var angle: float = -PI * 0.5 + float(i) * TAU / 10.0
				var r: float = 10.0 if i % 2 == 0 else 4.6
				pts.append(Vector2(cos(angle), sin(angle)) * r)
			for i in range(10):
				draw_line(pts[i], pts[(i + 1) % 10], INK, 1.8, true)
		"date":
			draw_rect(Rect2(-9, -7, 18, 16), INK, false, 1.8)
			draw_line(Vector2(-9, -2), Vector2(9, -2), INK, 1.8, true)
			draw_line(Vector2(-5, -10), Vector2(-5, -4), INK, 2.0, true)
			draw_line(Vector2(5, -10), Vector2(5, -4), INK, 2.0, true)
		"developer":
			draw_arc(Vector2(0, -5), 4.4, 0, TAU, 32, INK, 1.8, true)
			draw_arc(Vector2(0, 10), 8.2, PI, TAU, 32, INK, 1.8, true)
		"publisher":
			draw_rect(Rect2(-7, -9, 14, 18), INK, false, 1.7)
			for yy in [-5.0, 0.0, 5.0]:
				for xx in [-3.0, 3.0]:
					draw_rect(Rect2(xx - 1.0, yy - 1.0, 2.0, 2.0), INK, true)
		"genre":
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 48, INK, 1.7, true)
			draw_circle(Vector2(-3.5, -1.8), 1.5, INK)
			draw_circle(Vector2(3.5, -1.8), 1.5, INK)
			draw_arc(Vector2(0, 1.5), 4.2, 0, PI, 20, INK, 1.5, true)
	draw_set_transform(Vector2.ZERO)
