# Plan: Discovery module

Written 2026-11-19 at version 0.5.108. Status: proposed, nothing implemented. Branch: feat/discovery-module (from main). The shared core stays clean for CurseForge releases; all work happens in a new runtime folder and in tools/, and the branch is merged only on the owner's decision.

## 1. Goal

A data-collection module for the owner (and for contributors who knowingly choose to help) that records what the WoW Forever client shows and compares it with the data Titan Gathered Forever already ships, so that new and different facts can be reviewed and then added to catalogue/ deliberately.

It is a new, standalone data-collection module; no earlier addon is kept, detected or imported.

## 2. Decisions from the owner (2026-11-19)

- The module does nothing with the auction house. No passive auction recording, no scan of the full content.
- Every active scan or heavy operation is started only by a chat command, never automatically and never from a button that could be hit by accident.
- Every heavy operation shows progress: which operation runs, which phase, how far it is, and can be cancelled by a command.
- Passive collection is broad: all looting, every contact with an NPC or other entity, every newly seen zone and area. The aim is to catch as many new or different facts as possible.
- Data size does not matter by itself. Only rate limits and lag matter.
- The module is primarily for the owner. Contributors are welcome, but only after they have been told what it does, how to use it, and that they only pass data on.
- No new runtime changes to the core unless unavoidable. The module reads the core through the existing TitanGatheredForeverV3 namespace alias.

## 3. Corrections and additions to the owner's ideas

