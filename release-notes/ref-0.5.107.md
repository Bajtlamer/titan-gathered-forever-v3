# Titan Gathered Forever 0.5.107

First stable version. It contains everything since 0.5.81-beta, which is described in ref-0.5.81-beta.md. Per-step history is in ref-unreleased.md. This text is the changelog for the website and the release page.

## Highlights

- The Sell tab of the auction house fills the Buyout price for you, with a combo box for the percentage, and shows what the auction would bring and cost.
- The addon has its official name, Titan Gathered Forever, and runtime folders that match it.
- Original artwork for the core and every module.

## Added

### Buyout undercut in the Sell tab

- When you pick an item to sell, the add-on searches the auction house for it and fills the Buyout price with the lowest buyout of other players (per unit for stackable goods) minus a percentage. Choose 2, 5, 10 or 15 percent in a combo box, or Custom for your own value from 0.1 to 90. Changing the percentage prices the same item again. Your own auctions are ignored, and a price you type yourself is not overwritten.
- The price never falls below the lowest price at which a sale, after the auction house fee, still brings what a vendor pays. When the percentage would go lower, the Buyout is set to that price and a red line says so.
- It works on both Sell forms: stackable goods (unit price) and single items (with Buyout Mode on).
- Two lines under the Sell form show the auction as it stands: "Sold" with the sale net of the fee, the profit against the cheapest known way to buy one unit again (last price scan or a merchant) and the gain against a vendor, and "Unsold" with the deposit that an expired auction costs and the share of auctions that must sell for posting to pay.
- It can be switched off in the Titan menu under Auction prices. The last fills and deposit readings are kept in the saved variables for diagnosis.

### Name, folders and artwork

- The public name is Titan Gathered Forever everywhere in the game. Runtime folders and manifests are TitanGatheredForever and TitanGatheredForever_<Module>. The saved table key TitanGatheredForeverV3DB and the exported namespace alias stay, so your saved data keeps working.
- Each module has its own icon in the AddOns list, and the core uses its emblem on Titan Panel and the minimap.
- The version number has no beta suffix from now on.

## Upgrading

The folders were renamed. Install through tools/install.py when you work from the source: it moves the old TitanGatheredForeverV3 folders to a backup, copies the saved files to the new names and keeps the addon enablement, with the game closed. With a downloaded ZIP, close the game, remove the old TitanGatheredForeverV3 folders from Interface/AddOns, extract the new folders next to the other addons, and copy your old SavedVariables files to the new addon names before starting the game. Enable the new modules in the AddOns list. A full client restart is required.

## Verification and limitations

All automated checks and Lua 5.1 compilation of every shipped file pass. Checked live on WoW Forever 1.60.1: the fill on both Sell forms, the combo box and custom value, the vendor floor with its red line, the deposit readings (the deposit is for the whole auction: vendor price times quantity times 2.5 percent per hour, independent of the price) and the posting lines.

Still assumptions or unchecked: the fee rate of 5 percent, whether an expired auction loses the deposit, the fill with Buyout Mode off, an item without any other auction, the Titan menu switch after /reload, and whether the "Sold" line fits the panel for prices in gold. The addon targets WoW Forever 1.60.1, interface 16001, with Titan Panel installed separately.
