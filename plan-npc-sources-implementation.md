# Profession Trainers and Recipe Vendors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show profession trainers and recipe vendors on the world map and minimap (menu toggles plus per-profession filter), list recipes, required skill and price in vendor and trainer tooltips, and add a window of unlearned recipes with a trainer or vendor source.

**Architecture:** A generated seed (`Data/NpcSeed.lua`, built from a pinned CMaNGOS classic-db dump) is merged at read time with live observations stored in SavedVariables (`saved.npcs`). `NpcSources.lua` owns merging, map placement, visibility and tooltips. `NpcObserver.lua` records trainer and merchant windows. `KnownRecipes.lua` records which recipes each character knows. `RecipeBrowser.lua` is the unlearned recipes window. Existing `Map.lua` and `Minimap.lua` draw the new pin kinds `Trainer` and `RecipeVendor`.

**Tech Stack:** Lua 5.1 semantics (LuaJIT for tests, WoW Forever 1.60.1, interface 16001), Python 3.10+ for tooling and unit tests, the repository's own test style (`tests/*.lua` run by `tools/check.py`, `tests/test_*.py` by unittest).

Specification: [plan-npc-sources.md](plan-npc-sources.md). Read it first. Repository rules are in AGENTS.md: no em dashes, no emoji, no unrelated reformatting, unknown evidence stays unknown, instance spots are never created, runtime changes need a version increment and automatic installation. Commit and push steps below run only when the owner has authorized commits for this work.

Deviations from the spec, decided while planning (the spec file is updated in Task 10):
- The per-profession filter is one shared setting `mapNpcProfessions` for both trainers and vendors (spec said `mapTrainerProfessions`).
- Trainer and vendor observation live in `NpcObserver.lua`, not in `NpcSources.lua`, to keep files focused.
- The recipe browser row button opens the world map on the NPC's continent or zone instead of placing a waypoint.
- Seed faction is omitted: the dump has no faction data usable without client tables. Pins for both factions appear.
- `settings.npcAxisSwap` (default false) lets the owner flip world coordinate axes live without rebuilding, with the `/tgf npc` calibration command.

---

## File structure

Create:
- `tools/generate_npc_seed.py`: reads the pinned dump, writes `TitanGatheredForeverV3/Data/NpcSeed.lua`.
- `catalogue/npc-seed-source.json`: provenance pin (repository, commit, file, SHA-256, license).
- `TitanGatheredForeverV3/Data/NpcSeed.lua`: generated. Never edited by hand.
- `TitanGatheredForeverV3/KnownRecipes.lua`: per-character known recipe names, name normalisation, profession window scan.
- `TitanGatheredForeverV3/NpcSources.lua`: merge, placement, visibility, tooltip, unlearned recipe model.
- `TitanGatheredForeverV3/NpcObserver.lua`: trainer and merchant observation and the client API adapter.
- `TitanGatheredForeverV3/RecipeBrowser.lua`: unlearned recipes window.
- `tests/test_npc_seed.py`, `tests/known_recipes.lua`, `tests/npc_sources.lua`, `tests/npc_observer.lua`, `tests/recipe_browser.lua`.

Modify:
- `TitanGatheredForeverV3/TitanGatheredForeverV3.toc` (load order), `Settings.lua`, `PinStyle.lua`, `Map.lua`, `Minimap.lua`, `Titan.lua`, `Core.lua`.
- `tools/check.py`, `tools/package.py`, `tools/generate_catalog.py` (VERSION), `tests/test_package.py`, `tests/minimap.lua`, `tests/map.lua`.
- Documentation listed in Task 10.

Load order (core `.toc`): `Data/Metadata.lua`, `Data/NpcSeed.lua`, ..., `Professions.lua`, `KnownRecipes.lua`, ..., `Sources.lua`, `NpcSources.lua`, `NpcObserver.lua`, `PinStyle.lua`, ..., `CraftingView.lua`, `RecipeBrowser.lua`, `Titan.lua`, `Core.lua`.

Scratch data: the pinned dump is already downloaded at `/private/tmp/claude-501/-Users-roza-Sites-addons-titan-gathered-forever-v3/f3b5f0d6-1d44-47ae-a67e-380d0e59a1db/scratchpad/classicdb/ClassicDB.sql.gz`. If it is missing, re-download it (Task 2 Step 1). It is never committed.

---

### Task 1: Seed generator with fixture tests

**Files:**
- Create: `tools/generate_npc_seed.py`, `catalogue/npc-seed-source.json`, `tests/test_npc_seed.py`

- [ ] **Step 1: Write the provenance file**

Create `catalogue/npc-seed-source.json`:

```json
{
  "schema": 1,
  "repository": "https://github.com/cmangos/classic-db",
  "commit": "c33f90b8eeb3f8bacb53d5cbfee45075c80b416c",
  "file": "Full_DB/ClassicDB_1_12_1_z2815.sql.gz",
  "sha256": "4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0",
  "license": "GPL-3.0",
  "clientData": "Classic 1.12.1; not yet confirmed on WoW Forever 1.60.1",
  "retrieved": "2026-11-12"
}
```

- [ ] **Step 2: Write the failing tests**

Create `tests/test_npc_seed.py`:

```python
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
        self.assertEqual(self.npcs[2]['v'], [[100, 'Alchemy', 12000, 225]])

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
        self.assertIn('[2] = {n="Recipe Vendor",m=0,x=100.5,y=200.25,v={{100,"Alchemy",12000,225}}},', text)
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `python3 -m unittest tests.test_npc_seed -v`
Expected: FAIL (cannot load `tools/generate_npc_seed.py`: FileNotFoundError).

- [ ] **Step 4: Write the generator**

Create `tools/generate_npc_seed.py`:

```python
#!/usr/bin/env python3
"""Generate TitanGatheredForeverV3/Data/NpcSeed.lua from a pinned CMaNGOS classic-db dump.

The dump is never committed. catalogue/npc-seed-source.json pins its commit and SHA-256.
Usage: generate_npc_seed.py --dump ClassicDB.sql.gz [--check]
       generate_npc_seed.py --check        (header-only check against the provenance file)
"""
import argparse
import collections
import gzip
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROVENANCE = ROOT / 'catalogue/npc-seed-source.json'
OUTPUT = ROOT / 'TitanGatheredForeverV3/Data/NpcSeed.lua'
CONTINENTS = {0, 1}
SKILL_KINDS = {171: 'Alchemy', 164: 'Blacksmithing', 333: 'Enchanting', 202: 'Engineering', 182: 'Herbs',
               165: 'Leatherworking', 186: 'Mining', 393: 'Skinning', 197: 'Tailoring', 185: 'Cooking',
               356: 'Fishing', 129: 'FirstAid'}
RECIPE_SUBCLASS_KINDS = {1: 'Leatherworking', 2: 'Tailoring', 3: 'Engineering', 4: 'Blacksmithing',
                         5: 'Cooking', 6: 'Alchemy', 7: 'FirstAid', 8: 'Enchanting', 9: 'Fishing'}
TABLES = ('creature_template', 'creature', 'npc_vendor', 'npc_vendor_template', 'npc_trainer',
          'item_template', 'spell_template')
KEY_ORDER = ('n', 'm', 'x', 'y', 'p', 't', 'v')


def to_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def parse_values(text):
    """Parse the tuple list after VALUES in a MySQL INSERT into lists of strings."""
    rows, i, n = [], 0, len(text)
    while i < n:
        if text[i] != '(':
            raise ValueError('Unexpected SQL near: ' + text[i:i + 30])
        i += 1
        fields = []
        while True:
            if text[i] == "'":
                i += 1
                value = []
                while True:
                    if text[i] == '\\':
                        value.append(text[i + 1])
                        i += 2
                    elif text[i] == "'":
                        if text[i + 1:i + 2] == "'":
                            value.append("'")
                            i += 2
                        else:
                            i += 1
                            break
                    else:
                        value.append(text[i])
                        i += 1
                fields.append(''.join(value))
            else:
                j = i
                while text[j] not in ',)':
                    j += 1
                fields.append(text[i:j])
                i = j
            if text[i] == ',':
                i += 1
                continue
            i += 1  # closing parenthesis
            break
        rows.append(fields)
        if i < n and text[i] == ',':
            i += 1
    return rows


def open_dump(path):
    path = Path(path)
    if path.suffix == '.gz':
        return gzip.open(path, 'rt', encoding='utf8', errors='replace')
    return open(path, encoding='utf8', errors='replace')


def load_tables(path):
    columns = {}
    rows = {name: [] for name in TABLES}
    current = None
    create = re.compile(r'^CREATE TABLE `(\w+)` \($')
    insert = re.compile(r'^INSERT INTO `(\w+)` VALUES (.*);$')
    with open_dump(path) as handle:
        for line in handle:
            line = line.rstrip('\n')
            match = create.match(line)
            if match:
                current = match.group(1) if match.group(1) in TABLES else None
                if current:
                    columns[current] = []
                continue
            if current:
                if line.startswith(') '):
                    current = None
                elif line.lstrip().startswith('`'):
                    columns[current].append(line.split('`')[1])
                continue
            match = insert.match(line)
            if match and match.group(1) in TABLES:
                rows[match.group(1)].extend(parse_values(match.group(2)))
    return {name: [dict(zip(columns.get(name, []), row)) for row in rows[name]] for name in TABLES}


def trainer(template, rows, spells):
    if to_int(template.get('TrainerType')) != 2:
        return None, []
    counts = collections.Counter(to_int(r['reqskill']) for r in rows if to_int(r['reqskill']) in SKILL_KINDS)
    if not counts:
        return None, []
    top = sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))[0][0]
    result = []
    for row in sorted(rows, key=lambda r: (to_int(r['reqskillvalue']), to_int(r['spell']))):
        if to_int(row['reqskill']) != top:
            continue
        spell = spells.get(to_int(row['spell']), {})
        result.append([to_int(row['spell']), spell.get('SpellName', ''), to_int(row['spellcost']),
                       to_int(row['reqskillvalue']), to_int(spell.get('EffectItemType1'))])
    return SKILL_KINDS[top], result


def vendor(template, entry, stock, items):
    ids = list(stock.get(('npc_vendor', entry), []))
    template_id = to_int(template.get('VendorTemplateId'))
    if template_id:
        ids += stock.get(('npc_vendor_template', template_id), [])
    result, seen = [], set()
    for item_id in ids:
        item = items.get(item_id)
        if item is None or item_id in seen or to_int(item['class']) != 9:
            continue
        kind = RECIPE_SUBCLASS_KINDS.get(to_int(item['subclass']))
        if kind is None:
            continue
        seen.add(item_id)
        result.append([item_id, kind, to_int(item['BuyPrice']), to_int(item['RequiredSkillRank'])])
    return sorted(result)


def build(tables):
    items = {to_int(r['entry']): r for r in tables['item_template']}
    spells = {to_int(r['Id']): r for r in tables['spell_template']}
    stock = collections.defaultdict(list)
    for table in ('npc_vendor', 'npc_vendor_template'):
        for row in tables[table]:
            stock[(table, to_int(row['entry']))].append(to_int(row['item']))
    trainer_rows = collections.defaultdict(list)
    for row in tables['npc_trainer']:
        trainer_rows[to_int(row['entry'])].append(row)
    spawns = {}
    for row in sorted(tables['creature'], key=lambda r: to_int(r['guid'])):
        if to_int(row['map']) in CONTINENTS:
            spawns.setdefault(to_int(row['id']), row)
    npcs = {}
    for template in tables['creature_template']:
        entry = to_int(template['Entry'])
        spawn = spawns.get(entry)
        if spawn is None:
            continue
        record = {'n': template['Name'], 'm': to_int(spawn['map']),
                  'x': round(float(spawn['position_x']), 2), 'y': round(float(spawn['position_y']), 2)}
        kind, rows = trainer(template, trainer_rows.get(entry, []), spells)
        if rows:
            record['p'], record['t'] = kind, rows
        recipes = vendor(template, entry, stock, items)
        if recipes:
            record['v'] = recipes
        if 'p' in record or 'v' in record:
            npcs[entry] = record
    return npcs


