#!/usr/bin/env python3
"""Validate numeric recipe facts and reproducibly generate the addon catalogue."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

PROFESSIONS = {'Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering',
               'First Aid', 'Fishing', 'Herbalism', 'Leatherworking', 'Mining', 'Skinning', 'Tailoring'}
MODULE_IDS = {'First Aid': 'FirstAid', 'Herbalism': 'Herbs'}
VERSION = '0.5.2-beta'
MINING_ORES = {2770, 2771, 2772, 2775, 2776, 3858, 7911, 10620, 11370, 18562}
SCARCE_MINERALS = {249391, 249425, 249426}
SCARCE_HERBS = {249274, 249399, 249424}


def positive(value, label):
    if type(value) is not int or value <= 0:
        raise ValueError(f'{label} must be a positive integer: {value!r}')


def validate_memberships(memberships, legacy=None, supported=None):
    known = {MODULE_IDS.get(p, p) for p in PROFESSIONS}
    seen = set()
    for row in memberships:
        positive(row['itemID'], 'membership itemID')
        key = (row['module'], row['itemID'])
        if row['module'] not in known or key in seen:
            raise ValueError(f'Unknown or duplicate membership: {key}')
        seen.add(key)
        if supported is not None and row['itemID'] not in supported:
            raise ValueError(f'Membership has no supported item use: {key}')
        evidence = row.get('evidence')
        if not isinstance(evidence, str):
            raise ValueError('Membership requires traceable evidence')
        prefix = 'catalogue/legacy-items.json#'
        if evidence.startswith(prefix):
            fragment = evidence[len(prefix):]
            if not fragment or '..' in fragment.split('/'):
                raise ValueError('Invalid legacy provenance fragment')
            if legacy is not None and not any(r['itemID'] == row['itemID'] and r['file'] == fragment for r in legacy):
                raise ValueError(f'Legacy provenance does not identify this item/file: {key}')
        else:
            url = urlsplit(evidence)
            if url.scheme != 'https' or not url.hostname:
                raise ValueError('Membership evidence must be HTTPS or an exact legacy reference')


def validate_supplements(supplements):
    for recipe in supplements:
        positive(recipe['spellID'], 'supplement spellID')
        evidence = recipe.get('evidence')
        match = re.fullmatch(r'https://www\.wowhead\.com/forever/spell=([1-9][0-9]*)(?:/[a-z0-9-]+)?', evidence or '')
        if not match or int(match[1]) != recipe['spellID']:
            raise ValueError('Supplementary recipe requires evidence for its exact Forever spell ID')


def recipe_facts_hash(recipes):
    facts = [{'spellID': r['spellID'], 'outputItemID': r.get('outputItemID'), 'profession': r['profession'],
              'reagents': sorted(r['reagents'], key=lambda reagent: reagent['itemID'])}
             for r in sorted(recipes, key=lambda r: r['spellID'])]
    return hashlib.sha256(json.dumps(facts, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def parse_recipe_mirror(text):
    """Read the mirror's delimited numeric rows without executing Lua."""
    professions = re.findall(r'\bprofessions\s*=\s*\{([^{}]*)\}', text)
    blocks = re.findall(r'\brecipes\s*=\s*\{(.*?)\n\s*\}', text, re.S)
    if len(professions) != 1 or len(blocks) != 1:
        raise ValueError('Expected one mirror professions/recipes table')
    names = json.loads('[' + professions[0] + ']')
    if not names or len(set(names)) != len(names) or any(name not in PROFESSIONS for name in names):
        raise ValueError('Invalid mirror profession mapping')
    recipes = []
    for line in blocks[0].splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'\s*"([0-9;:,]+)",?\s*', line)
        if not match:
            raise ValueError('Mirror recipe row is not numeric data')
        fields = match[1].split(';')
        if len(fields) != 8:
            raise ValueError('Mirror recipe row has the wrong field count')
        output, minimum, maximum, index, yellow, grey, spell = map(int, fields[:7])
        if not (output > 0 and minimum > 0 and maximum >= minimum and 1 <= index <= len(names)):
            raise ValueError('Invalid mirror output quantities/profession')
        reagents = []
        for reagent in fields[7].split(','):
            pair = reagent.split(':')
            if len(pair) != 2:
                raise ValueError('Invalid mirror reagent pair')
            item, quantity = map(int, pair)
            reagents.append({'itemID': item, 'quantity': quantity})
        recipes.append({'spellID': spell, 'outputItemID': output,
                        'profession': names[index - 1], 'reagents': reagents})
    build_catalog({'schema': 1, 'clientVersion': '1.60.1', 'recipes': recipes}, [])
    return recipes


