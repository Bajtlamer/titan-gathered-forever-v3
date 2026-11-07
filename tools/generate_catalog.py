#!/usr/bin/env python3
"""Validate numeric recipe facts and reproducibly generate the addon catalogue."""
import argparse
import hashlib
import json
from pathlib import Path

PROFESSIONS = {'Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering',
               'First Aid', 'Fishing', 'Herbalism', 'Leatherworking', 'Mining', 'Skinning', 'Tailoring'}
MODULE_IDS = {'First Aid': 'FirstAid', 'Herbalism': 'Herbs'}
VERSION = '0.4.1-alpha'
MINING_ORES = {2770, 2771, 2772, 2775, 2776, 3858, 7911, 10620, 11370, 18562}
SCARCE_MINERALS = {249391, 249425, 249426}
SCARCE_HERBS = {249274, 249399, 249424}


def positive(value, label):
    if type(value) is not int or value <= 0:
        raise ValueError(f'{label} must be a positive integer: {value!r}')


def build_catalog(dataset, curated):
    if dataset.get('schema') != 1 or dataset.get('clientVersion') != '1.60.1':
        raise ValueError('Expected schema 1 and Forever version 1.60.1')
    items, seen = {}, set()

    def item(item_id):
        positive(item_id, 'itemID')
        return items.setdefault(item_id, {'professions': set(), 'recipes': set(), 'uses': []})

    for recipe in dataset['recipes']:
        spell_id = recipe['spellID']
        positive(spell_id, 'spellID')
        if spell_id in seen:
            raise ValueError(f'Duplicate spellID {spell_id}')
        seen.add(spell_id)
        profession = recipe['profession']
        if profession not in PROFESSIONS:
            raise ValueError(f'Unsupported profession: {profession}')
        if recipe.get('outputItemID') is not None:
            positive(recipe['outputItemID'], 'outputItemID')
        reagent_ids = set()
        for reagent in recipe['reagents']:
            positive(reagent['quantity'], 'quantity')
            record = item(reagent['itemID'])
            if reagent['itemID'] in reagent_ids:
                raise ValueError(f'Duplicate reagent in {spell_id}')
            reagent_ids.add(reagent['itemID'])
            record['professions'].add(profession)
            record['recipes'].add(spell_id)
    for use in curated:
        if use.get('kind') not in {'auction', 'supply'}:
            raise ValueError('Curated use requires an auction or supply kind')
        if not isinstance(use.get('reason'), str) or not use['reason'].strip():
            raise ValueError('Curated use requires a reason')
        if not str(use.get('evidence', '')).startswith('https://'):
            raise ValueError('Curated use requires evidence')
        if use['kind'] == 'auction' and use.get('auctionable') is not True:
            raise ValueError('Auction-only entry must have verified auction eligibility')
        item(use['itemID'])['uses'].append(use)
    for record in items.values():
        record['professions'] = sorted(record['professions'])
        record['recipes'] = sorted(record['recipes'])
        record['uses'].sort(key=lambda use: (use['kind'], use['reason']))
    return dict(sorted(items.items()))


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return '{' + ','.join(f'[{lua(k)}]={lua(value[k])}' for k in sorted(value)) + '}'


def build_modules(dataset, curated, memberships):
    """Produce optional publisher addons, retaining one identity per item."""
    items = build_catalog(dataset, curated)
    recipes = {r['spellID']: r for r in dataset['recipes']}
    modules = {}
    for profession in sorted(PROFESSIONS):
        module_id = MODULE_IDS.get(profession, profession)
        selected = {reagent['itemID'] for recipe in recipes.values()
                    if recipe['profession'] == profession for reagent in recipe['reagents']}
        for member in memberships:
            if member['module'] != module_id:
                continue
            positive(member['itemID'], 'membership itemID')
            if not member.get('evidence'):
                raise ValueError('Gathering membership requires evidence')
            if member['itemID'] not in items:
                raise ValueError('Gathering membership has no supported item use')
            selected.add(member['itemID'])
        if selected:
            modules[module_id] = {'id': module_id, 'label': profession, 'kind': 'profession',
                                  'folder': 'TitanGatheredForeverV3_' + module_id,
                                  'items': {item_id: items[item_id] for item_id in sorted(selected)}}
    auction_ids = {use['itemID'] for use in curated if use['kind'] == 'auction'}
    if auction_ids:
        modules['Auction'] = {'id': 'Auction', 'label': 'Auction items', 'kind': 'auction',
                              'folder': 'TitanGatheredForeverV3_Auction',
                              'items': {i: items[i] for i in sorted(auction_ids)}}
    for module in modules.values():
        if module['id'] == 'Mining':
            module['gatheringResources'] = {i: 0 if i in MINING_ORES else 1
                for i in module['items'] if i in MINING_ORES | SCARCE_MINERALS}
        elif module['id'] == 'Herbs':
            module['gatheringResources'] = {i: 1 if i in SCARCE_HERBS else 0 for i in module['items']}
        elif module['id'] == 'Skinning':
            module['gatheringResources'] = {i: 0 for i in module['items']}
        for item_id, record in list(module['items'].items()):
            counts = {}
            for recipe_id in record['recipes']:
                profession = recipes[recipe_id]['profession']
                counts[profession] = counts.get(profession, 0) + 1
            module['items'][item_id] = {
                'professions': record['professions'], 'recipeCounts': counts,
                'recipes': record['recipes'][:2], 'uses': record['uses'],
            }
        relevant = {recipe_id for record in module['items'].values() for recipe_id in record['recipes']}
        # The UI only needs recipe identity and consuming profession. Full
        # reagent/source records stay in the build inputs rather than game memory.
        module['recipes'] = {i: {'profession': recipes[i]['profession']} for i in sorted(relevant)}
    return dict(sorted(modules.items()))


