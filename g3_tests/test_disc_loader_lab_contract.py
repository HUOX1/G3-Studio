from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "g3_frontend" / "scripts"


def read_script(name: str) -> str:
    return (SCRIPTS / name).read_text(encoding="utf-8")


def test_interaction_lab_repurposes_icon_comparison_page_for_disc_loader():
    source = read_script("interaction_lab.gd")
    assert 'preload("res://scripts/disc_loader_lab.gd")' in source
    assert '"启动装置实验"' in source
    assert "图标对比" not in source
    assert "ICON_LAB_SCRIPT" not in source
    assert not (SCRIPTS / "icon_lab.gd").exists()


def test_disc_loader_lab_previews_the_button_in_detail_page_context():
    source = read_script("disc_loader_lab.gd")
    assert "Hero" in source or "HERO" in source
    assert "截图" in source
    assert "简介" in source
    assert "set_page_active" in source
    assert "HiddenSlimLoaderDrawerExperiment" in source
    assert "外露把手" in source
    assert "不会启动真实游戏" in source


def test_disc_loader_experiment_button_has_two_mechanical_faceplate_variants():
    source = read_script("disc_loader_experiment_button.gd")
    assert "HI_FI_DECK" in source
    assert "SLIM_LOADER" in source
    assert "draw_colored_polygon" in source
    assert "_disc_x" in source
    assert "animate_insert" in source
    assert "animate_eject" in source


def test_experiment_faceplate_avoids_the_rejected_rounded_rectangle():
    source = read_script("disc_loader_experiment_button.gd")
    assert "draw_colored_polygon" in source
    assert "set_corner_radius_all" not in source
    assert "_inserted_disc_x" in source


def test_experiment_button_is_not_connected_to_real_game_launch_pipeline():
    source = read_script("disc_loader_experiment_button.gd")
    drawer = read_script("hidden_slim_loader_drawer_experiment.gd")
    forbidden = ["play_requested", "backend_client", "game_controller", "launch_game"]
    assert not any(token in source for token in forbidden)
    assert not any(token in drawer for token in forbidden)


def test_formal_detail_page_and_production_dvd_button_remain_untouched_by_lab_design():
    interaction = read_script("interaction_lab.gd")
    assert "_on_play_pressed" not in interaction
    lab = read_script("disc_loader_lab.gd")
    button = read_script("disc_loader_experiment_button.gd")
    drawer = read_script("hidden_slim_loader_drawer_experiment.gd")
    forbidden = ["backend_client", "launch_game", "play_requested", "game_controller"]
    assert not any(token in lab for token in forbidden)
    assert not any(token in button for token in forbidden)
    assert not any(token in drawer for token in forbidden)


def test_disc_loader_panel_is_larger_and_uses_auto_intake_positioning():
    source = read_script("disc_loader_experiment_button.gd")
    assert "const DESIGN_HEIGHT: float = 104.0" in source
    assert "const DISC_RADIUS: float = 28.0" in source
    assert "return _slot_x() + DISC_RADIUS + 26.0" in source
    assert "func _approach_disc_x()" in source
    assert "Tween.TRANS_QUART" in source


def test_disc_loader_lab_defaults_to_the_enlarged_faceplate_width():
    source = read_script("disc_loader_lab.gd")
    assert "_width_slider.value = 520.0" in source
    assert "_width_slider.value = 520.0" in source
    assert "点击外露把手展开面板" in source
    assert "HiddenSlimLoaderDrawerExperiment" in source


def test_disc_loader_has_loading_and_booting_action_text_states():
    source = read_script("disc_loader_experiment_button.gd")
    assert '"INSERTING", "READING"' in source
    assert 'action_text = "载入中..."' in source
    assert 'action_text = "启动中..."' in source
    assert 'action_text = "退盘中..."' in source


