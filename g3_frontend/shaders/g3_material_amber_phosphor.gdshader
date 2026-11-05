shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "g3_material_common.gdshaderinc"

// M03 · Amber Phosphor
// Layered lens, phosphor core and soft radial emission. Optional project Glow may add bloom.
uniform vec4 accent_color : source_color = vec4(1.0, 0.57, 0.19, 1.0);
uniform vec4 housing_color : source_color = vec4(0.025, 0.035, 0.038, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.35;
uniform float lens_roughness : hint_range(0.0, 1.0) = 0.38;
uniform vec2 panel_size = vec2(440.0, 112.0);
uniform float corner_radius : hint_range(0.0, 12.0) = 3.0;

void fragment() {
    float panel_sd = g3_sd_round_rect(UV, panel_size, corner_radius);
    float panel_alpha = 1.0 - smoothstep(0.0, 1.0, panel_sd);
    // Convert normalized UV into height-relative pixel space. This keeps the
    // lens circular when the preview column changes width or window size.
    float aspect = panel_size.x / max(panel_size.y, 1.0);
    vec2 p = (UV - vec2(0.28, 0.5)) * vec2(aspect, 1.0);
    float d = length(p);
    float pulse = 0.92 + 0.08 * sin(TIME * pulse_speed * 6.28318);
    float halo = exp(-d * 8.0) * 0.22;
    float outer_glow = exp(-d * 18.0) * 0.28;
    float lens = 1.0 - smoothstep(0.115, 0.135, d);
    float rim = smoothstep(0.105, 0.115, d) * (1.0 - smoothstep(0.125, 0.135, d));
    float core = 1.0 - smoothstep(0.038, 0.062, d);
    float hot_core = 1.0 - smoothstep(0.014, 0.030, d);
    float spec = exp(-length((p - vec2(-0.035, -0.04)) * vec2(1.0, 1.5)) * 85.0);

    vec3 color = housing_color.rgb;
    color += accent_color.rgb * (halo + outer_glow * glow_strength);
    color = mix(color, accent_color.rgb * 0.28, lens * 0.40);
    color += accent_color.rgb * rim * 0.72;
    color += accent_color.rgb * core * pulse * 0.75 * glow_strength;
    color = mix(color, vec3(1.0, 0.86, 0.60), hot_core * 0.86);
    color += vec3(1.0) * spec * (1.0 - lens_roughness) * 0.30;

    float body_edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    color += vec3(0.12, 0.16, 0.16) * (1.0 - smoothstep(0.0, 0.018, body_edge)) * 0.5;
    COLOR = vec4(color, panel_alpha);
}
