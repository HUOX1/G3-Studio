shader_type canvas_item;

uniform vec4 panel_color : source_color = vec4(0.055, 0.065, 0.085, 1.0);
uniform vec4 theme_top_color : source_color = vec4(0.10, 0.16, 0.24, 1.0);
uniform vec4 theme_bottom_color : source_color = vec4(0.08, 0.10, 0.14, 1.0);
uniform float theme_strength : hint_range(0.0, 1.0) = 0.0;
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
	// Hero theme hue is strongest near the panel's upper region and fades toward a neutral deep surface.
	float theme_mix = theme_strength * mix(0.68, 0.22, clamp(UV.y, 0.0, 1.0));
	vec3 theme_rgb = mix(theme_top_color.rgb, theme_bottom_color.rgb, clamp(UV.y, 0.0, 1.0));
	vec3 panel_rgb = mix(panel_color.rgb, theme_rgb, theme_mix);
	// Subtle chassis material, without overriding the existing Hero transparency.
	// UV-space texture is intentionally low contrast: it must not compete with text.
	float fine_grain = fract(sin(dot(floor(UV * vec2(970.0, 620.0)), vec2(12.9898, 78.233))) * 43758.5453);
	panel_rgb *= 1.0 + (fine_grain - 0.5) * 0.016;
	// Avoid making the upper feather region look like a rigid metal border.
	float surface_presence = smoothstep(extend_end, extend_end + 0.12, UV.y);
	float top_sheen = exp(-pow((UV.y - extend_end - 0.023) / 0.042, 2.0));
	panel_rgb += vec3(0.022, 0.030, 0.035) * top_sheen * surface_presence;
	float left_edge = 1.0 - smoothstep(0.0, 0.018, UV.x);
	float right_edge = smoothstep(0.982, 1.0, UV.x);
	panel_rgb += vec3(0.018, 0.025, 0.030) * left_edge * surface_presence;
	panel_rgb -= vec3(0.013, 0.016, 0.019) * right_edge * surface_presence;
	COLOR = vec4(clamp(panel_rgb, vec3(0.0), vec3(1.0)), panel_color.a * a);
}
