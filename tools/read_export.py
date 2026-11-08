#!/usr/bin/env python3
"""Validate a TGF v3 statistics export or reconstruct its numbered JSON parts."""
import argparse
import json
import math
import re
import sys
import zlib
from pathlib import Path

FORMAT = 'TGFv3-statistics'
PART_FORMAT = 'TGFv3-statistics-part'


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON key: {key}')
        result[key] = value
    return result


def parse(text):
    def invalid_constant(value):
        raise ValueError(f'Nonfinite JSON value: {value}')
    def finite_float(value):
        parsed = float(value)
        if not math.isfinite(parsed):
            raise ValueError('JSON number exceeds finite floating-point range')
        return parsed
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=invalid_constant,
                      parse_float=finite_float)


def header(document, expected):
    if (not isinstance(document, dict) or document.get('format') != expected
            or type(document.get('schemaVersion')) is not int or document['schemaVersion'] != 1):
        raise ValueError('Unsupported export format or schema version')


def validate(document):
    header(document, FORMAT)
    selection = document.get('selection')
    characters = document.get('characters')
    if (not isinstance(selection, dict) or selection.get('scope') not in ('character', 'combined')
            or type(selection.get('includeIdentity')) is not bool or not isinstance(characters, list)
            or type(selection.get('characterCount')) is not int
            or selection['characterCount'] != len(characters) or not characters):
        raise ValueError('Invalid character selection metadata')
    if selection['scope'] == 'character' and len(characters) != 1:
        raise ValueError('Character selection must contain one character')
    if selection['scope'] == 'combined' and not isinstance(document.get('combined'), dict):
        raise ValueError('Combined export is missing its summary')
    refs = set()
    for character in characters:
        if not isinstance(character, dict) or not isinstance(character.get('ref'), str):
            raise ValueError('Invalid character reference')
        if character['ref'] in refs:
            raise ValueError('Duplicate character reference')
        refs.add(character['ref'])
        if selection['includeIdentity'] != ('identity' in character):
            raise ValueError('Identity fields do not match the export selection')
    return document


def read_export(paths):
    """Read complete JSON or all copy-part envelopes, without executing any data."""
    if not paths:
        raise ValueError('At least one export file is required')
    documents = [parse(Path(path).read_text(encoding='utf-8')) for path in paths]
    if len(documents) == 1 and isinstance(documents[0], dict) and documents[0].get('format') == FORMAT:
        return validate(documents[0])
    parts = {}
    expected = None
    for document in documents:
        header(document, PART_FORMAT)
        for field in ('part', 'total', 'bytes'):
            if type(document.get(field)) is not int or document[field] < 1:
                raise ValueError(f'Invalid copy-part {field}')
        if document['part'] > document['total']:
            raise ValueError('Copy-part index exceeds total')
        if not isinstance(document.get('payload'), str):
            raise ValueError('Copy part has no string payload')
        checksum = document.get('checksum')
        if not isinstance(checksum, str) or not re.fullmatch('[0-9a-f]{8}', checksum):
            raise ValueError('Invalid copy-part checksum')
        identity = (document['total'], document['bytes'], checksum)
        if expected is not None and identity != expected:
            raise ValueError('Copy parts belong to different exports')
        expected = identity
        if document['part'] in parts:
            raise ValueError('Duplicate copy part')
        parts[document['part']] = document['payload']
    total, byte_count, checksum = expected
    if len(parts) != total:
        raise ValueError(f'Missing copy parts: got {len(parts)} of {total}')
    payload = ''.join(parts[i] for i in range(1, total + 1))
    encoded = payload.encode('utf-8')
    if len(encoded) != byte_count or f'{zlib.adler32(encoded):08x}' != checksum:
        raise ValueError('Copy-part payload is incomplete or corrupt')
    return validate(parse(payload))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, help='Write a new normalized JSON file; never overwrite')
    args = parser.parse_args()
    try:
        document = read_export(args.files)
        text = json.dumps(document, ensure_ascii=False, allow_nan=False, indent=2) + '\n'
        if args.output:
            with args.output.open('x', encoding='utf-8') as output:
                output.write(text)
        else:
            sys.stdout.write(text)
    except (OSError, ValueError, UnicodeError) as error:
        parser.exit(1, f'Export validation failed: {error}\n')


if __name__ == '__main__':
    main()
