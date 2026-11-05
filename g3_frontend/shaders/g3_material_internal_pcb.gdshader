shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "g3_material_common.gdshaderinc"

// M04 · Internal PCB
// Orthogonal copper traces, solder pads and a moving signal pulse under a smoked cover.
uniform vec4 board_color : source_color = vec4(0.018, 0.045, 0.046, 1.0);
uniform vec4 trace_color : source_color = vec4(0.17, 0.35, 0.34, 1.0);
uniform vec4 accent_color : source_color = vec4(0.98, 0.58, 0.20, 1.0);
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.72;
uniform float trace_brightness : hint_range(0.0, 2.0) = 0.8;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.58;
uniform vec2 panel_size = vec2(440.0, 112.0);
uniform float corner_radius : hint_range(0.0, 12.0) = 3.0;

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * h);
}

float line_mask(float d, float width) {
    return 1.0 - smoothstep(width, width + 0.008, d);
}

void fragment() {
    float panel_sd = g3_sd_round_rect(UV, panel_size, corner_radius);
    float panel_alpha = 1.0 - smoothstep(0.0, 1.0, panel_sd);
    float aspect = panel_size.x / max(panel_size.y, 1.0);
    // Work in height-relative pixel space: trace thickness stays constant
    // while the preview width changes, and solder pads remain round.
    vec2 p = vec2(UV.x * aspect, UV.y);
    float d = 1.0;
    d = min(d, segment_distance(p, vec2(0.08 * aspect, 0.25), vec2(0.44 * aspect, 0.25)));
    d = min(d, segment_distance(p, vec2(0.44 * aspect, 0.25), vec2(0.44 * aspect, 0.72)));
    d = min(d, segment_distance(p, vec2(0.44 * aspect, 0.72), vec2(0.82 * aspect, 0.72)));
    d = min(d, segment_distance(p, vec2(0.18 * aspect, 0.82), vec2(0.18 * aspect, 0.48)));
    d = min(d, segment_distance(p, vec2(0.18 * aspect, 0.48), vec2(0.72 * aspect, 0.48)));
    d = min(d, segment_distance(p, vec2(0.72 * aspect, 0.48), vec2(0.72 * aspect, 0.16)));
    d = min(d, segment_distance(p, vec2(0.58 * aspect, 0.16), vec2(0.90 * aspect, 0.16)));

    float traces = line_mask(d, 0.009);
    float fine_traces = line_mask(d, 0.0035) * 0.55;
    float pulse_phase = fract(TIME * pulse_speed + UV.x * 0.78 + UV.y * 0.22);
    float pulse_band = exp(-pow((pulse_phase - 0.5) * 7.0, 2.0));
    float pulse = traces * pulse_band;

    float pad_a = 1.0 - smoothstep(0.025, 0.032, distance(p, vec2(0.08 * aspect, 0.25)));
    float pad_b = 1.0 - smoothstep(0.025, 0.032, distance(p, vec2(0.82 * aspect, 0.72)));
    float pad_c = 1.0 - smoothstep(0.025, 0.032, distance(p, vec2(0.90 * aspect, 0.16)));
    float pads = max(max(pad_a, pad_b), pad_c);
    float grid = (1.0 - smoothstep(0.001, 0.004, abs(fract(UV.x * 18.0) - 0.5))) * 0.025;

    vec3 color = board_color.rgb + trace_color.rgb * traces * trace_brightness;
    color += trace_color.rgb * fine_traces * detail_amount;
    color += accent_color.rgb * pulse * 0.95;
    color += accent_color.rgb * pads * 0.55;
    color += vec3(0.05, 0.08, 0.08) * grid;
    color += vec3(0.08, 0.12, 0.12) * (1.0 - smoothstep(0.0, 0.025, min(min(UV.x, 1.0-UV.x), min(UV.y, 1.0-UV.y))));
    COLOR = vec4(color, panel_alpha);
}
