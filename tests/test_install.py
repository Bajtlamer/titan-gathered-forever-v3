import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/install.py'


def snapshot(root):
    return {p.relative_to(root).as_posix(): p.read_bytes()
            for p in root.rglob('*') if p.is_file()}


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.destination = self.base / 'Interface/AddOns'
        self.destination.mkdir(parents=True)
        self.assertTrue(SCRIPT.is_file(), 'Candidate installer is not implemented')
        spec = importlib.util.spec_from_file_location('candidate_installer', SCRIPT)
        self.installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.installer)

    def existing(self):
        for name in ('TitanGatheredForever', 'TitanGatheredForever_Herbalism',
                     'Titan', 'TitanGathered2', 'AnotherAddon'):
            folder = self.destination / name
            folder.mkdir()
            (folder / 'old.txt').write_text(name)
        saved = self.base / 'WTF/Account/test/SavedVariables'
        saved.mkdir(parents=True)
        (saved / 'TitanGatheredForever.lua').write_text('saved data')

    def test_the_standalone_module_installs_alone_and_leaves_everything_else_untouched(self):
        self.existing()
        name = 'TitanGatheredForever_Discovery'
        before = snapshot(self.base)
        preview = self.installer.install(ROOT, self.destination, names=[name])
        self.assertEqual(preview['addons'], [name])
        self.assertEqual(snapshot(self.base), before)
        result = self.installer.install(ROOT, self.destination, apply=True, names=[name])
        after = snapshot(self.base)
        self.assertEqual({k: v for k, v in after.items() if not k.startswith('Interface/AddOns/' + name)
                          and not k.startswith('Interface/.tgf-v3-backups')}, before)
        self.assertTrue((self.destination / name / f'{name}.toc').is_file())
        self.assertTrue((self.destination / name / 'Artwork/AddonIcon.tga').is_file())
        self.assertEqual(result['state_files'], 0)
        (self.destination / name / 'old.txt').write_text('edited')
        again = self.installer.install(ROOT, self.destination, apply=True, names=[name])
        self.assertEqual((again['backup'] / name / 'old.txt').read_text(), 'edited')
        self.assertFalse((self.destination / name / 'old.txt').exists())

    def test_only_listed_standalone_modules_may_be_installed_alone(self):
        with self.assertRaises(ValueError):
            self.installer.install(ROOT, self.destination, names=['TitanGatheredForever_Mining'])
        with self.assertRaises(ValueError):
            self.installer.install(ROOT, self.destination, names=['Titan'])

    def test_legacy_folders_saved_files_and_disabled_state_migrate_together(self):
        legacy = self.destination / 'TitanGatheredForeverV3'
        legacy.mkdir()
        (legacy / 'previous.lua').write_bytes(b'previous runtime')
        (self.destination / 'TitanGatheredForeverV3_Herbs').mkdir()
        (self.destination / 'TitanGatheredForeverV3_Auction').mkdir()
        saved = self.base / 'WTF/Account/TEST/SavedVariables'
        saved.mkdir(parents=True)
        payload = b'TitanGatheredForeverV3DB = { lifetime = 12345 }\n'
        (saved / 'TitanGatheredForeverV3.lua').write_bytes(payload)
        enablement = saved.parent / 'Realm/Character/AddOns.txt'
        enablement.parent.mkdir(parents=True)
        enablement.write_bytes(b'TitanGatheredForeverV3: disabled\nTitanGatheredForeverV3_Herbs: enabled\nOther: enabled\n')
        before = snapshot(self.base)
        self.installer.install(ROOT, self.destination)
        self.assertEqual(snapshot(self.base), before)
        result = self.installer.install(ROOT, self.destination, apply=True)
        self.assertFalse(legacy.exists())
        self.assertFalse((self.destination / 'TitanGatheredForeverV3_Herbs').exists())
        self.assertFalse((self.destination / 'TitanGatheredForeverV3_Auction').exists())
        self.assertTrue((self.destination / 'TitanGatheredForever_Herbalism/Data.lua').is_file())
        self.assertTrue((self.destination / 'TitanGatheredForever_AuctionItems/Data.lua').is_file())
        self.assertTrue((self.destination / 'TitanGatheredForever/Core.lua').is_file())
        self.assertEqual((saved / 'TitanGatheredForever.lua').read_bytes(), payload)
        self.assertEqual((saved / 'TitanGatheredForeverV3.lua').read_bytes(), payload)
        self.assertEqual(enablement.read_bytes(), b'TitanGatheredForever: disabled\nTitanGatheredForever_Herbalism: enabled\nOther: enabled\n')
        self.assertEqual((result['backup'] / 'TitanGatheredForeverV3/previous.lua').read_bytes(), b'previous runtime')
        # Future installs must not replace newer new-name state from the retained old file.
        (saved / 'TitanGatheredForever.lua').write_bytes(b'newer saved state')
        self.installer.install(ROOT, self.destination, apply=True)
        self.assertEqual((saved / 'TitanGatheredForever.lua').read_bytes(), b'newer saved state')

    def test_failure_while_migrating_enablement_rolls_back_runtime_and_copied_saved_files(self):
        legacy = self.destination / 'TitanGatheredForeverV3'
        legacy.mkdir()
        (legacy / 'previous.lua').write_bytes(b'previous runtime')
        saved = self.base / 'WTF/Account/TEST/SavedVariables'
        saved.mkdir(parents=True)
        (saved / 'TitanGatheredForeverV3.lua').write_bytes(b'original saved state')
        enablement = saved.parent / 'AddOns.txt'
        enablement.write_bytes(b'TitanGatheredForeverV3: disabled\n')
        before = snapshot(self.destination)
        write = self.installer.state_tools.StateMigration.write
        def fail_enablement(path, payload, mode, exclusive=False):
            if path.name == 'AddOns.txt':
                raise OSError('injected state write failure')
            return write(path, payload, mode, exclusive)
        with patch.object(self.installer.state_tools.StateMigration, 'write', side_effect=fail_enablement):
            with self.assertRaisesRegex(OSError, 'state write failure'):
                self.installer.install(ROOT, self.destination, apply=True)
        self.assertEqual(snapshot(self.destination), before)
        self.assertFalse((saved / 'TitanGatheredForever.lua').exists())
        self.assertEqual(enablement.read_bytes(), b'TitanGatheredForeverV3: disabled\n')

    def test_preview_leaves_entire_client_unchanged(self):
        self.existing()
        before = snapshot(self.base)
        result = self.installer.install(ROOT, self.destination)
        self.assertEqual(snapshot(self.base), before)
        self.assertEqual(set(self.destination.parent.iterdir()), {self.destination})
        self.assertEqual(len(result['addons']), 14)
        self.assertIsNone(result['backup'])

    def test_install_backs_up_old_folders_and_preserves_other_data(self):
        self.existing()
        result = self.installer.install(ROOT, self.destination, apply=True)
        backup = result['backup']
        self.assertFalse(backup.is_relative_to(self.destination))
        self.assertEqual((backup / 'TitanGatheredForever/old.txt').read_text(), 'TitanGatheredForever')
        self.assertEqual((backup / 'TitanGatheredForever_Herbalism/old.txt').read_text(), 'TitanGatheredForever_Herbalism')
        self.assertEqual(len(list(backup.iterdir())), 2)
        self.assertFalse((self.destination / 'TitanGatheredForever/old.txt').exists())
        self.assertTrue((self.destination / 'TitanGatheredForever/Core.lua').is_file())
        self.assertTrue((self.destination / 'TitanGatheredForever/Artwork/TitanOre.tga').is_file())
        self.assertFalse((self.destination / 'TitanGatheredForever/tools').exists())
        self.assertEqual((self.destination / 'Titan/old.txt').read_text(), 'Titan')
        self.assertEqual((self.destination / 'TitanGathered2/old.txt').read_text(), 'TitanGathered2')
        self.assertEqual((self.destination / 'AnotherAddon/old.txt').read_text(), 'AnotherAddon')
        self.assertEqual((self.base / 'WTF/Account/test/SavedVariables/TitanGatheredForever.lua').read_text(), 'saved data')

    def test_repeat_install_retains_distinct_backups(self):
        first = self.installer.install(ROOT, self.destination, apply=True)
        installed = snapshot(self.destination)
        second = self.installer.install(ROOT, self.destination, apply=True)
        third = self.installer.install(ROOT, self.destination, apply=True)
        self.assertNotEqual(second['backup'], third['backup'])
        self.assertTrue(first['backup'].is_dir())
        self.assertEqual(snapshot(second['backup']), installed)
        self.assertEqual(snapshot(third['backup']), installed)
        self.assertEqual(snapshot(self.destination), installed)

    def test_invalid_destination_rejected_without_changes(self):
        for destination in (self.base, self.base / 'missing/Interface/AddOns', ROOT,
                            self.destination / 'TitanGatheredForever'):
            with self.subTest(destination=destination):
                before = snapshot(self.base)
                with self.assertRaises(ValueError):
                    self.installer.install(ROOT, destination, apply=True)
                self.assertEqual(snapshot(self.base), before)

    def test_symlink_and_file_targets_rejected_without_changes(self):
        outside = self.base / 'outside'
        outside.mkdir()
        link = self.destination / 'TitanGatheredForever'
        link.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.installer.install(ROOT, self.destination, apply=True)
        self.assertTrue(link.is_symlink())
        link.unlink()
        link.write_text('not a directory')
        with self.assertRaises(ValueError):
            self.installer.install(ROOT, self.destination, apply=True)
        self.assertEqual(link.read_text(), 'not a directory')
        alias = self.base / 'alias/Interface'
        alias.mkdir(parents=True)
        (alias / 'AddOns').symlink_to(self.destination, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.installer.install(ROOT, alias / 'AddOns', apply=True)

    def test_source_overlap_rejected(self):
        source = self.base / 'source'
        target = source / 'Interface/AddOns'
        target.mkdir(parents=True)
        with self.assertRaises(ValueError):
            self.installer.install(source, target, apply=True)
        with self.assertRaises(ValueError):
            self.installer.install(self.destination / 'source', self.destination, apply=True)

    def test_candidate_build_failure_preserves_installation(self):
        self.existing()
        before = snapshot(self.base)
        with patch.object(self.installer.packager, 'package', side_effect=ValueError('missing source')):
            with self.assertRaisesRegex(ValueError, 'missing source'):
                self.installer.install(ROOT, self.destination, apply=True)
        self.assertEqual(snapshot(self.base), before)
        self.assertFalse((self.destination.parent / '.tgf-v3-install-lock').exists())

    def test_mid_install_failure_rolls_back_all_replaced_folders(self):
        self.existing()
        before = snapshot(self.destination)
        rename = Path.rename

        def fail_new_herbs(path, target):
            if path.name == 'TitanGatheredForever_Herbalism' and path.parent.name == 'candidate':
                raise OSError('injected installation failure')
            return rename(path, target)

        with patch.object(Path, 'rename', fail_new_herbs):
            with self.assertRaisesRegex(OSError, 'injected installation failure'):
                self.installer.install(ROOT, self.destination, apply=True)
        self.assertEqual(snapshot(self.destination), before)
        self.assertFalse((self.destination.parent / '.tgf-v3-install-lock').exists())

    def test_lock_blocks_another_installer(self):
        lock = self.destination.parent / '.tgf-v3-install-lock'
        lock.mkdir()
        with self.assertRaisesRegex(ValueError, 'lock'):
            self.installer.install(ROOT, self.destination, apply=True)
        self.assertTrue(lock.is_dir())
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_backup_symlink_rejected_without_writing_outside_client(self):
        outside = self.base / 'outside'
        outside.mkdir()
        (self.destination.parent / '.tgf-v3-backups').symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.installer.install(ROOT, self.destination, apply=True)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_failed_recovery_keeps_original_folders_and_reports_backup(self):
        self.existing()
        rename = Path.rename

        def fail_install_and_recovery(path, target):
            if (path.name == 'TitanGatheredForever_Herbalism' and path.parent.name == 'candidate'
                    or path.parent == self.destination.resolve()):
                # Allow old-folder backup moves, but fail a candidate rollback move.
                if Path(target).parent.name == 'candidate' or path.parent.name == 'candidate':
                    raise OSError('injected recovery failure')
            return rename(path, target)

        with patch.object(Path, 'rename', fail_install_and_recovery):
            with self.assertRaisesRegex(RuntimeError, 'Retained original folders:') as failure:
                self.installer.install(ROOT, self.destination, apply=True)
        backups = list((self.destination.parent / '.tgf-v3-backups').iterdir())
        self.assertEqual(len(backups), 1)
        self.assertIn(str(backups[0]), str(failure.exception))
        self.assertEqual((backups[0] / 'TitanGatheredForever/old.txt').read_text(), 'TitanGatheredForever')
        self.assertEqual((self.destination / 'Titan/old.txt').read_text(), 'Titan')

    def test_cli_requires_destination_and_previews_by_default(self):
        missing = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
        self.assertNotEqual(missing.returncode, 0)
        preview = subprocess.run([sys.executable, str(SCRIPT), '--addons-dir', str(self.destination)],
                                 capture_output=True, text=True)
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn('Preview', preview.stdout)
        self.assertIn('TitanGatheredForever_Herbalism', preview.stdout)
        self.assertEqual(list(self.destination.iterdir()), [])
        applied = subprocess.run([sys.executable, str(SCRIPT), '--addons-dir', str(self.destination), '--apply'],
                                 capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertTrue((self.destination / 'TitanGatheredForever/Core.lua').exists())


if __name__ == '__main__':
    unittest.main()
