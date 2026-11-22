# Plan: sales history, price trends and the posting panel

Written 2026-11-21 as a handover (the work moves to another computer). It records the decisions, the state of the code, what is verified and what is not, and the next steps. Version at the time of writing: 0.5.123 on `main`.

## Left-side Market History candidate

The left-side panel supersedes the placement described in the handover below. Both Sell forms expose history only while holding a valid item. Keep the player's collapsed preference across item and tab changes. Use native dialog materials, with a left-edge overlay available through the toggle when there is too little screen space to dock the panel outside the window.

Live screenshots of 0.5.124 showed the docked panel, a Show history button clipped by the title bar and the old posting panel covering the auction tabs. In 0.5.125 the toggle goes below the title bar, and Current listing in the left panel replaces the bottom panel. Keep Undercut, AH sold and Vendor inside the Sell form.

The owner confirmed 0.5.125 working in the client. Version 0.5.126 compares the current buyout per unit with the latest scanned price and the estimated net per unit with the weighted net from this item's confirmed sales. Both comparisons use the selected item and realm. The local save has one price snapshot and no completed sale mail yet. The Forever mail UI uses the seller invoice's bid field as the actual sale amount and shows proceeds as that amount less the fee plus the returned deposit. The add-on checks this arithmetic against the amount attached to the mail before reporting historical net proceeds. [Forever mail frame source](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua#L763-L778)

- Record only prices from completed scans. Archive the previous scan by realm and UTC day as the next scan completes. Read the current snapshot through the same history view so an existing snapshot is available on first use. Retain at most the visible seven days of daily snapshots, including the current day. Clearing scanned prices clears both sources.
- Summarize confirmed mail entries for the same base item and realm over 30 days. Calculate the realized unit price from the invoice sale amount and known quantity. Preserve partial and unknown quantities and mark the sale date as estimated.
- Exercise scan persistence, realm isolation, expiry, incomplete invoices, both forms and the toggle with LuaJIT. Verify frame placement, small screen behavior, and actual mail values in the client.

## Economy tab in the main TGF window

Add a dedicated Economy tab for overall trading, quest and loot income. Show the quantities sold to merchants and through auctions, the proceeds from each source, cash awarded for turning in quests, cash looted from mobs, and combined income from those sources. The auction house Sell panel remains the item-level view. Both views must read the same auction sales ledger.

The 0.5.127 candidate introduced the Economy tab and Titan menu entry with confirmed auction totals. Version 0.5.131 includes all four income sources and displays the recorded total as a lower bound. The scope is all recorded characters on the current realm.

- Merchant sales in 0.5.129 match changes in the native buyback list to the wallet credit and retain item, quantity and proceeds by character and realm. Matched buybacks are tracked as spending. Earlier buyback entries provide a baseline. Unchanged snapshots, including an indistinguishable rotation of a full list, provide no attributable sale evidence. Verify manual sales, several stacks, buybacks and repairs in the client. [Forever merchant frame source](https://raw.githubusercontent.com/Gethe/wow-ui-source/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua#L383-L395)
- Auction sales use the confirmed seller invoices already recorded by the mail ledger. Preserve gross sale amount, fee, returned deposit and credited amount. Use net sale proceeds in combined income so a returned deposit does not increase earnings. Waiting auctions and scanned prices are useful context for Sell.
- Quest income records the quest ID and the cash awarded through `QUEST_TURNED_IN`. Each repeatable quest completion counts once. Merchant or auction sales of quest reward items belong to the corresponding sale source. [Forever quest event definition](https://raw.githubusercontent.com/Gethe/wow-ui-source/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua#L1325-L1334)
- Mob loot counts cash pickups from dead creatures. Version 0.5.128 records a cleared coin slot when the creature source is known and the visible amount matches a single change in the player's wallet. Cash from opening an inventory item and ambiguous money changes stay out. Check manual loot, auto-loot and group shares in the client. [Forever loot frame source](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua#L83-L90)

The 0.5.129 live save had an initialized vendor ledger and zero vendor log records after merchant visits at 21:22:21 and 21:22:48 CET. The core debug log recorded both opens, the updates and the closes. The 0.5.130 candidate routes the vendor collector through that core handler and saves the opening before reading the buyback data. Verify a new sale and inspect the saved ledger and vendor log after a reload.

The 0.5.131 live save at 21:45:04 CET showed `realm unavailable` for all three merchant visits at 21:41. The stored auction mail and mob coin records use the empty string returned by Forever. Version 0.5.132 accepts that same key for merchant sales and quest rewards. The rejected merchant visits had no recorded wallet or buyback data to recover.

The 0.5.132 live save at 21:59:21 CET confirmed a merchant sale at 21:49:56 CET. The buyback list grew from six entries to seven and the wallet increased by 273 copper. The ledger stored one stack with one item for 273 copper.

Automated checks cover overlapping quest and wallet events, a later merchant sale, and totals rendered from all four sources. Verify new merchant sales, cash quest turn-ins and a real auction settlement in Forever. Keep the amounts and quantities with missing evidence unknown and indicate incomplete coverage in the overview.

## Goal

1. In the auction house Sell tab keep the Undercut row (label, combo box, "AH sold", "Vendor") inside the original window, and show the remaining information about the item being posted in a panel that hangs under the window. The panel should look like part of the window (same frame and background as the original window), not a custom dark box as it does now.
2. Record what was really sold and for how much, from the sale mails in the mailbox, and keep it in the saved variables.
3. In the auction panel show only very brief information about the item about to be posted: how many were sold lately, the average real price, the last sale, and the trend of the current price from our scans. A fuller overview (totals, most profitable items, a price chart) belongs in the main window, possibly as a new tab.

## Decisions so far

- The auction house window is never resized. Making it taller (0.5.114 to 0.5.119) made the client's scroll lists lay out again while the window closed, and ESC after preparing a sale raised errors in Blizzard code (Pool release of nil in TableBuilder RemoveRow, GetCommoditySearchResultInfo). Switching the extension off (EXTRA = 0) stopped the errors. Do not reintroduce any change of the height of AuctionHouseFrame, also not deferred.
- Truth about sales comes from the mail ("Auction successful"), not from our own postings. A posting log (what was offered, at what price and deposit) is a possible later addition if the invoice does not give enough.
- Nothing is taken, opened or changed in the mailbox by the add-on. Unknown values stay nil.
- Everything needed for verification is written by the add-on itself to the saved variables at game events; the user is not asked to paste in-game output and types a command only when unavoidable.

## State of the code (main)

- `AuctionUndercut.lua`: `Undercut.strip` is the row inside the window (item form: 32, 78 from the bottom left; commodity form: 32, 85; `Undercut.Place`), `Undercut.panel` hangs under the window (`Undercut.HEIGHT` 76, anchored TOPLEFT/TOPRIGHT to the window's BOTTOMLEFT/BOTTOMRIGHT) and holds the gains line, the unsold line and the red warning. Both follow the Sell forms by `OnShow`/`OnHide` hooks. The row position is an estimate from earlier versions and has not been confirmed on a screenshot of the new layout.
- `Sales.lua` (new, 0.5.122, log in 0.5.123): `Sales.New(api, store, log)`, `Scan(source)`, `ParseSubject`, `DefaultAPI`, `Report` (`/tgf sales`), `Initialize` (events MAIL_SHOW and MAIL_INBOX_UPDATE, one scan 0.5 s after the last event, a hook on `OpenMail_Update`). Tests in `tests/sales.lua` and one in `tests/integration.lua`.
- Saved variables (`TitanGatheredForeverV3DB`, file `WTF/Account/<account>/SavedVariables/TitanGatheredForever.lua`): `sales.entries` and `mailLog`, both created in `Settings.lua`.

### Sales entry

`at` (first seen), `character`, `realm`, `subject`, `itemName`, `itemID` (nil when the client does not know the name), `count` (from a trailing "(n)" in the subject, otherwise nil), `received` (copper in the mail), `expiry` (estimated, used as identity), `soldAt` (expiry minus 30 days, an estimate), `source` ('header' or 'invoice'), and `buyer`, `buyout`, `deposit`, `fee` when the seller invoice is readable.

Identity of a mail: same character, subject and money and an estimated expiry within 30 seconds; a mail is claimed once per scan, so identical mails remain separate sales, and a mail whose money was collected later (money 0, 3 days left) is neither repeated nor erased. Only mails with money greater than zero are recorded; "Sale Pending" (invoice type `seller_temp_invoice`) and purchase mails are skipped and logged.

### mailLog rows (120 kept)

`scan` (source event, number of mails, sales recorded; written when something new was found or the number of mails changed), `recorded` (with the raw invoice values), `pending`, `other` (other invoices), `other-mail` (a sample of every other mail once per session: subject, sender, money, days), `bad-money`, `bad-days`, `scan-failed`.

## Not verified yet (read from the saved variables after a real sale and a /reload)

1. The exact subject text of a sale mail and whether it carries the stack size.
2. Whether `GetInboxInvoiceInfo` returns the invoice before the mail is opened, or only after. Without it the price per unit is unknown, only the money received.
3. What the money in the mail contains (buyout minus fee plus the returned deposit is the assumption).
4. Positions of the return values of `GetInboxHeaderInfo` (sender 3, subject 4, money 5, COD 6, days left 7) in this client.
5. The position of the Undercut row on both forms and the look of the panel.

## Next steps

1. Read `sales.entries` and `mailLog` after the user has sold items, opened the mailbox and reloaded. Fix the parsing from the evidence (subject format, stack size, invoice fields). If the invoice is unavailable before opening, decide between a posting log (hook `C_AuctionHouse.PostItem` and `PostCommodity` with `hooksecurefunc`, store item, quantity, price, duration) and reading the invoice when the mail is opened.
2. Brief history in the auction panel for the selected item: sales in the last 30 days, average real price, last sale, plus trend of the lowest price from our scans (ns.db.auction holds only the last scan, so price history needs its own bounded series, one point per item per scan day).
3. Make the panel look like the original window: use the same atlases or frame template and background as Blizzard's auction house frame instead of the dark texture and gold line.
4. Main window overview of sales (totals, per item, most profitable), with a price chart. Follow the text and price style rules in AGENTS.md (gold small labels, white values, green dates, money with coin icons).
5. Remove diagnostics that served their purpose once confirmed (see the cleanup item in `plan-live-verification-and-optimization.md`), keeping one bounded log per feature.

## Working agreements

- TDD: write the test, watch it fail, then implement. `python3 tools/check.py` must pass. Version the patch number for every completed update (core toc, `tools/generate_catalog.py` VERSION, all profession tocs, README), and add a section to `release-notes/ref-unreleased.md`.
- After checks, install with `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'` then `--apply`, and compare the installed files with the source. New files need a full WoW restart, Lua-only changes a `/reload`.
- Saved variables are written only on `/reload` or logout. Read them directly instead of asking the user to copy anything from the game.
- Commits carry no attribution to an AI tool (AGENTS.md). Nothing is pushed or published without being asked.
- No em dashes and no emoji in documents. The user writes Czech, documents in this repository are English.

## Other repositories and branches

- `feat/discovery-module` (local, not pushed): the standalone Discovery module (`TitanGatheredForever_Discovery`), merged with `main` up to 0.5.118. `main` has moved on by the commits 0.5.119 to 0.5.123 (window resize fix, panel, Sales ledger); merge `main` into the branch before continuing there. Live acceptance of Discovery is still open (`book-wow-forever-validation.md`).
- Bajt's Fight Assist is a separate repository, `Bajtlamer/bajt-fight-assist` (public, released as v0.4.6: Core 0.4.6, Hunter 0.4.5, Rogue 0.3.4 with addon list icons). Open item: the combo point colours do not look right in game yet (the user said they will be left for now). Ideas not done: poison timers and Sap on the nameplate, posting the release to the website (`dist/web` has the ZIPs and SHA256SUMS).
- Blizzard auction house Lua errors seen earlier at AUCTION_HOUSE_SHOW (GetCommoditySearchResultInfo) were in Blizzard stacks only; the resize was the part we caused.
