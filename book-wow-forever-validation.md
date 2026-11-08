# Validate Titan Gathered Forever v3

This is an alpha. Automated checks pass against simulated host APIs, but history collection and the new report windows still need live acceptance. Catalogue completeness is still under review.

## Install the alpha

1. Install a Forever-compatible Titan Panel release. The target used during research is Titan Panel 9.3.5.
2. Extract `dist/TitanGatheredForeverV3-0.4.1-alpha.zip` into the Forever client's `Interface/AddOns/` directory. It contains the shared `TitanGatheredForeverV3` core, twelve separate profession addon folders, and an optional `TitanGatheredForeverV3_Auction` addon. Individual core/module downloads are also available under `dist/modules/`.
3. Replace the old addon folders with their new counterparts; do not merge leftover legacy Lua/XML files into the new folders. Preserve the normal core-plus-profession addon layout.
4. In WoW's AddOns screen, enable Titan Panel, the Gathered core and only the profession addons you want. Disabled addons load no database. Enable Auction Items separately if wanted. Log in and enable the `TitanGatheredForeverV3` broker entry in Titan's settings if needed.
5. Run `/console scriptErrors 1`, then `/tgf status`. Record the actual live client version/build/interface and installed Titan version. Latest captured installation metadata is `1.60.1.70862`; this is separate from live API verification. Check interface `16001` and the declared catalogue counts without assuming installation metadata certifies compatibility.

## Confirm counts

1. Before first visiting the bank, hover a tracked material. Bags should match carried stacks, Bank should show zero and Total should equal Bags. Neither the item tooltip nor the Titan summary should display unknown or a bank-visit reminder.
2. Open the personal bank with known quantities of that material in bags and bank. Verify separate Bags, Bank and Total values and the invariant `Total = Bags + Bank`.
2a. With Show bank counts enabled and Show items with zero counts disabled, verify a zero Bank value is omitted from both Titan summaries and item tooltips, while positive Bags, Bank and Total values remain visible. If all inventory values are zero, no zero-valued count lines should appear. Enable zero-count display and confirm the zeros return. Disable Show bank counts and confirm Bank and Total are hidden regardless of their values.
3. Move a partial stack into the bank, then withdraw some. Wait for the inventory event batch to settle. Total should remain unchanged by either transfer.
4. Move every bank stack out. Confirm a known bank count of zero rather than a retained old quantity.
5. Close the bank. Its count should remain visible with a last-observed timestamp.
6. Reload and relog. Cached personal-bank quantities should survive, with their timestamp, until the next bank visit.
7. Switch to a second character. It must not inherit the first character's snapshot.
8. Open only account or guild storage. It must not replace or inflate the personal-bank snapshot.
9. Close the bank immediately after a transfer. Reopen and verify the updated counts; while inaccessible, the display must identify the last observation rather than claim it is current.
10. Empty both bags and the observed bank for a tracked item, enable zero-count rows, and verify `0 / 0 / 0`. Unavailable counts also display zero; internal scan status remains separate for diagnostics and must not fabricate saved observations.
11. Turn off `Show bank counts`. The list and item tooltip must show Bags alone, hide bank timestamps and bank-only items, and stop scanning bank containers. Turn it back on with the bank open and confirm that the next refresh updates counts.
12. Confirm there is no separate `Show total counts` option. Total must appear whenever Bank is enabled and disappear whenever Bank is disabled. Confirm the Bank preference survives reload. If bank quantities do not update after opening the personal bank, capture the scan status printed by `/tgf status`.

## Confirm uses and UI behavior

