# Unreleased development updates

Updated 2026-11-12. These changes describe the 0.5.10-beta source candidate and its versioned update. They have not been assigned a new release tag or published as replacement release assets. Historical versioned notes describe their original releases.

## Red, temporary rings, 0.5.10-beta

- The mark on the NPCs of a clicked recipe is red instead of gold, and more compact: three tight concentric rings forming one thick band, about 1.7 times the pin size and at least 24 pixels (they were two thin rings of about 34 pixels).
- The mark is no longer permanent. It belongs to the map opened from the unlearned recipes window, so closing the world map ends it and reopening the map shows plain pins. Clicking the same row again, choosing another recipe and the five minute limit still end it too. Because the rings are a single shared mark, they also leave the minimap when the world map is closed.

## Gold ring on the NPCs of a clicked recipe, 0.5.9-beta

- Clicking a row in the unlearned recipes window now opens the world map at the zone of the recipe's first source (the continent only as a fallback) and marks every trainer and vendor that provides the recipe with two pulsing gold rings, raised above neighboring pins, on the world map and the minimap. The target is shown even when the trainer or vendor toggles or the profession filter would hide it. Clicking the same row again clears the mark, choosing another recipe replaces it, and it ends by itself after five minutes. It is not saved across a reload.

## Skill colors and a minimap button, 0.5.8-beta

- The unlearned recipes window colors a recipe red (name and skill) when the character's rank in that profession is below the required skill, or when the character does not have the profession. Recipes the character could learn now keep the normal color, and an unknown requirement stays neutral because unknown evidence is never guessed. The skill in brackets in trainer and vendor pin tooltips is red under the same rule.
- A round TG3 button on the minimap edge, styled like the ApproxDPS button: left click opens or closes the unlearned recipes window, right click opens the addon menu, dragging moves it around the minimap, and the angle is saved. Display > Show minimap button hides it. It is a new file, so a full client restart is needed.

## Debug log file and scrolling recipe list, 0.5.7-beta

- Debug mode now writes to a debug log instead of the chat. The log holds the latest 1,000 lines in the saved variables file TitanGatheredForeverV3.lua, which the client writes on /reload and logout (an addon cannot write any other file). It records important events with readable arguments (player spell casts, loot, trainer and merchant windows, profession windows, bank and world changes, honor events), the status messages the addon already produced, NPC recording outcomes and profession recipe reads. Frequent noise such as bag updates is left out. Diagnostics gained Also show debug messages in chat (off by default) and Clear debug log.
- The unlearned recipes window scrolls with the mouse wheel or a scroll bar instead of Previous and Next buttons. The range of visible rows is shown, the window returns to the top when the filter changes, and the scroll bar hides when everything fits.

## Unlearned recipes window: profession filter and NPC tooltip, 0.5.6-beta

- A profession filter button (All professions, then each recipe profession) limits the list. Unread-profession notes follow the filter, and paging restarts when it changes.
- NPC names in the list are green. Hovering the NPC column shows a tooltip for the row: the recipe, then every trainer or vendor that provides it with a green name, its role, the price in coin icons, and the zone with coordinates. Coordinates of NPCs seen in game are exact for where you stood; seed NPCs are converted from the Classic world position and marked not yet confirmed in game. Clicking the column still opens the map.

## Smaller tooltip text, 0.5.5-beta

- The role and confirmation lines, the recipe rows (both columns) and the closing lines of trainer and vendor pin tooltips use the small tooltip font. The NPC name keeps the normal size. A new Style.Small helper shrinks the last tooltip line in both columns and restores the original fonts when the tooltip is recycled, like Style.Note.

## Trainer and vendor tooltip layout, 0.5.4-beta

- The skill is now in brackets right after the recipe name, for example Boiled Clams (50), and the right side shows only the price in the classic format of gold, silver and copper numbers followed by their coin icons. Unknown skills read (?) and unknown prices read price unknown. An extra cost is noted as + extra cost.
- A rule separates the NPC header from the recipe list. Colors separate the three kinds of text: gold is the NPC name, white is the recipe list, gray is additional information (role, confirmation, and N more), and green marks confirmation and known recipes.

