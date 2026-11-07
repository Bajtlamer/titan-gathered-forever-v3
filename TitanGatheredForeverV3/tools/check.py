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
    [runtime, 'TitanGatheredForeverV3/tests/run.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/integration.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/addon_loading.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/presentation.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/gathering.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/history.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/observations.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/reports.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/map.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/pin_style.lua'],
    [runtime, 'TitanGatheredForeverV3/tests/minimap.lua'],
]
for command in commands:
    subprocess.run(command, cwd=root.parent if command[0] == runtime else root, check=True)
addons = ['TitanGatheredForeverV3'] + [row['folder'] for row in json.loads((root / 'catalogue/modules.json').read_text())]
for addon in addons:
    toc = root.parent / addon / (addon + '.toc')
    for line in toc.read_text().splitlines():
        if line.endswith('.lua'):
            path = addon + '/' + line
            subprocess.run([runtime, '-e', 'assert(loadfile(arg[1])); os.exit(0)', path], cwd=root.parent, check=True)
print('PASS all shipped Lua files compile with Lua 5.1 semantics')