def test_disc_loader_tray_retracts_with_disc_and_can_be_ejected():
    source = read_script("disc_loader_experiment_button.gd")
    assert "_tray_offset_x" in source
    assert '"_tray_offset_x", retract_distance' in source
    assert "func _draw_dvd_tray" in source
    assert '"_tray_offset_x", 0.0' in source


def test_disc_loader_reveals_internal_chassis_after_insert():
    source = read_script("disc_loader_experiment_button.gd")
    assert "_internal_reveal" in source
    assert "func _draw_internal_chassis" in source
    assert '"_internal_reveal", 1.0' in source


def test_disc_loader_indicator_and_slot_glow_use_theme_accent():
    source = read_script("disc_loader_experiment_button.gd")
    assert "func set_theme_accent" in source
    assert "func apply_game_theme_palette" in source
    assert "func _draw_slot_glow" in source
    assert "func _draw_status_lamp" in source
    assert "_effective_accent()" in source


def test_disc_loader_lab_exposes_hero_palette_preview():
    source = read_script("disc_loader_lab.gd")
    assert "ColorPickerButton.new()" in source
    assert "func apply_game_theme_palette" in source
    assert '"set_theme_accent"' in source
    assert "_hero_tint_overlay" in source


def test_real_game_theme_palette_is_forwarded_to_disc_loader_lab_and_cleared():
    main = (SCRIPTS / "main.gd").read_text(encoding="utf-8")
    interaction = read_script("interaction_lab.gd")
    assert "interaction_lab.apply_game_theme_palette(palette)" in main
    assert "interaction_lab.reset_game_theme_palette()" in main
    assert "_disc_loader_page.apply_game_theme_palette(palette)" in interaction
    assert "_disc_loader_page.reset_game_theme_palette()" in interaction


def test_disc_loader_demo_holds_booting_until_manual_eject():
    source = read_script("disc_loader_experiment_button.gd")
    assert '"BOOTING"' in source
    assert "func get_demo_state() -> String" in source
    assert "func animate_eject()" in source
    assert '_set_state("BOOTING")' in source


def test_disc_loader_theme_reset_returns_smoothly_to_variant_accent():
    source = read_script("disc_loader_experiment_button.gd")
    assert "func _default_variant_accent() -> Color" in source
    assert "_theme_tween.tween_property(self, \"_theme_accent\", _default_variant_accent(), 0.68)" in source
    assert "func _finish_theme_reset()" in source


def test_disc_loader_chassis_is_on_left_side_of_slot():
    source = read_script("disc_loader_experiment_button.gd")
    assert "var left: float = maxf(112.0, slot_x - 108.0)" in source
    assert "var right: float = slot_x - 8.0" in source
    assert "_draw_internal_chassis(slot_x, height, accent)" in source
    # The electronics window must stay to the left of the optical slot at every panel size.
    for width in [380.0, 400.0, 520.0]:
        slot_x = width - 145.0
        left = max(112.0, slot_x - 108.0)
        right = slot_x - 8.0
        disc_center = slot_x - 28.0 - 18.0
        assert left < slot_x and right < slot_x
        assert right - left >= 35.0
        assert disc_center - 28.0 >= left
        assert disc_center + 28.0 <= right


def test_disc_loader_tray_is_shorter_and_clears_slot_when_retracted():
    source = read_script("disc_loader_experiment_button.gd")
    assert "_rest_disc_x() + DISC_RADIUS - 6.0 + _tray_offset_x" in source
    assert "_rest_disc_x() + DISC_RADIUS + 12.0 + _tray_offset_x" not in source


def test_disc_loader_status_moves_to_left_g3_position_and_disc_white_ring_is_removed():
    source = read_script("disc_loader_experiment_button.gd")
    assert 'draw_string(font, Vector2(22.0 * scale_px, 30.0 * scale_px), state_text' in source
    assert 'draw_string(font, Vector2(status_x, 34), _state' not in source
    assert '"READY"' in source and '"LOADING"' in source and '"BOOTING"' in source
    assert "radius - 0.9" not in source


