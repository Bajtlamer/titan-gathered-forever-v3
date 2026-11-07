#!/usr/bin/env python3
"""Run the project's data, Lua 5.1, and integration checks; fail on any error."""
import shutil
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
runtime = shutil.which('luajit')
if not runtime:
    raise SystemExit('Install LuaJIT (Lua 5.1 semantics) to run the addon tests.')
commands = [
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py'],
    [sys.executable, 'tools/generate_catalog.py', '--check'],
    [runtime, 'tests/run.lua'],
    [runtime, 'tests/integration.lua'],
    [runtime, 'tests/addon_loading.lua'],
    [runtime, 'tests/presentation.lua'],
    [runtime, 'tests/gathering.lua'],
    [runtime, 'tests/history.lua'],
    [runtime, 'tests/observations.lua'],
    [runtime, 'tests/reports.lua'],
    [runtime, 'tests/map.lua'],
    [runtime, 'tests/pin_style.lua'],
    [runtime, 'tests/minimap.lua'],
]
for command in commands:
    subprocess.run(command, cwd=root, check=True)
addons = ['TitanGatheredForeverV3'] + [row['folder'] for row in json.loads((root / 'catalogue/modules.json').read_text())]
for addon in addons:
    toc = root / addon / (addon + '.toc')
    for line in toc.read_text().splitlines():
        if line.endswith('.lua'):
            path = addon + '/' + line
            subprocess.run([runtime, '-e', 'assert(loadfile(arg[1])); os.exit(0)', path], cwd=root, check=True)
print('PASS all shipped Lua files compile with Lua 5.1 semantics')