def lua_value(value):
    if isinstance(value, str):
        escaped = value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '')
        return '"' + escaped + '"'
    if isinstance(value, float):
        text = ('%.2f' % value).rstrip('0').rstrip('.')
        return '0' if text in ('-0', '') else text
    if isinstance(value, int):
        return str(value)
    if isinstance(value, dict):
        keys = [key for key in KEY_ORDER if key in value]
        return '{' + ','.join(f'{key}={lua_value(value[key])}' for key in keys) + '}'
    return '{' + ','.join(lua_value(item) for item in value) + '}'


def render(npcs, source):
    lines = ['-- Generated by tools/generate_npc_seed.py. Do not edit.',
             f'-- Source: {source["repository"]} commit {source["commit"]}, file {source["file"]}',
             f'-- Dump SHA-256: {source["sha256"]}',
             '-- License: ' + source['license'] + '; see NOTICE. Classic data, not yet confirmed on WoW Forever.',
             'local _, ns = ...',
             'ns.NpcSeed = {',
             f'    source = {lua_value(source["repository"] + " " + source["commit"])},',
             '    npcs = {']
    for npc_id in sorted(npcs):
        lines.append(f'        [{npc_id}] = {lua_value(npcs[npc_id])},')
    lines += ['    },', '}']
    return '\n'.join(lines) + '\n'


def header_matches(text, source):
    head = '\n'.join(text.splitlines()[:4])
    return source['commit'] in head and source['sha256'] in head


def generate(dump, source, output, check=False):
    digest = hashlib.sha256(Path(dump).read_bytes()).hexdigest()
    if digest != source['sha256']:
        raise ValueError(f'Dump SHA-256 {digest} does not match the pinned {source["sha256"]}')
    text = render(build(load_tables(dump)), source)
    output = Path(output)
    if check:
        return output.is_file() and output.read_text() == text
    output.write_text(text)
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dump', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    source = json.loads(PROVENANCE.read_text())
    if args.dump:
        ok = generate(args.dump, source, OUTPUT, check=args.check)
        if args.check and not ok:
            print('NpcSeed.lua is stale or missing relative to the pinned dump', file=sys.stderr)
            return 1
        print(('Verified ' if args.check else 'Wrote ') + str(OUTPUT.relative_to(ROOT)))
        return 0
    if not args.check:
        parser.error('--dump is required unless --check is used')
    if not OUTPUT.is_file() or not header_matches(OUTPUT.read_text(), source):
        print('NpcSeed.lua header does not match catalogue/npc-seed-source.json', file=sys.stderr)
        return 1
    print('NpcSeed.lua header matches the pinned provenance; pass --dump to verify the full output')
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 5: Run the tests**

Run: `python3 -m unittest tests.test_npc_seed -v`
Expected: all tests PASS except `RealSeedTests.test_seed_header_matches_pinned_provenance`, which fails with "Run tools/generate_npc_seed.py --dump <dump> (Task 2)". That one is fixed in Task 2.

- [ ] **Step 6: Commit (if authorized)**

