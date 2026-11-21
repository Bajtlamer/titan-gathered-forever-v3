# Titan Gathered Forever: Discovery 0.1.1

Small update to 0.1.0. This text is the changelog for the release page.

## Changed

- Recording starts by itself at the first login after the module is installed. A module that had to be switched on first was loaded and never used. The notice (what is recorded, what never is, how to pause and how to hand the data over) is printed at that first start and again whenever it changes; `/tgfd` shows it at any time. `/tgfd stop` pauses and the pause is kept after a reload; a changed notice never un-pauses.
- The Titan Panel plugin is now called "Titan Gathered Forever: Discovery" and uses the icon of the module, so it is clear that it belongs to Titan Gathered Forever.
- The window of the collected data also opens from the right click menu of the Titan Gathered Forever minimap button (and of the Titan entry): "Discovery: collected data". This needs Titan Gathered Forever 0.5.144 or newer; with an older core the menu entry is simply missing and `/tgfd show` still works.

## Upgrading

Install over the old folder. Data collected so far is kept. An installation that was never accepted starts recording at the next login.
