# Plan: live verification and optimization (continuation for a clean session)

See also plans/plan-sales-history-and-price-trends.md (auction panel, sales ledger from the mail, handover notes).

Written 2026-11-15 at the state of 0.5.53-beta (branch feat/npc-sources, pull request 3) and Titan Command History 0.1.5-alpha (repository titan-command-history, branch main). This is the single continuation plan: it lists everything that is implemented but not yet confirmed in the game, and everything that is worth optimizing next. Older plans in this folder keep their original designs and evidence; where they disagree with this plan, this plan wins.

## 1. How to start a clean session

- Repository: <addons-dir>/titan-gathered-forever, branch feat/npc-sources, stacked pull request 3 on top of pull request 2 (branch feat/history-source-tree). Nothing is merged to main, no tag or release exists. Release publication is on hold until the user says otherwise.
- Companion project: <addons-dir>/titan-command-history (GitHub Bajtlamer/titan-command-history, branch main, public). Its own plan is plans/plan-command-history.md in that repository.
- Game: WoW Forever 1.60.1, interface 16001, add-ons in /Applications/World of Warcraft/_forever_/Interface/AddOns. Saved variables: /Applications/World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/TitanGatheredForever.lua and TitanCommandHistory.lua. The client writes them only on /reload or logout, so ask the user for a /reload before reading a log.
- Rules of the user (also in AGENTS.md): no em dashes, no emoji or decorative glyphs; document prefixes plan-, ref-, book-, tmp-; every completed runtime update bumps the patch version; the 2026-11-16 user instruction changes all projects to stable numeric versions without alpha/beta suffixes; run `python3 tools/check.py </dev/null`, then `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'` (preview, then `--apply`), then verify the installed bytes; never close or restart the game; commit and push on the branch only; no release, tag or merge to main without approval; every add-on text is English for now.
- Version bump in TG3: replace the old version in README.md, tools/generate_catalog.py, every TitanGatheredForeverV3*/*.toc and the release note file name, run `python3 tools/generate_catalog.py`, update release-notes/ref-unreleased.md, ref-wow-forever-progress.md and the pull request description (gh pr edit 3 with a body file in the scratchpad).
- Reply language: the user writes Czech and sometimes English; answer in the language of the last message.
- Read first: README.md, release-notes/ref-unreleased.md (newest on top), ref-wow-forever-progress.md (last sections), this plan.

## 2. What exists (0.5.53-beta)

- One tabbed window (minimap button): Unlearned recipes, Trainers, Lifetime materials, Observed chances, Profession actions, Crafting and cooking, Crafting profit, Reagent use, PvP Board. Classic panel tabs, scroll bars, search, combo boxes, shared saved position. Reagent window (/tgf recipe, the Reagents button in the profession window header, a Reagents entry in the recipe right-click menu), export window and icon window. All windows are opaque and remember their position; the profession window and the auction house window of the client can be moved too.
- Trainer and recipe vendor pins from a Classic seed plus live observation, tooltips with learned status, rank rows, trainers list with visited status.
- Auction scan (button below the auction house window): prices of reagents and products of the installed professions, tooltips, reagent window columns, crafting profit list with thin-market handling.
- Modular data: every profession addon carries the recipe book of its profession; the core works with installed and switched-on professions only.
- Titan Command History: persistent history of commands and chat lines, arrow keys, window with tabs Commands, Conversations and Favorites, favorites, Titan plugin and minimap button, saved window position.

## 3. Live verification checklist

Do these in the game after a full restart (new files exist in 0.5.36, 0.5.37, 0.5.44 and 0.5.46; /reload alone is enough for later Lua-only changes). Turn on `/console scriptErrors 1` first and report any Lua error with its text. Each item names the evidence to bring back. "Log" means a key in the saved variables that I read after a /reload.

### 3.1 Start and shell

- [ ] Folder migration 0.5.84: restart WoW fully; confirm that only TitanGatheredForever and its thirteen named modules appear, old folders are absent, earlier statistics/settings remain present and previously disabled addons stay disabled. The original saved table key and exported namespace alias remain compatible. The installer migrates saved filenames and enablement with retained originals while the game is closed. Artwork now lives in each project's artwork/v1/ directory, outside runtime.

- [ ] Stable-name update 0.5.83: after a full restart, verify the official Titan Gathered Forever title in the AddOns list, Titan Panel, minimap hover and report windows. Verify the preserved history/settings and the Map spots button. The 2026-11-16 user request supersedes earlier instructions to retain beta/alpha suffixes; current project versions are stable numeric versions.
- [ ] Artwork update 0.5.82-beta: after a full client restart, verify the core, twelve professions and Auction Items display distinct icons in the AddOns list, including disabled modules. Check the core emblem on Titan Panel and the minimap at normal UI scale. Source metadata and packaged TGA bytes are verified automatically; actual client rendering remains unconfirmed.
- [ ] No Lua error at login or when opening any window (the console shows the stack; send it).
- [ ] The first window opened after a game start has full width tabs (fixed in 0.5.33, confirmed once). Repeat after a restart: nine tabs along the bottom, none cut. Evidence: screenshot.
- [ ] A window moved by dragging opens at the same place after /reload and after a restart (tabbed window, reagent window, export window, icon window). Titan menu > Display > Reset window positions puts them in the middle.
- [ ] Windows are opaque, a click raises a window, the reagent window opens above the tabbed window. Look at the frame edge and the title bar against the dark layer (0.5.45, unverified there).
- [ ] The first opening of the tabbed window after a restart is not slow (0.5.28 coalesced the redraw after item answers). If it is slow, note how many seconds and which tab.

### 3.2 Trainers

- [ ] Open a trainer of a profession you know (Engineering, Mining, Fishing) and one you have no skills left to learn from (Bronk Guzzlegear): both are recorded (npcLog result saved, filters-on only for an empty update) and the "Already known" filter of the trainer window is back to off afterwards (0.5.19 to 0.5.26).
- [ ] The tooltip of a visited trainer says Confirmed in game; the Trainers tab lists unvisited and visited trainers with zone, coordinates and status; hover shows what the trainer teaches; a click opens the map at the trainer with a red ring; a second click clears it (0.5.27).
- [ ] The converted coordinates of an unvisited seed trainer are close to the real place (compare one or two). If they are mirrored, Titan menu > Trainers and recipe vendors > Pin placement > Swap map axes.
- [ ] A trainer of a profession whose addon is not installed is not recorded (npcLog not-installed) and has no pin (0.5.53).

### 3.3 Recipe vendors, recipes and learned status

- [ ] Open a vendor that sells recipes: npcLog shows saved with recipes=N (and goods=N when it sells profession reagents). Prices and required skills are read from the merchant tooltip (open since the first beta).
- [ ] The Unlearned recipes tab lists recipes with Trainer or Vendor source, red when the skill is too low, profession and source filters, search; a click opens the map at the first source with red rings on all sources; the rings end when the world map closes.
- [ ] Trainer and vendor tooltips dim and tag learned recipes, and say when the profession was never read (open the profession window once). Rank rows (Journeyman Fishing and so on) follow skill and character level.
- [ ] Recipe names match between the Classic seed and the client names (recipes that never match show as unlearned although known). Note any recipe that is wrong.

### 3.4 Reagent window, Reagents button, recipe menu

- [ ] The Reagents button is in the header of the profession window (left of the close button), shows only on the recipes page, a second click closes the reagent window, a click with another recipe selected switches it (0.5.47, 0.5.48). If it is missing, read professionLog (attached and placed lines).
- [ ] A right click on a learned recipe has an entry Reagents that opens that recipe (0.5.38, never confirmed).
- [ ] The reagent window: plus, minus and the number box change the crafts, Shift adds five; colors green, yellow, red; the bank column is a dash when Display > Show bank counts is off; click on a reagent opens the source menu with recipe names, the auction line and the vendor price; hover shows the item; the window is as tall as its list.
- [ ] The three product lines (what it makes and where it sells better, the prices, the profit per craft) match your own arithmetic for two or three recipes, including one that makes more than one item.
- [ ] The last column: a merchant when it is the cheapest known way to buy, otherwise an observed source, otherwise "Buy at the auction house", otherwise "No recorded source".

### 3.5 Auction scan and prices

- [ ] The Scan prices button and the progress bar appear below the auction house window; the bar shows waiting and then reading with a percentage; the chat shows the answer, every quarter of a long list and the result (0.5.37 to 0.5.41, buttons seen once).
- [ ] Sales ledger (0.5.122, log 0.5.123): sell items, open the mailbox, then /reload; read the saved variables `sales.entries` and `mailLog` (subject text, stack size, invoice values before and after opening the mail, received money against buyout minus fee plus deposit).
- [ ] auctionLog after a scan: requested, the throttled message events, update-ignored once, done with entries, items, distinct and seconds. Compare seconds with the 7.2 s of the second scan (287,853 auctions).
- [ ] The saved block `auction` is smaller than the 139 KB of the full item list because only reagents and products of the installed professions are kept (0.5.53). Note the size before and after.
- [ ] Item tooltips of reagents and products show Auction, Worth, Vendor pays and the age of the scan; no price line for other items; Titan menu > Auction prices > Show auction prices in item tooltips switches it off.
- [ ] The cooldown message appears when a scan is asked for within 15 minutes; the automatic scan on opening (off by default) works and respects 30 minutes.

### 3.5a Buyout undercut in the Sell tab (0.5.97)

- [x] Commodity form (Clam Meat, item 5503), checked live 2026-11-17 from the saved variables: choosing the item fills the Unit Price with the lowest foreign unit price minus the percentage (25 copper at 2, 5, 10 and 15 percent gave 24, 23, 22 and 21; 28 copper at 5 percent gave 26); the combo box and the custom field work, a changed percentage prices the item again, and the value read back 0.4 s later equals the fill, so the client does not overwrite it.
- [x] A percentage below the vendor price (80 percent of 28 copper, vendor 16) sets the vendor price, 16 copper, with the red line above the strip.
- [x] The strip sits in the row above the Buyout Mode check box and does not cover other controls (confirmed by the user).
- [x] Form of single items (Stiletto), checked live 2026-11-18 with a step trace (0.5.99, removed in 0.5.100): ITEM_SEARCH_RESULTS_UPDATED arrives, the answer is used and the Buyout goes into PriceInput with Buyout Mode on (confirmed on screen: 2 percent under 5 silver gave 4 silver 90 copper in Buyout Price). Still open: Buyout Mode off (the code then uses SecondaryPriceInput when it is shown).
- [x] Deposit readings (auctionDepositLog, 0.5.98), 2026-11-18: the deposit is for the whole auction, vendor price times quantity times 2.5 percent per hour, in whole copper, and does not depend on the price. Duration 1 is "2 Hours" on the form (the ratios 1:4:12 make 2, 8 and 24 hours). Still open: whether the fee is 5 percent, whether the deposit is lost when an auction expires and returned on a sale.
- [x] Posting lines (0.5.101 to 0.5.106), checked live 2026-11-18: "Sold" (sale after the fee and gain against a vendor) and "Unsold" (deposit and the share of auctions that must sell) follow the quantity, duration and price; the values match a hand calculation on both forms (Stiletto, Linen Cloth). Positions: above the strip on the single-item form, below it on the commodity form, whose Create Auction button sits low; the final commodity position was marked by the user on a screenshot and confirmed (0.5.106). The fill floor counts the fee (Economy.MinPrice).
- [x] Profit against the cost (0.5.107), checked live 2026-11-18 on Linen Cloth (4 units at 30 copper, a screenshot of the Sell tab): "Sold: 1s 14c net, +30 vs cost, +62 vs vendor" and "Unsold: -2 deposit, pays off if 4% sell"; the figures match a hand calculation (net 114, vendor 52, cost 21 per unit from the last scan).
- [ ] A dearer item (gold and silver in the prices) still fits the width of the left panel with the three figures of the "Sold" line; if it runs into the list pane, shorten the line or wrap it.
- [ ] An item with only the player's own auctions, and an item with no auction at all: nothing is set and the chat says so.
- [ ] The Titan menu check box (Auction prices > Fill Buyout in the Sell tab) stops the fill; the setting stays after /reload.
- What went wrong on the way, to avoid repeating it: the client had no global GetItemInfo (use C_Item through ns.Economy.VendorSell); IsThrottledMessageSystemReady was false right after an item was chosen, so the add-on waits for the answer of the client's own search; SetOnValueChangedCallback would replace the callback of the client (HookScript on the money boxes is used); the Create Auction button moves between the two Sell forms, so the strip is anchored to the window, not to a form.

### 3.5b Market history in Sell (0.5.125)

- [x] The owner confirmed that the 0.5.125 layout and feature work in the client after the toggle and bottom panel were moved from their 0.5.124 positions.
- [ ] Select a material and a single item in Sell. Check the left panel, coin amounts, the Hide history and Show history controls, and the transition when the native form clears the previous selection. The panel and toggle disappear with an empty slot, outside Sell, and when the window closes.
- [ ] Drag the auction window toward and away from the screen's left edge. Confirm the panel docks with room, opens on request as an overlay without room, and can always be collapsed.
- [ ] Compare the latest price and date with an existing scan. After completing scans on distinct days, check the plotted values and change. Open a mailbox containing a confirmed sale and compare quantities and available invoice prices with the panel.
- [ ] On 0.5.126, open a completed auction mail with its funds still attached and then choose the same item in Sell. Compare gross, fee, deposit and net with the invoice. Change the unit buyout and check the two Current listing comparisons. There were no completed mail entries in the saved variables before this candidate.

### 3.6 Crafting profit and the recipe harvest

- [ ] Open every profession window once: no frame stall (40 recipes per frame, 0.5.51) even for Leatherworking and Tailoring; note the delay if any.
- [ ] The Crafting profit tab, My recipes: lists exactly the recipes you know (by recipe ID), with the number made in the name when it is not one; the footer names professions that were never read and says how many recipes were added from your profession windows (recipeExtra). Report that count for each profession: it measures how incomplete the mirror table is.
- [ ] 3+ auctions hides thin markets, All markets shows them, the orange Auctions numbers and the hidden count agree; the Vendor pays and Sells better to columns are right for items a vendor buys (the client reports no price for some items, for example ammunition).
- [ ] A click on a row opens the reagent window of the recipe.

### 3.7 Modular installation

- [ ] Move all profession addons except Engineering out of AddOns, restart: the profit tab, trainers list, unlearned recipes list and the profession filters list Engineering only; no Lua error. Repeat with no profession addon at all: the tabs open and say there is nothing to list.
- [ ] Switch a profession off in Titan menu > Professions: its recipes, pins and prices disappear without a reload.
- [ ] After a scan with one profession addon the saved auction block holds that profession only.

### 3.8 Movable client windows

- [ ] The profession window and the auction house window drag by an empty place, keep the position after closing and opening, after /reload and a restart, and the client does not undo it when another panel opens. Titan menu > Display > Let me move the profession and auction house windows switches it off.

### 3.9 Older features that still lack live acceptance

From plans/plan-next-development.md and the older plans: profession actions (event order of fishing and disenchanting, cancellations), crafting and cooking production (single and queued crafts, recrafts), statistics export (clipboard, scrolling, a full round trip), flight points (native styling, discovery tracking), the PvP Board (client totals, rank, honor events, death recap, outdoor kill spots), the red ring and gold outline options of pins, the minimap button look. Test each once and note what differs from the description in its plan.

### 3.10 Titan Command History

Details in that repository's plans/plan-command-history.md. In short: arrow keys walk the history after a /reload; a mistyped command and a line followed by an error are not recorded; /reload, /logout and /quit are; conversation lines are recorded when enabled; favorites run from the window and from the menu; the history window and the minimap button keep their position; the Titan text shows the count after a reload.

### 3.10a Discovery module (0.1.0, standalone)

The checklist is in book-wow-forever-validation.md ("Validate the Discovery module"). Open live gates: the look of the progress window, overview window and Titan Panel plugin; the client calls behind the recipe, map, quest, trainer and zone collectors; the lag and runtime of `/tgfd compare`, the scans, the privacy check and the checksums on a large saved table; that the saved file carries the export stamp after /reload; that a client recipe ID equals the catalogue spell ID. Record the results in ref-wow-forever-progress.md separately from the automated checks.

### 3.10b Kills, Quests and Journal tabs (0.5.165 and 0.5.166)

- [ ] Kill a creature solo: the Kills tab shows it under Your kills with name, level, type and zone; with a pet landing the blow it is also yours; in a party a member's killing blow is a group kill.
- [ ] One kill followed by an experience gain fills XP per kill; a pull of two or more leaves it Unknown; a quest turn-in is never counted as kill experience.
- [ ] Kills in a dungeon: check whether PARTY_KILL GUIDs are secret there (counted as hidden in the footer) or readable.
- [ ] Accept, turn in and abandon a quest: status, time taken, zone, experience and money; abandoning shows Abandoned or failed.
- [ ] Quest names of older quests load after the list opens (QUEST_DATA_LOAD_RESULT redraws the list).
- [ ] Quest pins (0.5.172): the silver question mark disappears when the objectives are done, leaving only the game's own turn-in mark.
- [ ] Quest pins (0.5.168): no yellow exclamation mark from the addon on the map or minimap; a silver question mark with a drop shadow (0.5.171) only at givers of quests in the log, gone after the turn-in or abandon.
- [ ] Quests ready to turn in (0.5.189): finish the objectives of a quest, the row turns to Ready to turn in with the yellow question mark without reopening the window; the filter choice lists it; the marks are not cut.
- [ ] Divider on every list tab (0.5.188, accepted on My materials in 0.5.187): the line sits between headers and rows on Unlearned recipes, Trainers, Lifetime materials, Observed chances, Crafting profit, PvP Board and Journal; the last rows clear the footers.
- [ ] Item and profession icons (0.5.179, 0.5.180): every list shows icons before the names (Statistics Attempts included), trainers and profession columns show profession icons, every profession icon exists on Forever, rows stay aligned and long names are cut cleanly; Unlearned recipes shows recipe or spell icons.
- [ ] My materials tab (0.5.178): first tab, counts match bags and bank, scope and group combo boxes, search, sort, item tooltip, Learned professions view, the tab strip with nine tabs fits; the minimap hover shows only the help.
- [x] Without Titan Panel (0.5.177, checked by the owner on 2026-11-28 with and without Titan): all fifteen addons load; right click menu, world map button and Options work; the General page note matches. With Titan enabled the panel entry and its list work as before. Discovery 0.1.6 loads without Titan.
- [x] Options text size (0.5.177, accepted by the owner on 2026-11-28): smaller text is still readable, labels do not overlap the check boxes, buttons fit their text.
- [ ] Options > AddOns > Titan Gathered (0.5.174, 0.5.175): the icon stands before the name; the category and its nine pages are listed, rows fit the canvas and scroll, switches and combo boxes change the same settings as the Titan menu, the window buttons close Options and open the window. Backup: the folder box shows the real account folder (GetCVar accountList) and the path opens in Finder or File Explorer; Export settings fills the box and selects it, copy and paste work, Import settings on another character applies after Reload interface.
- [ ] Statistics > Materials (0.5.173): leading profession and share columns, the search box beside the pickers stays inside the panel (fixed in 0.5.181 after it ran over the profession buttons) and does not overlap the Back button, Reagent use estimates in the Titan menu opens it.
- [ ] The tabs (eight since 0.5.173) fit along the bottom of the window (0.5.167 merged Kills and Quests into the Journal tab); at a low resolution or a large UI scale the window and tabs are scaled down and stay on screen; the sort arrow sits after the header text.
- [ ] Loot (0.5.166): a looted corpse adds money per loot and Drops rows; pickpocketing and skinning add nothing there.
- [ ] A rare creature on the nameplates or as target appears in Rare creatures and as a pin; a click opens the map with the rings.
- [ ] Accepting a quest from an NPC records the giver pin; the turn-in records the turn-in NPC and the chosen reward (GetQuestReward hook).
- [ ] Journal: a level up records the reached date and the played time; a death records the killer from C_DeathRecap; a reputation gain appears under Reputation, also for a faction under a collapsed header.

### 3.11 Boat and zeppelin routes (0.5.69-beta, in progress)

State: Transport.lua draws thin dashed arcs between docks, with anchor markers (Artwork/RouteAnchor.tga), for every player. Menu: Boat and zeppelin routes (Show routes on the map; Line style with Thickness Thin or Clear and Pattern Dashed, Dotted or Solid). Dock positions come from /tgf dock <name> (recorded, always wins) or are estimated from the flight point of the same town (Menethil Harbor, Southshore, Theramore, Feathermoon, Orgrimmar, Undercity, Grom'gol, Ratchet, Booty Bay). Recorded so far: Stormwind Harbour, Auberdine, Rut'theran Village.

Open steps, in order:

1. Done in 0.5.69-beta and accepted by the user: docks use the original icons Islands-AllianceBoat (boats) and Vehicle-Air-Horde (zeppelin towers), with the tinted anchor for neutral boats and as a fallback; the Dock icon submenu switches between them. The atlas search results are in ns.db.atlasSearch of the saved variables (alternatives found: Vehicle-Air-Alliance, FlightMaster_Ferry-TaxiNode_Alliance, poi-lighthouse-neutral).
2. Record the docks that have no estimate: /tgf dock Forgotten Coast, Steamwheedle Port, Powderfuse Port. Check the estimated docks by eye on the world map and re-record any that sit wrong (/tgf dock lists recorded, estimated and missing docks).
3. Ship the recorded docks as built-in data: read ns.db.docks from the saved variables and add it as seed positions in Transport.lua (a recorded position still wins).
4. Optional: a separate marker for zeppelin towers.
5. Remove the diagnostics that served their purpose: /tgf transport (area point probe) and /tgf atlas.

## 4. Optimization and open work, in order

1. Split the trainer and vendor seed over the profession addons (Data/NpcSeed.lua is 190 KB in the core and is only filtered when used). Needs the pinned classic-db dump (catalogue/npc-seed-source.json, not in the repository, not downloaded by builds): extend tools/generate_npc_seed.py to write one shard per profession, load shards through the module registration like the books, keep the header check. Vendors of several professions repeat their position in each shard.
2. Thin markets for materials: the profit list checks the product only; a reagent priced by one auction can still distort the cost. Add a flag per reagent (in the reagent window and the profit tooltip) and an option to hide such recipes.
3. Targeted price refresh for the reagents and the product of one recipe with C_AuctionHouse.SendSearchQuery (100 calls a minute, no 15 minute cooldown); needs the commodity search events and a live check of their shape. Keep the full scan for the bulk list.
4. Measure and, if needed, reduce cost: the profit list recomputes about 2,000 recipes on every refresh (9 ms on a desktop, unmeasured in the client); Crafting.Harvest frame cost; the first opening of a window; the auction read at 6 ms per frame (raise the budget only with a hitch warning); the memory of the auction price table.
5. Show the age of a price in the profit list and warn when the scan is older than a day; keep the last two scans to show a trend.
6. Vendor sell prices are read from the item info and are unknown for items the client has not loaded; request the item data for the visible rows only and refresh once.
7. Extend the movable client windows to the trainer, merchant and bank windows only if the first two work without interfering with the client layout.
8. Remove diagnostics that served their purpose once confirmed: professionLog, auctionLog event lines, the Titan menu entries that only print logs; keep one bounded diagnostic log per feature.
9. Command History ideas: a multi line editor for long macros copied out in 255 character lines, export of the history, sorting by use count, an option to keep the history per character with a separate favorites list.
10. Catalogue evidence: the recipe table is a mirror of client tables and not complete (completeness false); use the counts from section 3.6 and the output-free enchantments to decide what to supplement.

## 5. Release readiness (on hold by the user)

When the user approves: rebuild dist/releases with `python3 tools/package.py`, update release-notes/ref-<version>.md (the newest is ref-0.5.53-beta.md, written for the website), merge pull request 2 then pull request 3 to main, tag v<version>, confirm the release workflow, and update the pull request description if it still describes older behavior. Do not publish assets or tags before that.

## 6. Pitfalls found in this work (avoid repeating them)

- In Lua `a and f()` returns only the first value of f: reading `local price, at = x and x.Price()` loses `at`. Write `if x then price, at = x.Price() end`.
- A new frame is already shown, so its first Show() fires no OnShow; a new tab text has a fixed width that makes GetStringWidth report the cut text (set the width to 0 before measuring). A button that was a child of a hidden or clipped frame never shows: make it a child of the screen.
- The client sends TRAINER_UPDATE from inside SetTrainerServiceTypeFilter (and wants a boolean, not 1 or 0): guard against recursion and restore filters from a table that was cleared first.
- Saved variables reach the disk only on /reload or logout: ask for a /reload before reading a log.
- Test stubs for frames are strict in some suites and permissive in others (use rawget on the permissive ones); LuaJIT has `unpack`, not `table.unpack`.
- A diagnostic log must not hold conversation text (Command History) and must be bounded.
