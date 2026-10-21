shader_type spatial;
render_mode diffuse_burley;

void fragment() {
    // Broad architectural joints, not a luminous coordinate grid.
    vec2 p = UV * vec2(5.0, 5.0);
    vec2 d = min(fract(p), 1.0 - fract(p));
    float seam = 1.0 - smoothstep(0.001, 0.006, min(d.x, d.y));
    ALBEDO = mix(vec3(0.40, 0.42, 0.38), vec3(0.34, 0.36, 0.32), seam * 0.18);
    ROUGHNESS = 0.82;
}
