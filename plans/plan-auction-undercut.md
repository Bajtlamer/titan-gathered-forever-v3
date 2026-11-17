# Plan: automatic Buyout undercut in the Sell tab

Written 2026-11-17 at version 0.5.84. Design agreed with the user in conversation; implementation follows in the same session.

## 1. Goal

When the player prepares a new auction in the Sell tab of the auction house, the Buyout price is filled in automatically: the lowest existing buyout of the same item minus x percent. The percentage comes from a combo box with the presets 2, 5, 10 and 15 percent and a custom entry with a text field.

## 2. Placement

The feature lives in the shared core (new file TitanGatheredForever/AuctionUndercut.lua, loaded after AuctionScan.lua), next to the existing price scan. The Auction Items add-on stays a pure data catalogue.

## 3. Interface

- A small strip under the Sell form of AuctionHouseFrame: gold info label "Undercut", a combo box and, when the custom entry is chosen, a numeric text field with a percent sign.
- Combo box entries: 2 %, 5 %, 10 %, 15 %, Custom. It reuses the existing combo box helper used in the other windows of the add-on.
- Check box "Fill Buyout automatically" in the same strip, also available in the Titan menu next to the auction scan options.
- Custom field accepts 0.1 to 90 (one decimal). Invalid input restores the last valid value.
- Texts follow the style rules: gold small info text, prices with coin icons (ns.Economy.Coin), English only.

## 4. Settings

- ns.settings.auctionUndercutEnabled (boolean, default true)
- ns.settings.auctionUndercutPercent (number, default 5)
- ns.settings.auctionUndercutPreset (one of 2, 5, 10, 15 or "custom")
- Added in Settings.lua with the same validation pattern as auctionAutoScan. Existing settings are untouched.

## 5. Flow

1. The player picks an item in the Sell form. A hook on the item selection of the Sell frames starts a live search for that item: C_AuctionHouse.SendSearchQuery with the item key.
2. The answer arrives as COMMODITY_SEARCH_RESULTS_UPDATED (commodities) or ITEM_SEARCH_RESULTS_UPDATED (other items). Results are read with the matching C_AuctionHouse getters.
3. The lowest unit price (commodities) or lowest buyout (other items) is taken, ignoring the player's own auctions.
4. Price = floor(lowest * (1 - percent / 100)), at least 1 copper, written to the Buyout field through MoneyInputFrame_SetCopper. For commodities the value is a unit price.
5. If the price would fall below the vendor sell price, nothing is set and a short chat message states the reason.
6. The player may edit the field at any time; the add-on does not overwrite a manual edit for the same item selection.
7. A result for an item that is no longer selected is discarded. Search requests go through the existing throttle handling; no request is sent while the client reports the message system as not ready.
8. No other auctions: nothing is set and the chat message says so.

## 6. Structure

- Pure logic (price calculation, percent validation, own-auction filtering, staleness check) is separated from the client calls and receives a replaceable api table, the same pattern as AuctionScan.New(api). This keeps it testable without the game.
- DefaultAPI wraps C_AuctionHouse calls in pcall and ns.IsPublic checks like AuctionScan.DefaultAPI.

## 7. Tests

tests/auction_undercut.lua with a fake api: percent calculation and rounding, 0 and 90 limits, invalid custom input, no results, own auctions ignored, item changed before the answer, vendor price floor, manual edit not overwritten, disabled option. Registered in tools/check.py through the existing suite discovery.

## 8. Known risks and live validation

- The names of the Sell frames (AuctionHouseFrame.CommoditiesSellFrame, ItemSellFrame) and their item-selection hooks in WoW Forever 1.60.1 are not yet confirmed. The first implementation step is to verify them with /dump in the client; until confirmed, the hook points are isolated in one function.
- The live search is an extra request per selected item and is subject to the client throttle.
- Live results (the Sell form fills the price, the combo box works, custom value persists after /reload) are documented separately from the automated checks in ref-wow-forever-progress.md.

Confirmed on 2026-11-17 from the saved variables (auctionProbe, version 0.5.85): AuctionHouseFrame.CommoditiesSellFrame and AuctionHouseFrame.ItemSellFrame exist and both have SetItem, PriceInput (with SetAmount, GetAmount, SetOnValueChangedCallback, MoneyInputFrame), QuantityInput, GetPrice, GetDefaultPrice and SetSearchResultPrice. ItemSellFrame also has SecondaryPriceInput and BuyoutModeCheckButton: there PriceInput is checked against the Buyout mode before it is assumed to be the buyout. All of C_AuctionHouse.SendSearchQuery, GetItemKeyFromItem, GetItemCommodityStatus, GetNum/GetCommoditySearchResult(s)Info, GetNum/GetItemSearchResult(s)Info and IsThrottledMessageSystemReady exist. The manual-edit hook is PriceInput:SetOnValueChangedCallback, not a hooked OnAmountChanged.

## 9. Release steps

Patch version bump, README.md, release-notes/ref-unreleased.md, python3 tools/check.py, install through tools/install.py, verification of installed bytes, then the player runs /reload or restarts if a new file is added (a new Lua file needs a full client restart).
