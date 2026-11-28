# Titan Gathered Forever 0.6.0

Update from 0.5.193. This text is the changelog for the release page.

Version 0.6.0 is a milestone. Titan Gathered Forever no longer needs Titan Panel (since 0.5.177, completed in 0.5.193), and with this version every auction house feature lives in its own optional module.

## Changed

- The Auction items module is now the **Auction house** module (Titan Gathered Forever: Auction house; the folder is still `TitanGatheredForever_AuctionItems`). It carries every auction feature: the price scan, auction prices in item tooltips, the Sell tab undercut, Market history beside the Sell tab and the sales ledger read from the mailbox (`/tgf sales`), together with the Auction items catalogue. Disabling it in the AddOns list switches all of them off.
- The core runs without the Auction house module:
  - The Crafting profit tab and the reagent window use what a vendor pays and say that auction prices need the module.
  - The Economy tab shows the auction sales row as needing the module.
  - The Auction house page in Options and the Auction prices entry of the menu say where the features went.
  - The chat says it once after the update, when the module is missing or disabled.
- Your scanned prices and recorded sales stay in the core's saved data. Disabling the module keeps them; enabling it again brings them back.

## Added

- The minimap button tooltip also lists the modules of the collection that are not installed, in gray as Not installed, after the installed ones, with a line saying where to get them (CurseForge or titan-gathered.com).
- A module of another version than the core shows its version in orange, with a line saying to update it, so an old module beside a new core stands out. Matching modules show no version, because they are released with the core; Discovery keeps its own version.

## Fixed

- The minimap button tooltip showed the Auction module as Switched off when the Auction items group was hidden in the material list, although the module kept running. Hiding the group now only hides the group.
- The minimap button tooltip never showed Herbalism as Switched off when it was hidden in the settings, because the folder name (Herbalism) differs from its settings key (Herbs).
- The Auction house and Discovery lines of the minimap button tooltip had no icon; they now show a coin and a spyglass.

## Upgrading

Install the core and the Auction house module together; both must be 0.6.0. Without the Auction house module installed and enabled, the auction features are gone until you add it. Nothing recorded is lost. Restart WoW after installing, because files moved between the folders.
