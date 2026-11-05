from pathlib import Path

ROOT = Path(__file__).parents[1]
SECTION = (ROOT / "g3_frontend/scripts/game_section.gd").read_text(encoding="utf-8")


def _function(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.index(marker)
    next_func = source.find("\nfunc ", start + len(marker))
    return source[start:] if next_func < 0 else source[start:next_func]


def test_sidebar_long_name_overlay_is_outside_clipped_scroll_container_and_above_grid():
    build_ui = _function(SECTION, "_build_ui")
    assert build_ui.index("_build_detail()") < build_ui.index("_sidebar_tip_layer = Control.new()")
    assert "_root.add_child(_sidebar_tip_layer)" in build_ui
    assert "_sidebar_tip_layer.clip_contents = false" in build_ui
    assert "_sidebar_tip_layer.z_index = 4096" in build_ui

    make_item = _function(SECTION, "_make_sidebar_item")
    assert "_sidebar_tip_layer.add_child(tip)" in make_item


def test_sidebar_long_name_replaces_ellipsis_at_original_text_position_without_wrapping():
    update_tip = _function(SECTION, "_update_sidebar_tip")
    assert "tip_lbl.text = name_lbl.text" in update_tip
    assert "tip_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF" in update_tip
    assert "tip_minimum.x = full_w + 16.0" in update_tip
    assert "_sync_sidebar_tip_position()" in update_tip

    sync_position = _function(SECTION, "_sync_sidebar_tip_position")
    assert "_sidebar_active_tip_label.get_global_rect()" in sync_position
    assert "label_rect.position.x - 8.0" in sync_position
    assert "_sidebar_scroll.get_global_rect().intersects(label_rect)" in sync_position


def test_sidebar_long_name_overlay_tracks_scroll_and_is_freed_on_list_rebuild():
    process = _function(SECTION, "_process")
    assert "_sync_sidebar_tip_position()" in process

    rebuild = _function(SECTION, "_rebuild_sidebar")
    assert "old_tip.queue_free()" in rebuild
    assert "_sidebar_active_tip = null" in rebuild
