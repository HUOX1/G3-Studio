shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec3 bg_top : source_color = vec3(0.135, 0.260, 0.470);
uniform vec3 bg_bottom : source_color = vec3(0.055, 0.125, 0.270);

// ── 主波 / 副波共用的蓝色三段渐变 ──
uniform vec3 wave_blue_top : source_color = vec3(0.22, 0.38, 0.58);
uniform vec3 wave_blue_core : source_color = vec3(0.14, 0.26, 0.44);
uniform vec3 wave_blue_bottom : source_color = vec3(0.07, 0.16, 0.32);

// ── 第三波：撞色循环（4 个 base 色轮流）──
uniform vec3 wave3_base_a : source_color = vec3(1.00, 0.10, 0.85);   // 荧光品红
uniform vec3 wave3_base_b : source_color = vec3(0.15, 1.00, 0.35);   // 荧光绿
uniform vec3 wave3_base_c : source_color = vec3(1.30, 1.20, 0.10);   // 电光黄
uniform vec3 wave3_base_d : source_color = vec3(0.10, 0.95, 1.30);   // 电光青

// 循环速度：0 = 不变色；0.04 ≈ 25 秒一轮
uniform float wave3_color_speed : hint_range(0.0, 0.5) = 0.04;
// 三段渐变的明暗乘数（上亮下暗）
uniform float wave3_top_mult : hint_range(0.5, 2.0) = 1.20;
uniform float wave3_bottom_mult : hint_range(0.1, 1.0) = 0.30;

// ── 主波 ──
uniform float wave_y : hint_range(0.0, 1.0) = 0.40;
uniform float wave_thickness : hint_range(0.05, 0.40) = 0.10;
uniform float wave_amplitude : hint_range(0.0, 0.25) = 0.030;
uniform float wave_speed : hint_range(-2.0, 2.0) = 0.16;
uniform float wave_freq : hint_range(0.3, 3.0) = 0.85;
uniform float wave_hollow : hint_range(0.5, 4.0) = 1.5;
uniform float wave_intensity : hint_range(0.0, 1.5) = 0.75;
uniform float wave_edge_bias : hint_range(-1.0, 1.0) = -0.8;

// ── 副波 ──
uniform float wave2_y : hint_range(0.0, 1.0) = 0.35;
uniform float wave2_thickness : hint_range(0.05, 0.40) = 0.13;
uniform float wave2_amplitude : hint_range(0.0, 0.25) = 0.020;
uniform float wave2_speed : hint_range(-2.0, 2.0) = 0.38;
uniform float wave2_freq : hint_range(0.3, 3.0) = 1.30;
uniform float wave2_hollow : hint_range(0.5, 4.0) = 1.0;
uniform float wave2_intensity : hint_range(0.0, 1.5) = 0.45;
uniform float wave2_edge_bias : hint_range(-1.0, 1.0) = 0;

// ── 第三波（细、密、安静、荧光红）──
uniform float wave3_y : hint_range(0.0, 1.0) = 0.40;
uniform float wave3_thickness : hint_range(0.02, 0.40) = 0.10;
uniform float wave3_amplitude : hint_range(0.0, 0.25) = 0.013;
uniform float wave3_speed : hint_range(-2.0, 2.0) = 0.8;
uniform float wave3_freq : hint_range(0.3, 3.0) = 1.85;
uniform float wave3_hollow : hint_range(0.5, 4.0) = 2.5;
uniform float wave3_intensity : hint_range(0.0, 1.5) = 0.2;
uniform float wave3_edge_bias : hint_range(-1.0, 1.0) = 0.9;
// 1.0 = 不透明实心（第三条专用）；0.0 = 保持原来的加法 + 中空
uniform float wave3_solid : hint_range(0.0, 1.0) = 0.4;

uniform float edge_soft : hint_range(0.002, 0.030) = 0.01;
uniform float hollow_min : hint_range(0.0, 0.8) = 0.05;
uniform float grain_amount : hint_range(0.0, 0.08) = 0.007;

uniform float overlap_strength : hint_range(0.0, 0.6) = 0.28;
uniform float overlap_near : hint_range(0.0, 0.3) = 0.04;
uniform float overlap_far : hint_range(0.05, 0.5) = 0.22;

uniform float side_right_amp_scale : hint_range(0.0, 1.0) = 0.50;
uniform float side_right_thick_scale : hint_range(0.0, 1.0) = 0.60;
uniform float side_y_spread : hint_range(0.0, 0.15) = 0.04;
uniform float side_left_intensity : hint_range(0.0, 1.0) = 0.55;
uniform float side_power : hint_range(0.3, 4.0) = 1.2;

