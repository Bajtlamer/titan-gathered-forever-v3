import unittest
from pathlib import Path

CORE = Path(__file__).resolve().parents[1]
ROOT = CORE.parent


class RepositoryLayoutTests(unittest.TestCase):
    def test_public_readme_and_workflow_are_at_repository_root(self):
        self.assertTrue((ROOT / 'README.md').is_file())
        workflow = (ROOT / '.github/workflows/releases.yml').read_text()
        self.assertNotIn('path: TitanGatheredForeverV3\n', workflow)
        self.assertIn('working-directory: TitanGatheredForeverV3', workflow)
        self.assertFalse((CORE / '.github').exists())

    def test_core_is_source_not_a_nested_repository(self):
        self.assertFalse((CORE / '.git').exists())
        self.assertTrue((ROOT / '.gitignore').is_file())
        self.assertIn('TitanGatheredForeverV3/tools/check.py', (ROOT / 'README.md').read_text())
