# Titan Gathered Forever: Discovery 0.1.0

First version of the Discovery module. It has its own version line and is released separately from Titan Gathered Forever 0.5.x and its profession modules; it is not part of the published collection. This text is the changelog for the website and the release page.

## Added

- A data-collection companion for the owner and for contributors who choose to help. It records what the WoW Forever client shows and compares it with the Titan Gathered Forever catalogue, so new or different data can be found.
- A notice that says what is recorded and what never is. Nothing is recorded until `/tgfd accept`. `/tgfd stop` and `/tgfd start` pause and resume.
- Passive collection of loot and its sources, NPCs and objects met, vendor goods, trainer lessons, quests, areas and zone names, profession skills and the client build. Every observation carries a count, the first and last time and the client build. Players, pets and their names are never recorded, and neither are chat, mail, gossip or quest text. The module does nothing with the auction house.
- `/tgfd compare` compares the observations with the baseline the core keeps in memory (new, different, unchanged, without baseline) as an operation with progress. `/tgfd show` opens an overview window with filters, search, paging, a detail panel and local review marks.
- A read-only Titan Panel plugin with the counts of what has been found.
- `/tgfd scan recipes` (recipes of the profession window you opened, also unlearned ones) and `/tgfd scan areas` (map IDs of the client). Every long operation starts only from a command, shows a progress window, can be cancelled and stops on combat or a loading screen. `/tgfd selftest` shows the progress window with a harmless test.
- `/tgfd audit` and `/tgfd export` check the data for private values and stamp it with versions, counts and checksums, then tell you to `/reload` and send `TitanGatheredForeverDiscoveryDB.lua`. `/tgfd archive confirm` clears exported data from the game only when the saved file provably holds it.
- `tools/read_discovery.py` merges the files of several contributors and compares them with the catalogue files, without running the files or changing anything.
- An emblem and packaged addon-list icon in the family of the other addons, drawn procedurally by `tools/generate_discovery_art.py`.

## Packaging

`python3 tools/package.py --standalone` builds `dist/standalone/TitanGatheredForever_Discovery-0.1.0/` with the ZIP (35 files: Lua, icon, manifest and the license), `downloads.json` and `SHA256SUMS`. `python3 tools/install.py --addons-dir <path> --standalone-only` installs only this folder and leaves every other folder and saved file untouched. The module is listed in `catalogue/standalone-modules.json`, so the published collection and the profession ZIPs are unchanged.

## Requirements

WoW Forever 1.60.1 (interface 16001), Titan Panel and the Titan Gathered Forever shared core.

## Validation

Automated: the Python suites, five Lua suites for the module (consent, runner, collectors, comparison, window and statistics, scans, export) and Lua 5.1 compilation of every shipped file pass. These are automated results only. The live acceptance checklist in `book-wow-forever-validation.md` is open: the look of the window, progress window and Titan Panel plugin, the client calls for recipes, maps, quests and zones, the lag of the scans and that the saved file carries the export stamp.

## Known limitations

- Everything recorded is an observation, not a verified fact. The baseline is what the installed catalogue modules and the NPC seed hold, so "new" means "not in the installed data".
- Areas, maps, quests and entities have no baseline in the game and are only compared by the offline tool, which lists them for review.
- The assumption that a client recipe ID equals the catalogue spell ID is not yet checked on the live client.
- A large saved file lengthens login; exported data can be cleared with the archive command.
