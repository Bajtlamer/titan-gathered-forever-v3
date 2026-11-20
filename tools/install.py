#!/usr/bin/env python3
"""Preview or install a runtime-only candidate into an explicit Interface/AddOns."""
import argparse
import importlib.util
import tempfile
import zipfile
from pathlib import Path

spec = importlib.util.spec_from_file_location('tgf_packager', Path(__file__).with_name('package.py'))
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)

state_spec = importlib.util.spec_from_file_location('addon_install_state', Path(__file__).with_name('install_state.py'))
state_tools = importlib.util.module_from_spec(state_spec)
state_spec.loader.exec_module(state_tools)

def legacy_names(names):
    result = {}
    for name in names:
        old = name.replace('TitanGatheredForever', 'TitanGatheredForeverV3', 1)
        old = old.replace('_Herbalism', '_Herbs').replace('_AuctionItems', '_Auction')
        result[old] = name
    return result



def legacy_for(root, names):
    """Old-name folders and state are migrated only when the whole published set is installed."""
    return legacy_names(names) if names == packager.addon_names(root) else {}


def validate(root, destination, names=None):
    root = Path(root).resolve()
    destination = Path(destination).expanduser()
    if destination.is_symlink():
        raise ValueError('AddOns destination must not be a symlink')
    destination = destination.resolve()
    if (not destination.is_dir() or destination.name != 'AddOns'
            or destination.parent.name != 'Interface'):
        raise ValueError('Destination must be an existing Interface/AddOns directory')
    if destination.is_relative_to(root) or root.is_relative_to(destination):
        raise ValueError('Source and AddOns destination must not overlap')
    if names is None:
        names = packager.addon_names(root)
    elif not names or not set(names) <= set(packager.standalone_names(root)):
        raise ValueError('Only standalone modules can be installed on their own')
    names = list(names)
    for name in names + list(legacy_for(root, names)):
        if Path(name).name != name or not name.startswith('TitanGatheredForever'):
            raise ValueError(f'Invalid addon folder: {name}')
        target = destination / name
        if target.is_symlink() or (target.exists() and not target.is_dir()):
            raise ValueError(f'Installed addon must be a regular directory: {target}')
    backups = destination.parent / '.tgf-v3-backups'
    if backups.is_symlink() or (backups.exists() and not backups.is_dir()):
        raise ValueError(f'Backup location must be a regular directory: {backups}')
    return root, destination, names


def install(root, destination, apply=False, names=None):
    """Return the preview, or install with retained backups and failure rollback.

    names=None installs the whole published set; a list of standalone modules installs only those and touches nothing else."""
    root, destination, names = validate(root, destination, names)
    legacy = legacy_for(root, names)
    selection = None if names == packager.addon_names(root) else names
    if apply and any((destination / name).exists() for name in legacy):
        state_tools.ensure_game_closed(destination.parent.parent)
    state = state_tools.StateMigration(destination, legacy)
    result = {'destination': destination, 'addons': names, 'backup': None, 'state_files': len(state.changes)}
    if not apply:
        # Validate all package inputs even in preview, without writing to the client.
        with tempfile.TemporaryDirectory(prefix='tgf-preview-') as directory:
            packager.package(root, Path(directory) / 'candidate.zip', addons=selection)
        return result

    if state.changes or any((destination / name).exists() for name in legacy):
        state_tools.ensure_game_closed(destination.parent.parent)
    lock = destination.parent / '.tgf-v3-install-lock'
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError(f'Installation lock exists: {lock}') from None
    try:
        with tempfile.TemporaryDirectory(prefix='.tgf-stage-', dir=destination.parent) as directory:
            stage = Path(directory)
            archive = packager.package(root, stage / 'candidate.zip', addons=selection)
            candidate = stage / 'candidate'
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(candidate)
            # Validate again after staging, before replacing any installed folders.
            validate(root, destination, names if selection else None)
            backups = destination.parent / '.tgf-v3-backups'
            backups.mkdir(exist_ok=True)
            backup = Path(tempfile.mkdtemp(prefix='candidate-', dir=backups))
            result['backup'] = backup
            moved, placed = [], []
            try:
                for name in names + list(legacy):
                    target = destination / name
                    if target.exists():
                        target.rename(backup / name)
                        moved.append(name)
                for name in names:
                    (candidate / name).rename(destination / name)
                    placed.append(name)
                state.apply(backup)
            except BaseException:
                try:
                    state.rollback()
                    for name in reversed(placed):
                        (destination / name).rename(candidate / name)
                    for name in reversed(moved):
                        (backup / name).rename(destination / name)
                except BaseException as recovery_error:
                    raise RuntimeError(
                        f'Automatic recovery failed. Retained original folders: {backup}. '
                        f'Recovery error: {recovery_error}') from recovery_error
                raise
    finally:
        lock.rmdir()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--addons-dir', type=Path, required=True,
                        help='Existing Forever client Interface/AddOns directory')
    parser.add_argument('--apply', action='store_true', help='Install; default is preview only')
    parser.add_argument('--standalone-only', action='store_true',
                        help='Install only the standalone modules (Discovery) and leave every other folder untouched')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        names = packager.standalone_names(root) if args.standalone_only else None
        result = install(root, args.addons_dir, apply=args.apply, names=names)
    except (ValueError, OSError, RuntimeError) as error:
        parser.exit(1, f'Installation failed: {error}\n')
    print(('Installed' if args.apply else 'Preview') + f': {result["destination"]}')
    for name in result['addons']:
        operation = 'replace' if (result['destination'] / name).exists() else 'add'
        print(f'  {name}' if args.apply else f'  {operation}: {name}')
    if result['state_files']:
        print(f"Saved-file/enablement migrations: {result['state_files']} (originals retained)")
    if result['backup']:
        print(f'Previous addon folders: {result["backup"]}')
    else:
        print('No installation changes made. Use --apply to install this candidate.')


if __name__ == '__main__':
    main()
