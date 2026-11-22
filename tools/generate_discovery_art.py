#!/usr/bin/env python3
"""Render the emblem of Titan Gathered Forever: Discovery and its derived sizes.

The other addons use generated painted artwork. Discovery's emblem is drawn procedurally with Pillow, in the same family:
a dark midnight blue field, an antique gold bevel frame with clipped corners and one strong central subject (a
magnifying glass that enlarges a marked treasure map). The output is deterministic for one Pillow version and is
written to artwork/v1/TitanGatheredForever_Discovery/ (master, 1024px logo, 400px avatar, 64px preview and Icon.tga).
Run tools/generate_brand_icons.py afterwards to copy the icon into the runtime folder.
"""
import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
FOLDER = 'TitanGatheredForever_Discovery'
CANVAS = 4096          # drawn at this size, then reduced for clean edges
UNIT = CANVAS / 1000   # all coordinates below are in a 1000 x 1000 design space

GOLD_LIGHT, GOLD, GOLD_DARK, GOLD_SHADOW = (246, 205, 104), (214, 164, 58), (140, 92, 20), (72, 44, 8)
NAVY_CENTER, NAVY_EDGE = (24, 44, 86), (5, 10, 28)
PARCHMENT_LIGHT, PARCHMENT_DARK = (246, 228, 184), (196, 160, 98)
INK = (88, 52, 24)


def p(x, y):
    return (x * UNIT, y * UNIT)


def pts(points):
    return [p(x, y) for x, y in points]


def blank():
    return Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))


def gradient(top, bottom, angle=90):
    """A linear RGBA gradient over the whole canvas; angle 90 runs from top to bottom."""
    size = 256
    base = Image.new('RGB', (size, size))
    radians = math.radians(angle)
    dx, dy = math.cos(radians), math.sin(radians)
    pixels = base.load()
    for y in range(size):
        for x in range(size):
            t = ((x / (size - 1) - 0.5) * dx + (y / (size - 1) - 0.5) * dy) + 0.5
            t = max(0.0, min(1.0, t))
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return base.resize((CANVAS, CANVAS), Image.BILINEAR).convert('RGBA')


def radial(center, inner, outer, radius):
    size = 256
    image = Image.new('RGB', (size, size))
    pixels = image.load()
    cx, cy = center[0] / 1000 * size, center[1] / 1000 * size
    reach = radius / 1000 * size
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / reach)
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(inner, outer))
    return image.resize((CANVAS, CANVAS), Image.BICUBIC).convert('RGBA')


def masked(fill, mask):
    layer = blank()
    layer.paste(fill, (0, 0), mask)
    return layer


def polygon_mask(points):
    mask = Image.new('L', (CANVAS, CANVAS), 0)
    ImageDraw.Draw(mask).polygon(pts(points), fill=255)
    return mask


def shadow(mask, offset=(10, 14), blur=16, strength=150):
    layer = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    soft = mask.filter(ImageFilter.GaussianBlur(blur * UNIT))
    soft = ImageChops.offset(soft, round(offset[0] * UNIT), round(offset[1] * UNIT))
    layer.paste((0, 0, 0, strength), (0, 0), soft)
    return layer


def glow(center, radius, color, alpha=170):
    mask = Image.new('L', (CANVAS, CANVAS), 0)
    cx, cy = p(*center)
    r = radius * UNIT
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius * UNIT * 0.55))
    layer = blank()
    layer.paste(color + (alpha,), (0, 0), mask)
    return layer


def star(center, size, color, rotate=0):
    cx, cy = center
    points = []
    for index in range(8):
        radius = size if index % 2 == 0 else size * 0.22
        angle = math.radians(index * 45 + rotate - 90)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    mask = polygon_mask(points)
    layer = masked(Image.new('RGBA', (CANVAS, CANVAS), color + (255,)), mask)
    return Image.alpha_composite(glow(center, size * 0.9, color, 120), layer)


def background(rng):
    image = radial((500, 470), NAVY_CENTER, NAVY_EDGE, 760)
    draw = ImageDraw.Draw(image)
    for _ in range(70):
        x, y, r = rng.uniform(60, 940), rng.uniform(60, 940), rng.uniform(0.8, 2.6)
        a = rng.randint(40, 120)
        cx, cy = p(x, y)
        draw.ellipse([cx - r * UNIT, cy - r * UNIT, cx + r * UNIT, cy + r * UNIT], fill=(170, 200, 255, a))
    return image