1. Hover Linen Cloth or another shared reagent. All supported profession uses should be listed; the same item must appear only once in the material summary.
2. Check Soul Dust, Small Glowing Shard, Star Wood, Pyrite (`249391`) and Mote of Magic (`247786`). Verify their IDs and uses against current Forever recipes. Pyrite Ore (`52183`) is not the new Pyrite.
3. If available, inspect Craftsman's Writ: Draught of Water Breathing (`264019`). The tooltip should explain its transferable crafting-order use, without making a market-price or profitability claim.
4. Inspect Vision Dust. Its additional supply-use reason refers to a bundle for Waylaid Crate: Expert Curiosities, not a requirement to supply every alternative bundle.
5. Repeatedly hover the same item, different items, chat links, loot, bank items, recipe reagents and auction results. Each supported item tooltip should gain one Gathered section, never duplicate sections or Lua errors.
6. Right-click the Titan entry. Only loaded profession addons should be listed. Auction Items belongs under Additional Items, with no `Other` profession. Toggle categories: shared reagents remain when another enabled module publishes them, without inflated counts. Disable a profession in WoW's AddOns screen and reload; its unique materials must be absent and its database must not load. Settings must survive reload.
7. Use the mouse wheel over the broker entry to page the summary if the host forwards wheel events. `/tgf next` and `/tgf prev` also change the page. `/tgf settings` opens settings and `/tgf refresh` requests a fresh scan of accessible containers.
8. Test purchases, sales, crafting consumption, trade, mailing and split stacks. Counts must describe present inventory, not historical loot.
9. Confirm material names match native item rarity colors, including poor/common/uncommon/rare items where available. Labels should be gold, profession uses cyan, recipe names violet, explanatory use notes muted teal and freshness/help notes gray. The original item tooltip above the TGF v3 section must keep its own styling; repeated addon-title headers should be absent.
10. Confirm the Titan tooltip lists every learned primary/secondary profession and its current/max rank, including a profession whose Gathered data addon is disabled. Learn a skill rank and check that it refreshes.
11. Check full-inner-width horizontal rules between learned professions and material columns, and before material groups. Check the item-tooltip rules between native information and TGF v3 uses, and between uses and inventory counts. Hover narrow then wide tooltips repeatedly: rules must resize and cleared rules must disappear.

## Confirm gathering map settings and spots

1. Enable the Mining, Herbalism and/or Skinning addon and its category. In the Titan context menu, enable `Gathering map > Enable gathering map` and the corresponding profession switch.
2. Gather ore or an herb with manual looting, then autoloot. Each successful taken resource should produce a small resource icon on the world map near the player's gathering position and on the minimap while nearby. Failed/interrupted casts or opening loot without taking it must produce none.
3. Gather a nearby node of the same resource again. It should merge and increment its observed count; a different resource should retain its own icon. Ordinary ore/herbs should take icon priority over scarce byproducts.
4. Open ordinary corpse/chest loot without gathering, then test a chest immediately after a successful gather, including a gather whose loot was never opened. Neither unrelated source should become a spot. Record the event/source sequence if a false association occurs.
5. If an icon is absent, immediately run `/tgf status` and record the Gathering map line, herb name and map. If needed, enable Debug mode for one gather, capture the gathering messages, then disable it. The status should distinguish disabled mapping, an unrecognized spell, missing map position, unreadable loot, absent supported GameObject loot and a recorded spot.
6. Switch maps, including a containing continent map, resize and zoom the world map, close/reopen it and use gamepad controls if available. Resource icons should remain a readable 14 UI pixels as the art canvas scales. Pins should stay aligned, reuse correctly, and produce no Lua errors or host interaction failures.
7. Disable `Enable gathering map`. All pins must disappear and subsequent gathering must record nothing. Re-enable it: saved points must return. Repeat separately for Mining, Herbalism and Skinning switches.
8. Disable a profession category, then disable its addon in the AddOns screen and reload. Its spots must be hidden and new observations suppressed; other enabled professions should still work.
9. Toggle `World map icons` and `Minimap icons` independently. Turning one off should hide only that display and retain spots; verify preferences survive reload. Walk toward and away from a spot, change minimap zoom, and test rotating minimap mode facing north/west/south/east. Nearby icons should track the terrain and distant spots should disappear, without icons outside the circular border.
10. Reload/relog and restart the client. Saved points and observation counts must survive. Gathering after a restart must not discard newer spots ahead of older ones when the per-map limit is reached.

## Record release evidence

Record the exact Forever/Titan builds, relevant item IDs, expected and observed counts, bank state, timestamps and any Lua error text. Run `python3 tools/check.py` after fixes and reproduce each reported failure in a regression test where possible.

Before claiming full coverage, obtain a build-matched recipe/material export and verify obtainability, output-free enchants, gathering/camping uses and curated auction items. The bundled mirror is a starting dataset, not a completeness certificate. Preserve alternative reagent groups and distinguish recipe items from crafting spells.

## Confirm debug settings

1. Right-click the Titan entry and confirm `Debug mode` is off by default. Login, gathering, inventory refresh, paging and settings changes should produce no routine diagnostic messages.
2. Enable `Debug mode`, run `/tgf` and confirm the client/catalogue/bank report appears. Disable it again: `/tgf` should print only one command-help line.
3. Reload with the option enabled, then disabled, and verify each preference persists. `/tgf status` should always print the diagnostic report when explicitly requested, even with debug off.

