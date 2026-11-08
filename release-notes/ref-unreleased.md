# Unreleased development updates

Updated 2026-11-08. These changes extend the 0.4.1-alpha source and installed development candidate. They have not been assigned a new release tag or published as replacement release assets. Historical versioned notes describe their original releases.

## Added

- Times obtained in the lifetime material report: one occurrence per item per observed loot/gather source receipt, separate from total quantity, action casts and rate samples. Partial loot counts once per source/item. Older evidence recovers a marked lower bound; missing older occurrence evidence stays Unknown. Counts and coverage flags are included in acquired-item statistics exports.

- Per-character Mining, Herbalism, Skinning, Fishing and Disenchanting action counters, combined reports and independent recording controls. Fishing launch and confirmed catch are separate outcomes.
- Crafting/cooking production statistics: observed attempts, completed casts, matched result operations, item quantities/distributions and readable bonus/multicraft denominators.
- Live recipe reagent planning with required, available and missing quantities, material-limited estimates, inventory freshness and personal source evidence.
- Schema-1 manual JSON statistics export, identity opt-in, numbered checksum-protected parts and an offline reconstruction tool.
- Faction-aware world-map flight points, including client-exposed undiscovered nodes, with explicit discovery status in tooltips.
- A draggable icon configurator through `/tgf icons` and the Titan menu. World-map materials, minimap materials and flights have separate size, Circle/Full image and optional Thin gold outline settings, with previews, Apply, Cancel and Reset group.
- A safe local installer with preview, retained backups, rollback and runtime-only package allowlisting. Completed updates are installed automatically under the user's project instruction.
- PvP Board with native lifetime honorable kills and rank, plus separately tracked honor-confirmed kills and estimated honor by outdoor, Battleground and arena context. Outdoor honorable kills create persistent PvP markers on the world map and minimap. PvP deaths are tracked from feature activation only.
- Reproducible catalogue reconciliation, pinned mirror provenance and an offline crosscheck of four public tables labelled 1.60.1.70862. All 1,971 base recipe facts match the scoped extraction.

## Corrected

- Applied the zero-count display setting to each Bags, Bank and Total value in Titan summaries and item tooltips. Zero Bank counts no longer leak through when zero display is off; positive values remain visible, and Show bank counts continues to control Bank and Total together.
- Report windows now open one at a time while retaining independent scope, filters and page. Lifetime materials, observed chances and profession actions use compact columns, wrapped rows and height-aware pagination. Acquired/crafted quantities, sample denominators and action outcomes stay distinct; source menus and native item hovers remain available.

- Material visibility is now shared by item across profession menus and both maps. Linen Cloth no longer requires separate First Aid and Tailoring material toggles. Bulk actions affect the submenu’s materials globally; profession switches remain independent. Legacy hidden preferences migrate without deleting observations or statistics.

- Removed gathering-icon backplates, shadows and artificial offsets. Markers remain at recorded/projected positions even when they overlap; the original WoW artwork is retained.
- Added selectable circular cropping and full-image display. Optional outlines have transparent centers and are tinted gold.
- Prevented large square minimap images and outlines from extending beyond the circular map boundary.
- Preserved native flight-marker interactions, avoided duplicate markers, restored temporary styling and cleaned up stale discovery tooltips.
- Mining markers now prefer the primary ore over stones/gems while retaining every output in statistics. Legacy overlapping byproduct pins are hidden where ore is recorded, without deleting saved data. Stone-only partial loot does not create a guessed ore marker.
- Added seven evidenced Fishing memberships, bringing the module to 23 materials, and repaired 128 inherited provenance references. Global counts remain 532 supported items and 1,973 recipe relationships.
- Fixed reviewed attribution, crafting selection, export privacy and audit output-alias defects with regressions.

## Verification and installation

`python3 tools/check.py` passes 391 checks: 76 Python and 315 Lua, plus Lua 5.1 compilation of every shipped Lua file. Generated catalogue and outline data are checked, and deterministic runtime packaging is covered. Individual feature reviews and their regression fixes are recorded in the focused plans.

The current candidate is installed in the local Forever client. All 57 runtime files across fourteen addons were byte-verified against the source package; the prior candidate is backed up at `Interface/.tgf-v3-backups/candidate-zza0heza`. User feedback confirms the icon configuration window and shared material visibility work. Compact report rendering and PvP behavior await live acceptance. Automated checks and these observations do not certify every live feature.

## Open issues and release gates

- Shared Linen Cloth visibility is confirmed working in game, and the cloth artwork currently looks correct. Monitor further experience; no speculative crop/offset fix has been deployed.
- The user confirms the compact report list changed. Check Times obtained against quantity and partial source reopenings after /reload, and continue real-client wrapping, page controls and item hover/source acceptance.
- Production event ordering, queued crafts, fishing/disenchant timing, bank readiness, clipboard round trips, native flight styling and full persistence flows still need the live acceptance checklist.
- Catalogue completeness remains false: 456 unresolved legacy IDs, 11 producer-association review candidates, incomplete output-free enchanting, useful-item coverage and live obtainability evidence.
- The mirror extraction build remains unknown. The independent build-labelled base-fact crosscheck does not prove server availability or complete coverage.
- Export transport verification does not certify all statistical semantics. Unsupported complex required reagent choices withhold full crafting estimates.

See [the roadmap](../plan-next-development.md), [progress](../ref-wow-forever-progress.md) and [live validation checklist](../book-wow-forever-validation.md).