```bash
git add tools/generate_npc_seed.py catalogue/npc-seed-source.json tests/test_npc_seed.py
git commit -m "Add pinned NPC seed generator" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Generate and verify the real seed

**Files:**
- Create: `TitanGatheredForeverV3/Data/NpcSeed.lua` (generated)
- Modify: `tools/check.py`

- [ ] **Step 1: Make sure the pinned dump is present and matches**

Run:
```bash
D=/private/tmp/claude-501/-Users-roza-Sites-addons-titan-gathered-forever-v3/f3b5f0d6-1d44-47ae-a67e-380d0e59a1db/scratchpad/classicdb
ls -l $D/ClassicDB.sql.gz || (mkdir -p $D && curl -sSL -o $D/ClassicDB.sql.gz https://raw.githubusercontent.com/cmangos/classic-db/c33f90b8eeb3f8bacb53d5cbfee45075c80b416c/Full_DB/ClassicDB_1_12_1_z2815.sql.gz)
shasum -a 256 $D/ClassicDB.sql.gz
```
Expected hash: `4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0`.

- [ ] **Step 2: Generate the seed**

Run: `python3 tools/generate_npc_seed.py --dump $D/ClassicDB.sql.gz`
Expected: `Wrote TitanGatheredForeverV3/Data/NpcSeed.lua`.

- [ ] **Step 3: Sanity-check the result**

Run:
```bash
ls -l TitanGatheredForeverV3/Data/NpcSeed.lua
grep -c '^        \[' TitanGatheredForeverV3/Data/NpcSeed.lua
luajit -e 'local ns={}; assert(loadfile("TitanGatheredForeverV3/Data/NpcSeed.lua"))("x", ns); local t,v=0,0; for id,n in pairs(ns.NpcSeed.npcs) do assert(n.p or n.v); assert(n.m==0 or n.m==1); if n.p then t=t+1 end; if n.v then v=v+1 end end; print("trainers",t,"vendors",v)'
python3 tools/generate_npc_seed.py --dump $D/ClassicDB.sql.gz --check
```
Expected: the NPC count is roughly 500 (the throwaway parse found 495), trainers near 284 minus those without spawn, vendors near 227, and `Verified TitanGatheredForeverV3/Data/NpcSeed.lua`. Record the file size in `ref-wow-forever-progress.md` during Task 10. If the file is larger than 1 MB, stop and tell the owner before continuing, because runtime memory is a stated project concern.

- [ ] **Step 4: Run the Python tests and add the header check to check.py**

Edit `tools/check.py`, in `commands` after the `generate_catalog.py --check` line, add:

```python
    [sys.executable, 'tools/generate_npc_seed.py', '--check'],
```

Run: `python3 -m unittest tests.test_npc_seed -v` and `python3 tools/generate_npc_seed.py --check`
Expected: all PASS, header message printed.

- [ ] **Step 5: Commit (if authorized)**

```bash
git add TitanGatheredForeverV3/Data/NpcSeed.lua tools/check.py
git commit -m "Add generated NPC seed from pinned classic-db" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

The seed is not yet loaded by the addon, so nothing is installed after this task.

---

### Task 3: Settings and NpcSources core

**Files:**
- Create: `TitanGatheredForeverV3/NpcSources.lua`, `tests/npc_sources.lua`
- Modify: `TitanGatheredForeverV3/Settings.lua`, `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`, `tools/check.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/npc_sources.lua`:

```lua
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function near(a, b) assert(math.abs(a - b) < 0.0001, tostring(a) .. ' != ' .. tostring(b)) end

CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
local player = { mapID = 1429, x = 0.1, y = 0.2 }
C_Map = {
    GetMapPosFromWorldPos = function(_, vector, mapID)
        if mapID == 9999 then return mapID, nil end
        return mapID, CreateVector2D(vector.x / 100, vector.y / 100)
    end,
    GetMapRectOnMap = function() return nil end,
    GetBestMapForUnit = function() return player.mapID end,
    GetPlayerMapPosition = function() return CreateVector2D(player.x, player.y) end,
}

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1',
        settings = { mapNpcProfessions = {} }, db = { npcs = {} },
        Style = { gold = 'gold', gray = 'gray', Text = function(_, text) return text end },
        ItemName = function(id) return 'Recipe: Item' .. id end }
    ns.NpcSeed = { npcs = {
        [1] = { n = 'Alchemy Trainer', m = 0, x = 10, y = 20, p = 'Alchemy',
            t = { { 2259, 'Elixir of Minor Defense', 100, 1, 0 }, { 3101, 'Lesser Healing Potion', 500, 50, 0 } } },
        [2] = { n = 'Recipe Vendor', m = 0, x = 11, y = 21,
            v = { { 100, 'Alchemy', 12000, 225 }, { 101, 'Cooking', 0, 0 } } },
    } }
    assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('seed only record is unconfirmed and unknown values stay unknown', function()
    local ns = fresh()
    local trainer = ns.NpcSources.Record(1)
    eq(trainer.confirmed, false); eq(trainer.profession, 'Alchemy'); eq(#trainer.trainer, 2)
    eq(trainer.trainer[1].skill, 1); eq(trainer.trainer[1].cost, 100)
    local vendor = ns.NpcSources.Record(2)
    eq(vendor.vendor[1].price, 12000); eq(vendor.vendor[1].skill, 225)
    eq(vendor.vendor[2].price, nil); eq(vendor.vendor[2].skill, nil)
    eq(ns.NpcSources.Record(99), nil)
end)

test('observed data overrides seed data', function()
    local ns = fresh()
    ns.db.npcs[1] = { name = 'Seen Trainer', profession = 'Alchemy', mapID = 1429, x = 0.5, y = 0.6, lastSeen = 7,
        trainer = { { name = 'Elixir of Minor Defense', skill = 1, cost = 90 } } }
    local record = ns.NpcSources.Record(1)
    eq(record.confirmed, true); eq(record.name, 'Seen Trainer'); eq(#record.trainer, 1); eq(record.trainer[1].cost, 90)
    eq(ns.NpcSources.Record(2).confirmed, false)
end)

test('observed vendor stock replaces seed stock completely', function()
    local ns = fresh()
    ns.db.npcs[2] = { name = 'Recipe Vendor', mapID = 1429, x = 0.2, y = 0.3, lastSeen = 1,
        vendor = { { itemID = 100, kind = 'Alchemy', price = 11000, skill = 225 } } }
    local record = ns.NpcSources.Record(2)
    eq(#record.vendor, 1); eq(record.vendor[1].price, 11000); eq(record.vendor[1].observed, true)
end)

test('seed npcs are placed through world coordinates', function()
    local ns = fresh()
    local nodes = ns.NpcSources.Nodes(1429)
    eq(#nodes, 2)
    eq(nodes[1].kind, 'Trainer'); near(nodes[1].x, 0.1); near(nodes[1].y, 0.2)
    eq(nodes[2].kind, 'RecipeVendor'); eq(nodes[2].professions.Alchemy, true); eq(nodes[2].professions.Cooking, true)
end)

test('observed position wins and is used only on its own map', function()
    local ns = fresh()
    ns.db.npcs[1] = { name = 'T', profession = 'Alchemy', mapID = 1429, x = 0.5, y = 0.6, lastSeen = 1, trainer = {} }
    near(ns.NpcSources.Nodes(1429)[1].x, 0.5)
    for _, node in ipairs(ns.NpcSources.Nodes(1430)) do assert(node.npcID ~= 1, 'observed npc leaked to another map') end
end)

test('axis swap exchanges world coordinates', function()
    local ns = fresh()
    ns.settings.npcAxisSwap = true
    near(ns.NpcSources.Nodes(1429)[1].x, 0.2); near(ns.NpcSources.Nodes(1429)[1].y, 0.1)
end)

test('unsupported continents and failed conversions are skipped', function()
    local ns = fresh()
    ns.NpcSeed.npcs[3] = { n = 'Far', m = 489, x = 1, y = 1, p = 'Cooking', t = {} }
    eq(#ns.NpcSources.Nodes(1429), 2)
    eq(#ns.NpcSources.Nodes(9999), 0)
end)

test('toggles and profession filter control visibility', function()
    local ns = fresh()
    local nodes = ns.NpcSources.Nodes(1429)
    eq(#ns.NpcSources.List(1429), 2)
    ns.settings.mapTrainers = false
    eq(#ns.NpcSources.List(1429), 1)
    ns.settings.mapTrainers = true; ns.settings.mapRecipeVendors = false
    eq(#ns.NpcSources.List(1429), 1); eq(ns.NpcSources.List(1429)[1].kind, 'Trainer')
    ns.settings.mapRecipeVendors = true; ns.settings.mapNpcProfessions.Alchemy = false
    local visible = ns.NpcSources.List(1429)
    eq(#visible, 1); eq(visible[1].kind, 'RecipeVendor')   -- vendor still sells a Cooking recipe
    ns.settings.mapNpcProfessions.Cooking = false
    eq(#ns.NpcSources.List(1429), 0)
    assert(nodes[1] ~= nil)
end)

test('coin text', function()
    local ns = fresh()
    eq(ns.NpcSources.Coin(12000), '1g 20s'); eq(ns.NpcSources.Coin(0), '0c')
    eq(ns.NpcSources.Coin(5), '5c'); eq(ns.NpcSources.Coin(10101), '1g 1s 1c')
end)

local function tip()
    local t = { lines = {}, doubles = {} }
    function t:AddLine(text) self.lines[#self.lines + 1] = text end
    function t:AddDoubleLine(left, right) self.doubles[#self.doubles + 1] = { left, right } end
    return t
end

test('vendor tooltip lists recipes with skill and price and marks unconfirmed data', function()
    local ns = fresh()
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 2 })
    eq(t.lines[1], 'Recipe Vendor'); eq(t.lines[2], 'Recipe vendor'); eq(t.lines[3], 'Not yet confirmed in game')
    eq(t.doubles[1][1], 'Recipe: Item100'); eq(t.doubles[1][2], 'Skill 225, 1g 20s')
    eq(t.doubles[2][1], 'Recipe: Item101'); eq(t.doubles[2][2], 'Skill unknown, price unknown')
end)

test('trainer tooltip shows profession, skill and cost', function()
    local ns = fresh()
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 1 })
    eq(t.lines[2], 'Alchemy trainer')
    eq(t.doubles[1][1], 'Elixir of Minor Defense'); eq(t.doubles[1][2], 'Skill 1, 1s')
end)

test('tooltip is capped at fifteen recipes and marks known ones', function()
    local ns = fresh()
    local rows = {}
    for id = 1, 20 do rows[id] = { 200 + id, 'Alchemy', 100, id } end
    ns.NpcSeed.npcs[5] = { n = 'Big', m = 0, x = 1, y = 1, v = rows }
    ns.KnownRecipes = { IsKnown = function(_, _, name) return name == 'Recipe: Item201' end }
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 5 })
    eq(#t.doubles, 15); eq(t.doubles[1][1], 'Recipe: Item201 (known)')
    eq(t.lines[#t.lines], 'and 5 more')
end)

test('nearest reports the closest visible pin to the player', function()
    local ns = fresh()
    player.mapID, player.x, player.y = 1429, 0.1, 0.2
    local node, distance = ns.NpcSources.Nearest()
    eq(node.npcID, 1); assert(distance < 0.001)
end)

test('settings defaults preserve explicit choices', function()
    local ns = {}
    assert(loadfile('TitanGatheredForeverV3/Settings.lua'))('TitanGatheredForeverV3', ns)
    local saved, settings = ns.Settings.Initialize({ schema = 1, settings = { mapTrainers = false } })
    eq(settings.mapTrainers, false); eq(settings.mapRecipeVendors, true); eq(settings.recordNpcs, true)
    eq(settings.npcAxisSwap, false); eq(type(settings.mapNpcProfessions), 'table')
    eq(type(saved.npcs), 'table'); eq(type(saved.knownRecipes), 'table')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS npc sources ' .. #tests .. ' checks')
```

- [ ] **Step 2: Run to verify failure**

Run: `luajit tests/npc_sources.lua`
Expected: FAIL (cannot open `TitanGatheredForeverV3/NpcSources.lua`; the assert fires on `loadfile` returning nil).

- [ ] **Step 3: Extend Settings.lua**

In `TitanGatheredForeverV3/Settings.lua`, after the line `if type(settings.recordPvP) ~= 'boolean' then settings.recordPvP = true end` add:

```lua
    if type(settings.mapTrainers) ~= 'boolean' then settings.mapTrainers = true end
    if type(settings.mapRecipeVendors) ~= 'boolean' then settings.mapRecipeVendors = true end
    if type(settings.recordNpcs) ~= 'boolean' then settings.recordNpcs = true end
    if type(settings.npcAxisSwap) ~= 'boolean' then settings.npcAxisSwap = false end
    if type(settings.mapNpcProfessions) ~= 'table' then settings.mapNpcProfessions = {} end
```

and after `if type(saved.pvp) ~= 'table' then saved.pvp = {} end` add:

```lua
    if type(saved.npcs) ~= 'table' then saved.npcs = {} end
    if type(saved.knownRecipes) ~= 'table' then saved.knownRecipes = {} end
```

- [ ] **Step 4: Write NpcSources.lua**

Create `TitanGatheredForeverV3/NpcSources.lua`:

```lua
local _, ns = ...
local Npc = {}
ns.NpcSources = Npc

Npc.Kinds = { 'Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'FirstAid', 'Fishing',
    'Herbs', 'Leatherworking', 'Mining', 'Skinning', 'Tailoring' }
local labels = { FirstAid = 'First Aid', Herbs = 'Herbalism' }
-- Seed continents (world map ids in the dump). Anything else, such as instances, is never placed.
local supported = { [0] = true, [1] = true }
local SHOWN = 15
local cache = {}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end
local function seedNpcs() return (ns.NpcSeed and ns.NpcSeed.npcs) or {} end
local function observed() return (ns.db and ns.db.npcs) or {} end

function Npc.Label(kind) return labels[kind] or kind end
function Npc.Invalidate() cache = {} end

function Npc.Enabled()
    local settings = ns.settings or {}
    return settings.mapTrainers ~= false or settings.mapRecipeVendors ~= false
end

function Npc.Coin(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. 'g' end
    if silver > 0 then parts[#parts + 1] = silver .. 's' end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. 'c' end
    return table.concat(parts, ' ')
end

-- Merge one NPC. Observed values replace seed values; missing evidence stays nil.
function Npc.Record(npcID)
    local seed, saw = seedNpcs()[npcID], observed()[npcID]
    if not seed and not saw then return nil end
    local record = { npcID = npcID, confirmed = saw ~= nil, lastSeen = saw and saw.lastSeen,
        name = (saw and saw.name) or (seed and seed.n) or ('NPC ' .. npcID) }
    record.profession = (saw and saw.profession) or (seed and seed.p)
    if record.profession then
        local rows = {}
        if saw and saw.trainer then
            for _, row in ipairs(saw.trainer) do
                rows[#rows + 1] = { name = row.name, skill = row.skill, cost = row.cost, observed = true }
            end
        elseif seed and seed.t then
            for _, row in ipairs(seed.t) do
                rows[#rows + 1] = { spellID = row[1], name = row[2], cost = row[3],
                    skill = row[4] > 0 and row[4] or nil, observed = false }
            end
        end
        record.trainer = rows
    end
    local vendor = {}
    if saw and saw.vendor then
        for _, row in ipairs(saw.vendor) do
            vendor[#vendor + 1] = { itemID = row.itemID, kind = row.kind, price = row.price, skill = row.skill,
                extendedCost = row.extendedCost, observed = true }
        end
    elseif seed and seed.v then
        for _, row in ipairs(seed.v) do
            vendor[#vendor + 1] = { itemID = row[1], kind = row[2], price = row[3] > 0 and row[3] or nil,
                skill = row[4] > 0 and row[4] or nil, observed = false }
        end
    end
    if #vendor > 0 then record.vendor = vendor end
    return record
end

function Npc.WorldToMap(continent, a, b, mapID)
    if not supported[continent] or not C_Map or not C_Map.GetMapPosFromWorldPos or not CreateVector2D then return end
    local first, second = a, b
    if ns.settings and ns.settings.npcAxisSwap == true then first, second = b, a end
    local ok, _, position = pcall(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(first, second), mapID)
    if not ok or type(position) ~= 'table' or not position.GetXY then return end
    local x, y = position:GetXY()
    if finite(x) and finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function observedPlace(saw, mapID)
    if not saw or not saw.mapID then return end
    if saw.mapID == mapID then return saw.x, saw.y end
    if C_Map and C_Map.GetMapRectOnMap then
        local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, saw.mapID, mapID)
        if ok and finite(left) and finite(right) and finite(top) and finite(bottom) then
            local x, y = left + saw.x * (right - left), top + saw.y * (bottom - top)
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
        end
    end
end

local function place(npcID, mapID)
    local saw, seed = observed()[npcID], seedNpcs()[npcID]
    local x, y = observedPlace(saw, mapID)
    if x then return x, y end
    if saw and saw.mapID then return end -- observed spot exists elsewhere; never add the seed spot too
    if seed then return Npc.WorldToMap(seed.m, seed.x, seed.y, mapID) end
end

function Npc.ContinentMap(npcID)
    local saw = observed()[npcID]
    if saw and saw.mapID then return saw.mapID end
    local seed = seedNpcs()[npcID]
    return seed and ({ [0] = 1415, [1] = 1414 })[seed.m] or nil
end

function Npc.Nodes(mapID)
    if cache[mapID] then return cache[mapID] end
    local ids, seen, nodes = {}, {}, {}
    for id in pairs(seedNpcs()) do ids[#ids + 1] = id; seen[id] = true end
    for id in pairs(observed()) do if not seen[id] then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local x, y = place(id, mapID)
        if x then
            local record = Npc.Record(id)
            if record.profession then
                nodes[#nodes + 1] = { kind = 'Trainer', npcID = id, mapID = mapID, x = x, y = y,
                    profession = record.profession }
            end
            if record.vendor then
                local kinds = {}
                for _, row in ipairs(record.vendor) do kinds[row.kind] = true end
                nodes[#nodes + 1] = { kind = 'RecipeVendor', npcID = id, mapID = mapID, x = x, y = y,
                    professions = kinds }
            end
        end
    end
    cache[mapID] = nodes
    return nodes
end

function Npc.Visible(node)
    local settings = ns.settings or {}
    local filter = settings.mapNpcProfessions or {}
    if node.kind == 'Trainer' then
        return settings.mapTrainers ~= false and filter[node.profession] ~= false
    end
    if settings.mapRecipeVendors == false then return false end
    for kind in pairs(node.professions or {}) do
        if filter[kind] ~= false then return true end
    end
    return false
end

function Npc.List(mapID)
    local result = {}
    for _, node in ipairs(Npc.Nodes(mapID)) do
        if Npc.Visible(node) then result[#result + 1] = node end
    end
    return result
end

-- Calibration aid for /tgf npc: nearest visible pin to the player on the current map.
function Npc.Nearest()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
    local mapID = C_Map.GetBestMapForUnit('player')
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, 'player')
    if not position then return end
    local px, py = position:GetXY()
    local best, bestDistance
    for _, node in ipairs(Npc.List(mapID)) do
        local distance = math.sqrt((node.x - px) ^ 2 + (node.y - py) ^ 2)
        if not bestDistance or distance < bestDistance then best, bestDistance = node, distance end
    end
    return best, bestDistance, mapID
end

function Npc.FillTooltip(tooltip, node)
    local record = Npc.Record(node.npcID)
    if not record then return end
    local Style = ns.Style
    tooltip:AddLine(Style.Text(Style.gold, record.name))
    local rows, role
    if node.kind == 'Trainer' then
        role, rows = Npc.Label(record.profession) .. ' trainer', record.trainer or {}
    else
        role, rows = 'Recipe vendor', record.vendor or {}
    end
    tooltip:AddLine(role)
    if record.confirmed then
        local when = record.lastSeen and date and (' ' .. date('%Y-%m-%d', record.lastSeen)) or ''
        tooltip:AddLine('Confirmed in game' .. when)
    else
        tooltip:AddLine(Style.Text(Style.gray, 'Not yet confirmed in game'))
    end
    local ordered = {}
    for _, row in ipairs(rows) do ordered[#ordered + 1] = row end
    table.sort(ordered, function(a, b)
        local left, right = a.skill or math.huge, b.skill or math.huge
        if left ~= right then return left < right end
        local ida, idb = a.itemID or a.spellID or 0, b.itemID or b.spellID or 0
        if ida ~= idb then return ida < idb end
        return tostring(a.name or '') < tostring(b.name or '')
    end)
    local shown = math.min(#ordered, SHOWN)
    for index = 1, shown do
        local row = ordered[index]
        local name = row.itemID and ns.ItemName(row.itemID) or row.name or 'Unknown recipe'
        local known = ns.KnownRecipes and ns.KnownRecipes.IsKnown(ns.characterID, row.kind or record.profession, name)
        if known == true then name = name .. ' (known)' end
        local skill = row.skill and ('Skill ' .. row.skill) or 'Skill unknown'
        local price
        if row.itemID then price = row.price and Npc.Coin(row.price) or 'price unknown'
        else price = row.cost and Npc.Coin(row.cost) or 'cost unknown' end
        if row.extendedCost then price = price .. ' + extra cost' end
        tooltip:AddDoubleLine(name, skill .. ', ' .. price)
    end
    if #ordered > shown then tooltip:AddLine(string.format('and %d more', #ordered - shown)) end
    if #ordered == 0 then tooltip:AddLine('No recipes recorded yet.') end
end
```

- [ ] **Step 5: Load the new files in the manifest and add the test to check.py**

In `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`, add `Data/NpcSeed.lua` on the line after `Data/Metadata.lua`, and add `NpcSources.lua` on the line after `Sources.lua`.

In `tools/check.py` add `[runtime, 'tests/npc_sources.lua'],` after the `tests/minimap.lua` entry.

- [ ] **Step 6: Run tests**

Run: `luajit tests/npc_sources.lua`
Expected: `PASS npc sources 13 checks`.

Run: `luajit tests/addon_loading.lua && luajit tests/run.lua`
Expected: no failure (the loader tests do not read the core manifest order, and `run.lua` is unaffected). If `addon_loading.lua` fails because `NpcSeed.lua` is loaded without `ns`, check that it is not loading the core toc; the core toc is never passed to `loadAddon`.

- [ ] **Step 7: Commit (if authorized)**

```bash
git add TitanGatheredForeverV3 tests/npc_sources.lua tools/check.py
git commit -m "Add NPC source merge, placement and tooltips" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Known recipes

**Files:**
- Create: `TitanGatheredForeverV3/KnownRecipes.lua`, `tests/known_recipes.lua`
- Modify: `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`, `tools/check.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/known_recipes.lua`:

```lua
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1', db = { knownRecipes = {} },
        settings = {} }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('names are stripped of recipe prefixes and normalised', function()
    local K = fresh().KnownRecipes
    eq(K.Strip('Recipe: Tender Wolf Steak'), 'Tender Wolf Steak')
    eq(K.Strip('Pattern: Blue Linen Vest'), 'Blue Linen Vest')
    eq(K.Strip('Plans: Sharp Claw'), 'Sharp Claw')
    eq(K.Strip('Elixir of Wisdom'), 'Elixir of Wisdom')
    eq(K.Strip('Some: Odd Name'), 'Some: Odd Name')
    eq(K.Normalize('Recipe: Tender Wolf Steak'), 'tender wolf steak')
    eq(K.Normalize(nil), '')
end)

