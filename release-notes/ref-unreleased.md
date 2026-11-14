# Unreleased development updates

Updated 2026-11-12. These changes describe the 0.5.40-beta source candidate and its versioned update. They have not been assigned a new release tag or published as replacement release assets. Historical versioned notes describe their original releases.

## Auction scan: longer wait and the server's own messages, 0.5.40-beta

- The first live scan logged "requested" and, 15 seconds later, "no-answer": no REPLICATE_ITEM_LIST_UPDATE arrived in time. The wait is now 120 seconds, the bar counts the seconds, and the throttled message events of the auction house are shown in the bar and written to auctionLog: AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED, SENT, RESPONSE_RECEIVED and DROPPED (a dropped request ends the scan with a message to wait a minute). A list that arrives while no scan was asked for is logged as update-ignored with its size, and the log keeps 30 entries and records whether the throttled message system was ready at the request. The status line says when the last scan got no answer instead of "No auction prices scanned yet".
- The line "No auction prices scanned yet" beside the button was correct: nothing had been stored, because the scan had not finished.

## Progress of the auction scan, 0.5.39-beta

- The scan now shows what it is doing. A progress bar appears beside the Scan prices button with the phase: "Waiting for the auction house to send its list..." and then "Reading auctions: 40% (12000 of 30000)". The idle status line returns when the scan ends, fails or the window closes, and the button is disabled while a scan runs.
- The chat gets a line when the list arrives ("The auction house sent N auctions. Reading them..."), at 25, 50 and 75 percent of a list longer than 1000 auctions, and the existing line at the end. An empty list is reported as well.

## Reagents button in the header and a recipe menu entry, 0.5.38-beta

- The Reagents button of 0.5.36 was drawn inside the recipe list and displayed wrongly. It is now in the header of the profession window, left of the maximize button (left of the close button when the window has none), as a child of the maximize button so that it shows only on the recipes tab.
- A right click on a learned recipe in the recipe list has a new entry Reagents that opens the reagent window for that recipe (one craft). It is added to the menu the client opens there (tag MENU_PROFESSIONS_RECIPE_LIST_FAVORITE) with Menu.ModifyMenu, and uses the highest learned rank like the selection does (new Crafting.Resolve).
- The anchors come from the client source of the forever branch (ProfessionsFrame.MaximizeMinimize, CloseButton, the menu tag) and are not yet verified in game.

## Auction prices, 0.5.37-beta

- A Scan prices button appears below the auction house window (and Titan menu > Auction prices > Scan now). It reads the whole auction house with the client's full scan (C_AuctionHouse.ReplicateItems, answered with REPLICATE_ITEM_LIST_UPDATE), in steps of 250 auctions so the game does not stall, and keeps for each item of the profession catalogue the lowest buyout per unit, the quantity on offer and the number of auctions. Bid-only auctions are ignored. The client allows a full scan about every 15 minutes: an early request is refused with the minutes left, and a scan that gets no answer within 15 seconds ends with a message. The prices are saved per realm. The menu can scan automatically when the auction house opens (at most every 30 minutes, off by default) and can clear the prices; an auction scan log with the last 12 outcomes is kept in the saved variables (auctionLog).
- The reagent window has an Auction each column with the lowest buyout per unit, and its line shows what the missing reagents would cost at auction, with how many of them are priced. The reagent window still names merchants first in the last column.
- New file AuctionScan.lua, so a full game restart is needed. The API shape comes from the client documentation of the forever branch (the position of the values returned by GetReplicateItemInfo is covered by a test); it is not yet verified in game, and the button is placed below the window of the auction house (AuctionHouseFrame) without knowing its layout.

## Merchants with reagents and a button in the profession window, 0.5.36-beta

