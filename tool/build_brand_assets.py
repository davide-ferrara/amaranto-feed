#!/usr/bin/env python3
"""Package the generated master into platform icon and splash sizes.

Run from the repo root: python tool/build_brand_assets.py
Requires Pillow. This only trims transparent margins, scales, and adds padding;
the source artwork remains untouched.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'assets/branding'
BACKGROUND = '#F5F1F0'
DARK_BACKGROUND = '#20070D'
LAUNCHER_ICON_BACKGROUND = '#FFFFFF'
def load_mark(filename):
    source = Image.open(BRAND / filename).convert('RGBA')
    bounds = source.getchannel('A').point(lambda value: 255 if value > 16 else 0).getbbox()
    if bounds is None:
        raise ValueError(f'{filename} is fully transparent')
    return source.crop(bounds)


mark = load_mark('amaranto_feed_mark_source.png')


def canvas(size, mark_size, background=None, artwork=mark):
    result = Image.new('RGBA', (size, size), background or (0, 0, 0, 0))
    scaled = artwork.copy()
    scaled.thumbnail((mark_size, mark_size), Image.Resampling.LANCZOS)
    result.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
    return result if background is None else result.convert('RGB')


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


save(canvas(1024, 980), BRAND / 'amaranto_feed_mark.png')
save(canvas(1024, 760, BACKGROUND), BRAND / 'amaranto_feed_icon.png')
# The dark export is the unchanged day artwork without the light backplate.
save(canvas(1024, 760), BRAND / 'amaranto_feed_icon_dark.png')
res = ROOT / 'android/app/src/main/res'
for density, factor in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    for appearance, artwork in [('', mark), ('-night', mark)]:
        background = LAUNCHER_ICON_BACKGROUND
        save(canvas(round(48 * factor), round(36 * factor), background, artwork), res / f'mipmap{appearance}-{density}/ic_launcher.png')
        # The adaptive icon's central safe circle is 66dp in a 108dp canvas.
        save(canvas(round(108 * factor), round(52 * factor), artwork=artwork), res / f'drawable{appearance}-{density}/ic_launcher_foreground.png')
        save(canvas(round(180 * factor), round(180 * factor), artwork=artwork), res / f'drawable{appearance}-{density}/splash_logo.png')
        # Android 12 uses a 288dp canvas with a 192dp safe circle.
        save(canvas(round(288 * factor), round(152 * factor), artwork=artwork), res / f'drawable{appearance}-{density}/splash_icon.png')

icons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for spec in json.loads((icons / 'Contents.json').read_text())['images']:
    if spec.get('appearances'):
        save(canvas(1024, 760, artwork=mark), icons / spec['filename'])
        continue
    size = round(float(spec['size'].split('x')[0]) * float(spec['scale'].removesuffix('x')))
    save(canvas(size, round(size * .74), BACKGROUND), icons / spec['filename'])
launch = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for factor in [1, 2, 3]:
    suffix = '' if factor == 1 else f'@{factor}x'
    save(canvas(180 * factor, 180 * factor), launch / f'LaunchImage{suffix}.png')
    save(canvas(180 * factor, 180 * factor, artwork=mark), launch / f'LaunchImageDark{suffix}.png')
print('Packaged Amaranto Feed light/dark marks, launcher icons, and native splash images.')
