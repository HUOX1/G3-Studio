from pathlib import Path
import math
import pytest
import re

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "g3_frontend" / "scripts"
SHADERS = ROOT / "g3_frontend" / "shaders"


def test_interaction_lab_keeps_the_dedicated_crt_page_and_real_sample_bridge():
    lab = (SCRIPTS / "interaction_lab.gd").read_text(encoding="utf-8")
    main = (SCRIPTS / "main.gd").read_text(encoding="utf-8")
    game_section = (SCRIPTS / "game_section.gd").read_text(encoding="utf-8")

    assert 'preload("res://scripts/crt_animation_lab.gd")' in lab
    assert '"CRT 动画实验"' in lab
    assert "_crt_page.set_page_active" in lab
    assert "func set_game_samples(samples: Array[Dictionary])" in lab
    assert "game_section.lab_cover_samples_changed.connect" in main
    assert "game_section.get_animation_lab_samples(6)" in main
    assert "signal lab_cover_samples_changed" in game_section
    assert '"texture": cover_rect.texture' in game_section


def test_experiment_a_replaces_all_legacy_v16_effects_in_the_lab():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader_path = SHADERS / "g3_crt_phosphor_scan.gdshader"
    legacy_shader_path = SHADERS / "g3_crt_lab_preview.gdshader"

    assert 'preload("res://shaders/g3_crt_phosphor_scan.gdshader")' in lab
    assert shader_path.is_file()
    assert not legacy_shader_path.exists()

    legacy_controls = (
        "Shadow Mask", "Aperture Grille", "Slot Mask", "Hybrid",
        "水平撕裂", "RGB 色彩渗漏", "模拟噪点", "水平扫描线",
        "静态点阵预览", "蒸汽波色调", "mask_when_idle",
        "tracking_enabled", "vaporwave_tone_enabled", "crt_ms",
    )
    for legacy in legacy_controls:
        assert legacy not in lab
        if shader_path.is_file():
            assert legacy not in shader_path.read_text(encoding="utf-8")


def test_experiment_a_exposes_only_the_phosphor_scan_parameters():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    for label in ("通电爆发", "颗粒显色强度", "展开边缘磷光", "信号故障", "扫光强度", "光带宽度", "锁定高光", "颗粒余辉", "噪声破碎", "扫描速度"):
        assert label in lab
    for uniform in (
        "power_intensity", "phosphor_strength", "reveal_edge_intensity", "glitch_intensity", "scan_intensity",
        "scan_width_scale", "lock_intensity", "afterglow_strength", "breakup_strength",
        "power_progress", "power_envelope", "reveal_progress", "phosphor_activity",
        "glitch_strength", "glitch_phase", "scan_progress", "scan_envelope",
        "afterglow_envelope", "lock_progress", "lock_envelope", "phosphor_pitch",
        "card_size", "card_size_progress",
    ):
        assert uniform in shader
        assert uniform in lab


def _expected_game_card_size(width: int, height: int) -> tuple[float, float]:
    ui_scale = max(0.62, min(1.30, min(width / 1920.0, height / 1080.0)))
    sidebar_width = 280.0 * ui_scale
    padding = int(24.0 * ui_scale)
    available_logic_width = (width - sidebar_width - 2.0 * padding) / ui_scale
    tiers = ((150.0, 5, 7, 52.0), (200.0, 5, 7, 70.0), (290.0, 6, 8, 100.0))
    chosen_width = tiers[0][0]

    for index, (card_width, min_cols, max_cols, max_gap) in enumerate(tiers):
        n_max = math.floor((available_logic_width + 12.0) / (card_width + 12.0))
        columns = max(min_cols, min(max_cols, n_max))
        gap = (available_logic_width - columns * card_width) / (columns - 1) if columns > 1 else 0.0
        is_last = index == len(tiers) - 1
        if n_max < min_cols:
            chosen_width = max(80.0, (available_logic_width - (min_cols - 1) * 12.0) / min_cols)
            break
        if n_max <= max_cols and gap <= max_gap:
            chosen_width = card_width
            break
        if is_last:
            chosen_width = card_width
            break

    actual_width = chosen_width * ui_scale
    return actual_width, actual_width * 1.5


