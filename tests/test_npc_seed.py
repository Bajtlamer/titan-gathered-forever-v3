import gzip
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('generate_npc_seed', ROOT / 'tools/generate_npc_seed.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

FIXTURE = """-- fixture dump
CREATE TABLE `creature_template` (
  `Entry` mediumint unsigned NOT NULL DEFAULT '0',
  `Name` char(100) NOT NULL DEFAULT '',
  `TrainerType` tinyint NOT NULL DEFAULT '0',
  `VendorTemplateId` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`Entry`)
) ENGINE=MyISAM;
INSERT INTO `creature_template` VALUES (1,'Alchemy Trainer',2,0),(2,'Recipe Vendor',0,50),(3,'O\\'Brien the Smith',2,0),(4,'Instance Vendor',0,50),(5,'Class Trainer',0,0);
CREATE TABLE `creature` (
  `guid` int unsigned NOT NULL AUTO_INCREMENT,
  `id` mediumint unsigned NOT NULL DEFAULT '0',
  `map` smallint unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=MyISAM;
INSERT INTO `creature` VALUES (10,1,0,-8914.256,-132.1),(11,2,0,100.5,200.25),(12,3,1,50,60),(13,4,389,1,2),(14,1,1,9,9),(15,5,0,3,4);
CREATE TABLE `npc_vendor` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `item` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`,`item`)
) ENGINE=MyISAM;
INSERT INTO `npc_vendor` VALUES (2,102);
CREATE TABLE `npc_vendor_template` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `item` mediumint unsigned NOT NULL DEFAULT '0'
) ENGINE=MyISAM;
INSERT INTO `npc_vendor_template` VALUES (50,100),(50,101),(50,102),(50,103);
CREATE TABLE `npc_trainer` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `spell` mediumint unsigned NOT NULL DEFAULT '0',
  `spellcost` int unsigned NOT NULL DEFAULT '0',
  `reqskill` smallint unsigned NOT NULL DEFAULT '0',
  `reqskillvalue` smallint unsigned NOT NULL DEFAULT '0'
) ENGINE=MyISAM;
INSERT INTO `npc_trainer` VALUES (1,3101,500,171,50),(1,2259,100,171,1),(3,2018,10,164,1),(5,133,1,0,0);
CREATE TABLE `item_template` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `subclass` tinyint unsigned NOT NULL DEFAULT '0',
  `BuyPrice` int unsigned NOT NULL DEFAULT '0',
  `RequiredSkillRank` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=MyISAM;
INSERT INTO `item_template` VALUES (100,9,6,12000,225),(101,9,0,500,0),(102,0,0,50,0),(103,9,5,0,0);
CREATE TABLE `spell_template` (
  `Id` int unsigned NOT NULL DEFAULT '0',
  `EffectItemType1` int unsigned NOT NULL DEFAULT '0',
  `SpellName` text NOT NULL
) ENGINE=MyISAM;
INSERT INTO `spell_template` VALUES (2259,0,'Alchemy Spell'),(3101,555,'Second Spell'),(2018,0,'Smith Spell');
"""


def write_dump(directory, gz=False):
    path = Path(directory) / ('dump.sql.gz' if gz else 'dump.sql')
    data = FIXTURE.encode('utf8')
    path.write_bytes(gzip.compress(data) if gz else data)
    return path


class ParserTests(unittest.TestCase):
    def test_values_handle_escapes_null_and_numbers(self):
        rows = gen.parse_values("(1,'O\\'Brien',NULL,-2.5),(2,'a''b','x,y)',0)")
        self.assertEqual(rows, [['1', "O'Brien", 'NULL', '-2.5'], ['2', "a'b", 'x,y)', '0']])


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.npcs = gen.build(gen.load_tables(write_dump(self.directory.name)))

    def test_only_profession_trainers_and_recipe_vendors_on_continents_remain(self):
        self.assertEqual(sorted(self.npcs), [1, 2, 3])

    def test_trainer_uses_lowest_guid_spawn_and_dominant_profession(self):
        npc = self.npcs[1]
        self.assertEqual((npc['m'], npc['x'], npc['y'], npc['p']), (0, -8914.26, -132.1, 'Alchemy'))
        self.assertEqual(npc['t'], [[2259, 'Alchemy Spell', 100, 1, 0], [3101, 'Second Spell', 500, 50, 555]])
        self.assertEqual(self.npcs[3]['n'], "O'Brien the Smith")
        self.assertEqual(self.npcs[3]['p'], 'Blacksmithing')

    def test_vendor_keeps_only_profession_recipes_and_unknown_skill_is_zero(self):
        # Book (101) and non-recipe (102) items are dropped; recipe 103 has no price or skill, so both are 0.
        self.assertEqual(self.npcs[2]['v'], [[100, 'Alchemy', 12000, 225], [103, 'Cooking', 0, 0]])

    def test_class_trainers_are_excluded(self):
        self.assertNotIn(5, self.npcs)


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.dump = write_dump(self.directory.name)
        self.source = json.loads((ROOT / 'catalogue/npc-seed-source.json').read_text())
        self.source['sha256'] = hashlib.sha256(self.dump.read_bytes()).hexdigest()
        self.output = Path(self.directory.name) / 'NpcSeed.lua'

    def test_render_is_deterministic_and_compact(self):
        npcs = gen.build(gen.load_tables(self.dump))
        text = gen.render(npcs, self.source)
        self.assertEqual(text, gen.render(npcs, self.source))
        self.assertIn('[2] = {n="Recipe Vendor",m=0,x=100.5,y=200.25,v={{100,"Alchemy",12000,225},{103,"Cooking",0,0}}},', text)
        self.assertIn('Do not edit', text.splitlines()[0])
        self.assertIn(self.source['commit'], text)

    def test_generate_writes_then_check_accepts_and_rejects_stale_output(self):
        self.assertTrue(gen.generate(self.dump, self.source, self.output))
        self.assertTrue(gen.generate(self.dump, self.source, self.output, check=True))
        self.output.write_text(self.output.read_text() + '-- stale\n')
        self.assertFalse(gen.generate(self.dump, self.source, self.output, check=True))

    def test_gzip_input_and_hash_pin(self):
        gz = write_dump(self.directory.name, gz=True)
        self.source['sha256'] = hashlib.sha256(gz.read_bytes()).hexdigest()
        self.assertTrue(gen.generate(gz, self.source, self.output))
        self.source['sha256'] = '0' * 64
        with self.assertRaises(ValueError):
            gen.generate(gz, self.source, self.output)


class RealSeedTests(unittest.TestCase):
    def test_seed_header_matches_pinned_provenance(self):
        source = json.loads((ROOT / 'catalogue/npc-seed-source.json').read_text())
        seed = ROOT / 'TitanGatheredForeverV3/Data/NpcSeed.lua'
        self.assertTrue(seed.is_file(), 'Run tools/generate_npc_seed.py --dump <dump> (Task 2)')
        header = '\n'.join(seed.read_text().splitlines()[:4])
        self.assertIn(source['commit'], header)
        self.assertIn(source['sha256'], header)
        self.assertTrue(gen.header_matches(seed.read_text(), source))


if __name__ == '__main__':
    unittest.main()