uniform float macro_warp : hint_range(0.0, 2.0) = 1.20;
uniform float thickness_wobble : hint_range(0.0, 0.6) = 0.35;

uniform vec3 reflection_color : source_color = vec3(0.72, 0.88, 1.00);
uniform float reflection_amount : hint_range(0.0, 1.5) = 0.0;
uniform float reflection_power : hint_range(4.0, 30.0) = 4.0;

// ── 光点：大颗层 ──
uniform float sparkle_density : hint_range(10.0, 200.0) = 60.0;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.55;
uniform float sparkle_size : hint_range(0.005, 0.10) = 0.060;
uniform float sparkle_ratio : hint_range(0.80, 0.999) = 0.955;
uniform float sparkle_spread : hint_range(0.05, 0.60) = 0.55;
uniform float sparkle_size_var : hint_range(0.0, 1.0) = 1.0;
uniform float sparkle_bright_var : hint_range(0.0, 1.0) = 1.0;
uniform float sparkle_drift_x : hint_range(-0.5, 0.5) = 0.4;
uniform float sparkle_drift_y : hint_range(-0.5, 0.5) = -0.015;
uniform float sparkle_wobble : hint_range(0.0, 0.30) = 0.08;
uniform vec3 sparkle_color : source_color = vec3(0.65, 0.80, 0.95);

// ── 光点：小颗层 ──
uniform float sparkle2_density : hint_range(20.0, 300.0) = 110.0;
uniform float sparkle2_amount : hint_range(0.0, 1.0) = 0.35;
uniform float sparkle2_size : hint_range(0.003, 0.06) = 0.024;
uniform float sparkle2_ratio : hint_range(0.80, 0.999) = 0.965;
uniform float sparkle2_drift_x : hint_range(-0.5, 0.5) = 0.22;
uniform float sparkle2_drift_y : hint_range(-0.5, 0.5) = -0.008;
uniform vec3 sparkle2_color : source_color = vec3(0.55, 0.68, 0.86);

uniform float viewport_aspect : hint_range(0.5, 3.0) = 1.78;

uniform float breath_amount : hint_range(0.0, 0.3) = 0.06;
uniform float breath_speed : hint_range(0.0, 0.5) = 0.06;

uniform float sweep_amount : hint_range(0.0, 0.3) = 0.0;
uniform float sweep_speed : hint_range(-0.5, 0.5) = 0.028;
uniform vec3 sweep_color : source_color = vec3(0.62, 0.82, 1.00);

uniform float warm_amount : hint_range(0.0, 0.3) = 0.0;
uniform vec3 warm_color : source_color = vec3(0.95, 0.72, 0.42);
uniform vec2 warm_center = vec2(0.86, 0.16);

// ── PS 图案（大小不一 + 整体放大）──
uniform float ps_density : hint_range(2.0, 60.0) = 26.0;
uniform float ps_ratio : hint_range(0.5, 0.999) = 0.91;
uniform float ps_size : hint_range(0.02, 0.30) = 0.11;
uniform float ps_line_width : hint_range(0.003, 0.06) = 0.013;
uniform float ps_spread : hint_range(0.02, 0.30) = 0.10;
uniform float ps_amount : hint_range(0.0, 2.0) = 0.55;
uniform float ps_speed : hint_range(-2.0, 2.0) = 0.35;
// 每个图案的旋转速度（正值 = 屏幕上逆时针），约 2π/速度 = 一圈秒数
uniform float ps_rot_speed : hint_range(-2.0, 2.0) = 0.5;
uniform vec3 ps_color : source_color = vec3(0.72, 0.84, 0.98);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float _wave_top(float x, float t, float base_y, float amp, float freq, float phase) {
	return base_y
		+ sin(x * 1.9 * freq + t * 1.0 + phase) * amp
		+ sin(x * 4.1 * freq - t * 1.6) * amp * 0.45
		+ sin(x * 0.85 * freq + t * 0.7) * amp * 0.75
		+ sin(x * 5.5 * freq + t * 2.2) * amp * 0.15
		+ sin(x * 0.45 * freq + t * 0.35 + phase * 1.7) * amp * macro_warp
		+ sin(x * 8.5 * freq - t * 2.7 + phase * 0.6) * amp * 0.12
		+ sin(x * 14.0 * freq + t * 3.3 + phase * 1.3) * amp * 0.06;
}

