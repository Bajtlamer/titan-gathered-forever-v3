# Titan Gathered Forever v3: Next Development Plan

Updated 2026-11-09. This is the current continuation roadmap. Focused plans preserve the initial designs, execution evidence and later corrections; historical instructions do not override this roadmap or AGENTS.md.

## Current baseline

- Repository: https://github.com/Bajtlamer/titan-gathered-forever-v3, branch main. Interface refinements are installed locally. The follow-up user request authorizes committing and pushing these changes to main; no release tag is requested.
- Development candidate: 0.4.1-alpha, WoW Forever 1.60.1, interface 16001. Latest captured installation build: 70862. The live API/build compatibility gate remains explicit.
- Fourteen runtime addon folders: shared core, twelve professions and Auction Items. The current runtime package has 57 files. Development tools, tests, catalogue evidence and documentation stay outside these folders.
- The current interface candidate passes 405 automated checks and Lua 5.1 compilation. Its candidate is installed and all 57 runtime files were byte-verified; broader live acceptance remains pending.
- Changelog: [unreleased development updates](release-notes/ref-unreleased.md). Current implementation and installation history: [progress](ref-wow-forever-progress.md).

## Standing constraints

Preserve separate profession addons, existing settings/history and unrelated addons. Use tools/install.py with preview, backups and verification to install each completed runtime update automatically into the user's Forever AddOns directory. Report installation failures. Do not restart the user's game or edit SavedVariables automatically. Source commits/pushes and release publication require their own user authorization; the follow-up request authorizes committing the verified update and pushing main.

Keep attempts, completed casts, matched production results, obtained quantities, complete loot trials and item-hit frequencies distinct. Unknown coverage stays unknown. Never reconstruct unobserved history from inventory or create map coordinates from crafting/disenchanting. Instance observations may contribute to history but do not create map spots.

## Milestone status

### 1. Safe candidate installation: implemented and used

Preview, explicit target, runtime allowlist, backups, rollback and post-install verification are implemented. Repeated real-client installations are recorded in progress. Continue automatic installation after completed runtime updates. See plan-safe-candidate-installation.md and book-releases.md.

### 2. Profession actions: implementation complete, live acceptance pending

Per-character/combined action reports, independent controls, bounded receipts and explicit unresolved/stopped semantics are implemented and tested. Exercise actual fishing/disenchant event order, cancellations, reloads and persistence. See plan-profession-action-counters.md.

### 3. Crafting and cooking production: implementation complete, live acceptance pending

Recipe attempts, completed casts, matched output operations, distributions and explicit proc denominators are implemented. Test actual single/queued operations, result attribution, recrafts and recording gaps. Keep skipped/ambiguous observations explicit. See plan-crafting-production.md.

### 4. Contextual crafting: initial implementation complete

Fixed-reagent plans, deficits, selected inventory scope, freshness and contextual source evidence are implemented. Validate native recipe selection and tooltips in game. Complex required reagent choices remain unsupported; they must not produce a guessed overall estimate. See plan-contextual-crafting.md.

### 5. Statistics export: implementation complete, live acceptance pending

Schema-1 JSON, current/combined scopes, identity opt-in, safe numbered parts and offline reconstruction are implemented. Test clipboard/scroll behavior and complete round trips in game. The reader validates transport and framing rather than all statistical semantics. See plan-statistics-export.md and ref-statistics-export-format.md.

Next planned extension: add user-initiated Import statistics so a player can transfer a validated export to another WoW installation. Before implementation, define how imported per-character records merge with existing SavedVariables, how repeated imports avoid double counting, and how combined exports are unpacked without importing their aggregate twice. Preserve the current export format and require explicit review of the target character and import result.

### 6. Catalogue reconciliation: partial, remains open

Pinned mirror verification and the four-table 70862-labelled crosscheck match all 1,971 base recipe facts. Seven Fishing additions bring that module to 23 materials. Global counts remain 532 items and 1,973 recipes. The mirror sourceBuild remains null and complete remains false.

