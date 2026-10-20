shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.50, 0.72, 0.95, 1.0);
uniform float brightness : hint_range(0.0, 1.0) = 0.0;
uniform float falloff : hint_range(0.5, 6.0) = 2.0;
// 节点物理尺寸（像素），由脚本每帧设置
uniform vec2 node_size = vec2(100.0, 100.0);
// 光点半径：0 = 用固定值，>0 = 用固定值覆盖自动
// 自动 = min(node_size.x, node_size.y) × glow_radius_scale
uniform float glow_radius_px : hint_range(0.0, 400.0) = 0.0;
uniform float glow_radius_scale : hint_range(0.0, 4.0) = 1.5;

void fragment() {
	// 把 UV 转成"以按钮中心为原点、单位=像素"的坐标
	vec2 p = (UV - vec2(0.5)) * node_size;
	float radius = glow_radius_px;
	if (radius <= 0.001) {
		radius = min(node_size.x, node_size.y) * glow_radius_scale;
	}
	// 到中心的像素距离 / 半径
	float d = length(p) / max(radius, 0.001);
	// 高斯衰减：中心最亮、边缘快速收，像灯泡
	float a = exp(-d * d * falloff);
	COLOR = vec4(glow_color.rgb, a * brightness);
}