## Merchant price and recipe diagnostics, 0.5.3-beta

- Fix from live evidence: this client has no GetMerchantItemInfo (the recording log probe printed info=missing), so merchant recipe prices could never be read. Prices and extended cost now come from C_MerchantFrame.GetItemInfo with the old function as a fallback.
- The merchant probe in the NPC recording log now counts all items by item class and shows the first four recipe items with their raw info and tooltip lines, so the log shows whether a vendor sells recipes and how the required skill reads. Recording rules are otherwise unchanged.

## Trainer and merchant lists read on update, 0.5.2-beta

- Fix from live evidence: the recording log showed TRAINER_SHOW arriving with GetNumTrainerServices returning 0, because the client fills the trainer list a moment later. Trainer and merchant windows are now read again on TRAINER_UPDATE and MERCHANT_UPDATE while they stay open and cleared on TRAINER_CLOSED and MERCHANT_CLOSED. Empty updates are logged once per window and identical repeated saves are not logged again.

## NPC recording log, 0.5.1-beta

- Live test: a trainer window was opened but its pin kept the tooltip line Not yet confirmed in game. Every trainer and merchant recording attempt is now logged with its outcome (saved, no-npc, no-services, no-profession, no-recipes, disabled) and the raw answers of the client trainer and merchant APIs, for the last 12 attempts. Diagnostics > Show NPC recording log prints it. The log is stored in SavedVariables as npcLog and does not affect statistics.
- This is a diagnostic step: it finds why recording failed on Forever 1.60.1. Recording behavior itself is unchanged.

## Beta stage, 0.5.0-beta

- The project leaves alpha. The version is 0.5.0-beta: the feature set (gathering and production history, crafting plans, statistics export, flight points, trainer and recipe vendor pins, unlearned recipes window and a menu that covers every parameterless command) is complete for this stage, and the remaining work is live acceptance and fixes. Several live validation checklists stay open, so beta here means feature complete with unverified client behavior, not verified on every client path.
- Version-only change: no runtime behavior differs from 0.4.13-alpha. Earlier versioned notes and downloads keep their alpha names.

## Menu covers every parameterless command, 0.4.13-alpha

- The right-click menu now offers the functions that were only reachable through chat commands: Refresh inventory and Show status report (Diagnostics), Next and Previous summary page (Display), and Find nearest trainer or vendor pin plus a Swap map axes checkbox (Trainers and recipe vendors, Pin placement).
- Chat commands and the menu share one implementation. /tgf recipe <recipeID> [operations] stays as the documented command because it needs a parameter. The other commands still work as undocumented shortcuts, and the in-game help now points to the menu.

## Trainers and recipe vendors, 0.4.12-alpha

- Optional map pins show profession trainers and recipe vendors on the world map and minimap. The menu has toggles for each, a per-profession filter and a switch for recording NPCs when their window opens. The pins work independently of the gathering map switch.
- Vendor tooltips list recipes with the minimum profession level and price. Trainer tooltips list trainable recipes with skill and cost. Recipes you know are marked once that profession window has been read.
- A new Unlearned recipes window (menu or /tgf recipes) lists unlearned recipes with a Trainer or Vendor source, with a filter for vendor-only recipes. Professions whose recipes were never read for the character are named instead of guessed.
- Seed data comes from CMaNGOS classic-db (GPL-3.0, see NOTICE) and is labelled not yet confirmed in game until you visit the NPC. Observed data replaces seed data. Unknown skills and prices are shown as unknown. Instances never get pins.
- /tgf npc names the nearest pin and /tgf npc swap flips the world axes if pins appear mirrored.
- LICENSE and NOTICE are packaged with the core addon. New files require a full client restart. tools/check.py no longer waits on stdin.

## Learned profession colors, 0.4.10-alpha

- Names under Learned professions match their skill rank color. Section headings use bright gold.

## Bright gold labels, 0.4.9-alpha

