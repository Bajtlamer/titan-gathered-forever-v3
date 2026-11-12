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
    [sys.executable, 'tools/generate_npc_seed.py', '--check'],
    [runtime, 'tests/run.lua'],
    [runtime, 'tests/integration.lua'],
    [runtime, 'tests/addon_loading.lua'],
    [runtime, 'tests/presentation.lua'],
    [runtime, 'tests/gathering.lua'],
    [runtime, 'tests/history.lua'],
    [runtime, 'tests/actions.lua'],
    [runtime, 'tests/production.lua'],
    [runtime, 'tests/crafting.lua'],
    [runtime, 'tests/crafting_view.lua'],
    [runtime, 'tests/export.lua'],
    [runtime, 'tests/export_view.lua'],
    [runtime, 'tests/observations.lua'],
    [runtime, 'tests/pvp.lua'],
    [runtime, 'tests/reports.lua'],
    [runtime, 'tests/map.lua'],
    [runtime, 'tests/flight_paths.lua'],
    [runtime, 'tests/pin_style.lua'],
    [runtime, 'tests/icon_appearance.lua'],
    [runtime, 'tests/icon_config.lua'],
    [runtime, 'tests/minimap.lua'],
    [runtime, 'tests/npc_sources.lua'],
    [runtime, 'tests/debug_log.lua'],
    [runtime, 'tests/minimap_button.lua'],
    [runtime, 'tests/known_recipes.lua'],
    [runtime, 'tests/npc_observer.lua'],
    [runtime, 'tests/recipe_browser.lua'],
]
for command in commands:
    subprocess.run(command, cwd=root, check=True, stdin=subprocess.DEVNULL)
addons = ['TitanGatheredForeverV3'] + [row['folder'] for row in json.loads((root / 'catalogue/modules.json').read_text())]
for addon in addons:
    toc = root / addon / (addon + '.toc')
    for line in toc.read_text().splitlines():
        if line.endswith('.lua'):
            path = addon + '/' + line
            subprocess.run([runtime, '-e', 'assert(loadfile(arg[1])); os.exit(0)', path], cwd=root, check=True,
                           stdin=subprocess.DEVNULL)
print('PASS all shipped Lua files compile with Lua 5.1 semantics')
