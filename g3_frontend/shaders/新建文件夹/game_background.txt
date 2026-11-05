shader_type canvas_item;

// G3 Space Atmosphere A1 - static ambient architecture.
// No textures, no motion, no bloom dependency: intentionally gentle on the GPU.
uniform vec4 top_color : source_color = vec4(0.115, 0.145, 0.190, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.055, 0.070, 0.095, 1.0);
uniform vec4 glow_color : source_color = vec4(0.38, 0.54, 0.73, 1.0);
uniform float glow_amount : hint_range(0.0, 0.5) = 0.075;
uniform float glow_pos_y : hint_range(0.0, 1.0) = 0.10;
uniform float grain_amount : hint_range(0.0, 0.05) = 0.005;
uniform vec4 warm_color : source_color = vec4(0.79, 0.52, 0.32, 1.0);
uniform float warm_amount : hint_range(0.0, 0.15) = 0.016;
uniform float edge_vignette : hint_range(0.0, 0.5) = 0.20;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    // Architectural vertical gradient: brighter above the collection wall.
    vec3 col = mix(bottom_color.rgb, top_color.rgb, pow(1.0 - uv.y, 1.18));

    // Cool ceiling bounce, broad and subtle. Not a moving spotlight.
    vec2 cool_uv = (uv - vec2(0.54, glow_pos_y)) / vec2(0.72, 0.49);
    float cool_pool = exp(-dot(cool_uv, cool_uv) * 2.0);
    col += glow_color.rgb * cool_pool * glow_amount;

    // A small warm reflection makes the space feel lived-in, not sci-fi neon.
    vec2 warm_uv = (uv - vec2(0.90, 0.80)) / vec2(0.34, 0.52);
    float warm_pool = exp(-dot(warm_uv, warm_uv) * 2.2);
    col += warm_color.rgb * warm_pool * warm_amount;

    // Very mild lateral falloff creates a room-like visual boundary.
    vec2 edge = (uv - vec2(0.51, 0.45)) * vec2(1.03, 0.85);
    float vignette = smoothstep(0.25, 0.95, length(edge));
    col *= 1.0 - vignette * edge_vignette;

    // Static dither to avoid perfectly sterile digital gradients.
    float g = hash(floor(uv * vec2(1920.0, 1080.0))) - 0.5;
    col += vec3(g) * grain_amount;
    COLOR = vec4(col, 1.0);
}