- The shared label color is now bright gold (#FFD100), including profession section headings in the Titan hover tooltip.

## Titan label colors, 0.4.8-alpha

- Gold marks Titan headings, section labels and profession names. Skill ranks use their progress colors, and material names use their item rarity colors.

## Titan Panel footer divider, 0.4.7-alpha

- Added a horizontal divider between the material list and the bank, page and controls notes in the Titan Panel hover tooltip.

## Gathering tooltip dividers, 0.4.6-alpha

- A divider separates observed gathering data from the explanatory footer on world veins, world-map pins and minimap pins.

## Skill percentage bands and world-vein tooltips, 0.4.5-alpha

- Supersedes the earlier three-color progress thresholds: below 50% orange, 50% to below 75% yellow, 75% to below 100% green, and capped gray. All colors use current rank / current maximum and refresh with rank/cap changes. Mining 68/75 remains green.
- Added the missing native Object tooltip post-call. Actual world ore veins now show observed complete mining loot samples and each sampled output's quantity, hit/sample percentage and counts for the current character, source, zone and instance context. Map pin enrichment remains available separately.
- Recognizes source IDs only from saved mining observations, including partial history and other characters for identity only. No guessed ore-to-object mapping, external drop table or invented depleted-vein count. Unrecognized objects are unchanged. Identified sources without matching current-character samples display Unknown. History in item tooltips controls this enrichment.
- Registration guards missing Object enums; forbidden/restricted tooltips and mismatched GUID/object IDs are ignored. Regression tests cover registration, source isolation, partial exclusion, clearing/reuse, duplicate suppression, restricted identity, absent enums and skill color boundaries.
- API evidence: [pinned Forever tooltip rules](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataRules.lua) registers an Object post-call; the sibling generated TooltipInfoSharedDocumentation declares Object type 4. Live world-object identity availability and appearance remain to be verified in the client.
- Full checks pass. Installed with backup `Interface/.tgf-v3-backups/candidate-b5wi9ft_`; all 57 installed runtime files match source with no extras.

## Near-cap profession colors, 0.4.4-alpha

- Corrected the skill-progress green threshold from 95% to 90% of the current skill cap. Mining 68/75 now displays green for both the name and rank in the Titan tooltip and Professions submenu.
- Added integration coverage for the reported 68/75 case, including both tooltip and menu output. These remain rank/cap progress colors, not per-recipe difficulty.
- Full checks pass. Installed with backup `Interface/.tgf-v3-backups/candidate-yx5g4e3i`; all 57 installed files match source with no extras. Live appearance needs verification after `/reload`.

## Profession colors and mining pin statistics, 0.4.3-alpha

- Learned profession names share the existing rank/max progress colors; the Professions submenu now includes colored live ranks. These colors describe profession progress, not recipe skill-up difficulty.
- Mining pin hovers list all observed outputs for the matching ore sources and outdoor zone, including stones and gems, with hit/sample percentages and obtained quantities from complete loot samples. Partial loot does not enter the rate denominator; other characters, zones and instance contexts are excluded. Missing evidence remains Unknown.
- Minimap pins now show their saved observation count, matching world-map visibility. Counts describe recorded observations, not unique depleted veins or completed mining casts.
- Regression tests reproduce the missing colors, omitted minimap counts and missing byproduct rates. Full checks pass. Installed with backup `Interface/.tgf-v3-backups/candidate-5ab9ipau`; all 57 installed runtime files match source, without extra files. Live tooltip appearance still requires in-game validation after `/reload`.

## Expandable lifetime sources, 0.4.2-alpha

- Compact material parents show quantity and source count, with a dedicated + / - control for individual source rows.
- Source labels, observed chance and hits/samples have separate columns. All sources are available across pages, with material context repeated on continuation pages.
- Expansion/collapse preserves report scope/filter state, clamps page bounds and anchors the selected material to visible source evidence. Unknown evidence remains explicit.
- All fourteen manifests and generator VERSION are synchronized to 0.4.2-alpha. Each completed update now increments its version under the user's standing instruction.

The 0.4.2-alpha candidate is installed and all 57 runtime files match the package byte-for-byte. Previous folders are backed up at Interface/.tgf-v3-backups/candidate-yndg5ybt. Versioned download packages are rebuilt separately from GitHub release/tag publication.

## Interface refinements, 2026-11-09

- Lifetime materials replaces the last-location column with source-specific observed drop chances and hit/sample counts. Unknown evidence stays unknown; row clicks retain all sources.
- Crafting/cooking uses compact columns for attempts, completions, completion percentage, matched operations, items and bonus/multicraft percentages with readable-field denominators. Output distributions and dates remain in recipe details.
- Removed unnamed numeric source labels. Item tooltips omit totals unless both bags and bank contribute; the panel omits totals entirely and uses compact `/` separators. Caption: TG3 Forever - v0.4.1.
- Supporting tooltip/menu explanations use smaller fonts, restoring native tooltip fonts when cleared. Removed the flight-menu explanatory lines.
- Flight artwork is tinted green for confirmed visits, amber for explicit undiscovered status and gray for unconfirmed discovery. Only opening the taxi map at the current flight master confirms a visit for the current character; false map-wide discovery flags do not. Tracking works before the world map loads. Native interactions and subsequent native tint changes are preserved.
- Added independent Record PvP lifetime history, preserving prior observations and native lifetime totals. Disabling stops new addon PvP kills/deaths and spots.
- User reviews and live acceptance are deferred at the user's request. All 405 automated checks pass (76 Python, 329 Lua), with shipped Lua compilation. Safe installation completed; all 57 installed files match source. Backup: Interface/.tgf-v3-backups/candidate-eqi9ea04.

## Added

- Acquisition occurrence evidence, retained in storage/export after the latest compact report changes: one occurrence per item per observed loot/gather source receipt, separate from total quantity, action casts and rate samples. Partial loot counts once per source/item. Older evidence recovers a marked lower bound; missing older occurrence evidence stays Unknown. Counts and coverage flags are included in acquired-item statistics exports.

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

- Applied the zero-count display setting to each Bags, Bank and Total value in Titan summaries and item tooltips. Zero values and their separators no longer leak through when zero display is off; positive values remain visible, and Show bank counts continues to control Bank and Total together.
- Removed the Bags / Bank / Total summary header, which no longer described compact rows consistently.
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

`python3 tools/check.py` passes 408 checks: 76 Python and 332 Lua, plus Lua 5.1 compilation of every shipped Lua file. Generated catalogue and outline data are checked, and deterministic runtime packaging is covered. Individual feature reviews and their regression fixes are recorded in the focused plans.

The current candidate is installed in the local Forever client. All 57 runtime files across fourteen addons were byte-verified against the source package; the prior candidate is backed up at `Interface/.tgf-v3-backups/candidate-yndg5ybt`. User feedback confirms the icon configuration window and shared material visibility work. Compact report rendering and PvP behavior await live acceptance. Automated checks and these observations do not certify every live feature.

## Open issues and release gates

- Shared Linen Cloth visibility is confirmed working in game, and the cloth artwork currently looks correct. Monitor further experience; no speculative crop/offset fix has been deployed.
- The user confirms the compact report list changed. Check Times obtained against quantity and partial source reopenings after /reload, and continue real-client wrapping, page controls and item hover/source acceptance.
- Production event ordering, queued crafts, fishing/disenchant timing, bank readiness, clipboard round trips, native flight styling and full persistence flows still need the live acceptance checklist.
- Catalogue completeness remains false: 456 unresolved legacy IDs, 11 producer-association review candidates, incomplete output-free enchanting, useful-item coverage and live obtainability evidence.
- The mirror extraction build remains unknown. The independent build-labelled base-fact crosscheck does not prove server availability or complete coverage.
- Export transport verification does not certify all statistical semantics. Unsupported complex required reagent choices withhold full crafting estimates.

See [the roadmap](../plan-next-development.md), [progress](../ref-wow-forever-progress.md) and [live validation checklist](../book-wow-forever-validation.md).