float _wave_bottom(
	float x, float t, float top, float thickness, float amp, float freq, float phase
) {
	float thick_mod = thickness * (
		1.0
		+ thickness_wobble * sin(x * 0.95 * freq + t * 0.55 + phase * 0.9)
		+ thickness_wobble * 0.40 * sin(x * 2.1 * freq - t * 0.35 + phase * 1.4)
	);
	return top + thick_mod
		+ sin(x * 2.6 * freq - t * 1.3 + 1.5 + phase * 0.8) * amp * 0.55
		+ sin(x * 1.4 * freq + t * 0.8 + phase * 0.4) * amp * 0.45
		+ sin(x * 4.8 * freq + t * 0.45 + phase) * amp * 0.25
		+ sin(x * 8.0 * freq - t * 2.1 + phase * 0.7) * amp * 0.12
		+ sin(x * 13.0 * freq + t * 2.8 + phase * 1.1) * amp * 0.06;
}

vec3 _wave_layer(
	float x, float y, float t,
	float base_y, float thickness, float amp, float soft, float freq, float phase,
	float side_smooth, float right_amp_scale, float right_thick_scale, float y_spread
) {
	float amp_eff = amp * mix(right_amp_scale, 1.0, side_smooth);
	float thick_eff = thickness * mix(right_thick_scale, 1.0, side_smooth);
	float base_y_eff = base_y + y_spread * side_smooth;

	float top = _wave_top(x, t, base_y_eff, amp_eff, freq, phase);
	float bottom = _wave_bottom(x, t, top, thick_eff, amp_eff, freq, phase);
	float inner = clamp((y - top) / max(bottom - top, 0.001), 0.0, 1.0);
	float soft_top = soft;
	float soft_bottom = soft * 1.4;
	float in_wave = smoothstep(-soft_top, soft_top, y - top) *
					(1.0 - smoothstep(-soft_bottom, soft_bottom, y - bottom));
	float center_y = (top + bottom) * 0.5;
	return vec3(in_wave, inner, center_y);
}

// 三段色渐变（每条波传入自己的三色）
vec3 _wave_color(float inner, vec3 c_top, vec3 c_core, vec3 c_bottom) {
	if (inner < 0.35) {
		return mix(c_top, c_core, inner / 0.35);
	}
	return mix(c_core, c_bottom, (inner - 0.35) / 0.65);
}

// 第三波的 base 色循环：4 色平滑过渡
vec3 _wave3_cycle_base(float t) {
	float p = fract(t) * 4.0;
	int idx = int(floor(p));
	float f = fract(p);
	if (idx == 0) return mix(wave3_base_a, wave3_base_b, f);
	if (idx == 1) return mix(wave3_base_b, wave3_base_c, f);
	if (idx == 2) return mix(wave3_base_c, wave3_base_d, f);
	return mix(wave3_base_d, wave3_base_a, f);
}

float _hollow_profile(float inner, float hollow_power, float edge_bias) {
	float top_dist = max(1.0 - inner * 2.0, 0.0);
	float bot_dist = max(inner * 2.0 - 1.0, 0.0);
	float top_profile = pow(top_dist, hollow_power);
	float bot_profile = pow(bot_dist, hollow_power);
	float top_scale = mix(1.0, 0.55, max(-edge_bias, 0.0));
	float bot_scale = mix(1.0, 0.55, max(edge_bias, 0.0));
	float profile = max(top_profile * top_scale, bot_profile * bot_scale);
	return mix(hollow_min, 1.0, profile);
}

float _wave_reflection(float inner, float edge_bias, float power) {
	float top_dist = max(1.0 - inner * 2.0, 0.0);
	float bot_dist = max(inner * 2.0 - 1.0, 0.0);
	float top_hl = pow(top_dist, power);
	float bot_hl = pow(bot_dist, power);
	float top_weight = clamp(edge_bias, 0.0, 1.0);
	float bot_weight = clamp(-edge_bias, 0.0, 1.0);
	return max(top_hl * top_weight, bot_hl * bot_weight);
}

