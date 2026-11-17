import importlib.util
import hashlib
import re
import json
import tempfile
import struct
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('packager', ROOT / 'tools/package.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class PackageTests(unittest.TestCase):
    def test_each_standalone_addon_resolves_its_own_icon_without_core_artwork(self):
        with tempfile.TemporaryDirectory() as directory:
            for addon in packager.addon_names(ROOT):
                target = packager.package(ROOT, Path(directory) / (addon + '.zip'), addons=[addon])
                with zipfile.ZipFile(target) as archive:
                    manifest = archive.read(f'{addon}/{addon}.toc').decode()
                    texture = re.search(r'^## IconTexture: (.+)$', manifest, re.M).group(1)
                    self.assertEqual(texture, f'Interface\\AddOns\\{addon}\\Artwork\\AddonIcon')
                    raw = archive.read(texture.removeprefix('Interface\\AddOns\\').replace('\\', '/') + '.tga')
                    self.assertEqual(raw[2], 2, 'Use uncompressed true-color TGA')
                    self.assertEqual(struct.unpack_from('<HHB', raw, 12), (64, 64, 32))
                    self.assertEqual(len(raw), 18 + 64 * 64 * 4)
                    self.assertGreater(len(set(raw[18:])), 100, 'Texture must contain artwork')

    def test_core_only_download_cannot_overwrite_the_full_bundle(self):
        bundle = packager.default_target(ROOT, '0.2.0-alpha')
        core = packager.default_target(ROOT, '0.2.0-alpha', 'TitanGatheredForever')
        self.assertNotEqual(bundle, core)
        self.assertEqual(core.parent, ROOT / 'dist/modules')

    def test_package_contains_only_new_addon_and_manifest_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'addon.zip'
            packager.package(ROOT, target)
            with zipfile.ZipFile(target) as archive:
                names = set(archive.namelist())
                self.assertIn('TitanGatheredForever/Core.lua', names)
                self.assertIn('TitanGatheredForever/Artwork/TitanOre.tga', names)
                self.assertNotIn('TitanGatheredForever/TitanGatheredForever.lua', names)
                self.assertFalse(any('.work' in name or name.startswith('catalogue/') for name in names))
                self.assertNotIn('TitanGatheredForever/Data/Items.lua', names)
                self.assertNotIn('TitanGatheredForever/Data/Recipes.lua', names)
                self.assertIn('TitanGatheredForever/Data/Metadata.lua', names)
                for module in json.loads((ROOT / 'catalogue/modules.json').read_text()):
                    folder = module['folder']
                    self.assertIn(f'{folder}/Data.lua', names)
                    module_toc = archive.read(f'{folder}/{folder}.toc').decode()
                    self.assertIn('## Dependencies: Titan, TitanGatheredForever', module_toc)
                manifest = archive.read('TitanGatheredForever/TitanGatheredForever.toc').decode()
                self.assertIn('## Interface: 16001', manifest)
                self.assertIn('## Dependencies: Titan', manifest)
                self.assertIn('## SavedVariables: TitanGatheredForeverV3DB', manifest)
                for line in manifest.splitlines():
                    if line and not line.startswith('#'):
                        self.assertIn('TitanGatheredForever/' + line, names)

    def test_core_only_package_has_no_profession_database(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'core.zip'
            packager.package(ROOT, target, addons=['TitanGatheredForever'])
            with zipfile.ZipFile(target) as archive:
                self.assertTrue(all(name.startswith('TitanGatheredForever/') for name in archive.namelist()))
                self.assertNotIn('TitanGatheredForever/Data/Items.lua', archive.namelist())

    def test_core_package_carries_license_and_notice_but_professions_do_not(self):
        with tempfile.TemporaryDirectory() as directory:
            core = packager.package(ROOT, Path(directory) / 'core.zip', addons=['TitanGatheredForever'])
            with zipfile.ZipFile(core) as archive:
                names = archive.namelist()
                self.assertIn('TitanGatheredForever/LICENSE', names)
                self.assertIn('TitanGatheredForever/NOTICE', names)
                self.assertIn('TitanGatheredForever/Data/NpcSeed.lua', names)
                self.assertEqual(archive.read('TitanGatheredForever/LICENSE'), (ROOT / 'LICENSE').read_bytes())
                self.assertEqual(archive.read('TitanGatheredForever/NOTICE'), (ROOT / 'NOTICE').read_bytes())
            mining = packager.package(ROOT, Path(directory) / 'mining.zip', addons=['TitanGatheredForever_Mining'])
            with zipfile.ZipFile(mining) as archive:
                self.assertFalse([name for name in archive.namelist() if name.endswith(('LICENSE', 'NOTICE'))])

    def test_single_profession_download_contains_only_that_optional_addon(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'herbs.zip'
            packager.package(ROOT, target, addons=['TitanGatheredForever_Herbalism'])
            with zipfile.ZipFile(target) as archive:
                self.assertEqual(set(archive.namelist()), {
                    'TitanGatheredForever_Herbalism/Artwork/AddonIcon.tga',
                    'TitanGatheredForever_Herbalism/Data.lua', 'TitanGatheredForever_Herbalism/TitanGatheredForever_Herbalism.toc'})

    def test_package_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / 'a.zip', Path(directory) / 'b.zip'
            packager.package(ROOT, first)
            packager.package(ROOT, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_release_folder_contains_only_current_downloads_and_verified_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            version = re.search(r'^## Version: (.+)$', (ROOT / 'TitanGatheredForever/TitanGatheredForever.toc').read_text(), re.M).group(1)
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
                    self.assertIn('TitanGatheredForever', item['requires'])
            for line in (staging / 'SHA256SUMS').read_text().splitlines():
                digest, name = line.split('  ', 1)
                self.assertEqual(hashlib.sha256((staging / name).read_bytes()).hexdigest(), digest)

    def test_catalogue_inputs_are_separate_from_runtime_data(self):
        self.assertTrue((ROOT / 'catalogue/forever-recipes.json').is_file())
        self.assertEqual(list((ROOT / 'TitanGatheredForever/Data').glob('*.json')), [])


if __name__ == '__main__':
    unittest.main()
