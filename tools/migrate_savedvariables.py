#!/usr/bin/env python3
"""Copy the previous addon's saved state into the renamed addon's namespace."""
import argparse
import re
from pathlib import Path

OLD_VARIABLE = 'TitanGathered2ForeverDB'
NEW_VARIABLE = 'TitanGatheredForeverV3DB'


def migrate(source, target):
    source, target = Path(source), Path(target)
    payload = source.read_bytes()
    text = payload.decode('utf-8')
    old = re.compile(r'(?m)^([ \t]*)' + re.escape(OLD_VARIABLE) + r'([ \t]*=)')
    if len(list(old.finditer(text))) != 1:
        raise ValueError('Input must contain exactly one previous saved-data assignment')
    if re.search(r'(?m)^\s*' + re.escape(NEW_VARIABLE) + r'\s*=', text):
        raise ValueError('Input already contains data for the renamed addon')
    converted = old.sub(lambda match: match[1] + NEW_VARIABLE + match[2], text, count=1)
    # Exclusive creation preserves both the original and any existing new data.
    with target.open('xb') as output:
        output.write(converted.encode('utf-8'))
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Previous account SavedVariables .lua file; close WoW first')
    parser.add_argument('target', type=Path, help='New TitanGatheredForeverV3.lua file in the same SavedVariables directory')
    args = parser.parse_args()
    try:
        print(migrate(args.source, args.target))
    except (OSError, ValueError) as error:
        parser.exit(2, f'Migration failed: {error}\n')