def frame():
    """The gold bevel frame with clipped corners, inset a little from the edge like the other emblems."""
    def shape(inset, cut):
        lo, hi = 38 + inset, 962 - inset
        return [(lo + cut, lo), (hi - cut, lo), (hi, lo + cut), (hi, hi - cut), (hi - cut, hi), (lo + cut, hi), (lo, hi - cut), (lo, lo + cut)]
    outer, inner = shape(0, 52), shape(30, 36)
    ring = ImageChops.subtract(polygon_mask(outer), polygon_mask(inner))
    layer = masked(gradient(GOLD_LIGHT, GOLD_DARK, 60), ring)
    bevel_in = ImageChops.subtract(polygon_mask(shape(7, 49)), polygon_mask(shape(24, 40)))
    layer = Image.alpha_composite(layer, masked(gradient(GOLD, GOLD_LIGHT, 120), bevel_in).filter(ImageFilter.GaussianBlur(1.2 * UNIT)))
    edge = Image.new('L', (CANVAS, CANVAS), 0)
    draw = ImageDraw.Draw(edge)
    draw.line(pts(outer + [outer[0]]), fill=255, width=round(3 * UNIT))
    draw.line(pts(inner + [inner[0]]), fill=255, width=round(3 * UNIT))
    layer = Image.alpha_composite(layer, masked(Image.new('RGBA', (CANVAS, CANVAS), GOLD_SHADOW + (255,)), edge))
    # corner studs
    studs = blank()
    sd = ImageDraw.Draw(studs)
    for x, y in ((98, 98), (902, 98), (98, 902), (902, 902)):
        cx, cy = p(x, y)
        r = 15 * UNIT
        sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_DARK + (255,))
        r = 11 * UNIT
        sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_LIGHT + (255,))
    return Image.alpha_composite(layer, studs), inner


def rotate_points(points, center, degrees):
    angle = math.radians(degrees)
    cx, cy = center
    return [(cx + (x - cx) * math.cos(angle) - (y - cy) * math.sin(angle),
             cy + (x - cx) * math.sin(angle) + (y - cy) * math.cos(angle)) for x, y in points]


def bezier(a, b, c, d, steps=60):
    result = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        result.append((u**3 * a[0] + 3 * u * u * t * b[0] + 3 * u * t * t * c[0] + t**3 * d[0],
                       u**3 * a[1] + 3 * u * u * t * b[1] + 3 * u * t * t * c[1] + t**3 * d[1]))
    return result


def parchment(rng):
    """A tilted treasure map: torn edge, a dotted route, small peaks and a red X."""
    corners = [(190, 300), (810, 270), (830, 800), (170, 830)]
    jagged = []
    for index, (x, y) in enumerate(corners):
        nx, ny = corners[(index + 1) % 4]
        for step in range(12):
            t = step / 12
            jagged.append((x + (nx - x) * t + rng.uniform(-4, 4), y + (ny - y) * t + rng.uniform(-4, 4)))
    jagged = rotate_points(jagged, (500, 550), -7)
    mask = polygon_mask(jagged)
    body = masked(gradient(PARCHMENT_LIGHT, PARCHMENT_DARK, 70), mask)
    inner = mask.filter(ImageFilter.GaussianBlur(14 * UNIT))
    vignette = ImageChops.subtract(mask, ImageChops.multiply(inner, mask).point(lambda v: min(255, v * 2)))
    body = Image.alpha_composite(body, masked(Image.new('RGBA', (CANVAS, CANVAS), (120, 78, 30, 200)), vignette))
    draw = ImageDraw.Draw(body)
    def at(x, y):
        return rotate_points([(x, y)], (500, 550), -7)[0]
    for x, y, scale in ((300, 700, 1.0), (360, 720, 0.7), (470, 385, 1.0), (405, 405, 0.7), (700, 640, 0.9)):
        peak = [at(x - 40 * scale, y + 28 * scale), at(x, y - 34 * scale), at(x + 40 * scale, y + 28 * scale)]
        draw.polygon(pts(peak), fill=(150, 110, 60, 255), outline=INK + (255,))
        draw.line(pts([peak[1], at(x + 6 * scale, y + 28 * scale)]), fill=INK + (255,), width=round(2 * UNIT))
    route = bezier(at(270, 760), at(290, 560), at(470, 690), at(500, 560))
    route += bezier(at(500, 560), at(520, 480), at(560, 500), at(600, 425))[1:]
    for index, (x, y) in enumerate(route):
        if index % 4 == 0:
            cx, cy = p(x, y)
            r = 5.5 * UNIT
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK + (255,))
    for x, y in (at(270, 760),):
        cx, cy = p(x, y)
        r = 13 * UNIT
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK + (255,), width=round(4 * UNIT))
    mark = p(*at(600, 425))
    arm = 20 * UNIT
    for sign in (1, -1):
        draw.line([(mark[0] - arm, mark[1] - sign * arm), (mark[0] + arm, mark[1] + sign * arm)], fill=(176, 34, 34, 255), width=round(9 * UNIT))
    return body, mask


