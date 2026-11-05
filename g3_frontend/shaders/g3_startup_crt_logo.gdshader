shader_type canvas_item;
// G3 startup logo only: expanding tube burst, center reveal, VHS horizontal
// displacement and horizontal phosphor scan. No rectangular snow alpha, no
// screen-sized edge outlines and NO vertical signal-lock sweep.
uniform vec2 card_size = vec2(420.0, 322.0);
uniform float power_progress : hint_range(0.0, 1.0) = 0.0;
uniform float power_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float power_burst : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_edge_activity : hint_range(0.0, 1.0) = 0.0;
uniform float phosphor_activity : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_strength : hint_range(0.0, 1.5) = 0.0;
uniform float glitch_phase : hint_range(0.0, 100.0) = 0.0;
uniform float scan_progress : hint_range(-1.0, 1.0) = -1.0;
uniform float scan_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float afterglow_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float settle_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float snow_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float snow_time = 0.0;

varying vec4 vertex_tint;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 local = fract(p);
    local = local * local * (3.0 - 2.0 * local);
    float a = hash12(cell);
    float b = hash12(cell + vec2(1.0, 0.0));
    float c = hash12(cell + vec2(0.0, 1.0));
    float d = hash12(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec2 pixel = UV * card_size;
    vec4 source = texture(TEXTURE, UV);

    // Actual VHS tear: shift complete strips of the original alpha image.
    // Two separate tear rows make the fault readable, but the underlying
    // padded texture keeps displaced fragments inside the logo stage.
    float tracking = clamp(glitch_strength, 0.0, 1.0);
    float row1 = 0.38 + 0.012 * sin(glitch_phase * 0.37);
    float row2 = 0.64 + 0.009 * sin(glitch_phase * 0.51);
    float band1 = 1.0 - smoothstep(0.032, 0.044, abs(UV.y - row1));
    float band2 = 1.0 - smoothstep(0.026, 0.038, abs(UV.y - row2));
    float tear_px = tracking * (band1 * 38.0 - band2 * 29.0);
    vec2 tear_uv = clamp(UV + vec2(tear_px / max(card_size.x, 1.0), 0.0), vec2(0.0), vec2(1.0));
    vec4 torn = texture(TEXTURE, tear_uv);
    float tear_mask = clamp(max(band1, band2) * tracking * 1.18, 0.0, 1.0);
    vec4 image_sample = mix(source, torn, tear_mask);
    vec3 picture = image_sample.rgb;

    // Slight chromatic convergence error INSIDE torn strips only.
    if (tear_mask > 0.001) {
        float shift_px = 2.8 * tear_mask;
        vec2 d = vec2(shift_px / max(card_size.x, 1.0), 0.0);
        vec3 rgb_fault = vec3(
            texture(TEXTURE, clamp(tear_uv + d, vec2(0.0), vec2(1.0))).r,
            torn.g,
            texture(TEXTURE, clamp(tear_uv - d, vec2(0.0), vec2(1.0))).b
        );
        picture = mix(picture, rgb_fault, tear_mask * 0.52);
    }

    // Full center-out image reveal. Its white rim only lights up real logo
    // pixels; unlike the previous version, it cannot outline the card bounds.
    float half_height = mix(0.002, 0.505, clamp(reveal_progress, 0.0, 1.0));
    float from_center = abs(UV.y - 0.5);
    float visible = 1.0 - smoothstep(half_height - 0.008, half_height + 0.008, from_center);
    visible *= step(0.001, reveal_progress);
    float edge_px = abs(from_center * card_size.y - half_height * card_size.y);
    float edge_core = exp(-pow(edge_px / 2.6, 2.0));
    float edge_halo = exp(-edge_px / 10.0);
    float edge_gain = (edge_core * 0.75 + edge_halo * 0.19) * reveal_edge_activity;
    picture += image_sample.rgb * edge_gain * 1.10;

    // Center-line buildup then a coherent oval burst, synchronized with reveal.
    // Both are oval/elliptical so no light reaches a rectangular texture edge.
    float dist_x = abs(UV.x - 0.5);
    float dist_y_px = abs((UV.y - 0.5) * card_size.y);
    float half_w = mix(0.010, 0.405, clamp(power_progress, 0.0, 1.0));
    float width_gate = 1.0 - smoothstep(half_w - 0.023, half_w + 0.022, dist_x);
    float end_soft = exp(-pow(dist_x / 0.34, 4.0));
    float line_core = exp(-pow(dist_y_px / 3.3, 2.0));
    float line_halo = exp(-dist_y_px / 22.0);
    float power_line = (line_core * 1.28 + line_halo * 0.52) * power_envelope * width_gate * end_soft;
    float radial = exp(-pow(dist_x / 0.275, 2.0) - pow(dist_y_px / 75.0, 2.0));
    float bloom = radial * power_burst * 1.95;
    float power_alpha = clamp(power_line * 0.76 + bloom * 0.54, 0.0, 0.98);
    vec3 power_rgb = vec3(0.94, 0.98, 1.0) * (power_line * 1.03 + bloom * 1.12)
        + vec3(0.15, 0.52, 0.76) * (line_halo * width_gate * power_envelope * 0.24 + bloom * 0.19);
    // Prevent texture-rectangle corners from becoming visible.
    float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float no_rectangle = smoothstep(0.0, 0.085, edge_distance);
    power_alpha *= no_rectangle;
    power_rgb *= no_rectangle;

    // Random gray TV snow ONLY on existing silhouette, not in a rectangular
    // region around it. Time-varying noise also reduces fixed grid patterning.
    float snow_frame = floor(snow_time * 30.0);
    float coarse = hash12(floor(pixel * 0.55) + vec2(snow_frame * 7.7, snow_frame * 12.9));
    float fine = hash12(floor(pixel * 1.3) + vec2(snow_frame * 3.1, snow_frame * 5.2));
    float snow = clamp((coarse * 0.69 + fine * 0.31 - 0.40) * 1.55, 0.0, 1.0);
    float snow_mix = snow_envelope * 0.12;
    picture = mix(picture, vec3(snow), snow_mix);
    picture *= 1.0 + phosphor_activity * (fine - 0.5) * 0.09;

    // Unlike the card CRT entrance, the startup logo has no traveling scan.
    // A short intrinsic phosphor memory follows the center-out power bloom.
    picture += image_sample.rgb * afterglow_envelope * 0.20;
    float seam = (exp(-pow((UV.y - row1) / 0.0035, 2.0))
        + exp(-pow((UV.y - row2) / 0.0035, 2.0))) * tracking;
    picture += image_sample.rgb * seam * 0.19;

    // Signal lock is a brief, stationary contrast snap; no vertical sweep.
    picture *= 1.0 + settle_envelope * 0.18;
    float silhouette = image_sample.a * visible;
    float alpha = clamp(max(silhouette, power_alpha), 0.0, 1.0);
    // Outside the actual silhouette, ONLY the oval power burst may appear.
    // The previous rectangular snow/edge alpha contributions are removed.
    vec3 final_rgb = picture + power_rgb;
    COLOR = vec4(max(final_rgb, vec3(0.0)), alpha) * vertex_tint;
}
