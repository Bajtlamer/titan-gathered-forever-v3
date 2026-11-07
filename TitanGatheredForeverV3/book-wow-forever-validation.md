# Validate Titan Gathered Forever v3

This is an alpha. Automated checks pass against simulated host APIs, but history collection and the new report windows still need live acceptance. Catalogue completeness is still under review.

## Install the alpha

1. Install a Forever-compatible Titan Panel release. The target used during research is Titan Panel 9.3.5.
2. Extract `dist/TitanGatheredForeverV3-0.4.1-alpha.zip` into the Forever client's `Interface/AddOns/` directory. It contains the shared `TitanGatheredForeverV3` core, twelve separate profession addon folders, and an optional `TitanGatheredForeverV3_Auction` addon. Individual core/module downloads are also available under `dist/modules/`.
3. Replace the old addon folders with their new counterparts; do not merge leftover legacy Lua/XML files into the new folders. Preserve the normal core-plus-profession addon layout.
4. In WoW's AddOns screen, enable Titan Panel, the Gathered core and only the profession addons you want. Disabled addons load no database. Enable Auction Items separately if wanted. Log in and enable the `TitanGatheredForeverV3` broker entry in Titan's settings if needed.
5. Run `/console scriptErrors 1`, then `/tgf status`. Confirm client `1.60.1.70790` and the expected catalogue counts. Record the actual installed Titan version.

## Confirm counts

1. Before first visiting the bank, hover a tracked material. Bags should match carried stacks, Bank should show zero and Total should equal Bags. Neither the item tooltip nor the Titan summary should display unknown or a bank-visit reminder.
2. Open the personal bank with known quantities of that material in bags and bank. Verify separate Bags, Bank and Total values and the invariant `Total = Bags + Bank`.
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

1. Confirm both world-map and nearby minimap resource icons have circular item art, a thin golden border and a subtle shadow down/right. Zoom the world map and confirm all decoration stays proportional and readable.
2. Confirm the Titan caption shows the addon name and `0.4.1-alpha`, without a material count. Loot or move items: the caption should keep the version while tooltip counts update.


## Confirm Skinning and material controls

1. Enable the Skinning addon/category and map switch. Skin an outdoor creature and take its leather or hide. Confirm an icon for the obtained material on the world map and nearby minimap. When two supported materials drop, both icons should remain visible with a small separation.
2. Test interrupted Skinning, untaken loot, ordinary corpse loot without Skinning and ordinary corpse loot immediately after a Skinning cast. Unrelated loot must not create a spot; capture the event/source sequence if it does.
3. Gather or skin inside a dungeon and raid. No new observations should be saved. Test entering an instance between cast and loot. Previously saved outdoor spots should remain intact.
4. Open Gathering map > Map materials. Each loaded gathering profession should have individual material checkboxes and Show all / Hide all. Hide one material: its icons should disappear from both maps while other materials remain. Gather it while hidden, then show it again and confirm the observation was retained.
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
