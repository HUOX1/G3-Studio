shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.55, 0.70, 0.72, 1.0);
uniform vec4 fill_color : source_color = vec4(0.95, 0.22, 0.72, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// UV.y: 0 = 顶，1 = 底
	float from_bottom = 1.0 - UV.y;
	// 底部先填：from_bottom <= fill 的像素显示 fill_color
	float t = 1.0 - smoothstep(fill, fill + 0.05, from_bottom);
	vec3 c = mix(base_color.rgb, fill_color.rgb, t);
	COLOR = vec4(c, 1.0) * tex;
}