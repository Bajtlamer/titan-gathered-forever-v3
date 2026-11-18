# Unreleased development updates

Updated 2026-11-16. These changes describe the 0.5.102 source candidate and its versioned update. They have not been assigned a new release tag or published as replacement release assets. Historical versioned notes describe their original releases.

## Posting lines moved up, 0.5.102

- The two posting lines sit 10 pixels higher above the undercut strip, as the user asked after seeing them live (no overlap with the Create Auction button on the single-item form).

## Posting profit lines and a floor after the fee, 0.5.101

- Two lines above the undercut strip show the auction as it stands (price, quantity, duration, deposit as the client has them): "Sold" with the sale after the 5 percent fee and the gain or loss against a vendor, and "Unsold" with the deposit that an expired auction costs and the share of auctions that must sell for posting to pay (deposit divided by gain plus deposit); a sale that does not beat a vendor says so in red. They follow every change of the quantity, duration and price. The fee rate (assumed 5 percent) and the loss of the deposit on expiry are not yet confirmed with a real sale.
- The floor of the fill is now the lowest price whose sale after the fee still brings what a vendor pays (Economy.MinPrice), not the vendor price itself, which would have been a loss against selling to a vendor. The red line says "Below the vendor price after the fee".

## Trace removed, single-item form confirmed, 0.5.100

- The trace of 0.5.99 is removed (and its saved rows are cleared). It showed that the form of single items is filled: the search event arrives, the answer is used and the Buyout goes into PriceInput. Confirmed on screen with Buyout Mode on (Stiletto, 2 percent under a lowest buyout of 5 silver gave 4 silver 90 copper in Buyout Price). The earlier note that this form was not filled was wrong: the items tried then had no other auction. Buyout Mode off (SecondaryPriceInput) is not yet checked.
- Deposit, from the readings of 0.5.98 and the Deposit line of the form: for the whole auction, vendor price times quantity times 2.5 percent per hour, whole copper, independent of the price. Duration 1 is 2 hours on the form (3 and 2 follow as 24 and 8 hours from the ratios).

## Temporary trace for the single-item form, 0.5.99

- The saved deposit readings (0.5.98) showed that the Buyout was never filled on the form of single items: all fills in auctionUndercutLog are from the commodity form. A step trace (auctionUndercutTrace, last 60 steps: selection, search, search events, results, input used) is added to find the cause and will be removed again. The deposit readings also show that the deposit is for the whole auction, follows vendor price times quantity times 2.5 percent per hour (durations 1, 2, 3 are 2, 8 and 24 hours) and does not depend on the price.

## Posting cost: calculation and deposit evidence, 0.5.98

- Economy.Posting works out what one auction brings: the sale after the fee, what an unsold auction costs (the deposit, the item stays with the player), the gain against a vendor and the share of auctions that must sell for posting to pay. Economy.MinPrice gives the lowest price per unit that still beats a vendor after the fee. Nothing is shown in the Sell tab yet.
- The deposit that the client asks is read from the Sell forms (GetDepositAmount) on every update and logged in auctionDepositLog (last 30 readings: deposit, duration, quantity, prices, vendor price). It tells whether the deposit is for one unit or for the whole auction and how it follows the duration; the display and the fix of the vendor floor of the undercut (the fee is not yet counted there) follow once these readings are checked live.

## Undercut debugging trace removed, 0.5.97

- The step trace (auctionUndercutTrace) that found the failures of the first live tests is removed; the fills stay in auctionUndercutLog. Live checked on the commodity form (Clam Meat): fill, combo box, custom value, recalculation after a change and the vendor price floor. The form of single items (Buyout Mode, SecondaryPriceInput) is not yet checked live.

## Undercut sets the vendor price when the percentage is too high, 0.5.96

- A percentage that would put the Buyout below what a vendor pays (for example 80 percent of 25 copper) left the old price in place, which looked like a value that was not recalculated. The Buyout is now set to the vendor price, a red line above the strip says so (with the price in coins), and the line is cleared at the next fill. The chat gets the same message.

## Undercut strip moved up and left, 0.5.95

- The strip is in the row above the Buyout Mode check box and starts further left, so the label, the combo box and the custom value field all fit in the left panel.

## Undercut follows the percentage, 0.5.94

- Changing the percentage in the combo box, or confirming another custom value, prices the selected item again from the last search answer, also over a price typed before. No new search is sent.

## Undercut vendor price fix, 0.5.93

