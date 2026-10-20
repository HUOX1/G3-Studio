shader_type canvas_item;

// 屏幕纹理（Godot 会自动做 backbuffer copy）
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// 与玻璃混合的主题色（深青或深棕）
uniform vec4 tint : source_color = vec4(0.02, 0.06, 0.09, 0.55);
// 模糊强度：0 = 不模糊，越大越糊
uniform float blur_amount : hint_range(0.0, 8.0) = 2.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = SCREEN_PIXEL_SIZE * blur_amount;

	// 3x3 高斯近似（权重和 = 1.0）
	float w0 = 0.0625;
	float w1 = 0.125;
	float w2 = 0.25;
	vec4 acc = vec4(0.0);
	acc += texture(screen_tex, uv + vec2(-1.0, -1.0) * pixel) * w0;
	acc += texture(screen_tex, uv + vec2( 0.0, -1.0) * pixel) * w1;
	acc += texture(screen_tex, uv + vec2( 1.0, -1.0) * pixel) * w0;
	acc += texture(screen_tex, uv + vec2(-1.0,  0.0) * pixel) * w1;
	acc += texture(screen_tex, uv) * w2;
	acc += texture(screen_tex, uv + vec2( 1.0,  0.0) * pixel) * w1;
	acc += texture(screen_tex, uv + vec2(-1.0,  1.0) * pixel) * w0;
	acc += texture(screen_tex, uv + vec2( 0.0,  1.0) * pixel) * w1;
	acc += texture(screen_tex, uv + vec2( 1.0,  1.0) * pixel) * w0;

	// 与主题色混合（tint.a 越大越不透明、越偏主题色）
	vec3 glass = mix(acc.rgb, tint.rgb, tint.a);

	COLOR = vec4(glass, 1.0);
}