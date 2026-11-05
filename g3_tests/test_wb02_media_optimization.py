"""WB-02 regression checks for category sizing and animation preservation."""
import io
import os
from PIL import Image, ImageSequence
import pytest
from g3_core.services import sgdb_hero_optimizer as opt

@pytest.mark.parametrize('kind', ['grid', 'hero', 'logo', 'icon'])
def test_large_static_media_is_optimized(kind):
    im = Image.frombytes('RGB', (2200, 1400), os.urandom(2200 * 1400 * 3))
    buf = io.BytesIO()
    im.save(buf, format='PNG')
    data, ext, ok, original = opt.optimize_sgdb_image(buf.getvalue(), 'png', kind)
    assert ok and ext == 'webp' and original == (2200, 1400)
    with Image.open(io.BytesIO(data)) as reduced:
        assert reduced.width <= opt.MEDIA_LIMITS[kind][0][0]
        assert reduced.height <= opt.MEDIA_LIMITS[kind][0][1]


def test_animated_cover_keeps_frame_count_and_timing(monkeypatch):
    frames = [Image.new('RGBA', (80, 80), color) for color in ('red', 'green', 'blue')]
    buf = io.BytesIO()
    frames[0].save(buf, format='WEBP', save_all=True, append_images=frames[1:], duration=[100, 140, 180], loop=2, quality=100)
    monkeypatch.setitem(opt.MEDIA_LIMITS, 'grid', ((900, 1350), 1, 90))
    result, ext, changed, original = opt.optimize_sgdb_image(buf.getvalue(), 'webp', 'grid')
    assert original == (80, 80)
    assert ext == 'webp'
    with Image.open(io.BytesIO(result)) as image:
        assert image.n_frames == 3
        assert opt._webp_frame_durations(result) == [100, 140, 180]
        assert image.info['loop'] == 2
