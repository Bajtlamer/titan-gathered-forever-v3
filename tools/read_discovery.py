#!/usr/bin/env python3
"""Read Discovery saved variables, merge several contributors and compare them with the catalogue files.

The saved files are read as data only: a small parser accepts Lua table literals and nothing else, so a file can never
run code. Nothing is downloaded and nothing in the game or the catalogue is changed. The report lists observations with
their evidence; adding anything to catalogue/ stays a manual, reviewed step.
"""
import argparse
import functools
import hashlib
import json
import re
import sys
import tempfile
import zlib
from pathlib import Path

CATEGORIES = ('loot', 'npcs', 'vendors', 'entities', 'quests', 'areas', 'skills', 'recipes', 'maps')
SCHEMA = 1
VARIABLE = 'TitanGatheredForeverDiscoveryDB'
PROFESSIONS = ('Alchemy', 'Blacksmithing', 'Enchanting', 'Engineering', 'Herbalism', 'Leatherworking', 'Mining',
               'Skinning', 'Tailoring', 'Cooking', 'Fishing', 'First Aid')
MAX_BYTES = 1 << 30
MAX_DEPTH = 64
NOTE = 'These are unverified observations, not catalogue facts. Adding anything to the catalogue is a manual, reviewed step.'


# ---------------------------------------------------------------------------------------------------------------------
# A parser for Lua table literals (saved variables). It accepts data and nothing else.

NUMBER = re.compile(r'-?(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)')
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', 'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v', '\\': '\\', '"': '"', "'": "'", '\n': '\n'}


class Parser:
    def __init__(self, text):
        self.text, self.pos, self.size = text, 0, len(text)

    def fail(self, message):
        raise ValueError(f'Invalid Lua data: {message} at offset {self.pos}')

    def skip(self):
        text = self.text
        while self.pos < self.size:
            char = text[self.pos]
            if char in ' \t\r\n':
                self.pos += 1
            elif text.startswith('--', self.pos):
                block = re.match(r'--\[(=*)\[', text[self.pos:self.pos + 40])
                if block:
                    end = text.find(']' + block.group(1) + ']', self.pos)
                    if end < 0:
                        self.fail('unterminated comment')
                    self.pos = end + len(block.group(1)) + 2
                else:
                    newline = text.find('\n', self.pos)
                    self.pos = self.size if newline < 0 else newline + 1
            else:
                return

    def expect(self, char):
        self.skip()
        if self.pos >= self.size or self.text[self.pos] != char:
            self.fail(f'expected {char!r}')
        self.pos += 1

    def string(self):
        quote, out = self.text[self.pos], bytearray()
        self.pos += 1
        while self.pos < self.size:
            char = self.text[self.pos]
            if char == quote:
                self.pos += 1
                return out.decode('utf-8', 'surrogateescape')
            if char == '\\':
                self.pos += 1
                if self.pos >= self.size:
                    break
                escaped = self.text[self.pos]
                digits = re.match(r'\d{1,3}', self.text[self.pos:self.pos + 3])
                if digits:
                    code = int(digits.group(0))
                    if code > 255:
                        self.fail('invalid escape')
                    out.append(code)
                    self.pos += len(digits.group(0))
                    continue
                if escaped not in ESCAPES:
                    self.fail('invalid escape')
                out += ESCAPES[escaped].encode()
                self.pos += 1
                continue
            out += char.encode('utf-8', 'surrogateescape')
            self.pos += 1
        self.fail('unterminated string')

    def number(self):
        match = NUMBER.match(self.text, self.pos)
        if not match:
            self.fail('invalid number')
        self.pos = match.end()
        raw = match.group(0)
        if re.fullmatch(r'-?0[xX][0-9a-fA-F]+', raw):
            return int(raw, 16)
        if re.fullmatch(r'-?\d+', raw):
            return int(raw)
        return float(raw)

    def value(self, depth):
        self.skip()
        if self.pos >= self.size:
            self.fail('missing value')
        char = self.text[self.pos]
        if char == '{':
            return self.table(depth + 1)
        if char in '"\'':
            return self.string()
        if char in '-.0123456789':
            return self.number()
        match = IDENT.match(self.text, self.pos)
        if match and match.group(0) in ('true', 'false', 'nil'):
            self.pos = match.end()
            return {'true': True, 'false': False, 'nil': None}[match.group(0)]
        self.fail('only literals are allowed')

    def table(self, depth):
        if depth > MAX_DEPTH:
            self.fail('nesting is too deep')
        self.pos += 1
        result, index = {}, 1
        while True:
            self.skip()
            if self.pos >= self.size:
                self.fail('unterminated table')
            char = self.text[self.pos]
            if char == '}':
                self.pos += 1
                return result
            if char == '[':
                self.pos += 1
                key = self.value(depth)
                self.expect(']')
                self.expect('=')
                value = self.value(depth)
                if key is None:
                    self.fail('nil key')
                if value is not None:
                    result[key] = value
            else:
                match = IDENT.match(self.text, self.pos)
                after = self.text[match.end():].lstrip(' \t\r\n') if match else ''
                if match and after.startswith('=') and not after.startswith('=='):
                    self.pos = match.end()
                    self.expect('=')
                    value = self.value(depth)
                    if value is not None:
                        result[match.group(0)] = value
                else:
                    value = self.value(depth)
                    if value is not None:
                        result[index] = value
                    index += 1
            self.skip()
            if self.pos < self.size and self.text[self.pos] in ',;':
                self.pos += 1


