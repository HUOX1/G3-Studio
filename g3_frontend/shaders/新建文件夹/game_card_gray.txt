shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(vec3(lum), tex.rgb, saturation);
	COLOR = vec4(desat * brightness, tex.a);
}