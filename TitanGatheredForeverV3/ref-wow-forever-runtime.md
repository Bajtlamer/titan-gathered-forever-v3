# WoW Forever Runtime Reference

Recorded 2026-11-06; updated 2026-11-07. This describes the development target and evidence, not a completed in-game compatibility certification.

## Installed target

- Product: `wowf`, installed under `/Applications/World of Warcraft/_forever_/`.
- Version/build: `1.60.1.70790`, read from the installation's `.build.info`.
- Interface: `16001`, independently recorded by the existing WoWFScout observation of `GetBuildInfo()`.
- Client build date in that observation: `Nov 3 2026`.
- Titan Panel: installed release 9.3.5. Last inspected installed Gathered manifest: 0.3.5-alpha; the workspace package is 0.4.0-alpha.
- Test runtime: LuaJIT, using Lua 5.1 semantics. The machine's separate Lua 5.5 compiler is not the project validation target.

## Implementation decisions

Carried items are counted by scanning containers `0` through `NUM_TOTAL_EQUIPPED_BAG_SLOTS`. This includes a reagent bag when the client exposes one and excludes equipped gear, mail and auction listings.

The character bank uses `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)`, scanning each returned `ID` through `C_Container`. It does not assume old negative bank container IDs or scan account storage. A complete successful observation is persisted by player GUID. Inaccessible, malformed or uninitialized reads retain the previous observation. Known empty slots and unknown data are distinct.

Item names use `C_Item.GetItemInfo`, followed by `RequestLoadItemDataByID` when needed. Tooltip enrichment uses the native item tooltip processor and context menu API. The Titan entry is a LibDataBroker object with a private summary tooltip.

The core contains no item database. Twelve profession addons and a separate Auction Items addon publish compact records through `Catalog.RegisterModule`. Only addons enabled in WoW load data; category toggles rebuild the cached active index. Shared IDs are deduplicated. Repeated item lookups use numeric table keys and summary refreshes reuse the cached ID list. Full recipe source records stay outside game memory; publishers carry use counts and at most two recipe examples per item.

`Show bank counts` controls both display and scanning. When off, summaries use carried items only, omit Bank and Total, and omit bank timestamps. Total follows Bank automatically; the old independent Total setting is discarded. Following the user's clarified requirement, all unavailable counts display zero, including an unvisited bank; displayed Total sums the displayed Bags and Bank values. Scan states remain separate internally, and no zero snapshot is fabricated. The bank-visit reminder is removed. Readiness retries are bounded to four per visit and `/tgf status` reports the latest scan status.

Material names use native item rarity colors with a white fallback until item data loads. TGF v3 sections have colored headings and full-inner-width texture rules that resize with the tooltip and reset when it is cleared. Learned professions are separated from material columns. Repeated addon-title headers are omitted. Labels are gold, profession uses cyan, recipe names violet, use explanations muted teal and freshness/help notes gray. Learned profession ranks come from `C_SkillInfo.GetSkillLineInfoByID`, independently of loaded profession data addons.

`Enable gathering map` controls both recording and world-map pins. Mining and Herbalism have individual switches and require their corresponding data addons. Observations correlate a successful gathering cast with taken resource loot from one game-object source. Locations use the player's map coordinates near the gather, merge nearby identical resources and retain at most 500 points per map. Saved observation times use wall time, while cast expiration uses uptime. A private map-canvas overlay reuses resource-icon buttons without registering Blizzard map pins. Disabling retains saved observations. Actual autoloot timing, source correlation and map zoom/gamepad behavior require live testing.

