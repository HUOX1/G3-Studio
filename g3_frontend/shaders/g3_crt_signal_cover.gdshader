shader_type canvas_item;

// v15 standard-enhance pass: preserve v14's stable structure (no container,
// no aliasing-causing perspective warp, same 520ms HTML clock stretched to
// 960ms by script) while giving the reveal a much clearer VHS / CRT identity.
// Added emphasis: stronger RGB separation, denser scanlines, one short VHS
// tracking event, a lock-on sweep highlight, and a richer inner phosphor glow.
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float crt_ms = -1.0;
uniform vec2 card_size = vec2(150.0, 225.0);
varying vec4 crt_vertex_tint;

float phase(float t, float a, float b) {
    float x = clamp((t - a) / (b - a), 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}
float pulse(float t, float a, float b) {
    if (t <= a || t >= b) {
        return 0.0;
    }
    return sin((t - a) / (b - a) * 3.14159265);
}
float gaussian(float x, float radius) {
    return exp(-3.0 * x * x / max(radius * radius, 0.00001));
}
float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
    crt_vertex_tint = COLOR;
    if (crt_ms >= 0.0 && crt_ms < 520.0) {
        float t = clamp(crt_ms, 0.0, 520.0);
        float expansion = phase(t, 70.0, 190.0);
        float sc = t < 290.0 ? 0.96 + 0.05 * expansion : 1.01 - 0.01 * phase(t, 290.0, 430.0);
        vec2 center = card_size * 0.5;
        vec2 p = VERTEX - center;
        VERTEX = center + p * sc;
    }
}

