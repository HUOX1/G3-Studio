shader_type canvas_item;

// Experiment A complete entrance: power burst, center-out reveal, two VHS faults,
// particle-reactive raster scan, signal-lock sweep, and a clean final frame.
uniform vec2 card_size = vec2(129.58, 194.37);
uniform vec2 phosphor_pitch = vec2(3.2, 2.4);
uniform float card_size_progress : hint_range(0.0, 1.0) = 0.0;

uniform float power_progress : hint_range(0.0, 1.0) = 0.0;
uniform float power_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float reveal_edge_activity : hint_range(0.0, 1.0) = 0.0;
uniform float phosphor_activity : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_strength : hint_range(0.0, 1.5) = 0.0;
uniform float glitch_phase : hint_range(0.0, 100.0) = 0.0;
uniform float scan_progress : hint_range(-1.0, 1.0) = -1.0;
uniform float scan_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float afterglow_envelope : hint_range(0.0, 1.0) = 0.0;
uniform float lock_progress : hint_range(0.0, 1.0) = 0.0;
uniform float lock_envelope : hint_range(0.0, 1.0) = 0.0;

uniform float power_intensity : hint_range(0.5, 2.6) = 1.85;
uniform float phosphor_strength : hint_range(0.0, 1.0) = 0.72;
uniform float reveal_edge_intensity : hint_range(0.0, 2.4) = 1.55;
uniform float glitch_intensity : hint_range(0.0, 1.5) = 0.92;
uniform float scan_intensity : hint_range(0.4, 2.2) = 1.35;
uniform float scan_width_scale : hint_range(0.55, 1.65) = 1.0;
uniform float lock_intensity : hint_range(0.0, 2.0) = 1.15;
uniform float afterglow_strength : hint_range(0.0, 1.0) = 0.55;
uniform float breakup_strength : hint_range(0.0, 1.0) = 0.38;

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
	vec2 safe_pitch = max(phosphor_pitch, vec2(0.5));
	vec2 cell_position = pixel / safe_pitch;
	vec2 cell_id = floor(cell_position);
	vec2 cell_local = fract(cell_position) - vec2(0.5);

	// Fixed RGB phosphor cells. Their response is gated by phosphor_activity,
	// so the final frame returns exactly to the source texture.
	float row_offset = mod(cell_id.y, 2.0);
	float channel_index = mod(cell_id.x + row_offset, 3.0);
	vec3 channel_mask = vec3(
		1.0 - step(0.5, abs(channel_index - 0.0)),
		1.0 - step(0.5, abs(channel_index - 1.0)),
		1.0 - step(0.5, abs(channel_index - 2.0))
	);
	float dot_shape = 1.0 - smoothstep(0.27, 0.39, length(cell_local * vec2(1.0, 1.12)));
	vec3 particle_response = channel_mask * dot_shape;

	// VHS faults are two short timeline events. They perturb selected scanline
	// groups rather than smearing the whole cover continuously.
	float active_glitch = clamp(glitch_strength * glitch_intensity, 0.0, 1.5);
	vec2 sample_uv = UV;
	if (active_glitch > 0.001) {
		float row_height = mix(2.5, 6.0, card_size_progress);
		float row_id = floor(pixel.y / row_height);
		float row_noise = hash12(vec2(row_id, floor(glitch_phase * 1.7)));
		float tear_gate = step(1.0 - min(active_glitch * 0.16, 0.24), row_noise);
		float tear_offset_px = (row_noise - 0.5) * active_glitch * 17.0 * tear_gate;
		float micro_jitter_px = (hash12(vec2(row_id + 19.0, floor(glitch_phase * 2.9))) - 0.5) * active_glitch * 2.2;
		sample_uv.x = clamp(UV.x + (tear_offset_px + micro_jitter_px) / max(card_size.x, 1.0), 0.0, 1.0);
		sample_uv.y = clamp(UV.y + (row_noise - 0.5) * active_glitch * 1.2 / max(card_size.y, 1.0), 0.0, 1.0);
	}

	vec4 source = texture(TEXTURE, sample_uv);
	vec3 source_rgb = source.rgb;
	if (active_glitch > 0.001) {
		float rgb_shift_px = mix(1.2, 5.8, card_size_progress) * active_glitch;
		vec2 red_uv = clamp(sample_uv + vec2(rgb_shift_px / max(card_size.x, 1.0), 0.0), vec2(0.0), vec2(1.0));
		vec2 blue_uv = clamp(sample_uv - vec2(rgb_shift_px / max(card_size.x, 1.0), 0.0), vec2(0.0), vec2(1.0));
		source_rgb = vec3(texture(TEXTURE, red_uv).r, source.g, texture(TEXTURE, blue_uv).b);
	}

	// Center-out image reveal. A narrow horizontal line exists before the image.
	float reveal_half_height = mix(0.002, 0.5, clamp(reveal_progress, 0.0, 1.0));
	float reveal_edge = 0.5 - reveal_half_height;
	float reveal_coordinate = 0.5 - abs(UV.y - 0.5);
	float reveal_mask = 0.0;
	if (reveal_progress > 0.001) {
		reveal_mask = smoothstep(reveal_edge - 0.006, reveal_edge + 0.006, reveal_coordinate);
		reveal_mask = mix(reveal_mask, 1.0, smoothstep(0.985, 1.0, reveal_progress));
	}

	// The opening power line becomes the two moving reveal edges. At the first
	// reveal frame, both edges are still at the card center; as the mask expands,
	// the phosphor core and cyan / magenta bloom follow those exact edge positions.
	float reveal_edge_distance_px = abs(abs(pixel.y - card_size.y * 0.5) - reveal_half_height * card_size.y);
	float reveal_edge_core_width_px = mix(0.78, 1.08, card_size_progress);
	float reveal_edge_halo_width_px = mix(7.0, 11.0, card_size_progress);
	float reveal_edge_core = exp(-pow(reveal_edge_distance_px / reveal_edge_core_width_px, 2.0));
	float reveal_edge_halo = exp(-reveal_edge_distance_px / reveal_edge_halo_width_px);
	float reveal_edge_grain = mix(0.84, 1.16, value_noise(vec2(
		cell_id.x * 0.47,
		cell_id.y * 0.61 + reveal_progress * 9.0
	)));
	vec3 reveal_edge_rgb = vec3(0.90, 0.98, 1.0) * reveal_edge_core
		+ vec3(0.12, 0.78, 1.0) * reveal_edge_halo * 0.68
		+ vec3(1.0, 0.14, 0.62) * reveal_edge_halo * 0.34;
	vec3 reveal_edge_particles = source_rgb * particle_response * reveal_edge_core * 0.62 * phosphor_strength;
	float active_reveal_edge = clamp(reveal_edge_activity, 0.0, 1.0);

	vec3 phosphor_gain = vec3(0.78) + particle_response * 0.62;
	float phosphor_mix = clamp(phosphor_strength * phosphor_activity, 0.0, 1.0);
	vec3 display_rgb = mix(source.rgb, source_rgb, clamp(active_glitch, 0.0, 1.0));
	display_rgb = mix(display_rgb, source_rgb * phosphor_gain, phosphor_mix);
	display_rgb += (reveal_edge_rgb + reveal_edge_particles) * reveal_edge_grain
		* active_reveal_edge * reveal_edge_intensity;

	// POWER ON: a fast white core expands horizontally, surrounded by cyan/pink bloom.
	float center_x_distance = abs(pixel.x - card_size.x * 0.5);
	float center_y_distance = abs(pixel.y - card_size.y * 0.5);
	float power_half_width = mix(1.2, card_size.x * 0.58, power_progress);
	float power_extent = 1.0 - smoothstep(power_half_width, power_half_width + 2.5, center_x_distance);
	float power_core = exp(-center_y_distance / 1.35);
	float power_halo = exp(-center_y_distance / max(mix(8.0, 20.0, card_size_progress), 1.0));
	float power_bloom = exp(-length(vec2(center_x_distance * 0.10, center_y_distance * 0.42)) / 16.0);
	float power_mask = clamp((power_core * 0.95 + power_halo * 0.30) * power_extent * power_envelope * power_intensity, 0.0, 1.0);
	vec3 power_rgb = vec3(0.92, 0.98, 1.0) * power_core
		+ vec3(0.12, 0.78, 1.0) * power_halo * 0.72
		+ vec3(1.0, 0.12, 0.66) * power_bloom * 0.42;
	display_rgb += power_rgb * power_extent * power_envelope * power_intensity;

	// Raster scan: the moving band excites the individual RGB cells.
	float active_envelope = clamp(scan_envelope, 0.0, 1.0);
	float trail_envelope = clamp(afterglow_envelope, 0.0, 1.0);
	if (scan_progress >= 0.0) {
		float scan_band_width_px = mix(9.0, 23.0, card_size_progress) * scan_width_scale;
		float scan_center_px = mix(-scan_band_width_px, card_size.y + scan_band_width_px, clamp(scan_progress, 0.0, 1.0));
		float scan_distance_px = pixel.y - scan_center_px;
		float scan_core = exp(-pow(scan_distance_px / max(scan_band_width_px * 0.20, 1.0), 2.0));
		float scan_halo = exp(-abs(scan_distance_px) / max(scan_band_width_px * 0.95, 1.0));

		float scan_noise = value_noise(vec2(
			UV.x * 46.0 + scan_progress * 8.0,
			pixel.y / max(safe_pitch.y * 3.0, 1.0) + scan_progress * 17.0
		));
		float cell_noise = hash12(cell_id + vec2(floor(scan_progress * 72.0), floor(scan_progress * 29.0)));
		float noise_level = clamp(scan_noise * 0.68 + cell_noise * 0.52, 0.08, 1.22);
		float scan_breakup = mix(1.0, noise_level, breakup_strength);
		float active_scan = scan_core * scan_breakup * active_envelope;
		float halo_scan = scan_halo * mix(1.0, scan_noise, breakup_strength * 0.28) * active_envelope;

		vec3 particle_scan = source_rgb * particle_response * active_scan * scan_intensity * 0.86 * phosphor_strength;
		vec3 scan_tint = vec3(0.30, 0.78, 1.0) * scan_core
			+ vec3(1.0, 0.20, 0.70) * scan_halo * 0.30;
		display_rgb += particle_scan;
		display_rgb += scan_tint * scan_breakup * scan_intensity * 0.20 * active_envelope;

		// A separate decaying phosphor trail survives briefly after the beam passes.
		float behind_distance_px = scan_center_px - pixel.y;
		float trail_length_px = mix(13.0, 32.0, card_size_progress) * (0.65 + afterglow_strength * 0.75);
		float phosphor_trail = exp(-max(behind_distance_px, 0.0) / max(trail_length_px, 1.0))
			* step(0.0, behind_distance_px);
		display_rgb += source_rgb * particle_response * phosphor_trail * afterglow_strength * 0.52 * trail_envelope * phosphor_strength;
		display_rgb += vec3(0.045, 0.16, 0.22) * scan_halo * phosphor_trail * afterglow_strength * 0.22 * trail_envelope;
	}

	// SIGNAL LOCK: a distinct vertical cyan/pink light sheet sweeps left-to-right.
	if (lock_envelope > 0.0) {
		float lock_width_px = mix(5.0, 12.0, card_size_progress);
		float lock_center_px = mix(-lock_width_px * 2.0, card_size.x + lock_width_px * 2.0, lock_progress);
		float lock_distance_px = pixel.x - lock_center_px;
		float lock_core = exp(-pow(lock_distance_px / max(lock_width_px * 0.24, 1.0), 2.0));
		float lock_halo = exp(-abs(lock_distance_px) / max(lock_width_px * 1.8, 1.0));
		float lock_grain = mix(0.62, 1.18, value_noise(vec2(UV.y * 52.0, pixel.x * 0.08 + lock_progress * 13.0)));
		vec3 lock_rgb = vec3(0.78, 0.96, 1.0) * lock_core + vec3(0.18, 0.72, 1.0) * lock_halo * 0.62
			+ vec3(1.0, 0.16, 0.62) * lock_halo * 0.24;
		display_rgb += lock_rgb * lock_grain * lock_envelope * lock_intensity;
	}

	float output_alpha = max(source.a * reveal_mask, power_mask);
	COLOR = vec4(max(display_rgb, vec3(0.0)), output_alpha) * vertex_tint;
}