def generate(root, check=False):
    source_path = root / 'catalogue/forever-recipes.json'
    dataset = json.loads(source_path.read_text())
    supplements = json.loads((root / 'catalogue/verified-recipes.json').read_text())
    for recipe in supplements:
        if not str(recipe.get('evidence', '')).startswith('https://www.wowhead.com/forever/spell='):
            raise ValueError('Supplementary recipe requires exact Forever spell evidence')
    dataset['recipes'].extend(supplements)
    curated = json.loads((root / 'catalogue/curated-uses.json').read_text())
    items = build_catalog(dataset, curated)
    memberships = json.loads((root / 'catalogue/module-membership.json').read_text())
    modules = build_modules(dataset, curated, memberships)
    recipes = {r['spellID']: r for r in dataset['recipes']}
    source_hash = hashlib.sha256(b'\n'.join((root / path).read_bytes() for path in
        ['catalogue/forever-recipes.json', 'catalogue/verified-recipes.json', 'catalogue/curated-uses.json',
         'catalogue/module-membership.json'])).hexdigest()
    metadata = {key: dataset.get(key) for key in
                ['clientVersion', 'targetBuild', 'sourceBuild', 'complete', 'retrieved', 'source']}
    metadata.update(recipeCount=len(recipes), itemCount=len(items), sourceSHA256=source_hash)
    header = '-- Generated by tools/generate_catalog.py. Do not edit.\nlocal _, ns = ...\n'
    outputs = {
        'TitanGatheredForeverV3/Data/Metadata.lua': header + 'ns.DataMetadata = ' + lua(metadata) + '\n',
    }
    module_index = []
    for module in modules.values():
        folder = module['folder']
        payload = {key: value for key, value in module.items() if key != 'folder'}
        outputs[folder + '/Data.lua'] = ('-- Generated by tools/generate_catalog.py. Do not edit.\n'
            'TitanGatheredForeverV3.Catalog.RegisterModule(' + lua(payload) + ')\n')
        outputs[folder + '/' + folder + '.toc'] = (
            f'## Interface: 16001\n## Title: Titan Gathered Forever v3: {module["label"]}\n'
            f'## Notes: Optional {module["label"]} material catalogue for Titan Gathered Forever v3.\n'
            f'## Version: {VERSION}\n## Dependencies: Titan, TitanGatheredForeverV3\n\nData.lua\n')
        module_index.append({key: module[key] for key in ['id', 'label', 'kind', 'folder']} |
                            {'itemCount': len(module['items']), 'recipeCount': len(module['recipes'])})
    outputs['catalogue/modules.json'] = json.dumps(module_index, indent=2) + '\n'
    legacy = json.loads((root / 'catalogue/legacy-items.json').read_text())
    old_ids = sorted({row['itemID'] for row in legacy})
    audit = {
        'sourceSHA256': source_hash, 'complete': False,
        'oldUniqueIDs': len(old_ids), 'catalogueIDs': len(items),
        'addedIDs': sorted(set(items) - set(old_ids)),
        'legacy': [{'itemID': i, 'status': 'present-in-forever-evidence' if i in items else 'unresolved',
                    'names': sorted({r['name'] for r in legacy if r['itemID'] == i})} for i in old_ids],
        'limits': ['Source mirror does not state its exact extraction build.',
                   'Client-table existence does not prove live obtainability.',
                   'Output-free enchantments and gathering/camping uses need independent coverage.',
                   'Unmatched legacy IDs are not proof of unavailability.'],
    }
    outputs['catalogue/catalog-audit.json'] = json.dumps(audit, indent=2, sort_keys=True) + '\n'
    for path, content in outputs.items():
        target = root / path
        if check:
            if not target.exists() or target.read_text() != content:
                raise ValueError(f'Stale generated file: {path}')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    return metadata


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = generate(Path(__file__).resolve().parents[1], args.check)
    print(f"Catalogue: {result['itemCount']} item IDs, {result['recipeCount']} recipe relationships; live completeness unverified.")