def parse_lua(text):
    """The assignments of a saved variables file as a dict of Python values (tables become dicts)."""
    parser = Parser(text)
    result = {}
    while True:
        parser.skip()
        if parser.pos >= parser.size:
            return result
        match = re.compile(r'[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*').match(text, parser.pos)
        if not match:
            parser.fail('expected a variable name')
        parser.pos = match.end()
        parser.expect('=')
        result[match.group(0)] = parser.value(0)


def to_lists(value):
    if not isinstance(value, dict):
        return value
    converted = {key: to_lists(inner) for key, inner in value.items()}
    if converted and all(isinstance(key, int) for key in converted) and sorted(converted) == list(range(1, len(converted) + 1)):
        return [converted[key] for key in range(1, len(converted) + 1)]
    return converted


def parse_seed(text):
    """The NPC table of the generated Data/NpcSeed.lua: ID to record, with lists for sequences."""
    marker = text.find('ns.NpcSeed')
    if marker < 0:
        raise ValueError('The NPC seed file has no ns.NpcSeed table')
    parser = Parser(text)
    parser.pos = marker + len('ns.NpcSeed')
    parser.expect('=')
    seed = parser.value(0)
    npcs = seed.get('npcs') if isinstance(seed, dict) else None
    if not isinstance(npcs, dict):
        raise ValueError('The NPC seed has no npcs table')
    return {key: to_lists(value) for key, value in npcs.items()}


# ---------------------------------------------------------------------------------------------------------------------
# Checksums, written exactly like the module does (see ref-discovery-data-format.md).

def lua_string(value):
    out = ['"']
    for char in value:
        if char == '"':
            out.append('\\"')
        elif char == '\\':
            out.append('\\\\')
        elif char == '\n':
            out.append('\\\n')
        elif char == '\r':
            out.append('\\r')
        elif char == '\0':
            out.append('\\000')
        else:
            out.append(char)
    out.append('"')
    return ''.join(out)


def lua_text(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return '%.14g' % value
    return str(value)


def lua_less(a, b):
    numeric = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool)
    if (numeric(a) and numeric(b)) or (isinstance(a, str) and isinstance(b, str)):
        return a < b
    return lua_text(a) < lua_text(b)


def sorted_keys(mapping):
    def compare(a, b):
        return -1 if lua_less(a, b) else (1 if lua_less(b, a) else 0)
    return sorted(mapping, key=functools.cmp_to_key(compare))


def canonical(value):
    if isinstance(value, dict):
        return '{' + ''.join(canonical(key) + '=' + canonical(value[key]) + ',' for key in sorted_keys(value)) + '}'
    if isinstance(value, str):
        return lua_string(value)
    return lua_text(value)


def adler32_hex(data):
    return '%08x' % (zlib.adler32(data) & 0xffffffff)


def category_checksum(bucket):
    text = ''.join(canonical(key) + '=' + canonical(bucket[key]) + ';' for key in sorted_keys(bucket))
    return adler32_hex(text.encode('utf-8', 'surrogateescape'))


def total_checksum(checksums):
    return adler32_hex(','.join(checksums[category] for category in CATEGORIES).encode())


# ---------------------------------------------------------------------------------------------------------------------
# Reading a contribution.

