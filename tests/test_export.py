import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools/read_export.py'


def lua_export(mode):
    result = subprocess.run([shutil.which('luajit'), 'tests/emit_export.lua', mode],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(TOOL.is_file(), 'Export reconstruction tool is not implemented')
        spec = importlib.util.spec_from_file_location('read_export', TOOL)
        self.reader = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.reader)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)

    def files(self, values):
        paths = []
        for i, value in enumerate(values):
            path = self.base / f'part-{i}.json'
            path.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
            paths.append(path)
        return paths

    def test_real_lua_json_parses_with_identity_off_and_weighted_denominators(self):
        doc = lua_export('combined')
        self.assertEqual(doc['schemaVersion'], 1)
        self.assertFalse(doc['selection']['includeIdentity'])
        self.assertEqual(len(doc['characters']), 2)
        self.assertNotIn('Private', json.dumps(doc))
        rate = doc['combined']['history']['rates'][0]
        self.assertEqual((rate['hits'], rate['eligibleCompleteSources']), (2, 3))
        self.assertEqual(doc['characters'][0]['production']['recipes'][0]['quantity'], 6)
        self.assertEqual(self.reader.read_export(self.files([doc])), doc)

    def test_unicode_quotes_newlines_and_backslashes_survive_real_json_encoding(self):
        doc = lua_export('identity')
        self.assertEqual(doc['characters'][0]['identity']['name'], 'Žofie "Private"\\Realm\nLine')
        self.assertEqual(doc['characters'][0]['identity']['guid'], 'Player-private-A')

    def test_numbered_unicode_parts_reconstruct_in_any_file_order(self):
        parts = [json.loads(text) for text in lua_export('parts')]
        payload = ''.join(part['payload'] for part in parts)
        self.assertEqual(len(payload.encode('utf-8')), parts[0]['bytes'])
        self.assertEqual(f'{zlib.adler32(payload.encode("utf-8")):08x}', parts[0]['checksum'])
        doc = self.reader.read_export(list(reversed(self.files(parts))))
        self.assertEqual(doc, json.loads(payload))

    def test_copy_boundary_inside_a_multibyte_character_preserves_valid_utf8(self):
        parts = [json.loads(text) for text in lua_export('boundary')]
        self.assertEqual(parts[0]['payload'], '{"name":"')
        self.assertEqual(json.loads(''.join(part['payload'] for part in parts)), {'name': 'Žofie'})

    def test_missing_and_duplicate_parts_are_rejected(self):
        parts = [json.loads(text) for text in lua_export('parts')]
        with self.assertRaises(ValueError):
            self.reader.read_export(self.files(parts[:-1]))
        with self.assertRaises(ValueError):
            self.reader.read_export(self.files(parts + [parts[0]]))

    def test_changed_mixed_or_out_of_range_parts_are_rejected(self):
        parts = [json.loads(text) for text in lua_export('parts')]
        for field, value in [('payload', 'changed'), ('checksum', '00000000'), ('part', 0),
                             ('part', True), ('bytes', 1), ('schemaVersion', 2)]:
            candidate = [dict(part) for part in parts]
            candidate[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.reader.read_export(self.files(candidate))

    def test_invalid_json_duplicate_keys_and_future_versions_are_rejected(self):
        for text in ['{"format":"TGFv3-statistics","schemaVersion":2}',
                     '{"format":"TGFv3-statistics","schemaVersion":true}',
                     '{"format":"TGFv3-statistics","schemaVersion":1,"schemaVersion":2}',
                     '{"x":NaN}', 'incomplete {']:
            path = self.base / 'invalid.json'
            path.write_text(text)
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.reader.read_export([path])
        with self.assertRaises(ValueError):
            self.reader.parse('1e999')

    def test_cli_writes_normalized_json_and_refuses_to_overwrite(self):
        doc = lua_export('current')
        path = self.files([doc])[0]
        target = self.base / 'export.json'
        result = subprocess.run([sys.executable, str(TOOL), str(path), '--output', str(target)],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(target.read_text()), doc)
        before = target.read_bytes()
        result = subprocess.run([sys.executable, str(TOOL), str(path), '--output', str(target)],
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
