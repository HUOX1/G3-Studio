from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "g3_frontend" / "scripts"


def read_script(name: str) -> str:
    return (SCRIPTS / name).read_text(encoding="utf-8")


def test_production_detail_page_wraps_the_existing_slim_loader_in_a_hidden_drawer():
    detail = read_script("game_detail_view.gd")
    drawer = read_script("hidden_slim_loader_drawer.gd")
    assert 'preload("res://scripts/hidden_slim_loader_drawer.gd")' in detail
    assert '_play_drawer.set_panel_button(_play_btn)' in detail
    assert '_play_row.add_child(_play_drawer)' in detail
    assert '_play_row.add_child(_play_btn)' not in detail
    assert 'const DVD_LAUNCH_BUTTON_SCRIPT = preload("res://scripts/dvd_launch_button.gd")' in detail
    assert "const DVD_LAUNCH_BUTTON_SCRIPT = preload(\"res://scripts/dvd_launch_button.gd\")" in drawer


def test_production_drawer_keeps_only_a_handle_in_layout_and_expands_as_overlay():
    drawer = read_script("hidden_slim_loader_drawer.gd")
    assert "const BASE_PANEL_SIZE := Vector2(504.0, 120.0)" in drawer
    assert "const BASE_HANDLE_SIZE := Vector2(30.0, 72.0)" in drawer
    assert "custom_minimum_size = Vector2(_handle_size.x, _panel_size.y)" in drawer
    assert "_mask.clip_contents = true" in drawer
    assert "_mask.size = Vector2(_handle_size.x + visible_panel_width, _panel_size.y)" in drawer
    assert "_panel_root.position = Vector2(lerpf(-_panel_size.x, _handle_size.x - 4.0, _reveal), 0.0)" in drawer
    assert "_handle.position = Vector2(0.0, (_panel_size.y - _handle_size.y) * 0.5)" in drawer


def test_production_drawer_uses_a_two_stage_mechanical_motion_and_fixed_left_handle():
    drawer = read_script("hidden_slim_loader_drawer.gd")
    assert "_tween.tween_interval(0.045)" in drawer
    assert "_tween.tween_method(_set_reveal, _reveal, detent, 0.095)" in drawer
    assert "_tween.tween_method(_set_reveal, detent, 1.0, 0.285)" in drawer
    assert "_handle.position = Vector2(0.0" in drawer
    assert "_panel_root.position = Vector2(lerpf(-_panel_size.x, _handle_size.x - 4.0, _reveal), 0.0)" in drawer


def test_drawer_preserves_the_real_launch_button_api_and_blocks_hidden_clicks():
    drawer = read_script("hidden_slim_loader_drawer.gd")
    detail = read_script("game_detail_view.gd")
    assert "func animate_insert() -> Tween:" in drawer
    assert "return _button.call(\"animate_insert\") as Tween" in drawer
    assert "func animate_eject() -> Tween:" in drawer
    assert "func reset_disc() -> void:" in drawer
    assert "_button.mouse_filter = Control.MOUSE_FILTER_STOP if _expanded and not _busy and not transitioning else Control.MOUSE_FILTER_IGNORE" in drawer
    assert "var insertion: Tween = _play_btn.call(\"animate_insert\") as Tween" in detail
    assert "play_requested.emit(item_id)" in detail


def test_drawer_forwards_theme_and_closes_on_game_change():
    drawer = read_script("hidden_slim_loader_drawer.gd")
    detail = read_script("game_detail_view.gd")
    assert "func apply_game_theme_palette(palette: Dictionary) -> void:" in drawer
    assert "func reset_game_theme_palette() -> void:" in drawer
    assert '_play_drawer.call("reset_drawer", false)' in detail
    assert '_play_drawer.call("set_busy", launching)' in detail
    assert "_play_drawer.call(\"set_panel_size\", Vector2(504.0 * _ui_scale, 120.0 * _ui_scale))" in detail


def test_drawer_handle_is_an_integrated_machined_pull_tab_not_a_rounded_button():
    handle = read_script("slim_loader_drawer_handle.gd")
    assert "signal pressed" in handle
    assert "draw_colored_polygon(plate, base)" in handle
    assert "Recessed grip channel with three machined ribs" in handle
    assert "set_corner_radius_all" not in handle
    assert "func set_accent(accent: Color)" in handle