- When a merchant window opens, the goods that belong to the professions of the catalogue (reagents and the like) are recorded with the price of a stack, the stack size and the stock, together with the recipes the merchant sells. Merchants without such goods are not recorded for them, and goods paid with something other than money are marked as special cost. The seed has no reagent goods, so this is observed data only.
- The reagent window names such a merchant in its last column ("Buy 50c each: Name, Zone", cheapest first), and the source menu of a reagent has a Sold by section that opens the map and marks the merchant with the red ring. The pin tooltip of a merchant lists the goods as well. A merchant with goods only gets a pin only while it is marked, so the map is not crowded.
- The profession window of the client has a Reagents button beside the Create buttons. It opens the reagent window for the selected recipe with the number of crafts typed in the profession window, so /tgf recipe is no longer needed. The chat command and the Titan menu entry stay. New file ProfessionButton.lua, so a full game restart is needed. The anchor (CreateAllButton of the crafting page) comes from the client source of the forever branch and is not yet verified in game; the button is simply absent if the frame differs.

## Recipe reagent window redesigned, 0.5.35-beta

- The window of /tgf recipe now has one line per reagent in columns: Need, Bags, Bank, Missing and Where to get it. The reagent name and the last column are green when the bags hold enough, yellow when enough is only in the bank (the line says how many to take) and red when it is missing (the line shows the best observed source, or says that none is recorded). Reagents with a count the client has not given are gray. The missing ones are listed first, then unknown, in the bank and ready; inside a group they follow the item name.
- A headline says whether the planned crafts can be made (ready, enough but in the bank, only some, not yet) and a line counts the missing, in bank and ready reagents.
- Fewer and More are replaced by - and + buttons beside a number box. Typing a number works up to a million, Shift adds or removes five.
- 18 reagents fit on the screen instead of 6, because a reagent is one short line. Click a reagent still opens the observed sources, and hovering shows the item.
- The bank column shows a dash when Display > Show bank counts is off, and the yellow state is not used then. The addon has no data about which reagents vendors sell, so it cannot mark a reagent as something to buy; it shows only sources observed by the player.

## Tab width measurement log removed, 0.5.34-beta

- The tab widths of the first window are confirmed correct live after 0.5.33, so the measurement log (saved variables key navProbe) is removed. Lines already saved under that key stay in the saved variables file until the client rewrites it without them and are harmless.

## Tab widths: measure without the fixed text width, 0.5.33-beta

- The measurement log of 0.5.32 showed the real reason: a new tab has a fixed text width of 52, so GetStringWidth only reports the cut text (about 50 for "Unlearned recipes") and every earlier resize used that wrong number. Re-showing the window repaired the tabs because the template measures again on its own then (text 94, tab 114). The fit now removes the fixed text width first and then measures. The measurement log stays one more version.

## Tab widths: the first show never fired, 0.5.32-beta

- Cause found from the measurement log: a new frame is already shown, so the first Show of a tab window does not fire OnShow, and the tab measuring that 0.5.29 to 0.5.31 attached to OnShow only ran after the window was hidden and shown again (which is why clicking another tab and back repaired the tabs). The tabs are now measured at creation as well, and again after 0.1, 0.5 and 1.5 seconds. The measurement log stays for one more version to confirm the fix.

## Tab width fallback and measurement log, 0.5.31-beta

- 0.5.30 did not fix the first window either (hiding and showing the window repairs it, which no code of ours does). A tab that is still narrower than its own text now gets a width set directly. To find the real cause, every show of a tab window writes the widths of the tab buttons and their texts (button / text / string width, before and after the resize, and again at 0.1, 0.5 and 1.5 seconds) to the saved variables key navProbe, at most 24 lines. This is diagnostic and will be removed once the cause is known.

## Tab widths measured with the string width, 0.5.30-beta

- 0.5.29 did not help: clicking another tab and back repaired the tabs, but the first show did not. The template measures the tab text with GetWidth, which is still 0 before the first layout pass. The tabs are now resized with the exact GetStringWidth passed as the text width, on show and again after 0.1, 0.5 and 1.5 seconds while the window is open.

## Tab widths on the first window, 0.5.29-beta

- The tabs along the bottom of the first window opened after the game starts were too narrow and cut their names ("Unlearn..."); they fixed themselves once other tab windows were created. The tab widths are now measured again when the window is shown, right away and 0.1 seconds later. A /reload is enough.

## Faster first opening of the recipes window, 0.5.28-beta

