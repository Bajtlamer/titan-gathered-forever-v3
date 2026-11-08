# Profession action counters

## Current status, 2026-11-08

Implemented, tested and installed. Live event-order, fishing/disenchant, combined-character and persistence acceptance remains pending. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective and scope

Implement the automated portion of Milestone 2 without reinterpreting existing loot history. Add per-character Mining, Herbalism, Skinning, Fishing and Disenchanting action counters, recording controls and a native report. Live event-order validation remains a separate release gate.

## API evidence and decisions

The Forever UI source at commit `9dc84f0d3bbae1768ac3405b3716000bd93eda06`, `Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua`, registers START, STOP, FAILED, INTERRUPTED, CHANNEL_START and CHANNEL_STOP. Its handlers consume unit, cast GUID and spell ID. CHANNEL_STOP includes an optional interrupting unit, but does not establish why an ordinary player fishing channel ended. Existing addon code already consumes SUCCEEDED and IsFishingLoot.

Reference: https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua

Ruling: count an observed action once per readable cast GUID when START, CHANNEL_START, SUCCEEDED, FAILED or INTERRUPTED is observed for a recognized profession spell. Missing START does not discard an otherwise evidenced action. STOP alone cannot create a new attempt. Non-fishing SUCCEEDED confirms spell completion, independent of obtained loot. Fishing SUCCEEDED launches the line; a fishing-loot window confirms completion, independent of taking items. Never infer attempts from old source history.

Ruling: FAILED and INTERRUPTED remain separate. STOP/CHANNEL_STOP without stronger evidence is labeled stopped without confirmed result, not manual cancellation or guaranteed failure. Later success evidence can replace that provisional stop. World transitions, reloads and recording changes seal pending observations as unresolved; do not invent outcomes. A fishing catch can update only the current unsealed fishing action within 45 seconds, before another player action begins.

## Implementation steps and interfaces

1. Add `tests/actions.lua`, first failing against the absent Actions module: duplicate and out-of-order events, all five professions, unpaired terminal evidence, fishing launch/stop/interruption/loot, unrelated casts, invalid values, recording pauses, reloads, bounded receipts and combined aggregation. `Actions.New(saved, api)` uses Character, Name, Timestamp, Now, Enabled and Changed callbacks. Public methods: Cast(event, unit, guid, spell), FishingLoot(), Pause(), Rows(character).
2. Implement `Actions.lua` with schema 1, per-character aggregates and at most 1024 recent receipts. Store first recording time per profession and last observation time. Keep source history and inventory untouched. Add the manifest entry and checker command.
3. Add failing integration/report tests. Wire Core events into Actions before the loot collector; only the original four spell events continue to the existing collector. Add saved recordActions/actionProfessions settings, master and per-profession controls, `/tgf actions` and a third native report with character/combined selection and profession filters. Recording works independently of history and map settings. Preserve historical records when modules are disabled.
4. Run `python3 tools/check.py`, review the complete diff independently, update README, roadmap, progress and in-game validation steps. No installation, version publication or commits are required by this task.

## Review focus and success criteria

Check fishing stop-before-loot order, stale fishing identity, paused recording with late terminal events, event duplication across reload, old saved-data preservation and current/combined report labels. Automated tests must demonstrate actions do not change source denominators, item quantities or map spots. Full checker and shipped Lua compilation must pass. Real-client fishing, stop and disenchant event flows remain unverified until exercised in game.

## Execution record

- Existing installer work and user edits retained in the requested workspace. No branch changes or deployment.
- Tasks 1 and 2 complete: wrote failing action tests, implemented separate schema-1 storage and bounded receipts. Unknown future schemas remain untouched.
- Task 3 complete: watched new host/report tests fail, then wired controls, native report and event handling. Added a failing stale-fishing regression and fixed superseded receipt reactivation before counting catches.
- Full checker: 208 checks (40 Python and 168 Lua), plus shipped Lua compilation. Real-client acceptance remains pending; no deployment or publication.
- Independent review complete: no remaining important correctness findings after the stale fishing START regression fix. Reviewer independently ran the action, host integration and report suites. Real-client event ordering and visual layout remain acceptance gates.
