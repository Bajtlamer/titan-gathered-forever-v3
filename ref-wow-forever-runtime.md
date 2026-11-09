# WoW Forever Runtime Reference

Recorded 2026-11-06; updated 2026-11-08. This describes the development target and evidence, not a completed in-game compatibility certification.

## Installed target

- Product: `wowf`, installed under `/Applications/World of Warcraft/_forever_/`.
- Latest installation metadata: `1.60.1.70862`, read on 2026-11-07 from `.build.info`. The earlier observed build was `70790`.
- Expected interface: `16001`, independently observed by WoWFScout on the earlier build. It was not reverified live on `70862` by this pass.
- Client build date in the earlier Scout observation: `Nov 3 2026`.
- Titan Panel: last inspected release 9.3.5. The current installed development candidate is 0.4.1-alpha; all 56 runtime files across fourteen addons were verified against source.
- Test runtime: LuaJIT, using Lua 5.1 semantics. The machine's separate Lua 5.5 compiler is not the project validation target.

## Implementation decisions

Carried items are counted by scanning containers `0` through `NUM_TOTAL_EQUIPPED_BAG_SLOTS`. This includes a reagent bag when the client exposes one and excludes equipped gear, mail and auction listings.

The character bank uses `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)`, scanning each returned `ID` through `C_Container`. It does not assume old negative bank container IDs or scan account storage. A complete successful observation is persisted by player GUID. Inaccessible, malformed or uninitialized reads retain the previous observation. Known empty slots and unknown data are distinct.

Item names use `C_Item.GetItemInfo`, followed by `RequestLoadItemDataByID` when needed. Tooltip enrichment uses the native item tooltip processor and context menu API. The Titan entry is a LibDataBroker object with a private summary tooltip.

The core contains no item database. Twelve profession addons and a separate Auction Items addon publish compact records through `Catalog.RegisterModule`. Only addons enabled in WoW load data; category toggles rebuild the cached active index. Shared IDs are deduplicated. Repeated item lookups use numeric table keys and summary refreshes reuse the cached ID list. Full recipe source records stay outside game memory; publishers carry use counts and at most two recipe examples per item.

`Show bank counts` controls both display and scanning. When off, summaries use carried items only, omit Bank and Total, and omit bank timestamps. Total follows Bank automatically; the old independent Total setting is discarded. Following the user's clarified requirement, all unavailable counts display zero, including an unvisited bank; displayed Total sums the displayed Bags and Bank values. Scan states remain separate internally, and no zero snapshot is fabricated. The bank-visit reminder is removed. Readiness retries are bounded to four per visit and `/tgf status` reports the latest scan status.

Material names use native item rarity colors with a white fallback until item data loads. TGF v3 sections have colored headings and full-inner-width texture rules that resize with the tooltip and reset when it is cleared. Learned professions are separated from material columns. Repeated addon-title headers are omitted. Labels are gold, profession uses cyan, recipe names violet, use explanations muted teal and freshness/help notes gray. Learned profession ranks come from `C_SkillInfo.GetSkillLineInfoByID`, independently of loaded profession data addons.

`Enable gathering map` controls both recording and world-map pins. Mining and Herbalism have individual switches and require their corresponding data addons. The active Observations/Sources path correlates confirmed gathering context with readable loot sources and taken items. Mining selects one canonical resource with primary ore priority for its marker; stones/gems remain in history. Legacy overlapping byproduct markers are suppressed only where a recorded ore exists, without deleting data. Locations use the player's map coordinates near the gather, merge nearby identical resources and retain at most 500 points per map. Saved observation times use wall time, while cast expiration uses uptime. A private map-canvas overlay reuses resource-icon buttons without registering Blizzard map pins. Disabling retains saved observations. Actual autoloot timing, source correlation and map zoom/gamepad behavior require live testing.

