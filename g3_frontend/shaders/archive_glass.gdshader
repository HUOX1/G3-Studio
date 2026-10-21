shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float frosted : hint_range(0.0, 1.0) = 0.0;
uniform float selected : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 d = min(UV, 1.0 - UV);
    float edge = 1.0 - smoothstep(0.0, 0.018, min(d.x, d.y));
    float ribbon = pow(max(0.0, 1.0 - abs(UV.x * 0.65 + UV.y * 0.35 - 0.34) * 7.0), 8.0);
    // A restrained coat, with no screen-texture refraction or animated noise.
    ALBEDO = mix(vec3(0.88, 0.94, 0.94), vec3(0.64, 0.48, 0.28), edge * selected * 0.35);
    ALPHA = clamp(edge * (0.24 + selected * 0.12) + ribbon * 0.026 + frosted * 0.025, 0.0, 0.52);
}