def test_phosphor_pitch_adapts_between_minimum_and_maximum_game_card_sizes():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    game_section = (SCRIPTS / "game_section.gd").read_text(encoding="utf-8")

    assert "func _calculate_game_card_size(viewport_size: Vector2) -> Vector2" in lab
    assert "func _calculate_phosphor_pitch(card_width: float) -> Vector2" in lab
    assert "func _calculate_card_size_progress(card_width: float) -> float" in lab
    assert "NOTIFICATION_RESIZED" in lab
    assert "card_size" in lab and "phosphor_pitch" in lab
    assert "CARD_TIERS" in lab
    assert "UI_SCALE_MIN" in lab and "UI_SCALE_MAX" in lab
    assert "CARD_ASPECT" in lab
    assert "const MIN_REFERENCE_CARD_WIDTH: float = 129.58" in lab
    assert "const MAX_REFERENCE_CARD_WIDTH: float = 377.0" in lab

    min_size = _expected_game_card_size(1244, 700)
    max_size = _expected_game_card_size(3840, 2160)
    assert min_size == pytest.approx((129.58, 194.37), abs=0.02)
    assert max_size == pytest.approx((377.0, 565.5), abs=0.01)

    assert "const PHOSPHOR_PITCH_MIN: Vector2 = Vector2(3.2, 2.4)" in lab
    assert "const PHOSPHOR_PITCH_MAX: Vector2 = Vector2(1.9, 1.55)" in lab


def test_preview_card_layout_constants_mirror_the_formal_game_grid():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    game_section = (SCRIPTS / "game_section.gd").read_text(encoding="utf-8")

    for constant in (
        "UI_BASE_W", "UI_BASE_H", "UI_SCALE_MIN", "UI_SCALE_MAX",
        "SIDEBAR_W_BASE", "GRID_PADDING_BASE", "GRID_GAP_MIN", "CARD_ASPECT",
    ):
        formal = re.search(rf"const {constant}: float = ([0-9.]+)", game_section)
        preview = re.search(rf"const {constant}: float = ([0-9.]+)", lab)
        assert formal is not None and preview is not None
        assert float(preview.group(1)) == float(formal.group(1))

    formal_tiers = re.search(r"const CARD_TIERS: Array = \[([\s\S]*?)\n\]", game_section)
    preview_tiers = re.search(r"const CARD_TIERS: Array = \[([\s\S]*?)\n\]", lab)
    assert formal_tiers is not None and preview_tiers is not None
    assert re.sub(r"\s+", "", preview_tiers.group(1)) == re.sub(r"\s+", "", formal_tiers.group(1))


def test_scan_is_idle_until_played_and_stop_or_page_exit_clears_the_beam():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    assert 'set_shader_parameter("scan_progress", -1.0)' in lab
    assert "func _start_scan()" in lab
    assert "func _stop_scan(" in lab
    assert "_stop_scan()" in lab.split("func set_page_active", 1)[1].split("func set_game_samples", 1)[0]
    assert "if (scan_progress >= 0.0)" in shader
    assert "if (lock_envelope > 0.0)" in shader
    assert "func _process(delta: float) -> void" in lab


def test_shader_uses_structured_rgb_phosphor_and_particle_responsive_scan_noise():
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    for token in (
        "channel_index", "phosphor_pitch", "dot_shape", "value_noise",
        "scan_center_px", "scan_core", "scan_halo", "scan_breakup",
        "particle_response", "phosphor_trail",
    ):
        assert token in shader
    assert "SCREEN_TEXTURE" not in shader
    assert "SCREEN_UV" not in shader


def test_lab_uses_real_cover_textures_and_does_not_start_another_decode_pipeline():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    assert 'sample.get("texture") as Texture2D' in lab
    assert "TextureRect.new()" in lab
    assert "poster.texture = texture" in lab
    assert "WorkerThreadPool" not in lab
    assert "func set_game_samples(samples: Array[Dictionary])" in lab
    assert "_has_pending_samples" in lab


