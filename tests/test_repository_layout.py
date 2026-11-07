import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / 'TitanGatheredForeverV3'


class RepositoryLayoutTests(unittest.TestCase):
    def test_public_readme_and_workflow_are_at_repository_root(self):
        self.assertTrue((ROOT / 'README.md').is_file())
        workflow = (ROOT / '.github/workflows/releases.yml').read_text()
        self.assertNotIn('working-directory: TitanGatheredForeverV3', workflow)
        self.assertIn('python3 tools/check.py', workflow)
        self.assertFalse((CORE / '.github').exists())

    def test_development_content_is_at_root(self):
        for name in ['tools', 'tests', 'catalogue', 'release-notes']:
            self.assertTrue((ROOT / name).is_dir(), name)
            self.assertFalse((CORE / name).exists(), name)
        self.assertTrue((ROOT / 'AGENTS.md').is_file())
        self.assertFalse((CORE / '.git').exists())
        self.assertIn('python3 tools/check.py', (ROOT / 'README.md').read_text())

    def test_every_addon_contains_only_manifest_files_and_required_artwork(self):
        modules = json.loads((ROOT / 'catalogue/modules.json').read_text())
        for name in ['TitanGatheredForeverV3'] + [module['folder'] for module in modules]:
            addon = ROOT / name
            manifest = addon / (name + '.toc')
            self.assertTrue(manifest.is_file(), name)
            expected = {line.strip() for line in manifest.read_text().splitlines()
                        if line.strip() and not line.startswith('#')}
            expected.add(manifest.name)
            if addon == CORE:
                expected.add('Artwork/TitanOre.tga')
            actual = {p.relative_to(addon).as_posix() for p in addon.rglob('*') if p.is_file()}
            self.assertEqual(actual, expected, name)
