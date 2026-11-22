# Titan Gathered Discovery 0.1.5

Update to 0.1.0. This text is the changelog for the release page.

## Changed

- Recording starts by itself at the first login after the module is installed. A module that had to be switched on first was loaded and never used. The notice (what is recorded, what never is, how to pause and how to hand the data over) is printed at that first start and again whenever it changes; `/tgfd` shows it at any time. `/tgfd stop` pauses and the pause is kept after a reload; a changed notice never un-pauses.
- The module is called Titan Gathered Discovery everywhere: the Titan Panel plugin (with the icon of the module), the window, the addon list and the menu.
- The window has two tabs. Collected data is the overview of what is new, different or not seen. How it works explains what the module is, what it records and never records, how it works, what the data are used for and how to hand them over by Discord or e-mail.
- The window of the collected data also opens from the right click menu of the Titan Gathered Forever minimap button (and of the Titan entry): "Titan Gathered Discovery". This needs Titan Gathered Forever 0.5.144 or newer; with an older core the menu entry is simply missing and `/tgfd show` still works.

## Fixed

- The rows of the list no longer run into each other: every cell is one line and a long text is cut. An area shows its name (the zone, the zone and subzone, or the instance) and its map number instead of its long internal key, and a profession does not repeat its name in the ID column.
- The columns use the whole width: Last seen ends at the right edge of the list, Category has room for "Vendors and trainers" (it was cut) and the name takes the rest.
- The column Notes was always empty before a comparison and took a third of the width. It is gone; the name gets the room. The state says how many differences a row has (Different (2)) and whether it was marked as reviewed, and the detail of the row says if it was seen on another build or on more than one build.
- The tabs at the bottom of the window were cut ("Collecte...", "How it w..."): they are fitted to their text when the window is built.
- The list of the window was empty before a comparison had run in the session, even with Everything observed selected, while the Titan Panel plugin counted the records. Everything observed now lists the observed records at once (state Observed); New and different, Different and the other lists still need `/tgfd compare`, and the header says so.
- The hand-over text named the file `TitanGatheredForeverDiscoveryDB.lua`, which is the name of the variable. The game writes the saved variables of this module to `TitanGatheredForever_Discovery.lua` in `WTF/Account/<account>/SavedVariables`; that is the file to send.

## Upgrading

Install over the old folder. Data collected so far is kept. An installation that was never accepted starts recording at the next login.
