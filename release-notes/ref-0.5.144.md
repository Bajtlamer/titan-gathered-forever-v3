# Titan Gathered Forever 0.5.144

Update from 0.5.108. This text is the changelog for the website and the release page. New files were added to the core, so close the game before updating and start it again afterwards (a plain reload is not enough once).

## Added

- **Statistics in the Professions window.** A Statistics button at the bottom of the native window opens one panel with three views chosen in a combo box. Attempts lists the crafted recipes and, as one row each, Mining, Herbalism, Skinning, Fishing and Disenchanting, with attempts, completed and completed %. Materials estimates the use of required materials. Gathered items shows what the gathering professions collected, valued at the better of the vendor and the auction price after the fee, for all of them or one. Every column header sorts the list. Click a row for details, a profession tab to leave the panel. This replaces the Crafting and cooking and Profession actions windows; your saved data is unchanged.
- **Economy window.** Verified income on the current realm: merchant sales (also Sell All Junk Items), auction proceeds after fees from confirmed seller invoices, quest cash rewards and coin from mobs, with merchant buybacks and equipment repairs shown as spending. Only amounts that match what the game reported are counted, so the total is a lower bound.
- **Sales ledger.** Sale mails and their invoices are read when you open a mailbox and recorded once each (item, quantity, price, deposit, fee, buyer when the game provides them). Nothing is opened, taken or changed in the mailbox.
- **Market history in the auction house Sell tab.** A collapsible panel for the selected item shows the last scanned lowest price, a seven-day trend, 30 days of your confirmed sales and a comparison of the current listing with them. The Undercut row stays in the Sell form; the auction window is never resized.
- **Recipe menu.** The right click menu of a recipe shows how many of it you have crafted in total.
- **Menu entries for other modules.** The menu of the minimap button and of the Titan entry accepts entries from add-on modules; Titan Gathered Discovery (a separate data-collection module, not part of these downloads) uses it to open its window.

## Changed

- Compact posting rows in the Sell tab: a narrow Undercut combo box (2, 5, 10 or 15 percent), "AH sold" and "Vendor" beside it, and the gains, unsold deposit and vendor floor warning in the market history panel. The custom percentage was removed.
- The native recipe list is left as the game draws it: its number in square brackets is still what you can make with the materials at hand.

## Fixed

- Pressing ESC after preparing a sale in the auction house no longer causes Lua errors in the game's own scroll lists. The cause was resizing the auction window, which the add-on does not do any more.
- Profit against the cost of the item, the unsold deposit and the vendor floor are shown again in the Sell tab.

## Upgrading

Close the game, install the new folders over the old ones (the installer or the ZIP contents go directly into Interface/AddOns), and start the game. Existing settings, statistics, per-character coverage and map observations are kept. The folders were renamed in 0.5.84 from TitanGatheredForeverV3 to TitanGatheredForever: remove any old TitanGatheredForeverV3 folders.

## Known limitations

- Matched crafted outputs, bonus and multicraft rates are not provided by this client, so they appear only in the details of a recipe as Unknown.
- Catalogue completeness is not claimed; it remains unverified in the live game.
- Merchant sales, repairs and mail invoices are recorded from the time of this version; earlier ones cannot be reconstructed.
