# Titan Gathered Forever 0.5.161

Update from 0.5.156. This text is the changelog for the website and the release page. Versions 0.5.157 to 0.5.160 were internal steps and are included here. No new files were added: a plain reload is enough after updating.

## Added

- **Current listing in the Sell tab.** The panel shows what matters for a posting: what the sale earns after the 5 percent fee (the deposit comes back), what that is against selling the same units to a vendor, what a failed auction loses (the deposit), and how many units of the stack must sell for the gain over the vendor to cover the deposit ("3 of 20", "all 3", or "the item must sell" for a single item).
- **A warning for a cheap item.** When even a full sale gains less than the deposit, a red "Not worth the risk: the gain is less than the deposit" is shown.

## Changed

- **Economy counts sales.** The Sales column of Economy (it was Units sold) counts successful sales: one confirmed auction invoice or one merchant sale is one sale, a single item or a stack of a hundred alike. The number of items stays in the Market history panel of the auction house.
- **The Current listing no longer compares** with other auctions, the last scan or your earlier sales, and the break-even percentage is gone. When the price is at or below what a vendor pays, only the red "Vendor pays more" comparison and the loss of a failed auction are shown, because what the sale would bring is of no use then.

## Fixed

- None.

## Upgrading

Install over the old folders. Your saved data and settings are kept. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
