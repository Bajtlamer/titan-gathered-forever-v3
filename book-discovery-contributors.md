# Discovery contributor guide

Steps for anyone who wants to help collect data with Titan Gathered Forever: Discovery. The module is a diagnostic tool, not a player feature. It reads what the game client shows and keeps it so that new or different data can be compared with the Titan Gathered Forever catalogue. You only hand data over; you decide when.

## Before you start

- Install the TitanGatheredForever_Discovery folder next to Titan, Titan Gathered Forever and its profession modules. It is not part of the published downloads.
- Type /tgfd. The module prints a notice that says what it records and what it never records. It records nothing until you type /tgfd accept.
- You can pause with /tgfd stop and resume with /tgfd start at any time.

## What happens while you play

Once accepted, the module records loot, NPCs and objects you meet, vendor and trainer goods, quests, the areas you enter, profession skills and the client build. It never records chat, mail, gossip or quest text, player or pet names or GUIDs, or anything about the auction house. The Titan Panel plugin shows counts, and /tgfd show opens the overview window.

## Scans and comparison

These run only when you type them, show their progress and can be cancelled with /tgfd cancel. Expect a little lag while one runs, and do not start one in a fight.

- /tgfd compare compares what was observed with the data of Titan Gathered Forever and updates the counts.
- /tgfd scan recipes reads the recipes of a profession window that you opened yourself, also the ones you have not learned.
- /tgfd scan areas [number] reads the map IDs of the client.
- /tgfd selftest shows the progress window with a harmless test.

## Handing data over

1. Type /tgfd export. It checks the data for private values and stamps them with versions and checksums. If it finds a private value it refuses and names where.
2. Type /reload, or log out, so the game writes the file.
3. Send TitanGatheredForeverDiscoveryDB.lua from WTF/Account/<your account>/SavedVariables/ to the owner. Nothing is sent by the game itself.

## Clearing the data afterwards (optional)

The file can grow, which lengthens login a little. After a hand-over you can clear the data from the game:

1. /tgfd stop, then /tgfd export, then /reload and copy the file.
2. /tgfd archive confirm clears the observations only if recording is stopped, the file was saved after the export and the data are unchanged since. Otherwise it clears nothing and says why.

The format of the file is described in [the data format reference](ref-discovery-data-format.md).
