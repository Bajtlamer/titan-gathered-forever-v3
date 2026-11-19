# Plan: Discovery module (replacement for WoW Forever Scout)

Written 2026-11-19 at version 0.5.108. Status: proposed, nothing implemented. Branch: feat/discovery-module (from main). The shared core stays clean for CurseForge releases; all work happens in a new runtime folder and in tools/, and the branch is merged only on the owner's decision.

## 1. Goal

A data-collection module for the owner (and for contributors who knowingly choose to help) that records what the WoW Forever client shows and compares it with the data Titan Gathered Forever already ships, so that new and different facts can be reviewed and then added to catalogue/ deliberately.

It replaces the retired WoW Forever Scout addon (WoWForeverScout 0.1.3, SavedVariables WoWFScoutDB). Scout and the module never run together.

## 2. Decisions from the owner (2026-11-19)

- Scout and the module do not run side by side. The module refuses to start collecting while WoWForeverScout is loaded and says so in chat. Scout is switched off or removed by the user.
- The module does nothing with the auction house. No passive auction recording, no scan of the full content. Scout's AuctionScanner is not ported.
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
| Areas | zone, subzone, real zone text, instance name and type, map ID, parent map, first visit time | zone changed events, every new name is stored, as Scout intended |
| Skills | profession names and ranks (evidence which professions exist) | skill lines changed |
| Client | build, interface version, locale, module version | at login and via /tgfd info |

Scout's loot debug print of raw GUIDs is not ported; GUID segment layout is a documented test fixture instead.

### 4.2 Commands (active, started by the user only)

All under /tgfd. No command runs on login or from a hidden trigger.

- /tgfd, /tgfd help: explain the module and list commands.
- /tgfd accept: confirm the first-run notice and start passive collection. /tgfd stop and /tgfd start pause and resume it.
- /tgfd status: counts per category, file size estimate, last export, baseline version, collection on or off.
- /tgfd show: open the overview window (section 5).
- /tgfd scan recipes: full recipe list of the open profession window including unlearned recipes and reagents. Needs the window open; the module never opens it.
- /tgfd scan areas: walk the map hierarchy and record every map ID, name, parent and type the client reports. Chunked, with progress.
- /tgfd compare: run the comparison against the baseline in chunks, with progress, then open the overview.
- /tgfd import scout: one-time import of WoWFScoutDB (about 14 kB at present) into the module's tables, marked as imported from Scout 0.1.3.
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
- Tabs: New (not in the baseline), Different (same ID, other name, price, location, source or requirement), Not seen (in the baseline, never observed on this client), Areas, NPCs, Items, Quests, Recipes, Imported from Scout.
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
- Core/: namespace, saved-variable lifecycle with schema version, Scout presence check, notice and consent, command router, batch runner and progress frame.
- Collectors/: Loot, Npc, Vendor, Entity, Quest, Area, Skill, Client, plus the command-started RecipeScan and AreaScan.
- Compare/: pure Lua comparison with no WoW calls (testable offline, as Scout's Compare was).
- UI/: overview window and progress frame.
- Artwork: an emblem following the existing artwork inventory, added last.

Own SavedVariables key, so the core's TitanGatheredForeverV3DB and the retired WoWFScoutDB are never touched. The module's tests live in tests/ with the other suites and are added to tools/check.py; tools/install.py and the packaging allowlist are extended only so the module can be installed locally.

## 8. Versioning, branch and release rules

- All work stays on feat/discovery-module (or sub-branches merged into it). main and the CurseForge release line are not touched. Merge to main only on the owner's explicit decision.
- The module has its own version line, starting at 0.1.0, because it is not part of the published addon set. If a core change turns out to be unavoidable, it is made as a separate, minimal commit that is reviewed on its own; a core change means a patch increment and synchronized manifests as AGENTS.md requires.
- Install into the live AddOns folder follows AGENTS.md (checks, preview, --apply, verify). Scout must be removed first; the installer is not used to delete it.
- Documentation as the repository asks: README section, ref- status update, release notes only on a release. No attribution to an AI tool in commits or the PR description.

## 9. Milestones

1. Skeleton and safety (about 1 day): folder, manifest, SavedVariables lifecycle, Scout detection, first-run notice and /tgfd accept, command router, status. Tests for lifecycle and consent.
2. Batch runner and progress frame (1 day): time-budgeted runner, cancel, abort on combat and loading screens. Tests with a fake clock.
3. Passive collectors (2 days): loot, NPC contact, vendor and trainer goods, entities, areas, skills, client. Fixtures from real event payloads; privacy tests proving that no player GUID or name is stored.
4. Comparison engine (1 day): pure Lua, baseline from the published compact records, build-dependent flag.
5. Overview window (1 to 2 days): tabs, filters, paging, detail panel, style tests with tests/style_stub.lua.
6. Command-started scans (1 to 2 days): recipes and areas; live validation needed because the C_TradeSkillUI and C_Map shapes are unverified on this client.
7. Scout import and export or archive (1 day).
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