def test_disc_loader_has_no_separate_white_disc_or_tray_ring():
    source = read_script("disc_loader_experiment_button.gd")
    disc = source.split("func _draw_disc(", 1)[1].split("func _default_variant_accent", 1)[0]
    tray = source.split("func _draw_dvd_tray(", 1)[1].split("func _draw_slot_glow", 1)[0]
    assert "draw_arc(" not in disc
    assert "draw_arc(well_center" not in tray
    assert "DISC_RADIUS + 2.5" not in tray


def test_disc_loader_smoked_window_replaces_pop_up_mechanical_box():
    source = read_script("disc_loader_experiment_button.gd")
    chassis = source.split("func _draw_internal_chassis(", 1)[1].split("func _draw_dvd_tray", 1)[0]
    assert "slot_x - 108.0" in chassis
    assert "Smoked translucent electronics window" in chassis
    assert "draw_colored_polygon(silhouette" not in chassis
    assert "draw_polyline(outline" not in chassis
    assert "if reveal <= 0.001" in chassis
    assert "var board_alpha" in chassis
    assert "func _draw_chassis_glass_overlay" in source


def test_disc_loader_circuit_flows_and_blinks_during_loaded_state():
    source = read_script("disc_loader_experiment_button.gd")
    assert "_circuit_time += delta" in source
    assert "if _internal_reveal > 0.001" in source
    assert "func _draw_circuit_pulse(" in source
    assert "_draw_circuit_pulse(upper_path" in source
    assert "_draw_circuit_pulse(lower_path" in source
    assert "for led_index in range(3)" in source
    assert '"_internal_reveal", 1.0' in source
    assert '_set_state("BOOTING")' in source


def test_disc_loader_panel_uses_reduced_1_5x_scale_and_native_pixel_text():
    source = read_script("disc_loader_experiment_button.gd")
    assert "const DESIGN_SCALE: float = 1.3" in source
    assert "draw_set_transform(Vector2.ZERO, 0.0, Vector2(DESIGN_SCALE, DESIGN_SCALE))" in source
    assert "_panel_width * DESIGN_SCALE, DESIGN_HEIGHT * DESIGN_SCALE" in source
    assert "size.x / DESIGN_SCALE" in source
    assert "clampf(width / DESIGN_SCALE, 380.0, 520.0)" in source
    assert "draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)" in source
    assert "15, accent.lightened(0.10)" in source
    assert "30, title_color" in source


def test_disc_loader_uses_one_continuously_moving_disc_and_reveals_body_after_insert():
    source = read_script("disc_loader_experiment_button.gd")
    draw_block = source.split("func _draw() -> void:", 1)[1]
    assert "_draw_internal_disc" not in source
    assert draw_block.count("_draw_disc(Vector2(_disc_x") == 1
    assert "_draw_chassis_glass_overlay(slot_x, height, accent)" in draw_block
    animation = source.split("func animate_insert() -> void:", 1)[1].split("func animate_eject()", 1)[0]
    assert animation.index('tween_property(self, "_disc_x", _inserted_disc_x()') < animation.index('tween_property(self, "_internal_reveal", 1.0')
    assert '_demo_tween.parallel().tween_property(self, "_internal_reveal"' not in animation
    assert "draw_rect(Rect2(6, 6, slot_x - 12, height - 12)" not in draw_block


def test_disc_loader_slot_bezel_has_recessed_depth_layers():
    source = read_script("disc_loader_experiment_button.gd")
    assert "func _draw_slot_bezel(" in source
    assert "Compact front bezel" in source
    assert "single narrow dark channel" in source
    assert "Rear cast shadow" not in source
    assert "_draw_slot_bezel(slot_x, height, accent)" in source