def test_experiment_shader_remains_isolated_from_formal_v15_shaders():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    assert 'preload("res://shaders/g3_crt_phosphor_scan.gdshader")' in lab
    assert "g3_crt_signal_cover.gdshader" not in lab
    assert "g3_crt_signal_halo.gdshader" not in lab


def test_preview_card_geometry_resizes_without_legacy_shell_motion():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    assert "poster_stage.custom_minimum_size = _card_size" in lab
    assert 'material.set_shader_parameter("card_size", _card_size)' in lab
    assert "poster_shell" not in lab
    assert "_update_shell_offset" not in lab
    assert "10.0 * (1.0 - eased)" not in lab


def test_scan_controls_update_each_preview_material_without_old_v16_parameters():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")
    for parameter in (
        "power_intensity", "phosphor_strength", "reveal_edge_intensity", "glitch_intensity", "scan_intensity",
        "scan_width_scale", "lock_intensity", "afterglow_strength", "breakup_strength",
        "card_size_progress",
    ):
        assert f'set_shader_parameter("{parameter}"' in lab
        assert f'uniform float {parameter}' in shader
    for effect_parameter in (
        "power_progress", "power_envelope", "reveal_progress", "phosphor_activity",
        "glitch_strength", "glitch_phase", "scan_progress", "scan_envelope",
        "afterglow_envelope", "lock_progress", "lock_envelope",
    ):
        assert f'"{effect_parameter}"' in lab
        assert f'uniform float {effect_parameter}' in shader
    assert "material.set_shader_parameter(StringName(str(parameter)), effect_state[parameter])" in lab
    assert "CRT / VHS 完整入场实验" in lab
    for old_parameter in (
        "mask_type", "mask_strength", "tracking_enabled", "rgb_bleed_enabled",
        "grain_enabled", "scanlines_enabled", "phosphor_enabled",
        "mask_when_idle", "vaporwave_tone_enabled",
    ):
        assert old_parameter not in lab


def test_complete_entry_animation_moves_the_whole_card_with_staggered_timing():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")

    assert "const ENTRY_DURATION_SEC: float = 0.96" in lab
    assert "const CARD_STAGGER_SEC: float = 0.13" in lab
    assert "const ENTRY_START_OFFSET_Y: float = 24.0" in lab
    assert "const ENTRY_START_SCALE: float = 0.97" in lab
    assert "const PHASE_MOVE_START: float = 0.455" in lab
    assert "const PHASE_MOVE_END: float = 0.835" in lab
    assert '"motion": motion' in lab
    assert '"slot": slot' in lab
    assert "var local_elapsed: float = _animation_elapsed - float(index) * CARD_STAGGER_SEC" in lab
    assert "motion.offset_top = y_offset" in lab
    assert "motion.offset_bottom = y_offset" in lab
    assert "motion.scale = Vector2.ONE * scale_value" in lab
    assert "motion.modulate = Color(1.0, 1.0, 1.0, 1.0)" in lab
    assert "func _update_card_entry(" in lab
    assert "func _prepare_card_for_entry(" in lab
    assert "func _set_card_to_rest(" in lab
    assert "_set_card_label_alpha(card, 0.0)" in lab
    stop_body = lab.split("func _stop_scan(", 1)[1].split("func _update_card_entry(", 1)[0]
    assert "for card in _cards:" in stop_body
    assert "_set_card_to_rest(card)" in stop_body
    assert 'play_button.text = "播放完整入场"' in lab

def test_shader_animates_center_out_reveal_and_fades_each_effect_independently():
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")
    for token in (
        "uniform float reveal_progress", "uniform float power_envelope",
        "uniform float phosphor_activity", "uniform float glitch_strength",
        "uniform float scan_envelope", "uniform float afterglow_envelope",
        "uniform float lock_envelope", "reveal_edge", "reveal_mask",
        "power_extent", "active_envelope", "trail_envelope",
        "vec3 display_rgb = mix(source.rgb, source_rgb", "phosphor_mix",
    ):
        assert token in shader
    assert "uniform float entry_progress" not in shader
    assert "startup_line_strength" not in shader

