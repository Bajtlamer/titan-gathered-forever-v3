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

    def test_a_module_with_its_own_notes_gets_them_and_the_others_the_short_note(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'release-notes').mkdir()
            (Path(folder) / 'release-notes' / 'ref-9.9.9-TitanGatheredForever_AuctionItems.md').write_text('Auction house notes')
            self.assertEqual(upload.changelog('TitanGatheredForever_AuctionItems', '9.9.9', 'core', root=folder), 'Auction house notes')
            self.assertIn('Version number aligned', upload.changelog('TitanGatheredForever_Mining', '9.9.9', 'core', root=folder))
            self.assertEqual(upload.changelog('TitanGatheredForever', '9.9.9', 'core', root=folder), 'core')
        self.assertIn('Auction house', upload.changelog('TitanGatheredForever_AuctionItems', '0.6.0', 'core'))


if __name__ == '__main__':
    unittest.main()
