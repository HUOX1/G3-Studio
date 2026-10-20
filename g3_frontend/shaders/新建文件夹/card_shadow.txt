shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.75);
uniform float softness : hint_range(0.1, 2.5) = 1.2;
// 阴影整体横向偏移（正=向右），让右边缘更厚，像光从左上来
uniform float x_offset : hint_range(-0.3, 0.3) = 0.06;

void fragment() {
	vec2 uv = UV;
	uv.x -= x_offset;   // 阴影往右移，右边缘加厚
	// UV ∈ [0,1]；把矩形映射成椭圆
	vec2 p = (uv - vec2(0.5)) * vec2(2.0, 2.4);
	float d = length(p);   // 中心=0，边缘≈1.0~1.56
	// 从中心到边缘持续衰减，不是内部全浓
	float alpha = 1.0 - smoothstep(0.30, 1.10 * softness, d);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * alpha);
}