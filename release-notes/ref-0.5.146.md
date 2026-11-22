# Titan Gathered Forever 0.5.146

Update from 0.5.144. This text is the changelog for the website and the release page. Version 0.5.145 was an internal step and is included here. No new files were added: a plain reload is enough after updating.

## Added

- **Economy by character.** The Economy tab has a character selector for the current realm. The default, All characters, still shows the realm total. This character or another character with recorded history filters every source: merchant sales, auction settlement, quest rewards, mob coin, merchant buybacks and equipment repairs. Existing history is available at once. Auction invoices whose seller name cannot be linked to a character have their own choice in the selector ("auction history"), so nothing is lost or guessed.
- **Personal auction price history.** The Market history chart in the Sell tab shows the current character's confirmed sales of the selected item on the current realm: for each day the net proceeds per unit after the auction fee, with stack quantities counted and returned deposits excluded. Two priced sale days are enough to show the 30-day personal trend; with less evidence the chart keeps the seven-day scan history. The current listing shows the percentage and per-unit difference from your recorded net average.

## Changed

- The Economy income sources (mob loot, quest rewards, auction invoices, vendor sales) can be summed per character instead of only for the whole realm; the character name is remembered for the selector.

## Fixed

- None. Behaviour of the other windows is unchanged.

## Upgrading

Install over the old folders. Your saved data and settings are kept. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
