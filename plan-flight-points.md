# Flight Points Implementation Plan

## Current status, 2026-11-08

Implementation/review complete and installed. Initial no-install/no-commit constraints below are historical. Discovery status is in tooltips; an optional gold outline and separate flight appearance settings replace mandatory colored borders. Live native-provider acceptance remains open. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

> For agentic workers: use superpowers:executing-plans inline with TDD and a final independent review.

Goal: show all client-exposed, faction-appropriate world-map flight points with discovered/undiscovered border colors.
Architecture: independent FlightPaths module queries live map taxi data and manages a pooled overlay. Decorate matching native flight pins rather than duplicating them. No flight database or gathering dependencies.
Tech stack: existing Lua 5.1 addon, C_TaxiMap and world-map canvas.
Spec: plan-flight-points-design.md.

## Global constraints and rulings

Preserve all prior uncommitted work. Work in this checkout because the feature depends on the uncommitted candidate already installed for testing; a new checkout of HEAD would omit it. No branch integration, commits or live installation in this pass. Existing auto-mode instruction authorizes routine design/implementation choices and continuing without another approval cycle.

## Review focus

Unknown/restricted faction and discovery values must not leak opposing-faction markers or invent an undiscovered state. Native pin reuse must not leave colored decorations or tooltip state on recycled pins. A disabled gathering feature and no profession modules must not disable flight points. Native event timing and API failures must not retain old-map nodes. Canvas replacement/zoom and native redraws must not allocate frames repeatedly or duplicate markers.

## Task 1: Flight data and rendering

Files: create TitanGatheredForeverV3/FlightPaths.lua and tests/flight_paths.lua. Add FlightPaths.lua to the core manifest after PinStyle.lua. Interface: FlightPaths.Read(mapID) returns sanitized current-character nodes and a diagnostic status; FlightPaths.New(world), Attach(), Update() manage an independent overlay. Each node has nodeID, name, faction, atlasName, x, y and status (discovered, undiscovered, unknown).

- [x] Write failing tests for faction filtering, discovery booleans, invalid coordinates/IDs/factions, restricted values and missing/throwing API. Run luajit tests/flight_paths.lua; expected feature-missing failure.
- [x] Implement Read, safe node validation and live API calls. Add tests for map and canvas lifecycle, scale, pool reuse, independent setting, native reuse and cleanup. Run focused tests to pass.
- [x] Implement independent overlay with a 0.2s visible-map refresh, API cache invalidated by context/events (retry failures after 2s), native node deduplication and addon-owned border/tooltip cleanup. Existing native click handlers remain intact.

## Task 2: Integration, verification and documentation

Files: Settings.lua (flightPoints boolean default true), Titan.lua (Flight points menu independent of Gathering map), Core.lua (attach on login/late map load), tests/integration.lua and tools/check.py (new suite).

- [x] Add failing integration tests for default/persisted setting, menu toggle and no-module attachment; run luajit tests/integration.lua and observe expected failure.
- [x] Integrate initialization, persistent toggle and menu legend. Run focused suites and python3 tools/check.py; expected all pass and every shipped file compiles.
- [x] Extend README, validation checklist and progress/roadmap notes with current data-source limits, colors and native behavior when disabled.
- [x] Obtain independent focused code review. Fix important findings with failing regression tests, then run the full checker and git diff --check. Preserve the installed client candidate until separately requested.

## Execution record

Ruling: use current client nodes instead of static source data. Coverage inherits the live API; the cost is that unexposed nodes cannot be shown until their client data source is verified.
Ruling: unknown discovery gets a gray border. This avoids falsely directing players to already learned nodes; the cost is an extra status when the client cannot answer.
Ruling: native flight points retain normal behavior when the addon toggle is off. Only addon markers and decorations are disabled; the cost is that this is not a global Blizzard flight-marker hide switch.

- Task 1: complete. Observed feature-missing RED before implementation, then 16 focused scenarios passed. Added a failing open-tooltip discovery-update regression, traced stale text to OnEnter-only rendering, and refreshed owned tooltips on changed node status; 17 focused scenarios now pass.
- Task 2 implementation: host integration failed for the absent setting before wiring; 54 host scenarios now pass. Added manifest/checker coverage and a read-only installer preview; preview validates the runtime allowlist and performs no live writes. Independent review completed; the findings and fixes are recorded below.

- Final review: two important lifecycle findings. Reproduced missing first-layout readiness and stale native tooltip status after discovery, disabling and recycling. Fixed both in one pass: canvas watch is established before size validation; native decorations retain identity/status for comparison and clear owned tooltip content on changes/removal. Both regressions failed before fixes and pass afterward. No deferred findings.
- Final verification: 336 checks (75 Python, 261 Lua), including 19 focused flight-point cases and 54 host integration cases; all shipped Lua files compile and git diff --check is clean. No live writes, publication or commits. Current source candidate contains FlightPaths.lua; the installed earlier candidate does not.