## Confirm icon styling and panel caption

1. With default appearance settings, confirm world-map and minimap material icons have circular item art without borders, filled backplates or shadows. Use `/tgf icons` to select Full image or an optional Thin gold outline. Zoom the map and confirm the selected appearance stays proportional and readable.
2. Confirm the Titan caption shows the addon name and `0.4.1-alpha`, without a material count. Loot or move items: the caption should keep the version while tooltip counts update.


## Confirm Skinning and material controls

1. Enable the Skinning addon/category and map switch. Skin an outdoor creature and take its leather or hide. Confirm an icon for the obtained material on the world map and nearby minimap. When two supported materials drop at one position, their markers must share that exact position, even if their images overlap. Changing observation counts must not move them.
2. Test interrupted Skinning, untaken loot, ordinary corpse loot without Skinning and ordinary corpse loot immediately after a Skinning cast. Unrelated loot must not create a spot; capture the event/source sequence if it does.
3. Gather or skin inside a dungeon and raid. No new map spots should be saved; eligible acquired history may still record instance loot. Test entering an instance between cast and loot. Previously saved outdoor spots should remain intact.
4. Open Gathering map > Map materials. Each loaded gathering profession should have individual material checkboxes and Show all / Hide all. Hide one material: its icons should disappear from both maps while other materials remain. For Linen Cloth, toggle it under First Aid and confirm Tailoring shows the same checkbox state and all eligible cloth spots follow the setting. Repeat from Tailoring, including Show all / Hide all; these bulk actions affect each listed material globally. Profession-wide switches still gate their own groups. Gather cloth while hidden, show it again and confirm observations were retained. Reload and confirm the shared choice persists. On first migration, any legacy explicit hidden material becomes hidden globally until shown again.
5. Test Show all and Hide all for each profession, then reload and confirm preferences persist. Disable the entire profession map switch: its icons should disappear and further gathering should not record. Re-enable it and confirm prior observations return.
6. Disable a profession addon and reload. Its material submenu and icons should be absent, without affecting other professions. Confirm the master switch and independent world/minimap switches still work.


## Confirm configuration organization

1. Reload and right-click the Gathered Titan entry. Check that the top level has Display, Professions, Additional items, Gathering map and Diagnostics sections, with no checkboxes at the top level. Additional items appears only when an additional module is loaded.
2. Under Display, test zero-count rows, item tooltips and bank counts. Confirm Bank still controls Total automatically.
3. Under Gathering map, check the master switch, Visibility controls, Professions switches and Map materials filters grouped by profession. Disable and re-enable mapping, reopen the submenu and confirm saved settings persist.
4. Under Diagnostics, toggle Debug mode. Confirm the setting still persists and routine chat logging stops when disabled.


## Clear saved spots from the world map

1. Open a zone with saved spots and select the TGF v3 spots button near the upper right of the map. Confirm the menu identifies the displayed map and reports separate Mining, Herbalism and Skinning counts, including hidden materials.
2. Open a category's clear action, then leave the menu without confirming. Nothing should be deleted. Repeat and select Confirm: only that category's spots saved directly on the selected map should disappear from both maps.
3. Confirm another category and another map retain their observations. Reload and verify cleared spots stay deleted. Gathering there again should create a new observation.
4. Open a confirmation, change the displayed map, then try confirming. Deletion must be refused. Continent maps may show projected child-zone spots: the menu explicitly clears only observations saved directly on the displayed map, so use the source zone to clear its records.
5. Check the TGF v3 spots button remains usable with gathering-map display disabled, is not duplicated on reopening the map, and does not overlap native map controls at your UI scale.


## Validate compact report layout

