"""Read-only integration boundaries; see the native smoke test for behavior."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ArchiveGalleryContract(unittest.TestCase):
    def test_scene_and_shader_dependencies_exist(self):
        script = (ROOT / "g3_frontend/scripts/archive_gallery.gd").read_text(encoding="utf-8")
        for path in re.findall(r'preload\("res://([^"\n]+)"\)', script):
            self.assertTrue((ROOT / "g3_frontend" / path).is_file(), path)

    def test_existing_sections_and_backend_route_remain_connected(self):
        main = (ROOT / "g3_frontend/scripts/main.gd").read_text(encoding="utf-8")
        self.assertIn('archive_gallery.set_section_visible(section == "MUSIC")', main)
        self.assertIn('spatial_gallery.set_section_visible(section == "COMICS")', main)
        self.assertIn('archive_gallery.set_games(games)', main)
        self.assertIn('archive_gallery.game_launch_requested.connect(_on_archive_launch_requested)', main)
        handler = main.split('func _on_archive_launch_requested(', 1)[1].split('func _on_game_double_clicked(', 1)[0]
        self.assertIn('_on_game_double_clicked(game)', handler)

    def test_archive_is_read_only_and_owns_its_render_world(self):
        script = (ROOT / "g3_frontend/scripts/archive_gallery.gd").read_text(encoding="utf-8")
        self.assertIn('_viewport.own_world_3d = true', script)
        self.assertIn('SubViewport.UPDATE_DISABLED', script)
        self.assertNotIn('FileAccess.WRITE', script)
        self.assertNotIn('backend.request(', script)
        self.assertNotIn('_shared_camera.', script)

if __name__ == "__main__":
    unittest.main()
