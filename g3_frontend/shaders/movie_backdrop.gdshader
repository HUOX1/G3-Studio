shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D albedo_tex_prev : source_color, filter_linear_mipmap;
uniform float blend_factor : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float backdrop_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float cull_offset_y : hint_range(-500.0, 500.0) = 0.0;

void vertex() {
	VERTEX.y += cull_offset_y;
}

void fragment() {
	vec2 uv_shrunk = mix(vec2(0.003), vec2(0.997), UV);
	vec4 col;
	if (blend_factor >= 0.999) {
		col = texture(albedo_tex, uv_shrunk);
	} else {
		vec4 prev = texture(albedo_tex_prev, uv_shrunk);
		vec4 curr = texture(albedo_tex, uv_shrunk);
		col = mix(prev, curr, blend_factor);
	}
	ALBEDO = col.rgb * brightness;
	ALPHA = col.a * backdrop_alpha;
}