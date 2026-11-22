# Titan Gathered Discovery

## Summary

A data-collection companion for Titan Gathered Forever: it records what the WoW Forever client shows and compares it with the catalogue, so that new or different data can be found.

## Description

Titan Gathered Discovery is a diagnostic tool for the owner of Titan Gathered Forever and for contributors who choose to help. It is not a player feature. It watches what the game client already shows (loot, NPCs, vendors, trainers, quests, zones, professions and recipes), keeps it, and compares it with the data of Titan Gathered Forever so that missing or different facts become visible. Nothing is sent anywhere: if you want to help, you hand the saved file over yourself.

### Features

- Records loot and its sources, NPCs and objects you meet, vendor goods and prices, trainer lessons, quests, areas and zone names, profession skills and the client build.
- Keeps a count, the first and last time and the client build with every observation, so a difference seen on another build is not mistaken for an error.
- Compares the observations with the data of Titan Gathered Forever and shows what is new, different or unchanged in an overview window (`/tgfd show`).
- Adds a read-only Titan Panel plugin with the numbers of what has been found.
- Scans only when you type a command, with a progress window and a way to cancel: recipes of the profession window you opened yourself, and the map IDs of the client.
- Checks the data for private values before an export, and stamps it with versions and checksums.

### What it never records

Chat, whispers, mail, gossip and quest text, player and pet names or GUIDs, guild names, and anything about the auction house. The module does nothing with the auction house at all.

### Requirements and installation

Requires **WoW Forever 1.60.1**, **Titan Panel** and the **Titan Gathered Forever shared core**. Install the `TitanGatheredForever_Discovery` folder in `Interface/AddOns/`, alongside `TitanGatheredForever` and Titan, then restart WoW. It does not need any profession module, but the comparison is more useful with the profession modules you use.

### Getting started

1. Install the module. It starts recording by itself at the first login and prints a notice that says what is recorded and what is not (`/tgfd` shows it again).
2. Play as usual. `/tgfd status` shows what has been recorded, and `/tgfd stop` and `/tgfd start` pause and resume.
3. Open the window (the minimap button menu, the Titan Panel entry or `/tgfd show`): the second tab, How it works, explains the module and how to hand data over.
4. Type `/tgfd compare` to compare with the Titan Gathered Forever data, then `/tgfd show` to see the result.
5. To help the owner: `/tgfd export`, then `/reload`, then send `TitanGatheredForever_Discovery.lua` from `WTF/Account/<your account>/SavedVariables/`. The file contains only what the notice lists. Send it on Discord (`_bajt`) or by e-mail (bajtlamer@gmail.com).

### Notes and limitations

Everything recorded is an observation, not a verified fact, and nothing recorded here changes the catalogue by itself. Scans and the comparison cause a short, visible load, which is why they only start on a command. A large saved file lengthens login a little; `/tgfd archive confirm` clears exported data from the game when it is safe to do so. Several client calls (recipe schematics, map information, quests) are still being verified on the live client.

### Reporting issues

Include the module and core versions, the client build, the command you used and what you expected. Do not attach the saved file to a public report; send it to the owner directly.

## Upload reference (local notes)

Use **Summary** for the short project summary and **Description**, including its subsections, for the main project description. The notes below are preparation references and do not need to be pasted into the public description.

- Current local version: `0.1.0`. This module has its own version line and is released separately from the shared core and its profession modules.
- Intended client: WoW Forever 1.60.1, interface `16001`.
- Runtime folder: `TitanGatheredForever_Discovery`.
- Dependencies and integrations: Titan Panel and the Titan Gathered Forever shared core are required.
- Package: `python3 tools/package.py --standalone` builds `dist/standalone/TitanGatheredForever_Discovery-0.1.0/` with the ZIP, `downloads.json` and `SHA256SUMS`. See [the release book](../book-releases.md).
- [400px PNG avatar](../artwork/v1/TitanGatheredForever_Discovery/avatar-400.png)
- [1024px PNG logo](../artwork/v1/TitanGatheredForever_Discovery/logo-1024.png)
- [64px PNG icon preview](../artwork/v1/TitanGatheredForever_Discovery/icon-64.png)
- [Master PNG](../artwork/v1/TitanGatheredForever_Discovery/master.png), drawn by `tools/generate_discovery_art.py` (not an image-model render, see [the artwork prompts](../artwork/v1/prompts.json)).
- [Contributor guide](../book-discovery-contributors.md) and [data format](../ref-discovery-data-format.md).

Suggested screenshots to capture in game: the overview window after a comparison; the progress window during a scan; the Titan Panel plugin with its tooltip; the first notice in chat.