test('unread professions are unknown, read ones are true or false', function()
    local K = fresh().KnownRecipes
    eq(K.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), nil)
    K.Record('C1', 'Alchemy', { 'Elixir of Wisdom' }, 100)
    eq(K.IsKnown('C1', 'Alchemy', 'Recipe: Elixir of Wisdom'), true)
    eq(K.IsKnown('C1', 'Alchemy', 'Lesser Healing Potion'), false)
    eq(K.IsKnown('C1', 'Cooking', 'Elixir of Wisdom'), nil)
    eq(K.IsKnown('C2', 'Alchemy', 'Elixir of Wisdom'), nil)
    eq(K.ReadAt('C1', 'Alchemy'), 100)
end)

test('scan records learned recipes per profession from the trade skill window', function()
    local ns = fresh()
    local info = {
        [1] = { name = 'Elixir of Wisdom', learned = true }, [2] = { name = 'Lesser Healing Potion', learned = false },
        [3] = { name = 'Tender Wolf Steak', learned = true }, [4] = { name = 'Odd', learned = true } }
    local profession = { [1] = 171, [2] = 171, [3] = 185, [4] = 9999 }
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() return { 1, 2, 3, 4 } end,
        GetRecipeInfo = function(id) return info[id] end,
        GetProfessionInfoByRecipeID = function(id) return { professionID = profession[id], parentProfessionID = profession[id] } end,
    }
    time = function() return 500 end
    ns.KnownRecipes.Scan()
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), true)
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Lesser Healing Potion'), false)
    eq(ns.KnownRecipes.IsKnown('C1', 'Cooking', 'Tender Wolf Steak'), true)
    eq(ns.KnownRecipes.ReadAt('C1', 'Alchemy'), 500)
    eq(ns.KnownRecipes.IsKnown('C1', 'Tailoring', 'Odd'), nil)
end)

test('scan ignores unreadable or empty data and keeps earlier records', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Wisdom' }, 1)
    C_TradeSkillUI = { GetAllRecipeIDs = function() return {} end }
    ns.KnownRecipes.Scan()
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), true)
    C_TradeSkillUI = nil
    ns.KnownRecipes.Scan()
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), true)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS known recipes ' .. #tests .. ' checks')
```

- [ ] **Step 2: Run to verify failure**

Run: `luajit tests/known_recipes.lua`
Expected: FAIL (assert on `loadfile` of the missing module).

- [ ] **Step 3: Write KnownRecipes.lua**

Create `TitanGatheredForeverV3/KnownRecipes.lua`:

```lua
local _, ns = ...
local K = {}
ns.KnownRecipes = K

local prefixes = { Recipe = true, Pattern = true, Plans = true, Formula = true, Schematic = true,
    Manual = true, Design = true, Technique = true }
local skillKinds = { [171] = 'Alchemy', [164] = 'Blacksmithing', [185] = 'Cooking', [333] = 'Enchanting',
    [202] = 'Engineering', [129] = 'FirstAid', [165] = 'Leatherworking', [186] = 'Mining', [197] = 'Tailoring' }

function K.Strip(name)
    if type(name) ~= 'string' then return '' end
    local prefix, rest = name:match('^(%a+):%s*(.+)$')
    if prefix and prefixes[prefix] then name = rest end
    return (name:gsub('^%s+', ''):gsub('%s+$', ''))
end

function K.Normalize(name) return K.Strip(name):lower() end

local function store() return ns.db and ns.db.knownRecipes end

function K.Record(character, kind, names, now)
    local saved = store()
    if not saved or not character then return end
    saved[character] = saved[character] or {}
    local set = {}
    for _, name in ipairs(names) do set[K.Normalize(name)] = true end
    saved[character][kind] = { at = now, names = set }
end

-- true: known, false: read and not known, nil: this profession was never read for this character.
function K.IsKnown(character, kind, name)
    local saved = store()
    local entry = saved and saved[character] and saved[character][kind]
    if not entry then return nil end
    return entry.names[K.Normalize(name)] == true
end

function K.ReadAt(character, kind)
    local saved = store()
    local entry = saved and saved[character] and saved[character][kind]
    return entry and entry.at or nil
end

