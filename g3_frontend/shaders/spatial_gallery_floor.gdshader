shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	vec2 uv = UV;
	// A restrained dark-teal floor: visible enough to establish a plane, never a black void.
	float depth_glow = (1.0 - smoothstep(0.08, 0.98, uv.y));
	float center_lane = exp(-pow((uv.x - 0.47) / 0.24, 2.0));
	float horizon_fade = smoothstep(0.05, 0.92, uv.y);
	vec3 base = mix(vec3(0.004, 0.012, 0.020), vec3(0.012, 0.036, 0.048), depth_glow);
	base += vec3(0.006, 0.030, 0.042) * center_lane * (0.25 + horizon_fade * 0.55);

	// Fine perspective-like seams. Their low contrast makes the floor readable without looking like a grid UI.
	float gx = abs(fract(uv.x * 22.0) - 0.5);
	float gy = abs(fract(uv.y * 14.0) - 0.5);
	float line_x = 1.0 - smoothstep(0.0, 0.012, gx);
	float line_y = 1.0 - smoothstep(0.0, 0.010, gy);
	float lines = max(line_x * 0.32, line_y * smoothstep(0.18, 0.92, uv.y) * 0.48);
	base += vec3(0.020, 0.070, 0.090) * lines * (0.18 + depth_glow * 0.32);

	// A broad, broken light path draws the eye through the scene rather than under the cards.
	float path = exp(-pow((uv.x - (0.24 + uv.y * 0.44)) / 0.035, 2.0));
	base += vec3(0.010, 0.044, 0.060) * path * (1.0 - uv.y * 0.45);

	ALBEDO = base;
	EMISSION = base * 0.62;
}
