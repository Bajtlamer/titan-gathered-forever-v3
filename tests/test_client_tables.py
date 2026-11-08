import copy
import csv
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('client_table_generator', ROOT / 'tools/generate_catalog.py')
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)


class ClientTableTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.recipe = {'spellID': 7836, 'outputItemID': 6370, 'profession': 'Alchemy',
                       'reagents': [{'itemID': 6358, 'quantity': 2}]}
        self.dataset = {'recipes': [self.recipe]}
        rows = {
            'SkillLineAbility': [{'SkillLine': 171, 'Spell': 7836, 'TradeSkillCategoryID': 1},
                                 {'SkillLine': 171, 'Spell': 100, 'TradeSkillCategoryID': 0}],
            'SpellEffect': [{'SpellID': 7836, 'Effect': 24, 'EffectItemType': 6370},
                            {'SpellID': 100, 'Effect': 24, 'EffectItemType': 999}],
            'SpellReagents': [dict(SpellID=s, **{f'Reagent_{i}': 6358 if i == 0 else 0 for i in range(8)},
                                  **{f'ReagentCount_{i}': 2 if i == 0 else 0 for i in range(8)}) for s in [7836, 100]],
            'ItemSparse': [{'ID': 6370}, {'ID': 999}],
        }
        self.proof = {'product': 'wowf', 'clientVersion': '1.60.1', 'build': '70862',
                      'method': 'create-item-reagents-v1', 'recipeCount': 1,
                      'numericRecipeSHA256': g.recipe_facts_hash([self.recipe]), 'tables': {}}
        for name, records in rows.items():
            out = io.StringIO(newline='')
            writer = csv.DictWriter(out, fieldnames=list(records[0])); writer.writeheader(); writer.writerows(records)
            raw = out.getvalue().encode()
            (self.directory / (name + '.csv')).write_bytes(raw)
            self.proof['tables'][name] = {'sha256': hashlib.sha256(raw).hexdigest(),
                'responseFilename': f'{name}.1.60.1.70862.csv',
                'url': f'https://wago.tools/db2/{name}/csv?product=wowf&build=1.60.1.70862'}

    def test_build_labelled_csv_facts_match_without_promoting_mirror_build(self):
        g.verify_client_tables(self.directory, self.dataset, self.proof)
        g.validate_client_table_evidence(self.dataset, self.proof)

    def test_changed_raw_bytes_and_wrong_build_labels_fail(self):
        for field, value in [('responseFilename', 'ItemSparse.1.60.1.70790.csv'),
                             ('url', 'https://wago.tools/db2/ItemSparse/csv?product=wow&build=1.60.1.70862'),
                             ('sha256', 'bad')]:
            proof = copy.deepcopy(self.proof); proof['tables']['ItemSparse'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                g.verify_client_tables(self.directory, self.dataset, proof)
        with (self.directory / 'ItemSparse.csv').open('a') as f: f.write('9999\n')
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            g.verify_client_tables(self.directory, self.dataset, self.proof)

    def test_changed_recipe_quantity_or_missing_table_fails(self):
        data = copy.deepcopy(self.dataset); data['recipes'][0]['reagents'][0]['quantity'] = 3
        with self.assertRaises(ValueError):
            g.verify_client_tables(self.directory, data, self.proof)
        del self.proof['tables']['SpellEffect']
        with self.assertRaises(ValueError):
            g.validate_client_table_evidence(self.dataset, self.proof)

    def test_reconstruction_excludes_hidden_category_and_requires_item_and_reagents(self):
        facts = g.extract_client_table_recipes(self.directory)
        self.assertEqual(facts, [self.recipe])
        (self.directory / 'ItemSparse.csv').write_text('ID\n999\n')
        self.assertEqual(g.extract_client_table_recipes(self.directory), [])

    def test_conflicting_spell_outputs_are_rejected_instead_of_order_dependent(self):
        with (self.directory / 'SpellEffect.csv').open('a') as f: f.write('7836,24,999\n')
        with self.assertRaisesRegex(ValueError, 'Conflicting'):
            g.extract_client_table_recipes(self.directory)

    def test_repinning_changed_bytes_cannot_hide_changed_numeric_facts(self):
        path = self.directory / 'SpellReagents.csv'
        path.write_text(path.read_text().replace('7836,6358,', '7836,6359,'))
        self.proof['tables']['SpellReagents']['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'facts differ'):
            g.verify_client_tables(self.directory, self.dataset, self.proof)

    def test_table_row_order_does_not_change_reconstructed_facts(self):
        for name in g.CLIENT_TABLES:
            path = self.directory / (name + '.csv')
            lines = path.read_text().splitlines()
            path.write_text('\n'.join(lines[:1] + list(reversed(lines[1:]))) + '\n')
        self.assertEqual(g.extract_client_table_recipes(self.directory), [self.recipe])

    def test_report_crosscheck_stays_separate_from_mirror_build_and_completeness(self):
        dataset = dict(self.dataset, schema=1, clientVersion='1.60.1', sourceBuild=None, complete=True)
        target = {'schema': 1, 'product': 'wowf', 'clientVersion': '1.60.1', 'build': '70862',
                  'expectedInterface': 16001, 'liveInterfaceVerified': False, 'evidence': 'installation-metadata'}
        evidence = {'schema': 1, 'recipeMirror': {'commit': 'a' * 40, 'sha256': 'b' * 64,
                    'numericRecipeSHA256': self.proof['numericRecipeSHA256'], 'recipeCount': 1,
                    'sourceBuild': None, 'url': 'https://example.test/Data.lua'}, 'clientTables': self.proof}
        report = g.build_reconciliation(dataset, [], [], [], [], target, evidence)
        self.assertTrue(report['gates']['baseRecipeFactsCrosscheckedForTarget'])
        self.assertFalse(report['gates']['recipeBuildKnown'])
        self.assertFalse(report['complete'])
        self.assertEqual(report['buildEvidence']['sourceBuildMatch'], 'unknown')
        target['build'] = '70900'
        self.assertFalse(g.build_reconciliation(dataset, [], [], [], [], target, evidence)
                         ['gates']['baseRecipeFactsCrosscheckedForTarget'])

    def test_cli_verifies_offline_tables_and_rejects_changed_bytes(self):
        root = self.directory / 'root'
        (root / 'catalogue').mkdir(parents=True)
        values = {'forever-recipes': dict(self.dataset, schema=1, clientVersion='1.60.1', sourceBuild=None),
                  'verified-recipes': [], 'curated-uses': [], 'module-membership': [], 'legacy-items': [],
                  'target-client': {'schema': 1, 'product': 'wowf', 'clientVersion': '1.60.1', 'build': '70862',
                                    'expectedInterface': 16001, 'liveInterfaceVerified': False,
                                    'evidence': 'installation-metadata'},
                  'source-evidence': {'schema': 1, 'clientTables': self.proof, 'recipeMirror': {
                      'commit': 'a' * 40, 'sha256': 'b' * 64, 'recipeCount': 1, 'sourceBuild': None,
                      'numericRecipeSHA256': self.proof['numericRecipeSHA256'], 'url': 'https://example.test/Data.lua'}}}
        for name, value in values.items():
            (root / 'catalogue' / (name + '.json')).write_text(json.dumps(value))
        command = [sys.executable, str(ROOT / 'tools/audit_catalog.py'), '--root', str(root),
                   '--client-tables', str(self.directory)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Pinned client tables verified', result.stdout)
        with (self.directory / 'ItemSparse.csv').open('a') as f: f.write('12345\n')
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('SHA-256', result.stderr)
