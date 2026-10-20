shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.88, 0.66, 0.36, 1.0);
uniform float brightness : hint_range(0.0, 1.5) = 0.5;
uniform float edge_power : hint_range(0.5, 4.0) = 1.4;
// 纵向衰减（让光边有"厚度"而不是一条色块）
uniform float vertical_falloff : hint_range(0.5, 4.0) = 1.2;
// 中心额外亮点强度（像真的有颗灯）
uniform float core_amount : hint_range(0.0, 1.5) = 0.65;
// 微闪烁（光在动）
uniform float shimmer_amount : hint_range(0.0, 0.5) = 0.12;
uniform float shimmer_speed : hint_range(0.0, 8.0) = 2.5;
// 形状铺平程度：0 = 中心亮两端淡（默认），1 = 整条边均匀亮
uniform float shape_flat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// 横向：中心 1.0，两端 0.0
	float hx = 1.0 - abs(UV.x - 0.5) * 2.0;
	hx = max(hx, 0.0);
	float hx_sharp = pow(hx, edge_power);
	float hx_flat = smoothstep(0.0, 0.05, hx);
	hx = mix(hx_sharp, hx_flat, shape_flat);

	// 纵向：中心 1.0，上下 0.0
	float vy = 1.0 - abs(UV.y - 0.5) * 2.0;
	vy = max(vy, 0.0);
	vy = pow(vy, vertical_falloff);

	// 中心亮点
	float core = pow(hx, 3.0) * core_amount;

	// 微闪烁
	float shimmer = 1.0 + sin(TIME * shimmer_speed + UV.x * 12.0) * shimmer_amount;

	vec3 col = glow_color.rgb * brightness * (hx + core) * vy * shimmer;
	COLOR = vec4(col, 1.0);
}