def walk_strings(value, visit, path=''):
    if isinstance(value, str):
        visit(value, path)
    elif isinstance(value, dict):
        for key in sorted_keys(value):
            child = f'{path}/{key}'
            if isinstance(key, str):
                visit(key, child)
            walk_strings(value[key], visit, child)


def load_contribution(path, label=None):
    path = Path(path)
    if path.stat().st_size > MAX_BYTES:
        raise ValueError(f'{path.name} is too large')
    label = label or path.stem
    try:
        parsed = parse_lua(path.read_text(encoding='utf-8', errors='surrogateescape'))
    except ValueError as error:
        raise ValueError(f'{path.name}: {error}')
    db = parsed.get(VARIABLE)
    if not isinstance(db, dict):
        raise ValueError(f'{path.name} has no {VARIABLE} table')
    meta, consent, data = db.get('meta'), db.get('consent'), db.get('data')
    if not isinstance(meta, dict) or type(meta.get('schemaVersion')) is not int:
        raise ValueError(f'{path.name} has no schema version')
    if meta['schemaVersion'] > SCHEMA:
        raise ValueError(f'{path.name} was written by a newer schema ({meta["schemaVersion"]}); update this tool')
    if not isinstance(data, dict):
        raise ValueError(f'{path.name} has no data table')
    if not isinstance(consent, dict) or consent.get('accepted') is not True:
        raise ValueError(f'{path.name} holds data without an accepted notice; it is not used')
    for category in CATEGORIES:
        if not isinstance(data.get(category), dict):
            data[category] = {}
    offenders = []

    def visit(text, where):
        if re.search(r'Player-\d', text) or re.match(r'Pet-\d', text):
            offenders.append(where)

    for category in CATEGORIES:
        walk_strings(data[category], visit, category)
    if offenders:
        raise ValueError(f'{path.name} contains private values (player or pet GUIDs), first at {offenders[0]}; it is not used')
    warnings, stamp = [], 'none'
    export = db.get('export')
    if isinstance(export, dict) and isinstance(export.get('checksums'), dict):
        checksums = {category: category_checksum(data[category]) for category in CATEGORIES}
        if checksums == export['checksums'] and total_checksum(checksums) == export.get('checksum'):
            stamp = 'verified'
        else:
            stamp = 'changed since the export'
            warnings.append(f'{label}: the data changed since the export, or the saved numbers differ in the last digits')
    builds = sorted({str(key) for key in (meta.get('builds') or {})})
    return {
        'label': label, 'db': db, 'moduleVersion': meta.get('moduleVersion'), 'schemaVersion': meta['schemaVersion'],
        'builds': builds, 'client': meta.get('client') if isinstance(meta.get('client'), dict) else {},
        'records': sum(len(data[category]) for category in CATEGORIES), 'stamp': stamp, 'warnings': warnings,
    }


# ---------------------------------------------------------------------------------------------------------------------
# Merging several contributions.

COUNT_TOP = {'seen', 'offered', 'taken', 'unsourced', 'accepted', 'turnedIn', 'scans'}
COUNT_PATTERNS = (re.compile(r'^(services|sources|areas|lootSources)/[^/]+$'), re.compile(r'^goods/[^/]+/seen$'))
NEAR, MAX_POSITIONS = 0.01, 5


def is_count(path):
    return path in COUNT_TOP or any(pattern.match(path) for pattern in COUNT_PATTERNS)


def union_positions(values):
    positions = []
    for table in values:
        for key in sorted_keys(table):
            spot = table[key]
            if not isinstance(spot, dict):
                continue
            if any(known['mapID'] == spot.get('mapID') and abs(known['x'] - spot['x']) < NEAR and abs(known['y'] - spot['y']) < NEAR
                   for known in positions):
                continue
            if len(positions) < MAX_POSITIONS:
                positions.append(spot)
    return {index + 1: spot for index, spot in enumerate(positions)}


def merge_dicts(dicts, path, conflicts):
    merged = {}
    keys = {}
    for table in dicts:
        for key in table:
            keys[key] = None
    for key in sorted_keys(keys):
        values = [table[key] for table in dicts if key in table]
        where = f'{path}/{key}' if path else str(key)
        if not path and key in ('firstBuild', 'lastBuild'):
            continue
        if all(isinstance(value, dict) for value in values):
            if key == 'positions' and not path:
                merged[key] = union_positions(values)
            else:
                merged[key] = merge_dicts(values, where, conflicts)
        elif is_count(where) and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in values):
            merged[key] = sum(values)
        elif not path and key == 'first' and all(isinstance(v, (int, float)) for v in values):
            merged[key] = min(values)
        elif not path and key == 'last' and all(isinstance(v, (int, float)) for v in values):
            merged[key] = max(values)
        else:
            counts = {}
            for value in values:
                text = json.dumps(value, sort_keys=True, default=str)
                counts[text] = counts.get(text, 0) + 1
            best = max(counts, key=lambda text: counts[text])
            first_best = next(text for text in counts if counts[text] == counts[best])
            merged[key] = next(value for value in values if json.dumps(value, sort_keys=True, default=str) == first_best)
            if len(counts) > 1:
                conflicts.append({'path': where, 'values': counts})
    return merged


