shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.20, 0.82, 0.76, 1.0);
uniform float brightness : hint_range(0.0, 1.0) = 0.5;
uniform float edge_power : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	// 横向：中心 1.0，两端 0.0
	float hx = 1.0 - abs(UV.x - 0.5) * 2.0;
	hx = max(hx, 0.0);
	hx = pow(hx, edge_power);

	// 亮度直接乘到最终颜色上
	// blend_add 意味着亮度低 = 加一点点 = 几乎看不见
	// 亮度高 = 加很多 = 明亮的青/金色光
	vec3 col = glow_color.rgb * brightness * hx;
	COLOR = vec4(col, 1.0);
}