1. Size does matter a little. WoW reads the whole SavedVariables file into memory at login and reload. A very large file lengthens every login and reload even when nothing is collected. Mitigation: compact records, one table per category, a /tgfd archive command that moves finished data out (export and clear), and a size and load-time indicator in the status window. No hard limit is set, as requested.
2. SavedVariables are written only at logout or /reload. A crash or a killed client loses the whole session. The module reminds the user after a long session and offers /tgfd save (which asks for a /reload).
3. Contributors must not leak personal data. Player GUIDs, character names, guild names, chat text, whispers, mail text and battle tags are never recorded. Only creature, object, item, spell, quest, area and map IDs and public names are kept. Exports contain no account or realm identifiers. The first-run notice states this.
4. Addons cannot send data anywhere. "Passing data on" means the contributor sends the export file or the SavedVariables file to the owner by hand. The export therefore needs a schema version, the client build (GetBuildInfo) and the module version in every file, so merges from several people can be deduplicated and told apart by build.
5. "Different from the old database" needs a defined baseline. The baseline is the catalogue state of a named TGF version plus the pinned reference inputs (catalogue/*.json). Every comparison result names that baseline. A difference seen on another client build is flagged as build-dependent, not as an error.
6. Comparison has two levels. In game, only against the compact records the modules already publish (cheap, enough for "new item", "unknown NPC", "new area"). Full recipe and source records stay out of runtime memory (AGENTS.md); the complete comparison is done offline by a tool that reads the SavedVariables file.
7. Unknown stays unknown. A discovery is an observation with a count, first seen and last seen, not a verified fact. Nothing observed here changes catalogue completeness; only the documented evidence gates do.
8. Passive collection is a consent question too. Enabling the module is the consent. First start shows a notice (what is recorded, what is not, how to stop, how to export) and recording starts only after the user confirms it with /tgfd accept. Without it the module collects nothing.
9. Secret and restricted values: the modern client can return restricted values in some contexts. Collectors use ns.IsPublic and pcall as the core does, and skip a record instead of raising an error.
10. Probing item or spell ID ranges with GetItemInfo is a server request per unknown ID. It is optional, off by default, throttled, command-started and clearly labelled as a lag source. It is not part of the first version.
11. Keep it out of CurseForge releases. catalogue/modules.json drives tools/package.py and the downloads; the module is not listed there, so it is not packaged. If it is ever published, that is a separate decision and a separate project entry.

## 4. Scope

### 4.1 Passive collectors (always on after acceptance, cheap, event-driven)

| Collector | Records | Events and notes |
|---|---|---|
| Loot | item, quantity, source creature or object ID, source type, zone and area, count | loot opened and loot slot events, not limited to professions; separate from the core's profession observations |
| NPC contact | creature ID, name, subname, level, type, family, classification, location, services offered (gossip options, vendor, trainer, quest giver, flight master, repair, innkeeper, banker, auctioneer seen only as an NPC contact, no auction data) | gossip, merchant, trainer, quest, taxi, bank frames |
| Vendor and trainer goods | item or spell IDs, price in copper, stack, stock, extended cost flag, skill requirement | on window open, rate limited, one pass per window |
| Other entities | game objects (nodes, chests, mailboxes), units seen by tooltip and target, with IDs | target and mouseover, deduplicated per ID |
| Quests | quest ID, title, giver, turn-in, reward item IDs shown | quest frame events |
| Areas | zone, subzone, real zone text, instance name and type, map ID, parent map, first visit time | zone changed events, every new name is stored |
| Skills | profession names and ranks (evidence which professions exist) | skill lines changed |
| Client | build, interface version, locale, module version | at login and via /tgfd info |


### 4.2 Commands (active, started by the user only)

All under /tgfd. No command runs on login or from a hidden trigger.

- /tgfd, /tgfd help: explain the module and list commands.
- /tgfd accept: confirm the first-run notice and start passive collection. /tgfd stop and /tgfd start pause and resume it.
- /tgfd status: counts per category, file size estimate, last export, baseline version, collection on or off.
- /tgfd show: open the overview window (section 5).
- /tgfd scan recipes: full recipe list of the open profession window including unlearned recipes and reagents. Needs the window open; the module never opens it.
- /tgfd scan areas: walk the map hierarchy and record every map ID, name, parent and type the client reports. Chunked, with progress.
- /tgfd compare: run the comparison against the baseline in chunks, with progress, then open the overview.
- /tgfd export: write the export blob or table for sending; /tgfd archive: export and clear the collected data after confirmation (/tgfd archive confirm).
- /tgfd cancel: stop the running operation.

Auction commands do not exist.

### 4.3 Progress and lag handling

- All active operations run through one batch runner: work is split into small steps and executed from a frame OnUpdate with a time budget per frame (for example 5 ms), so the game keeps drawing.
- A progress frame shows operation name, phase (for example "Reading recipes 3 of 5, profession Tailoring"), a bar, items done and total, elapsed time, and a Cancel button that does the same as /tgfd cancel. Chat gets a start line, a line at every phase change and a result line.
- Only one active operation at a time. A second command says what is running.
- Operations are aborted cleanly on combat start, loading screens and window close, and report that they stopped and why.

## 5. Overview window (what is new and different)

Opened with /tgfd show or by clicking the Titan Panel statistics button (section 5.1). Follows the style rules in AGENTS.md: Style.Label and Style.Value, Style.Range for "Showing a-b of n", Style.Date for dates, game money format for prices, small gold informational text.

- Header: baseline TGF version, client build, last compare time, observations total, and one line saying that these are unverified observations.
- Tabs: New (not in the baseline), Different (same ID, other name, price, location, source or requirement), Not seen (in the baseline, never observed on this client), Areas, NPCs, Items, Quests, Recipes.
- Each row: ID, name, category, count, first seen, last seen, state (new, different, unchanged, build-dependent) and a short "why" text.
- Filters by category and state, sorting, paging, and a detail panel with all observations of one row (where, when, how many times, which build).
- Buttons: Export selection and Mark reviewed. Reviewed marks are local notes only; they do not change the catalogue.

### 5.1 Titan Panel statistics

The only Titan Panel element is a read-only statistics plugin. It shows counts of what has been discovered and differs from the baseline: new locations and areas, new items, new recipes, new skills, new NPCs, new quests, and the number of differing records, for example a short label with the total and a tooltip with the full breakdown by category and the baseline version. It has no scan, export or settings actions; every operation stays a /tgfd command. Clicking it opens the overview window. Counts are refreshed after a compare and at a low rate from the passive collectors, never from a heavy loop. When collection is not accepted or paused, the label says so.

## 6. Offline tooling (the path into the stable database)

- tools/read_discovery.py (modelled on tools/read_export.py): reads the module's SavedVariables or an export file, validates the schema, merges several contributor files by ID and build, and produces a deterministic report in a tmp or ref- file.
- Comparison against catalogue/*.json and catalogue/reconciliation.json with the same rules as tools/audit_catalog.py: no downloads, no executing external code, pinned inputs.
- Output: candidate additions grouped by evidence class, each with observation counts and contributors' builds. Adding anything to catalogue/ stays a manual, reviewed step through tools/generate_catalog.py and its checks. No candidate raises completeness.
- Instance data: no map spots from instances (AGENTS.md). Instance observations are kept as facts about content, not as coordinates for pins.

## 7. Structure of the module

New runtime folder TitanGatheredForever_Discovery (hand-written, not generated; not listed in catalogue/modules.json):

- TitanGatheredForever_Discovery.toc: interface 16001, Dependencies: Titan, TitanGatheredForever (Titan for the statistics plugin), SavedVariables: TitanGatheredForeverDiscoveryDB, version in step with the core on release rules below.
- Core/: namespace, saved-variable lifecycle with schema version, notice and consent, command router, batch runner and progress frame.
- Collectors/: Loot, Npc, Vendor, Entity, Quest, Area, Skill, Client, plus the command-started RecipeScan and AreaScan.
- Compare/: pure Lua comparison with no WoW calls (testable offline).
- UI/: overview window and progress frame.
- Artwork: an emblem following the existing artwork inventory, added last.

Own SavedVariables key, so the core's TitanGatheredForeverV3DB is never touched. The module's tests live in tests/ with the other suites and are added to tools/check.py; tools/install.py and the packaging allowlist are extended only so the module can be installed locally.

## 8. Versioning, branch and release rules

- All work stays on feat/discovery-module (or sub-branches merged into it). main and the CurseForge release line are not touched. Merge to main only on the owner's explicit decision.
- The module has its own version line, starting at 0.1.0, because it is not part of the published addon set. If a core change turns out to be unavoidable, it is made as a separate, minimal commit that is reviewed on its own; a core change means a patch increment and synchronized manifests as AGENTS.md requires.
- Install into the live AddOns folder follows AGENTS.md (checks, preview, --apply, verify).
- Documentation as the repository asks: README section, ref- status update, release notes only on a release. No attribution to an AI tool in commits or the PR description.

## 9. Milestones

1. Skeleton and safety (about 1 day): folder, manifest, SavedVariables lifecycle, first-run notice and /tgfd accept, command router, status. Tests for lifecycle and consent.
2. Batch runner and progress frame (1 day): time-budgeted runner, cancel, abort on combat and loading screens. Tests with a fake clock.
3. Passive collectors (2 days): loot, NPC contact, vendor and trainer goods, entities, areas, skills, client. Fixtures from real event payloads; privacy tests proving that no player GUID or name is stored.
4. Comparison engine (1 day): pure Lua, baseline from the published compact records, build-dependent flag.
5. Overview window (1 to 2 days): tabs, filters, paging, detail panel, style tests with tests/style_stub.lua.
6. Command-started scans (1 to 2 days): recipes and areas; live validation needed because the C_TradeSkillUI and C_Map shapes are unverified on this client.
7. Export and archive (1 day).
8. Offline tool and report (1 to 2 days).
9. Live acceptance and documentation (1 day): record live results separately from automated checks.

Rough total: 9 to 12 working days; the first useful version (milestones 1 to 5) is about 6 days.

## 10. Decisions and open questions

Decided 2026-11-19: the displayed name is "Titan Gathered Forever: Discovery" and the folder is TitanGatheredForever_Discovery, so the two match (the manifest Title follows the existing "Titan Gathered Forever: <Module>" pattern); operations are slash commands only, with the single exception of the read-only Titan Panel statistics plugin; the bag and bank snapshot is not ported (the core keeps its own).

Still open:


- Whether the optional item ID range probing (3, point 10) is ever wanted.
- Whether contributors get the module as a ZIP from the repository (not CurseForge) and where it is hosted.

## 11. Risks

- API shapes on the Forever client (recipe schematic, map hierarchy, merchant info) are unverified; every call is guarded and checked live before it is trusted.
- Passive collection on a busy raid or city frame must stay inside a small per-event cost; measure with the existing performance addon data before enabling by default.
- Growth of the SavedVariables file lengthens login; the archive command and the status indicator are the control.
- Contributor data quality: merged files are only evidence, never truth. Reports always show the number of independent observations and builds.

## 12. Execution record

- Milestone 1 (2026-11-20, branch feat/discovery-module): the folder TitanGatheredForever_Discovery 0.1.0 exists with manifest (own saved table TitanGatheredForeverDiscoveryDB), Core/Text, Database, Consent, Commands, Main and Start. Tests (29 checks at that point) were written first and failed for the missing manifest before any module code. Covered: saved-table lifecycle including newer-schema protection, consent and notice versioning, /tgfd help, accept, stop, start and status, login checks, a guard that no file touches the auction house, and that only ADDON_LOADED and PLAYER_LOGIN are used.
- tools/check.py runs the new suite and compiles the module's Lua. tests/test_branding.py lets the module keep its own version line; tests/test_repository_layout.py guards that it stays out of catalogue/modules.json and holds only manifest files.
- Not done: no artwork or IconTexture (planned last), not installed in the game (the installer only handles the published set), no live check. Automated results only.
- Milestone 2 (2026-11-20): Core/Runner.lua (one operation at a time, phases with lazily read totals, a 5 ms budget per tick with at least one step, errors in steps, totals and finish handlers contained, listeners), Core/Progress.lua (progress window with phase, bar, counts, elapsed time and a Cancel button; built lazily and optional, so a window failure leaves chat progress and the operation intact), Core/SelfTest.lua (/tgfd selftest, a harmless three-phase operation that records nothing) and the commands /tgfd cancel and selftest. Main drives an operation from its own ticker frame and registers PLAYER_REGEN_DISABLED and PLAYER_LEAVING_WORLD only while it runs, so an idle module still has no per-frame work and no game events. tests/discovery.lua now has 46 checks (fake clock for the budget and the order of steps). Operations refuse to start in combat. Live validation still open: the look of the progress window (BackdropTemplate, StatusBar, UIPanelButtonTemplate on the Forever client), the lag of /tgfd selftest and that PLAYER_LEAVING_WORLD stops a running operation on a real loading screen.
- 2026-11-20: the owner asked for the earlier addon to be removed everywhere. It was deleted from the game folder together with its saved data and backups. The module has no detection of it, no blocked state and no import; a test guards that no module file or manifest mentions it again. tests/discovery.lua has 43 checks after the removal.
- Milestone 3 (2026-11-20): passive collectors. Core/Safe (restricted values and errors never reach a collector; a found bug: unpack lost values after a nil, fixed by counting with select), Privacy (only Creature and GameObject GUIDs become IDs; players, pets, player-controlled units and anything else are skipped with their names), Records (counts, first and last time, first and last build), Api (the one adapter to the client, shapes taken from the core; skill, quest and zone calls are live validation gates) and the collectors Area, Entities, Npc, Loot, Vendor (also trainers), Quest, Skill and Client, tied to events by Manager. The events are registered only while the module is collecting, so before acceptance or while paused the module listens to nothing. A failing collector is counted and shown in /tgfd status. Loot keeps offered and taken apart, reads the window at LOOT_READY and again at LOOT_OPENED, and keeps loot without a readable source as "unsourced" instead of guessing. Positions are kept outside instances only, at most five per creature. Gossip text, quest text and chat are not recorded (they can contain the player's name). tests/discovery_collectors.lua has 25 checks including a session sweep proving that no player GUID or name remains in the saved data. Not done: live validation of every event payload, and the Titan Panel statistics plugin (milestone 5).
- Milestone 4 (2026-11-20): the comparison. Core/Baseline reads what the core keeps in memory through the exported namespace (installed catalogue items, the NPC seed, the twelve known professions, the target build and the installed modules); Core/Compare classifies every observed record as new, different, unchanged or unbaselined, with per-field details, a flag for another build than the baseline's target and for several builds, counts per category, and a list of baseline entries never observed. /tgfd compare runs it through the runner with a phase per category; only the counts are saved (db.compare), the rows are rebuilt on demand for the window. Findings that shaped the design: the NPC seed holds only profession trainers and recipe vendors, so an NPC outside it is not "new" by that alone (it is "unbaselined"); a trainer with a profession lesson outside the seed is new; the catalogue holds no item names, so loot can only be new or known; areas, quests and entities have no in-game baseline and are left to the offline tool (milestone 8). The installed catalogue modules define "new", which the report states. tests/discovery_compare.lua has 17 checks. Live check still open: runtime of a comparison on a large saved table.
- Milestone 5 (2026-11-20): the overview window and the Titan Panel statistics. Core/View is the view model (filters, search over category, ID and name, paging, seven-cell rows with colored states, detail lines with prices in game money, header with the baseline and builds); UI/Window builds the window with the core's own helpers (drag position, dropdown, scroll bar) and reports a failure instead of raising it; Core/Stats registers a LibDataBroker data source that Titan Panel shows as a plugin: text "N new, M different" after a comparison (otherwise "N records", "off", "paused" or "blocked"), a tooltip with observed, new and different per category and the date and baseline of the last comparison, left click opens the window, no other actions. The statistics refresh after a comparison and on accept, stop and start, and at most every ten seconds after new records. /tgfd show opens the window. Deviation from section 5: instead of tabs there are two dropdowns (what to show: new and different, new, different, not yet seen, no baseline, unchanged, everything; and the category), which is the layout the core's own windows use and covers the same views; "Mark reviewed" and "Export selection" are left to milestone 7. Without a comparison in the session the window says to run /tgfd compare and shows no rows. The plugin icon is a stock game icon until the artwork exists. tests/discovery_view.lua has 19 checks. Live validation open: how the window and the plugin look and fit in Titan Panel on the Forever client.
- Milestone 6 (2026-11-20): the command-started scans. /tgfd scan recipes reads the recipes the client lists for the open profession window (unlearned ones too, with the product, the quantity and the basic reagent slots; a profession that is not one of the known ones is kept under the name the client gives, so a new profession shows up here); the module never opens the window and says so when the client lists nothing. /tgfd scan areas [number] reads the map IDs from 1 to the number (default 4000, at most 20000) with name, type and parent; these are reads of local client data, no server request. Both are runner operations with progress and cancel, and both need the notice accepted and recording not paused, because they record observations. Two new categories, recipes and maps, with labels and baseline rules: a recipe is new outside the installed catalogue, different when its profession differs from the catalogue (compared without spaces and case, so First Aid equals FirstAid) and otherwise unchanged; maps have no in-game baseline. The notice gained a line about the scans and its version is now 2, so an earlier acceptance has to be repeated. The bag and bank scan stays dropped. Commands now pass their arguments. tests/discovery_scans.lua has 12 checks. Live validation open: the trade skill and map calls on the Forever client (recipe schematics, GetMapInfo for IDs without a map, the highest map ID in use, whether the profession window exposes unlearned recipes through GetAllRecipeIDs).
- Milestone 7 (2026-11-20): export, archive and review marks. A game addon cannot write a file, so export means the SavedVariables file: /tgfd export runs the privacy check (a second line of defence that searches every string and key for a player or pet GUID and for the character name) and the checksums as one operation, and only on a clean result stamps db.export with schema, module and client versions, counts, per-category and total Adler-32 checksums and the session; it then tells the user to /reload and hand over TitanGatheredForeverDiscoveryDB.lua. /tgfd audit runs the privacy check alone. /tgfd archive confirm clears the observations, but only when an export exists, the game was reloaded since it (a new session, so the file holds it), recording is stopped and the checksums still match; otherwise it clears nothing and says why. A small history stays in db.archives and the consent stays. Review marks (db.reviewed) are local notes with a "To review" filter and a button in the window; they never change a comparison. "Export selection" from section 5 is dropped: the whole file is the hand-over. A bug of the design was avoided on purpose: archive without a reload or with recording on could have deleted data that never reached the disk. Documents added: ref-discovery-data-format.md and book-discovery-contributors.md. tests/discovery_export.lua has 15 checks. Live validation open: that the file written by the game contains the stamp after /reload, and the time the privacy check and the checksums take on a large saved table.
