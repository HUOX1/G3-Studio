"""Read-only offline Hero palette inspector. Run through Inspect-G3ThemePalette.bat."""
from __future__ import annotations

import argparse
import base64
from collections import Counter
from html import escape
from io import BytesIO
from pathlib import Path
import sys
import webbrowser

from PIL import Image, ImageOps
from g3_core.services.game_theme import GameThemeService


def preview_and_clusters(image_path: Path):
    with Image.open(image_path) as source:
        rgb = ImageOps.exif_transpose(source).convert('RGBA')
        thumb = rgb.copy()
        thumb.thumbnail((1200, 640), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        thumb.convert('RGB').save(buffer, format='JPEG', quality=84)
        preview = 'data:image/jpeg;base64,' + base64.b64encode(buffer.getvalue()).decode('ascii')
        rgb.thumbnail((240, 160), Image.Resampling.LANCZOS)
        counter: Counter[tuple[int, int, int]] = Counter()
        total = 0
        for r, g, b, a in rgb.getdata():
            if a < 96:
                continue
            # Quantized RGB clusters are descriptive; distinct from the game's hue-weighted extractor.
            key = ((r // 32) * 32 + 16, (g // 32) * 32 + 16, (b // 32) * 32 + 16)
            counter[key] += 1
            total += 1
        clusters = counter.most_common(10)
        return preview, [(('#%02X%02X%02X' % rgb), round(n * 100 / total, 1)) for rgb, n in clusters] if total else []


def report(hero: Path, output: Path, cache_root: Path) -> None:
    if not hero.is_file():
        raise FileNotFoundError(hero)
    svc = GameThemeService(cache_root)
    palette = svc.get_palette(hero)
    colors = palette.get('colors', {})
    picture, clusters = preview_and_clusters(hero)
    original_rows = ''.join(f'<div class="swatch"><i style="background:{color}"></i><b>{color}</b><small>{pct:.1f}% pixels</small></div>' for color, pct in clusters)
    mapped = ''.join(f'<div class="swatch"><i style="background:{escape(str(value))}"></i><b>{escape(role)}</b><small>{escape(str(value))}</small></div>' for role, value in colors.items())
    accent = colors.get('accent', '#8196AA')
    ambient = colors.get('ambient', '#242D39')
    surface = colors.get('surface', '#292F3A')
    # This is a role-color comparison, not a pixel-perfect recreation of the Godot shader.
    markup = '''<!doctype html><html lang="zh"><meta charset="utf-8"><title>G3 Hero Palette Inspector</title><style>
:root{font-family:system-ui,'Microsoft YaHei',sans-serif;color:#e6ebef;background:#10171d}body{max-width:1180px;margin:auto;padding:24px}h1{font-size:23px}h2{font-size:17px;margin-top:32px}p,small{color:#aebac4}img{width:100%;max-height:480px;object-fit:contain;background:#090f15;border-radius:8px}.swatches{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:12px}.swatch{background:#1a252d;border:1px solid #35414b;padding:8px;border-radius:7px;display:grid;gap:6px;font-size:12px}.swatch i{height:64px;border-radius:5px}.swatch small{font-size:11px}.preview{border:1px solid #3b4c5b;border-radius:9px;padding:20px;background:linear-gradient(135deg,ACCENT,AMBIENT 70%,SURFACE);color:#fff}.preview span{background:#071018d9;padding:8px 12px;border-radius:5px}.meta{overflow-wrap:anywhere;font-size:13px}</style>
<h1>G3 · Hero 调色板诊断</h1><p class="meta">取色图片：PATH</p><img src="PICTURE" alt="Hero 原图"/>
<h2>① 原图常见颜色（RGB 量化，占有效像素的比例）</h2><div class="swatches">CLUSTERS</div><p>注：这些比例是量化 RGB 颜色簇的像素占比，不是 G3 色相加权算法的选择权重，也不是精确的感知主色占比。</p>
<h2>② G3 实际调色板（真实服务 API / 可命中缓存）</h2><div class="swatches">COLORS</div><p class="meta">取色状态：STATUS；算法：METHOD；采样像素：COUNT</p>
<h2>③ UI 语义色直观对照</h2><div class="preview"><span>这是使用 Accent / Ambient / Surface 渐变的语义色示意，不代表 Godot 实际屏幕像素或完整 Shader 合成结果。</span></div>
<p>本工具不会修改 Hero、缓存记录或 G3 的界面配色。要验证真实 UI 合成结果，请结合 G3 实机截图。</p></html>'''
    for key, value in {'PATH': escape(str(hero)), 'PICTURE': picture, 'CLUSTERS': original_rows, 'COLORS': mapped, 'ACCENT': accent, 'AMBIENT': ambient, 'SURFACE': surface, 'STATUS': escape(str(palette.get('status'))), 'METHOD': escape(str(palette.get('method'))), 'COUNT': escape(str(palette.get('sampled_pixels')))}.items():
        markup = markup.replace(key, value)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(markup, encoding='utf-8')
    print('Report:', output)
    webbrowser.open(output.resolve().as_uri())


def main() -> int:
    parser = argparse.ArgumentParser(description='Inspect G3 Hero image palette in a local browser')
    parser.add_argument('hero', type=Path, help='Actual backdrop.png / cover.png path')
    parser.add_argument('--output', type=Path, default=Path('g3_theme_palette_report.html'))
    parser.add_argument('--cache-root', type=Path, default=Path.home() / 'AppData/Local/G3')
    args = parser.parse_args()
    report(args.hero.expanduser().resolve(), args.output, args.cache_root)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print('Inspection failed:', exc, file=sys.stderr)
        sys.exit(1)
