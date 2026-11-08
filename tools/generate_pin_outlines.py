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


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / 'TitanGatheredForeverV3/Artwork'
    for shape in ('Circle', 'Square'):
        path = root / ('PinOutline' + shape + '.tga')
        content = outline(shape)
        if args.check:
            if not path.is_file() or path.read_bytes() != content:
                parser.exit(1, f'Stale outline: {path}\n')
        else:
            path.write_bytes(content)
