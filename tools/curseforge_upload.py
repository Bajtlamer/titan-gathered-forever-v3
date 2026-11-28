#!/usr/bin/env python3
"""Upload the files of a release to the CurseForge projects (the author upload API).

    python3 tools/curseforge_upload.py versions            # the game versions CurseForge knows (read only)
    python3 tools/curseforge_upload.py plan                # what would be uploaded (no network write)
    python3 tools/curseforge_upload.py upload --apply      # upload, one file per project

The author upload token is read from the .env file of the curseforge folder (CF_UPLOAD_TOKEN) and is never printed. The
project IDs are the ones in curseforge/ref-curseforge-project-ids.md. The core ZIP goes to the main project and every
module ZIP to its own project, as `release` files for the game version given with --game-version.
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = 'https://wow.curseforge.com/api'
ENV = ROOT.parent / 'curseforge' / '.env'
LEDGER = ROOT.parent / 'curseforge' / 'ref-uploaded-files.json'   # every file the tool sent: a file under review is not visible in the API

# Project IDs of ref-curseforge-project-ids.md. folder: (project id, slug)
PROJECTS = {
    'TitanGatheredForever': (1810955, 'titan-gathered-forever'),
    'TitanGatheredForever_Alchemy': (1811017, 'titan-gathered-forever-alchemy'),
    'TitanGatheredForever_AuctionItems': (1811077, 'titan-gathered-forever-auction-items'),
    'TitanGatheredForever_Blacksmithing': (1811028, 'titan-gathered-forever-blacksmithing'),
    'TitanGatheredForever_Cooking': (1811032, 'titan-gathered-forever-cooking'),
    'TitanGatheredForever_Enchanting': (1811035, 'titan-gathered-forever-enchanting'),
    'TitanGatheredForever_Engineering': (1811041, 'titan-gathered-forever-engineering'),
    'TitanGatheredForever_FirstAid': (1811046, 'titan-gathered-forever-first-aid'),
    'TitanGatheredForever_Fishing': (1811051, 'titan-gathered-forever-fishing'),
    'TitanGatheredForever_Herbalism': (1811057, 'titan-gathered-forever-herbalism'),
    'TitanGatheredForever_Leatherworking': (1811063, 'titan-gathered-forever-leatherworking'),
    'TitanGatheredForever_Mining': (1811065, 'titan-gathered-forever-mining'),
    'TitanGatheredForever_Skinning': (1811070, 'titan-gathered-forever-skinning'),
    'TitanGatheredForever_Tailoring': (1811072, 'titan-gathered-forever-tailoring'),
}


def token():
    for line in ENV.read_text().splitlines():
        match = re.match(r'^\s*CF_UPLOAD_TOKEN\s*=\s*(.*?)\s*$', line)
        if match:
            return match.group(1).strip('\'"')
    raise SystemExit('CF_UPLOAD_TOKEN is not in ' + str(ENV))


def request(path, data=None, headers=None):
    req = urllib.request.Request(API + path, data=data, headers={'X-Api-Token': token(), **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=120) as reply:
            return json.loads(reply.read().decode() or 'null')
    except urllib.error.HTTPError as error:
        body = error.read().decode(errors='replace')[:400]
        raise SystemExit('HTTP %s from %s: %s' % (error.code, path, body))


def already_sent(ledger, project, name):
    try:
        return name in json.loads(ledger.read_text()).get(str(project), {})
    except (OSError, ValueError):
        return False


def record_sent(ledger, project, name, file_id):
    try:
        data = json.loads(ledger.read_text())
    except (OSError, ValueError):
        data = {}
    data.setdefault(str(project), {})[name] = file_id
    ledger.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')


def version(root):
    match = re.search(r'^## Version:\s*(\S+)', (root / 'TitanGatheredForever/TitanGatheredForever.toc').read_text(), re.M)
    return match.group(1)


def files_for(release_dir, release):
    """folder -> ZIP of the release directory."""
    found = {}
    for folder in PROJECTS:
        name = '%s-%s-core.zip' % (folder, release) if folder == 'TitanGatheredForever' else '%s-%s.zip' % (folder, release)
        path = release_dir / name
        if not path.is_file():
            raise SystemExit('Missing ' + str(path))
        found[folder] = path
    return found


def changelog(folder, release, notes, root=ROOT):
    if folder == 'TitanGatheredForever':
        return notes
    # A module that changed in this release has its own notes: release-notes/ref-<version>-<folder>.md
    own = Path(root) / 'release-notes' / f'ref-{release}-{folder}.md'
    if own.is_file():
        return own.read_text()
    return ('Version number aligned with the Titan Gathered Forever core %s. The catalogue data of this module is '
            'unchanged. Requires the core of the same version; Titan Panel is optional.' % release)


def multipart(metadata, path):
    boundary = uuid.uuid4().hex
    parts = [
        b'--' + boundary.encode() + b'\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'
        + json.dumps(metadata).encode() + b'\r\n',
        b'--' + boundary.encode() + b'\r\nContent-Disposition: form-data; name="file"; filename="' + path.name.encode()
        + b'"\r\nContent-Type: application/zip\r\n\r\n' + path.read_bytes() + b'\r\n',
        b'--' + boundary.encode() + b'--\r\n',
    ]
    return b''.join(parts), 'multipart/form-data; boundary=' + boundary


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command', choices=('versions', 'plan', 'upload'))
    parser.add_argument('--release-dir', type=Path)
    parser.add_argument('--game-version', type=int, action='append', help='game version ID (see the versions command)')
    parser.add_argument('--release-type', default='release', choices=('alpha', 'beta', 'release'))
    parser.add_argument('--apply', action='store_true', help='really upload (upload only)')
    parser.add_argument('--only', action='append', help='folder name, repeat for several (default: all)')
    args = parser.parse_args()
    if args.command == 'versions':
        for row in request('/game/versions'):
            print(row['id'], row.get('gameVersionTypeID'), row.get('name'))
        return
    release = version(ROOT)
    release_dir = args.release_dir or ROOT / 'dist' / 'releases' / release
    files = files_for(release_dir, release)
    notes = (ROOT / 'release-notes' / ('ref-%s.md' % release)).read_text()
    if not args.game_version:
        raise SystemExit('Give --game-version <id> (run the versions command and pick the WoW Forever entry).')
    selected = [folder for folder in PROJECTS if not args.only or folder in args.only]
    for folder in selected:
        project, slug = PROJECTS[folder]
        metadata = {'changelog': changelog(folder, release, notes), 'changelogType': 'markdown',
                    'displayName': '%s %s' % (folder.replace('_', ': ', 1).replace('TitanGatheredForever', 'Titan Gathered Forever', 1)
                                              if folder != 'TitanGatheredForever' else 'Titan Gathered Forever', release),
                    'gameVersions': args.game_version, 'releaseType': args.release_type}
        if folder != 'TitanGatheredForever':
            metadata['relations'] = {'projects': [{'slug': 'titan-gathered-forever', 'type': 'requiredDependency'}]}
        size = files[folder].stat().st_size
        print('%s -> project %s (%s): %s, %d bytes, %s' % (folder, project, slug, files[folder].name, size, args.release_type))
        if args.command == 'upload' and args.apply and already_sent(LEDGER, project, files[folder].name):
            print('   skipped: this file was already sent (see ref-uploaded-files.json in the curseforge folder)')
        elif args.command == 'upload' and args.apply:
            body, content_type = multipart(metadata, files[folder])
            reply = request('/projects/%d/upload-file' % project, body, {'Content-Type': content_type})
            file_id = reply.get('id') if isinstance(reply, dict) else reply
            record_sent(LEDGER, project, files[folder].name, file_id)
            print('   uploaded, file id', file_id)
    if args.command == 'upload' and not args.apply:
        print('Nothing was uploaded: add --apply.')


if __name__ == '__main__':
    sys.exit(main())
