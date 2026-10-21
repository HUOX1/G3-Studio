"""Native animation support must not be required to parse the G3 frontend."""
from pathlib import Path
import re
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / 'g3_frontend/scripts'


class OptionalAnimationContract(unittest.TestCase):
    def test_gallery_games_and_detail_do_not_reference_native_classes_directly(self):
        for name in ('archive_gallery.gd', 'game_section.gd', 'game_detail_view.gd'):
            with self.subTest(name=name):
                source = (SCRIPTS / name).read_text(encoding='utf-8')
                self.assertIsNone(re.search(r'(?<!["\'])\bAnimatedImage(?:Player|Loader)\s*\.', source))
                self.assertNotRegex(source, r':\s*AnimatedImagePlayer\b|as\s+AnimatedImagePlayer\b')

    def test_extension_calls_are_gated(self):
        for name in ('archive_gallery.gd', 'game_section.gd', 'game_detail_view.gd'):
            with self.subTest(name=name):
                source = (SCRIPTS / name).read_text(encoding='utf-8')
                self.assertIn('ClassDB.class_exists(&"AnimatedImageLoader")', source)
        source = (SCRIPTS / 'game_section.gd').read_text(encoding='utf-8')
        self.assertIn('ClassDB.class_exists(&"AnimatedImagePlayer")', source)


if __name__ == '__main__':
    unittest.main()