1. Run /reload. Open Lifetime materials, Observed chances, Profession actions and Crafting and cooking in succession. Only the selected report should remain visible: no overlapping titles, descriptions or rows. Close with the button and Escape, then reopen.
2. In each report change character scope, profession filter and page where enough data exists. Switch to another report, then return. Scope/filter/page should remain independent, with pages clamped only when the selected data no longer fills them.
3. Check Lifetime columns: material, obtained quantity, Times obtained, crafted and last obtained location. One gather yielding four items must add four to quantity and one to Times obtained. Reopen a partially looted source and obtain more of the same item: quantity increases but the occurrence count stays one for that source/item. Empty sources and failed/cancelled casts do not increment the item occurrence count. Check persistence after /reload and the combined-character sum. Legacy lower bounds show N+ with the at-least explanation; no recovered occurrence evidence shows Unknown. Clearing map spots must not reset either history value. Crafted-only materials must show zero obtained and no acquired-loot location. Chance percentage, hits/samples and item quantity must remain separate. Action attempts, completed, failed, interrupted, stopped without confirmation, unresolved and recording start must remain distinct.
4. Test long item/source names, large counts, multiple pages and empty filters at the normal UI scale. Text should wrap inside its column, adjacent rows should not overlap, and the last row should stay above the footer. Extremely long source text can be bounded within a page; click the item to inspect its full source information.
5. Hover an item for its native tooltip and click it for sources. Confirm source map actions and production output-detail menus still work. Switch or close the report while hovering: a stale item tooltip should not remain visible.

## Validate lifetime history and observed chances

1. Reload, then open `/tgf history` and `/tgf chances`. Both should remain independently open, movable and closable with their close buttons or Escape. Test paging, empty results, item hovers and profession filters.
2. Confirm each view defaults to This character. Gather on a second character, then choose All characters: quantities and sample counts should sum, with a weighted combined rate rather than an average of percentages.
3. Mine multiple sources of the same vein type, including one secondary drop. Confirm ore quantity differs from the number of successful outcomes. A gem obtained once in ten complete sources should show 10% (1 / 10), independently of stack size. Known input/source types and zones should remain separate.
4. Catch fish and junk in one zone, then another. Fishing should list each catch, keep junk in the complete-catch denominator and show separate zone results. Repeat with manual loot, autoloot and late source metadata.
5. Loot known cloth/meat from a corpse, then loot money only from another corpse of the same creature type. The second must count as a zero-material source. Leave a slot behind: the sample must remain incomplete. Verify area loot splits quantities by source without counting the same source twice.
6. Disenchant a known item. Confirm input-item identity when readable, obtained material quantities and observed outcomes. No map spot should be created. If identity is unavailable, the view must say unknown input. Remaining source-less item loot after a partial close must not acquire a guessed input or rate.
7. Turn map display off and gather again: enabled history should continue. Turn Record lifetime history off: new lifetime entries should stop, while enabled map collection may continue. Test recording switches per profession, Ordinary loot sources and Include rare loot. Settings should persist after reload.
8. Change recording configuration or pause during a partial source. That incomplete source must not become a complete rate sample with missing outcomes. Newly enabled materials must not inherit samples collected while excluded.
9. Gather/loot inside a dungeon and raid. Lifetime history should retain readable acquisition, rates should identify the instance context and neither map should gain instance observations.
10. Hover a reagent directly in a profession recipe, then in bags and bank. The TGF v3 section should show inventory counts, known recipe uses, lifetime quantity and source evidence without duplicating itself. History in item tooltips should hide the history section independently. Open a source list from a report and select a zone to display it on the world map.
11. Clear a category's current-map spots. History totals and percentages must remain unchanged. Ordinary gathering at that location afterward may record a new spot. Old spots should never be converted into guessed lifetime totals or rates.

Record exact spell/item IDs and event order when fishing or disenchanting fails. Live completeness is unverified until this checklist is exercised on the installed client.


## Validate the new addon identity

1. With WoW closed, back up and migrate the old account SavedVariables using the README instructions. Confirm the original file remains intact.
2. Install the new core and selected renamed profession folders. Confirm their AddOns titles begin Titan Gathered Forever v3 and dependencies resolve against the new core.
3. Disable the previous-generation addon folders. Enable the new Titan broker entry. Its caption should display the official name and 0.4.1-alpha.
4. Confirm /tgf settings, /tgf history and /tgf chances work. Verify prior history, spots, bank snapshots and preferences survived migration.
5. Verify map icons use the new icon path, context menu labels say TGF v3, and the map button opens the new spot menu. Reload and confirm persistence in TitanGatheredForeverV3.lua.

## Validate profession actions

This gate is pending real-client execution. Test the candidate in the actual Forever 1.60.1 client with the affected modules and Titan Panel enabled. Record client build, spell IDs and event order for any discrepancy.

