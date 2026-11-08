# Tooltip Restoration and Gathering Map Implementation Plan

## Current status, 2026-11-08

Historical implementation/design record. Some original decisions and task restrictions were superseded. Use README.md, ref-wow-forever-runtime.md and plan-next-development.md for current behavior and remaining work. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

User authorized autonomous implementation, including item rarity colors and configurable map spotting. Existing separate profession addons remain unchanged in purpose.

## Required behavior

- Use WoW's item rarity colors for material names. Restore orange/gold TGF v3 headings, distinct count/skill colors, and section separators without recoloring the native item tooltip.
- Restore learned primary and secondary professions, with current/max skill, independently of installed data addons.
- Remove the separate total-count setting. Bank enabled means Bags/Bank/Total; bank disabled means Bags alone and no bank scan.
- Completed empty scans and unavailable counts display zero. This follows the user's later clarification, superseding the initial unknown-before-bank-visit agreement. Keep scan state internally and never fabricate saved observations. Displayed Total sums Bags and Bank; readiness retries and diagnostics remain available.
- Record personally gathered Mining/Herbalism locations only after a recognized successful gathering cast and cleared loot from a game-object source. Do not mark purchases, mail, failed/interrupted gathering or ordinary corpse/chest loot.
- Persist resource type, approximate player map position, observation count and time. Merge nearby observations of the same resource; cap retained locations per map.
- Provide a master map switch plus Mining and Herbalism switches. Disabling hides pins and stops new recording, retaining saved observations. Disabled profession addons also disable their mapping data.
- Render small resource icons on the world map through a private overlay. The original world-map-only scope is superseded by the 0.3.5 minimap requirement below. No preloaded node database is included.

## Implementation tasks

1. Regression tests for automatic Total, empty bank retry, rarity formatting, primary/secondary learned ranks and section separators. Add `Style.lua` and `Professions.lua`; preserve previous settings except obsolete `showTotal`.
2. Test and implement a pure `Gathering.New(api, saved, resources, enabled)` controller. Methods: `Cast(event, unit, castGUID, spellID)`, `LootReady()`, `SlotCleared(slot)`, `LootClosed()`, `List(mapID)`. Validate coordinates, expiration, cancellation, source identity, resource priority, deduplication, persistence and limits.
3. Generate gathering-resource maps only inside Mining and Herbalism addons. Prefer ordinary ore/herb loot over scarce byproducts when choosing the marker icon.
4. Implement `Map.lua` as a private child overlay on the world-map canvas. Handle lazy map loading, map switches, resizing, toggles, pin reuse and resource tooltips. Avoid shared Blizzard pin pools/data providers.
5. Wire current Forever APIs/events, test the host integration and map renderer with fake client surfaces, and retain an explicit real-game acceptance checklist.
6. Bump to `0.3.0-alpha`, regenerate all modules, review independently, run `python3 tools/check.py` and build bundle/individual ZIPs. Preserve AGENTS.md and do not modify the installed game.

## Runtime evidence

The installed Titan release is now 9.3.5 and the installed Gathered manifest is 0.2.0-alpha. The installed game remains Forever interface 16001. The local saved addon state has no personal-bank snapshot.

Primary client references: [skill APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SkillInfoDocumentation.lua), [map APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua), and [map canvas](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua). Exact live event timing remains a manual validation gate. Gathering pins represent the player's position near a successful gather, not guaranteed exact object coordinates.

## Progress

- All six implementation tasks completed for `0.3.0-alpha`. Separate profession packaging is preserved.
- Independent review identified a persistent-clock defect and malformed-saved-entry handling gap. Both were corrected; regression checks cover uptime resets and pruning before eviction. A separate regression covers a map canvas whose dimensions become available after attachment.
- `python3 tools/check.py` passes: 17 Python tests, 17 catalogue/inventory tests, 21 host/tooltip tests, six addon-loading scenarios, eight presentation checks, 14 gathering tests and eight map checks. Every shipped Lua manifest entry compiles with Lua 5.1 semantics.
- Live acceptance remains pending in `book-wow-forever-validation.md`. In particular, a GameObject source is not proof of a particular node: test an ordinary chest immediately after a successful gathering cast as well as ordinary chest loot without one. No installed game files were changed.

## 0.3.1 tooltip corrections

Reported visual issues were reproduced in the rendering code: fixed-length dash strings, no rule before material columns, plain-white recipe/use text and redundant addon-title lines. These are replaced by resizing texture rules with clear/reset handling, an explicit skills/material break, distinct information colors and compact headers. Three additional host regressions cover layout, semantic colors and bank diagnostics; the full checker passes.

The inspected installed manifest confirms 0.3.0. Diagnostics identify the unreadable container/capacity/item or API exception instead of a generic failure.

## 0.3.2 count-display clarification

The user explicitly requires zero instead of unknown even before visiting the bank. Both item and Titan tooltips now normalize unavailable counts to zero and compute displayed Total from displayed Bags and Bank. The bank-visit reminder is removed. Internal unknown/cached/current states and complete-scan persistence are preserved for diagnostics. Regression coverage checks an unvisited bank, unavailable initial scans, arithmetic and absence of fabricated snapshots.