- The vendor price check called the global GetItemInfo, which this client does not have (Lua error at the first answer), so no price was filled. It now uses Economy.VendorSell (C_Item.GetItemInfo), and an error while reading the vendor price can no longer stop the fill.

## Undercut trace of the answer, 0.5.92

- The answer of the client now arrives (52 auctions) but no price was filled. The trace keeps the lowest price, the vendor price and the field names of the first result to find the step that stops the fill.

## Undercut waits for the answer of the client, 0.5.91

- The trace showed that the client reported its message queue as not ready right after an item was chosen, so the fill gave up while the client's own search answered a moment later. A busy queue no longer cancels the fill: no search of our own is sent and the client's answer is used. The price is checked 0.4 s after the fill and put back if the client wrote its own default price over it (the log keeps the value read back and a reapplied flag).

## Undercut trace, 0.5.90

- The first live test did not fill the price and the log stayed empty. The steps of the fill (item selected, search sent, answer received, reason for skipping) are now kept in the saved variables (auctionUndercutTrace, last 40) to find the cause.

## Undercut strip in a fixed row, 0.5.89

- The Create Auction button moves between the Sell forms, so the strip overlapped it. The strip is now in the bottom row of the left panel, right of the Buyout Mode check box, with the shorter label Undercut.

## Undercut strip clear of Buyout Mode, 0.5.88

- The strip overlapped the Buyout Mode check box of the single-item Sell form. It is now higher, in the free place between the Create Auction button and that check box.

## Undercut strip moved into the Sell form, 0.5.87

- The strip with the percentage combo box was below the window of the auction house, where the Buy, Sell and Auctions tabs covered it. It is now in the free place of the left panel under the Create Auction button and is shown only while a Sell form is shown.

## Automatic Buyout undercut in the Sell tab, 0.5.86

- New core file AuctionUndercut.lua (needs a full client restart). Choosing an item in the Sell tab starts a live search; the Buyout is filled with the lowest foreign buyout minus a percentage. A combo box under the auction house window offers 2, 5, 10 and 15 percent and Custom with a text field (0.1 to 90). Own auctions are ignored, the price never goes below the vendor price, and a typed price is left alone. A Titan menu check box switches it off. Fills are logged in auctionUndercutLog.
- Not yet confirmed in the game: which input holds the Buyout in the form of single items (the log records the input used), and the placement of the strip. Live results go to ref-wow-forever-progress.md.

## Auction Sell tab probe, 0.5.85

- The names of the Sell frames were read from the client with a probe (auctionProbe, now removed): CommoditiesSellFrame and ItemSellFrame with SetItem and PriceInput, and the C_AuctionHouse search functions all exist.

## Matching folders and project artwork, 0.5.84

- Runtime folders/manifests and dependencies use TitanGatheredForever and TitanGatheredForever_*; texture paths, addon metadata lookups, generated publishers, packages and tests follow those names. The development directory is titan-gathered-forever. The previous exported namespace remains an alias and the saved table key remains TitanGatheredForeverV3DB.
- The installer backs up and removes old runtime folders, copies previous account/character saved files to the new filenames without executing or changing their contents, and migrates addon enablement. It refuses conflicting saved state, requires a closed client for the real migration and rolls back runtime and state writes together on failure. Original saved files are retained.
- All five projects have their own versioned artwork/ directory in their development root. Gathered's artwork/v1/ contains all fourteen of its addon designs; the other projects each keep their own design. PNG masters, 1024px logos, 400px avatars and 64px icons are preserved byte-for-byte and excluded from runtime ZIPs. Old artwork is retained in the source migration backup.
- Development directories are titan-gathered-forever, titan-command-history, titan-approx-dps, target-ranger and wow-forever-scout. Scout gains a separate WoWForeverScout/ runtime folder and matching manifest, with its own saved-file migration in 0.1.2. No remote repositories, releases or CurseForge projects are renamed or published.

## Official name and stable version, 0.5.83

- The public product name is Titan Gathered Forever: manifests, Titan Panel, tooltips, status messages and window titles no longer display TG3 or TGF v3. The compact map button says Map spots. Internal folder names, dependencies, namespaces and SavedVariables remain compatible.
- The user requested stable numeric versions for every addon. All fourteen Gathered manifests now use 0.5.83 without a beta suffix. Historical release notes and evidence retain their original version designations.
- The complete artwork collection now covers all five local projects and eighteen addon emblems: Gathered's fourteen, Command History, Approx DPS, Target Ranger and WoWFScout. The three previously omitted projects have their own large PNG logos, 400px avatars, 64px previews and game textures. No website or CurseForge publication is implied.

