#!/usr/bin/env python3
"""Generate every HumSukhan brand raster from one vector definition.

Run from the repository root:  python3 tool/generate_brand_assets.py

The mark is a quill inside a speech bubble with a three-dot ellipsis, drawn as a
cream silhouette. It is defined once, in normalised (0..1) coordinates, so the
launcher icon, the adaptive-icon layers and the in-app badge can never drift
apart. `assets/images/icon_mark.png` carries adaptive-icon safe-zone padding
(72/108 of the canvas); `BrandLogo` reverses that framing by scaling 108/72.
"""

import json
import math
import os
from PIL import Image, ImageDraw

BRAND_GREEN = (0x53, 0x69, 0x5B, 255)
CREAM = (0xF8, 0xF0, 0xE8, 255)
WHITE = (0xFF, 0xFF, 0xFF, 255)

# Supersampling factor: everything is drawn large and downsampled for smooth edges.
SS = 4


def _rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def _leaf(base, tip, half_width):
    """Polygon points for a symmetric leaf between base and tip."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    px, py = -uy, ux
    left, right = [], []
    steps = 64
    for i in range(steps + 1):
        t = i / steps
        w = half_width * (math.sin(math.pi * t) ** 0.75)
        cx, cy = bx + dx * t, by + dy * t
        left.append((cx + px * w, cy + py * w))
        right.append((cx - px * w, cy - py * w))
    return left + list(reversed(right))


def mark_mask(size):
    """Alpha mask of the mark, drawn to fill `size` x `size` completely."""
    s = size * SS
    mask = Image.new('L', (s, s), 0)
    d = ImageDraw.Draw(mask)

    def p(x, y):
        return (x * s, y * s)

    # Speech bubble body.
    _rounded_rect(d, [p(0.04, 0.08), p(0.96, 0.755)], radius=0.19 * s, fill=255)
    # Bubble tail.
    d.polygon([p(0.26, 0.70), p(0.50, 0.70), p(0.30, 0.96)], fill=255)

    # Quill, punched out of the bubble.
    base, tip = (0.355, 0.545), (0.735, 0.185)
    d.polygon([p(x, y) for x, y in _leaf(base, tip, 0.105)], fill=0)
    # Rachis / nib: a cream vein through the feather, extending past the base.
    nib = (base[0] - 0.075, base[1] + 0.070)
    d.line([p(*nib), p(*tip)], fill=255, width=int(0.030 * s))

    # Three-dot ellipsis.
    for cx in (0.290, 0.420, 0.550):
        cy, r = 0.630, 0.052
        d.ellipse([p(cx - r, cy - r), p(cx + r, cy + r)], fill=0)

    return mask.resize((size, size), Image.LANCZOS)


def _tinted(size, colour, padded):
    """`colour` mark on transparency. `padded` applies adaptive safe-zone framing."""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = max(1, round(size * 72 / 108)) if padded else size
    mark = Image.new('RGBA', (inner, inner), colour)
    mark.putalpha(mark_mask(inner))
    offset = (size - inner) // 2
    canvas.paste(mark, (offset, offset), mark)
    return canvas


def foreground(size):
    """Adaptive-icon foreground: transparent, safe-zone padded, cream mark."""
    return _tinted(size, CREAM, padded=True)


def monochrome(size):
    """Adaptive-icon monochrome layer: themed by the launcher, so white on alpha."""
    return _tinted(size, WHITE, padded=True)


def background(size):
    return Image.new('RGBA', (size, size), BRAND_GREEN)


def composited(size, rounded=False):
    """Legacy launcher icon: the mark on brand green, no transparency."""
    base = background(size)
    base.alpha_composite(foreground(size))
    if rounded:
        mask = Image.new('L', (size * SS, size * SS), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size * SS - 1, size * SS - 1], radius=int(size * SS * 0.22), fill=255
        )
        base.putalpha(mask.resize((size, size), Image.LANCZOS))
    return base


def write(image, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print('wrote', path, image.size)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    # In-app assets.
    write(foreground(512), 'assets/images/icon_mark.png')

    # Android adaptive-icon layers, one PNG per density bucket.
    densities = {
        'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432
    }
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for bucket, px in densities.items():
        out = f'android/app/src/main/res/mipmap-{bucket}'
        write(background(px), f'{out}/ic_launcher_background.png')
        write(foreground(px), f'{out}/ic_launcher_foreground.png')
        write(monochrome(px), f'{out}/ic_launcher_monochrome.png')
        write(composited(legacy[bucket]), f'{out}/ic_launcher.png')

    # Play Store listing icon.
    write(composited(512), 'assets/images/play_store_icon.png')

    # iOS: every size declared in the asset catalogue, flattened (no alpha).
    ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    with open(f'{ios}/Contents.json') as handle:
        catalogue = json.load(handle)
    for entry in catalogue['images']:
        if 'filename' not in entry:
            continue
        side = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        px = int(round(side * scale))
        icon = composited(px).convert('RGB')
        icon.save(f'{ios}/{entry["filename"]}')
        print('wrote', entry['filename'], icon.size)


if __name__ == '__main__':
    main()
