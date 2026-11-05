"""试验场占位清理与动态 WebP 首帧兜底的源码合约测试。"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TrialPlaceholderWebPContract(unittest.TestCase):
    def test_trial_section_keeps_navigation_but_does_not_load_gallery_code(self):
        main = (ROOT / "g3_frontend/scripts/main.gd").read_text(encoding="utf-8")
        self.assertIn('const XMB_SECTION_LABELS: Array[String] = ["游戏", "电影", "试验场", "游戏藏品室", "系统"]', main)
        self.assertIn('placeholder_label.visible = section == "COMICS"', main)
        self.assertNotIn("SPATIAL_GALLERY_SCRIPT", main)
        self.assertNotIn("spatial_gallery", main)
        self.assertFalse((ROOT / "g3_frontend/scripts/spatial_gallery.gd").exists())
        self.assertFalse((ROOT / "g3_frontend/shaders/spatial_cover.gdshader").exists())
        self.assertFalse((ROOT / "g3_frontend/shaders/spatial_gallery_bg.gdshader").exists())
        self.assertFalse((ROOT / "g3_frontend/shaders/spatial_gallery_floor.gdshader").exists())

    def test_game_cover_loader_continues_after_extension_poster_failure(self):
        script = (ROOT / "g3_frontend/scripts/game_section.gd").read_text(encoding="utf-8")
        loader = script.split("func _load_animated_poster(", 1)[1].split("func _load_image_smart(", 1)[0]
        self.assertIn('"load_poster_from_file"', loader)
        self.assertIn('"load_from_file"', loader)
        self.assertIn('"get_frame_texture"', loader)
        self.assertIn("image.load_webp_from_buffer(bytes)", loader)
        self.assertIn('player.call("play")', script)
        self.assertNotIn("return ClassDB.class_call_static(&\"AnimatedImageLoader\", &\"load_poster_from_file\", path)", loader)

    def test_archive_cover_loader_has_the_same_webp_first_frame_fallback(self):
        script = (ROOT / "g3_frontend/scripts/archive_gallery.gd").read_text(encoding="utf-8")
        self.assertIn("texture = _load_cover_poster_fallback(path)", script)
        self.assertIn('"load_poster_from_file"', script)
        self.assertIn('"load_from_file"', script)
        self.assertIn("image.load_webp_from_buffer(bytes)", script)


if __name__ == "__main__":
    unittest.main()