## Original addon artwork, 0.5.82-beta

- A coordinated original fantasy emblem for the core, twelve profession modules and Auction Items. Every manifest declares its own IconTexture; each standalone download includes its own 64px uncompressed 32-bit TGA. The core's Titan and minimap buttons use the new core emblem.
- Large artwork, 1024px PNG logos, 400px avatars and 64px PNG previews are kept outside runtime under branding/v1. Includes a companion Titan Command History design and the generation prompts. No CurseForge upload or website deployment is performed.
- Forever's AddonList.lua reads IconTexture and otherwise uses the question mark. Source evidence: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AddOnList/AddonList.lua (inspected 2026-11-16). Actual rendering and small-size clarity remain live checks after a full client restart.

## More room before the gathered list, 0.5.81-beta

- The gap between the profession title with its two summary lines and the list of items is 18 pixels (it was 8).

## Normal row spacing in the gathered list, 0.5.80-beta

- Since one profession is shown per page, the items of the gathered views are back to the normal row spacing of the other lists. Only the title and the summary lines keep their tighter layout.

## One gathering profession at a time, 0.5.79-beta

- The gathered views of the Profession actions window show one profession per page. The profession box lists only the installed and switched on gathering professions (no All professions entry there), starts with the first one, and falls back to the first one when the chosen profession is switched off or gone. The Actions summary view keeps All professions.
- A player without any gathering profession gets the message No gathering profession (Mining, Herbalism, Skinning, Fishing) is installed or switched on instead of an empty page, and a test opens every report with no profession addon installed.

## Green dates and a gap before the item list, 0.5.78-beta

- Every date and time of day is green (Style.Date), so it stands out from the gold labels and the white values: Measured since, Recording began, First recorded, the PvP and reagent coverage dates, Bank observed, Last seen on the map, Visited and Confirmed in game (the status words are gold now, only the date is green).
- A small gap separates the two summary lines of a gathering profession from its list of items.

## Summary lines use the full width, 0.5.77-beta

- The two summary lines of each gathering profession run across the whole width of the window instead of the first column, so the Measured since date no longer wraps to a new line.

## One text and price style, 0.5.76-beta

- Informational text is small and gold in every window (notes, footers, empty messages, range lines, the Crafting window note and scope line, the export texts) and the data in it is white, so a label and its value are told apart: Completed: 100, Items collected: 105, Showing 1-18 of 40, Counting: bags, the profit footer counts and the browser footers.
- Every price is in the game money format with gold, silver and copper icons: the gathered views and their summary lines, the profit and recipe windows, the reagent window, the vendor each line of the tooltips (the trainers and the recipe browser used plain 1g 2s text before). Style.Label, Style.Value and Style.Range are the helpers; tests/style_stub.lua gives the test stubs the same text.
- The rule is written in AGENTS.md so new windows follow it from the start.

## Space between professions, 0.5.75-beta

- In place of the removed line, a blank row of 26 pixels separates one profession of the gathered views from the next.

## No separator line, 0.5.74-beta

- The gold line above each profession title is removed (it looked odd). The large gold title stays, and the rows go back to the normal text when the view is switched away from the gathered lists.

## Profession sections, 0.5.73-beta

- Each profession in the gathered views starts with a large gold title and, from the second profession on, a thin gold line above it, so the end of one list and the start of the next is clear at a glance. The summary lines follow the title in the normal text.

## Denser gathered lists, 0.5.72-beta

- The gathered views of the Profession actions window use tighter rows (2 pixels of padding instead of 6, 4 for the summary lines), so more items fit under each other.

## Gathering yield and value, 0.5.71-beta

- The Profession actions window has a view box with three views: Actions summary (as before), Gathered, most items and Gathered, most valuable. The gathered views list for each installed gathering profession (Mining, Herbalism, Skinning, Fishing, Disenchanting) two summary lines and its 40 most collected items (the most caught fish for Fishing) with the quantity, the share, the unit value, the total value and where it sells best.
- The value of an item is the better of the vendor price and the lowest auction buyout of the last scan after the fee; an item without a known price is shown as No price and counted in the summary, never guessed. The summary line gives the collected items, their worth and the number of unpriced items.
- Value per hour: the addon now measures the active gathering time per profession (the gaps of at most 2 minutes between attempts) and counts the items obtained in that same time, so the rate (money and items per hour) divides two things measured over the same period. It needs at least 5 minutes of measured time and starts from this version on; older gathering has items but no time, so it is listed without a rate.
- New file Yields.lua (full client restart needed), Economy.Sale for the best sale of one item, Actions.Yield and the per profession fields active, timedBegan and timedItems in the saved actions.

