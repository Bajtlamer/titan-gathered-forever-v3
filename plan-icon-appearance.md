# Icon Appearance Window Implementation Plan

## Current status, 2026-11-08

Implemented and installed; the user confirms the window works. All three appearance groups are independent, and the optional outline is now gold. The reported artwork clipping/offset remains unresolved across modes. Current full verification is 360 checks plus shipped Lua compilation. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

> Use superpowers:executing-plans inline with test-driven development and one final independent review.

## Design and decisions

The user requests a small in-game window for icon size, borders and square/circle appearance, including an option to show the full image. Chosen approach: a native draggable window with sample previews, Apply, Cancel and Reset. A context-menu-only configurator was considered but the user explicitly prefers a window. No web UI or external dependencies.

Default to separate World map materials, Minimap materials and Flight points settings. A scope question was offered asynchronously; the standing auto-mode preference permits proceeding with this reversible default after reasonable opportunity to answer. Size 12–40 UI pixels in steps of two, shape Circle or Full image, border None or Thin white outline. Current defaults remain 14/circle/no-border for materials and 18/full-image/no-border for flights. Circle mode crops corners; Full image preserves all source pixels. No image zoom, locations, offsets, background fills or shadows. Outline assets have transparent centers, generated reproducibly from code-defined geometric shapes as 32-bit TGA, not edited game artwork.

Previews update inside the window. Maps change only when Apply saves all groups. Cancel/close discard unapplied edits; Reset restores the selected group's defaults in the draft. Changes persist through reload. Open from Titan menu Icon appearance or /tgf icons. No new chat spam or technical implementation details in product UI.

Native flight markers must retain their click handlers and provider ownership. When explicit non-default flight styling is selected, use the existing native texture, an addon-owned mask/outline and a reversible scale adjustment; restore original scale/mask state when disabled/default or recycled. Do not mutate atlas data, stored coordinates or native scripts. Missing native texture/scale APIs leave that native marker unchanged; custom markers remain configurable. Parent/child masks and outlines are reused, not allocated on each refresh.

## Tasks

1. Write failing PinStyle model/render tests for validated independent settings, defaults, non-finite sizes, shape changes on pooled pins, transparent outline geometry, stable anchors and finite size limits. Implement settings normalization and reversible styling. Generate and test the two outline assets; update packaging allowlist.
2. Add failing map/minimap/flight tests for sizes/shapes/borders and independent settings, including native flight scale restoration and texture mask removal. Implement renderer wiring and native lifecycle restoration.
3. Add a small native IconConfig.lua window with previews, target selectors, size controls, shape/border controls, Apply/Cancel/Reset; add failing window tests for transactional settings and reuse. Wire manifest, /tgf icons and Titan menu with host regressions.
4. Run all checks, independent review, fix important findings with red-to-green reproductions. Document controls and live validation. Apply verified candidate to live WoW under the user's standing instruction to update live addons when done, retain backups and byte-verify installed files.

## Constraints and review focus

Preserve the existing uncommitted candidate and unrelated edits, work in place, no commits/publication. Validate saved values before math or UI calls. Apply must refresh hidden and visible renderers without requiring reload. Native flight markers must restore their original state after disable, map changes and pool recycling. No accumulation of masks, outlines or callbacks. Current circle/flight defaults are preserved. Fully transparent outline centers and correct package inclusion are release requirements.

## Execution record

- Implemented inline in the existing checkout, preserving prior uncommitted work. New model and native-style tests failed before implementation. Window test failed before IconConfig.lua existed; host entry-point test failed before /tgf icons was wired.
- Added independent normalized settings, reusable masks/outlines, native flight scale/mask restoration, map/minimap refreshes and transactional native window previews. Geometric outline generation and alpha-center/packaging checks pass; no external bitmap editing or runtime dependencies.
- Independent review found one important minimap footprint issue: large square corners could cross the circular boundary. A diagonal-edge regression failed, then shape-aware half-diagonal and outline margins made it pass. No other important findings or deferred issues. No re-review needed after the focused regression fix.
- Final automated verification and installed-candidate record follow below. Existing full-image native artwork, exact coordinates, faction filters and native click handlers are retained.

- The user confirmed separate settings for all three groups. Final verification: 356 checks (76 Python,280 Lua), all shipped Lua compilation, deterministic outline checks and clean whitespace. Installed and byte-verified all 56 runtime files across fourteen addons. Previous candidate retained at Interface/.tgf-v3-backups/candidate-oviso3fq. Full client restart and the icon appearance live checklist remain pending. No commits or publication.

User follow-up on 2026-11-08 changes the optional outline from white to gold. Tint the existing alpha-only outline texture, preserving border thickness, transparent center and all stored preferences. Artwork clipping remains a separate unresolved investigation awaiting further user testing.
