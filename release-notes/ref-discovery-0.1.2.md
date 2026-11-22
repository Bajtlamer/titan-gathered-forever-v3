# Titan Gathered Discovery 0.1.2

Update to 0.1.0. This text is the changelog for the release page.

## Changed

- Recording starts by itself at the first login after the module is installed. A module that had to be switched on first was loaded and never used. The notice (what is recorded, what never is, how to pause and how to hand the data over) is printed at that first start and again whenever it changes; `/tgfd` shows it at any time. `/tgfd stop` pauses and the pause is kept after a reload; a changed notice never un-pauses.
- The module is called Titan Gathered Discovery everywhere: the Titan Panel plugin (with the icon of the module), the window, the addon list and the menu.
- The window has two tabs. Collected data is the overview of what is new, different or not seen. How it works explains what the module is, what it records and never records, how it works, what the data are used for and how to hand them over by Discord or e-mail.
- The window of the collected data also opens from the right click menu of the Titan Gathered Forever minimap button (and of the Titan entry): "Titan Gathered Discovery". This needs Titan Gathered Forever 0.5.144 or newer; with an older core the menu entry is simply missing and `/tgfd show` still works.

## Fixed

- The hand-over text named the file `TitanGatheredForeverDiscoveryDB.lua`, which is the name of the variable. The game writes the saved variables of this module to `TitanGatheredForever_Discovery.lua` in `WTF/Account/<account>/SavedVariables`; that is the file to send.

## Upgrading

Install over the old folder. Data collected so far is kept. An installation that was never accepted starts recording at the next login.
