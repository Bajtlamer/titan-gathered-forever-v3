import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = 'TitanGatheredForever'
TITLE = 'Titan Gathered Forever'
CORE = ROOT / NAME


class BrandingTests(unittest.TestCase):
    def test_all_manifests_have_the_same_stable_version(self):
        current = re.search(r'^## Version: (.+)$', (CORE / (NAME + '.toc')).read_text(), re.M).group(1)
        for manifest in ROOT.glob('TitanGatheredForever*/*.toc'):
            version = re.search(r'^## Version: (.+)$', manifest.read_text(), re.M).group(1)
            self.assertRegex(version, r'^\d+\.\d+\.\d+$')
            # The Discovery module is not part of the published set and keeps its own version line.
            if manifest.parent.name != 'TitanGatheredForever_Discovery':
                self.assertEqual(version, current)

    def test_core_identity_and_all_optional_dependencies(self):
        self.assertTrue(CORE.is_dir())
        toc = (CORE / (NAME + '.toc')).read_text()
        self.assertIn('## Title: ' + TITLE + '\n', toc)
        self.assertIn('## SavedVariables: TitanGatheredForeverV3DB\n', toc)
        self.assertIn('## OptionalDeps: Titan\n', toc)
        self.assertNotIn('## Dependencies:', toc)
        self.assertIn('## Category: Professions\n', toc)        # the AddOns list section of the whole family
        modules = json.loads((ROOT / 'catalogue/modules.json').read_text())
        self.assertEqual(len(modules), 13)
        for module in modules:
            folder = module['folder']
            self.assertTrue(folder.startswith(NAME + '_'))
            manifest = (ROOT / folder / (folder + '.toc')).read_text()
            self.assertIn('## Dependencies: ' + NAME + '\n', manifest)
            self.assertNotIn('Titan,', manifest)
            self.assertIn('## Title: ' + TITLE + ': ', manifest)
            # every module folds under the core in the AddOns list
            self.assertIn('## Category: Professions\n## Group: ' + NAME + '\n', manifest)

    def test_runtime_has_no_old_brand(self):
        old = 'Titan' + 'Gathered2'
        for file in [*CORE.glob('*.lua'), *CORE.glob('*.toc'), *CORE.glob('Localization/*.lua')]:
            self.assertNotIn(old, file.read_text(), str(file))
            self.assertNotIn('TG' + '2', file.read_text(), str(file))
            for old_title in ('TG3', 'TGF v3', 'Titan Gathered Forever v3'):
                self.assertNotIn(old_title, file.read_text(), str(file))
        self.assertTrue((ROOT / 'README.md').read_text().startswith('# ' + TITLE + '\n'))


if __name__ == '__main__':
    unittest.main()
