# Interface refinements implementation plan

Requested 2026-11-09. User design reviews and live acceptance are explicitly deferred.

## Goal and design

Reduce redundant information while keeping recorded evidence and statistical meanings intact. Use the existing Lua report, tooltip and menu components. Replace the lifetime location column with observed source-specific chances. Compact crafting rows into recipe, attempts, completed, completion percentage, matched operations, items and observed proc percentages; retain detail menus and explicit denominators. Unknown chances remain unknown.

Remove unnamed source IDs from presentation, retain readable source names/categories and zones. Item tooltips show a total only when both bags and bank contribute; the panel never shows totals and joins bag/bank values with `/`. Supporting information uses the small game font, without changing native item tooltip content. Shorten only the broker caption, leaving manifests and product identity intact.

Flight points use green for confirmed visits, amber for client-reported undiscovered nodes and gray for unconfirmed discovery. Persist only the current node observed when opening a flight master's taxi map, by character. The map-wide isUndiscovered=false flag alone never confirms a visit. Preserve native interactions and restore native texture colors when decorations are removed. Remove flight-menu explanations. Add an independent PvP history recording control which preserves prior data and native totals.

## Constraints and review focus

- WoW Forever 1.60.1, interface 16001; LuaJIT with Lua 5.1 semantics. No manifest/API replacement or release version bump.
- Preserve SavedVariables, history denominators, independent map controls and native click handlers.
- No aggregation of unrelated source probabilities; combined views use existing summed hit/trial rates.
- No inferred flight visits from proximity, remote nodes or false discovery flags. Unsupported/unready taxi APIs keep status unconfirmed.
- User explicitly deferred review gates; execute in the current checkout without commits, pushes or publication.

## Tasks

- [x] Reports: update tests for source probability and compact production columns, watch failures, implement Reports.lua and pass tests/reports.lua.
- [x] Presentation: update integration tests for concise caption/counts/source labels and small informational text, watch failures, implement Tooltips.lua, Style.lua and Titan.lua, pass integration/presentation suites.
- [x] PvP: add failing independent recording toggle and persistence tests, implement Settings.lua and Core.lua gates plus Titan.lua menu control, pass integration suite.
- [x] Flights: add failing false-discovery, visited-current-node, character isolation/persistence, tint/restoration and closed-map tests; implement FlightPaths.lua and settings storage; pass flight suites.
- [x] Verification: run python3 tools/check.py and git diff --check, inspect diff, update current documentation, preview/apply safe installation and byte-verify all runtime files. Keep live validation deferred and record results here.

## Execution evidence

- Report regressions failed against the old location/multiline layout, then passed with source chances and compact columns. Host regressions failed for the old caption, normal-size note font and absent PvP toggle before their implementations.
- Flight regressions reproduced false discovery claims, missed pre-world-map interactions and stale native tint restoration. All pass after the tracker separation and ownership-aware tint restoration.
- Final checks: 405 checks (76 Python, 329 Lua), every shipped Lua file compiled with Lua 5.1 semantics; git diff --check clean.
- Independent code review identified the two flight lifecycle issues above; both received failing-then-passing regressions. Minor deferred: the lifetime summary shows up to three sources without a numeric remaining-source indicator. Its help text and click menu expose all sources.
- Installer preview and apply completed. Previous candidate: Interface/.tgf-v3-backups/candidate-eqi9ea04. All 57 runtime files across fourteen installed addons match the packaged source candidate byte-for-byte, with no extra runtime files.
- User reviews and live acceptance remain deferred. Lua-only update: /reload loads it. No commits, source push, tags, release assets or hosting changes.

## Source integration follow-up

The user subsequently authorized committing the verified changes and publishing them on main. The checkout is already on main. Fetch and compare origin/main, rerun the full checks, inspect staged files, commit the implementation and push without rewriting remote history. Release assets and hosting remain outside scope.