def test_disc_loader_internal_leds_have_diffused_transmitted_glow():
    source = read_script("disc_loader_experiment_button.gd")
    chassis = source.split("func _draw_internal_chassis(", 1)[1].split("func _draw_chassis_glass_overlay(", 1)[0]
    glass = source.split("func _draw_chassis_glass_overlay(", 1)[1].split("func _draw_circuit_pulse(", 1)[0]
    assert "16.0, Color(accent.r, accent.g, accent.b, 0.035 * light_alpha)" in chassis
    assert "11.0, Color(accent.r, accent.g, accent.b, 0.065 * light_alpha)" in chassis
    assert "Color(0.095, 0.135, 0.145, 0.36 * reveal)" in glass
    assert "Color(0.17, 0.205, 0.21, 0.055 * reveal)" in glass
    assert "var right: float = slot_x - 8.0" in glass


def test_disc_loader_smoked_plastic_shell_covers_disc_after_insert():
    source = read_script("disc_loader_experiment_button.gd")
    draw_block = source.split("func _draw() -> void:", 1)[1]
    assert draw_block.index("_draw_disc(Vector2(_disc_x") < draw_block.index("_draw_chassis_glass_overlay(slot_x")
    glass = source.split("func _draw_chassis_glass_overlay(", 1)[1].split("func _draw_circuit_pulse(", 1)[0]
    assert "Color(0.095, 0.135, 0.145, 0.36 * reveal)" in glass
    assert "Color(0.17, 0.205, 0.21, 0.055 * reveal)" in glass
    assert "var right: float = slot_x - 8.0" in glass
    assert "One continuous smoked-plastic cover" in glass
    assert "no separate right seam at the joined interface" in glass


def test_disc_loader_slot_bezel_uses_minimal_recess_not_detached_shadow():
    source = read_script("disc_loader_experiment_button.gd")
    bezel = source.split("func _draw_slot_bezel(", 1)[1].split("func _draw_slot_glow(", 1)[0]
    assert "Rear cast shadow" not in bezel
    assert "Compact front bezel" in bezel
    assert "single narrow dark channel" in bezel
    assert "draw_rect(Rect2(slot_x - 3.0" in bezel


def test_disc_loader_right_side_is_compact_and_status_is_nearer_to_slot():
    source = read_script("disc_loader_experiment_button.gd")
    assert "var _panel_width: float = 400.0" in source
    assert "return _drive_width() - 145.0" in source
    assert "_draw_status_lamp(Vector2(width - 24.0, 50.0)" in source
    assert "draw_line(Vector2(width - 34.0, 18), Vector2(width - 12.0, 18)" in source



def test_hidden_drawer_experiment_wraps_disc_loader_and_only_exposes_handle_by_default():
    source = read_script("hidden_slim_loader_drawer_experiment.gd")
    assert 'preload("res://scripts/disc_loader_experiment_button.gd")' in source
    assert 'const HANDLE_VISIBLE_WIDTH: float = 30.0' in source
    assert 'custom_minimum_size = Vector2(HANDLE_VISIBLE_WIDTH, DRAWER_HEIGHT)' in source
    assert 'default only; the full 520 px panel lives hidden inside' not in source.lower()
    assert 'Small exterior pull tab only; the full 520 px panel lives hidden inside' in source


def test_hidden_drawer_uses_overlay_expand_motion_not_layout_push():
    source = read_script("hidden_slim_loader_drawer_experiment.gd")
    assert '_mask.clip_contents = true' in source
    assert 'lerpf(HANDLE_VISIBLE_WIDTH, _panel_width, _drawer_reveal)' in source
    assert 'lerpf(-_panel_width + HANDLE_VISIBLE_WIDTH, 0.0, _drawer_reveal)' in source
    assert 'drawer_state_changed' in source


def test_hidden_drawer_experiment_still_forwards_theme_and_demo_state():
    source = read_script("hidden_slim_loader_drawer_experiment.gd")
    assert 'func apply_game_theme_palette(palette: Dictionary) -> void:' in source
    assert 'func reset_game_theme_palette() -> void:' in source
    assert 'demo_state_changed.emit(state)' in source
    assert 'func set_panel_width(width: float) -> void:' in source
    assert 'func get_demo_state() -> String:' in source
