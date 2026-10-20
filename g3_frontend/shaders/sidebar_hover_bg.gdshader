shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.30, 0.38, 0.50, 0.75);
// 渐隐曲线：越大越快消失
uniform float falloff_power : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	// UV.x = 0（左）→ 1（右）
	// 左端最浓，往右平滑淡出
	float a = pow(1.0 - UV.x, falloff_power);
	COLOR = vec4(bg_color.rgb, bg_color.a * a);
}