def validate_source_evidence(dataset, evidence):
    if evidence.get('schema') != 1:
        raise ValueError('Expected source-evidence schema 1')
    mirror = evidence['recipeMirror']
    for field, size in [('commit', 40), ('sha256', 64), ('numericRecipeSHA256', 64)]:
        if not isinstance(mirror.get(field), str) or not re.fullmatch('[0-9a-f]{' + str(size) + '}', mirror[field]):
            raise ValueError(f'Invalid pinned mirror {field}')
    url = urlsplit(mirror.get('url', ''))
    if url.scheme != 'https' or not url.hostname:
        raise ValueError('Pinned mirror requires an HTTPS URL')
    if (mirror.get('recipeCount') != len(dataset['recipes'])
            or mirror['numericRecipeSHA256'] != recipe_facts_hash(dataset['recipes'])
            or mirror.get('sourceBuild') != dataset.get('sourceBuild')):
        raise ValueError('Pinned recipe provenance does not match captured numeric facts/build')
    return mirror


def verify_recipe_mirror(content, dataset, evidence):
    mirror = validate_source_evidence(dataset, evidence)
    if hashlib.sha256(content).hexdigest() != mirror['sha256']:
        raise ValueError('Mirror bytes do not match the pinned SHA-256')
    if recipe_facts_hash(parse_recipe_mirror(content.decode('utf-8'))) != mirror['numericRecipeSHA256']:
        raise ValueError('Mirror numeric facts differ from the captured snapshot')


CLIENT_TABLES = {'SkillLineAbility', 'SpellEffect', 'SpellReagents', 'ItemSparse'}
CLIENT_SKILLS = {171: 'Alchemy', 164: 'Blacksmithing', 185: 'Cooking', 333: 'Enchanting',
                 202: 'Engineering', 129: 'First Aid', 165: 'Leatherworking', 186: 'Mining', 197: 'Tailoring'}


def validate_client_table_evidence(dataset, proof):
    if (proof.get('product') != 'wowf' or proof.get('clientVersion') != '1.60.1'
            or not isinstance(proof.get('build'), str) or not re.fullmatch(r'[1-9][0-9]*', proof['build'])
            or proof.get('method') != 'create-item-reagents-v1'
            or proof.get('recipeCount') != len(dataset['recipes'])
            or proof.get('numericRecipeSHA256') != recipe_facts_hash(dataset['recipes'])
            or set(proof.get('tables', {})) != CLIENT_TABLES):
        raise ValueError('Client-table evidence does not identify matching base recipe facts')
    version = proof['clientVersion'] + '.' + proof['build']
    for table, record in proof['tables'].items():
        if (record.get('responseFilename') != f'{table}.{version}.csv'
                or record.get('url') != f'https://wago.tools/db2/{table}/csv?product=wowf&build={version}'
                or not isinstance(record.get('sha256'), str)
                or not re.fullmatch('[0-9a-f]{64}', record['sha256'])):
            raise ValueError(f'Invalid pinned client-table attribution: {table}')


def extract_client_table_recipes(directory):
    """Reconstruct the mirror's scoped item-output subset from inert CSV data."""
    def rows(table):
        with (directory / (table + '.csv')).open(encoding='utf-8-sig', newline='') as source:
            return list(csv.DictReader(source))

    def unique(mapping, key, value):
        if key in mapping and mapping[key] != value:
            raise ValueError(f'Conflicting client-table records for spell {key}')
        mapping[key] = value

    outputs = {}
    for row in rows('SpellEffect'):
        if int(row['Effect']) == 24 and int(row['EffectItemType']) > 0:
            unique(outputs, int(row['SpellID']), int(row['EffectItemType']))
    reagents = {}
    for row in rows('SpellReagents'):
        values = [{'itemID': int(row[f'Reagent_{i}']), 'quantity': int(row[f'ReagentCount_{i}'])}
                  for i in range(8) if int(row[f'Reagent_{i}']) > 0 and int(row[f'ReagentCount_{i}']) > 0]
        unique(reagents, int(row['SpellID']), sorted(values, key=lambda r: r['itemID']))
    items = {int(row['ID']) for row in rows('ItemSparse')}
    recipes = {}
    for row in rows('SkillLineAbility'):
        spell, skill = int(row['Spell']), int(row['SkillLine'])
        if (skill in CLIENT_SKILLS and int(row['TradeSkillCategoryID']) > 0
                and outputs.get(spell) in items and reagents.get(spell)):
            unique(recipes, spell, {'spellID': spell, 'outputItemID': outputs[spell],
                                   'profession': CLIENT_SKILLS[skill], 'reagents': reagents[spell]})
    result = [recipes[spell] for spell in sorted(recipes)]
    build_catalog({'schema': 1, 'clientVersion': '1.60.1', 'recipes': result}, [])
    return result


