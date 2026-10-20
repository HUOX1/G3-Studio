shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.48, 0.48);
	float vignette = smoothstep(0.26, 0.88, length(p * vec2(1.05, 0.84)));
	vec3 base = mix(vec3(0.012, 0.030, 0.043), vec3(0.003, 0.008, 0.016), vignette * 0.88);

	// Off-center light gives the scene a direction instead of a flat centered gradient.
	vec2 cool_delta = (uv - vec2(0.34, 0.47)) * vec2(1.35, 1.05);
	float cool_glow = exp(-dot(cool_delta, cool_delta) * 4.2);
	vec2 amber_delta = (uv - vec2(0.82, 0.42)) * vec2(1.7, 1.2);
	float amber_glow = exp(-dot(amber_delta, amber_delta) * 7.0);
	base += vec3(0.022, 0.078, 0.112) * cool_glow * 0.72;
	base += vec3(0.075, 0.035, 0.018) * amber_glow * 0.22;

	// Broad diagonal light folds create a sense of architectural planes behind the cases.
	float fold_a = exp(-pow((uv.y - (0.20 + uv.x * 0.23)) / 0.060, 2.0));
	float fold_b = exp(-pow((uv.y - (0.76 - uv.x * 0.20)) / 0.085, 2.0));
	float fold_c = exp(-pow((uv.y - (0.48 + uv.x * 0.06)) / 0.16, 2.0));
	base += vec3(0.010, 0.037, 0.052) * fold_a * (1.0 - vignette * 0.55);
	base += vec3(0.008, 0.024, 0.038) * fold_b * 0.68;
	base += vec3(0.008, 0.022, 0.032) * fold_c * 0.22;

	// A low horizon glow connects the backdrop to the floor without creating a hard black cut.
	float horizon = exp(-pow((uv.y - 0.70) / 0.11, 2.0));
	base += vec3(0.012, 0.045, 0.060) * horizon * (1.0 - vignette * 0.40);

	// Sparse distant seams are deliberately irregular and very low contrast.
	float seam_a = 1.0 - smoothstep(0.0, 0.009, abs(uv.y - (0.31 + uv.x * 0.22)));
	float seam_b = 1.0 - smoothstep(0.0, 0.008, abs(uv.y - (0.60 - uv.x * 0.12)));
	base += vec3(0.030, 0.070, 0.086) * (seam_a * 0.12 + seam_b * 0.08);

	ALBEDO = base;
	EMISSION = base * 0.42;
}
