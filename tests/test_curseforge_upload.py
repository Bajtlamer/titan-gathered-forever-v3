import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('curseforge_upload', ROOT / 'tools' / 'curseforge_upload.py')
upload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upload)


class UploadLedgerTests(unittest.TestCase):
    def test_a_file_that_was_sent_is_never_sent_again(self):
        with tempfile.TemporaryDirectory() as folder:
            ledger = Path(folder) / 'ledger.json'
            self.assertFalse(upload.already_sent(ledger, 1810955, 'a-0.5.151-core.zip'))
            upload.record_sent(ledger, 1810955, 'a-0.5.151-core.zip', 9777064)
            self.assertTrue(upload.already_sent(ledger, 1810955, 'a-0.5.151-core.zip'))
            self.assertFalse(upload.already_sent(ledger, 1811017, 'a-0.5.151-core.zip'))
            self.assertFalse(upload.already_sent(ledger, 1810955, 'a-0.5.152-core.zip'))
            self.assertEqual(json.loads(ledger.read_text())['1810955']['a-0.5.151-core.zip'], 9777064)


if __name__ == '__main__':
    unittest.main()