def test_entry_queue_duration_and_one_shot_completion_are_consistent():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    six_card_total = 0.96 + 5 * 0.13
    assert six_card_total == pytest.approx(1.61)
    assert "var all_cards_entered: bool = true" in lab
    assert "if all_cards_entered:" in lab
    assert "完整入场完成 · 所有入场特效已清除" in lab
    assert "_loop_check" not in lab

def test_complete_entry_is_a_one_shot_per_card_and_never_loops_after_cover_reveals():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    assert "_loop_check" not in lab
    assert "入场后循环扫描" not in lab
    assert "循环扫描" not in lab
    assert "播放完成后全部入场特效归零" in lab


def test_entry_timeline_uses_independent_bursts_sustained_scans_and_a_final_clean_tail():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    for phase in (
        "PHASE_POWER_START", "PHASE_POWER_PEAK", "PHASE_POWER_END",
        "PHASE_REVEAL_START", "PHASE_REVEAL_END",
        "PHASE_GLITCH_ONE", "PHASE_GLITCH_TWO",
        "PHASE_SCAN_START", "PHASE_SCAN_END",
        "PHASE_LOCK_START", "PHASE_LOCK_END",
        "PHASE_MOVE_START", "PHASE_MOVE_END", "PHASE_CLEAN_START",
    ):
        assert f"const {phase}" in lab

    for uniform in (
        "power_progress", "power_envelope", "reveal_progress", "phosphor_activity",
        "glitch_strength", "glitch_phase", "scan_progress", "scan_envelope",
        "afterglow_envelope", "lock_progress", "lock_envelope",
    ):
        assert f'uniform float {uniform}' in shader
        assert f'"{uniform}"' in lab

    assert "_pulse_envelope" in lab
    assert "_get_entry_effect_state" in lab
    assert "_smoothstep(PHASE_CLEAN_START" in lab
    assert "_smoothstep(PHASE_CLEAN_START, PHASE_AFTERGLOW_END, progress)" in lab


def test_rest_state_disables_every_visual_effect_and_returns_the_original_texture():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")
    rest_body = lab.split("func _get_clean_effect_state(", 1)[1].split("func _get_initial_effect_state(", 1)[0]
    set_rest_body = lab.split("func _set_card_to_rest(", 1)[1].split("func _set_card_motion_state(", 1)[0]

    for parameter in (
        "power_envelope", "reveal_edge_activity", "phosphor_activity", "glitch_strength", "scan_envelope",
        "afterglow_envelope", "lock_envelope",
    ):
        assert f'"{parameter}": 0.0' in rest_body
    assert '"scan_progress": -1.0' in rest_body
    assert '"reveal_progress": 1.0' in rest_body
    assert "_get_clean_effect_state()" in set_rest_body
    assert "vec3 display_rgb = mix(source.rgb, source_rgb" in shader
    assert "phosphor_activity" in shader


def test_glitch_is_two_short_events_and_scan_afterglow_is_separate_from_the_beam():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    assert "_pulse_envelope(progress, PHASE_GLITCH_ONE" in lab
    assert "_pulse_envelope(progress, PHASE_GLITCH_TWO" in lab
    assert "afterglow_envelope" in shader
    assert "active_envelope" in shader
    assert "trail_envelope" in shader


def test_card_motion_and_labels_are_coordinated_without_fading_the_power_beam_with_the_root():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    update_body = lab.split("func _update_card_entry(", 1)[1].split("func _prepare_card_for_entry(", 1)[0]
    prepare_body = lab.split("func _prepare_card_for_entry(", 1)[1].split("func _set_card_to_rest(", 1)[0]

    assert "_set_card_motion_state(card, y_offset, scale_value)" in update_body
    assert "_set_card_label_alpha" in update_body
    assert "_set_card_label_alpha(card, 0.0)" in prepare_body
    assert "motion.modulate = Color(1.0, 1.0, 1.0, 1.0)" in lab