def verify_client_tables(directory, dataset, proof):
    validate_client_table_evidence(dataset, proof)
    for table, record in proof['tables'].items():
        if hashlib.sha256((directory / (table + '.csv')).read_bytes()).hexdigest() != record['sha256']:
            raise ValueError(f'{table} bytes do not match the pinned SHA-256')
    recipes = extract_client_table_recipes(directory)
    if len(recipes) != proof['recipeCount'] or recipe_facts_hash(recipes) != proof['numericRecipeSHA256']:
        raise ValueError('Client-table recipe facts differ from the base snapshot')


def build_reconciliation(dataset, supplements, curated, memberships, legacy, target, evidence):
    mirror = validate_source_evidence(dataset, evidence)
    client_tables = evidence.get('clientTables')
    if client_tables is not None:
        validate_client_table_evidence(dataset, client_tables)
    if (target.get('schema') != 1 or target.get('product') != 'wowf'
            or target.get('clientVersion') != '1.60.1'
            or not isinstance(target.get('build'), str) or not re.fullmatch(r'[1-9][0-9]*', target['build'])
            or target.get('expectedInterface') != 16001
            or target.get('evidence') != 'installation-metadata' or target.get('liveInterfaceVerified') is not False):
        raise ValueError('Expected explicit installation metadata and unverified live interface')
    source_build = dataset.get('sourceBuild')
    if source_build is not None and (not isinstance(source_build, str) or not re.fullmatch(r'[1-9][0-9]*', source_build)):
        raise ValueError('Source build must be explicit numeric build evidence or null')
    validate_supplements(supplements)
    combined = dict(dataset, recipes=dataset['recipes'] + supplements)
    items = build_catalog(combined, curated)
    validate_memberships(memberships, legacy, items)
    old_ids = {r['itemID'] for r in legacy}
    professions = {MODULE_IDS.get(p, p): {'label': p, 'recipes': 0, 'outputFreeRecipes': 0, 'memberships': 0}
                   for p in sorted(PROFESSIONS)}
    producers = {}
    for recipe in combined['recipes']:
        module = MODULE_IDS.get(recipe['profession'], recipe['profession'])
        professions[module]['recipes'] += 1
        if recipe.get('outputItemID') is None:
            professions[module]['outputFreeRecipes'] += 1
        else:
            producers.setdefault(recipe['outputItemID'], []).append(recipe)
    counts = {'legacyReference': 0, 'foreverReference': 0, 'otherHttpsReference': 0}
    review = []
    for row in memberships:
        professions[row['module']]['memberships'] += 1
        link = row['evidence']
        kind = ('legacyReference' if link.startswith('catalogue/legacy-items.json#')
                else 'foreverReference' if link.startswith('https://www.wowhead.com/forever/')
                else 'otherHttpsReference')
        counts[kind] += 1
        recipes = producers.get(row['itemID'], [])
        if recipes and not any(MODULE_IDS.get(r['profession'], r['profession']) == row['module'] for r in recipes):
            review.append({'module': row['module'], 'itemID': row['itemID'],
                           'recipeProducers': sorted({r['profession'] for r in recipes}),
                           'recipeIDs': sorted(r['spellID'] for r in recipes),
                           'status': 'review-only-not-proof-of-wrong-membership'})
    return {
        'schema': 1, 'complete': False, 'declaredSourceComplete': dataset.get('complete') is True,
        'buildEvidence': {'targetBuild': target['build'], 'clientVersion': target['clientVersion'],
                          'expectedInterface': target['expectedInterface'], 'liveInterfaceVerified': False,
                          'datasetTargetBuild': dataset.get('targetBuild'),
                          'datasetTargetMatches': dataset.get('targetBuild') == target['build'],
                          'sourceBuild': source_build,
                          'sourceBuildMatch': 'unknown' if source_build is None else 'match' if source_build == target['build'] else 'mismatch'},
        'recipeMirror': dict(mirror), 'clientTableCrosscheck': client_tables,
        'recipeCount': len(combined['recipes']), 'itemCount': len(items),
        'professions': professions, 'membershipEvidence': counts,
        'legacy': {'presentIDs': sorted(old_ids & set(items)), 'unresolvedIDs': sorted(old_ids - set(items)),
                   'addedIDs': sorted(set(items) - old_ids)},
        'producerReview': sorted(review, key=lambda r: (r['module'], r['itemID'])),
        'gates': {'recipeBuildKnown': source_build is not None, 'recipeBuildMatchesTarget': source_build == target['build'],
                  'baseRecipeFactsCrosscheckedForTarget': client_tables is not None and client_tables['build'] == target['build'],
                  'liveObtainabilityVerified': False, 'allLegacyIDsResolved': old_ids <= set(items),
                  'producerMembershipsFullyVerified': False, 'outputFreeEnchantingCoverageComplete': False},
        'limits': ['Version-only mirror provenance does not identify the extraction build.',
                   'Matching numeric facts or a source build does not prove live obtainability.',
                   'Configured profession modules do not certify current profession availability.',
                   'Fishing memberships are a partial seed, not all fish/catches.',
                   'Producer review candidates are retained, not automatically removed.',
                   'Auction/supply usefulness and full output-free enchanting coverage remain incomplete.'],
    }


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