- Obtain live profession/recipe/material availability evidence.
- Resolve 456 legacy IDs and review 11 producer associations without unsupported removals.
- Expand output-free enchanting, Fishing and useful auction/supply coverage.
- Preserve the separate mirror and client-table provenance rather than relabelling the mirror to match the installed build.

See plan-catalogue-reconciliation.md, ref-catalogue-reconciliation.md and book-catalogue-reconciliation.md.

### Additional requested map features: implemented and installed

Faction-aware flight points expose current-client locations, including undiscovered routes. The current design uses native artwork and tooltip discovery text. Optional appearance settings now provide a thin gold outline; earlier mandatory green/amber/gray borders were superseded.

The small icon window provides independent world/minimap/flight size, shape and border settings. Apply persists, Cancel/close discards drafts, and Reset group affects the selected draft. Exact coordinates remain unchanged. Mining selects ore rather than a covering stone/gem; history retains all outputs. See plan-flight-points.md and plan-icon-appearance.md.

## Interface refinements requested 2026-11-09

User design reviews and live acceptance are deferred, as explicitly requested. The current interface refinement work is tracked in [plan-interface-refinements.md](plan-interface-refinements.md): lifetime source chances, compact crafting percentages, concise count/caption/source presentation, small explanatory text, independent PvP recording and interaction-confirmed flight visits. These replace earlier layout/discovery presentation requirements without changing historical records or manifest versions. All 405 checks pass, the safe installer completed and all 57 installed files match source. Previous candidate backup: Interface/.tgf-v3-backups/candidate-eqi9ea04. Older checklist entries below retain their original execution evidence; deferred live gates remain open and do not block this authorized implementation.

## Immediate next steps

### Lifetime acquisition occurrences, installed 2026-11-08

The user confirmed the compact lists changed but still needs how many times each item was looted or gathered. Add Times obtained beside obtained quantity, counting one occurrence per item per observed source receipt, including partial loot. Multiple stacks or later partial deliveries from that receipt must not increase the count again. Counts are not cast attempts or complete-source rate denominators.

Persist an additive per-item acquisition count. For legacy items recover a lower bound from completed item-hit aggregates and retained partial/invalidated receipts; mark the result incomplete because older partial receipts may have expired. Never infer occurrences from quantities, inventory or map spot counts. Combined views sum counts and retain any incomplete-history marker. Export the acquired-item count and uncertainty additively, leaving production totals and schema-1 framing unchanged.

- [x] Add failing model regressions for partial receipt deduplication, migration, reload/receipt eviction and combined uncertainty, plus report/export regressions.
- [x] Implement History.lua tracking and migration, Reports.lua Times obtained column and Export.lua acquired-only fields.
- [x] Run full checks, review, document semantics, automatically install and byte-verify the completed update. All 372 checks and Lua compilation pass; independent review found no important issues. All 56 installed files match source, with previous folders under Interface/.tgf-v3-backups/candidate-bqc6q0b1. Live occurrence-count acceptance awaits /reload.

### Compact report layout correction, installed 2026-11-08

User screenshot confirms overlapping report titles, descriptions and rows. The user approved showing one report at a time while retaining independent filters, scope and page. Use columns for Lifetime (material, obtained, crafted, last location), Chances (material, observed chance, hits/samples, quantity, source/zone) and Actions (profession, attempts, completed, failed, interrupted, stopped without confirmation, unresolved, recording start). Keep the production detail format and include it in exclusive report visibility. Preserve item hovers, source menus, production details, statistical meanings and saved data.

Use a 960 by 560 window, a 930-pixel content width, compact rows, wrapped text and height-aware pagination within the content area. Extremely long text is bounded by the content area; native item tooltips and source menus retain access to full item/source information. Do not claim live visual acceptance from simulated rendering tests.

- [x] Reproduce overlapping windows with a failing lifecycle regression; replace old tests that require simultaneous windows with retained-state expectations.
- [x] Add failing column/value and wrapped-row pagination regressions, including long names/sources, page bounds, empty views and production switching.
- [x] Implement Reports.lua layout and exclusive visibility, run report tests and all checks, review changes and update documentation.
- [x] Preview and apply the installer, verify all runtime bytes, and request /reload for live acceptance. All 366 checks and shipped Lua compilation pass; independent review found no actionable issues. All 56 installed runtime files match source. Previous folders: Interface/.tgf-v3-backups/candidate-38za0z8r. Live visual acceptance remains pending.

