# Titan Gathered Forever v3: Next Development Plan

Updated 2026-11-08. This is the current continuation roadmap. Focused plans preserve the initial designs, execution evidence and later corrections; historical instructions do not override this roadmap or AGENTS.md.

## Current baseline

- Repository: https://github.com/Bajtlamer/titan-gathered-forever-v3, branch main. This update prepares the accumulated work for a source commit and push; it does not create a release tag.
- Development candidate: 0.4.1-alpha, WoW Forever 1.60.1, interface 16001. Latest captured installation build: 70862. The live API/build compatibility gate remains explicit.
- Fourteen runtime addon folders: shared core, twelve professions and Auction Items. The current runtime package has 56 files. Development tools, tests, catalogue evidence and documentation stay outside these folders.
- All 360 automated checks pass, plus shipped Lua compilation. The candidate is installed locally and was byte-verified against source. The user confirms the icon configurator works; broader live acceptance is pending.
- Changelog: [unreleased development updates](release-notes/ref-unreleased.md). Current implementation and installation history: [progress](ref-wow-forever-progress.md).

## Standing constraints

Preserve separate profession addons, existing settings/history and unrelated addons. Use tools/install.py with preview, backups and verification to install each completed runtime update automatically into the user's Forever AddOns directory. Report installation failures. Do not restart the user's game or edit SavedVariables automatically. Source commits/pushes and release publication require their own user authorization; the current request authorizes commit and push.

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

## Immediate next steps

1. Let the user continue testing. Obtain a current screenshot/reproduction of the reported Linen Cloth artwork clipping/offset in Full image mode. It occurs across shapes and sizes according to the user. Do not claim the cause is confirmed or deploy a guessed offset fix.
2. Exercise the affected live checklists in book-wow-forever-validation.md, prioritizing production results, fishing/disenchant timing, bank updates, export round trips and native flight styling/persistence.
3. Continue evidence-backed catalogue reconciliation. Keep incomplete release gates explicit.
4. Fix confirmed defects with regressions, run the full checks and automatically install verified runtime changes with backups.

## Milestone 7: Release readiness, remains open

- Complete and record the live acceptance checks and resolve or clearly document outstanding defects.
- Assign a new version only when preparing an actual release; keep manifests and generator synchronized.
- Prepare release notes and package the collection plus fourteen individual ZIPs, downloads.json and SHA256SUMS.
- Publish tags/releases and website uploads only when authorized. A source push or local installation does not publish release assets or change hosting.
