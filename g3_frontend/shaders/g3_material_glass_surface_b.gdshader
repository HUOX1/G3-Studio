shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "g3_material_common.gdshaderinc"

// M02-B · Smoked glass surface.
// Transmission and environment reflection are separate SubViewport textures.
// The transmitted scene remains legible; only a restrained normal field shifts it.
uniform sampler2D reflection_texture : filter_linear;
uniform float refraction_strength_px : hint_range(0.0, 2.0, 0.01) = 0.75;
uniform float surface_frequency : hint_range(0.5, 2.5, 0.05) = 1.1;
uniform float reflection_strength : hint_range(0.0, 0.8, 0.01) = 0.42;
uniform float smoke_density : hint_range(0.0, 0.35, 0.005) = 0.10;
uniform float surface_roughness : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float edge_reflection : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform vec2 panel_size = vec2(960.0, 384.0);

float surface_height(vec2 uv) {
    // Broad, non-periodic micro-surface variation; no repeating sine-wave bands.
    vec2 p = uv * vec2(surface_frequency * 3.0, surface_frequency * 1.35);
    float broad = g3_fbm(p + vec2(1.7, 4.2));
    float fine = g3_fbm(p * 1.85 + vec2(8.3, 2.1));
    return (broad - 0.5) * 0.075 + (fine - 0.5) * 0.018;
}

void fragment() {
    vec2 texel = TEXTURE_PIXEL_SIZE;
    vec2 dx = vec2(texel.x * 2.0, 0.0);
    vec2 dy = vec2(0.0, texel.y * 2.0);

    // Estimate a restrained normal field from the low-frequency surface height.
    float h_left = surface_height(UV - dx);
    float h_right = surface_height(UV + dx);
    float h_up = surface_height(UV - dy);
    float h_down = surface_height(UV + dy);
    vec2 gradient = vec2(
        (h_right - h_left) / max(2.0 * dx.x, 0.000001),
        (h_down - h_up) / max(2.0 * dy.y, 0.000001)
    );
    vec2 normal_xy = clamp(gradient * 0.22, vec2(-0.72), vec2(0.72));

    // Refraction is capped at a few pixels so text and circuit traces stay readable.
    vec2 offset_uv = normal_xy * refraction_strength_px * texel;
    vec2 sample_uv = clamp(UV + offset_uv, vec2(0.001), vec2(0.999));
    vec3 transmitted = texture(TEXTURE, sample_uv).rgb;

    vec3 transmission_soft = (
        texture(TEXTURE, sample_uv + vec2(texel.x, 0.0)).rgb
        + texture(TEXTURE, sample_uv - vec2(texel.x, 0.0)).rgb
        + texture(TEXTURE, sample_uv + vec2(0.0, texel.y)).rgb
        + texture(TEXTURE, sample_uv - vec2(0.0, texel.y)).rgb
    ) * 0.25;
    transmitted = mix(transmitted, transmission_soft, surface_roughness * 0.12);

    // Sample a separately rendered environment, as a glass surface reflection.
    vec3 normal = normalize(vec3(-normal_xy * 0.18, 1.0));
    float ndotv = clamp(normal.z, 0.0, 1.0);
    float face_fresnel = 0.06 + 0.94 * pow(1.0 - ndotv, 5.0);

    float edge_px = min(
        min(UV.x * panel_size.x, (1.0 - UV.x) * panel_size.x),
        min(UV.y * panel_size.y, (1.0 - UV.y) * panel_size.y)
    );
    float edge_fresnel = exp(-edge_px / 11.0) * edge_reflection * 0.26;

    vec2 reflected_uv = clamp(UV + normal_xy * 0.006, vec2(0.001), vec2(0.999));
    vec3 reflected = texture(reflection_texture, reflected_uv).rgb;
    vec3 reflected_soft = (
        texture(reflection_texture, reflected_uv + vec2(texel.x * 2.0, 0.0)).rgb
        + texture(reflection_texture, reflected_uv - vec2(texel.x * 2.0, 0.0)).rgb
        + texture(reflection_texture, reflected_uv + vec2(0.0, texel.y * 2.0)).rgb
        + texture(reflection_texture, reflected_uv - vec2(0.0, texel.y * 2.0)).rgb
    ) * 0.25;
    reflected = mix(reflected, reflected_soft, surface_roughness * 0.75);

    float reflection_weight = clamp(
        (face_fresnel * 1.5 + edge_fresnel) * reflection_strength,
        0.0,
        0.34
    );
    vec3 color = mix(transmitted, reflected, reflection_weight);

    // A small cool smoke absorption tint; it should not become an opaque colour plate.
    vec3 smoke_tint = vec3(0.055, 0.080, 0.076);
    color = mix(color, smoke_tint, smoke_density);

    float top_glint = exp(-(UV.y * panel_size.y) / 3.0);
    float left_glint = exp(-(UV.x * panel_size.x) / 4.5);
    float edge_glint = max(edge_fresnel, top_glint * 0.12 + left_glint * 0.05);
    color += vec3(0.28, 0.39, 0.37) * edge_glint * edge_reflection * 0.22;

    // Very fine, low-contrast surface texture avoids a perfectly digital overlay.
    float micro = g3_value_noise(UV * vec2(130.0, 86.0)) - 0.5;
    color += vec3(micro * 0.005);

    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