- The first opening of the window after starting the game lagged for a long time. The recipes list asks the client for the names of about 550 vendor recipe items at once, every answer arrives as its own event, and each event recomputed and redrew the whole list. The redraw now happens once after a burst of answers (0.3 seconds after the first one), and item names are only requested for the professions in view (the profession filter limits the requests). The measured cost of one computation of the list is a few milliseconds on a desktop, so several hundred of them in a row were the lag.

## Trainers tab, 0.5.27-beta

- New tab Trainers in the window (also Titan menu > Trainers and recipe vendors > Trainers...): every profession trainer with zone, coordinates in percent and status. By default only trainers not visited yet are listed; a combo box switches to Visited (with the date) or All trainers, another one filters by profession. The search box matches trainer name, profession and zone. Hovering a row shows what the trainer teaches; clicking opens the world map at the trainer and marks it with the red ring (click again to clear). A trainer counts as visited once its window was opened and recorded, so a visit to the same NPC only as a merchant does not count. Trainers without a known position are counted in the footer.
- New file TrainerBrowser.lua, so a full game restart is needed. The tab strip now has eight tabs; the button fallback shares the width evenly.

## Trainer filters touched only when needed, 0.5.26-beta

- The client always reports an empty trainer list on the opening event and fills it on the update that follows, so the 0.5.25 read switched the player's type filters on for every trainer. They are now switched only when the list is still empty after that update, which is the case of a trainer with nothing left to teach (Bronk Guzzlegear). Other trainers, for example the Mining trainer, are read with the player's own filters as before.

## Fix: C stack overflow when a trainer opens, 0.5.25-beta

- Opening a Mining trainer raised "C stack overflow" in NpcObserver.lua. The client answers SetTrainerServiceTypeFilter with TRAINER_UPDATE from inside the call, so restoring the filters read the trainer again and restored the filters again, without end. A read that is running now ignores such nested events, and the list of changed filters is taken and cleared before the filters are put back. A test now simulates the immediate event. The error appeared from 0.5.24, which restored the filters right after the read.

## Trainer filters restored right after the read, 0.5.24-beta

- Keeping the filters on until the window closed (0.5.23) left the trainer window showing already known services, which is not what the player's filter says. The filters are now restored right after the successful read, in the same handler, so any flash lasts a moment. The close of the window still restores them as a fallback.

## No flashing trainer list, 0.5.23-beta

- For a trainer with nothing left to teach, the trainer window showed the known services for a moment and then emptied, because the filters were put back right after the read. The filters now stay on while that window is open and are restored when it closes.

## Trainers with all services known are recorded, 0.5.22-beta

- Confirmed live: Bronk Guzzlegear is now recorded (11 Engineering services). The client rejects the numbers 1 and 0 in SetTrainerServiceTypeFilter ("Missing on/off parameter") and accepts true and false, so the filters are switched on with true for one delayed read and put back with false. The report field in the NPC recording log is kept.

## Trainer filter diagnostics, 0.5.21-beta

- The live log after 0.5.20 showed the "Already known" filter still off after the addon tried to switch it on, and the delayed read still found no services. The addon now tries the value 1 and then true, reports what the client answered (the "first" field of the filters-on entry in the NPC recording log) and restores the filter whichever value took effect. This is a diagnostic step: if Bronk is still not recorded, the report shows whether the filter call is accepted at all.

## Trainer filters read after the list is rebuilt, 0.5.20-beta

- The 0.5.19 read did not record Bronk Guzzlegear: the live log showed the list was still empty right after the type filters were switched on. The filters are now switched on, the list is read again 0.3 seconds later (log event TRAINER_FILTER, first result filters-on), and the filters are put back after that read or when the trainer window closes. Still once per opened window.

## Trainers with nothing left to learn, 0.5.19-beta

- A trainer whose services are all already known (for example Bronk Guzzlegear for an engineer) stayed "Not yet confirmed in game", because the trainer window hides known services by default and the addon saw an empty list. When the list is empty the addon now switches the three type filters on for the read, records the trainer and puts the filters back. This happens once per opened window. The Diagnostics NPC recording log also shows the filter states. Whether the client applies the filter change immediately awaits live review.

## Combo boxes for every choice, 0.5.18-beta