1. Open `/tgf actions` and the Profession actions menu entry. Check dragging, Escape, current/combined selection, profession filters, empty states and readable coverage dates. Hovering or clicking an action row must not open an item tooltip/source menu. Confirm older history has not populated guessed action counts.
2. Mine, gather herbs, skin and disenchant one item each. Every distinct action should add one attempt; successful casts should add one completion. Loot quantity and complete-source samples must retain their earlier independent meanings. Attempt an action that fails, interrupt another, and stop another manually. Check failures and interruptions against the actual emitted events. A stop without stronger evidence must say stopped without confirmed result, not manual cancellation.
3. Cast Fishing and wait: completion must remain zero until a fishing-loot window opens. Catch fish, catch junk, leave a catch unlooted, cancel early and let a line expire. Repeat with manual loot and autoloot. Verify the client's cast GUID remains stable across launch/channel events. A catch window should add one completion even if no items are taken; opening/closing the same window must not add attempts.
4. Recast quickly and cast an unrelated spell between a cancelled line and later loot. Verify stale fishing events do not complete an older or newer unrelated action. Compare Fishing counts with actual cast/catch history; delayed fishing loot without a trusted current action must not invent attempts.
5. Disable map visibility and lifetime history while leaving action recording on: actions should continue. Disable action recording or just its profession, then act again: action counts must stop while enabled source history/maps continue. Re-enable during a pending cast and confirm its late events do not fill the recording gap. Profession category disabling must also stop recording. Ordinary display toggles should preserve pending actions.
6. Reload with a pending action, then complete a new one. Pending observations should remain unresolved rather than become guessed failures. Confirm saved totals and controls survive reload/relog, older settings/history remain intact and combined values sum across two characters. Coverage starts are per character/profession, with the earliest date shown in the combined view.
7. Repeat a supported action in an instance. Action recording may continue; it must create no map spot by itself. Inspect history and map counts before and after failed actions and unused fishing catches: no obtained-item quantity or complete-source sample should be invented by the counter.

If Fishing emits a different cast identity at channel start, or a loot window cannot be reliably correlated, retain this release gate and capture the exact sequence before claiming reliable live action coverage.

## Validate crafting and cooking production

This gate is pending real-client execution. Use the local candidate on the actual Forever client, with Titan Panel and the affected profession addons. Record build, recipe ID, cast GUID and operation ID for discrepancies.

1. Open `/tgf production` and Crafting and cooking under History and sources. Check current/combined selection, profession filters, five-row paging, item hovers, clicking a recipe for quantity distributions, readable dates and window layout at your UI scale. Existing history, bags and bank observations must remain intact.
2. Cook one item, then a queue of several identical recipes. Compare distinct observed starts, completed casts, matched result operations and actual quantities with the native crafting output log. Verify that recipe spell IDs match live recipe metadata and that result operation IDs are positive and distinguish operations. If operation identity is absent, retain the validation gate; do not infer missing output from bag changes.
3. Craft a recipe that produces multiple units. If available, exercise explicit bonus/multicraft results and variable outputs. Compare item totals and per-operation observed quantity distributions. A quantity larger than one must not itself imply a proc. Proc denominators should include only readable explicit flag observations, not all casts.
4. Test both result-before-success and success-before-result event sequences if the client emits them. Interrupt or fail a craft, stop a queue midway and check that failed/interrupted attempts produce no counted output. A cast with no matched result can remain completed with zero matched operations; explain any discrepancy using the recorded event sequence.
5. Test a multi-output recipe and first-craft rewards. Rewards must not become production. Additional outputs can join a bound operation; secondary output arriving first remains unpaired. If distinct recipes share an output and both have pending contexts, ambiguous results must be excluded rather than guessed. Inspect the resulting incomplete coverage.
6. Turn lifetime history, gathering actions and map display off while production stays on: production must continue. Disable Record production, a production profession, or its category and start crafting; re-enable before success. That cast must not enter production without an enabled observed start. Existing counters remain visible when recording stops.
7. Pause recording after a cast, then start another recipe producing the same item. Deliver or observe delayed old output if possible. Recent sealed contexts must block attribution to the new cast, even if that temporarily leaves new completed operations without quantities. Repeat across reload/world transitions and confirm preserved totals and recording settings. No old pending result may fill a recording gap.
8. Verify ordinary loot, purchases, trades and bag/bank transfers never change crafted quantities. Crafting must not add loot-source samples, alter acquired quantities, manufacture current inventory observations or create map spots, including inside instances. Tooltips and Lifetime materials should display crafted quantities separately, including outputs absent from the material catalogue.
9. If the client supports recrafting, enchant application or salvage, verify each remains excluded. Explicit recipe flags are checked; if a recraft uses ordinary recipe identity, capture that flow before claiming new-item-only coverage. Unknown, protected or unavailable recipe metadata must fail closed.
10. Produce on a second character, select All characters and verify summed completed/matched operations, output totals, quantity distributions and explicit-field counts. The earliest recording date is combined coverage only; it does not imply continuous measurement for every character.

