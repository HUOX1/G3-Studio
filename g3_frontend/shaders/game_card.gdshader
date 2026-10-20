shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float use_tex : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 1.0) = 1.0;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 base = tint.rgb;
	if (use_tex > 0.5) {
		base = texture(albedo_tex, UV).rgb;
	}
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(vec3(lum), base, saturation);
	vec3 col = desat * brightness;
	ALBEDO = col;
	ALPHA = alpha;
}