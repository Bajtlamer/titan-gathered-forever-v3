# Titan Gathered Discovery

## Summary

Helps complete Titan Gathered Forever: it quietly records what the WoW Forever client shows, and you can hand the saved file to the author to fill in missing data.

## Description

Titan Gathered Discovery is a data-collection companion for Titan Gathered Forever. It is not a player feature and nothing changes in your game because of it. It watches what the client already shows (loot and where it came from, NPCs, vendors, trainers, quests, zones, professions and recipes), keeps small records, and compares them with the data Titan Gathered Forever ships, so that missing or different facts can be found, checked and added.

**Nothing is ever sent by the game.** The module only saves a file on your computer. If you want to help, you send that file to the author yourself, when you decide to. The steps are below.

### Why it exists

The catalogue of Titan Gathered Forever (recipes, trainers, vendors, item sources, map areas) can only be as complete as what has been seen in the live game. One player sees a small part of the world. Many players together see most of it. Every file you hand over helps the author find what is missing or wrong, so that the next release of Titan Gathered Forever is more accurate for everyone.

### Features

- Starts recording by itself when the module is installed. Nothing to switch on, nothing to configure.
- Records loot and its sources, NPCs and objects you talk to or target (IDs, names, services, vendor and trainer goods and prices), quests (not their text), the areas you enter, profession skills and the client build.
- Keeps a count, the first and last time seen and the client build with every observation, so a difference seen on another build is not mistaken for an error.
- An overview window with two tabs: Collected data (what is new, different or not seen, with filters, search and the detail of every row) and How it works (what is recorded, how it is used and how to hand it over).
- Opens from the right click menu of the Titan Gathered Forever minimap button ("Titan Gathered Discovery"), from the Titan Panel plugin, or with `/tgfd show`.
- A Titan Panel plugin "Titan Gathered Discovery" with the number of records.
- Scans run only when you type a command, show their progress and can be cancelled.
- Checks the data for private values before an export, refuses to go on if it finds one, and stamps the export with versions and checksums.

### What it records

- Everything you loot and the source it came from (a creature, an object, a container).
- NPCs and objects you talk to or target: ID, name, services, what a vendor sells and what a trainer teaches.
- Quests you see or take: the IDs and names, never the quest text.
- Zones and areas you enter: map IDs and names.
- Your profession skills and, when you open a profession window yourself, its recipes.
- The WoW Forever client build and the versions of the addons.

### What it never records

Chat, whispers, mail text, gossip or quest text, player or pet names or GUIDs, guild names, and anything about the auction house (the module does nothing with the auction house at all). Before the data can be exported, an automatic audit looks for private values and refuses to export if it finds any.

### Requirements and installation

Requires **WoW Forever 1.60.1**, **Titan Panel** and the **Titan Gathered Forever shared core**. The menu entry on the minimap button needs the core 0.5.144 or newer; with an older core the window still opens with `/tgfd show`.

1. Install the `TitanGatheredForever_Discovery` folder into `Interface/AddOns/`, next to `TitanGatheredForever` and Titan.
2. Fully restart WoW (a new addon needs a restart, `/reload` is not enough the first time).
3. At the first login a notice appears in chat. From then on the module records while you play.

Upgrading: install over the old folder. Data collected so far is kept.

## How to send the data to the author

The author reads the files that players hand over, merges them by ID and build, and reviews every candidate by hand before anything is added to the Titan Gathered Forever catalogue. Observations are unverified: they are never published with your name and they never change the catalogue by themselves.

You do not need to send anything regularly. A good time to send is after you have played a while, visited new zones, opened profession windows or talked to vendors and trainers. The more varied the play, the more useful the file.

### Step by step

1. **Play as usual.** The module records quietly. Type `/tgfd status` to see what has been recorded.
2. **Optional but useful:** open the window (minimap button menu, Titan Panel plugin or `/tgfd show`), then type `/tgfd compare` to compare with the catalogue. This shows you what is new and what differs. It is not required for sending.
3. **Export.** Type `/tgfd export`. The module checks the data for private values and stamps them with versions and checksums. If it finds a private value it refuses and says where. (`/tgfd audit` runs the check alone.)
4. **Save the file.** Type `/reload` or log out. WoW writes saved variables only at those moments, so the file is not current before that.
5. **Find the file.** It is called `TitanGatheredForever_Discovery.lua` and lives in the saved variables folder of your account:

   `<WoW folder>/_forever_/WTF/Account/<your account name>/SavedVariables/TitanGatheredForever_Discovery.lua`

   On a Mac the WoW folder is usually `/Applications/World of Warcraft`. On Windows it is the folder you installed WoW into, for example `C:\Program Files (x86)\World of Warcraft`. The file is in the `_forever_` folder, not in `_retail_` or `_classic_`. Send only this file.
6. **Send it to the author** by either way:
   - **Discord:** send a direct message to **`_bajt`** and attach the file.
   - **E-mail:** write to **bajtlamer@gmail.com** and attach the file.

   If the file is too large for your mail or Discord, put it in a ZIP first. Add a line with your WoW Forever client build if you know it, and anything you noticed that looked wrong. The file already carries the module and core versions.
7. **Optional, clear the data afterwards.** The file can grow over time, which lengthens login a little. After a hand-over you can clear it from the game: `/tgfd stop`, then `/tgfd export`, then `/reload`, copy the file, then `/tgfd archive confirm`. It clears nothing if the data changed since the export, and it clears only the records of this module and never touches your Titan Gathered Forever data or settings. Then `/tgfd start` resumes recording.

### What is in the file

