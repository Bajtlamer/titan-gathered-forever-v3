# Titan Gathered Forever 0.5.156

Update from 0.5.154. This text is the changelog for the website and the release page. Version 0.5.155 was an internal step and is included here. No new files were added: a plain reload is enough after updating. Run one auction scan after updating, because the earlier scan holds only the items of the catalogue.

## Added

- **Best sale.** The Your sales section of the Market history panel in the Sell tab shows the best sale of the selected item: the highest net price per unit you ever got for it on this realm, with its date. It counts only your own sales (the seller invoices in your mail), never other players' auctions, and it is kept in the saved data apart from the bounded sales ledger, so it survives when older sales are forgotten.

## Changed

- **The Market history chart is your own history.** With one or more days of confirmed sales of the item it shows the net price per unit of each day, the best day in green, and the trend from two days. Without a sale of the item it shows one point, the price of the last auction scan with its date. A short text explains a missing price: no scan yet, or the item is not in the last scan.
- **No daily history of scans.** Only the last scan is kept; the daily archive of earlier versions is deleted, so the saved file does not grow with every scan.

## Fixed

- **Items outside the catalogue had no scan price.** The auction scan kept only the reagents and the products of recipes of the installed professions, so any other item, for instance a ring with a random enchantment, showed "No scan prices in this period" right after a scan. The scan now keeps the lowest buyout and the number of auctions of every item, as the documentation says. The saved file grows with the number of different items on the realm.

## Upgrading

Install over the old folders. Your saved data and settings are kept. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
