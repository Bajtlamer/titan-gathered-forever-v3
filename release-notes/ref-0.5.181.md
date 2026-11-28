# Titan Gathered Forever 0.5.181

Update from 0.5.172. This text is the changelog for the website and the release page. Versions 0.5.173 to 0.5.180 were internal steps and are included here. New files were added and the manifests changed: fully restart WoW after updating, a reload is not enough.

## Added

- **My materials tab.** The first tab of the main window lists the materials of your installed professions that the character holds, with bags, bank and total, a scope choice (in bags or bank, or all catalogue materials), a group choice, search and sortable columns; hover a row for the item tooltip. A second view lists the learned professions with their skill. It is the same information as the list of the Titan Panel entry, as one scrolling list without pages. A left click on the minimap button opens it, and `/tgf materials`.
- **Works without Titan Panel.** Titan Panel is now optional. With it, Titan Gathered Forever is a Titan Panel plugin as before. Without it, the addon runs on its own: your materials are in the new My materials tab, the right click menu of the minimap button is the same menu as on the Titan Panel entry, the world map button keeps the map options, and every setting is in the game Options window. Other panel displays of the LibDataBroker library (ChocolateBar, Bazooka and similar) show the entry too. The profession modules need only the core.
- **Settings in the game Options window.** Esc > Options > AddOns > Titan Gathered lists the settings on pages: General, Material list, Professions, Map pins, Gathering spots, Map materials, Travel routes, Auction house, Diagnostics and Backup. A change there is the same change as in the right click menu, which now starts with Options...; `/tgf settings` opens the page.
- **Backup page.** It shows the folder and the file that hold all your data (statistics, map spots, journal and the settings of every character of the account) in a box to copy, with the steps to move it to another computer or keep a backup. All settings can also be exported as one text and imported on another account; the text is only read as values and a checksum refuses an incomplete copy.
- **Icons in the lists.** Every list that names items shows the item's icon before the name: My materials, Lifetime materials, Observed chances, Crafting profit (the product), Unlearned recipes (the recipe item, or the spell a trainer teaches), Journal > Creature drops, Statistics (Attempts with the crafted item or the gathering profession, Materials and Gathered items), the reagent window, the auction history beside the Sell tab and the list of the Titan Panel entry. Professions carry their icon too: the trainers in the Trainers tab, the Profession columns of Unlearned recipes and Crafting profit, the profession tabs and headings of Gathered items, Learned professions and the Titan Panel list.
- **Search in Statistics.** Attempts and Materials in the professions Statistics have a search box (Escape clears it).

## Changed

- Statistics > Materials has the leading profession of each material and its share of the use, both sortable. History and sources > Reagent use estimates in the menu opens it.
- The main window has nine tabs: My materials is new and Reagent use is gone.
- Without Titan Panel the addon no longer prints that Titan Panel is required.

## Fixed

- The Reagent use tab of the main window showed the same estimate as Statistics > Materials in the professions window. The duplicate tab is removed; its columns are in Materials.
- The search box of the professions Statistics ran past the right edge of the panel, over the profession buttons beside the window. It now stretches from the view combo box to the edge and fits any window width.

## Upgrading

Install over the old folders and fully restart WoW. Your saved data and settings are kept. Titan Panel can stay installed or be removed. The thirteen optional modules carry the new version number and depend on the core only: their catalogue data is unchanged.