vec3 _apply_sparkle_layer(
	vec3 col, vec2 uv_in, float y, float center_y, float side_smooth, float aspect,
	float density, float amount, float size, float ratio,
	float drift_x, float drift_y, vec3 color
) {
	vec2 grid_uv = vec2(
		uv_in.x * density * aspect + TIME * drift_x,
		(y - center_y) * density + TIME * drift_y
	);
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv) - 0.5;
	float r = hash(cell);
	float is_spark = step(ratio, r);

	float size_seed = hash(cell + vec2(17.3, 41.7));
	float bright_seed = hash(cell + vec2(93.1, 7.3));
	float flicker_seed = hash(cell + vec2(31.9, 23.5));
	float mode_seed = hash(cell + vec2(71.1, 55.9));
	float wobble_seed_x = hash(cell + vec2(2.1, 19.7));
	float wobble_seed_y = hash(cell + vec2(7.7, 61.3));
	float color_seed_r = hash(cell + vec2(11.7, 88.3));
	float color_seed_g = hash(cell + vec2(5.5, 9.9));
	float color_seed_b = hash(cell + vec2(33.3, 44.4));

	float size_var = mix(1.0 - sparkle_size_var * 0.85, 1.0 + sparkle_size_var * 1.20, size_seed);
	float bright_var = mix(1.0 - sparkle_bright_var * 0.85, 1.0 + sparkle_bright_var * 0.70, bright_seed);

	float flicker_freq = mix(2.0, 6.0, flicker_seed);
	float f_slow = sin(TIME * flicker_freq * 0.5 + flicker_seed * 42.0) * 0.5 + 0.5;
	float f_fast = sin(TIME * flicker_freq * 2.2 + flicker_seed * 88.0) * 0.5 + 0.5;
	float flicker = mix(f_slow, f_fast, step(0.5, mode_seed));
	flicker = 0.30 + 0.70 * flicker;

	float wobble_freq = mix(0.15, 0.45, wobble_seed_x);
	vec2 wobble = vec2(
		sin(TIME * wobble_freq + wobble_seed_x * 6.283),
		cos(TIME * wobble_freq * 0.87 + wobble_seed_y * 6.283)
	) * sparkle_wobble;
	local += wobble;

	vec3 tint = vec3(
		mix(0.80, 1.20, color_seed_r),
		mix(0.80, 1.20, color_seed_g),
		mix(0.80, 1.20, color_seed_b)
	);

	float dist_to_center = abs(y - center_y);
	float near_wave = 1.0 - smoothstep(0.0, sparkle_spread, dist_to_center);
	float d = length(local);
	float shape = smoothstep(size * size_var, 0.0, d);
	float mask = is_spark * shape * near_wave * flicker * amount * bright_var;
	mask *= mix(1.0, side_left_intensity, side_smooth);
	return col + color * tint * mask;
}

