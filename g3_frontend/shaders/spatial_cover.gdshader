shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D cover_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = false;
uniform vec4 fallback_color : source_color = vec4(0.08, 0.16, 0.24, 1.0);
uniform float sheen_strength : hint_range(0.0, 0.12) = 0.035;
uniform float edge_darkening : hint_range(0.0, 0.18) = 0.055;

void fragment() {
	vec4 base = fallback_color;
	if (use_texture) {
		base = texture(cover_texture, UV);
	}

	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = 1.0 - smoothstep(0.0, 0.055, edge_distance);
	float diagonal = UV.x * 0.72 + UV.y * 0.28;
	float sheen = exp(-pow((diagonal - 0.43) / 0.19, 2.0));
	float upper_edge = (1.0 - smoothstep(0.0, 0.22, UV.y)) * 0.22;

	vec3 color = base.rgb * (1.0 - edge * edge_darkening);
	color += vec3(0.42, 0.70, 0.94) * sheen * sheen_strength;
	color += vec3(0.42, 0.70, 0.94) * upper_edge * sheen_strength * 0.32;
	ALBEDO = color;
	ALPHA = base.a;
}
