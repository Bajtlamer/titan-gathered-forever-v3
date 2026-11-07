import copy
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('catalog_generator', ROOT / 'tools/generate_catalog.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.data = {'schema': 1, 'clientVersion': '1.60.1', 'targetBuild': '70790',
                     'complete': False, 'source': 'https://example.test/forever',
                     'recipes': [
                         {'spellID': 1, 'outputItemID': 3, 'profession': 'Tailoring',
                          'reagents': [{'itemID': 2589, 'quantity': 2}]},
                         {'spellID': 2, 'outputItemID': 4, 'profession': 'First Aid',
                          'reagents': [{'itemID': 2589, 'quantity': 1}]}]}

    def test_shared_reagent_is_one_item_with_two_profession_relationships(self):
        rows = generator.build_catalog(self.data, [])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[2589]['professions'], ['First Aid', 'Tailoring'])
        self.assertEqual(rows[2589]['recipes'], [1, 2])

    def test_unknown_profession_rejected(self):
        self.data['recipes'][0]['profession'] = 'Archaeology'
        with self.assertRaises(ValueError):
            generator.build_catalog(self.data, [])

    def test_nonpositive_and_noninteger_values_rejected(self):
        for field, value in [('itemID', 0), ('itemID', True), ('quantity', -1), ('quantity', 1.5)]:
            data = copy.deepcopy(self.data)
            data['recipes'][0]['reagents'][0][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                generator.build_catalog(data, [])

    def test_duplicate_spell_rejected_instead_of_double_counted(self):
        self.data['recipes'].append(copy.deepcopy(self.data['recipes'][0]))
        with self.assertRaises(ValueError):
            generator.build_catalog(self.data, [])

    def test_curated_auction_reason_and_evidence_required(self):
        use = {'itemID': 50, 'kind': 'auction', 'reason': 'Teaches a craft',
               'evidence': 'https://www.wowhead.com/forever/item=50', 'auctionable': True}
        self.assertEqual(generator.build_catalog(self.data, [use])[50]['uses'][0], use)
        for key in ['reason', 'evidence', 'auctionable']:
            invalid = dict(use)
            invalid.pop(key)
            with self.subTest(key=key), self.assertRaises(ValueError):
                generator.build_catalog(self.data, [invalid])

    def test_recipe_without_item_output_can_still_establish_reagent_use(self):
        self.data['recipes'][0]['outputItemID'] = None
        self.assertIn(2589, generator.build_catalog(self.data, []))

    def test_serialization_is_deterministic(self):
        self.assertEqual(generator.lua({'z': 1, 'a': [3, 2]}), generator.lua({'a': [3, 2], 'z': 1}))

    def test_profession_modules_only_publish_their_own_relevant_item_subset(self):
        self.data['recipes'].append({'spellID': 3, 'outputItemID': 10, 'profession': 'Alchemy',
                                     'reagents': [{'itemID': 765, 'quantity': 1}]})
        modules = generator.build_modules(self.data, [], [])
        self.assertEqual(set(modules['FirstAid']['items']), {2589})
        self.assertNotIn(765, modules['FirstAid']['items'])
        self.assertEqual(set(modules['Alchemy']['items']), {765})
        self.assertEqual(modules['FirstAid']['folder'], 'TitanGatheredForeverV3_FirstAid')

    def test_gathering_module_membership_is_separate_from_consumer_profession(self):
        self.data['recipes'].append({'spellID': 3, 'outputItemID': 10, 'profession': 'Alchemy',
                                     'reagents': [{'itemID': 765, 'quantity': 1}]})
        modules = generator.build_modules(self.data, [], [
            {'module': 'Herbs', 'itemID': 765, 'evidence': 'https://example.test/herb'}])
        self.assertEqual(set(modules['Herbs']['items']), {765})
        self.assertEqual(modules['Herbs']['label'], 'Herbalism')
        self.assertEqual(modules['Herbs']['items'][765]['professions'], ['Alchemy'])

    def test_auction_uses_have_their_own_optional_addon_not_an_other_profession(self):
        use = {'itemID': 50, 'kind': 'auction', 'reason': 'Teaches a craft',
               'evidence': 'https://www.wowhead.com/forever/item=50', 'auctionable': True}
        modules = generator.build_modules(self.data, [use], [])
        self.assertEqual(modules['Auction']['kind'], 'auction')
        self.assertEqual(modules['Auction']['label'], 'Auction items')
        self.assertEqual(set(modules['Auction']['items']), {50})
        self.assertNotIn('Other', modules)

    def test_runtime_modules_keep_use_counts_without_loading_every_recipe(self):
        for recipe_id in range(3, 103):
            self.data['recipes'].append({'spellID': recipe_id, 'outputItemID': 10,
                                         'profession': 'Tailoring',
                                         'reagents': [{'itemID': 2589, 'quantity': 1}]})
        module = generator.build_modules(self.data, [], [])['FirstAid']
        self.assertEqual(module['items'][2589]['recipeCounts']['Tailoring'], 101)
        self.assertLessEqual(len(module['items'][2589]['recipes']), 2)
        self.assertLessEqual(len(module['recipes']), 2)

    def test_gathering_metadata_identifies_ore_and_herbs_but_not_bars(self):
        self.data['recipes'].extend([
            {'spellID': 3, 'outputItemID': 2840, 'profession': 'Mining',
             'reagents': [{'itemID': 2770, 'quantity': 1}]},
            {'spellID': 4, 'outputItemID': 2841, 'profession': 'Mining',
             'reagents': [{'itemID': 2840, 'quantity': 1}]},
            {'spellID': 5, 'outputItemID': 10, 'profession': 'Alchemy',
             'reagents': [{'itemID': 765, 'quantity': 1}]},
        ])
        modules = generator.build_modules(self.data, [], [
            {'module': 'Herbs', 'itemID': 765, 'evidence': 'https://example.test/herbs'}])
        self.assertEqual(modules['Mining']['gatheringResources'][2770], 0)
        self.assertNotIn(2840, modules['Mining']['gatheringResources'])
        self.assertEqual(modules['Herbs']['gatheringResources'][765], 0)

    def test_skinning_module_publishes_material_sources_without_crafted_leather(self):
        self.data['recipes'].append({'spellID': 3, 'outputItemID': 10, 'profession': 'Leatherworking',
                                     'reagents': [{'itemID': 2318, 'quantity': 1}]})
        modules = generator.build_modules(self.data, [], [
            {'module': 'Skinning', 'itemID': 2318, 'evidence': 'https://example.test/skin'}])
        self.assertEqual(modules['Skinning']['gatheringResources'], {2318: 0})


if __name__ == '__main__':
    unittest.main()
