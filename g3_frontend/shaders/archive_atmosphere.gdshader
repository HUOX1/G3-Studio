shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	vec2 p = UV;
	vec2 cool = (p - vec2(0.34, 0.58)) * vec2(1.0, 1.5);
	vec2 warm = (p - vec2(0.82, 0.44)) * vec2(1.4, 1.7);
	vec3 walls = mix(vec3(0.026, 0.052, 0.058), vec3(0.008, 0.022, 0.029), p.y);
	walls += vec3(0.025, 0.051, 0.055) * exp(-dot(cool, cool) * 8.0);
	walls += vec3(0.042, 0.025, 0.014) * exp(-dot(warm, warm) * 11.0);
	float recess = 1.0 - smoothstep(0.0, 0.018, abs(p.x - 0.68));
	walls += vec3(0.031, 0.045, 0.039) * recess * 0.24;
	ALBEDO = walls;
	EMISSION = walls * 0.30;
}