def magnifier(under):
    """The lens at (545, 455), handle to the lower right. The lens shows `under` enlarged."""
    center, outer_r, inner_r = (545, 455), 205, 168
    angle = math.radians(48)
    direction = (math.cos(angle), math.sin(angle))
    start = (center[0] + direction[0] * outer_r * 0.92, center[1] + direction[1] * outer_r * 0.92)
    end = (center[0] + direction[0] * 470, center[1] + direction[1] * 470)
    normal = (-direction[1], direction[0])

    def band(a, b, width):
        return [(a[0] + normal[0] * width, a[1] + normal[1] * width), (b[0] + normal[0] * width, b[1] + normal[1] * width),
                (b[0] - normal[0] * width, b[1] - normal[1] * width), (a[0] - normal[0] * width, a[1] - normal[1] * width)]

    handle_mask = polygon_mask(band(start, end, 27))
    handle = masked(gradient((150, 98, 46), (74, 42, 16), 0), handle_mask)
    grain = ImageDraw.Draw(handle)
    for offset in (-14, -4, 8, 17):
        a = (start[0] + normal[0] * offset + direction[0] * 40, start[1] + normal[1] * offset + direction[1] * 40)
        b = (end[0] + normal[0] * offset - direction[0] * 20, end[1] + normal[1] * offset - direction[1] * 20)
        grain.line(pts([a, b]), fill=(60, 34, 12, 150), width=round(2.2 * UNIT))
    for lo, hi in ((0.0, 0.1), (0.9, 1.0)):
        a = (start[0] + (end[0] - start[0]) * lo, start[1] + (end[1] - start[1]) * lo)
        b = (start[0] + (end[0] - start[0]) * hi, start[1] + (end[1] - start[1]) * hi)
        cap = polygon_mask(band(a, b, 31))
        handle = Image.alpha_composite(handle, masked(gradient(GOLD_LIGHT, GOLD_DARK, 40), cap))
    pommel_center = (end[0] + direction[0] * 14, end[1] + direction[1] * 14)

    lens_mask = Image.new('L', (CANVAS, CANVAS), 0)
    cx, cy = p(*center)
    ImageDraw.Draw(lens_mask).ellipse([cx - inner_r * UNIT, cy - inner_r * UNIT, cx + inner_r * UNIT, cy + inner_r * UNIT], fill=255)
    zoom = 1.55
    crop_size = round(inner_r * 2 * UNIT / zoom)
    box = (round(cx - crop_size / 2), round(cy - crop_size / 2), round(cx + crop_size / 2), round(cy + crop_size / 2))
    enlarged = under.crop(box).resize((round(inner_r * 2 * UNIT),) * 2, Image.LANCZOS)
    lens = blank()
    lens.paste(enlarged, (round(cx - inner_r * UNIT), round(cy - inner_r * UNIT)))
    lens = masked(lens, lens_mask)
    tint = masked(Image.new('RGBA', (CANVAS, CANVAS), (120, 215, 255, 26)), lens_mask)
    lens = Image.alpha_composite(lens, tint)
    sheen = Image.new('L', (CANVAS, CANVAS), 0)
    sd = ImageDraw.Draw(sheen)
    reach = inner_r * 0.84
    sd.arc([cx - reach * UNIT, cy - reach * UNIT, cx + reach * UNIT, cy + reach * UNIT], 198, 252, fill=255, width=round(13 * UNIT))
    sd.ellipse([cx - reach * 0.74 * UNIT - 9 * UNIT, cy - reach * 0.52 * UNIT - 9 * UNIT, cx - reach * 0.74 * UNIT + 9 * UNIT, cy - reach * 0.52 * UNIT + 9 * UNIT], fill=255)
    sheen = ImageChops.multiply(sheen.filter(ImageFilter.GaussianBlur(3 * UNIT)), lens_mask)
    lens = Image.alpha_composite(lens, masked(Image.new('RGBA', (CANVAS, CANVAS), (255, 255, 255, 170)), sheen))

    ring_mask = Image.new('L', (CANVAS, CANVAS), 0)
    rd = ImageDraw.Draw(ring_mask)
    rd.ellipse([cx - outer_r * UNIT, cy - outer_r * UNIT, cx + outer_r * UNIT, cy + outer_r * UNIT], fill=255)
    rd.ellipse([cx - inner_r * UNIT, cy - inner_r * UNIT, cx + inner_r * UNIT, cy + inner_r * UNIT], fill=0)
    ring = masked(gradient(GOLD_LIGHT, GOLD_DARK, 50), ring_mask)
    ring_edge = ImageChops.subtract(ring_mask, ring_mask.filter(ImageFilter.MinFilter(2 * round(3 * UNIT) + 1)))
    ring = Image.alpha_composite(ring, masked(Image.new('RGBA', (CANVAS, CANVAS), GOLD_SHADOW + (200,)), ring_edge))
    highlight = Image.new('L', (CANVAS, CANVAS), 0)
    hd = ImageDraw.Draw(highlight)
    mid = (outer_r + inner_r) / 2
    hd.arc([cx - mid * UNIT, cy - mid * UNIT, cx + mid * UNIT, cy + mid * UNIT], 195, 275, fill=255, width=round(9 * UNIT))
    ring = Image.alpha_composite(ring, masked(Image.new('RGBA', (CANVAS, CANVAS), (255, 244, 200, 230)),
                                              highlight.filter(ImageFilter.GaussianBlur(2 * UNIT))))

    pommel = blank()
    px, py = p(*pommel_center)
    ImageDraw.Draw(pommel).ellipse([px - 34 * UNIT, py - 34 * UNIT, px + 34 * UNIT, py + 34 * UNIT], fill=GOLD + (255,))
    pommel = Image.alpha_composite(pommel, glow((0, 0), 1, GOLD_LIGHT, 0))
    whole_mask = ImageChops.lighter(ImageChops.lighter(handle_mask, ring_mask), pommel.split()[3])
    whole_mask = ImageChops.lighter(whole_mask, lens_mask)
    parts = Image.alpha_composite(Image.alpha_composite(Image.alpha_composite(shadow(whole_mask, (14, 20), 18, 170), handle), pommel), lens)
    return Image.alpha_composite(parts, ring)