def merge(contributions):
    """category -> key -> {fields, conflicts, contributors, builds}; contributors are used in label order."""
    ordered = sorted(contributions, key=lambda item: item['label'])
    result = {}
    for category in CATEGORIES:
        keys = {}
        for contribution in ordered:
            for key in contribution['db']['data'].get(category, {}):
                keys[key] = None
        merged = {}
        for key in sorted_keys(keys):
            sources = [(c['label'], c['db']['data'][category][key]) for c in ordered if key in c['db']['data'].get(category, {})]
            records = [record for _, record in sources if isinstance(record, dict)]
            conflicts = []
            builds = sorted({str(record[name]) for record in records for name in ('firstBuild', 'lastBuild') if name in record})
            merged[key] = {'fields': merge_dicts(records, '', conflicts), 'conflicts': sorted(conflicts, key=lambda c: c['path']),
                           'contributors': [label for label, _ in sources], 'builds': builds}
        result[category] = merged
    return result


# ---------------------------------------------------------------------------------------------------------------------
# The baseline: the catalogue files of the repository.

def normalize(name):
    return re.sub(r'\s+', '', str(name)).lower()


class Baseline:
    FILES = ('catalogue/forever-recipes.json', 'catalogue/verified-recipes.json', 'catalogue/legacy-items.json',
             'catalogue/module-membership.json', 'TitanGatheredForever/Data/NpcSeed.lua')

    def __init__(self, root):
        root = Path(root)
        self.hashes = {}
        for relative in self.FILES:
            path = root / relative
            if not path.is_file():
                raise ValueError(f'Baseline file is missing: {relative}')
            self.hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        read = lambda name: json.loads((root / name).read_text(encoding='utf-8'))
        self.recipes = {}
        for recipe in read('catalogue/forever-recipes.json')['recipes'] + read('catalogue/verified-recipes.json'):
            self.recipes[recipe['spellID']] = recipe
        self.legacy_names = {row['itemID']: row['name'] for row in read('catalogue/legacy-items.json')}
        self.gatherable = set(self.legacy_names) | {row['itemID'] for row in read('catalogue/module-membership.json')}
        self.items = set(self.gatherable)
        for recipe in self.recipes.values():
            if recipe.get('outputItemID'):
                self.items.add(recipe['outputItemID'])
            self.items.update(reagent['itemID'] for reagent in recipe.get('reagents', []))
        self.seed = parse_seed((root / 'TitanGatheredForever/Data/NpcSeed.lua').read_text(encoding='utf-8'))


def classify_loot(key, fields, baseline):
    if key not in baseline.items:
        return 'new', 'Not in the catalogue files (the catalogue is not complete).', []
    name, legacy = fields.get('name'), baseline.legacy_names.get(key)
    if isinstance(name, str) and legacy and name != legacy:
        return 'different', 'The name differs from the legacy item list.', [{'field': 'name', 'baseline': legacy, 'observed': name}]
    return 'unchanged', 'In the catalogue files.', []


def classify_recipe(key, fields, baseline):
    base = baseline.recipes.get(key)
    if base is None:
        return 'new', 'Not in the catalogue recipe files (the catalogue is not complete).', []
    details = []
    profession = fields.get('profession')
    if profession and base.get('profession') and normalize(profession) != normalize(base['profession']):
        details.append({'field': 'profession', 'baseline': base['profession'], 'observed': profession})
    output = fields.get('outputItemID')
    if output is not None and base.get('outputItemID') is not None and output != base['outputItemID']:
        details.append({'field': 'output', 'baseline': base['outputItemID'], 'observed': output})
    observed = to_lists(fields.get('reagents') or {})
    if observed and base.get('reagents'):
        base_pairs = {(r['itemID'], r['quantity']) for r in base['reagents']}
        slots = []
        for slot in observed:
            items = to_lists(slot.get('items') or {})
            slots.append((slot.get('quantity'), items if isinstance(items, list) else []))
        observed_pairs = {(item, quantity) for quantity, items in slots for item in items}
        unmatched_slot = any(not any((item, quantity) in base_pairs for item in items) for quantity, items in slots)
        if base_pairs - observed_pairs or unmatched_slot:
            details.append({'field': 'reagent', 'baseline': sorted(base_pairs), 'observed': sorted(observed_pairs)})
    if details:
        return 'different', 'The profession, the product or the reagents differ from the catalogue.', details
    return 'unchanged', 'In the catalogue recipe files.', []


