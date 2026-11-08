import importlib.util
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class PinOutlineTests(unittest.TestCase):
    def test_generated_outlines_have_alpha_holes_and_visible_edges(self):
        path = ROOT / 'tools/generate_pin_outlines.py'
        self.assertTrue(path.is_file(), 'Outline generator is missing')
        spec = importlib.util.spec_from_file_location('pin_outlines', path)
        generator = importlib.util.module_from_spec(spec); spec.loader.exec_module(generator)
        for shape in ('Circle', 'Square'):
            raw = generator.outline(shape)
            self.assertEqual(raw[:3], b'\x00\x00\x02')
            width, height = struct.unpack_from('<HH', raw, 12)
            self.assertEqual((width, height, raw[16]), (64, 64, 32))
            alpha = lambda x, y: raw[18 + (y * width + x) * 4 + 3]
            self.assertEqual(alpha(32, 32), 0, 'Outline center must be fully transparent')
            self.assertEqual(alpha(0, 0), 0)
            self.assertGreater(alpha(32, 2), 0)
            self.assertEqual(raw, (ROOT / 'TitanGatheredForeverV3/Artwork' / ('PinOutline' + shape + '.tga')).read_bytes())