def render():
    rng = random.Random(2026)
    canvas = background(rng)
    canvas = Image.alpha_composite(canvas, glow((545, 455), 330, (60, 190, 255), 90))
    map_body, map_mask = parchment(rng)
    under = Image.alpha_composite(shadow(map_mask, (12, 18), 20, 190), map_body)
    canvas = Image.alpha_composite(canvas, under)
    canvas = Image.alpha_composite(canvas, magnifier(Image.alpha_composite(background(random.Random(2026)), under)))
    for center, size, color in (((760, 190), 58, (190, 240, 255)), ((300, 210), 34, (255, 232, 160)), ((835, 330), 24, (190, 240, 255)),
                                ((240, 380), 20, (255, 232, 160))):
        canvas = Image.alpha_composite(canvas, star(center, size, color))
    framed, _ = frame()
    return Image.alpha_composite(canvas, framed).convert('RGBA')


def tga(image):
    out = image.convert('RGBA')
    return out


def write(output):
    master = render().resize((2048, 2048), Image.LANCZOS)
    output.mkdir(parents=True, exist_ok=True)
    master.save(output / 'master.png', optimize=True)
    master.resize((1024, 1024), Image.LANCZOS).save(output / 'logo-1024.png', optimize=True)
    master.resize((400, 400), Image.LANCZOS).save(output / 'avatar-400.png', optimize=True)
    small = master.resize((64, 64), Image.LANCZOS)
    small.save(output / 'icon-64.png', optimize=True)
    small.save(output / 'Icon.tga')   # uncompressed 32-bit, top-left origin, like the other icons


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'artwork/v1' / FOLDER)
    args = parser.parse_args()
    write(args.output)
    print(f'Wrote the emblem files to {args.output}')
