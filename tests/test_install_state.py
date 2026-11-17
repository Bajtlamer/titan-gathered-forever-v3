import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('state_migration', ROOT / 'tools/install_state.py')
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)


class StateMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.destination = self.root / 'Interface/AddOns'
        (self.destination / 'Old').mkdir(parents=True)
        self.saved = self.root / 'WTF/Account/TEST/SavedVariables'
        self.saved.mkdir(parents=True)
        self.enablement = self.root / 'WTF/Account/TEST/Realm/Character/AddOns.txt'
        self.enablement.parent.mkdir(parents=True)

    def test_preview_then_apply_preserves_raw_account_and_character_saved_files(self):
        character = self.enablement.parent / 'SavedVariables'
        character.mkdir()
        for directory in (self.saved, character):
            (directory / 'Old.lua').write_bytes(b'OldGlobalDB = { value = 123 }\r\n')
            (directory / 'Old.lua.bak').write_bytes(b'previous state\n')
        self.enablement.write_bytes(b'\xef\xbb\xbfOld: disabled\r\nOther: enabled\r\n')
        migration = state.StateMigration(self.destination, {'Old': 'New'})
        self.assertFalse((self.saved / 'New.lua').exists())
        self.assertTrue(self.enablement.read_bytes().startswith(b'\xef\xbb\xbfOld:'))
        backup = self.root / 'backup'
        migration.apply(backup)
        for directory in (self.saved, character):
            for suffix in ('.lua', '.lua.bak'):
                self.assertEqual((directory / ('New' + suffix)).read_bytes(), (directory / ('Old' + suffix)).read_bytes())
        self.assertEqual(self.enablement.read_bytes(), b'\xef\xbb\xbfNew: disabled\r\nOther: enabled\r\n')
        self.assertEqual((backup / 'client-state' / self.enablement.relative_to(self.root)).read_bytes(), b'\xef\xbb\xbfOld: disabled\r\nOther: enabled\r\n')
        migration.rollback()
        self.assertFalse((self.saved / 'New.lua').exists())
        self.assertTrue((self.saved / 'Old.lua').is_file())
        self.assertEqual(self.enablement.read_bytes(), b'\xef\xbb\xbfOld: disabled\r\nOther: enabled\r\n')

    def test_conflicting_saved_file_is_never_overwritten(self):
        (self.saved / 'Old.lua').write_bytes(b'old state')
        (self.saved / 'New.lua').write_bytes(b'newer state')
        with self.assertRaisesRegex(ValueError, 'Conflicting saved files'):
            state.StateMigration(self.destination, {'Old': 'New'})
        self.assertEqual((self.saved / 'New.lua').read_bytes(), b'newer state')

    def test_enablement_conflicts_are_detected_in_both_orders(self):
        for content in (b'Old: enabled\nNew: disabled\n', b'New: disabled\nOld: enabled\n'):
            with self.assertRaisesRegex(ValueError, 'Conflicting'):
                state.enablement(content, {'Old': 'New'})

    def test_enablement_only_renames_whole_addon_names_and_collapses_equal_duplicates(self):
        payload = b'Old: 0\nOld_Helper: 1\nOther: enabled\nNew: 0\n'
        self.assertEqual(state.enablement(payload, {'Old': 'New'}), b'New: 0\nOld_Helper: 1\nOther: enabled\n')
        self.assertEqual(state.enablement(b'Old: enabled', {'Old': 'New'}), b'New: enabled')

    def test_original_saved_file_changed_after_preview_is_not_copied_from_stale_bytes(self):
        original = self.saved / 'Old.lua'
        original.write_bytes(b'previous state')
        migration = state.StateMigration(self.destination, {'Old': 'New'})
        original.write_bytes(b'latest state')
        with self.assertRaisesRegex(ValueError, 'Original saved file changed'):
            migration.apply(self.root / 'backup')
        self.assertFalse((self.saved / 'New.lua').exists())
        self.assertEqual(original.read_bytes(), b'latest state')

    def test_changed_file_after_preview_stops_without_overwriting_it(self):
        self.enablement.write_bytes(b'Old: enabled\n')
        migration = state.StateMigration(self.destination, {'Old': 'New'})
        self.enablement.write_bytes(b'Old: disabled\n')
        with self.assertRaisesRegex(ValueError, 'changed during installation'):
            migration.apply(self.root / 'backup')
        self.assertEqual(self.enablement.read_bytes(), b'Old: disabled\n')

    def test_completed_install_does_not_restore_stale_legacy_saved_files(self):
        (self.saved / 'Old.lua').write_bytes(b'old state')
        (self.saved / 'New.lua').write_bytes(b'current state')
        (self.destination / 'Old').rmdir()
        (self.destination / 'New').mkdir()
        self.assertEqual(state.StateMigration(self.destination, {'Old': 'New'}).changes, [])

    def test_saved_file_symlink_is_rejected(self):
        elsewhere = self.root / 'elsewhere.lua'
        elsewhere.write_bytes(b'private state')
        (self.saved / 'Old.lua').symlink_to(elsewhere)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            state.StateMigration(self.destination, {'Old': 'New'})


if __name__ == '__main__':
    unittest.main()