## Validate contextual crafting assistance

This gate is pending real-client execution on Forever 1.60.1. Record the client build and recipe spell ID when comparing the planner against the native recipe schematic.

1. Select a simple item recipe in the native profession list and use `/tgf recipe`, or Plan selected recipe reagents in the Titan menu. Compare live reagent quantities with the native UI. Open the same plan with `/tgf recipe <recipeID> 3`, More/Fewer, production recipe details and a material's known recipe example. Verify the planned target counts operations rather than output items.
2. Compare each required/available/missing row and the limiting operation count against hand-calculated quantities. If the same item occupies multiple required slots, its requirements must be summed before capacity is calculated. Check reagent paging, native item hovers, source clicks, dragging, Escape, errors and empty states at your UI scale.
3. Switch Display > Show bank counts off. The planner and selected-recipe reagent tooltip must use Bags only, without bank quantities or bank observation timestamps. Switch it on, visit the bank and transfer a reagent: the refreshed plan should use Bags + Bank. Close the bank and verify cached estimates and observation time are labeled. Unknown inventory must display zero while withholding a definitive overall material limit.
4. Plan a recipe with required alternatives, currency, variable quantities or another unsupported required slot. It must say unresolved rather than claim unlimited or positive craftability. Fixed rows can be partial. Optional modifiers and finishing reagents must be explicitly excluded. No-material or partially loaded schematics must not yield an unlimited count.
5. Test a normal enchantment recipe and an unlearned recipe if live metadata is available. Distinguish a material limit from actual ability to craft. Test recraft, salvage, gathering and dummy contexts: these must remain excluded. Disabled or absent profession modules/categories must not provide an estimate.
6. Hover a reagent for the selected native recipe. Confirm the added summary is compact and contains the appropriate per-operation deficit and inventory scope. Change recipe, close professions, change data source and leave the world: stale context must not remain. Verify ranked recipes match the actual selected native schematic, not a different rank. If the selection callback or rank identity differs, retain this gate and capture the native event payload.
7. Click a reagent's source evidence. Rates must identify source and zone, retain instance context, and show complete observed sample counts separately from saved map positions. Selecting a saved-position entry should open its map. World-map/minimap pin tooltips must explicitly state that source/zone observations are not a chance at that coordinate. Lack of complete source samples must never turn saved positions into guessed rates.
8. With all recording controls off, open and refresh plans. Inventory refresh may update ordinary bag snapshots, but planning itself must create no bank observation, acquired item, produced quantity, action attempt, complete source trial or map spot. Preserve existing settings and saved observations across reload.

## Validate statistics export and copying

This gate is pending real-client execution. Use `/tgf export` and keep copied files outside game/runtime folders.

1. Open by slash command and menu. Confirm This character and identity off, with no automatic transmission. Copy a small snapshot, save UTF-8 JSON and run `python3 tools/read_export.py <file>`. Check the exact clipboard/save round trip; edit-box retention is insufficient.
2. Confirm default JSON omits names, character GUIDs, raw event IDs, coordinates, inventory and arbitrary labels/keys. Numeric game IDs, map IDs and timestamps remain. Opt into identity and verify only documented fields are added. Turn it off, close/reopen and reload: new snapshots must default off.
3. Generate a large combined export. Test scrolling, selection, Ctrl+C/Cmd+C, Previous/Next and saving all parts. Reconstruct in reverse order and compare counts/distributions with reports. Missing/duplicate/mixed/edited parts must fail. A truncation warning blocks Select text; do not manually copy rejected content.
4. Generate, then gather/craft while the window stays open. Parts must remain from the original snapshot until regeneration. Do not mix Generate actions or scope/identity changes. Accidental typing should restore the generated part.
5. Compare characters with unequal sample sizes. Combined rates must sum eligible counts, not percentages. Check excluded-material policies, zero-hit groups and partial quantities separately from complete-source outcomes.
6. Check action/production first observations, unresolved results and matched operations. Acquisition start timestamps remain unknown. Old spots must not become guessed counters. No uninterrupted coverage or server probability claims.
7. Close and verify buffer/focus clearing. Export must not seal collectors, change history, add spots, scan bank or alter recording settings. Unsupported future schemas remain unavailable without breaking identity export.
8. Verify Escape, dragging, key handling and layout. The reader checks transport/version/selection; independently assess statistical accuracy through the collection checklists.

