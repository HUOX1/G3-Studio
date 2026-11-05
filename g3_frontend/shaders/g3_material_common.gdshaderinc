#ifndef G3_MATERIAL_COMMON
#define G3_MATERIAL_COMMON

// Shared procedural building blocks, following the Shader Book's noise / SDF / include workflow.
float g3_hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float g3_value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = g3_hash21(i);
    float b = g3_hash21(i + vec2(1.0, 0.0));
    float c = g3_hash21(i + vec2(0.0, 1.0));
    float d = g3_hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float g3_fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * g3_value_noise(p);
        p *= 2.03;
        amplitude *= 0.48;
    }
    return value;
}

// Signed distance to a rounded rectangle in pixel space.
float g3_sd_round_rect(vec2 uv, vec2 size_px, float radius_px) {
    vec2 p = (uv - vec2(0.5)) * size_px;
    vec2 half_size = size_px * 0.5;
    vec2 q = abs(p) - (half_size - vec2(radius_px));
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius_px;
}

#endif