def classify_npc(key, fields, baseline):
    seed = baseline.seed.get(key)
    if not seed:
        return 'unbaselined', 'The NPC seed holds only profession trainers and recipe vendors; see vendors and trainers.', []
    name = fields.get('name')
    if isinstance(name, str) and seed.get('n') and name != seed['n']:
        return 'different', 'The name differs from the seed.', [{'field': 'name', 'baseline': seed['n'], 'observed': name}]
    return 'unchanged', 'In the NPC seed.', []


def classify_vendor(key, fields, baseline):
    goods, taught = fields.get('goods') or {}, fields.get('taught') or {}
    seed = baseline.seed.get(key)
    if not seed:
        if any(row.get('skillName') in PROFESSIONS for row in taught.values() if isinstance(row, dict)):
            return 'new', 'A profession trainer that is not in the NPC seed.', []
        return 'unbaselined', 'Goods and lessons of this NPC have no baseline in the seed.', []
    details = []
    if seed.get('v') and goods:
        for row in seed['v']:
            item = goods.get(row[0])
            if item is None:
                details.append({'field': 'notOffered', 'itemID': row[0]})
            elif row[2] and row[2] > 0 and item.get('price') and item['price'] != row[2]:
                details.append({'field': 'price', 'itemID': row[0], 'baseline': row[2], 'observed': item['price']})
    if seed.get('t') and taught:
        by_name = {row[1]: row for row in seed['t']}
        for name in sorted_keys(taught):
            row, seeded = taught[name], by_name.get(name)
            if seeded is None:
                if row.get('skillName') in PROFESSIONS:
                    details.append({'field': 'notInSeed', 'name': name})
            else:
                if row.get('cost') is not None and row['cost'] != seeded[2]:
                    details.append({'field': 'cost', 'name': name, 'baseline': seeded[2], 'observed': row['cost']})
                if row.get('skillRank') and seeded[3] > 0 and row['skillRank'] != seeded[3]:
                    details.append({'field': 'skill', 'name': name, 'baseline': seeded[3], 'observed': row['skillRank']})
        for row in seed['t']:
            if row[1] not in taught:
                details.append({'field': 'notTaught', 'name': row[1]})
    if details:
        return 'different', 'Goods or lessons differ from the NPC seed.', details
    return 'unchanged', 'Equal to the NPC seed in everything compared.', []


def classify_skill(key, fields, baseline):
    if key in PROFESSIONS:
        return 'unchanged', 'One of the known professions.', []
    return 'new', 'Not one of the twelve known professions.', []


def classify_unbaselined(key, fields, baseline):
    return 'unbaselined', 'No baseline in the catalogue files; kept for review.', []


CLASSIFIERS = {'loot': classify_loot, 'npcs': classify_npc, 'vendors': classify_vendor, 'skills': classify_skill,
               'recipes': classify_recipe, 'areas': classify_unbaselined, 'maps': classify_unbaselined,
               'quests': classify_unbaselined, 'entities': classify_unbaselined}
STATES = ('new', 'different', 'unchanged', 'unbaselined')


def evidence(contributors, builds):
    if len(contributors) > 1 and len(builds) > 1:
        return 'several contributors and builds'
    if len(contributors) > 1:
        return 'several contributors'
    if len(builds) > 1:
        return 'several builds'
    return 'one contributor'


def jsonable(value):
    if isinstance(value, dict):
        value = to_lists(value)
    if isinstance(value, dict):
        return {str(key): jsonable(inner) for key, inner in value.items()}
    if isinstance(value, list):
        return [jsonable(inner) for inner in value]
    return value


