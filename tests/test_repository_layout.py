import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / 'TitanGatheredForever'


class RepositoryLayoutTests(unittest.TestCase):
    def test_public_readme_and_workflow_are_at_repository_root(self):
        self.assertTrue((ROOT / 'README.md').is_file())
        workflow = (ROOT / '.github/workflows/releases.yml').read_text()
        self.assertNotIn('working-directory: TitanGatheredForever', workflow)
        self.assertIn('python3 tools/check.py', workflow)
        self.assertFalse((CORE / '.github').exists())

    def test_development_content_is_at_root(self):
        for name in ['tools', 'tests', 'catalogue', 'release-notes']:
            self.assertTrue((ROOT / name).is_dir(), name)
            self.assertFalse((CORE / name).exists(), name)
        self.assertTrue((ROOT / 'AGENTS.md').is_file())
        self.assertFalse((CORE / '.git').exists())
        self.assertIn('python3 tools/check.py', (ROOT / 'README.md').read_text())

    def test_discovery_module_is_unpublished_and_contains_only_manifest_files(self):
        folder = ROOT / 'TitanGatheredForever_Discovery'
        modules = json.loads((ROOT / 'catalogue/modules.json').read_text())
        self.assertNotIn(folder.name, [module['folder'] for module in modules])
        manifest = folder / (folder.name + '.toc')
        expected = {line.strip().replace('\\', '/') for line in manifest.read_text().splitlines()
                    if line.strip() and not line.startswith('#')}
        expected.add(manifest.name)
        expected.add('Artwork/AddonIcon.tga')
        actual = {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
        self.assertEqual(actual, expected)

    def test_every_addon_contains_only_manifest_files_and_required_artwork(self):
        modules = json.loads((ROOT / 'catalogue/modules.json').read_text())
        for name in ['TitanGatheredForever'] + [module['folder'] for module in modules]:
            addon = ROOT / name
            manifest = addon / (name + '.toc')
            self.assertTrue(manifest.is_file(), name)
            expected = {line.strip() for line in manifest.read_text().splitlines()
                        if line.strip() and not line.startswith('#')}
            expected.add(manifest.name)
            expected.add('Artwork/AddonIcon.tga')
            if addon == CORE:
                expected.update({'Artwork/TitanOre.tga', 'Artwork/PinOutlineCircle.tga', 'Artwork/PinOutlineSquare.tga', 'Artwork/RouteAnchor.tga'})
            actual = {p.relative_to(addon).as_posix() for p in addon.rglob('*') if p.is_file()}
            self.assertEqual(actual, expected, name)
