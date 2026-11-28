# Titan Gathered Forever 0.5.177

Update from 0.5.172. This text is the changelog for the website and the release page. Versions 0.5.173 to 0.5.176 were internal steps and are included here. New files were added and the manifests changed: fully restart WoW after updating, a reload is not enough.

## Added

- **Works without Titan Panel.** Titan Panel is now optional. With it, Titan Gathered Forever is a Titan Panel plugin as before. Without it, the addon runs on its own: pointing at the minimap button shows the material list (the mouse wheel turns its pages), the right click menu of the minimap button is the same menu as on the Titan Panel entry, the world map button keeps the map options, and every setting is in the game Options window. Other panel displays of the LibDataBroker library (ChocolateBar, Bazooka and similar) show the entry too. The profession modules need only the core.
- **Settings in the game Options window.** Esc > Options > AddOns > Titan Gathered lists the settings on pages: General, Material list, Professions, Map pins, Gathering spots, Map materials, Travel routes, Auction house, Diagnostics and Backup. A change there is the same change as in the right click menu, which now starts with Options...; `/tgf settings` opens the page.
- **Backup page.** It shows the folder and the file that hold all your data (statistics, map spots, journal and the settings of every character of the account) in a box to copy, with the steps to move it to another computer or keep a backup. All settings can also be exported as one text and imported on another account; the text is only read as values and a checksum refuses an incomplete copy.
- **Search in Statistics.** Attempts and Materials in the professions Statistics have a search box (Escape clears it).

## Changed

- Statistics > Materials has the leading profession of each material and its share of the use, both sortable. History and sources > Reagent use estimates in the menu opens it.
- The main window has eight tabs, which leaves room for later ones.
- Without Titan Panel the addon no longer prints that Titan Panel is required.

## Fixed

- The Reagent use tab of the main window showed the same estimate as Statistics > Materials in the professions window. The duplicate tab is removed; its columns are in Materials.

## Upgrading

Install over the old folders and fully restart WoW. Your saved data and settings are kept. Titan Panel can stay installed or be removed. The thirteen optional modules carry the new version number and depend on the core only: their catalogue data is unchanged.
