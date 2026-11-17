#!/usr/bin/env python3
"""Repack approved 64px brand textures as uncompressed game-ready TGA files."""
import argparse
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def uncompressed_tga(raw):
    header = list(struct.unpack('<BBBHHBHHHHBB', raw[:18]))
    image_id, color_map, kind = header[:3]
    width, height, depth, descriptor = header[8:]
    if color_map or kind not in (2, 10) or (width, height) != (64, 64) or depth not in (24, 32):
        raise ValueError('Expected a true-color 64x64 TGA')
    step, offset = depth // 8, 18 + image_id
    pixels = bytearray()
    if kind == 2:
        pixels.extend(raw[offset:offset + width * height * step])
    else:
        while len(pixels) < width * height * step:
            packet = raw[offset]
            offset += 1
            count = (packet & 127) + 1
            size = step if packet & 128 else count * step
            chunk = raw[offset:offset + size]
            if len(chunk) != size:
                raise ValueError('Truncated TGA packet')
            pixels.extend(chunk * count if packet & 128 else chunk)
            offset += size
    if len(pixels) != width * height * step:
        raise ValueError('Invalid TGA pixel count')
    # Preserve orientation and pixel colors; only change encoding to 32-bit raw.
    bgra = b''.join(pixels[i:i + 3] + (pixels[i + 3:i + 4] if step == 4 else b'\xff')
                    for i in range(0, len(pixels), step))
    header[0], header[2], header[10], header[11] = 0, 2, 32, (descriptor & 48) | 8
    return struct.pack('<BBBHHBHHHHBB', *header) + bgra


def generate(root=ROOT, check=False):
    folders = ['TitanGatheredForever'] + [row['folder'] for row in
        json.loads((root / 'catalogue/modules.json').read_text())]
    for folder in folders:
        source = root / 'artwork/v1' / folder / 'Icon.tga'
        target = root / folder / 'Artwork/AddonIcon.tga'
        expected = uncompressed_tga(source.read_bytes())
        if check:
            if not target.is_file() or target.read_bytes() != expected:
                raise ValueError(f'Stale brand icon: {target}')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(expected)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    generate(check=args.check)
    print('Brand icons verified.' if args.check else 'Brand icons written.')
