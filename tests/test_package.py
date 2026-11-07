import importlib.util
import hashlib
import re
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('packager', ROOT / 'tools/package.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class PackageTests(unittest.TestCase):
    def test_core_only_download_cannot_overwrite_the_full_bundle(self):
        bundle = packager.default_target(ROOT, '0.2.0-alpha')
        core = packager.default_target(ROOT, '0.2.0-alpha', 'TitanGatheredForeverV3')
        self.assertNotEqual(bundle, core)
        self.assertEqual(core.parent, ROOT / 'dist/modules')

    def test_package_contains_only_new_addon_and_manifest_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'addon.zip'
            packager.package(ROOT, target)
            with zipfile.ZipFile(target) as archive:
                names = set(archive.namelist())
                self.assertIn('TitanGatheredForeverV3/Core.lua', names)
                self.assertIn('TitanGatheredForeverV3/Artwork/TitanOre.tga', names)
                self.assertNotIn('TitanGatheredForeverV3/TitanGatheredForeverV3.lua', names)
                self.assertFalse(any('.work' in name or name.startswith('catalogue/') for name in names))
                self.assertNotIn('TitanGatheredForeverV3/Data/Items.lua', names)
                self.assertNotIn('TitanGatheredForeverV3/Data/Recipes.lua', names)
                self.assertIn('TitanGatheredForeverV3/Data/Metadata.lua', names)
                for module in json.loads((ROOT / 'catalogue/modules.json').read_text()):
                    folder = module['folder']
                    self.assertIn(f'{folder}/Data.lua', names)
                    module_toc = archive.read(f'{folder}/{folder}.toc').decode()
                    self.assertIn('## Dependencies: Titan, TitanGatheredForeverV3', module_toc)
                manifest = archive.read('TitanGatheredForeverV3/TitanGatheredForeverV3.toc').decode()
                self.assertIn('## Interface: 16001', manifest)
                self.assertIn('## Dependencies: Titan', manifest)
                self.assertIn('## SavedVariables: TitanGatheredForeverV3DB', manifest)
                for line in manifest.splitlines():
                    if line and not line.startswith('#'):
                        self.assertIn('TitanGatheredForeverV3/' + line, names)

    def test_core_only_package_has_no_profession_database(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'core.zip'
            packager.package(ROOT, target, addons=['TitanGatheredForeverV3'])
            with zipfile.ZipFile(target) as archive:
                self.assertTrue(all(name.startswith('TitanGatheredForeverV3/') for name in archive.namelist()))
                self.assertNotIn('TitanGatheredForeverV3/Data/Items.lua', archive.namelist())

    def test_single_profession_download_contains_only_that_optional_addon(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'herbs.zip'
            packager.package(ROOT, target, addons=['TitanGatheredForeverV3_Herbs'])
            with zipfile.ZipFile(target) as archive:
                self.assertEqual(set(archive.namelist()), {
                    'TitanGatheredForeverV3_Herbs/Data.lua', 'TitanGatheredForeverV3_Herbs/TitanGatheredForeverV3_Herbs.toc'})

    def test_package_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / 'a.zip', Path(directory) / 'b.zip'
            packager.package(ROOT, first)
            packager.package(ROOT, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_release_folder_contains_only_current_downloads_and_verified_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            version = re.search(r'^## Version: (.+)$', (ROOT / 'TitanGatheredForeverV3/TitanGatheredForeverV3.toc').read_text(), re.M).group(1)
            staging = packager.stage_release(ROOT, version, output=Path(directory) / 'release')
            files = {p.name for p in staging.iterdir()}
            self.assertEqual(len(files), 17)
            self.assertEqual(len([name for name in files if name.endswith('.zip')]), 15)
            index = json.loads((staging / 'downloads.json').read_text())
            self.assertEqual(index['version'], version)
            self.assertEqual(len(index['downloads']), 15)
            for item in index['downloads']:
                path = staging / item['file']
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), item['sha256'])
                self.assertEqual(path.stat().st_size, item['bytes'])
                self.assertIn('Titan', item['requires'])
                if item['type'] not in ('core', 'collection'):
                    self.assertIn('TitanGatheredForeverV3', item['requires'])
            for line in (staging / 'SHA256SUMS').read_text().splitlines():
                digest, name = line.split('  ', 1)
                self.assertEqual(hashlib.sha256((staging / name).read_bytes()).hexdigest(), digest)

    def test_catalogue_inputs_are_separate_from_runtime_data(self):
        self.assertTrue((ROOT / 'catalogue/forever-recipes.json').is_file())
        self.assertEqual(list((ROOT / 'TitanGatheredForeverV3/Data').glob('*.json')), [])


if __name__ == '__main__':
    unittest.main()
