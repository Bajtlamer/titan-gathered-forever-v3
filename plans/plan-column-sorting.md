# Plan: sorting by column in every window with columns, and by count in the Titan panel

Status: approved by the owner on 2026-11-24, in progress. Target version 0.5.147.

## Goal

1. Every Titan Gathered Forever window that shows data in columns sorts by a click on a column header, with the same rules as the Statistics panel: text columns go A to Z at the first click, numeric columns from the highest, the same column again reverses it, an arrow marks the sorted column, equal values keep a fixed order (name, then identity) so a list never jumps between two refreshes.
2. The Titan panel list of materials can be ordered by count.

## Design

### Shared helper `ColumnSort.lua` (new file, needs one full client restart)

- Pure logic, testable without a client: `ColumnSort.Compare(a, b, valueOf, state)` and `ColumnSort.Sort(rows, valueOf, state, tie)`. `valueOf(row, column)` returns a number or a lower-cased string, or nil for a row that has no value (nil sorts last in both directions). `state = { column, descending }`.
- `ColumnSort.Next(state, column, kind)`: the new state after a click (kind `text` starts ascending, `number` starts descending; the same column reverses).
- `ColumnSort.Attach(window, headerFrame, columns, options)`: turns the header cells of a window into buttons with an arrow texture, calls `options.onChange()` after a click, and saves the state in `ns.settings.columnSort[options.key]`. A column with `sortable = false` stays plain text. Reads the saved state at attach time.
- The default order of every window stays as it is today until the player clicks. A saved order is restored.

### Windows

| Window | File | Rows come from | Notes |
|---|---|---|---|
| Recipe browser | RecipeBrowser.lua | `ns.NpcSources.Unlearned` | all six columns, price numeric, Where by the first source name |
| Profit browser | ProfitBrowser.lua | `ns.Profit.Rows` | Materials, Auction after fee, Profit and the other price columns numeric |
| Trainer browser | TrainerBrowser.lua | NPC sources | Coordinates sort by zone then x |
| Crafting planner | CraftingView.lua | `View.Sorted(plan.rows)` | Need, Bags, Bank numeric; the default stays "missing first" |
| Reports tabs | Reports.lua | per view layout | every column of every tab where the value is a single comparable value |
| Statistics (Professions window) | ProfessionStats.lua | `View.SortRows` | every column of the three views is sortable, including Gathered (today only Quantity and Total value); moves to the shared helper |
| Economy | EconomyView.lua | fixed rows | no sorting: the rows are the fixed sources of income, not a list |

### Titan panel

- New setting `ns.settings.titanSort` with the values `id` (default, as today), `name`, `most`, `fewest`.
- The menu of the Titan entry gets a "Sort items" submenu with these four radio entries. The choice is saved and the tooltip refreshes at once.
- Sorting stays inside each group (section). The count is bags plus bank, the bank only when Show bank is on, which is what the panel shows. Ties go to the name, then the item ID.

## Tests (TDD: red first)

- `tests/column_sort.lua`: Compare/Sort/Next rules (text, number, nil last, ties, reverse), saved state, `Attach` with the stub frames.
- One test block per window: a click on a header reorders the visible rows and the arrow moves; the saved state restores the order.
- `tests/titan_sort.lua` (or an addition to the existing Titan test): the four modes, the group order kept, bank counted only when shown, tie breaking, the menu entries.
- `python3 tools/check.py` stays green; the new file is added to the toc and to the file list of the checks.

## Order of work

1. ColumnSort.lua and its tests.
2. Titan panel sorting and menu.
3. Recipe, Profit, Trainer browsers.
4. Crafting planner.
5. Reports tabs.
6. Statistics onto the shared helper, with all columns sortable.
7. Docs (README, release-notes/ref-unreleased.md), version 0.5.147, install, full restart note.

Release to GitHub, CurseForge and the website only on the owner's request.