### Shared material visibility correction, installed 2026-11-08

The user approved one visibility setting per item, accessible from every profession submenu containing that material. Category-specific filters currently split Linen Cloth observations between First Aid and Tailoring. Use an item-ID-keyed preference instead of synchronizing separate copies. Profession-wide switches remain independent. Retain all observations, coordinates, counts and history; this correction does not resolve icon overlap or prove a texture defect.

Migration keeps a material hidden if any legacy profession filter explicitly hid it, unless an existing shared preference already supplies the value. Keep legacy settings for compatibility, but do not consult them after migration. Show all and Hide all affect the materials listed in the selected submenu globally.

- [x] Add failing integration regressions for both profession submenu paths, historical spots stored under either category, shared bulk actions, migration conflicts, reload persistence and independent profession switches.
- [x] Update Settings.lua migration, Sources.lua material accessors and Titan.lua menu callbacks; preserve recording while a material is hidden.
- [x] Run the focused LuaJIT suite, full tools/check.py, review the diff, update current documentation, preview and apply tools/install.py, then verify installed runtime bytes. All 363 checks pass; all 56 installed files match source. Backup: Interface/.tgf-v3-backups/candidate-p1l5kps8. Live shared-filter acceptance awaits /reload.

### PvP Board and outdoor PvP spots, implementation complete, live acceptance pending

The PvP Board separates client lifetime honorable kills and rank from addon-observed honorable kills and per-kill estimated honor by outdoor, Battleground and arena context. Other honor awards are excluded from these estimates. PvP death counts begin with this feature and require a lethal player or player-controlled source in the death recap. World-map and minimap spots are recorded only for an outdoor honor-confirmed player kill; eligible assist credit is sufficient. Tracked estimates are never added to native totals. See [design](docs/superpowers/specs/2026-11-08-pvp-board-and-world-spots-design.md), [implementation plan](plan-pvp-board-and-world-spots.md) and the validation checklist.

- [x] Add per-character tracking, context-aware honor events, PvP node persistence, map controls, markers and a separate board.
- [x] Add focused model, integration, map, minimap and report regressions; run the full check suite and review whitespace.
- [x] Install the candidate with the safe installer and verify all shipped runtime files. All 57 files match; the previous folders are backed up under Interface/.tgf-v3-backups/candidate-zza0heza.
- [ ] In game, verify outdoor honorable kill and assist markers, Battleground/arena event separation, PvP death versus PvE death, rank APIs, persistence and map clearing. Automated coverage is not live-client confirmation.

1. Validate Times obtained against item quantity after a gather, partial loot/reopening and /reload; verify lower bounds for older data. The user confirms the report layout changed. Continue the compact-layout checklist: open Lifetime materials, Observed chances and Profession actions in succession, confirm exclusive visibility and retained filters/pages, then check wrapping, page controls and item interactions. Shared Linen Cloth visibility is confirmed working by the user. The cloth artwork currently looks correct; monitor further experience without a speculative texture or coordinate-offset change.
2. Exercise the affected live checklists in book-wow-forever-validation.md, prioritizing production results, fishing/disenchant timing, bank updates, export round trips and native flight styling/persistence.
3. Continue evidence-backed catalogue reconciliation. Keep incomplete release gates explicit.
4. Fix confirmed defects with regressions, run the full checks and automatically install verified runtime changes with backups.

## Milestone 7: Release readiness, remains open

- Complete and record the live acceptance checks and resolve or clearly document outstanding defects.
- Assign a new version only when preparing an actual release; keep manifests and generator synchronized.
- Prepare release notes and package the collection plus fourteen individual ZIPs, downloads.json and SHA256SUMS.
- Publish tags/releases and website uploads only when authorized. A source push or local installation does not publish release assets or change hosting.