Counts and identifiers of what you saw: item, NPC, object, quest, skill, recipe and area IDs with names, the observed relations between them (for example this vendor sells this item, this creature dropped this item), first and last seen, how often, and the client build. No chat, no mail, no gossip or quest text, no player or pet names, no GUIDs and nothing about the auction house. You can open the file in any text editor and read it before you send it. Nothing in it is executed by the author: it is read as data and compared with the catalogue by an offline tool.

### Commands

| Command | What it does |
|---|---|
| `/tgfd` | Shows the notice and the list of commands |
| `/tgfd show` | Opens the window |
| `/tgfd status` | State, versions and the number of records |
| `/tgfd stop` and `/tgfd start` | Pause and resume recording (a pause is kept after a reload) |
| `/tgfd compare` | Compares your observations with the Titan Gathered Forever data |
| `/tgfd scan recipes` | Reads the recipes of the profession window you opened yourself, also the ones you have not learned |
| `/tgfd scan areas` | Reads the map IDs of the client |
| `/tgfd audit` | Checks the data for private values |
| `/tgfd export` | Checks and stamps the data for hand-over |
| `/tgfd archive` | Clears exported data from the game, with safeguards (`/tgfd archive confirm`) |
| `/tgfd cancel` | Stops a running scan or comparison |
| `/tgfd selftest` | A harmless test of the progress window |

### Questions and problems

- **The window list is empty.** Choose "Everything observed" in the filter; it lists the records at once. The other lists (New and different, Different) need `/tgfd compare` first, and the window header says so.
- **I cannot find the file.** Run `/tgfd export`, then `/reload`, and look in the `_forever_/WTF/Account/<account>/SavedVariables/` folder. If your account folder has a different name than you expect, check which account folders exist; there can be more than one.
- **The file is old or missing the latest play.** WoW writes it only on `/reload` or logout. Do one of them first.
- **Does it slow the game down?** Recording only listens to a few game events and keeps small records. Scans and the comparison show a short, visible load, which is why they start only on a command. Do not start one in a fight.
- **Can I stop it?** Yes, `/tgfd stop` at any time, or disable the addon on the character select screen. Your records stay in the file until you clear them.
- **Who sees my data?** Only the person you send the file to. The game itself sends nothing anywhere.
- **Will my name appear anywhere?** No. Observations are merged by ID and build, they are not published with a name, and the file holds no player names.
- **Something looks wrong in the catalogue.** That is exactly what the module is for. Send the file, and mention the item, NPC or recipe by name or ID.

### Notes and limitations

Everything recorded is an observation, not a verified fact. Several client calls (recipe schematics, map information, quests) are still being verified on the live client, so some categories may be sparse. The module records only what the client shows you: it cannot see places you have not been to or things you have not looted, which is why files from many different players are valuable.

### Reporting issues

Include the module and core versions (`/tgfd status`), the client build, the command you used and what you expected. Do not attach the saved file to a public comment on this page; send it to the author directly on Discord (`_bajt`) or by e-mail (bajtlamer@gmail.com).

## Upload reference (local notes)

Use **Summary** for the short project summary and **Description**, including its subsections, for the main project description. The notes below are preparation references and do not need to be pasted into the public description.

- Current local version: `0.1.5`. This module has its own version line and is released separately from the shared core and its profession modules. Release notes: [ref-discovery-0.1.5.md](../release-notes/ref-discovery-0.1.5.md).
- Intended client: WoW Forever 1.60.1, interface `16001`.
- Runtime folder: `TitanGatheredForever_Discovery`.
- Dependencies and integrations: Titan Panel and the Titan Gathered Forever shared core are required. Add the core as a required dependency on the CurseForge project page (project `titan-gathered-forever`, ID 1810955).
- Project name: `Titan Gathered Discovery`. Suggested slug: `titan-gathered-discovery`. Project type: World of Warcraft Addons.
- Package: `python3 tools/package.py --standalone` builds `dist/standalone/TitanGatheredForever_Discovery-0.1.5/` with the ZIP, `downloads.json` and `SHA256SUMS`. The ZIP is also on the GitHub release `v0.5.144` and on the website. See [the release book](../book-releases.md).
- Upload with `tools/curseforge_upload.py` once the project exists: add `'TitanGatheredForever_Discovery': (<project id>, 'titan-gathered-discovery')` to `PROJECTS`, use the standalone ZIP (`TitanGatheredForever_Discovery-0.1.5.zip`) and the notes of `release-notes/ref-discovery-0.1.5.md`, and add the project ID to `ref-curseforge-project-ids.md`. The script builds the file names of the core and module ZIPs (`<folder>-<version>.zip`), which is also the name of the standalone ZIP, but it looks in `dist/releases/<version>`; pass `--release-dir dist/standalone/TitanGatheredForever_Discovery-0.1.5` and extend it to skip the other folders (`--only`).
- [400px PNG avatar](../artwork/v1/TitanGatheredForever_Discovery/avatar-400.png)
- [1024px PNG logo](../artwork/v1/TitanGatheredForever_Discovery/logo-1024.png)
- [64px PNG icon preview](../artwork/v1/TitanGatheredForever_Discovery/icon-64.png)
- [Master PNG](../artwork/v1/TitanGatheredForever_Discovery/master.png), drawn by `tools/generate_discovery_art.py` (not an image-model render, see [the artwork prompts](../artwork/v1/prompts.json)).
- [Contributor guide](../book-discovery-contributors.md) and [data format](../ref-discovery-data-format.md).

Suggested screenshots to capture in game: the window on the Collected data tab with Everything observed; the How it works tab (it shows the Discord and e-mail contacts); the right click menu of the minimap button with the Titan Gathered Discovery entry; the Titan Panel plugin with its tooltip; the first notice in chat.
