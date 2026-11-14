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
