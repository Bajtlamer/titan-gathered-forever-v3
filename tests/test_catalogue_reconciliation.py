import copy
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('reconciliation_generator', ROOT / 'tools/generate_catalog.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class ReconciliationTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(hasattr(generator, 'build_reconciliation'), 'Catalogue reconciliation is not implemented')
        self.data = {'schema': 1, 'clientVersion': '1.60.1', 'targetBuild': '70790',
                     'sourceBuild': None, 'complete': False, 'recipes': [
                         {'spellID': 7836, 'outputItemID': 6370, 'profession': 'Alchemy',
                          'reagents': [{'itemID': 6358, 'quantity': 2}, {'itemID': 3371, 'quantity': 1}]}]}
        self.legacy = [{'itemID': 6358, 'name': 'Oily Blackmouth', 'file': 'old/Fishing.en.lua', 'line': 1},
                       {'itemID': 999, 'name': 'Unresolved', 'file': 'old/Fishing.en.lua', 'line': 2}]
        self.members = [{'module': 'Fishing', 'itemID': 6358,
                         'evidence': 'catalogue/legacy-items.json#old/Fishing.en.lua'}]
        self.target = {'schema': 1, 'product': 'wowf', 'clientVersion': '1.60.1', 'build': '70862',
                       'expectedInterface': 16001, 'liveInterfaceVerified': False,
                       'recorded': '2026-11-07', 'evidence': 'installation-metadata'}
        self.raw = ('local _, ns = ...\nns.Data = {\n'
                    ' professions = { "Alchemy", "Cooking" },\n recipes = {\n'
                    '  "6370;1;1;1;80;100;7836;6358:2,3371:1",\n },\n}\n')
        self.evidence = {'schema': 1, 'recipeMirror': {
            'commit': 'a' * 40, 'sha256': hashlib.sha256(self.raw.encode()).hexdigest(),
            'numericRecipeSHA256': generator.recipe_facts_hash(self.data['recipes']),
            'recipeCount': 1, 'sourceBuild': None,
            'url': 'https://example.test/pinned/Data.lua'}}

    def report(self, supplements=None):
        return generator.build_reconciliation(self.data, supplements or [], [], self.members,
                                              self.legacy, self.target, self.evidence)

    def test_unknown_extraction_build_cannot_promote_declared_complete_or_target_build(self):
        self.data['complete'] = True
        r = self.report()
        self.assertFalse(r['complete'])
        self.assertEqual(r['buildEvidence']['sourceBuildMatch'], 'unknown')
        self.assertFalse(r['buildEvidence']['datasetTargetMatches'])
        self.assertFalse(r['gates']['liveObtainabilityVerified'])

    def test_known_matching_build_still_does_not_prove_complete_obtainability(self):
        self.data['sourceBuild'] = self.evidence['recipeMirror']['sourceBuild'] = '70862'
        r = self.report()
        self.assertEqual(r['buildEvidence']['sourceBuildMatch'], 'match')
        self.assertFalse(r['complete'])
        self.data['sourceBuild'] = self.evidence['recipeMirror']['sourceBuild'] = '70790'
        self.assertEqual(self.report()['buildEvidence']['sourceBuildMatch'], 'mismatch')

    def test_legacy_ids_remain_unresolved_without_evidence_instead_of_being_removed(self):
        r = self.report()
        self.assertEqual(r['legacy']['presentIDs'], [6358])
        self.assertEqual(r['legacy']['unresolvedIDs'], [999])
        self.assertEqual(r['legacy']['addedIDs'], [3371])

    def test_local_membership_provenance_must_identify_the_same_item_and_legacy_file(self):
        generator.validate_memberships(self.members, self.legacy)
        for reference in ['data/legacy-items.json#old/Fishing.en.lua',
                          'catalogue/legacy-items.json#wrong.lua',
                          '../catalogue/legacy-items.json#old/Fishing.en.lua', 'https://']:
            rows = copy.deepcopy(self.members)
            rows[0]['evidence'] = reference
            with self.subTest(reference=reference), self.assertRaises(ValueError):
                generator.validate_memberships(rows, self.legacy)
        rows = copy.deepcopy(self.members)
        rows[0]['itemID'] = 123
        with self.assertRaises(ValueError):
            generator.validate_memberships(rows, self.legacy)

    def test_duplicate_unknown_or_missing_membership_provenance_is_rejected(self):
        for rows in [self.members * 2, [{'module': 'Wrong', 'itemID': 6358, 'evidence': 'https://example.test'}],
                     [{'module': 'Fishing', 'itemID': 6358}]]:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                generator.build_modules(self.data, [], rows)

    def test_output_free_enchantments_are_counted_without_becoming_a_completeness_claim(self):
        supplement = {'spellID': 13626, 'outputItemID': None, 'profession': 'Enchanting',
                      'reagents': [{'itemID': 11083, 'quantity': 1}],
                      'evidence': 'https://www.wowhead.com/forever/spell=13626/enchant-chest-minor-stats'}
        r = self.report([supplement])
        self.assertEqual(r['professions']['Enchanting']['outputFreeRecipes'], 1)
        self.assertEqual(r['recipeCount'], 2)
        self.assertFalse(r['gates']['outputFreeEnchantingCoverageComplete'])

    def test_different_craft_producer_is_a_review_candidate_not_membership_removal(self):
        supplement = {'spellID': 9999, 'outputItemID': 6358, 'profession': 'Cooking',
                      'reagents': [{'itemID': 2672, 'quantity': 1}],
                      'evidence': 'https://www.wowhead.com/forever/spell=9999/test-recipe'}
        before = copy.deepcopy(self.members)
        r = self.report([supplement])
        self.assertEqual(r['producerReview'][0]['itemID'], 6358)
        self.assertEqual(r['producerReview'][0]['recipeProducers'], ['Cooking'])
        self.assertEqual(self.members, before)
        self.assertEqual(r['professions']['Fishing']['memberships'], 1)

    def test_pinned_mirror_numeric_rows_are_parsed_as_data_never_executed(self):
        raw = "error('must not execute')\n" + self.raw
        rows = generator.parse_recipe_mirror(raw)
        self.assertEqual(generator.recipe_facts_hash(rows), self.evidence['recipeMirror']['numericRecipeSHA256'])
        generator.verify_recipe_mirror(self.raw.encode(), self.data, self.evidence)
        with self.assertRaises(ValueError):
            generator.verify_recipe_mirror(raw.encode(), self.data, self.evidence)

    def test_bad_mirror_rows_duplicate_spell_ids_or_provenance_hashes_fail_closed(self):
        row = '  "6370;1;1;1;80;100;7836;6358:2,3371:1",'
        for raw in [self.raw.replace('6358:2', '6358:0'), self.raw.replace(';1;80;', ';0;80;'),
                    self.raw.replace(row, row + '\n' + row), self.raw.replace('6358:2', 'os.execute()')]:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                generator.parse_recipe_mirror(raw)
        self.evidence['recipeMirror']['numericRecipeSHA256'] = '0' * 64
        with self.assertRaises(ValueError):
            self.report()

    def test_reconciliation_is_deterministic_and_does_not_mutate_inputs(self):
        before = copy.deepcopy((self.data, self.members, self.legacy, self.target, self.evidence))
        self.assertEqual(json.dumps(self.report(), sort_keys=True), json.dumps(self.report(), sort_keys=True))
        self.assertEqual((self.data, self.members, self.legacy, self.target, self.evidence), before)

    def test_audit_rejects_unusable_supplements_and_unsupported_memberships(self):
        supplement = {'spellID': 13626, 'outputItemID': None, 'profession': 'Enchanting',
                      'reagents': [{'itemID': 11083, 'quantity': 1}]}
        for evidence in [None, 'https://example.test/spell=13626', 'https://www.wowhead.com/forever/spell=9999']:
            row = dict(supplement, evidence=evidence)
            with self.subTest(evidence=evidence), self.assertRaises(ValueError):
                self.report([row])
        self.members = [{'module': 'Fishing', 'itemID': 999999999, 'evidence': 'https://example.test/item'}]
        with self.assertRaises(ValueError):
            self.report()


class AuditCliTests(unittest.TestCase):
    def setUp(self):
        self.script = ROOT / 'tools/audit_catalog.py'
        self.assertTrue(self.script.is_file(), 'Catalogue audit CLI is not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'catalogue').mkdir()
        for path in (ROOT / 'catalogue').glob('*.json'):
            shutil.copy2(path, self.root / 'catalogue' / path.name)

    def run_cli(self, *args):
        return subprocess.run([sys.executable, str(self.script), '--root', str(self.root), *map(str, args)],
                              text=True, capture_output=True)

    def test_default_audit_is_readonly_and_reports_pending_build_gate(self):
        before = {p.name: p.read_bytes() for p in (self.root / 'catalogue').glob('*')}
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('70862', result.stdout)
        self.assertIn('456 unresolved legacy IDs', result.stdout)
        self.assertIn('complete: false', result.stdout)
        self.assertEqual({p.name: p.read_bytes() for p in (self.root / 'catalogue').glob('*')}, before)

    def test_check_rejects_stale_evidence_and_explicit_output_rebuilds_the_report(self):
        self.assertEqual(self.run_cli('--check').returncode, 0)
        path = self.root / 'catalogue/module-membership.json'
        rows = json.loads(path.read_text())
        rows[0]['retrieved'] = '2026-11-08'
        path.write_text(json.dumps(rows))
        self.assertNotEqual(self.run_cli('--check').returncode, 0)
        output = self.root / 'catalogue/reconciliation.json'
        result = self.run_cli('--output', output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.run_cli('--check').returncode, 0)

    def test_pinned_byte_mismatch_is_rejected_without_report_writes(self):
        mirror = self.root / 'mirror.lua'
        mirror.write_text('not the pinned data')
        before = (self.root / 'catalogue/reconciliation.json').read_bytes()
        result = self.run_cli('--mirror-file', mirror)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / 'catalogue/reconciliation.json').read_bytes(), before)

    def test_cli_verifies_numeric_mirror_data_without_executing_lua(self):
        raw = ('error("must not execute")\nlocal _, ns = ...\nns.Data = {\n'
               ' professions = { "Alchemy" },\n recipes = {\n'
               ' "6370;1;1;1;80;100;7836;6358:2,3371:1",\n },\n}\n')
        recipes = generator.parse_recipe_mirror(raw)
        values = {
            'forever-recipes.json': {'schema': 1, 'clientVersion': '1.60.1', 'targetBuild': '70790',
                                    'sourceBuild': None, 'complete': False, 'recipes': recipes},
            'source-evidence.json': {'schema': 1, 'recipeMirror': {
                'commit': 'a' * 40, 'sha256': hashlib.sha256(raw.encode()).hexdigest(), 'recipeCount': 1,
                'numericRecipeSHA256': generator.recipe_facts_hash(recipes), 'sourceBuild': None,
                'url': 'https://example.test/pinned/Data.lua'}},
            'verified-recipes.json': [], 'curated-uses.json': [], 'module-membership.json': [], 'legacy-items.json': [],
        }
        for name, value in values.items():
            (self.root / 'catalogue' / name).write_text(json.dumps(value))
        mirror = self.root / 'mirror.lua'
        mirror.write_text(raw)
        result = self.run_cli('--mirror-file', mirror)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Pinned mirror verified', result.stdout)

    def test_output_symlinks_and_hardlinks_cannot_overwrite_source_inputs(self):
        source = self.root / 'catalogue/forever-recipes.json'
        output = self.root / 'catalogue/reconciliation.json'
        source_bytes, report_bytes = source.read_bytes(), output.read_bytes()
        for kind in ['symlink', 'hardlink']:
            with self.subTest(kind=kind):
                output.unlink()
                if kind == 'symlink':
                    output.symlink_to(source)
                else:
                    os.link(source, output)
                try:
                    result = self.run_cli('--output', output)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(source.read_bytes(), source_bytes)
                finally:
                    output.unlink()
                    source.write_bytes(source_bytes)
                    output.write_bytes(report_bytes)

    def test_audit_cli_and_generator_reject_the_same_bad_membership(self):
        path = self.root / 'catalogue/module-membership.json'
        rows = json.loads(path.read_text())
        rows.append({'module': 'Fishing', 'itemID': 999999999, 'evidence': 'https://example.test/item'})
        path.write_text(json.dumps(rows))
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0)
        with self.assertRaises(ValueError):
            generator.generate(self.root)

    def test_generator_rejects_a_report_alias_before_writing_outputs(self):
        source = self.root / 'catalogue/forever-recipes.json'
        output = self.root / 'catalogue/reconciliation.json'
        original = source.read_bytes()
        output.unlink()
        os.link(source, output)
        with self.assertRaises(ValueError):
            generator.generate(self.root)
        self.assertEqual(source.read_bytes(), original)
        self.assertFalse((self.root / 'TitanGatheredForeverV3').exists())


if __name__ == '__main__':
    unittest.main()
