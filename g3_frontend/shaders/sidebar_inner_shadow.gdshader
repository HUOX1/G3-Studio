shader_type canvas_item;

// 侧边栏内阴影（WB-04.1-D 引入，WB-04.2-A 收窄到游戏文字列表视口）
//
// 用途：一整块矩形覆盖层，沿矩形内侧边缘向内渐弱，中心完全透明。
// 调用方用四边权重选择需要哪几条边：
//   · WB-04.1：铺满整个侧边栏，四边都开（顶边因为与菜单栏共边而压低）；
//   · WB-04.2：只铺游戏文字列表的可见视口，只保留上/右/下三边，left_weight = 0。
//
// 使用方式：一张与目标矩形同尺寸的 ColorRect（mouse_filter = IGNORE），
// 由 game_section._relayout_sidebar 同步 size_px 与 radius_px，
// 保证窗口缩放后阴影宽度与边缘仍然对齐。

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// 边缘处的最大不透明度（"非常克制"：远低于 0.5）
uniform float strength : hint_range(0.0, 1.0) = 0.26;
// 阴影向内衰减的距离（像素），由调用方按 UI 缩放同步
uniform float radius_px : hint_range(1.0, 120.0) = 22.0;
// 衰减曲线指数：越大越快消失
uniform float falloff : hint_range(0.5, 4.0) = 2.0;
// 逐边权重：0 = 该边完全关闭
uniform float left_weight : hint_range(0.0, 1.0) = 1.0;
uniform float top_weight : hint_range(0.0, 1.0) = 1.0;
uniform float right_weight : hint_range(0.0, 1.0) = 1.0;
uniform float bottom_weight : hint_range(0.0, 1.0) = 1.0;
// 覆盖矩形实际像素尺寸（由脚本同步，避免 UV 拉伸导致四边宽度不一致）
uniform vec2 size_px = vec2(280.0, 600.0);

void fragment() {
	vec2 px = UV * size_px;
	float r = max(radius_px, 1.0);

	float a_left = pow(1.0 - clamp(px.x / r, 0.0, 1.0), falloff) * strength * left_weight;
	float a_right = pow(1.0 - clamp((size_px.x - px.x) / r, 0.0, 1.0), falloff) * strength * right_weight;
	float a_bottom = pow(1.0 - clamp((size_px.y - px.y) / r, 0.0, 1.0), falloff) * strength * bottom_weight;
	float a_top = pow(1.0 - clamp(px.y / r, 0.0, 1.0), falloff) * strength * top_weight;

	float a = max(max(a_left, a_right), max(a_bottom, a_top));
	COLOR = vec4(shadow_color.rgb, a * shadow_color.a);
}
