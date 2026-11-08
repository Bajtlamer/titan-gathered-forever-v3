#!/usr/bin/env python3
"""Audit captured catalogue evidence without downloading, executing Lua or changing the game."""
import argparse
import importlib.util
import json
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location('tgf_catalogue_generator', Path(__file__).with_name('generate_catalog.py'))
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--check', action='store_true', help='Fail if the generated reconciliation report is stale')
    action.add_argument('--output', type=Path, help='Write the generated report, or a new report file')
    parser.add_argument('--mirror-file', type=Path, help='Additionally verify local mirror bytes and numeric facts')
    parser.add_argument('--client-tables', type=Path, help='Verify four local, pinned build-specific CSV tables')
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.mirror_file or args.client_tables:
            data = json.loads((root / 'catalogue/forever-recipes.json').read_text(encoding='utf-8'))
            evidence = json.loads((root / 'catalogue/source-evidence.json').read_text(encoding='utf-8'))
        if args.mirror_file:
            generator.verify_recipe_mirror(args.mirror_file.read_bytes(), data, evidence)
        if args.client_tables:
            generator.verify_client_tables(args.client_tables, data, evidence['clientTables'])
        report = generator.reconciliation_for_root(root)
        content = json.dumps(report, indent=2, sort_keys=True) + '\n'
        expected = root / 'catalogue/reconciliation.json'
        if args.check and (not expected.is_file() or expected.read_text(encoding='utf-8') != content):
            raise ValueError('Stale catalogue/reconciliation.json; regenerate from reviewed evidence')
        if args.output:
            output = generator.validate_reconciliation_output(root, args.output)
            output.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix='tmp-catalogue-audit-', dir=output.parent) as directory:
                staged = Path(directory) / 'report.json'
                staged.write_text(content, encoding='utf-8')
                staged.replace(output)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'Catalogue audit failed: {error}\n')
    if args.mirror_file:
        print('Pinned mirror verified: bytes and normalized numeric recipe facts match.')
    if args.client_tables:
        print('Pinned client tables verified: bytes and scoped base recipe facts match.')
    build = report['buildEvidence']
    print(f"Catalogue: {report['itemCount']} items / {report['recipeCount']} recipes; "
          f"target {build['targetBuild']}; source build {build['sourceBuildMatch']}; complete: false.")
    print(f"{len(report['legacy']['unresolvedIDs'])} unresolved legacy IDs; "
          f"{report['membershipEvidence']['legacyReference']} inherited memberships; "
          f"Fishing {report['professions']['Fishing']['memberships']} materials; "
          f"{len(report['producerReview'])} producer associations require review.")


if __name__ == '__main__':
    main()