These APIs were checked against the [Forever client UI source mirror](https://github.com/Gethe/wow-ui-source/tree/forever), particularly its `Blizzard_UIPanels_Game/Camelot/BankFrame.lua`, `Blizzard_FrameXMLBase/Constants.lua`, generated API documentation, and tooltip/menu code. The moving branch was readable, but an exact matching commit was not established. Installed-client behavior remains a manual validation gate.

## Current map and appearance behavior

Gathering marker centers use recorded/projected coordinates exactly, including overlapping images. Artificial row offsets, filled backplates and shadows are removed. Material icons use the original WoW artwork; circular cropping is the default. A circle necessarily removes corners, while Full image disables the addon crop mask. The user still reports partial artwork clipping/offset in all modes, especially Linen Cloth; root cause is unconfirmed and no guessed correction was deployed.

`/tgf icons` opens the native appearance window, also available from the Titan menu. World-map materials, minimap materials and flight points have independent 12–40 UI-pixel sizes, Circle/Full image choices and an optional Thin gold outline. The outline assets have alpha-only edges and transparent centers. Previews are local to the window; Apply saves and refreshes renderers, Cancel/close discards unapplied edits, and Reset group changes the selected draft. World-map sizes compensate canvas scale; minimap clipping includes square corners and outline extent.

FlightPaths uses current-client C_TaxiMap nodes for the displayed map, including exposed undiscovered locations. It filters Alliance/Horde plus neutral, excludes unknown opposing-faction evidence, and labels discovery explicitly in tooltips. Confirmed discovery is persisted per character only for the Current node returned by GetAllTaxiNodes during a flight-master taxi-map interaction. False map-wide isUndiscovered flags do not confirm visits. Tracking is independent of world-map loading and visibility. Green means a confirmed visit, amber an explicit undiscovered flag and gray unconfirmed status. It decorates/reuses native markers rather than drawing duplicates; optional configured masks/scales are restored when no longer owned. Native click handlers are retained. Missing API/data fails closed. This is not a static all-world completeness guarantee.

## Action, production, planning and export components

Actions.lua, Production.lua and History.lua keep distinct schema-1 per-character stores and optional combined reports. Reload/world/policy gaps seal pending observations. Action completions, matched output operations, obtained quantities and complete-source trials have different meanings and denominators. Production requires readable recipe/cast/result evidence and does not create loot rates or map positions.

Crafting.lua and CraftingView.lua calculate fixed-reagent plans from live schematics and the chosen Bags/Bank scope, with cached/unknown inventory labels. Complex required choices withhold a full estimate. Export.lua/ExportView.lua produce schema-1 manual JSON with opt-in identities and numbered checksum-protected copy parts. tools/read_export.py reconstructs transport safely; it does not send/import data or certify all statistical semantics. See README.md and ref-statistics-export-format.md for exact user commands and limitations.

Current verification is 360 automated checks (76 Python,284 Lua), generated evidence/assets checks and shipped Lua 5.1 compilation. User feedback confirms the configurator works; complete live acceptance of event timing, native providers, copying and persistence is still pending.

## Data evidence

- `catalogue/forever-recipes.json`: numeric recipe facts captured from the [Forever recipe-data mirror](https://github.com/masterred92/DwarfExplorersBible/blob/main/Data.lua), attributed by that project to Forever client tables. Original mirror has 1,971 recipes with item outputs; it does not state an exact extraction build.
- `catalogue/verified-recipes.json`: separately sourced Forever enchantment relationships from Wowhead, including spells `13626` and `13655`, which have no conventional output item.
- `catalogue/curated-uses.json`: exact item-use evidence for a supply turn-in and an auctionable crafting writ.
- `catalogue/catalog-audit.json`: every old ID reconciled against current evidence, new IDs listed, and limitations retained. An unmatched old ID is unresolved, not proven absent from Forever.
- `catalogue/module-membership.json`: producer-module membership, kept separate from consuming professions. Existing gathering memberships are retained only for IDs supported by the current recipe union, with new scarce materials cross-checked against Wowhead's Forever profession guides. Fishing membership remains a partial seed.
- `catalogue/source-evidence.json`: pinned mirror commit, raw SHA-256 and normalized numeric-fact hash; all 1,971 base recipes match, with mirror extraction build still unknown. Separate evidence pins four public Wago CSV response filenames/hashes for 1.60.1.70862; independent reconstruction matches all base facts. This is a scoped crosscheck, not live obtainability verification.
- `catalogue/target-client.json`: latest read-only installation metadata, kept separate from the older dataset target and live API observations.
- `catalogue/reconciliation.json`: deterministic build/coverage/provenance gates, unresolved IDs and module-association review candidates. Seven direct-reference Fishing additions bring that module to 23 materials without changing global item/recipe counts.
- Generated metadata contains a SHA-256 digest of the combined data inputs, including module membership. This pins captured content, not its live availability or extraction build.

The alpha catalogue has 532 item IDs and 1,973 recipe records. All 15 initially identified missing enchanting reagent candidates are represented. Neither these counts nor recipe membership establish complete live coverage. Output-free enchants, profession camping uses, tradable useful items, and live obtainability need further reconciliation before a release.

## Commands

- `python3 tools/check.py`: generator checks, Python tests, Lua inventory/integration/presentation/gathering/map tests and Lua 5.1 compilation of manifest files.
- `python3 tools/generate_catalog.py`: regenerate Lua data and the legacy audit after editing normalized source inputs.
- `python3 tools/generate_catalog.py --check`: reject stale generated outputs.
- `python3 tools/audit_catalog.py --check`: verify the generated evidence report; add `--mirror-file` for the pinned source or `--client-tables DIRECTORY` for the four pinned build-labelled CSVs.
- `python3 tools/generate_pin_outlines.py --check`: verify the two deterministic transparent outline textures.
- `python3 tools/install.py --addons-dir PATH`: preview the runtime-only candidate; add `--apply` for backed-up installation.
- `python3 tools/package.py`: produce a deterministic addon-pack bundle under `dist/` and individual core/module ZIPs under `dist/modules/`.
- `python3 tools/package.py --addon TitanGatheredForeverV3_Herbs`: build a single selected profession download.

Completed runtime updates are installed automatically into the local Forever client through tools/install.py, retaining the previous candidate and verifying installed bytes. SavedVariables, enablement and unrelated addons are preserved. No new tag/release or website publication is part of the source update. The original implementation remains in ignored local archives.

## Debug output

The Titan context menu includes `Debug mode`, disabled by default and saved across reloads. Diagnostic messages use a gated logger. With debug off, `/tgf` prints only command help; `/tgf status` explicitly requests the full report. Refresh, paging and configuration actions remain silent. Startup errors for an unsupported client or unavailable Titan support remain visible. No routine event logging is enabled.

## Historical: Gathering recording diagnostics

Version 0.3.4 refreshes loot-source metadata on `LOOT_OPENED` when the earlier `LOOT_READY` observation had no source, preserving already-taken flags. A regression reproduces the previous dropped herb; a collector-to-map test verifies the herb item icon and coordinates. The inspected local saved state has mapping/Herbalism enabled but no saved spots; Scout separately recorded Silverleaf loot in Mulgore. This establishes a recording report, but does not establish the exact live event order. `/tgf status` includes enabled map professions and the last recording stage. Debug mode additionally traces cast/loot/recording stages; it remains off by default.

## Historical: Map rendering corrections in 0.3.5

The latest inspected SavedVariables contains Silverleaf and two Peacebloom spots on Mulgore map 1412, with mapping enabled. Recording is therefore confirmed for those observations. The running client was at its login screen, so live rendering could not be inspected.

World icons now compensate for the map canvas effective scale and stay at 14 UI pixels relative to the world-map frame. The native canvas uses map-art dimensions and scales to its viewport; previously icon dimensions shrank with that scale. Related-map rectangles project zone observations onto a containing map, up to 500 drawn icons.

A new minimap renderer draws nearby saved resource icons, updates movement/zoom/rotation at 0.2-second intervals, and clips icons within the circular map. It uses current-map player coordinates, `C_Map.GetMapWorldSize`, and `C_Minimap.GetViewRadius`; missing/restricted position data hides stale pins. World map and minimap have independent visibility switches, enabled by default. The master switch still stops recording and hides both; module/profession switches filter both. These are historical observations, not current resource-presence indicators.

Primary references: [map-canvas sizing](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_ScrollContainerMixin.lua), [map-coordinate APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua), and [minimap radius API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapDocumentation.lua). Actual screen rendering remains a live validation gate.

## Historical: Live rendering diagnosis and fix in 0.3.6

Live inspection on Forever 1.60.1 build 70840 confirmed mapping enabled, three saved Mulgore nodes, three shown/visible icon frames, valid item texture 134190, opacity 1 and valid coordinates. Their default MEDIUM strata matched the world map; the icons were absent in the screenshot despite frame levels above the tile layer. Raising all three icon frames to HIGH and refreshing their real textures immediately made Silverleaf and both Peacebloom icons visible. This is the first direct live visual confirmation of the world-map icons. The code now assigns HIGH strata when creating each icon, with a regression assertion.

The live frame adjustment is session-only; install 0.3.6 for persistence after reload. No installed addon files or saved observations were modified. Minimap reported zero nearby icons at the character's current position (45.3, 61.9), apart from the saved positions further south/east; nearby live minimap rendering is still unverified.

## Historical: Circular pins and version caption in 0.3.7

Both map renderers use `PinStyle.lua`: the native `CircleMaskScalable` atlas clips item art, a thin muted-gold disk forms the border, and three low-opacity circular layers form a small shadow down/right. Decoration dimensions follow icon size changes and are allocated once per pooled pin. The atlas and visual appearance were previewed successfully on the live world map and accepted by the user. A legacy portrait-mask path failed the live preview and is not used. Installed files remain untouched.

The Titan broker text now displays the manifest version, with the addon name supplied by its existing label. Material counts remain in tooltips; inventory refresh no longer computes a material count for the panel caption.


## Historical: Skinning and map filters in 0.3.8

Skinning gathering resources come from the separately loaded Skinning publisher. Recognized Skinning spells are 8613, 8617, 8618 and 10768. A successful cast and cleared supported Creature loot are required. Each distinct material is saved independently; that revision offset coincident Skinning icons without moving stored positions. This was superseded: current rendering keeps every icon at its recorded/projected position.

`mapSkinning` joins `mapMining` and `mapHerbs`. Saved `mapItems[profession][itemID] = false` suppresses that material on both displays. Per-material visibility does not stop collection; master/profession/category switches do. Show all clears the profession filter; Hide all suppresses its supported resources. Only loaded gathering publishers appear in the material menu.

`IsInInstance()` must return false and `none` at cast and finalization; unavailable or protected values fail closed. World entry/exit cancels pending collection. This excludes all instance types, including dungeons and raids, while allowing outdoor raid groups. See the [Forever API declaration](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua) and [Skinning spell](https://www.wowhead.com/forever/spell=8613/skinning).

Automated source filtering does not prove corpse identity against the cast target. Live cast/loot correlation, multiple-material drops and minimap proximity remain unverified.


## Separate development workspace

The development root is `~/Sites/addons/titan-gathered-forever-v3`. All fourteen addon folders contain only manifest-loaded scripts/data and required artwork. Root `tools/`, `tests/`, `catalogue/`, `release-notes/` and documentation are development content. Generated output is in root `dist/`; private archives are preserved in root `.work/` and ignored by Git.

Run from the repository root:

- `python3 tools/check.py`: automated checks and Lua 5.1 compilation.
- `python3 tools/generate_catalog.py`: regenerate runtime metadata and profession data.
- `python3 tools/package.py`: build the collection, independent downloads and website upload set.

Tools resolve paths relative to their own location and work independently of the caller's directory. Runtime ZIPs contain only manifest-listed files and required artwork. Install a built candidate into WoW for live validation; leave the separate workspace as the source of truth. Historical AGENTS.md contents were preserved while moving that guide to the root.


## Historical: History and source architecture in 0.4.0

`History.lua` stores per-character lifetime counters, source groups, eligible recording policies and bounded recent receipts under `TitanGatheredForeverV3DB.history`. `Observations.lua` receives spell/loot events and commits per-source obtained quantities. `Sources.lua` applies recording policies and profession/material map visibility. `Reports.lua` owns the two native windows and shared source labels. These files are loaded only by the shared core; separate profession publishers remain independently enabled.

A complete sample requires every observed slot for its readable source to be cleared, including money/currency. Partial loot adds lifetime quantity but not a rate sample until safely completed. Rates distinguish hit frequency from output quantity; source groups include zone and instance context. Fishing groups catches by zone, with junk retained in its denominator. Enchanting groups by input item ID and uses no map coordinates. Unreadable input identity is explicitly unknown. Unattributed reopened item loot can retain supported quantities but cannot create rates or spots.

Saved controls include `recordHistory`, `recordRare`, `historyTooltips`, `historyProfessions`, `mapFishing`, `mapRare` and `mapProfessions`, alongside existing map settings and material filters. Each recording-policy snapshot preserves the eligible item IDs. Partial samples are invalidated across recording interruptions and configuration changes. Existing icon observations are retained but never reinterpreted as historical quantities or probabilities.

Source-rate percentages measure complete observed loot sources, not all casts or kills. Corpses with no accessible loot/source evidence cannot be counted. Unknown source metadata, partial acquisition and recording gaps are excluded from rates. These are personal observations, not verified server loot tables. Catalogue completeness remains unverified.


## Public source and release layout

Development catalogue JSON now lives in `catalogue/`, separate from manifest-loaded `Data/Metadata.lua`. This avoids a case-insensitive macOS directory collision and supports clean Linux reconstruction. Source control is rooted in the collection workspace; module data and manifests are regenerated into independently loadable addon folders. `dist/releases/<version>/` contains a flat website/GitHub upload set with the collection, fourteen independent addon downloads, downloads.json and SHA256SUMS. The core-only asset uses a `-core.zip` suffix in that flat directory.


## Interface refinement API evidence, 2026-11-09

The optional visit tracker guards C_TaxiMap.GetAllTaxiNodes and Enum.FlightPathState.Current, declared in the [Forever TaxiMap API source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TaxiMapDocumentation.lua). It queries player/parent map IDs during TAXIMAP_OPENED and subsequent open-map status events; missing, restricted or ambiguous current-node evidence records nothing. These declarations establish an API candidate, while live Forever behavior remains deferred. The [Forever menu guide](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Menu/11_0_0_MenuImplementationGuide.lua) documents AddInitializer/fontString customization used for small informational menu notes. Tooltip font changes apply only to addon-owned notes and restore previous fonts on clearing. Manifests and the 16001 compatibility gate are unchanged.
