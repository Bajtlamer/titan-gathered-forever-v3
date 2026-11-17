"""Preserve saved files and addon enablement when installed folders are renamed."""
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


def ensure_game_closed(client):
    # Real Forever installations require a closed client; temporary test clients
    # have no running game and must not require access to the OS process list.
    if Path(client).name != '_forever_':
        return
    result = subprocess.run(['pgrep', '-ifl', 'World of Warcraft|WowClassic|WowF'],
                            capture_output=True)
    if result.returncode == 0:
        raise ValueError('Close WoW before migrating addon folders and saved files.')
    if result.returncode != 1:
        raise ValueError('Cannot verify that WoW is closed; saved-file migration stopped.')


def regular_path(path, root):
    path, root = Path(path), Path(root)
    if not path.is_relative_to(root):
        raise ValueError('State path escapes the client')
    for entry in [path, *path.parents]:
        if entry.is_symlink():
            raise ValueError('Refusing symlink in client state: ' + str(entry))
        if entry == root:
            break


def enablement(payload, aliases):
    mapping = {old.lower().encode(): new.encode() for old, new in aliases.items()}
    renamed = {new.lower() for new in mapping.values()}
    rows = payload.splitlines(keepends=True)
    parsed = []
    statuses = {}
    pattern = re.compile(rb'^(\xef\xbb\xbf)?([ \t]*)([^:\r\n]+)(:[^\r\n]*)(\r?\n)?$')
    for row in rows:
        match = pattern.match(row)
        if not match:
            parsed.append((row, None))
            continue
        old = match[3].strip().lower()
        new = mapping.get(old, match[3].strip())
        key, status = new.lower(), match[4][1:].strip().lower()
        if key in statuses and statuses[key] != status and (old in mapping or key in renamed):
            raise ValueError('Conflicting old and new addon enablement entries')
        statuses[key] = status
        parsed.append((row, (match, old, new)))
    result, emitted = [], set()
    for row, data in parsed:
        if data is None:
            result.append(row)
            continue
        match, old, new = data
        key = new.lower()
        if key in renamed:
            if key in emitted:
                continue
            emitted.add(key)
        if old in mapping:
            row = (match[1] or b'') + match[2] + new + match[4] + (match[5] or b'')
        result.append(row)
    return b''.join(result)


class StateMigration:
    def __init__(self, destination, aliases):
        self.client = Path(destination).parent.parent
        self.changes, self.applied, self.origins = [], [], []
        active = {old: new for old, new in aliases.items()
                  if (Path(destination) / old).exists() or not (Path(destination) / new).exists()}
        account = self.client / 'WTF/Account'
        if not active or not account.exists():
            return
        regular_path(account, self.client)
        for directory in sorted(account.rglob('SavedVariables')):
            regular_path(directory, self.client)
            if not directory.is_dir():
                continue
            for old, new in active.items():
                for suffix in ('.lua', '.lua.bak'):
                    source, target = directory / (old + suffix), directory / (new + suffix)
                    regular_path(source, self.client)
                    regular_path(target, self.client)
                    if not source.is_file():
                        continue
                    data = source.read_bytes()
                    if target.exists():
                        if not target.is_file() or target.read_bytes() != data:
                            raise ValueError('Conflicting saved files; refusing to overwrite: ' + str(target))
                        continue
                    self.origins.append((source, data))
                    self.changes.append((target, None, data, source.stat().st_mode & 0o777))
        for path in sorted(account.rglob('AddOns.txt')):
            regular_path(path, self.client)
            before = path.read_bytes()
            after = enablement(before, active)
            if after != before:
                self.changes.append((path, before, after, path.stat().st_mode & 0o777))

    def apply(self, backup):
        if not self.changes:
            return
        ensure_game_closed(self.client)
        for source, expected in self.origins:
            regular_path(source, self.client)
            if not source.is_file() or source.read_bytes() != expected:
                raise ValueError('Original saved file changed during installation: ' + str(source))
        for path, before, after, mode in self.changes:
            actual = path.read_bytes() if path.exists() else None
            if actual != before:
                raise ValueError('Client state changed during installation: ' + str(path))
            if before is not None:
                retained = Path(backup) / 'client-state' / path.relative_to(self.client)
                retained.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, retained)
            self.write(path, after, mode, exclusive=before is None)
            self.applied.append((path, before, mode))

    @staticmethod
    def write(path, payload, mode, exclusive=False):
        descriptor, temporary = tempfile.mkstemp(prefix='.addon-state-', dir=path.parent)
        temporary = Path(temporary)
        try:
            with os.fdopen(descriptor, 'wb') as output:
                output.write(payload)
            temporary.chmod(mode)
            if exclusive:
                os.link(temporary, path)
            else:
                temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)

    def rollback(self):
        for path, before, mode in reversed(self.applied):
            if before is None:
                path.unlink()
            else:
                self.write(path, before, mode)
        self.applied.clear()
