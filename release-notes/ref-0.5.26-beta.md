# Titan Gathered Forever v3 0.5.26-beta

First beta. It contains everything since the last built download set, 0.4.2-alpha. Per-step history is in ref-unreleased.md. This text is the changelog for the website; the release itself is not published yet.

## Highlights

- Trainer and recipe vendor pins on the world map and minimap, with tooltips that show which recipes you already know.
- One window with tabs for the unlearned recipes and every statistics view, opened from a minimap button.
- A list of unlearned recipes with their trainers and vendors, including the next rank of each profession you have.
- Scrolling lists with search, grouping and Blizzard style combo boxes everywhere.

## Added

### Trainers and recipe vendors

- Optional pins for profession trainers and recipe vendors on the world map and minimap, with a per-profession filter and a switch for recording NPCs when their window opens. The pins work independently of the gathering map and never appear in instances.
- Pin tooltips: the NPC name in gold, role and confirmation state in gray (green when confirmed in game), then one recipe per line with the required skill and the price in gold, silver and copper icons. Recipes you already know are dimmed and tagged "learned". When a profession has never been read for the character, the tooltip says so instead of guessing. Profession ranks (Apprentice to Master) are judged by the skill you have.
- Trainers and merchants are recorded when you open their window, including the character level a trainer requires. A trainer with nothing left to teach you is recorded too. A diagnostic log of recording attempts is in the Diagnostics menu.
- The data is a bundled Classic seed of 458 trainers and recipe vendors that live observation replaces. Entries not yet seen in game read "Not yet confirmed in game".

### Unlearned recipes

- Every recipe with a known trainer or vendor source that the character has not learned, labelled Trainer or Vendor. Recipes that need more skill than you have are red. Professions never read for the character are named instead of guessed.
- For each profession you have, the next rank (for example Journeyman Fishing) is listed with its trainers, price and required skill, once your skill and character level allow it. The hover tooltip starts with the skill the addon read from the client.
- Hovering the NPC column shows every source with its role, price, zone and coordinates. Clicking a row opens the world map at that zone and marks every trainer and vendor of the recipe with red rings. The marks end when the map closes, when you click the row again, when you choose another recipe, or after five minutes.
- Filters for profession and source (all or vendors only), and a search box.

### One window and the minimap button

- A round TG3 button on the minimap edge. Left click opens or closes the window, right click opens the addon menu, dragging moves it around the minimap. Display > Show minimap button hides it.
- The window has classic tabs along the bottom: Unlearned recipes, Lifetime materials, Observed chances, Profession actions, Crafting and cooking, Reagent use and PvP Board. All tabs share one size and one remembered position and keep their own filters and scroll position.
- Every list scrolls with the mouse wheel and a scroll bar instead of Previous and Next buttons (only the export parts keep them). Lists have a search box. Observed chances can be grouped by item, with a button to expand the sources of each item.
- Every choice (profession, scope, source, grouping, export identity) is a Blizzard style combo box. If a client lacks the template, a button with a menu takes its place.

### Menu and diagnostics

- The right-click menu covers every function that needs no parameter: refresh, status report, summary paging, NPC recording log, nearest NPC pin and axis swap. `/tgf recipe <recipeID> [operations]` remains a documented command because it takes a parameter.
- Debug mode writes to a debug log that keeps the latest 1,000 lines in the saved variables file instead of printing to chat. Diagnostics can also show debug messages in chat and clear the log.
- Earlier refinements since 0.4.2-alpha: profession colors and mining pin statistics, near-cap skill colors, skill percentage bands, world-vein tooltips, tooltip and footer dividers and Titan label colors.
- LICENSE (GPL-3.0) and NOTICE are packaged with the core addon.

## Fixed

- The Fishing trainer tooltip no longer says "Learned status unknown" after the Fishing window was opened. Rank spells of every profession are shown as learned or not.
- Trainers whose services you have all learned were never recorded, because the client reports an empty list for them. They are recorded now.

## Data and evidence

The seed comes from CMaNGOS classic-db (GPL-3.0, pinned by commit and SHA-256) and is Classic 1.12.1 data. Observed data replaces seed data, and unknown skills and prices stay unknown. The catalogue is not marked complete.

## Verification and limitations

All automated checks and Lua 5.1 compilation of every shipped file pass. Checked live on WoW Forever 1.60.1: trainer recording, reading of known recipes, pin placement, tooltip layout, the combo boxes, the classic tabs and the rank rows. Still open: recipe vendor recording (price and required skill from the merchant tooltip), the zone and coordinates of seed NPCs, the look of the search box and of the grouped chances, and the other live checks in ref-wow-forever-progress.md. Trainers visited before 0.5.16 use classic character levels for their rank rows until they are opened again.

This update adds files, so the client needs a full restart, not only /reload. The addon targets WoW Forever 1.60.1, interface 16001, with Titan Panel installed separately.
