from pathlib import Path

ROOT = Path(__file__).parents[1]
SECTION = (ROOT / "g3_frontend/scripts/game_section.gd").read_text(encoding="utf-8")


def _function(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.index(marker)
    next_func = source.find("\nfunc ", start + len(marker))
    return source[start:] if next_func < 0 else source[start:next_func]


def test_footer_uses_the_same_live_surface_color_as_the_window_menu_bar():
    build_sidebar = _function(SECTION, "_build_sidebar")
    emit_surface = _function(SECTION, "_emit_sidebar_surface_color")

    assert "_sidebar_footer_theme_overlay = ColorRect.new()" in build_sidebar
    assert build_sidebar.index("_sidebar_root.add_child(_sidebar_theme_overlay)") < build_sidebar.index(
        "_sidebar_root.add_child(_sidebar_footer_theme_overlay)"
    )
    assert "_sidebar_footer_theme_overlay.color = surface" in emit_surface
    assert "sidebar_surface_color_changed.emit(surface)" in emit_surface


def test_footer_theme_overlay_is_confined_to_footer_without_changing_list_gradient():
    build_sidebar = _function(SECTION, "_build_sidebar")
    relayout = _function(SECTION, "_relayout_sidebar")
    assert "void fragment() { COLOR = mix(top_color, bottom_color, clamp(UV.y, 0.0, 1.0)); }" in build_sidebar
    assert "_sidebar_footer_theme_overlay.offset_top = -footer_h" in relayout
    assert "_sidebar_footer_theme_overlay.offset_bottom = 0.0" in relayout