These APIs were checked against the [Forever client UI source mirror](https://github.com/Gethe/wow-ui-source/tree/forever), particularly its `Blizzard_UIPanels_Game/Camelot/BankFrame.lua`, `Blizzard_FrameXMLBase/Constants.lua`, generated API documentation, and tooltip/menu code. The moving branch was readable, but an exact matching commit was not established. Installed-client behavior remains a manual validation gate.

## Data evidence

- `data/forever-recipes.json`: numeric recipe facts captured from the [Forever recipe-data mirror](https://github.com/masterred92/DwarfExplorersBible/blob/main/Data.lua), attributed by that project to Forever client tables. Original mirror has 1,971 recipes with item outputs; it does not state an exact extraction build.
- `data/verified-recipes.json`: separately sourced Forever enchantment relationships from Wowhead, including spells `13626` and `13655`, which have no conventional output item.
- `data/curated-uses.json`: exact item-use evidence for a supply turn-in and an auctionable crafting writ.
- `data/catalog-audit.json`: every old ID reconciled against current evidence, new IDs listed, and limitations retained. An unmatched old ID is unresolved, not proven absent from Forever.
- `data/module-membership.json`: producer-module membership, kept separate from consuming professions. Existing gathering memberships are retained only for IDs supported by the current recipe union, with new scarce materials cross-checked against Wowhead's Forever profession guides. Fishing membership remains a partial seed.
- Generated metadata contains a SHA-256 digest of the combined data inputs, including module membership. This pins captured content, not its live availability or extraction build.

The alpha catalogue has 532 item IDs and 1,973 recipe records. All 15 initially identified missing enchanting reagent candidates are represented. Neither these counts nor recipe membership establish complete live coverage. Output-free enchants, profession camping uses, tradable useful items, and live obtainability need further reconciliation before a release.

## Commands

- `python3 tools/check.py`: generator checks, Python tests, Lua inventory/integration/presentation/gathering/map tests and Lua 5.1 compilation of manifest files.
- `python3 tools/generate_catalog.py`: regenerate Lua data and the legacy audit after editing normalized source inputs.
- `python3 tools/generate_catalog.py --check`: reject stale generated outputs.
- `python3 tools/package.py`: produce a deterministic addon-pack bundle under `dist/` and individual core/module ZIPs under `dist/modules/`.
- `python3 tools/package.py --addon TitanGatheredForeverV3_Herbs`: build a single selected profession download.

No game installation files or website content were changed. The original implementation remains in ignored local archives. The new code is packaged with the original core-plus-profession-addon structure, extended to the supported professions and a separate optional auction-use module.

## Debug output

The Titan context menu includes `Debug mode`, disabled by default and saved across reloads. Diagnostic messages use a gated logger. With debug off, `/tgf` prints only command help; `/tgf status` explicitly requests the full report. Refresh, paging and configuration actions remain silent. Startup errors for an unsupported client or unavailable Titan support remain visible. No routine event logging is enabled.

## Gathering recording diagnostics

Version 0.3.4 refreshes loot-source metadata on `LOOT_OPENED` when the earlier `LOOT_READY` observation had no source, preserving already-taken flags. A regression reproduces the previous dropped herb; a collector-to-map test verifies the herb item icon and coordinates. The inspected local saved state has mapping/Herbalism enabled but no saved spots; Scout separately recorded Silverleaf loot in Mulgore. This establishes a recording report, but does not establish the exact live event order. `/tgf status` includes enabled map professions and the last recording stage. Debug mode additionally traces cast/loot/recording stages; it remains off by default.

## Map rendering corrections in 0.3.5

The latest inspected SavedVariables contains Silverleaf and two Peacebloom spots on Mulgore map 1412, with mapping enabled. Recording is therefore confirmed for those observations. The running client was at its login screen, so live rendering could not be inspected.

World icons now compensate for the map canvas effective scale and stay at 14 UI pixels relative to the world-map frame. The native canvas uses map-art dimensions and scales to its viewport; previously icon dimensions shrank with that scale. Related-map rectangles project zone observations onto a containing map, up to 500 drawn icons.

A new minimap renderer draws nearby saved resource icons, updates movement/zoom/rotation at 0.2-second intervals, and clips icons within the circular map. It uses current-map player coordinates, `C_Map.GetMapWorldSize`, and `C_Minimap.GetViewRadius`; missing/restricted position data hides stale pins. World map and minimap have independent visibility switches, enabled by default. The master switch still stops recording and hides both; module/profession switches filter both. These are historical observations, not current resource-presence indicators.

Primary references: [map-canvas sizing](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_ScrollContainerMixin.lua), [map-coordinate APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua), and [minimap radius API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapDocumentation.lua). Actual screen rendering remains a live validation gate.

## Live rendering diagnosis and fix in 0.3.6

Live inspection on Forever 1.60.1 build 70840 confirmed mapping enabled, three saved Mulgore nodes, three shown/visible icon frames, valid item texture 134190, opacity 1 and valid coordinates. Their default MEDIUM strata matched the world map; the icons were absent in the screenshot despite frame levels above the tile layer. Raising all three icon frames to HIGH and refreshing their real textures immediately made Silverleaf and both Peacebloom icons visible. This is the first direct live visual confirmation of the world-map icons. The code now assigns HIGH strata when creating each icon, with a regression assertion.

The live frame adjustment is session-only; install 0.3.6 for persistence after reload. No installed addon files or saved observations were modified. Minimap reported zero nearby icons at the character's current position (45.3, 61.9), apart from the saved positions further south/east; nearby live minimap rendering is still unverified.

## Circular pins and version caption in 0.3.7

Both map renderers use `PinStyle.lua`: the native `CircleMaskScalable` atlas clips item art, a thin muted-gold disk forms the border, and three low-opacity circular layers form a small shadow down/right. Decoration dimensions follow icon size changes and are allocated once per pooled pin. The atlas and visual appearance were previewed successfully on the live world map and accepted by the user. A legacy portrait-mask path failed the live preview and is not used. Installed files remain untouched.

The Titan broker text now displays the manifest version, with the addon name supplied by its existing label. Material counts remain in tooltips; inventory refresh no longer computes a material count for the panel caption.


## Skinning and map filters in 0.3.8

Skinning gathering resources come from the separately loaded Skinning publisher. Recognized Skinning spells are 8613, 8617, 8618 and 10768. A successful cast and cleared supported Creature loot are required. Each distinct material is saved independently; rendering offsets coincident Skinning icons without moving the stored positions.

`mapSkinning` joins `mapMining` and `mapHerbs`. Saved `mapItems[profession][itemID] = false` suppresses that material on both displays. Per-material visibility does not stop collection; master/profession/category switches do. Show all clears the profession filter; Hide all suppresses its supported resources. Only loaded gathering publishers appear in the material menu.

`IsInInstance()` must return false and `none` at cast and finalization; unavailable or protected values fail closed. World entry/exit cancels pending collection. This excludes all instance types, including dungeons and raids, while allowing outdoor raid groups. See the [Forever API declaration](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua) and [Skinning spell](https://www.wowhead.com/forever/spell=8613/skinning).

Automated source filtering does not prove corpse identity against the cast target. Live cast/loot correlation, multiple-material drops and minimap proximity remain unverified.


## Development directly in the game installation

The intended development root after applying the rename is `~/Sites/addons/titan-gathered-forever-v3/TitanGatheredForeverV3`. Shared runtime files remain directly in this folder, together with `tools/`, `tests/`, `data/`, `dist/`, documentation and `.work/` archives. There is no nested core addon folder. Profession and Auction addon folders remain siblings under `AddOns`, as required for independent WoW addon discovery. Only TGF v3 addon folders may be modified.

Run these commands from the core folder:

- `python3 tools/check.py`: run all automated checks and compile shipped Lua files.
- `python3 tools/generate_catalog.py`: regenerate core metadata and sibling profession data.
- `python3 tools/package.py`: build distributable archives in the core's `dist/` folder.

The tools resolve paths relative to their own location. Lua host tests run from the parent AddOns directory. Packaging includes only manifest-listed runtime files and the core artwork; development files and unrelated addons are excluded. The prior installed TGF v3 files are preserved in `.work/before-development-relocation.zip`. The former development directory remains an unchanged reference copy, not the working location. The copied `AGENTS.md` is preserved verbatim; its old structural and command descriptions are historical and this section describes the current layout.


## History and source architecture in 0.4.0

`History.lua` stores per-character lifetime counters, source groups, eligible recording policies and bounded recent receipts under `TitanGatheredForeverV3DB.history`. `Observations.lua` receives spell/loot events and commits per-source obtained quantities. `Sources.lua` applies recording policies and profession/material map visibility. `Reports.lua` owns the two native windows and shared source labels. These files are loaded only by the shared core; separate profession publishers remain independently enabled.

A complete sample requires every observed slot for its readable source to be cleared, including money/currency. Partial loot adds lifetime quantity but not a rate sample until safely completed. Rates distinguish hit frequency from output quantity; source groups include zone and instance context. Fishing groups catches by zone, with junk retained in its denominator. Enchanting groups by input item ID and uses no map coordinates. Unreadable input identity is explicitly unknown. Unattributed reopened item loot can retain supported quantities but cannot create rates or spots.

Saved controls include `recordHistory`, `recordRare`, `historyTooltips`, `historyProfessions`, `mapFishing`, `mapRare` and `mapProfessions`, alongside existing map settings and material filters. Each recording-policy snapshot preserves the eligible item IDs. Partial samples are invalidated across recording interruptions and configuration changes. Existing icon observations are retained but never reinterpreted as historical quantities or probabilities.

Source-rate percentages measure complete observed loot sources, not all casts or kills. Corpses with no accessible loot/source evidence cannot be counted. Unknown source metadata, partial acquisition and recording gaps are excluded from rates. These are personal observations, not verified server loot tables. Catalogue completeness remains unverified.


## Public source and release layout

Development catalogue JSON now lives in `catalogue/`, separate from manifest-loaded `Data/Metadata.lua`. This avoids a case-insensitive macOS directory collision and supports clean Linux reconstruction. Source control is rooted in the installed core; module data and manifests are regenerated as independently loadable siblings. `dist/releases/<version>/` contains a flat website/GitHub upload set with the collection, fourteen independent addon downloads, downloads.json and SHA256SUMS. The core-only asset uses a `-core.zip` suffix in that flat directory.
