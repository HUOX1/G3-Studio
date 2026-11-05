shader_type canvas_item;
render_mode blend_mix;

#include "g3_material_common.gdshaderinc"

// M01 · Aged Gunmetal
uniform vec4 base_color : source_color = vec4(0.075, 0.092, 0.098, 1.0);
uniform vec4 edge_color : source_color = vec4(0.43, 0.49, 0.49, 1.0);
uniform vec4 accent_color : source_color = vec4(0.76, 0.48, 0.20, 1.0);
uniform float grain_amount : hint_range(0.0, 1.0) = 0.42;
uniform float wear_amount : hint_range(0.0, 1.0) = 0.34;
uniform float grain_scale : hint_range(80.0, 900.0) = 420.0;
uniform vec2 panel_size = vec2(440.0, 112.0);
uniform float corner_radius : hint_range(0.0, 12.0) = 3.0;

void fragment() {
    vec2 px = UV * panel_size;
    float sd = g3_sd_round_rect(UV, panel_size, corner_radius);
    float alpha = 1.0 - smoothstep(0.0, 1.0, sd);
    float edge = -sd;

    float broad = g3_fbm(vec2(UV.x * 5.0, UV.y * 2.0));
    float brushing = g3_value_noise(vec2(UV.x * grain_scale, UV.y * 18.0));
    float micro = g3_hash21(floor(px * vec2(0.72, 1.8)));
    float scratch_seed = g3_hash21(vec2(floor(UV.y * 74.0), floor(UV.x * 11.0)));
    float scratch_line = 1.0 - smoothstep(0.02, 0.18, abs(fract(UV.y * 74.0 + scratch_seed * 0.7) - 0.5));
    float scratch_mask = step(0.84, scratch_seed) * scratch_line;

    float edge_wear = (1.0 - smoothstep(0.0, 5.0, edge)) * wear_amount;
    float highlight = exp(-abs(UV.y - 0.16) * 36.0) * 0.12;
    float grain = (brushing - 0.5) * grain_amount * 0.20;
    float texture_noise = (broad - 0.5) * 0.13 + (micro - 0.5) * 0.035;
    vec3 metal = base_color.rgb + vec3(grain + texture_noise + highlight);
    metal = mix(metal, edge_color.rgb, edge_wear * 0.52);
    metal -= vec3(scratch_mask * wear_amount * 0.12);
    metal += accent_color.rgb * (edge_wear * 0.035);
    float bevel = smoothstep(0.0, 2.5, edge) * (1.0 - smoothstep(2.5, 5.0, edge));
    metal += edge_color.rgb * bevel * 0.12;
    COLOR = vec4(clamp(metal, 0.0, 1.0), alpha);
}