## Validate catalogue corrections on the current build

1. Confirm actual GetBuildInfo. Installation metadata captured build 70862; the recipe mirror has no extraction build. Version/interface acceptance is not full catalogue certification.
2. Enable core and Fishing with Alchemy/Cooking disabled. Check 6358, 6359, 6522, 13422, 13755, 13888 and 13893: counts and consuming uses must remain. Enable consuming modules and confirm no duplicate counts or examples.
3. Fish supported materials and inspect history/source controls. Outdoor observations may create maps; instance catches may contribute to history but never instance map positions. Retain the earlier Fishing event-order gate.
4. Collect exact-build recipe/profession/material evidence separately from membership. Preserve unresolved IDs and review associations rather than deleting by inference. Follow book-catalogue-reconciliation.md for provenance and regeneration.

## Faction-aware flight points, local candidate

1. The updated 0.4.1-alpha candidate was installed on 2026-11-07, including this feature. Restart WoW to load it; close the client before subsequent replacements. Keep Titan Panel enabled and disable the previous addon generation.
2. Open the Titan menu, Flight points, and enable Show flight points. Disable gathering markers and profession addons to confirm flight points work independently.
3. On an Alliance character, browse a zone with known Alliance, Horde and neutral flight masters. Only Alliance and neutral addon markers should appear. Repeat on Horde, including a character with different discovered routes. No discovery status should carry between characters.
4. Confirm all exposed undiscovered locations remain visible. With default appearance settings, flight markers retain native artwork without added borders; discovery status is shown in tooltip text. Hover a marker to verify its name, faction and explicit status. Compare several locations and discoveries with the client flight map. Native markers should not receive a duplicate addon icon; applied flight appearance settings may change their size, shape and optional outline; their usual click behavior should remain functional.
5. Discover a new route and open/close its taxi map. The world-map discovery tooltip should update without a reload. Change zones/maps, zoom and resize the map; verify icon alignment and visibility. Check that empty maps do not retain markers from another map.
6. Turn Show flight points off: addon icons and tooltip additions disappear, while ordinary Blizzard flight markers retain their standard behavior. Reload and confirm the toggle persists. Reenable and verify the faction/discovery filter again.
7. Record missing locations, wrong factions, incorrect discovery status, appearance mismatches or Lua errors with character faction, map name/ID and client build. The live API supplies the locations; an empty response is not proof the map has no flight masters. No static all-world completeness claim is made.

## Exact map positions and image transparency correction

The screenshot report showed a row of co-located material images over large joined gold discs. The previous renderer deliberately displaced equal-coordinate pins and added filled circular rims plus multiple shadows. Both were removed for gathering markers. World-map and minimap positions now use only the recorded/projected coordinates; nearby markers are not spread into a row. Existing saved observations and counts are preserved.

1. Repeatedly gather at the same position, including drops of different supported materials. Check the world map and minimap: marker centers should stay at the saved/projected position as counts increase. No artificial horizontal separation should appear.
2. Browse a dense area at several zoom levels. Gathering markers should have no addon-created gold plates, background fills or shadow halos. With default settings their images have a circular alpha crop with transparent corners; Full image disables this crop. Source alpha inside the circle remains transparent.
3. Overlapping markers can obscure each other. This is intentional under the exact-location requirement; do not add offsets to make each image visible. Use the existing material visibility filters when inspecting one material.
4. With default settings, verify flight markers have no addon outline or background. An explicitly enabled Thin gold outline should follow the chosen shape without a filled center. Their discovered/undiscovered/unknown status remains in the tooltip. Check the native marker's click/tooltip behavior as well.
5. Distinguish native artwork from addon decoration: an opaque background baked into a source item image remains opaque. Renderer changes do not create background-free cutouts. The user confirmed retaining WoW's existing images without addon borders; no replacement artwork is part of this correction.