- The remaining two state buttons are now combo boxes as well: the scope (This character, All characters) in every statistics tab and in the export window, the source filter (All unlearned, Vendor only) of the recipes window, the grouping (All sources, Grouped by item) of the observed chances and the export setting for names and GUIDs. Only action buttons remain buttons (Generate, Select text, Fewer, More, Refresh, Clear, the expand and part buttons).

## Combo boxes and classic tabs, 0.5.17-beta

- The profession filter in the recipes window and in the statistics tabs is now a Blizzard style combo box (a drop down showing the selected choice) instead of a button that opens a menu. It falls back to the previous button and menu when the client has no drop down template.
- The tabs are classic panel tabs hanging below the window. When the client lacks the panel tab template they fall back to the button row used before, so the window always opens. Both the look of the drop down and of the tabs await live review, because the templates could not be checked outside the game.

## Character level for profession ranks, 0.5.16-beta

- Profession rank rows in the unlearned recipes window are hidden until the character reaches the level the trainer requires (Journeyman 10, Expert 20, Artisan 35, Master 50 when the trainer window never reported it).
- The trainer window recording now stores the required character level of each service (the fourth value of GetTrainerServiceInfo in the recorded probe), so visited trainers use the real value. Trainers visited before this version fall back to the classic values above until they are opened again.

## Skill reading shown for rank rows, 0.5.15-beta

- The hover tooltip of the Where column on a profession rank row now starts with "Your <profession> skill is a / b.", the values the addon read from the client, so a wrong choice of rank can be traced to its input.

## Next profession rank in the unlearned window, 0.5.14-beta

- The unlearned recipes window now lists the next profession rank (for example Journeyman Fishing) with the trainers who teach it, their price and the required skill. For every profession the character has, only the lowest rank not yet reached is listed, and only once the skill requirement is met, which covers both "the maximum is reached" and "it can be learned now". Clicking the row opens the map and marks those trainers like any other recipe. Fishing, Herbalism and Skinning were added to the profession filter for this. The vendor only filter hides these rows because they are trainer rows.

## Rank spells in trainer tooltips, 0.5.13-beta

- Fix: the Fishing trainer tooltip said "Learned status unknown: open the profession window once (Fishing)" even after the Fishing window was opened. Fishing has no recipe list, so it can never be read that way, and the trainer only teaches rank spells ("Journeyman Fishing"). Rank spells (Apprentice, Journeyman, Expert, Artisan, Master) are now judged by the profession skill cap (75, 150, 225, 300, 375) and are shown as learned or not without that note. The same applies to the rank rows of every other profession trainer, which were previously shown as not learned.

## Learned status in trainer and vendor tooltips, 0.5.12-beta

- A recipe the character already knows is dimmed (gray name) and tagged "learned" in green, so the white rows are the ones still worth learning. This replaces the earlier small "(known)" tag.
- When the professions of the listed recipes were never read for this character, the tooltip ends with a gray note "Learned status unknown: open the profession window once (Cooking, ...)". Previously such rows looked the same as unlearned ones.

## One window with tabs, scrolling lists, search and grouping, 0.5.11-beta

- The minimap button now opens one window with seven tabs along the bottom: Unlearned recipes, Lifetime materials, Observed chances, Profession actions, Crafting and cooking, Reagent use and PvP Board. Left click opens the last used tab or closes the window; right click still opens the menu. The tabs are the same windows the menu and chat commands already opened, so every existing entry still works. All tabs share one size and one remembered position, and each keeps its own filters and scroll position.
- Previous and Next paging is gone from the statistics windows and the recipe reagent planner. They scroll with the mouse wheel and a scroll bar, with a "Showing a-b of n" line. Rows keep their wrapped height, so a long row is never cut.
- Search box (with Clear) in the recipes window and in every statistics tab; it matches item, recipe or statistic names.
- Observed chances can be grouped by item (button "All sources" / "Grouped by item"): one row per item with its summed quantity, and a + button that expands the individual sources with their chances.
- The export window still shows its JSON in numbered parts, because the client text box cannot hold a larger text.
- New file Navigation.lua, so this update needs a full game restart, not only /reload.

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
