#!/usr/bin/env python3
"""Render geometric, transparent-center UI outlines as deterministic RGBA TGA assets."""
import argparse
import math
import struct
from pathlib import Path


def outline(shape):
    if shape not in ('Circle', 'Square'):
        raise ValueError('Expected Circle or Square')
    size = 64
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            hits = 0
            for sy in range(4):
                for sx in range(4):
                    dx, dy = x + (sx + .5) / 4 - 32, y + (sy + .5) / 4 - 32
                    distance = math.hypot(dx, dy) if shape == 'Circle' else max(abs(dx), abs(dy))
                    hits += 28 <= distance <= 31
            pixels.extend((255, 255, 255, round(255 * hits / 16)))
    return header + pixels


def anchor():
    """A white anchor on a transparent 64 px canvas, tinted in game by the route color."""
    size = 64
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)

    def inside(x, y):
        y -= 4    # centre the drawing on the canvas
        ring = 3.6 <= math.hypot(x - 32, y - 9) <= 6.8
        shank = 30.2 <= x <= 33.8 and 14 <= y <= 50
        stock = 22 <= x <= 42 and 18.5 <= y <= 22
        distance = math.hypot(x - 32, y - 33)
        arc = 16.5 <= distance <= 20.5 and y >= 31
        tips = any(math.hypot(x - (32 + side * 18.5), y - 31) <= 4.2 for side in (-1, 1))
        base = 28 <= x <= 36 and 49 <= y <= 53
        return ring or shank or stock or arc or tips or base

    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            hits = sum(inside(x + (sx + .5) / 4, y + (sy + .5) / 4) for sy in range(4) for sx in range(4))
            pixels.extend((255, 255, 255, round(255 * hits / 16)))
    return header + pixels


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / 'TitanGatheredForever/Artwork'
    assets = [(root / ('PinOutline' + shape + '.tga'), outline(shape)) for shape in ('Circle', 'Square')]
    assets.append((root / 'RouteAnchor.tga', anchor()))
    for path, content in assets:
        if args.check:
            if not path.is_file() or path.read_bytes() != content:
                parser.exit(1, f'Stale outline: {path}\n')
        else:
            path.write_bytes(content)
