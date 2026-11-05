shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D cover_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = false;
uniform float image_aspect = 0.666667;
uniform float frosted : hint_range(0.0, 1.0) = 0.0;
uniform float distance_fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fallback_color : source_color = vec4(0.18, 0.26, 0.29, 1.0);

void fragment() {
    vec3 color = fallback_color.rgb;
    if (use_texture) {
        // Contain, rather than crop, real cover artwork of any aspect ratio.
        vec2 fit = vec2(min(1.0, image_aspect / (2.55 / 3.8)), min(1.0, (2.55 / 3.8) / image_aspect));
        vec2 uv = (UV - 0.5) / fit + 0.5;
        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            float r = frosted * 0.005;
            vec3 center = texture(cover_texture, uv).rgb;
            vec3 soft = center * 0.4;
            soft += texture(cover_texture, clamp(uv + vec2(r, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.15;
            soft += texture(cover_texture, clamp(uv - vec2(r, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.15;
            soft += texture(cover_texture, clamp(uv + vec2(0.0, r), vec2(0.0), vec2(1.0))).rgb * 0.15;
            soft += texture(cover_texture, clamp(uv - vec2(0.0, r), vec2(0.0), vec2(1.0))).rgb * 0.15;
            color = mix(center, soft, frosted);
        }
    }
    color = mix(color, vec3(0.90, 0.89, 0.85), distance_fade);
    ALBEDO = color;
}