def test_visual_events_overlap_intentionally_but_all_effects_finish_before_the_clean_hold():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    values = {}
    for name in (
        "PHASE_POWER_END", "PHASE_REVEAL_START", "PHASE_REVEAL_END",
        "PHASE_GLITCH_ONE", "PHASE_GLITCH_TWO", "PHASE_SCAN_START",
        "PHASE_SCAN_END", "PHASE_LOCK_START", "PHASE_MOVE_START",
        "PHASE_MOVE_END", "PHASE_CLEAN_START", "PHASE_AFTERGLOW_END",
    ):
        match = re.search(rf"const {name}: float = ([0-9.]+)", lab)
        assert match is not None
        values[name] = float(match.group(1))

    assert values["PHASE_REVEAL_START"] < values["PHASE_POWER_END"]
    assert values["PHASE_GLITCH_ONE"] < values["PHASE_REVEAL_END"]
    assert values["PHASE_SCAN_START"] < values["PHASE_GLITCH_TWO"] < values["PHASE_SCAN_END"]
    assert values["PHASE_LOCK_START"] < values["PHASE_SCAN_END"]
    assert values["PHASE_MOVE_START"] < values["PHASE_LOCK_START"] < values["PHASE_MOVE_END"]
    assert values["PHASE_CLEAN_START"] < values["PHASE_MOVE_END"] < values["PHASE_AFTERGLOW_END"] < 1.0
    assert 1.0 - values["PHASE_AFTERGLOW_END"] >= 0.09


def test_reveal_edge_phosphor_handoffs_from_power_line_and_tracks_the_expanding_front():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    assert '"reveal_edge_activity"' in lab
    assert '"reveal_edge_intensity"' in lab
    assert "uniform float reveal_edge_activity" in shader
    assert "uniform float reveal_edge_intensity" in shader
    assert "maxf(power_envelope * 0.88, reveal_edge_envelope)" in lab
    assert "const PHASE_REVEAL_EDGE_RELEASE_START: float = 0.305" in lab
    assert "const PHASE_REVEAL_EDGE_RELEASE_END: float = 0.385" in lab
    assert "reveal_edge_distance_px = abs(abs(pixel.y - card_size.y * 0.5) - reveal_half_height * card_size.y)" in shader
    assert "reveal_edge_core" in shader
    assert "reveal_edge_halo" in shader
    assert "reveal_edge_rgb" in shader
    assert "display_rgb += (reveal_edge_rgb + reveal_edge_particles)" in shader
    assert shader.index("vec3 display_rgb =") < shader.index("display_rgb += (reveal_edge_rgb + reveal_edge_particles)")
    assert "float output_alpha = max(source.a * reveal_mask, power_mask);" in shader


def test_rgb_phosphor_dots_are_smaller_without_changing_the_adaptive_cell_pitch():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    assert "const PHOSPHOR_PITCH_MIN: Vector2 = Vector2(3.2, 2.4)" in lab
    assert "const PHOSPHOR_PITCH_MAX: Vector2 = Vector2(1.9, 1.55)" in lab
    assert "smoothstep(0.27, 0.39, length(cell_local * vec2(1.0, 1.12)))" in shader
    assert "smoothstep(0.34, 0.48, length(cell_local" not in shader


def test_phosphor_strength_is_explained_and_controls_particle_brightness_not_alpha_or_density():
    lab = (SCRIPTS / "crt_animation_lab.gd").read_text(encoding="utf-8")
    shader = (SHADERS / "g3_crt_phosphor_scan.gdshader").read_text(encoding="utf-8")

    assert "荧光颗粒响应强度" in lab
    assert "不改变透明度、颗粒数量或排列间距" in lab
    assert '"颗粒显色强度"' in lab
    assert "particle_scan" in shader
    assert "phosphor_strength" in shader.split("vec3 particle_scan", 1)[1].split(";", 1)[0]
    assert "phosphor_strength" in shader.split("float phosphor_mix", 1)[1].split(";", 1)[0]
    output_alpha_line = next(line for line in shader.splitlines() if "float output_alpha" in line)
    assert "phosphor_strength" not in output_alpha_line
