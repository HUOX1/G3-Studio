shader_type canvas_item;

uniform vec4 panel_color : source_color = vec4(0.055, 0.065, 0.085, 1.0);
// 面板顶边的 alpha（渐变区的"入口值"）
uniform float top_alpha : hint_range(0.0, 1.0) = 0.2;
// 面板内渐变区占面板实际高度的比例
uniform float gradient_ratio : hint_range(0.0, 1.0) = 0.5;
// 延伸区高度 / 面板实际高度（向上多画一段用于羽化）
uniform float extend_ratio : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	// _panel_bg 的高度 = 面板高 × (1 + extend_ratio)
	// UV.y = 0 → 延伸区顶（alpha 0）
	// UV.y = extend_end → 面板顶边（alpha = top_alpha）
	// UV.y = gradient_end → 渐变结束（alpha 1.0）
	// UV.y = 1 → 面板底

	float extend_end = extend_ratio / (1.0 + extend_ratio);
	float gradient_end = extend_end + gradient_ratio / (1.0 + extend_ratio);

	float a;
	if (UV.y < extend_end) {
		// 延伸区：alpha 0 → top_alpha
		float t = UV.y / max(extend_end, 0.0001);
		a = mix(0.0, top_alpha, t);
	} else if (UV.y < gradient_end) {
		// 面板内渐变区：alpha top_alpha → 1.0
		float t = (UV.y - extend_end) / max(gradient_end - extend_end, 0.0001);
		a = mix(top_alpha, 1.0, t);
	} else {
		a = 1.0;
	}
	COLOR = vec4(panel_color.rgb, panel_color.a * a);
}
