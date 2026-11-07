import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('saved_migration', ROOT / 'tools/migrate_savedvariables.py')


class SavedVariableMigrationTests(unittest.TestCase):
    def migration(self):
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_preserves_saved_data_and_original_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'TitanGathered2.lua'
            target = Path(directory) / 'TitanGatheredForeverV3.lua'
            payload = b'\r\nTitanGathered2ForeverDB = {\r\n ["history"] = { ["count"] = 7 },\r\n}\r\n'
            source.write_bytes(payload)
            self.migration().migrate(source, target)
            self.assertEqual(source.read_bytes(), payload)
            self.assertEqual(target.read_bytes(), payload.replace(b'TitanGathered2ForeverDB =', b'TitanGatheredForeverV3DB =', 1))

    def test_refuses_existing_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'old.lua', Path(directory) / 'new.lua'
            source.write_text('TitanGathered2ForeverDB = {}\n')
            target.write_text('keep existing data')
            with self.assertRaises(FileExistsError):
                self.migration().migrate(source, target)
            self.assertEqual(target.read_text(), 'keep existing data')

    def test_rejects_unrelated_input_without_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'other.lua', Path(directory) / 'new.lua'
            source.write_text('OtherAddonDB = {}\n')
            with self.assertRaises(ValueError):
                self.migration().migrate(source, target)
            self.assertFalse(target.exists())
