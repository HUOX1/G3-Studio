"""导航抽屉光晕锚点与卡片让位策略的源码契约测试。"""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "g3_frontend" / "scripts" / "game_section.gd"


class NavDrawerGlowBoundaryContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_drawer_influence_bounds_are_explicit(self):
        self.assertIn("const NAV_DRAWER_GLOW_Y: float = 37.0", self.source)
        self.assertIn("const NAV_DRAWER_TOP_CLEARANCE: float = 18.0", self.source)
        self.assertIn("const NAV_DRAWER_BOTTOM: float = 108.0", self.source)
        self.assertIn("const NAV_DRAWER_GAP: float = 24.0", self.source)

    def test_glow_position_selects_up_or_down(self):
        self.assertIn("glow_ratio >= (2.0 / 3.0)", self.source)
        self.assertIn("glow_ratio <= (1.0 / 3.0)", self.source)
        self.assertIn("prefer_up = shift_up <= shift_down", self.source)
        self.assertIn("row_offsets[row_i] = -shift_up", self.source)

    def test_lower_cards_only_move_to_bounded_safe_edge(self):
        self.assertIn("var lower_safe_y: float = NAV_DRAWER_BOTTOM + NAV_DRAWER_GAP", self.source)
        self.assertIn("lower_safe_y - row_tops[row_i]", self.source)
        self.assertIn("up_branch_prev - gap", self.source)
        self.assertIn("down_branch_prev - gap", self.source)

    def test_scroll_content_can_fit_downward_targets(self):
        self.assertIn("_grid.custom_minimum_size.y = maxf(previous_content_height, max_target_bottom)", self.source)
        self.assertIn("_grid.custom_minimum_size.y = maxf(base_content_height, max_target_bottom)", self.source)

    def test_old_always_push_down_rule_is_gone(self):
        self.assertNotIn("if row_i == 0:", self.source)
        self.assertNotIn("d = maxf(0.0, d_prev - gap)", self.source)

    def test_influence_bounds_are_wider_without_changing_drawer_width(self):
        self.assertIn("const NAV_DRAWER_W: float = 292.0", self.source)
        self.assertIn("const NAV_DRAWER_TOP_CLEARANCE: float = 18.0", self.source)
        self.assertIn("const NAV_DRAWER_GAP: float = 24.0", self.source)
        self.assertIn("const NAV_DRAWER_LEFT_INFLUENCE: float = 48.0", self.source)
        self.assertIn("const NAV_DRAWER_LEFT_OVERLAP_ALLOWANCE: float = 48.0", self.source)

    def test_left_adjacent_card_gets_rotation_target(self):
        self.assertIn("func _compute_nav_rotation_by_col_row(", self.source)
        self.assertIn("gap_to_drawer > NAV_DRAWER_LEFT_INFLUENCE", self.source)
        self.assertIn('rotation_by_col_row["%d:%d" % [left_col, row_i]]', self.source)

    def test_rotation_uses_card_center_and_spring_velocity(self):
        self.assertIn("wrapper.pivot_offset = Vector2(cell_w * 0.5, cell_h * 0.5)", self.source)
        self.assertIn('wrapper.get_meta("target_rotation", 0.0)', self.source)
        self.assertIn('wrapper.get_meta("rotation_vel", 0.0)', self.source)
        self.assertIn("rotation_vel += rotation_delta * CARD_SPRING_STIFFNESS * jitter * delta", self.source)
        self.assertIn("wrapper.rotation += rotation_vel * delta", self.source)

    def test_rotation_direction_depends_on_drawer_relative_to_card_center(self):
        self.assertIn("var drawer_center_y: float = (NAV_DRAWER_BOTTOM - NAV_DRAWER_HEIGHT * 0.5)", self.source)
        self.assertIn("var card_center_y: float = card_top_s + cell_h * 0.5", self.source)
        self.assertIn("var direction: float = -1.0 if drawer_center_y < card_center_y else 1.0", self.source)

    def test_layout_refresh_updates_rotation_target_for_open_and_closed_states(self):
        self.assertIn('wrapper.set_meta("target_rotation", float(rotations.get(key, 0.0)))', self.source)
        self.assertIn('wrapper.set_meta("target_rotation", target_rotation)', self.source)
        self.assertIn('wrapper.rotation = target_rotation', self.source)


if __name__ == "__main__":
    unittest.main()