void fragment() {
    vec4 base_tex = texture(TEXTURE, UV);
    float gray = dot(base_tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 normal = mix(vec3(gray), base_tex.rgb, saturation) * brightness;
    if (crt_ms < 0.0 || crt_ms >= 520.0) {
        COLOR = vec4(normal, base_tex.a) * crt_vertex_tint;
    } else {
        float t = clamp(crt_ms, 0.0, 520.0);
        float charge = phase(t, 0.0, 70.0);
        float expand = phase(t, 70.0, 190.0);
        float lock = phase(t, 190.0, 290.0);
        float finish = phase(t, 430.0, 520.0);
        float expansion = t <= 70.0 ? 0.0 : (t < 190.0 ? expand : 1.0);

        float edge_soft = max(1.5 / max(card_size.y, 1.0), TEXTURE_PIXEL_SIZE.y * 1.5);
        float band_limit = expansion * 0.5;
        float image_mask = step(70.0, t)
            * (1.0 - smoothstep(band_limit - edge_soft, band_limit + edge_soft, abs(UV.y - 0.5)));

        // Deterministic sample coordinates for VHS distortion. The picture is
        // already fully visible by the time the tracking event starts, so this
        // never creates a placeholder frame around a partial reveal.
        vec2 sample_uv = UV;
        float tracking = pulse(t, 214.0, 326.0);
        float track_center = mix(0.34, 0.69, phase(t, 214.0, 326.0));
        float track_band = gaussian(UV.y - track_center, 0.034);
        float row_noise = hash12(vec2(floor(UV.y * card_size.y * 0.45) + floor(t * 0.12), 17.0));
        float wobble_px = (sin(UV.y * 96.0 + t * 0.15) * 0.75 + (row_noise - 0.5) * 2.1)
            * tracking * (0.35 + 1.45 * track_band);
        sample_uv.x += wobble_px * TEXTURE_PIXEL_SIZE.x;
        sample_uv.y += sin(UV.x * 11.5 + t * 0.041) * tracking * track_band * 0.004;
        sample_uv = clamp(sample_uv, vec2(0.0), vec2(1.0));

        vec4 sample_tex = texture(TEXTURE, sample_uv);
        float sample_gray = dot(sample_tex.rgb, vec3(0.299, 0.587, 0.114));
        float image_opacity = t < 70.0 ? 0.0 : 0.56 + 0.44 * phase(t, 70.0, 240.0);
        float image_alpha = image_mask * image_opacity * sample_tex.a;
        float luminance = t < 70.0 ? 1.0 : 1.22 - 0.22 * lock;
        float sat_boost = 1.14 - 0.14 * lock;
        vec3 cover = mix(vec3(sample_gray), sample_tex.rgb, saturation * sat_boost) * brightness * luminance;

        // Stronger but still controlled RGB separation, peaking during the
        // reveal and decaying as the signal locks.
        float rgb_noise = t >= 70.0 && t < 360.0 ?
            (t < 190.0 ? 0.54 : 0.54 * (1.0 - 0.78 * lock)) : 0.0;
        float rgb_px = 1.2 + 1.0 * (1.0 - lock) + 0.9 * tracking * track_band;
        vec2 px = TEXTURE_PIXEL_SIZE;
        vec3 rgb_shift = vec3(
            texture(TEXTURE, clamp(sample_uv + vec2(rgb_px, 0.18) * px, vec2(0.0), vec2(1.0))).r,
            texture(TEXTURE, clamp(sample_uv + vec2(0.0, 0.10) * px, vec2(0.0), vec2(1.0))).g,
            texture(TEXTURE, clamp(sample_uv - vec2(rgb_px, 0.15) * px, vec2(0.0), vec2(1.0))).b
        );
        cover = mix(cover, rgb_shift * brightness * luminance, rgb_noise * 0.78);

        // Denser scanlines and a traveling raster-brightness band.
        float scan_alpha = t >= 70.0 && t < 360.0 ? 0.84 * (1.0 - 0.74 * lock) : 0.0;
        float scanlines = 0.5 + 0.5 * cos(UV.y * card_size.y * 3.14159265);
        cover *= 1.0 - scan_alpha * scanlines * 0.24;
        float raster_sweep = pulse(t, 120.0, 318.0);
        float raster_y = -0.18 + 1.30 * phase(t, 120.0, 318.0);
        float raster_band = gaussian(UV.y - raster_y, 0.050);
        cover += vec3(0.55, 0.90, 1.0) * raster_sweep * raster_band * 0.16;

        // One noticeable but brief VHS tracking event after full reveal.
        float track_bloom = tracking * track_band;
        cover += vec3(0.90, 0.97, 1.0) * track_bloom * 0.16;
        cover += vec3(1.0, 0.34, 0.79) * tracking * gaussian(UV.y - (track_center + 0.018), 0.060) * 0.08;

        float lock_alpha = pulse(t, 195.0, 255.0) * 0.92;
        float lock_y = 0.24 + 0.60 * lock;
        cover += vec3(0.77, 0.94, 1.0) * lock_alpha * gaussian(UV.y - lock_y, 4.0 / max(card_size.y, 1.0)) * 0.72;

        // Stronger inner phosphor and a two-layer glow, but only after the
        // full image exists so the empty slot never gets traced.
        float edge_px = min(min(UV.x, 1.0 - UV.x) * card_size.x, min(UV.y, 1.0 - UV.y) * card_size.y);
        float phosphor = phase(t, 190.0, 260.0) * (1.0 - 0.82 * finish);
        cover += vec3(0.48, 0.92, 1.0) * phosphor * gaussian(edge_px, 15.0) * 0.22;
        cover += vec3(1.0, 0.42, 0.82) * phosphor * gaussian(edge_px, 28.0) * 0.10;
        cover += vec3(0.95, 1.0, 1.0) * phosphor * gaussian(edge_px, 1.2) * 0.12;

        // Signal-lock sweep highlight synced to the shell return interval.
        float sweep = pulse(t, 292.0, 382.0);
        float sweep_x = -0.12 + 1.24 * phase(t, 292.0, 382.0);
        float highlight = gaussian(UV.x - sweep_x, 0.045) * (0.45 + 0.55 * gaussian(UV.y - 0.5, 0.34));
        cover += vec3(1.0, 1.0, 1.0) * sweep * highlight * 0.24;
        cover += vec3(0.52, 0.92, 1.0) * sweep * gaussian(UV.x - (sweep_x - 0.012), 0.060) * 0.11;

        float line_level = t < 70.0 ? sin(charge * 1.57079633) :
            (t < 190.0 ? 1.0 - expand : 0.0);
        float beam_half = (8.0 + 202.0 * charge) / 420.0;
        float beam_gate = 1.0 - smoothstep(beam_half - 0.018, beam_half + 0.002, abs(UV.x - 0.5));
        float dy_px = abs(UV.y - 0.5) * card_size.y;
        float white_core = gaussian(dy_px, 2.0);
        float cyan_glow = gaussian(dy_px, 14.0);
        float pink_glow = gaussian(dy_px, 34.0);
        vec3 beam_color = vec3(1.0) * white_core
            + vec3(0.15, 0.78, 0.95) * cyan_glow * 0.64
            + vec3(0.95, 0.25, 0.79) * pink_glow * 0.34;
        float spark = t < 70.0 ? sin(charge * 3.14159265) * 0.95 : 0.0;
        float spark_radius = length((UV - vec2(0.5)) * card_size);
        beam_color += (vec3(1.0) * gaussian(spark_radius, 5.0)
            + vec3(0.4, 0.85, 1.0) * gaussian(spark_radius, 18.0) * 0.74) * spark;

        // Very fine deterministic luma noise during the analog stages.
        float grain = (hash12(vec2(floor(UV.x * card_size.x * 0.8) + floor(t * 0.27), floor(UV.y * card_size.y * 0.8))) - 0.5);
        float grain_alpha = (0.018 + 0.026 * tracking + 0.016 * (1.0 - lock)) * (1.0 - finish);
        cover += vec3(grain * grain_alpha);

        vec3 output_rgb = cover * image_mask + beam_color * beam_gate * line_level;
        float line_alpha = clamp((white_core + 0.5 * cyan_glow + 0.18 * pink_glow)
            * beam_gate * line_level + spark * gaussian(spark_radius, 15.0), 0.0, 1.0);
        COLOR = vec4(max(output_rgb, vec3(0.0)), max(image_alpha, line_alpha)) * crt_vertex_tint;
    }
}
