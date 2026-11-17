# Titan Gathered Forever

## Summary

Track profession materials, bag and bank counts, recipe uses, personal gathering history and observed map locations in WoW Forever with Titan Panel.

## Description

Titan Gathered Forever brings profession materials, recipe uses and your own gathering observations together in one place. See what supported items are used for, what you have in your bags and personal bank, and what your recorded history says about obtaining them.

### Features

- Material tooltips with profession uses and available bag/bank counts.
- Optional profession catalogues, so you can load the professions you want.
- Personal lifetime material history and observed acquisition rates.
- Outdoor gathering locations on the world map and minimap, with configurable icon appearance.
- Recipe browsing, trainer and recipe-vendor information, and reagent planning for supported recipes.
- Auction-price snapshots and crafting-profit estimates when suitable data is available.
- Titan Panel menus, a minimap launcher and separate controls for recording and map visibility.

### Requirements and installation

Requires WoW Forever 1.60.1 and Titan Panel. Install the `TitanGatheredForever` folder in `Interface/AddOns/`, alongside Titan, then add the profession modules you want. Each module has its own addon folder and requires the shared core.

Restart WoW after installing new folders or artwork. When upgrading from the previous folder names, migrate the saved files while WoW is closed to retain your existing history and settings.

### Getting started

1. Right-click the Titan entry or minimap launcher and choose your professions.
2. Open your personal bank to update the available bank snapshot.
3. Open profession windows so the addon can read available recipe information.
4. Enable the history and source recording options you want.
5. Left-click the minimap launcher to open the recipes and statistics window.

Use `/tgf recipe` after selecting a supported recipe, or `/tgf recipe <recipeID> [operations]`, to open its reagent plan. Other everyday controls are available through the right-click menu.

### Notes and limitations

Recorded rates describe your own complete observed samples. They are not guaranteed server drop rates. Earlier activity and periods when recording was disabled cannot be reconstructed. Cached bank quantities and auction prices are snapshots, and profit figures are estimates.

Catalogue completeness, live recipe availability and some client event sequences remain under verification. Unknown or unreadable evidence remains unknown. Outdoor map recording excludes instance and raid locations. The supported client is WoW Forever; compatibility with other WoW editions is outside the current scope.

### Reporting issues

Include the addon version, WoW Forever build, installed profession modules, steps to reproduce, and the expected and actual result. A screenshot and the exact Lua error are useful for display problems. Redact personal information before sharing saved files or logs.

## Upload reference (local notes)

Use **Summary** for the short project summary and **Description**, including its subsections, for the main project description. The notes below are preparation references and do not need to be pasted into the public description.

- Current local version: `0.5.84`.
- Intended client: WoW Forever 1.60.1, interface `16001`.
- Runtime folder: `TitanGatheredForever`.
- Dependencies and integrations: Titan Panel, installed separately.
- [400px PNG avatar](../artwork/v1/TitanGatheredForever/avatar-400.png)
- [1024px PNG logo](../artwork/v1/TitanGatheredForever/logo-1024.png)
- [64px PNG icon preview](../artwork/v1/TitanGatheredForever/icon-64.png)
- [Original generated PNG](../artwork/v1/TitanGatheredForever/master.png)
- [All artwork versions](../artwork/)

Suggested screenshots to capture in game: Material tooltip with bag/bank counts; personal gathering map; recipe reagent planner; lifetime material report.
