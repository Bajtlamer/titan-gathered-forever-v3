import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = 'TitanGatheredForeverV3'
TITLE = 'Titan Gathered Forever v3'
CORE = ROOT / NAME


class BrandingTests(unittest.TestCase):
    def test_core_identity_and_all_optional_dependencies(self):
        self.assertTrue(CORE.is_dir())
        toc = (CORE / (NAME + '.toc')).read_text()
        self.assertIn('## Title: ' + TITLE + '\n', toc)
        self.assertIn('## SavedVariables: ' + NAME + 'DB\n', toc)
        modules = json.loads((ROOT / 'catalogue/modules.json').read_text())
        self.assertEqual(len(modules), 13)
        for module in modules:
            folder = module['folder']
            self.assertTrue(folder.startswith(NAME + '_'))
            manifest = (ROOT / folder / (folder + '.toc')).read_text()
            self.assertIn('## Dependencies: Titan, ' + NAME + '\n', manifest)
            self.assertIn('## Title: ' + TITLE + ': ', manifest)

    def test_runtime_has_no_old_brand(self):
        old = 'Titan' + 'Gathered2'
        for file in [*CORE.glob('*.lua'), *CORE.glob('*.toc'), *CORE.glob('Localization/*.lua')]:
            self.assertNotIn(old, file.read_text(), str(file))
            self.assertNotIn('TG' + '2', file.read_text(), str(file))
        self.assertTrue((ROOT / 'README.md').read_text().startswith('# ' + TITLE + '\n'))


if __name__ == '__main__':
    unittest.main()
