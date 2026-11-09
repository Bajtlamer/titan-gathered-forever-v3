# Profession storytelling and expandable history

Requested 2026-11-09. Auto-mode, website first and in-game changes second. Continue the existing website PR and keep rollback backups. Every completed update increments its own version: website 1.1.0 for the visual update, addon 0.4.2-alpha for the report improvement, then website 1.1.1 when publishing that new addon download set. No unchanged archive is silently overwritten.

## Design

Twelve separately generated profession scenes, not repeated crops. Preserve original game profession icons with circular gold frames. Use an original WoW bag/download symbol in circular frames. Four desktop rows of three cards are separated by three alternating screenshot-led feature stories; add a compact screenshot tour for the remaining windows/settings. Actual screenshots from Downloads/tg3 are cropped/resized without synthesizing UI text or values, decorated using CSS and visible captions. Keep narrow layouts sequential and keyboard accessible. Clearly distinguish captured old history layout from the upcoming source tree.

In-game lifetime materials retain a compact parent item row with quantity and a clickable plain [+]/[-] source summary. Expanded children show each source/zone independently with its percentage and hits/samples; preserve all evidence and never combine unrelated probabilities. All sources remain accessible with paging. Retain item hovers, detail menus and independent filter/scope/page state. Expansion is per-window, not SavedVariables.

## Tasks

- [x] Inspect provided screenshots and build deliberate UI crops; preserve screenshot text and avoid unrelated chat/world clutter.
- [x] Generate twelve independent profession images; record each prompt/source/hash and produce optimized local assets.
- [x] Add failing website structure/art provenance tests, implement interleaved feature sections, circular frames, download symbol and website version 1.1.0.
- [x] Run source/package, PHP, local smoke and responsive browser checks; review, update PR, back up and deploy website first.
- [x] Add failing report regressions for expansion/collapse, all source access, independent probabilities, unknown evidence, page bounds and report state; implement tree and version 0.4.2-alpha.
- [x] Run full addon checks, automatically install with backup and byte verification. Publish source branch/PR, build new versioned package set and release notes.
- [ ] Refresh website downloads and matching instructions to addon 0.4.2-alpha, website 1.1.1; test all current/legacy archives, update PR and deploy with backup.

## Constraints

No manifest API/interface changes; LuaJIT/Lua 5.1. Preserve settings/history/observations and separate counts/denominators. Unknown remains unknown. No synthetic screenshots. No release tag or main merge unless separately requested. Record exact installation/deployment verification and leave live report acceptance pending /reload.

## Execution evidence

Website 1.1.0 shipped first from a4988cf, with twelve independently generated artworks and twelve unchanged-UI screenshot crops. CI and live HTTP/browser checks passed at 320/390/768/1440 pixels, including all fifteen current and eight legacy archives. Pre-deployment backup: /opt/titan-gathered-backups/20261109T221052Z. Existing website PR remains open.

The old lifetime source-summary regression failed before implementation. The new parent/child tree passes nineteen report checks, including all fifty sources on bounded continuation pages, separate 50%/100% denominators, combined 2/3 rates, unknown evidence and collapse/page bounds. Full checks: 408 (76 Python, 332 Lua), plus every shipped Lua compilation. Independent review found no critical/important issue; native font rendering remains a live gate.

Installed 0.4.2-alpha automatically with the safe installer after checks/review. All 57 runtime files across fourteen addons match the new package byte-for-byte. Previous candidate: Interface/.tgf-v3-backups/candidate-yndg5ybt. Built fifteen new versioned ZIPs and matching downloads.json/SHA256SUMS under dist/releases/0.4.2-alpha. No SavedVariables were edited. /reload is required for live acceptance.
