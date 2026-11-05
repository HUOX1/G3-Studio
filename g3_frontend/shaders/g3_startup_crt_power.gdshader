shader_type canvas_item;
// Independent CRT tube power-up. Intentionally not masked by the logo image.
// Broader luminous core and a soft cyan/magenta field replace Phase 1's 1px line.
uniform float power_progress : hint_range(0.0, 1.0) = 0.0;
uniform float power_strength : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
    vec2 p = UV - vec2(0.5);
    float width_half = mix(0.015, 0.58, clamp(power_progress, 0.0, 1.0));
    float gate = 1.0 - smoothstep(width_half - 0.014, width_half + 0.022, abs(p.x));
    float white_core = exp(-pow(p.y / 0.0042, 2.0));
    float cyan_halo = exp(-abs(p.y) / 0.023);
    float magenta_halo = exp(-abs(p.y) / 0.050);
    float center_bloom = exp(-length(vec2(p.x * 0.68, p.y * 5.0)) / 0.17);
    vec3 light_rgb = vec3(0.94, 0.98, 1.0) * white_core
        + vec3(0.21, 0.80, 1.0) * cyan_halo * 0.72
        + vec3(0.87, 0.22, 0.56) * magenta_halo * 0.20
        + vec3(0.30, 0.57, 0.76) * center_bloom * 0.35;
    float opacity = clamp((white_core * 0.95 + cyan_halo * 0.47
        + magenta_halo * 0.13 + center_bloom * 0.22) * gate * power_strength, 0.0, 0.94);
    COLOR = vec4(light_rgb, opacity) * vertex_tint;
}