This correction was installed into live WoW on 2026-11-07. Restart WoW to load the updated files, keep the screenshot as the before state and repeat these checks. Close the client before subsequent replacements.

## Icon appearance window

1. Open `/tgf icons`, or Titan menu > Icon appearance. Confirm a compact draggable window with World map, Minimap and Flights selectors and sample previews. Opening the window must not change map appearance.
2. Select World map. Increase size, choose Full image and optionally Thin gold border. The sample should show all source artwork. Select Circle and confirm the corners are cropped rather than assuming a larger circle can show a square image in full.
3. Click Apply. Open the world map and verify image size/shape/outline immediately changes without moving icon centers or restoring the former horizontal separation. Minimap settings remain independent. Enabling an outline must never add a filled backdrop.
4. Change the draft again, then Cancel or close with the window button/Escape. Reopen and confirm only the last applied settings remain. Reset group should restore only that draft group until Apply is clicked.
5. Configure large Full image minimap markers. Walk near the map's edge and check that no image corners or outline extend outside its circular boundary. Rotate and zoom the minimap and verify positions remain correct.
6. Change flight size/shape/outline, Apply, and compare native and addon-created flight points. Confirm native clicks still work, discovery tooltips remain correct, and faction filtering is unchanged. Disable flight points: native markers should return to their normal scale/shape, while addon-created markers disappear. Reenable and change displayed maps to exercise pooled native pins.
7. Reload and verify all applied groups persist. Test with only the shared core and Titan, without profession modules; the window and flight controls should still open. Confirm no material/history/action/export data changes from appearance editing.

Default material appearance remains 14 px, Circle and no border; flight sample/default addon markers are 18 px, Full image and no border. Native flight markers retain standard styling until appearance settings are applied. Alpha outline assets are 32-bit TGA with transparent centers; no item artwork is replaced. Live UI/native-provider behavior still requires this acceptance pass.

## Mining vein marker identity

1. Mine a vein yielding ore plus stone and/or a gem. Take the loot in different orders. The map should show the primary ore at the recorded position, not a stone/gem covering it. Repeated gathers should update that ore marker without adding byproduct icons there.
2. Check lifetime quantities and source rates for every output. Stones and gems must still be counted; marker choice must not remove them from history or observations.
3. Take only stone, leaving ore unclaimed, then close loot. Do not create an invented ore marker from that partial receipt. Reopen and take the actual ore; it should create the proper ore pin while preserving the earlier stone quantity.
4. Existing legacy byproduct pins within the established merge radius of a recorded primary ore are hidden from world/minimap display. They remain in saved data and clear/count operations. A standalone old pin is retained when there is no ore evidence nearby. Do not silently relabel it to a guessed ore.
5. Ordinary material Loot locations remain supported, including mining reagents obtained outside a confirmed mining cast. Known scarce mining resources retain their existing fallback priority when no primary ore is observed. Appearance settings, faction-aware flights and marker coordinates are unchanged.

## PvP Board and outdoor PvP spots

1. Open `/tgf pvp` and the Titan menu's PvP Board. Confirm the client lifetime honorable-kill total and current/highest ranks are shown separately from addon-observed values. Missing client APIs should display as unavailable.
2. Check addon-observed honorable kills and per-kill estimated honor by outdoor, Battleground and arena context. Other honor awards are excluded. Estimates must not be added to the client lifetime total. Death counters are addon observations since feature activation, not reconstructed lifetime totals.
3. In an outdoor zone, perform a credited honorable kill. Confirm a PvP marker appears at the current map location on both world map and minimap, with count and estimated honor in the tooltip. Repeat nearby to increment the same marker. An honor-confirmed assist should count even without the killing blow.
4. Earn honor in a Battleground and arena. Confirm the board records those context-specific honor events while neither instance creates an outdoor map marker.
5. Die to a hostile player and confirm the death recap attributes the lethal hit to that player and increments the current context. Die to a creature and confirm no PvP death is added. If the recap is ambiguous or absent, do not claim that death was recorded.
6. Toggle PvP spot visibility, reload, reopen the map and confirm settings and observations persist. Use the map's TGF v3 spots menu to clear PvP spots for that map only; lifetime/client totals and other map nodes must remain.

Automated tests cover host-side event parsing, context routing, missing APIs, persistence, map/minimap rendering and clearing. They do not replace the live acceptance steps above.
