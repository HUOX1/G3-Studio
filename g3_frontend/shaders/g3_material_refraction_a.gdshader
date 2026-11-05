shader_type canvas_item;
render_mode unshaded;

#include "g3_material_common.gdshaderinc"

// Experiment A: analytic height-field refraction over a real ViewportTexture.
// This is intentionally not a Normal Map implementation; experiment B will
// replace the analytic surface gradient with a sampled normal texture.
uniform float refraction_strength_px : hint_range(0.0, 28.0, 0.1) = 12.0;
uniform float surface_frequency : hint_range(0.5, 6.0, 0.05) = 2.4;
uniform vec2 panel_size = vec2(960.0, 384.0);

float surface_height(vec2 uv) {
    float aspect = panel_size.x / max(panel_size.y, 1.0);
    vec2 p = (uv - vec2(0.5)) * vec2(aspect, 1.0);
    float broad_ridge = sin((p.y * 0.75 + p.x * 0.14) * TAU * surface_frequency);
    float cross_ridge = cos((p.x * 0.32 - p.y * 0.18) * TAU * surface_frequency * 0.63 + 0.8);
    return broad_ridge * 0.055 + cross_ridge * 0.025;
}

void fragment() {
    vec2 texel = TEXTURE_PIXEL_SIZE;
    vec2 dx = vec2(texel.x, 0.0);
    vec2 dy = vec2(0.0, texel.y);

    // Finite differences estimate the gradient of the analytic surface.
    // The gradient is converted into a pixel-sized UV displacement.
    float h_left = surface_height(UV - dx);
    float h_right = surface_height(UV + dx);
    float h_up = surface_height(UV - dy);
    float h_down = surface_height(UV + dy);
    vec2 gradient = vec2(
        (h_right - h_left) / max(2.0 * texel.x, 0.000001),
        (h_down - h_up) / max(2.0 * texel.y, 0.000001)
    );

    vec2 edge_fade = smoothstep(vec2(0.0), vec2(0.035), UV)
        * smoothstep(vec2(0.0), vec2(0.035), vec2(1.0) - UV);
    vec2 offset_uv = gradient * refraction_strength_px * texel * edge_fade;
    vec2 refracted_uv = clamp(UV + offset_uv, vec2(0.001), vec2(0.999));

    COLOR = texture(TEXTURE, refracted_uv);
}
