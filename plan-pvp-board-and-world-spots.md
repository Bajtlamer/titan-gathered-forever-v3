# PvP Board and World PvP Spots Implementation Plan

> **For agentic workers:** Execute inline with test-first changes. The PvP design brief is `docs/superpowers/specs/2026-11-08-pvp-board-and-world-spots-design.md`.

**Goal:** Add a PvP Board for client-wide honor results and tracked PvP deaths, plus persistent map/minimap spots for honor-confirmed outdoor PvP kills.

**Architecture:** A small PvP recorder listens to legacy honor/death/stat events, persists only addon-observed activity, and submits outdoor kill locations to the existing map store as a non-item PvP node. A PvP report window reads client summary APIs defensively and clearly separates their all-mode coverage from the addon's new world/death coverage.

**Tech Stack:** WoW Forever 1.60.1 Lua 5.1, existing Gathering/Map/Minimap/Reports modules, SavedVariables and LuaJIT tests.

**Spec:** `docs/superpowers/specs/2026-11-08-pvp-board-and-world-spots-design.md`

## Global Constraints

- Target WoW Forever 1.60.1, interface 16001. Do not change the manifest or depend on later-only APIs without exact client evidence.
- Only a client honor message identifying an honorable player kill can create an outdoor PvP spot.
- Battleground and arena events may update the client-wide board, but must never create outdoor map spots.
- Never infer PvP deaths from generic death or recent-combat events. Unavailable data must remain unavailable.
- Preserve existing gathering map and history data. PvP map nodes have no fabricated `itemID` and do not enter profession, acquisition or loot-source statistics.
- Label tracked world honor amounts as event-reported estimates and native summary values according to their API meaning.
- After checks pass, preview and apply `tools/install.py` to `/Applications/World of Warcraft/_forever_/Interface/AddOns`, then byte-verify all shipped runtime files.

## Review Focus

- Generic honor awards, arena/Battleground rewards or bonus honor must not create an outdoor kill marker: test named kill messages separately from generic awards and inside instances.
- PvE deaths must not increase PvP deaths: test explicit player-caused death identification and a generic `PLAYER_DEAD` event.
- Existing material nodes, map filtering, clearing and pin tooltips must remain intact when a node has no `itemID`: test mixed map nodes and PvP-only clearing.
- Missing/malformed summary APIs must leave the board open and display unavailable values rather than errors or zeroes.
- Assist credit must count when honor identifies the honored victim, even when the player is not the killing blow source.

---

### Task 1: Record confirmed outdoor PvP kills and PvP deaths

**Files:** Create `TitanGatheredForeverV3/PvP.lua`; modify `TitanGatheredForeverV3/Core.lua`, `TitanGatheredForeverV3/TitanGatheredForeverV3.toc` and `TitanGatheredForeverV3/Settings.lua`; add `tests/pvp.lua` and integration cases.

**Interfaces:** `ns.PvP.New(saved, api)` owns character-scoped PvP observations. `PvP:HonorMessage(message, context)` accepts the localized honor event payload, event-time position and outdoor context, and returns/records a named honorable kill only. `PvP:Death(eventData, context)` records only an explicitly identified player-caused death. `PvP:Snapshot(character)` returns copied tracked totals and coverage timestamps. Missing APIs or ambiguous events return unavailable and do not mutate counts.

- [x] Add focused failing tests for a named honor-kill message, generic honor award, assisted honor kill, instance rejection, duplicate event protection, persistence, PvE death rejection and ambiguous death rejection.
- [x] Run `luajit tests/pvp.lua` and confirm the expected missing-behavior failures.
- [x] Implement bounded event deduplication and per-character SavedVariables for observed kill count, event-reported estimated honor, PvP deaths and coverage start.
- [x] Wire `CHAT_MSG_COMBAT_HONOR_GAIN`, relevant PvP statistic events and safe death signals into the Core event dispatcher. Gate outdoor capture on `IsInInstance() == false` and `instanceType == 'none'`.
- [x] Run focused tests and applicable integration tests.

### Task 2: Add PvP map nodes and rendering

**Files:** Modify `TitanGatheredForeverV3/Gathering.lua`, `Sources.lua`, `Settings.lua`, `Titan.lua`, `Map.lua`, `Minimap.lua`, `PinStyle.lua`; extend `tests/map.lua`, `tests/minimap.lua`, `tests/pin_style.lua` and integration tests.

**Interfaces:** Add `Gathering:RecordPvP(position)` to merge PvP nodes within the current map threshold, increment count and update `lastSeen`. PvP nodes use `{mapID, x, y, kind='PvP', count, lastSeen}` and no item ID. `Sources.Enabled('PvP')`, a dedicated `mapPvP` setting, menu visibility and per-map clearing govern display/storage as specified.

- [x] Add failing tests for mixed material/PvP node validation, nearby merge, distinct locations, map/kind clear, map filtering and tooltip values with no item ID.
- [x] Run focused map and minimap tests to verify expected failures.
- [x] Implement the additive PvP node type, dedicated icon, world/minimap pin branches and visibility/clear controls.
- [x] Connect Task 1 confirmed outdoor kills to `Gathering:RecordPvP` and ensure no PvP observations enter item history or source rates.
- [x] Run map, minimap, pin style and integration tests.

### Task 3: Build the PvP Board

**Files:** Modify `TitanGatheredForeverV3/Reports.lua` and `TitanGatheredForeverV3/Titan.lua`; extend `tests/reports.lua` and `tests/integration.lua`.

**Interfaces:** Add a separate `Reports.Show('pvp')` native window. Display client lifetime honorable kills and current/highest rank where available; addon-observed honorable kills and per-kill honor estimates by outdoor, Battleground and arena context; and tracked player-caused PvP deaths with the observation start date. Guard every optional client API and render unavailable fields distinctly from zero. Never add addon observations to native totals.

- [x] Add failing report tests for supported and absent APIs, malformed API returns, all-mode labels, estimates, tracked coverage, rank absence, scoped character data and exclusive window visibility.
- [x] Run `luajit tests/reports.lua` and confirm expected failures.
- [x] Implement a defensive snapshot adapter for client lifetime PvP statistics and add the PvP Board menu entry/window.
- [x] Ensure API-provided total honorable kills are not summed with addon tracked honor estimates.
- [x] Run focused report and integration tests.

### Task 4: Document, verify, install and prepare the PR

**Files:** Update `README.md`, `book-wow-forever-validation.md`, `plan-next-development.md`, `ref-wow-forever-progress.md`, `release-notes/ref-unreleased.md` and project tests as needed.

- [x] Document API-wide coverage, local tracking start, honorable-kill-only map eligibility, estimate semantics and live validation steps.
- [x] Run `python3 tools/check.py` and `git diff --check`; address all failures before installation.
- [x] Preview and apply `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'` and verify installed files against source. All 57 runtime files match; previous folders are retained under `Interface/.tgf-v3-backups/candidate-zza0heza`.
- [x] Record live-client acceptance separately. Do not claim unavailable death attribution or untested event/API behavior as working.
- [x] Review staged files, commit the implementation, push the feature branch and create a PR describing behavior, validation, and remaining live-client checks. PR #1 is open; live-client acceptance remains pending.
