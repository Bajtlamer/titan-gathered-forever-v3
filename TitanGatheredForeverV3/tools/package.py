#!/usr/bin/env python3
"""Build the modular addon bundle and individual addon downloads."""
import argparse
import hashlib
import shutil
import tempfile
import importlib.util
import json
import re
import zipfile
from pathlib import Path


def addon_names(root):
    return ['TitanGatheredForeverV3'] + [row['folder'] for row in json.loads((root / 'catalogue/modules.json').read_text())]


def default_target(root, version, addon=None):
    if addon:
        return root / f'dist/modules/{addon}-{version}.zip'
    return root / f'dist/TitanGatheredForeverV3-{version}.zip'


def package(root, target, addons=None):
    allowed = addon_names(root)
    paths = []
    for name in (allowed if addons is None else addons):
        if name not in allowed:
            raise ValueError(f'Unknown addon: {name}')
        addon = root.parent / name
        manifest = addon / (name + '.toc')
        entries = [line.strip() for line in manifest.read_text().splitlines()
                   if line.strip() and not line.startswith('#')]
        entries.append(name + '.toc')
        if name == 'TitanGatheredForeverV3':
            entries.append('Artwork/TitanOre.tga')
        for entry in entries:
            path = addon / entry
            if not path.resolve().is_relative_to(addon.resolve()) or not path.is_file():
                raise ValueError(f'Invalid addon file: {entry}')
            paths.append(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(set(paths)):
            info = zipfile.ZipInfo(path.relative_to(root.parent).as_posix(), (2026, 11, 6, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    return target


def stage_release(root, version, output=None):
    """Build a clean upload directory from manifest-allowlisted runtime files."""
    if not re.fullmatch(r'[0-9][a-zA-Z0-9.-]*', version):
        raise ValueError('Invalid release version')
    for name in addon_names(root):
        toc = (root.parent / name / (name + '.toc')).read_text()
        if f'## Version: {version}\n' not in toc:
            raise ValueError(f'Version mismatch in {name}')
    target = output or root / 'dist/releases' / version
    if target.is_symlink():
        raise ValueError('Release directory must not be a symlink')
    target.parent.mkdir(parents=True, exist_ok=True)
    modules = json.loads((root / 'catalogue/modules.json').read_text())
    records = [{'id': 'collection', 'label': 'Complete collection', 'type': 'collection',
                'file': f'TitanGatheredForeverV3-{version}.zip', 'requires': ['Titan']},
               {'id': 'TitanGatheredForeverV3', 'label': 'Shared core', 'type': 'core',
                'file': f'TitanGatheredForeverV3-{version}-core.zip', 'requires': ['Titan']}]
    records.extend({'id': row['folder'], 'label': row['label'],
                    'type': 'profession' if row['kind'] == 'profession' else 'additional',
                    'file': f'{row["folder"]}-{version}.zip',
                    'requires': ['Titan', 'TitanGatheredForeverV3']} for row in modules)
    with tempfile.TemporaryDirectory(prefix='.release-', dir=target.parent) as directory:
        staged = Path(directory) / 'upload'
        staged.mkdir()
        for row in records:
            archive = staged / row['file']
            package(root, archive, addons=None if row['type'] == 'collection' else [row['id']])
            row['bytes'] = archive.stat().st_size
            row['sha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
        index = {'schema': 1, 'version': version, 'client': 'WoW Forever', 'interface': 16001,
                 'downloads': records}
        (staged / 'downloads.json').write_text(json.dumps(index, indent=2) + '\n')
        checksums = [hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.name
                     for path in sorted(staged.iterdir())]
        (staged / 'SHA256SUMS').write_text('\n'.join(checksums) + '\n')
        if target.exists():
            shutil.rmtree(target)
        staged.rename(target)
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--addon', help='Package only this addon folder; otherwise also build separate downloads.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    spec = importlib.util.spec_from_file_location('generate_catalog', root / 'tools/generate_catalog.py')
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    generator.generate(root, check=True)
    toc = (root / 'TitanGatheredForeverV3.toc').read_text()
    version = re.search(r'^## Version: ([a-zA-Z0-9.-]+)$', toc, re.M).group(1)
    target = args.output or default_target(root, version, args.addon)
    print(package(root, target, addons=[args.addon] if args.addon else None))
    if not args.addon:
        for addon in addon_names(root):
            package(root, root / f'dist/modules/{addon}-{version}.zip', addons=[addon])
        print(f'Built {len(addon_names(root))} individual addon downloads under dist/modules/.')
        print('Website/GitHub upload directory: ' + str(stage_release(root, version)))