## 0.3.4 missing herb spot investigation

Installed 0.3.2 has mapping and Herbalism enabled, with no persisted spots; Scout data separately confirms a Silverleaf loot observation. Investigation found that existing loot-slot records never refreshed sources between `LOOT_READY` and `LOOT_OPENED`. A failing regression with delayed source metadata now passes, and a collector-to-renderer check verifies the herb item icon at the recorded coordinates. Metadata refresh preserves taken state. The runtime now exposes the last recording stage through `/tgf status`, with optional traces gated by Debug mode. Exact user event timing and visual appearance remain live validation gates. Event payloads were checked against the [Forever loot API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua).

## 0.3.5 saved spots without visible icons

New evidence: installed 0.3.4 saved three real herb spots on Mulgore map 1412 while the user still saw no icons. Focus moved from recording to drawing. A failing scale regression showed that the 14-pixel buttons inherited the scaled art canvas and shrank; dimensions now compensate for effective scale, including zoom changes without size changes. Related-map projection handles browsing a containing map instead of the exact saved zone.

The user also expects minimap icons. Add a native private minimap overlay using normalized player/map positions, map size in yards and the current minimap radius. Refresh at 0.2 seconds, rotate with player facing when configured, hide out-of-range icons, reuse buttons and respect existing profession/master switches. Add independent saved World map icons and Minimap icons preferences, both enabled by default. Keep no-data modules and disabled overlays inactive.

Verification includes saved-herb-to-icon tests, effective-scale changes, parent-map projection, minimap rotation/movement/zoom/range and toggle persistence. `/tgf status` reports saved spots plus world-map ID and drawn counts for both renderers. Live pixels remain unverified: computer inspection reached the login screen, and login requires the user. No installed game files are modified.

Review found no blocking defect. Fixed the additional same-size replacement-canvas cache issue with a regression; reparenting also refreshes the overlay frame level. Final automated verification passes 109 checks and all shipped Lua compilation. This is evidence of the implementation, not a claim that the icons have been observed in the live client.

## 0.3.6 confirmed live rendering cause

Installed 0.3.5 was inspected in the actual running client. Mulgore had three saved nodes and three visible frames with valid textures, positions and full opacity, but no visible pixels. A controlled temporary strata change from MEDIUM to HIGH revealed all three actual herb icons. The permanent fix applies HIGH strata at frame creation. A regression fails without that assignment and passes with it. Live world-map visibility is now confirmed; minimap proximity behavior still requires checking near a saved spot. The game files and observations were not modified; the temporary in-memory fix lasts until reload.

## 0.3.7 approved circular-pin styling and version caption

Implement the user-approved live preview on both map surfaces: native `CircleMaskScalable` item masking, thin golden circular border and a small soft shadow down/right. Allocate decorations once per pooled pin, resize them proportionally with the existing world-map zoom compensation, and preserve HIGH strata. The native atlas was verified in the running Forever client.

Replace the Titan caption material count with the manifest version. Keep the existing addon-name label and all tooltip counts; remove the redundant count loop from refresh. Regression verification covers caption contents and mask/border/shadow/reuse/resize behavior.


## 0.3.8 profession and material controls

Implemented Skinning observations from successful casts and taken supported corpse loot. Preserve every distinct obtained material and separate coincident icons for readability. Exclude recording inside all instance types, including raids, and cancel pending casts on world transitions.

Provide saved Mining, Herbalism and Skinning switches and a Map materials submenu grouped by loaded profession. Every supported gathering material has a visibility checkbox; each profession includes Show all and Hide all. Material visibility affects both maps and retains saved spots and ongoing recording. Master/profession/category disabling stops recording too. World-map and minimap display switches remain independent.

Verification: 126 checks and shipped Lua compilation pass. Independent review found no blocking defect. Live acceptance still covers Skinning event timing, source correlation, multi-material loot and icon separation. Other professions require meaningful source detection before adding map collection.

## Screenshot correction: exact positions and transparent image rendering

User supersedes the previous material-separation presentation: every marker must remain centered on its saved/projected position regardless of neighboring markers or observation count. Removed PinStyle.Offset and its world/minimap callers. Default pins retain only the image layer with source alpha, without masking/cropping, filled gold discs or shadows. Flight status colors use edge-only backdrops without center texture, preserving their separate feature requirement. Coordinate/count tests and no-fill/alpha-preservation tests were observed failing before the changes.

An opaque source image is not made transparent by changing its container or file extension. The user confirmed keeping the original WoW images without addon borders. No new cutout asset set is required, and source image alpha is preserved unchanged. Existing data and earlier installed candidate are untouched.

Final verification: 337 checks (75 Python, 262 Lua), every shipped Lua file compiles, and whitespace checks pass. Independent focused review found no important findings. A zoomed-out flight-border regression failed at 0.25 UI pixels before proportional border resizing, then passed at one UI pixel. No deferred findings. Updated candidate remains local, with no live files or saved data changed.
