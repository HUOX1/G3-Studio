from pathlib import Path
ROOT = Path(__file__).parents[1]
MAIN = (ROOT / "g3_frontend/scripts/main.gd").read_text(encoding="utf-8")
GAME_SECTION = (ROOT / "g3_frontend/scripts/game_section.gd").read_text(encoding="utf-8")


def test_games_card_layout_and_interaction_constants_remain_native():
    assert "const CARD_ASPECT: float = 2.0 / 3.0" in GAME_SECTION
    assert "const HOVER_G_SCALE: float = 1.028" in GAME_SECTION
    assert "const CARD_SPRING_STIFFNESS: float = 300.0" in GAME_SECTION
    assert "const CARD_SPRING_DAMPING: float = 16.0" in GAME_SECTION


def test_games_default_visual_palette_is_fixed_without_theme_manifest():
    assert "_ui_text_color: Color = Color(0.925490, 1.0, 1.0, 1.0)" in MAIN
    assert "_ui_muted_color: Color = Color(0.560784, 0.768627, 0.796078, 1.0)" in MAIN
    assert "_ui_accent_color: Color = Color(0.223529, 0.847059, 0.772549, 1.0)" in MAIN
    assert "_ui_base_top_color: Color = Color(0.062745, 0.388235, 0.458824, 1.0)" in MAIN
    assert "theme.current" not in MAIN and "themes.list" not in MAIN
