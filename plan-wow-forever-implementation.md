# WoW Forever Implementation Plan

> For agentic workers: use superpowers:executing-plans task by task. Review the complete implementation before delivery.

**Goal:** Implement a Forever-only Titan plugin with item-use reasons and accurate bags, personal bank, and total counts.

**Architecture:** One addon, numeric item IDs, generated recipe relationships, a container inventory service, tooltip rendering, and a Titan Data Broker object. Keep generation evidence outside the addon.

**Tech stack:** WoW Forever Lua 5.1 APIs, LuaJIT for local tests, Python standard library for data validation and packaging.

**Spec:** `plan-wow-forever-rewrite.md`, including its Wowhead findings. User approved autonomous execution on 2026-11-06.

## Global constraints

- Forever only: installed client 1.60.1.70790, interface 16001, product wowf.
- Titan remains required; use its supported LibDataBroker integration and a private summary tooltip.
- Current character's carried bags and personal bank only. Unknown bank must never become a fabricated zero.
- Numeric IDs determine identity. Item and recipe names are resolved by the client.
- Curated auction-use scope is the autonomous default, not a claim that all tradable equipment is useful.
- Preserve AGENTS.md. No writes to the installed game or publishing.
- This source copy has no Git repository. Keep a local original archive and a progress ledger instead of worktree/commit steps.

## Review focus

- Bank closed before queued scans, switching bank type, and unavailable bank data preserve the last observation.
- Empty banks clear old items, but failed scans never clear snapshots.
- Metadata delays and repeated tooltip callbacks do not corrupt or duplicate output.
- Shared reagents appear in multiple profession views without inflating aggregate totals.
- Data imports reject unsupported professions, conflicting spell IDs, and invalid quantities; incomplete evidence stays explicit.

## Task 1: Data generation

Files: `tools/generate_catalog.py`, `data/forever-recipes.json`, `data/curated-uses.json`, `tests/test_catalog.py`, `TitanGatheredForeverV3/Data/Items.lua`, `TitanGatheredForeverV3/Data/Recipes.lua`.

Interface: `build_catalog(dataset, curated)` returns item-ID records with deduplicated recipe uses; `generate(root, check=False)` emits deterministic Lua and an audit of every old ID.

- [x] Write and run failing Python tests for multi-profession membership, invalid IDs/quantities, duplicate/conflicting recipes, curated reasons and deterministic generation.
- [x] Implement validation, deterministic output, legacy reconciliation, and source hashes. Preserve unknown source-build metadata instead of inventing a pin.
- [x] Run `python3 -m unittest discover -s tests -p 'test_*.py'` and `python3 tools/generate_catalog.py --check`.

## Task 2: Catalogue and inventory

Files: `TitanGatheredForeverV3/Catalog.lua`, `TitanGatheredForeverV3/Inventory.lua`, `tests/run.lua`.

Interfaces: `Catalog.Get(itemID)`, `Catalog.List(settings)`, `Inventory.New(api, saved)`, `inventory:RefreshBags()`, `inventory:RefreshBank()`, `inventory:Get(itemID)`, `inventory:SetBankOpen(open)`.

- [x] Write and run failing Lua tests for ID identity, filters, bag stack aggregation, unknown/zero bank, transfers, stale snapshots, character isolation, and failed scans.
- [x] Implement container scans using `NUM_TOTAL_EQUIPPED_BAG_SLOTS` and `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)`. Never use old negative bank IDs or retail tab constants.
- [x] Run `luajit tests/run.lua` against fake container APIs, including access failure halfway through a bank scan.

## Task 3: Presentation and host integration

Files: `TitanGatheredForeverV3/Localization/enUS.lua`, `Settings.lua`, `Tooltips.lua`, `Titan.lua`, `Core.lua`, `TitanGatheredForeverV3.toc`, `tests/integration.lua`.

Interfaces: `Tooltips.Lines(itemID)` returns use reasons and labels; `Tooltips.Append(tooltip, data)` appends once per item-processing cycle; `Titan.Refresh()` updates the broker and visible private summary; `Core` owns event coalescing and character settings.

- [x] Write and run failing integration tests for addon loading, broker registration, context menu toggles, metadata callbacks, tooltip recycling, unsupported client rejection and event coalescing.
- [x] Implement the modules and a slash diagnostic command. Use the native tooltip data processor and menu API, with no compatibility fallbacks for old clients.
- [x] Verify `luajit tests/integration.lua` and all previous checks.

## Task 4: Package and handoff

Files: `tools/package.py`, `ref-wow-forever-runtime.md`, `ref-wow-forever-progress.md`, `book-wow-forever-validation.md`.

- [x] Validate manifests and compile every shipped Lua file with Lua 5.1 semantics.
- [x] Move the legacy implementation out of addon discovery after the new tests pass. Preserve the original local archive and old-item audit.
- [x] Build a ZIP containing only the new addon and icon. Check package contents and deterministic regeneration.
- [x] Review the whole implementation independently and fix important findings with regression tests.
- [x] Report automated results separately from game/Titan validation and data availability limitations. A package with incomplete live verification remains an alpha, not a completed release.

## Execution result

The implementation steps above are complete for the alpha, with 38 automated tests passing. In-game compatibility and complete live catalogue verification are still pending release gates, not completed tasks. See `ref-wow-forever-progress.md` and `book-wow-forever-validation.md`.