def build_report(contributions, root):
    contributions = sorted(contributions, key=lambda item: item['label'])
    baseline = Baseline(root)
    merged = merge(contributions)
    categories, totals = {}, {state: 0 for state in STATES}
    for category in CATEGORIES:
        rows, counts = [], {state: 0 for state in STATES}
        for key in sorted_keys(merged[category]):
            entry = merged[category][key]
            fields = entry['fields']
            state, why, details = CLASSIFIERS[category](key, fields, baseline)
            name = fields.get('name') or fields.get('title')
            if category == 'vendors' and key in merged['npcs']:
                name = merged['npcs'][key]['fields'].get('name') or name
            counts[state] += 1
            totals[state] += 1
            rows.append({'category': category, 'key': key, 'name': name, 'state': state, 'why': why, 'details': details,
                         'contributors': entry['contributors'], 'builds': entry['builds'],
                         'evidence': evidence(entry['contributors'], entry['builds']), 'seen': fields.get('seen'),
                         'first': fields.get('first'), 'last': fields.get('last'), 'conflicts': entry['conflicts'],
                         'fields': jsonable(fields)})
        counts['total'] = len(rows)
        categories[category] = {'counts': counts, 'rows': rows}
    totals['total'] = sum(totals[state] for state in STATES)
    observed_npcs = set(merged['npcs']) | set(merged['vendors'])
    report = {
        'tool': 'read_discovery', 'schema': 1, 'note': NOTE,
        'inputs': [{'label': c['label'], 'moduleVersion': c['moduleVersion'], 'schemaVersion': c['schemaVersion'],
                    'builds': c['builds'], 'client': jsonable(c['client']), 'records': c['records'], 'stamp': c['stamp'],
                    'warnings': c['warnings']} for c in contributions],
        'merged': {'contributors': [c['label'] for c in contributions],
                   'builds': sorted({build for c in contributions for build in c['builds']})},
        'baseline': {'files': baseline.hashes, 'seedNpcs': len(baseline.seed), 'recipes': len(baseline.recipes),
                     'items': len(baseline.items)},
        'summary': totals,
        'notSeen': {'items': len(baseline.gatherable - set(merged['loot'])), 'npcs': len(set(baseline.seed) - observed_npcs)},
        'categories': categories,
    }
    return json.loads(json.dumps(report, default=str))


# ---------------------------------------------------------------------------------------------------------------------

def validate_output(root, output, inputs):
    output = Path(output).resolve()
    if output in {Path(path).resolve() for path in inputs}:
        raise ValueError('The report would overwrite an input file')
    for runtime in Path(root).resolve().glob('TitanGatheredForever*'):
        if runtime.is_dir() and (output == runtime or runtime in output.parents):
            raise ValueError('The report must not be written into a runtime folder')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', nargs='+', type=Path, help='SavedVariables files of the Discovery module, one per contributor')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, help='Write the deterministic JSON report here (use a tmp- name or a ref- file)')
    parser.add_argument('--strict', action='store_true', help='Fail when an export stamp does not match its data')
    args = parser.parse_args()
    try:
        output = validate_output(args.root, args.output, args.inputs) if args.output else None
        contributions = [load_contribution(path) for path in args.inputs]
        labels = [c['label'] for c in contributions]
        if len(set(labels)) != len(labels):
            raise ValueError('Two input files have the same name; rename one so contributors stay apart')
        if args.strict and any(c['stamp'] == 'changed since the export' for c in contributions):
            raise ValueError('An export stamp does not match its data')
        report = build_report(contributions, args.root)
        if output:
            content = json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + '\n'
            output.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix='tmp-discovery-report-', dir=output.parent) as directory:
                staged = Path(directory) / 'report.json'
                staged.write_text(content, encoding='utf-8')
                staged.replace(output)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'Discovery report failed: {error}\n')
    summary = report['summary']
    print(f"Read {len(contributions)} file(s): {summary['new']} new, {summary['different']} different, "
          f"{summary['unchanged']} unchanged, {summary['unbaselined']} without baseline.")
    for category in CATEGORIES:
        counts = report['categories'][category]['counts']
        if counts['total']:
            print(f"  {category}: {counts['new']} new, {counts['different']} different, {counts['unchanged']} unchanged, "
                  f"{counts['unbaselined']} without baseline")
    for contribution in contributions:
        for warning in contribution['warnings']:
            print(f'Warning: {warning}')
    print(f"Not seen: {report['notSeen']['items']} catalogue items and {report['notSeen']['npcs']} seed NPCs.")
    print(NOTE)


if __name__ == '__main__':
    main()