-- Reads the open profession window. A profession is recorded as read only when the client listed its recipes.
function K.Scan()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs or not ns.characterID then return end
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok or not ns.IsPublic(ids) or type(ids) ~= 'table' or #ids == 0 or #ids > 4096 then return end
    local byKind = {}
    for _, id in ipairs(ids) do
        local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        local okProfession, profession = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, id)
        if okInfo and okProfession and ns.IsPublic(info) and ns.IsPublic(profession)
            and type(info) == 'table' and type(profession) == 'table' then
            local kind = skillKinds[profession.parentProfessionID] or skillKinds[profession.professionID]
            if kind and ns.IsPublic(info.name) and type(info.name) == 'string'
                and ns.IsPublic(info.learned) and type(info.learned) == 'boolean' then
                byKind[kind] = byKind[kind] or {}
                if info.learned then byKind[kind][#byKind[kind] + 1] = info.name end
            end
        end
    end
    local now = time and time() or 0
    for kind, names in pairs(byKind) do K.Record(ns.characterID, kind, names, now) end
    if ns.RecipeBrowser and ns.RecipeBrowser.Refresh then ns.RecipeBrowser.Refresh() end
end

local pending = false
function K.Schedule()
    if pending or not C_Timer or not C_Timer.After then return end
    pending = true
    C_Timer.After(0.5, function() pending = false; K.Scan() end)
end
```

- [ ] **Step 4: Register in manifest and check.py**

Add `KnownRecipes.lua` after `Professions.lua` in the core `.toc`. Add `[runtime, 'tests/known_recipes.lua'],` after the `tests/npc_sources.lua` entry in `tools/check.py`.

- [ ] **Step 5: Run tests**

Run: `luajit tests/known_recipes.lua`
Expected: `PASS known recipes 4 checks`.

- [ ] **Step 6: Commit (if authorized)**

```bash
git add TitanGatheredForeverV3/KnownRecipes.lua TitanGatheredForeverV3/TitanGatheredForeverV3.toc tests/known_recipes.lua tools/check.py
git commit -m "Record known recipes per character" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Observation of trainer and merchant windows

**Files:**
- Create: `TitanGatheredForeverV3/NpcObserver.lua`, `tests/npc_observer.lua`
- Modify: `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`, `TitanGatheredForeverV3/Core.lua`, `tools/check.py`

Observation reads only during an explicit trainer or merchant interaction, never from map browsing. The client API adapter (`DefaultAPI`) is not unit tested; it is a live validation gate (Task 10). Everything else is tested through an injected API.

- [ ] **Step 1: Write the failing tests**

Create `tests/npc_observer.lua`:

```lua
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh(api)
    local ns = { IsPublic = function() return true end, settings = { recordNpcs = true }, db = { npcs = {} } }
    ns.NpcSources = { Invalidate = function() ns.invalidated = (ns.invalidated or 0) + 1 end }
    assert(loadfile('TitanGatheredForeverV3/NpcObserver.lua'))('TitanGatheredForeverV3', ns)
    local base = { Enabled = function() return ns.settings.recordNpcs end, Now = function() return 1234 end,
        Npc = function() return { id = 3167, name = 'Trainer Bob', mapID = 1429, x = 0.4, y = 0.5 } end,
        TrainerServices = function() return {} end, MerchantRecipes = function() return {} end }
    for key, value in pairs(api or {}) do base[key] = value end
    return ns, ns.NpcObserver.New(base)
end

test('creature guid yields the npc id and anything else is rejected', function()
    local ns = fresh()
    eq(ns.NpcObserver.NpcID('Creature-0-3134-0-0-3167-0000123ABC'), 3167)
    eq(ns.NpcObserver.NpcID('Player-0-0000ABCD'), nil)
    eq(ns.NpcObserver.NpcID(nil), nil)
    eq(ns.NpcObserver.NpcID(42), nil)
end)

test('requirement text parses profession and rank', function()
    local ns = fresh()
    local kind, rank = ns.NpcObserver.ParseRequirement('Requires Alchemy (225)')
    eq(kind, 'Alchemy'); eq(rank, 225)
    kind, rank = ns.NpcObserver.ParseRequirement('Requires First Aid (150)')
    eq(kind, 'FirstAid'); eq(rank, 150)
    eq(ns.NpcObserver.ParseRequirement('Requires Level 30'), nil)
    eq(ns.NpcObserver.ParseRequirement(nil), nil)
end)

test('trainer window stores the dominant profession and its services', function()
    local ns, observer = fresh({ TrainerServices = function() return {
        { name = 'Elixir of Minor Defense', cost = 100, skillName = 'Alchemy', skillRank = 1 },
        { name = 'Lesser Healing Potion', cost = 500, skillName = 'Alchemy', skillRank = 50 },
        { name = 'Heal', cost = 10, skillName = nil } } end })
    observer:TrainerShown()
    local saved = ns.db.npcs[3167]
    eq(saved.name, 'Trainer Bob'); eq(saved.profession, 'Alchemy'); eq(saved.lastSeen, 1234)
    eq(saved.mapID, 1429); eq(saved.x, 0.4); eq(#saved.trainer, 2)
    eq(saved.trainer[2].name, 'Lesser Healing Potion'); eq(saved.trainer[2].skill, 50); eq(saved.trainer[2].cost, 500)
    eq(ns.invalidated, 1)
end)

test('class trainers and disabled recording store nothing', function()
    local ns, observer = fresh({ TrainerServices = function() return { { name = 'Heal', cost = 10 } } end })
    observer:TrainerShown()
    eq(next(ns.db.npcs), nil)
    local ns2, off = fresh({ TrainerServices = function() return {
        { name = 'X', cost = 1, skillName = 'Alchemy', skillRank = 1 } } end })
    ns2.settings.recordNpcs = false
    off:TrainerShown()
    eq(next(ns2.db.npcs), nil)
end)

test('no recording without an npc such as inside an instance', function()
    local ns, observer = fresh({ Npc = function() return nil end, TrainerServices = function() return {
        { name = 'X', cost = 1, skillName = 'Alchemy', skillRank = 1 } } end })
    observer:TrainerShown(); observer:MerchantShown()
    eq(next(ns.db.npcs), nil)
end)

test('merchant window stores recipes only and replaces earlier stock', function()
    local rows = { { itemID = 100, kind = 'Alchemy', price = 12000, skill = 225, extendedCost = false } }
    local ns, observer = fresh({ MerchantRecipes = function() return rows end })
    observer:MerchantShown()
    eq(#ns.db.npcs[3167].vendor, 1); eq(ns.db.npcs[3167].vendor[1].price, 12000)
    rows = { { itemID = 101, kind = 'Cooking', price = 500 } }
    observer:MerchantShown()
    eq(#ns.db.npcs[3167].vendor, 1); eq(ns.db.npcs[3167].vendor[1].itemID, 101)
end)

test('a merchant without recipes does not create or erase a record', function()
    local ns, observer = fresh()
    observer:MerchantShown()
    eq(next(ns.db.npcs), nil)
    ns.db.npcs[3167] = { name = 'Old', vendor = { { itemID = 100, kind = 'Alchemy' } } }
    observer:MerchantShown()
    eq(#ns.db.npcs[3167].vendor, 1)
end)

test('trainer and vendor data for one npc are kept together', function()
    local ns, observer = fresh({
        TrainerServices = function() return { { name = 'A', cost = 1, skillName = 'Cooking', skillRank = 1 } } end,
        MerchantRecipes = function() return { { itemID = 5, kind = 'Cooking' } } end })
    observer:TrainerShown(); observer:MerchantShown()
    eq(ns.db.npcs[3167].profession, 'Cooking'); eq(#ns.db.npcs[3167].trainer, 1); eq(#ns.db.npcs[3167].vendor, 1)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS npc observer ' .. #tests .. ' checks')
```

- [ ] **Step 2: Run to verify failure**

Run: `luajit tests/npc_observer.lua`
Expected: FAIL (assert on `loadfile` of the missing module).

- [ ] **Step 3: Write NpcObserver.lua**

Create `TitanGatheredForeverV3/NpcObserver.lua`:

```lua
local _, ns = ...
local Obs = {}
Obs.__index = Obs
ns.NpcObserver = Obs

local kindBySkillName = { Alchemy = 'Alchemy', Blacksmithing = 'Blacksmithing', Cooking = 'Cooking',
    Enchanting = 'Enchanting', Engineering = 'Engineering', ['First Aid'] = 'FirstAid', Fishing = 'Fishing',
    Herbalism = 'Herbs', Leatherworking = 'Leatherworking', Mining = 'Mining', Skinning = 'Skinning',
    Tailoring = 'Tailoring' }
-- Item class 9 (recipes) subclass to profession.
local kindBySubclass = { [1] = 'Leatherworking', [2] = 'Tailoring', [3] = 'Engineering', [4] = 'Blacksmithing',
    [5] = 'Cooking', [6] = 'Alchemy', [7] = 'FirstAid', [8] = 'Enchanting', [9] = 'Fishing' }

function Obs.NpcID(guid)
    if type(guid) ~= 'string' or not ns.IsPublic(guid) then return nil end
    return tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$'))
end

function Obs.ParseRequirement(text)
    if type(text) ~= 'string' then return nil end
    local name, rank = text:match('^Requires ([%a ]+) %((%d+)%)$')
    if not name then return nil end
    return kindBySkillName[name], tonumber(rank)
end

function Obs.New(api) return setmetatable({ api = api }, Obs) end

function Obs:Save(npc, fields)
    local store = ns.db.npcs
    local record = store[npc.id] or {}
    record.name, record.mapID, record.x, record.y = npc.name, npc.mapID, npc.x, npc.y
    record.lastSeen = self.api.Now()
    for key, value in pairs(fields) do record[key] = value end
    store[npc.id] = record
    if ns.NpcSources then ns.NpcSources.Invalidate() end
    if self.api.Changed then self.api.Changed() end
end

function Obs:TrainerShown()
    if not self.api.Enabled() then return end
    local npc = self.api.Npc()
    if not npc then return end
    local counts, services = {}, {}
    for _, service in ipairs(self.api.TrainerServices()) do
        local kind = kindBySkillName[service.skillName or '']
        if kind then counts[kind] = (counts[kind] or 0) + 1 end
        services[#services + 1] = { name = service.name, cost = service.cost, skill = service.skillRank, kind = kind }
    end
    local profession
    for kind, count in pairs(counts) do
        if not profession or count > counts[profession] or (count == counts[profession] and kind < profession) then
            profession = kind
        end
    end
    if not profession then return end -- class or non-profession trainer
    local rows = {}
    for _, service in ipairs(services) do
        if service.kind == profession then
            rows[#rows + 1] = { name = service.name, skill = service.skill, cost = service.cost }
        end
    end
    self:Save(npc, { profession = profession, trainer = rows })
end

function Obs:MerchantShown()
    if not self.api.Enabled() then return end
    local npc = self.api.Npc()
    if not npc then return end
    local rows = self.api.MerchantRecipes()
    if #rows == 0 then return end
    self:Save(npc, { vendor = rows })
end

-- Client adapter. The exact Forever 1.60.1 behaviour of these calls is a live validation gate.
local function call(fn, ...)
    if type(fn) ~= 'function' then return end
    local results = { pcall(fn, ...) }
    if not results[1] then return end
    return unpack(results, 2)
end
local function public(value, kind)
    return ns.IsPublic(value) and type(value) == kind
end

function Obs.DefaultAPI()
    local api = {}
    api.Enabled = function() return ns.settings and ns.settings.recordNpcs ~= false end
    api.Now = function() return time() end
    api.Changed = function() if ns.RecipeBrowser and ns.RecipeBrowser.Refresh then ns.RecipeBrowser.Refresh() end end
    api.Npc = function()
        local inside, kind = IsInInstance()
        if not (ns.IsPublic(inside) and inside == false and ns.IsPublic(kind) and kind == 'none') then return end
        local id = Obs.NpcID(UnitGUID and UnitGUID('npc'))
        local name = UnitName and UnitName('npc')
        local mapID = call(C_Map.GetBestMapForUnit, 'player')
        local position = mapID and call(C_Map.GetPlayerMapPosition, mapID, 'player')
        if not id or not public(name, 'string') or not public(mapID, 'number') or not position then return end
        local x, y = position:GetXY()
        if not public(x, 'number') or not public(y, 'number') then return end
        return { id = id, name = name, mapID = mapID, x = x, y = y }
    end
    api.TrainerServices = function()
        local result = {}
        local count = call(GetNumTrainerServices)
        if not public(count, 'number') or count < 1 or count > 400 then return result end
        for index = 1, count do
            local name, _, category = call(GetTrainerServiceInfo, index)
            if public(name, 'string') and category ~= 'header' then
                local cost = call(GetTrainerServiceCost, index)
                local skillName, skillRank = call(GetTrainerServiceSkillReq, index)
                result[#result + 1] = { name = name, cost = public(cost, 'number') and cost or nil,
                    skillName = public(skillName, 'string') and skillName or nil,
                    skillRank = public(skillRank, 'number') and skillRank or nil }
            end
        end
        return result
    end
    api.MerchantRecipes = function()
        local result = {}
        local count = call(GetMerchantNumItems)
        if not public(count, 'number') or count < 1 or count > 400 then return result end
        for index = 1, count do
            local link = call(GetMerchantItemLink, index)
            local itemID = public(link, 'string') and tonumber(link:match('item:(%d+)')) or nil
            local classID, subclassID
            if itemID then
                local _, _, _, _, _, class, subclass = call(C_Item.GetItemInfoInstant, itemID)
                classID, subclassID = class, subclass
            end
            if itemID and classID == 9 and kindBySubclass[subclassID] then
                local _, _, price, _, _, _, _, extended = call(GetMerchantItemInfo, index)
                local skill
                local data = C_TooltipInfo and call(C_TooltipInfo.GetMerchantItem, index)
                if public(data, 'table') and public(data.lines, 'table') then
                    for _, line in ipairs(data.lines) do
                        local kind, rank = Obs.ParseRequirement(line.leftText)
                        if kind == kindBySubclass[subclassID] then skill = rank end
                    end
                end
                result[#result + 1] = { itemID = itemID, kind = kindBySubclass[subclassID],
                    price = public(price, 'number') and price or nil, skill = skill,
                    extendedCost = extended == true or nil }
            end
        end
        return result
    end
    return api
end
```

- [ ] **Step 4: Register in manifest and check.py**

Add `NpcObserver.lua` after `NpcSources.lua` in the core `.toc`. Add `[runtime, 'tests/npc_observer.lua'],` after the `tests/known_recipes.lua` entry in `tools/check.py`.

- [ ] **Step 5: Run tests**

Run: `luajit tests/npc_observer.lua`
Expected: `PASS npc observer 8 checks`.

- [ ] **Step 6: Wire the events into Core.lua**

In `TitanGatheredForeverV3/Core.lua`:

1. After the line `ns.observations = ns.Observations.New(observationAPI)` add:
```lua
    ns.npcObserver = ns.NpcObserver.New(ns.NpcObserver.DefaultAPI())
```
2. In the event registration list (the `for _, event in ipairs({ 'BAG_UPDATE_DELAYED', ... })` block) add `'TRAINER_SHOW', 'MERCHANT_SHOW'` to the table.
3. In the `OnEvent` handler, just before the line `if event:match('^UNIT_SPELLCAST_') then`, add:
```lua
    if event == 'TRAINER_SHOW' then ns.npcObserver:TrainerShown(); return end
    if event == 'MERCHANT_SHOW' then ns.npcObserver:MerchantShown(); return end
    if event == 'TRADE_SKILL_DATA_SOURCE_CHANGED' then ns.KnownRecipes.Schedule() end
```
(The last line does not return, so the existing refresh behaviour for that event stays.)

- [ ] **Step 7: Run the full checks**

Run: `python3 tools/check.py`
Expected: `PASS all shipped Lua files compile with Lua 5.1 semantics`. If `tests/integration.lua` or `tests/addon_loading.lua` fail because the harness loads `Core.lua` with stubbed `ns` lacking `NpcObserver`, add `ns.NpcObserver = { New = function() return {} end, DefaultAPI = function() return {} end }` and `ns.KnownRecipes = { Schedule = function() end }` to that harness next to the other module stubs.

- [ ] **Step 8: Commit (if authorized)**

```bash
git add TitanGatheredForeverV3 tests tools/check.py
git commit -m "Observe trainer and merchant windows" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Map pins, minimap pins, tooltips and menu

**Files:**
- Modify: `TitanGatheredForeverV3/PinStyle.lua`, `Map.lua`, `Minimap.lua`, `Titan.lua`, `Core.lua`, `tests/minimap.lua`, `tests/map.lua`

- [ ] **Step 1: Write the failing minimap test**

Append to `tests/minimap.lua` before the final summary lines (reuse the file's `test`, `map`, `state`, `near`, `ns` and `nodes` locals):

```lua
test('trainer and recipe vendor pins use their own icons and tooltip', function()
    local filled
    ns.NpcSources = {
        Enabled = function() return true end,
        List = function(mapID)
            return { { kind = 'Trainer', npcID = 7, mapID = mapID, x = 0.55, y = 0.5, profession = 'Alchemy' },
                     { kind = 'RecipeVendor', npcID = 8, mapID = mapID, x = 0.55, y = 0.5, professions = { Alchemy = true } } }
        end,
        FillTooltip = function(_, node) filled = node.npcID end }
    state.x, state.y, state.radius = 0.5, 0.5, 100
    map:Refresh()
    local icons = {}
    for _, pin in ipairs(map.pins) do if pin.shown then icons[pin.icon] = pin end end
    local trainer = icons['Interface\\Icons\\INV_Misc_Book_11']
    assert(trainer, 'trainer pin missing')
    assert(icons['Interface\\Icons\\INV_Scroll_03'], 'vendor pin missing')
    trainer.scripts.OnEnter(trainer)
    assert(filled == 7, 'npc tooltip not used')
    ns.NpcSources = nil
    map:Refresh()
end)
```

If the file's pins record the icon under a different field, use the same field the file's first test uses (`pin.icon`).

- [ ] **Step 2: Run to verify failure**

Run: `luajit tests/minimap.lua`
Expected: FAIL `trainer pin missing`.

- [ ] **Step 3: PinStyle icons and labels**

In `TitanGatheredForeverV3/PinStyle.lua` add to the `labels` table `Trainer = 'TGF v3 Profession trainer', RecipeVendor = 'TGF v3 Recipe vendor'` and to the `icons` table `Trainer = 'Interface\\Icons\\INV_Misc_Book_11', RecipeVendor = 'Interface\\Icons\\INV_Scroll_03'`. The existing `PinStyle.Icon(itemID, kind)` already falls back to `icons[kind]` when `itemID` is nil.

- [ ] **Step 4: Minimap wiring**

In `TitanGatheredForeverV3/Minimap.lua`:

1. In `Mini:CreatePin`, at the top of the `OnEnter` function body, after `GameTooltip:SetOwner(button, 'ANCHOR_LEFT')` add:
```lua
        if button.node.npcID and ns.NpcSources then
            ns.NpcSources.FillTooltip(GameTooltip, button.node)
            GameTooltip:Show()
            return
        end
```
2. In `Mini:Refresh`, replace
```lua
    if not ns.settings.gatheringMap or ns.settings.mapMinimap == false then
```
with
```lua
    local npcs = ns.NpcSources and ns.NpcSources.Enabled()
    if not (ns.settings.gatheringMap or npcs) or ns.settings.mapMinimap == false then
```
3. Replace the loop header `for _, node in ipairs(self.controller:List(mapID)) do` with:
```lua
    local combined = {}
    if ns.settings.gatheringMap then
        for _, node in ipairs(self.controller:List(mapID)) do combined[#combined + 1] = node end
    end
    if npcs then
        for _, node in ipairs(ns.NpcSources.List(mapID)) do combined[#combined + 1] = node end
    end
    for _, node in ipairs(combined) do
```

- [ ] **Step 5: Run the minimap test**

Run: `luajit tests/minimap.lua`
Expected: PASS. Run `luajit tests/pin_style.lua && luajit tests/icon_appearance.lua`; expected PASS.

- [ ] **Step 6: Map wiring and test**

In `TitanGatheredForeverV3/Map.lua`:

1. Rename the existing `function Map:Nodes(mapID)` to `function Map:GatheringNodes(mapID)` and add directly below it:
```lua
function Map:Nodes(mapID)
    local result = {}
    if ns.settings.gatheringMap then result = self:GatheringNodes(mapID) end
    if ns.NpcSources and ns.NpcSources.Enabled() then
        for _, node in ipairs(ns.NpcSources.List(mapID)) do result[#result + 1] = node end
    end
    return result
end
```
2. In `Map:CreatePin`'s `OnEnter`, after `GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')` add:
```lua
        if node.npcID and ns.NpcSources then
            ns.NpcSources.FillTooltip(GameTooltip, node)
            GameTooltip:Show()
            return
        end
```
3. In `Map:Refresh`, replace the first condition `if not ns.settings.gatheringMap or ns.settings.mapWorld == false or not self.world:IsShown() then` with:
```lua
    local npcs = ns.NpcSources and ns.NpcSources.Enabled()
    if not (ns.settings.gatheringMap or npcs) or ns.settings.mapWorld == false or not self.world:IsShown() then
```

Open `tests/map.lua`, read its first 60 lines to reuse its frame stub, and add a test analogous to the minimap one: set `ns.NpcSources` to the same stub (with `List`, `Enabled`, `FillTooltip`), call `Map.instance:Refresh(true)`, and assert a shown pin carries icon `Interface\Icons\INV_Misc_Book_11` at `x = 0.55 * canvas width`, that its `OnEnter` calls `FillTooltip`, and that setting `ns.settings.gatheringMap = false` still draws the NPC pin. Restore `ns.NpcSources = nil` at the end of the test.

Run: `luajit tests/map.lua`
Expected: PASS.

- [ ] **Step 7: Menu**

In `TitanGatheredForeverV3/Titan.lua`, directly after the flight points block (after the `flights:CreateCheckbox(...)` call) add:

```lua
        local npcs = root:CreateButton('Trainers and recipe vendors')
        local function redrawNpcs() ns.Map.Update(); ns.Minimap.Update() end
        npcs:CreateCheckbox('Show profession trainers', function() return ns.settings.mapTrainers ~= false end, function()
            ns.settings.mapTrainers = ns.settings.mapTrainers == false; redrawNpcs()
        end)
        npcs:CreateCheckbox('Show recipe vendors', function() return ns.settings.mapRecipeVendors ~= false end, function()
            ns.settings.mapRecipeVendors = ns.settings.mapRecipeVendors == false; redrawNpcs()
        end)
        npcs:CreateCheckbox('Record trainers and vendors when I open their window', function() return ns.settings.recordNpcs ~= false end, function()
            ns.settings.recordNpcs = ns.settings.recordNpcs == false
        end)
        local npcProfessions = npcs:CreateButton('Profession filter')
        npcProfessions:SetScrollMode(300)
        for _, kind in ipairs(ns.NpcSources.Kinds) do
            local id = kind
            npcProfessions:CreateCheckbox(ns.NpcSources.Label(id), function() return ns.settings.mapNpcProfessions[id] ~= false end, function()
                ns.settings.mapNpcProfessions[id] = ns.settings.mapNpcProfessions[id] == false; redrawNpcs()
            end)
        end
        npcs:CreateButton('Unlearned recipes...', function() ns.RecipeBrowser.Show() end)
```

`ns.RecipeBrowser` is created in Task 7; until then the button body is never executed in tests. If `tests/presentation.lua` or another test builds the Titan menu with a stub `ns`, add `ns.NpcSources = { Kinds = {}, Label = function(k) return k end }` and `ns.RecipeBrowser = { Show = function() end }` to that harness next to the other stubs.

- [ ] **Step 8: Calibration command**

In `TitanGatheredForeverV3/Core.lua`, in the slash handler just before `if command == 'refresh' then`, add:

```lua
        if command == 'npc' or command == 'npc swap' then
            if command == 'npc swap' then
                ns.settings.npcAxisSwap = not ns.settings.npcAxisSwap
                ns.NpcSources.Invalidate(); ns.Map.Update(); ns.Minimap.Update()
                ns.Print('NPC world axes swapped: ' .. tostring(ns.settings.npcAxisSwap))
            end
            local node, distance, mapID = ns.NpcSources.Nearest()
            if node then
                local record = ns.NpcSources.Record(node.npcID)
                ns.Print(string.format('Nearest NPC pin on map %s: %s (%s), %.1f%% of the map away; axis swap %s.',
                    tostring(mapID), record.name, node.kind, distance * 100, tostring(ns.settings.npcAxisSwap)))
            else ns.Print('No visible NPC pin on this map.') end
            return
        end
```

Add `/tgf npc` and `/tgf npc swap` to the `help` string in the same handler.

- [ ] **Step 9: Run all checks**

Run: `python3 tools/check.py`
Expected: PASS. Fix menu-harness stubs as described in Step 7 if any presentation test fails.

- [ ] **Step 10: Commit (if authorized)**

```bash
git add TitanGatheredForeverV3 tests
git commit -m "Draw trainer and recipe vendor pins with menu toggles" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Unlearned recipes model and window

**Files:**
- Modify: `TitanGatheredForeverV3/NpcSources.lua`
- Create: `TitanGatheredForeverV3/RecipeBrowser.lua`, `tests/recipe_browser.lua`
- Modify: `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`, `TitanGatheredForeverV3/Core.lua`, `tools/check.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/recipe_browser.lua`:

```lua
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local itemNames = { [100] = 'Recipe: Lesser Healing Potion', [101] = 'Recipe: Elixir of Wisdom', [102] = 'Recipe: Tender Wolf Steak' }
C_Item = { GetItemInfo = function(id) return itemNames[id] end }

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1', settings = {},
        db = { npcs = {}, knownRecipes = {} },
        Style = { gold = 'gold', gray = 'gray', Text = function(_, text) return text end },
        ItemName = function(id) return itemNames[id] or ('Loading ' .. id) end }
    ns.NpcSeed = { npcs = {
        [1] = { n = 'Alchemy Trainer', m = 0, x = 10, y = 20, p = 'Alchemy', t = {
            { 2259, 'Elixir of Minor Defense', 100, 1, 0 }, { 3101, 'Lesser Healing Potion', 500, 50, 0 },
            { 3102, 'Journeyman Alchemist', 5000, 50, 0 } } },
        [2] = { n = 'Recipe Vendor', m = 0, x = 11, y = 21, v = {
            { 100, 'Alchemy', 12000, 225 }, { 101, 'Alchemy', 20000, 0 }, { 102, 'Cooking', 300, 0 }, { 103, 'Alchemy', 1, 0 } } },
    } }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('unlearned recipes exclude known and rank spells and label the source', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Minor Defense' }, 10)
    local rows, unread, pending = ns.NpcSources.Unlearned('C1', false)
    eq(#rows, 2)
    eq(rows[1].name, 'Lesser Healing Potion'); eq(rows[1].trainer, true); eq(rows[1].skill, 50)
    eq(#rows[1].sources, 2); eq(rows[1].price, 500)
    eq(rows[2].name, 'Elixir of Wisdom'); eq(rows[2].trainer, false); eq(rows[2].skill, nil)
    eq(rows[2].sources[1].role, 'Vendor')
    eq(#unread, 1); eq(unread[1], 'Cooking')
    eq(pending, 1)
end)

test('vendor only hides recipes a trainer can also teach', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 10)
    local rows = ns.NpcSources.Unlearned('C1', true)
    eq(#rows, 1); eq(rows[1].name, 'Elixir of Wisdom')
end)

test('professions never read for the character are reported, not guessed', function()
    local ns = fresh()
    local rows, unread = ns.NpcSources.Unlearned('C1', false)
    eq(#rows, 0); eq(#unread, 2)
end)

test('browser cells and permissive frame construction', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Minor Defense' }, 10)
    local function frame()
        return setmetatable({}, { __index = function(_, key)
            return function(self, ...)
                if key:match('^Create') then return frame() end
                if key == 'GetNumPoints' then return 0 end
                return self
            end
        end })
    end
    CreateFrame = function() local f = frame(); f.TitleText = frame(); return f end
    UIParent, UISpecialFrames, GameTooltip = frame(), {}, frame()
    assert(loadfile('TitanGatheredForeverV3/RecipeBrowser.lua'))('TitanGatheredForeverV3', ns)
    local rows = ns.NpcSources.Unlearned('C1', false)
    local cells = ns.RecipeBrowser.Cells(rows[1])
    eq(cells[1], 'Lesser Healing Potion'); eq(cells[2], 'Alchemy'); eq(cells[3], '50'); eq(cells[4], 'Trainer')
    eq(cells[5], 'Alchemy Trainer (+1)'); eq(cells[6], '5s')
    ns.RecipeBrowser.Show()
    ns.RecipeBrowser.Refresh()
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS recipe browser ' .. #tests .. ' checks')
```

- [ ] **Step 2: Run to verify failure**

Run: `luajit tests/recipe_browser.lua`
Expected: FAIL (`Unlearned` is nil).

- [ ] **Step 3: Add the model to NpcSources.lua**

Append to `TitanGatheredForeverV3/NpcSources.lua`:

```lua
-- Item recipe name for matching, or nil while the client is still loading the item.
function Npc.ItemRecipeName(itemID)
    local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)
    if type(name) == 'string' and ns.IsPublic(name) then return name end
    ns.ItemName(itemID) -- requests the item data; the window refreshes on ITEM_DATA_LOAD_RESULT
end

local rankPrefixes = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true }
local function isRankSpell(name)
    local prefix = type(name) == 'string' and name:match('^(%a+) ')
    return prefix ~= nil and rankPrefixes[prefix] == true
end
local recipeKinds = { Alchemy = true, Blacksmithing = true, Cooking = true, Enchanting = true,
    Engineering = true, FirstAid = true, Leatherworking = true, Mining = true, Tailoring = true }

-- Rows: unlearned recipes with a known source. Second result: professions never read for this
-- character (their recipes are not listed). Third: vendor recipes whose item names are still loading.
function Npc.Unlearned(character, vendorOnly)
    local K = ns.KnownRecipes
    local byKey, rows, unreadSet, pending = {}, {}, {}, 0
    local ids, seen = {}, {}
    for id in pairs(seedNpcs()) do ids[#ids + 1] = id; seen[id] = true end
    for id in pairs(observed()) do if not seen[id] then ids[#ids + 1] = id end end
    table.sort(ids)
    local function add(npcID, npcName, kind, display, skill, price, role)
        if not recipeKinds[kind] then return end
        local known = K and K.IsKnown(character, kind, display)
        if known == nil then unreadSet[kind] = true; return end
        if known == true then return end
        local key = kind .. '|' .. K.Normalize(display)
        local row = byKey[key]
        if not row then
            row = { name = K.Strip(display), kind = kind, trainer = false, sources = {} }
            byKey[key] = row; rows[#rows + 1] = row
        end
        if role == 'Trainer' then row.trainer = true end
        if skill and (not row.skill or skill < row.skill) then row.skill = skill end
        if price and (not row.price or price < row.price) then row.price = price end
        row.sources[#row.sources + 1] = { npcID = npcID, name = npcName, role = role, price = price }
    end
    for _, id in ipairs(ids) do
        local record = Npc.Record(id)
        for _, row in ipairs(record.trainer or {}) do
            if not isRankSpell(row.name) then
                add(id, record.name, record.profession, row.name, row.skill, row.cost, 'Trainer')
            end
        end
        for _, row in ipairs(record.vendor or {}) do
            local name = Npc.ItemRecipeName(row.itemID)
            if name then add(id, record.name, row.kind, name, row.skill, row.price, 'Vendor')
            else pending = pending + 1 end
        end
    end
    if vendorOnly then
        local filtered = {}
        for _, row in ipairs(rows) do if not row.trainer then filtered[#filtered + 1] = row end end
        rows = filtered
    end
    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        local left, right = a.skill or math.huge, b.skill or math.huge
        if left ~= right then return left < right end
        return a.name < b.name
    end)
    for _, row in ipairs(rows) do
        table.sort(row.sources, function(a, b)
            if a.role ~= b.role then return a.role == 'Trainer' end
            return (a.price or math.huge) < (b.price or math.huge)
        end)
    end
    local unread = {}
    for kind in pairs(unreadSet) do unread[#unread + 1] = kind end
    table.sort(unread)
    return rows, unread, pending
end
```

- [ ] **Step 4: Run the model tests**

Run: `luajit tests/recipe_browser.lua`
Expected: the first three tests PASS and the fourth FAILS with `cannot open ... RecipeBrowser.lua`. That is fixed in Step 5.

- [ ] **Step 5: Write RecipeBrowser.lua**

Create `TitanGatheredForeverV3/RecipeBrowser.lua`:

```lua
local _, ns = ...
local Browser = { page = 1, vendorOnly = false }
ns.RecipeBrowser = Browser

local ROWS = 16
local columns = { { 'Recipe', 0, 250 }, { 'Profession', 260, 130 }, { 'Skill', 400, 60 }, { 'Source', 470, 80 },
    { 'Where', 560, 230 }, { 'Price', 800, 130 } }

function Browser.Cells(row)
    local first = row.sources[1]
    local where = first.name .. (#row.sources > 1 and (' (+' .. (#row.sources - 1) .. ')') or '')
    return { row.name, ns.NpcSources.Label(row.kind), row.skill and tostring(row.skill) or 'Unknown',
        row.trainer and 'Trainer' or 'Vendor', where, row.price and ns.NpcSources.Coin(row.price) or 'Unknown' }
end

local function text(parent, font, x, y, width)
    local fontString = parent:CreateFontString(nil, 'OVERLAY', font)
    fontString:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    fontString:SetWidth(width)
    fontString:SetJustifyH('LEFT')
    return fontString
end
local function button(parent, label, x, y, width, callback)
    local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    b:SetSize(width, 22)
    b:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    b:SetText(label)
    b:SetScript('OnClick', callback)
    return b
end

function Browser.Refresh()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    local rows, unread, pending = ns.NpcSources.Unlearned(ns.characterID, Browser.vendorOnly)
    local pages = math.max(1, math.ceil(#rows / ROWS))
    Browser.page = math.max(1, math.min(Browser.page, pages))
    w.filter:SetText(Browser.vendorOnly and 'Vendor only' or 'All unlearned')
    w.pageText:SetText(string.format('Page %d / %d, %d recipes', Browser.page, pages, #rows))
    for index = 1, ROWS do
        local line = w.lines[index]
        local row = rows[(Browser.page - 1) * ROWS + index]
        line.row = row
        if row then
            local cells = Browser.Cells(row)
            for i, value in ipairs(cells) do line.cells[i]:SetText(value) end
            line:Show()
        else line:Hide() end
    end
    local notes = {}
    if #unread > 0 then
        local names = {}
        for _, kind in ipairs(unread) do names[#names + 1] = ns.NpcSources.Label(kind) end
        notes[#notes + 1] = 'Recipes not yet read for this character: ' .. table.concat(names, ', ')
            .. '. Open each profession window once.'
    end
    if pending > 0 then notes[#notes + 1] = pending .. ' vendor recipes are still loading.' end
    w.footer:SetText(table.concat(notes, ' '))
end

function Browser.Show()
    local w = Browser.window
    if not w then
        local name = 'TitanGatheredForeverV3RecipeBrowserWindow'
        w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
        Browser.window = w
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        w:SetSize(960, 560)
        w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', function(self) self:StartMoving() end)
        w:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
        w:SetScript('OnHide', function() GameTooltip:Hide() end)
        w.TitleText:SetText('TGF v3 Unlearned recipes')
        local note = text(w, 'GameFontHighlightSmall', 15, -33, 930)
        note:SetText('Unlearned recipes with a known trainer or vendor source. Seed data is Classic and not confirmed in game until you visit the NPC. Click a row to open its map.')
        w.filter = button(w, 'All unlearned', 15, -65, 150, function()
            Browser.vendorOnly = not Browser.vendorOnly; Browser.page = 1; Browser.Refresh()
        end)
        button(w, 'Previous', 175, -65, 90, function() Browser.page = Browser.page - 1; Browser.Refresh() end)
        button(w, 'Next', 275, -65, 90, function() Browser.page = Browser.page + 1; Browser.Refresh() end)
        w.pageText = text(w, 'GameFontHighlightSmall', 380, -70, 300)
        local header = CreateFrame('Frame', nil, w)
        header:SetSize(930, 30); header:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -100)
        for _, column in ipairs(columns) do text(header, 'GameFontNormalSmall', column[2], 0, column[3]):SetText(column[1]) end
        w.lines = {}
        for index = 1, ROWS do
            local line = CreateFrame('Button', nil, w)
            line:SetSize(930, 22)
            line:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -132 - (index - 1) * 22)
            line.cells = {}
            for i, column in ipairs(columns) do line.cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3]) end
            line:SetScript('OnClick', function(self)
                local source = self.row and self.row.sources[1]
                local mapID = source and ns.NpcSources.ContinentMap(source.npcID)
                if mapID and OpenWorldMap then OpenWorldMap(mapID) end
            end)
            w.lines[index] = line
        end
        w.footer = text(w, 'GameFontHighlightSmall', 15, -520, 930)
    end
    w:Show()
    Browser.Refresh()
end
```

- [ ] **Step 6: Register, wire refresh, and add the test**

Add `RecipeBrowser.lua` after `CraftingView.lua` in the core `.toc`. Add `[runtime, 'tests/recipe_browser.lua'],` after `tests/npc_observer.lua` in `tools/check.py`.

In `Core.lua`, in the `ITEM_DATA_LOAD_RESULT` branch, after `ns.Reports.Refresh()` add `ns.RecipeBrowser.Refresh()`. In the slash handler add before `if command == 'refresh'`:
```lua
        if command == 'recipes' then ns.RecipeBrowser.Show(); return end
```
and add `/tgf recipes` to the help string.

- [ ] **Step 7: Run everything**

Run: `luajit tests/recipe_browser.lua && python3 tools/check.py`
Expected: `PASS recipe browser 4 checks`, then `PASS all shipped Lua files compile with Lua 5.1 semantics`.

- [ ] **Step 8: Commit (if authorized)**

```bash
git add TitanGatheredForeverV3 tests tools/check.py
git commit -m "Add unlearned recipes window" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Package LICENSE and NOTICE with the core addon

**Files:**
- Modify: `tools/package.py`, `tests/test_package.py`

The core addon folder contains the seed, so its ZIP must carry the GPL-3.0 license and the notice. They live once at the repository root and are copied into the archive as `TitanGatheredForeverV3/LICENSE` and `TitanGatheredForeverV3/NOTICE`. Profession addon ZIPs are unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_package.py` inside the existing test class (reuse the file's imports, `ROOT` and helper for building an archive; match the style of the neighbouring `test_core_only_package_has_no_profession_database`):

```python
    def test_core_package_carries_license_and_notice_but_professions_do_not(self):
        with tempfile.TemporaryDirectory() as directory:
            core = package.package(ROOT, Path(directory) / 'core.zip', addons=['TitanGatheredForeverV3'])
            with zipfile.ZipFile(core) as archive:
                names = archive.namelist()
                self.assertIn('TitanGatheredForeverV3/LICENSE', names)
                self.assertIn('TitanGatheredForeverV3/NOTICE', names)
                self.assertEqual(archive.read('TitanGatheredForeverV3/LICENSE'), (ROOT / 'LICENSE').read_bytes())
            mining = package.package(ROOT, Path(directory) / 'mining.zip', addons=['TitanGatheredForeverV3_Mining'])
            with zipfile.ZipFile(mining) as archive:
                self.assertFalse([n for n in archive.namelist() if n.endswith(('LICENSE', 'NOTICE'))])
```

If the test module names the packaging module differently (the file loads `tools/package.py` via `importlib`), use that name in place of `package`; add `import tempfile`, `import zipfile` and `from pathlib import Path` if they are missing.

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m unittest tests.test_package -v`
Expected: the new test FAILS (`LICENSE` not in archive).

- [ ] **Step 3: Implement**

In `tools/package.py`, `package()` currently collects `paths` as plain paths and names each archive entry with `path.relative_to(root)`. Change it to collect `(path, arcname)` pairs:

1. Replace `paths = []` with `paths = []  # (source path, archive name)` and change the `paths.append(path)` line inside the entry loop to:
```python
            paths.append((path, path.relative_to(root).as_posix()))
```
2. Directly after the `for entry in entries:` loop (still inside the outer `for name in ...` loop), add:
```python
        if name == 'TitanGatheredForeverV3':
            for notice in ('LICENSE', 'NOTICE'):
                source = root / notice
                if not source.is_file():
                    raise ValueError(f'Missing {notice} at the repository root')
                paths.append((source, f'TitanGatheredForeverV3/{notice}'))
```
3. Replace the archive-writing loop with:
```python
        for path, arcname in sorted(set(paths), key=lambda pair: pair[1]):
            info = zipfile.ZipInfo(arcname, (2026, 11, 6, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
```

- [ ] **Step 4: Run packaging, install and layout tests**

Run: `python3 -m unittest tests.test_package tests.test_install tests.test_repository_layout -v`
Expected: PASS. The install test copies from `package()`, so the installed core folder also gets `LICENSE` and `NOTICE`; the layout test inspects only the source folder and is unaffected. If a test asserts an exact installed file list, add the two files to its expectation.

- [ ] **Step 5: Commit (if authorized)**

```bash
git add tools/package.py tests/test_package.py
git commit -m "Ship license and notice with the core addon" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Version, full verification and automatic installation

**Files:**
- Modify: `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`, `tools/generate_catalog.py`, generated profession `.toc` files

AGENTS.md requires a patch increment, keeping the alpha suffix: `0.4.11-alpha` to `0.4.12-alpha`, synchronised across the core manifest, the generator `VERSION` and all generated profession manifests, before checks, installation and packaging.

- [ ] **Step 1: Bump versions**

```bash
sed -i '' 's/^## Version: 0.4.11-alpha$/## Version: 0.4.12-alpha/' TitanGatheredForeverV3/TitanGatheredForeverV3.toc
sed -i '' "s/^VERSION = '0.4.11-alpha'$/VERSION = '0.4.12-alpha'/" tools/generate_catalog.py
python3 tools/generate_catalog.py
grep -rn "0.4.11-alpha" --include='*.toc' --include='*.py' --include='*.lua' --include='*.json' . | grep -v '^./dist' | head
```
Expected: the `grep` prints nothing. If it prints a hit in a test or tool, update it to 0.4.12-alpha.

- [ ] **Step 2: Full automated checks**

Run: `python3 tools/check.py && python3 tools/generate_pin_outlines.py --check && python3 tools/audit_catalog.py --check`
Expected: every command exits 0 and `check.py` prints `PASS all shipped Lua files compile with Lua 5.1 semantics`. Do not continue past a failure. Report the test count.

- [ ] **Step 3: Preview the installation**

Run: `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'`
Expected: preview of 14 addons, no changes made. Check that `TitanGatheredForeverV3` lists the new files and `LICENSE` and `NOTICE`.

- [ ] **Step 4: Install**

AGENTS.md authorizes automatic installation of completed tested updates into the live game directory (not publishing or pushing). Run the same command with `--apply`:

`python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns' --apply`
Expected: installation completes and the backup folder path is printed under `Interface/.tgf-v3-backups/`. If the destination is missing or the sandbox blocks writing, report that clearly and stop; do not claim installation.

- [ ] **Step 5: Verify installed bytes against the source candidate**

Run:
```bash
A='/Applications/World of Warcraft/_forever_/Interface/AddOns/TitanGatheredForeverV3'
for f in Core.lua NpcSources.lua NpcObserver.lua KnownRecipes.lua RecipeBrowser.lua Data/NpcSeed.lua TitanGatheredForeverV3.toc; do cmp "TitanGatheredForeverV3/$f" "$A/$f" && echo "match $f"; done
cmp LICENSE "$A/LICENSE" && cmp NOTICE "$A/NOTICE" && echo "match notices"
```
Expected: `match` for every line. New files and a changed manifest need a full WoW client restart, not `/reload`. Tell the user this; do not close or restart their game.

- [ ] **Step 6: Commit (if authorized)**

```bash
git add -A TitanGatheredForeverV3* tools tests
git commit -m "Release 0.4.12-alpha with trainer and recipe vendor pins" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
Do not push, tag or publish release assets.

---

### Task 10: Documentation and live validation record

**Files:**
- Modify: `README.md`, `plan-npc-sources.md`, `plan-next-development.md`, `ref-wow-forever-progress.md`, `release-notes/ref-unreleased.md`

- [ ] **Step 1: Release notes**

At the top of the entries in `release-notes/ref-unreleased.md` (below the intro paragraph; also update the intro to say 0.4.12-alpha) add:

```markdown
## Trainers and recipe vendors, 0.4.12-alpha

- Optional map pins show profession trainers and recipe vendors on the world map and minimap. The menu has toggles for each, a per-profession filter and a switch for recording NPCs when their window opens.
- Vendor tooltips list recipes with the minimum profession level and price. Trainer tooltips list trainable recipes with skill and cost. Recipes you know are marked once the profession window has been read.
- A new Unlearned recipes window (menu, or /tgf recipes) lists unlearned recipes with a Trainer or Vendor source. A filter shows vendor-only recipes.
- Seed data comes from CMaNGOS classic-db (GPL-3.0, see NOTICE) and is labelled not yet confirmed in game until you visit the NPC. Observed data replaces seed data. Unknown skills and prices are shown as unknown.
- Packaging adds LICENSE and NOTICE to the core addon. New files require a full client restart.
- /tgf npc and /tgf npc swap help calibrate pin placement if the pins appear mirrored.
```

- [ ] **Step 2: README**

In `README.md`, under "Use TGF v3", add a short subsection "Trainers and recipe vendors" describing the toggles, the tooltip content, the Unlearned recipes window, the "not yet confirmed" labelling and `/tgf recipes`, `/tgf npc`. Keep the existing license section.

- [ ] **Step 3: Spec, roadmap and progress**

- In `plan-npc-sources.md`, update Status to "implemented in 0.4.12-alpha, live acceptance pending", apply the deviations listed at the top of this plan, add the file `NpcObserver.lua`, and link this plan.
- In `plan-next-development.md`, change the "designed, not implemented" milestone to "implemented and installed, live acceptance pending".
- In `ref-wow-forever-progress.md`, add an entry for 0.4.12-alpha with: the automated check count, the installed file verification result, the backup folder, and the seed file size recorded in Task 2 Step 3.

- [ ] **Step 4: Record the live validation gates (do not claim them passed)**

Add this checklist to `ref-wow-forever-progress.md` under the 0.4.12-alpha entry, as open items to be filled in after the owner restarts WoW:

```markdown
Live validation (open, separate from automated checks):
- [ ] Pins appear on the world map and minimap at plausible positions; /tgf npc names a nearby trainer; /tgf npc swap fixes mirrored placement if needed.
- [ ] Continent UiMapIDs 1414 (Kalimdor) and 1415 (Eastern Kingdoms) are correct for Forever.
- [ ] Opening a profession trainer stores profession, services, skill and cost (trainer API behaviour).
- [ ] Opening a recipe vendor stores recipe items with price and the required skill parsed from the tooltip.
- [ ] Opening each profession window marks recipes as known; the Unlearned recipes window reflects it.
- [ ] Tooltip text, the 15-line cap and the menu toggles behave as designed; no Lua errors with /console scriptErrors 1.
```

- [ ] **Step 5: Final check and commit (if authorized)**

Run: `python3 tools/check.py`
Expected: PASS. Then:
```bash
git add README.md plan-*.md ref-wow-forever-progress.md release-notes/ref-unreleased.md
git commit -m "Document trainer and recipe vendor feature and live validation gates" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-review against the spec

- Seed from pinned classic-db plus observation, observed wins: Tasks 1, 2, 3, 5.
- LICENSE and NOTICE, non-commercial statement, shipped in the core ZIP: Task 8 (files exist already).
- Menu toggles for trainers and vendors on the map, per-profession filter, recording toggle: Task 6 Step 7.
- Vendor tooltip with recipes, minimum skill, price, known marker, 15-line cap, unknown stays unknown: Task 3 (tests and code).
- Trainer tooltip with profession, skill and cost: Task 3.
- No instance pins: generator keeps continents 0 and 1 only (Task 1), observer skips instances (Task 5 adapter), unsupported continents skipped (Task 3 test).
- World-to-map conversion and its live gate; calibration command: Tasks 3, 6 Step 8, 10 Step 4.
- Unlearned recipes window, per profession, source column, all-versus-vendor-only filter, unread professions explicit: Task 7.
- Known-recipe recording with read time: Task 4.
- Version increment, installer, byte verification, restart note: Task 9.
- Documentation and separately recorded live results: Task 10.

Type and name consistency checked: `NpcSources.Record/Nodes/List/Visible/FillTooltip/Coin/Label/Kinds/Invalidate/Enabled/Nearest/ContinentMap/ItemRecipeName/Unlearned`, `KnownRecipes.Strip/Normalize/Record/IsKnown/ReadAt/Scan/Schedule`, `NpcObserver.NpcID/ParseRequirement/New/DefaultAPI` with methods `TrainerShown`/`MerchantShown`/`Save`, `RecipeBrowser.Cells/Refresh/Show`. Settings keys: `mapTrainers`, `mapRecipeVendors`, `recordNpcs`, `npcAxisSwap`, `mapNpcProfessions`; saved tables `npcs` and `knownRecipes`. Seed fields: `n m x y p t v`, trainer rows `{spell, name, cost, skill, outputItemID}`, vendor rows `{itemID, kind, price, skill}`.

Known residual risks, all explicit rather than hidden: Forever 1.60.1 trainer and merchant API behaviour, tooltip skill parsing, continent UiMapIDs and world axis order are unverified until live testing; seed recipe names are Classic names matched to client names by normalised text.
