from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_script(relative: str) -> str:
    return (ROOT / "g3_frontend" / "scripts" / relative).read_text(encoding="utf-8")


def test_production_dvd_button_uses_approved_slim_loader_at_534px():
    source = read_script("dvd_launch_button.gd")
    assert "const SLIM_LOADER: int = 1" in source
    assert "var _variant: int = SLIM_LOADER" in source
    assert "const DISPLAY_WIDTH: float = 504.0" in source
    assert "const DISPLAY_HEIGHT: float = 120.0" in source
    assert "custom_minimum_size = Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT)" in source


def test_production_dvd_button_preserves_real_launch_api_and_disc_animation():
    source = read_script("dvd_launch_button.gd")
    assert "func reset_disc() -> void:" in source
    assert "func animate_insert() -> Tween:" in source
    assert "func animate_eject() -> Tween:" in source
    assert "return _demo_tween" in source
    assert "_demo_tween.tween_callback(_begin_booting)" in source
    assert "func _finish_demo() -> void:" in source
    assert "pressed.connect(animate_insert)" not in source
    assert "reset_demo()" not in source


def test_production_dvd_button_uses_vector_rendering_at_actual_ui_scale():
    source = read_script("dvd_launch_button.gd")
    assert "func _draw_scale() -> float:" in source
    assert "minf(size.x / DESIGN_WIDTH, size.y / DESIGN_HEIGHT)" in source
    assert "var draw_scale: float = _draw_scale()" in source
    assert "var scale_px: float = draw_scale" in source


def test_production_dvd_button_keeps_continuous_disc_and_smoked_cover():
    source = read_script("dvd_launch_button.gd")
    draw_block = source.split("func _draw() -> void:", 1)[1]
    assert draw_block.index("_draw_disc(Vector2(_disc_x") < draw_block.index("_draw_chassis_glass_overlay(slot_x")
    assert "_draw_slot_bezel(slot_x, height, accent)" in draw_block
    glass = source.split("func _draw_chassis_glass_overlay(", 1)[1].split("func _draw_circuit_pulse(", 1)[0]
    assert "One continuous smoked-plastic cover" in glass
    assert "Color(0.095, 0.135, 0.145, 0.36 * reveal)" in glass


def test_detail_page_uses_534px_production_panel_and_theme_tint():
    source = (ROOT / "g3_frontend" / "scripts" / "game_detail_view.gd").read_text(encoding="utf-8")
    assert "_play_btn.custom_minimum_size = Vector2(504.0, 120.0)" in source
    assert "_play_btn.custom_minimum_size = Vector2(504.0 * _ui_scale, 120.0 * _ui_scale)" in source
    assert "_play_row.custom_minimum_size.y = 120.0 * s" in source
    assert '_play_drawer.call("apply_game_theme_palette", palette)' in source
    assert '_play_drawer.call("reset_game_theme_palette")' in source
    assert 'const SLIM_LOADER_DRAWER_SCRIPT = preload("res://scripts/hidden_slim_loader_drawer.gd")' in source