## Reports follow the installed professions, 0.5.70-beta

- Lifetime materials, Observed chances and Crafting and cooking (and Profession actions) now leave out the data of a profession whose addon is not installed or that is switched off in the Titan menu, the same way the map, the unlearned recipes, the trainers and the crafting profit already did. Items obtained or crafted only through such a profession are hidden, items that other sources or installed professions also provide stay. The profession filters list only the installed professions. Nothing is deleted: switching the profession on shows its data again.

## Game icons for the docks, 0.5.69-beta

- Docks use original game icons found with the atlas search: Islands-AllianceBoat for boats and Vehicle-Air-Horde for zeppelin towers, each only when the client has the atlas, drawn over a dark silhouette for contrast. Neutral boat docks and any dock without a usable atlas keep the tinted anchor. The Dock icon submenu under Boat and zeppelin routes switches between Game icons (default) and Anchor. No new file, a /reload is enough.

## Atlas search saved to a file, 0.5.68-beta

- /tgf atlas <word> now saves every matching atlas name (up to 1500 per word) in the saved variables instead of printing the first 40 in chat, so the list can be read from the file after /reload.

## Atlas search, 0.5.67-beta

- New diagnostic command /tgf atlas <word> lists the Blizzard icon atlas names that contain a word (for example ship or zeppelin), so the dock marker can use an original game icon whose name is confirmed in the client. Nothing else changed.

## Anchor dock markers, 0.5.66-beta

- Docks and towers on the map are marked with a small anchor instead of a dot. It is a new white artwork file (Artwork/RouteAnchor.tga, generated by tools/generate_pin_outlines.py), tinted in the route color and drawn over a dark shadow copy of itself so it stays readable on the parchment. The package and installer include it. New file, so a full game restart is needed.

## Own menu for the sea routes, 0.5.65-beta

- The boat and zeppelin settings have their own Titan menu entry, Boat and zeppelin routes (Show routes on the map, and a Line style submenu with Thickness and Pattern). The Flight points menu keeps only its own switch again.

## Lines submenu, 0.5.64-beta

- The route line choices moved into a Lines submenu under Flight points, in two groups: Thickness (Thin, Clear) and Pattern (Dashed, Dotted, Solid). Flight points itself keeps the two visibility switches.

## Line style choices kept, 0.5.63-beta

- The line style choices stay in the Flight points menu: thickness thin or clear, pattern dashed, dotted or solid. The defaults are thin and dashed, which looked best in testing. This restores the choices that 0.5.62-beta had removed.

## Dotted route lines, 0.5.61-beta

- Route lines have three patterns in the Flight points menu: dashed (default), dotted (small round-looking dots) and solid. They replace the single solid switch of 0.5.60-beta; the earlier choice is carried over.

## Solid route lines, 0.5.60-beta

- The Flight points menu has a new switch, Route lines: solid instead of dashed. It draws each route as one continuous curved line. Dashed stays the default.

## Estimated dock positions, 0.5.59-beta

