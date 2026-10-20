shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 top_color : source_color = vec3(0.14, 0.10, 0.06);
uniform vec3 bottom_color : source_color = vec3(0.03, 0.02, 0.02);
uniform vec3 gold_color : source_color = vec3(0.88, 0.66, 0.36);
uniform vec3 ember_color : source_color = vec3(0.72, 0.34, 0.18);
uniform float time_scale = 1.0;
uniform float wave_amount = 0.38;
uniform float glow_amount = 0.28;
uniform float grain_amount = 0.018;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;

	// 底色：暖棕渐变
	vec3 col = mix(bottom_color, top_color, smoothstep(0.0, 1.0, uv.y));

	// 两条宽阔的暖色波带，缓慢斜向流动
	float w1 = sin((uv.x * 1.8 + uv.y * 0.7) * 2.6 + t * 0.18);
	float w2 = sin((uv.x * -1.2 + uv.y * 1.1) * 3.1 - t * 0.13 + 2.0);
	float band = (w1 + w2) * 0.5 * 0.5 + 0.5;
	band = pow(band, 2.4);
	col += gold_color * band * wave_amount * 0.35;

	// 一团缓慢漂移的暖光晕
	vec2 glow_center = vec2(0.62 + 0.14 * sin(t * 0.10), 0.58 + 0.09 * cos(t * 0.08));
	float d = length((uv - glow_center) * vec2(1.0, 0.75));
	float glow = exp(-d * 2.2);
	col += gold_color * glow * glow_amount;

	// 左下角一抹余烬色，打破对称
	vec2 ember_center = vec2(0.18, 0.22);
	float de = length((uv - ember_center) * vec2(1.3, 1.0));
	float ember = exp(-de * 3.0) * 0.35;
	col = mix(col, col + ember_color * 0.35, ember);

	// 颗粒：UV 空间固定 1920×1080 格网，格子小于 1 屏幕像素——看不出方块，
	// 每格一个随机值 = 均匀细密的胶片颗粒，格子间不做插值（保持颗粒的"硬"）
	vec2 grain_uv = uv * vec2(1920.0, 1080.0) + vec2(t * 5.0, t * 3.0);
	float g = hash(floor(grain_uv)) - 0.5;
	col += vec3(g) * grain_amount;

	// 整体乘一个色温偏移，让"亮部偏暖、暗部偏冷"
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col * vec3(0.92, 0.94, 1.05), col * vec3(1.06, 1.00, 0.92), lum);

	ALBEDO = col;
}