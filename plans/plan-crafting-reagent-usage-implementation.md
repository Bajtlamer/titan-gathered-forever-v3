# Crafting Reagent Usage Implementation Plan

> **For agentic workers:** Execute inline with test-first changes. Keep this plan as the progress record.

**Goal:** Add a global reagent-use report with estimated quantities and per-profession shares from completed recorded crafts.

**Architecture:** Capture supported fixed reagent requirements with each production recipe receipt. Add those quantities once on completed casts to per-recipe usage aggregates. Combine recipe rows by reagent and profession for a one-row-per-item report, with a breakdown on selection. Aggregate characters only when the report scope requests it.

**Tech Stack:** WoW Forever Lua 5.1, existing Production and Crafting models, native report windows, LuaJIT test harness.

**Spec:** `docs/superpowers/specs/2026-11-08-crafting-reagent-usage.md`

## Global Constraints

- Use only fixed, required item reagents from supported recipe metadata.
- Count one completed cast, not output quantity, queue length or requested operations.
- Never infer unsupported reagent choices or use inventory deltas.
- Keep production outputs, acquisitions, action attempts and reagent estimates separate.
- Keep coverage start explicit and earlier use unknown.
- Run the full repository checker and install through `tools/install.py` after its preview.

## Review Focus

- Multiple outputs and proc quantities must not multiply reagent estimates. Regression: one completed receipt with multiple output results consumes the fixed requirements once.
- Duplicate completion/result events must not count twice. Regression: repeated completed event on a receipt adds no second usage.
- Failed and interrupted casts must add no usage. Regression: each terminal outcome leaves usage unchanged.
- Unsupported required slots must not report an incomplete recipe as fully known. Regression: no usage aggregate is added for that operation and report coverage remains explicit.
- Combined characters and profession percentages must preserve units and denominators. Regression: hand-calculated per-item totals and shares.

---

### Task 1: Persist completed recipe reagent estimates

**Files:** Modify `TitanGatheredForeverV3/Production.lua`; test `tests/production.lua` and `tests/crafting.lua`.

**Interfaces:** Use `api.Recipe(recipeID)` to return `reagents` as an itemID-to-fixed-quantity map and `reagentsSupported` as a boolean. Store per-recipe `reagentUse`, `reagentCoverageBegan` and `reagentCoverageIncomplete` with schema 1. Receipt snapshots prevent later recipe metadata changes from changing prior observations. Missing or unsupported requirements are not accumulated.

- [x] Add regression tests for fixed reagent metadata, completion-only count, multiple result events, unsupported requirements and combined rows.
- [x] Implement fixed reagent extraction from the existing validated recipe schematic and store receipt snapshots.
- [x] Add one-per-completed-cast updates to per-character recipe aggregates. Aggregate usage and coverage in `Production:Rows`.
- [x] Run focused production and craft metadata tests.

### Task 2: Global reagent usage report

**Files:** Modify `TitanGatheredForeverV3/Reports.lua`, `TitanGatheredForeverV3/Titan.lua`; test `tests/reports.lua`.

**Interfaces:** Add `Production:ReagentUsage(character)` returning sorted rows `{itemID, quantity, professions={kind=quantity}, coverageBegan, incomplete}`. The report shows one reagent per row, estimated quantity used, leading profession and its percentage of this reagent's tracked total. Clicking opens a profession quantity/share breakdown. Add a report menu/window named `reagentUsage`; retain exclusive window visibility and report-specific state.

- [x] Add regression tests for supported usage, leading-profession percentage, combined scope, item breakdown and exclusive report switching.
- [x] Implement aggregation and report UI with explicit estimate/coverage text.
- [x] Run focused report and production tests.

### Task 3: Export, documentation, full verification and install

**Files:** Modify `TitanGatheredForeverV3/Export.lua`, `tests/export.lua`, `README.md`, `book-wow-forever-validation.md`, `plan-next-development.md`, `ref-wow-forever-progress.md`, and `release-notes/ref-unreleased.md`.

- [x] Add acquired-independent reagent estimate export and regression coverage; keep schema-1 framing additive.
- [x] Document coverage, estimate limits, profession shares and manual in-game acceptance.
- [x] Run `python3 tools/check.py` and `git diff --check`; review the completed diff.
- [x] Preview and apply `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'`; byte-verify every installed runtime file against source.