- A dock that has not been recorded with /tgf dock now gets an estimated position from the flight point of the same town (Menethil Harbor, Southshore, Theramore, Feathermoon, Orgrimmar, Undercity, Grom'gol, Ratchet and Booty Bay), which the client reports and which stands near the harbor or tower. Estimated docks are drawn on the continent and world maps, their tooltip says Estimated position, and /tgf dock lists them as estimated. A position recorded in game always wins. Forgotten Coast, Steamwheedle Port and Powderfuse Port have no flight point and stay unknown until recorded, so routes to them are not drawn.
- Public sources do not publish dock coordinates, so none were typed in by hand.

## Darker blue for Alliance routes, 0.5.58-beta

- Alliance routes and dock markers use a darker blue for better contrast on the light parchment of the world map.

## Two line styles for sea routes, 0.5.57-beta

- The Flight points menu now offers Route lines: thin (one pixel, the default) and Route lines: clear (about 1.6 pixels, full opacity and a slightly brighter color), because the thin line is hard to see on the light parchment of the world map. The choice is saved in the settings.

## Rounder sea routes, 0.5.56-beta

- Routes are drawn as smooth arcs instead of straight lines: one pixel thin, finely dashed, each bending to a stable side by an amount that depends on the two docks, so they read as sea lanes and routes between the same docks do not overlap. This is an illustration only, not the real path of the ship.
- The dock marker is smaller and round, with a thin dark ring. The switch Show boat and zeppelin routes stays in the Flight points menu.

## Boat and zeppelin routes, 0.5.55-beta

- The world map shows dashed colored lines for the boat and zeppelin routes of WoW Forever (blue Alliance, red Horde, gold neutral), for every player, plus a small marker at each dock with a tooltip that lists its routes. A line is drawn on a map that holds both ends of a route (the continent maps and the world map), a marker on every map that holds the dock.
- The client does not report dock positions (the area point query returned nothing in Teldrassil), so each dock is recorded in game: stand at the dock or tower and type /tgf dock <name> (a unique start of the name is enough; /tgf dock lists the 15 docks and which are recorded; /tgf dock forget <name> removes one). Nothing is drawn for a dock that is not recorded.
- Routes (from the Method.gg travel guide): Stormwind Harbour, Auberdine, Menethil Harbor, Southshore, Theramore Isle, Rut'theran Village, Feathermoon Stronghold and Forgotten Coast by boat for the Alliance (the Auberdine, Menethil, Southshore loop is one way in the game, drawn as plain lines), Orgrimmar, Undercity and Grom'gol by zeppelin for the Horde, Ratchet and Booty Bay, Steamwheedle Port and Powderfuse Port by neutral boat. Skyborne routes and the Deeprun Tram are not drawn.
- Menu Flight points has a new Show boat and zeppelin routes switch. New file, so a full game restart is needed.

## Transport probe, 0.5.54-beta

- New diagnostic command /tgf transport lists the area points the client reports on the open world map (name, atlas and position). It is the first step for drawing boat and zeppelin routes: dock positions are taken from what the client knows instead of being typed in by hand. Nothing is drawn yet.

## Modular data: only the installed professions, 0.5.53-beta

- The recipe table (Data/RecipeBook.lua, 123 KB, all professions, in the core) is gone. Each profession addon now carries the recipes of its own profession (product and materials, key book of its Data.lua, generated by tools/generate_catalog.py with the rest of the catalogue; Engineering 245 recipes, Leatherworking 482 and so on, none for Fishing, Herbs, Skinning and the Auction addon). tools/generate_recipe_book.py is removed. The core reads the books through Catalog.Book(), Catalog.ExtraRecipes(), Catalog.IsProduct(), Catalog.Installed(kind) and Catalog.InstalledKinds(), which follow the installed and switched-on professions and rebuild when a module registers or the profession switches change.
- The auction scan still has to read the whole list (the client has no filter), but keeps only the reagents of the installed professions and the products of their recipes (before: every item, 6543 in the second scan). The saved price block shrinks to what the installed professions need, down to nothing when no profession addon is installed. Item tooltips show prices of those items.
- Trainers of a profession whose addon is not installed are not recorded (npcLog: not-installed), recipe merchants record the recipes of installed professions only, and pins, the trainers list, the unlearned recipes list, the profession filters and the Titan menu profession filter list the installed professions only. The profit list and its profession filter take their professions from the installed books; its footer says when none is installed.
- Not modular yet: the seed of trainers and vendors (Data/NpcSeed.lua, about 190 KB, generated from a pinned dump that is not in the repository) is still one file of the core; it is filtered when used, not when loaded. Splitting it over the profession addons needs the dump to regenerate it.
- The profession module files grow by their book (Engineering about 49 KB, Leatherworking about 62 KB), and the core shrinks by 123 KB.

## Footer note only when needed, 0.5.52-beta

- The footer of the profit list explained the star ("assumes one item per craft") even when no row had one. The note is shown only when a priced row still has an assumed number made. Live check of 0.5.51: after the professions were read, the stars were gone and the names showed the number made (x200, x2, x3); the arithmetic of every row checked out, and no recipe had to be added from the profession windows for Engineering.

## The recipe table fills itself, 0.5.51-beta

- Reading a profession (the existing read when its window opens) now also reads the schematic of every recipe in its list, 40 recipes per frame, once per recipe. Two things are kept: the number one craft makes (saved variables key recipeMakes, which removes the star from the profit list: no more assumed one item per craft), and, for a recipe that the recipe table lacks, its product and materials (key recipeExtra: product, profession, materials). The profit list shows such recipes too and its footer says how many came from your profession windows. A recipe that is in the table is never copied, and one that was read is skipped when the window opens again. A recipe with a reagent the planner cannot read (a choice of reagents, a currency) is not added.
- This answers the incomplete recipe table (a mirror of client tables, complete = false): what your professions show is added over time.

## Profit list: rounding, number made and a clearer footer, 0.5.50-beta

- The fee of the auction house is no longer rounded to whole coppers per unit. 95 percent of one copper was rounded down to nothing, so cheap ammunition showed an auction price of 0c after the fee and a profit of +0c. The unit price after the fee is kept as it is and rounded only when it is shown, and the value of a craft is rounded to the nearest copper.
- The name in the profit list shows how many one craft makes when it is not one ("Rough Dynamite x2"), because the profit is for the whole craft and the columns show prices per unit. A range shows its average ("x1.5").
- The footer said "20 of 20 recipes have a profit" when only a few earned one. It now says how many could be priced and how many of those earn a profit.

## Thin markets in the profit list, 0.5.49-beta

- The second real scan priced 1050 of the 1971 recipes (1045 of them completely) and showed the weakness of the lowest buyout: 18 of the 40 best profits rested on one or two auctions, and the best one was a single auction against materials of nearly the same size. One odd offer sets the lowest buyout.
- The profit list has a new column Auctions with the number of auctions behind the price of the product (an orange number below three), and a Markets filter next to the profession filter: 3+ auctions (the default) hides the recipes whose product sells on the auction house on fewer than three auctions, All markets shows them. The footer says how many are hidden. A product that sells better to a vendor than to the auction house is never hidden, because the auction does not decide its profit. The materials are not checked for thin markets.
- The product line of the reagent window marks a price that rests on fewer than three auctions in orange ("1 auction, thin market").
- The scan itself: 287,853 auctions were read in 7.2 seconds (the first scan needed 18.8) and 6543 items were priced, 484 of the catalogue and 6059 others; the saved price block is about 139 KB.

## The Reagents button closes the window again, 0.5.48-beta

- The Reagents button of the profession window works like the minimap button: a second click closes the reagent window when it shows the selected recipe, and a window that shows another recipe is switched to the selected one instead of being closed. The entry in the recipe menu still only opens.

## Reagents button as a child of the screen, 0.5.47-beta

- The professionLog of 0.5.46 showed that the button was created (the recipes page and the close button exist, the maximize button does not) and still never showed, so the cause is the drawing, not the search for the window. The button is now a child of the screen instead of the window or its page, in the HIGH strata and 50 levels above the window, anchored left of the close button (or of the maximize button when that is on screen), and it is shown and hidden with the window and with its recipes page. One second after it is created, the professionLog gets a "placed" line with where the button is (left, top, width), whether it is visible, the state of the window and page, the strata, level and scale, so that the next step does not need a guess.

## Reagents button visible, movable client windows, 0.5.46-beta

- The Reagents button of 0.5.38 to 0.5.45 did not show in the profession window. It hung on the maximize button, which this window has but keeps hidden, so the button was hidden with it. The button is now a child of the recipes page (shown exactly there), placed left of the maximize button when that is on screen and otherwise left of the close button, and the place is chosen again whenever the page is shown. What was found is written to a small log (saved variables key professionLog: whether the window, the page, the close and maximize buttons exist and whether the maximize button is shown), for the case that it still does not show.
- The profession window and the auction house window of the client can be moved now: drag any empty place of the window. The position is kept like the positions of the other windows (also after /reload and a restart) and put back after the client lays its windows out again. Titan menu > Display > Let me move the profession and auction house windows switches this off, and Reset window positions forgets them. New file Movable.lua, so a full game restart is needed. Other windows of the client (trainer, merchant, bank) are not touched.

## Opaque windows, 0.5.45-beta

- The art of the window frame is partly transparent, so a window over another (the reagent window opened from the profit list, for example) showed the window below through it and the texts mixed. Every window now has a solid dark layer behind the frame art, and a click raises a window above the others; the reagent window also opens above the window that opened it. This covers the tabbed window, the reagent window, the export window and the icon appearance window (all go through Nav.Draggable).

## Crafting profit list, 0.5.44-beta

- New tab Crafting profit (also Titan menu > History and sources > Crafting profit). It lists the recipes of the new recipe book with what the materials cost at the cheapest known price, what the product sells for to a vendor and on the auction house after the fee, where it sells better, and the profit of one craft, best first. Green is a profit, red a loss, gray is unknown because a price is missing (a profit is never guessed); a star marks a number made that is assumed to be one until the recipe was opened in the reagent window. A click opens the reagents of the recipe, hovering shows the product.
- Filters: My recipes or All recipes, one profession, and a search over the recipe and profession names. "My recipes" uses the learned recipe IDs of the profession windows (the profession must be read once; professions that were not are named in the footer); records from before this version have names only and are matched by name. If no profession was ever read for the character the list starts with all recipes.
- The recipe book is Data/RecipeBook.lua (about 120 KB, 1971 recipes: product, profession and materials), generated by the new tools/generate_recipe_book.py from catalogue/forever-recipes.json, checked by tools/check.py. It is a mirror of client tables for 1.60.1 and not complete (complete = false); the live schematic of the reagent window stays authoritative. The number a craft makes is read from the schematic and kept (saved variables key recipeMakes) when a recipe is opened in the reagent window.
- New files Data/RecipeBook.lua, Profit.lua and ProfitBrowser.lua, so a full game restart is needed. All 1971 recipes are priced in a few milliseconds.

## Product prices, profit and window positions, 0.5.43-beta

- The auction scan keeps the lowest buyout of every item on the auction house, not only of the profession catalogue: the catalogue items keep quantity and auction count, every other item (the products of recipes included) is stored in one number (lowest buyout times 1000 plus the number of auctions, capped at 999) to keep the saved data small. Run a new scan to fill them; scans from earlier versions have the catalogue items only.
- The reagent window shows the product of the recipe in three lines: what it makes and where one unit sells for more (the vendor price against the lowest buyout after the 5 percent auction fee, which is an assumption and not read from the client), the auction and vendor prices, and the profit of one craft against the materials at the cheapest known price (auction or a merchant that was seen selling it), also for the planned number of crafts. A reagent without a price, or a recipe the window cannot price completely, shows no profit instead of a guess. The window is as tall as its list (at least four rows). The product and the number made come from the recipe schematic (outputItemID, quantityMin and quantityMax); a range counts as its average.
- The last column says "Buy at the auction house" for a reagent that has an auction price but no merchant and no observed source. A merchant is named when it is the cheapest known way to buy the reagent; an observed source comes next.
- The source menu of a reagent shows the auction price with the scan age and what a vendor pays, and names the recipes ("Plan reagents: Rough Copper Bomb") instead of recipe numbers.
- Item tooltips show the auction price of any item that has one (not only profession items) with the worth of what you hold, what a vendor pays and which of the two leaves more after the fee, the number of auctions and the age. Titan menu > Auction prices > Show auction prices in item tooltips switches this off.
- Every window remembers where it was left, also after /reload and a restart: the tabbed window (one position for all tabs), the reagent window, the export window and the icon appearance window. Titan menu > Display > Reset window positions forgets them. New file Economy.lua, so a full game restart is needed.

## Auction price in item tooltips, 0.5.42-beta

- The tooltip of a profession item (the same items the tooltip already knows) shows the price of the last auction scan: "Auction: 12s 50c each" and, when you hold some, "Worth: ... for 3 at this price" (bags, plus the bank when bank counts are shown). A small gray line gives the number of auctions and items behind the lowest buyout and the age of the scan. Nothing is shown for items without a price, for another realm, or before a scan. It follows the existing item tooltip switch.

## Faster auction scan reading, 0.5.41-beta

- The first successful scan read 281,892 auctions in 18.8 seconds: the reading took 250 auctions per frame, so it was limited by the frame rate (1,128 frames at 60 per second), not by the work. The reading now takes as many auctions per frame as fit into 6 milliseconds (looking at the clock every 100 auctions), which should cut the time to a few seconds with a short, small hitch per frame. Without the clock function it keeps the fixed 250 per frame.
- The client repeats REPLICATE_ITEM_LIST_UPDATE dozens of times while the list is read, and every repetition was logged; the 30 line log was full of them. They are now logged once per scan.

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

See [the roadmap](../plans/plan-next-development.md), [progress](../ref-wow-forever-progress.md) and [live validation checklist](../book-wow-forever-validation.md).
