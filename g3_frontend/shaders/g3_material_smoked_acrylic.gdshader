shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "g3_material_common.gdshaderinc"

// M02 · Smoked Acrylic
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(0.045, 0.085, 0.091, 1.0);
uniform vec4 accent_color : source_color = vec4(0.35, 0.72, 0.76, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.58;
uniform float edge_reflection : hint_range(0.0, 1.0) = 0.52;
uniform float blur_amount : hint_range(0.0, 4.0) = 1.35;
uniform vec2 panel_size = vec2(440.0, 112.0);
uniform float corner_radius : hint_range(0.0, 12.0) = 3.0;

void fragment() {
    vec2 suv = SCREEN_UV;
    vec2 offset = SCREEN_PIXEL_SIZE * blur_amount;
    vec3 behind = texture(screen_texture, suv).rgb * 0.42;
    behind += texture(screen_texture, suv + vec2(offset.x, 0.0)).rgb * 0.145;
    behind += texture(screen_texture, suv - vec2(offset.x, 0.0)).rgb * 0.145;
    behind += texture(screen_texture, suv + vec2(0.0, offset.y)).rgb * 0.1375;
    behind += texture(screen_texture, suv - vec2(0.0, offset.y)).rgb * 0.1325;

    float sd = g3_sd_round_rect(UV, panel_size, corner_radius);
    float alpha = 1.0 - smoothstep(0.0, 1.0, sd);
    float edge_distance = max(-sd, 0.0);
    float fresnel_edge = 1.0 - smoothstep(0.0, 12.0, edge_distance);
    float cloudy = g3_value_noise(UV * vec2(19.0, 11.0)) * 0.035;
    float inner_shade = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
    vec3 smoked = mix(behind, tint_color.rgb, haze * 0.78 + cloudy);
    smoked *= 0.78 + inner_shade * 0.16;
    smoked += accent_color.rgb * fresnel_edge * edge_reflection * 0.16;
    smoked += vec3(0.13, 0.18, 0.18) * fresnel_edge * 0.18;
    COLOR = vec4(smoked, alpha);
}