float _sdf_triangle(vec2 p, float r) {
	const float k = 1.7320508;
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

float _sdf_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec3 _apply_ps_shapes(vec3 col, vec2 uv_in, float y, float center_y, float side_smooth, float aspect) {
	float y_rel = y - center_y;
	vec2 grid_uv = vec2(
		uv_in.x * ps_density * aspect + TIME * ps_speed,
		y_rel * ps_density
	);
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv) - 0.5;

	float r = hash(cell);
	float is_shape = step(ps_ratio, r);

	float type_seed = hash(cell + vec2(47.3, 91.1));
	int shape_type = int(floor(type_seed * 4.0));

	float size_seed = hash(cell + vec2(17.3, 41.7));
	float rot_seed = hash(cell + vec2(31.9, 23.5));
	float bright_seed = hash(cell + vec2(93.1, 7.3));

	// 大小不一：0.35 ~ 1.85 倍
	float sz = ps_size * mix(0.35, 1.85, size_seed);
	// 每个图案固定初相 + 随时间逆时针旋转
	float rot = rot_seed * 6.2831853 - TIME * ps_rot_speed;
	float bright = mix(0.55, 1.25, bright_seed);

	float rc = cos(rot);
	float rs = sin(rot);
	vec2 p = vec2(local.x * rc - local.y * rs, local.x * rs + local.y * rc);

	float d = 0.0;
	if (shape_type == 0) {
		d = abs(_sdf_triangle(p, sz));
	} else if (shape_type == 1) {
		d = abs(length(p) - sz);
	} else if (shape_type == 2) {
		float d1 = _sdf_segment(p, vec2(-sz, -sz), vec2(sz, sz));
		float d2 = _sdf_segment(p, vec2(-sz, sz), vec2(sz, -sz));
		d = min(d1, d2);
	} else {
		d = abs(max(abs(p.x), abs(p.y)) - sz);
	}

	float line_w = ps_line_width;
	float shape_mask = 1.0 - smoothstep(line_w, line_w + 0.015, d);

	float dist_rel = abs(y_rel);
	float near_wave = 1.0 - smoothstep(0.0, ps_spread, dist_rel);

	float mask = is_shape * shape_mask * near_wave * ps_amount * bright;
	mask *= mix(1.0, side_left_intensity, side_smooth);

	return col + ps_color * mask;
}

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;

	vec3 col = mix(bg_top, bg_bottom, smoothstep(0.0, 1.0, y));

	float fog_v = smoothstep(0.0, 0.35, y) * (1.0 - smoothstep(0.65, 1.0, y));
	col *= mix(0.88, 1.0, fog_v);

	float side_smooth = pow(1.0 - uv.x, side_power);

	float t1 = TIME * wave_speed;
	float t2 = TIME * wave2_speed;
	float t3 = TIME * wave3_speed;

	vec3 layer1 = _wave_layer(uv.x, y, t1,
		wave_y, wave_thickness, wave_amplitude, edge_soft, wave_freq, 0.0,
		side_smooth, side_right_amp_scale, side_right_thick_scale, -side_y_spread);
	vec3 layer2 = _wave_layer(uv.x, y, t2,
		wave2_y, wave2_thickness, wave2_amplitude, edge_soft, wave2_freq, 2.7,
		side_smooth, side_right_amp_scale, side_right_thick_scale, side_y_spread);
	vec3 layer3 = _wave_layer(uv.x, y, t3,
		wave3_y, wave3_thickness, wave3_amplitude, edge_soft, wave3_freq, 5.2,
		side_smooth, side_right_amp_scale, side_right_thick_scale, 0.0);

	float center_dist = abs(layer1.z - layer2.z);
	float overlap = 1.0 - smoothstep(overlap_near, overlap_far, center_dist);
	float boost = mix(1.0 - overlap_strength, 1.0 + overlap_strength, overlap);

	float profile1 = _hollow_profile(layer1.y, wave_hollow, wave_edge_bias);
	float profile2 = _hollow_profile(layer2.y, wave2_hollow, wave2_edge_bias);
	float profile3 = _hollow_profile(layer3.y, wave3_hollow, wave3_edge_bias);

	float side_intensity = mix(1.0, side_left_intensity, side_smooth);

	// 主波 + 副波（共用蓝色）
	vec3 c1 = _wave_color(layer1.y, wave_blue_top, wave_blue_core, wave_blue_bottom);
	vec3 c2 = _wave_color(layer2.y, wave_blue_top, wave_blue_core, wave_blue_bottom);

	// 第三波：base 色循环 + 派生三段渐变
	vec3 base3 = _wave3_cycle_base(TIME * wave3_color_speed);
	vec3 c3_top = base3 * wave3_top_mult;
	vec3 c3_core = base3;
	vec3 c3_bottom = base3 * wave3_bottom_mult;
	vec3 c3 = _wave_color(layer3.y, c3_top, c3_core, c3_bottom);

	col += c1 * layer1.x * profile1 * wave_intensity * boost * side_intensity;
	col += c2 * layer2.x * profile2 * wave2_intensity * boost * side_intensity;

	// 第三条：实心不透明（用 mix 替换背景，不再叠加）
	// wave3_solid = 1.0 时是实色；= 0.0 时退回加法 + 中空
	float a3_solid = clamp(layer3.x * wave3_intensity * side_intensity, 0.0, 1.0);
	float a3_old = clamp(layer3.x * profile3 * wave3_intensity * side_intensity, 0.0, 1.0);
	float a3 = mix(a3_old, a3_solid, wave3_solid);
	col = mix(col, c3, a3);

	// 反射
	float refl1 = _wave_reflection(layer1.y, wave_edge_bias, reflection_power);
	float refl2 = _wave_reflection(layer2.y, wave2_edge_bias, reflection_power);
	col += reflection_color * layer1.x * refl1 * reflection_amount * side_intensity;
	col += reflection_color * layer2.x * refl2 * reflection_amount * side_intensity;

	// 光点两层
	col = _apply_sparkle_layer(col, uv, y, layer1.z, side_smooth, viewport_aspect,
		sparkle_density, sparkle_amount, sparkle_size, sparkle_ratio,
		sparkle_drift_x, sparkle_drift_y, sparkle_color);
	col = _apply_sparkle_layer(col, uv, y, layer1.z, side_smooth, viewport_aspect,
		sparkle2_density, sparkle2_amount, sparkle2_size, sparkle2_ratio,
		sparkle2_drift_x, sparkle2_drift_y, sparkle2_color);

	// PS 图案
	col = _apply_ps_shapes(col, uv, y, layer1.z, side_smooth, viewport_aspect);

	// 呼吸
	float breath = 1.0 + sin(TIME * breath_speed) * breath_amount;
	col *= breath;

	// 颗粒
	vec2 grain_uv = uv * vec2(1920.0, 1080.0) + vec2(TIME * 5.0, TIME * 3.0);
	float g = hash(floor(grain_uv)) - 0.5;
	col += vec3(g) * grain_amount;

	ALBEDO = col;
}