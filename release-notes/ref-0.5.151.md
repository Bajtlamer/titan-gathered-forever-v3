# Titan Gathered Forever 0.5.151

Update from 0.5.146. This text is the changelog for the website and the release page. Versions 0.5.147 to 0.5.150 were internal steps and are included here. The core has one new file (ColumnSort.lua), so fully restart the game once after updating; a plain reload is not enough.

## Added

- **Sorting by column in every window with columns.** A click on a column header sorts the Recipe browser, the Profit browser, the Trainer browser, the recipe reagent planner, Lifetime materials, Observed chances (also grouped by item), Reagent use, and every column of the Attempts, Materials and Gathered items views of Statistics. A text column starts from A to Z, a number column from the highest, a second click reverses it, and an arrow marks the column. A row without a value is always last, equal values are ordered by name so a list never jumps, and the chosen order of each window is saved. Until the first click each window keeps the order it had. Economy has no list and the PvP Board is a fixed statement, so neither sorts.
- **Sorting the Titan panel list.** Right click the Titan entry, Display > Sort items: Item ID (as before), Name, Most first or Fewest first. The order is inside each section, the count is bags plus bank when bank counts are shown, and the choice is saved.
- **Tabs in Gathered items.** The Gathered items view has an Overview tab (the summary of every gathering profession) and one tab for each installed gathering profession with its items in one table under one header.

## Changed

- In every Statistics view the extra texts are under the list, below a thin gold line that follows the "Showing a-b of n" counter, and they are shorter: a profession tab shows two summary lines, the "Measured since" date is no longer shown, and the explanations of Overview and Attempts are one line. A change of the order keeps the position in the list. The profession picker of Gathered items is replaced by the tabs.

## Fixed

- None. Behaviour of the other windows is unchanged.

## Upgrading

Install over the old folders and restart the game fully once. Your saved data and settings are kept. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
