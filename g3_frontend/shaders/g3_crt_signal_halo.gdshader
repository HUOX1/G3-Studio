shader_type canvas_item;
render_mode blend_add;

// v15 standard-enhance: strengthen the outer CRT phosphor glow into a more
// clearly synthwave/VHS-flavoured double bloom, but keep it delayed until the
// poster is fully present so no placeholder silhouette can emerge.
uniform float crt_ms = -1.0;
uniform vec2 poster_size = vec2(150.0, 225.0);
uniform float margin_px = 20.0;

float phase(float t, float a, float b) {
    float x = clamp((t - a) / (b - a), 0.0, 1.0);
    return x*x*(3.0 - 2.0*x);
}
float pulse(float t, float a, float b) {
    if (t <= a || t >= b) {
        return 0.0;
    }
    return sin((t - a) / (b - a) * 3.14159265);
}
float gauss(float v, float r) { return exp(-3.0*v*v/max(r*r, 0.0001)); }

void fragment() {
    if (crt_ms < 190.0 || crt_ms >= 520.0) {
        discard;
    } else {
        float t = clamp(crt_ms, 0.0, 520.0);
        float lock = phase(t, 190.0, 290.0);
        float finish = phase(t, 430.0, 520.0);
        float glow = phase(t, 190.0, 255.0) * (1.0 - 0.78 * finish);
        float sweep = pulse(t, 292.0, 382.0);

        vec2 outer = poster_size + vec2(2.0 * margin_px);
        vec2 p = UV * outer - vec2(margin_px);
        vec2 ext = max(-p, p - poster_size);
        float outside = max(max(ext.x, ext.y), 0.0);
        float inside = step(0.0, min(min(p.x,p.y),min(poster_size.x-p.x,poster_size.y-p.y)));
        float edge_tight = (1.0 - inside) * gauss(outside, 6.0);
        float edge_wide = (1.0 - inside) * gauss(outside, 16.0);
        float vertical_focus = gauss(p.y - poster_size.y * 0.5, poster_size.y * 0.62);

        // Cyan + magenta double glow, the hallmark of the requested reference style.
        float cyan = (edge_tight * 0.22 + edge_wide * 0.26) * glow * vertical_focus;
        float pink = (edge_tight * 0.08 + edge_wide * 0.16) * glow * vertical_focus;

        // Brief lock-on pulse and sweep accent during the shell return.
        float lock_pulse = pulse(t, 210.0, 300.0);
        cyan += edge_wide * vertical_focus * lock_pulse * (0.06 + 0.04 * (1.0 - lock));
        pink += edge_wide * vertical_focus * lock_pulse * 0.03;
        float sweep_x = -margin_px + (poster_size.x + 2.0 * margin_px) * phase(t, 292.0, 382.0);
        float sweep_band = gauss(p.x - sweep_x, 9.0) * gauss(p.y - poster_size.y * 0.5, poster_size.y * 0.33);
        cyan += sweep * sweep_band * 0.06;
        pink += sweep * sweep_band * 0.03;

        float alpha = clamp(cyan + pink, 0.0, 0.30) * (1.0 - inside);
        COLOR = vec4(0.32 * cyan + 0.96 * pink, 0.94 * cyan + 0.28 * pink, cyan + 0.82 * pink, alpha);
    }
}