RECONCILIATION_INPUTS = [
    'catalogue/forever-recipes.json', 'catalogue/verified-recipes.json', 'catalogue/curated-uses.json',
    'catalogue/module-membership.json', 'catalogue/legacy-items.json', 'catalogue/target-client.json',
    'catalogue/source-evidence.json',
]


def reconciliation_for_root(root):
    values = [json.loads((root / path).read_text(encoding='utf-8')) for path in RECONCILIATION_INPUTS]
    report = build_reconciliation(*values)
    report['inputSHA256'] = {path: hashlib.sha256((root / path).read_bytes()).hexdigest()
                            for path in RECONCILIATION_INPUTS}
    return report


def validate_reconciliation_output(root, output):
    expected = root.resolve() / 'catalogue/reconciliation.json'
    output = output.expanduser().absolute()
    if output.is_symlink() or expected.is_symlink():
        raise ValueError('Reconciliation output must not be a symlink')
    if output.exists():
        if not output.is_file() or output.resolve() != expected:
            raise ValueError('Refusing to overwrite a file other than the generated reconciliation report')
        if any(output.samefile(root / path) for path in RECONCILIATION_INPUTS):
            raise ValueError('Reconciliation output aliases a source evidence file')
    return output


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
    validate_memberships(memberships, supported=items)
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
    source_dataset = json.loads(source_path.read_text())
    dataset = dict(source_dataset, recipes=list(source_dataset['recipes']))
    supplements = json.loads((root / 'catalogue/verified-recipes.json').read_text())
    validate_supplements(supplements)
    dataset['recipes'].extend(supplements)
    curated = json.loads((root / 'catalogue/curated-uses.json').read_text())
    items = build_catalog(dataset, curated)
    memberships = json.loads((root / 'catalogue/module-membership.json').read_text())
    legacy = json.loads((root / 'catalogue/legacy-items.json').read_text())
    reconciliation = reconciliation_for_root(root)
    modules = build_modules(dataset, curated, memberships)
    recipes = {r['spellID']: r for r in dataset['recipes']}
    source_hash = hashlib.sha256(b'\n'.join((root / path).read_bytes() for path in
        ['catalogue/forever-recipes.json', 'catalogue/verified-recipes.json', 'catalogue/curated-uses.json',
         'catalogue/module-membership.json'])).hexdigest()
    metadata = {key: dataset.get(key) for key in
                ['clientVersion', 'targetBuild', 'sourceBuild', 'complete', 'retrieved', 'source']}
    metadata.update(recipeCount=len(recipes), itemCount=len(items), sourceSHA256=source_hash, complete=reconciliation['complete'])
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
    outputs['catalogue/reconciliation.json'] = json.dumps(reconciliation, indent=2, sort_keys=True) + '\n'
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
    if not check:
        validate_reconciliation_output(root, root / 'catalogue/reconciliation.json')
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
