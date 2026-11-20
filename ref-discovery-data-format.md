# Discovery data format

Reference for the saved table of Titan Gathered Forever: Discovery (folder TitanGatheredForever_Discovery, version 0.1.0). The table is TitanGatheredForeverDiscoveryDB in WTF/Account/<account>/SavedVariables/TitanGatheredForeverDiscoveryDB.lua. It is separate from the saved table of the core. See [the plan](plans/plan-discovery-module.md) for the design and [the contributor guide](book-discovery-contributors.md) for the steps.

Everything below is an observation: a count with times and builds, not a verified fact. Nothing in it changes the catalogue by itself.

## Top level

| Key | Content |
|---|---|
| meta | schemaVersion (1), moduleVersion, createdAt, createdWith, client (version, build, date, interface, locale) and builds (build number to the time it was first seen) |
| consent | accepted, paused, version (of the notice), acceptedAt |
| data | one table per category, see below |
| compare | counts of the last comparison: ranAt, baselineVersion, targetBuild, clientBuild, modules, counts per category, totals, notSeen. Rows are not saved. |
| export | the stamp of the last export: schemaVersion, exportedAt, moduleVersion, client, builds, baselineVersion, counts, total, checksums per category, checksum, session, archived |
| archives | one small entry per archive: archivedAt, exportedAt, total, counts, checksum |
| reviewed | local review marks, "category:key" to the time they were set |

A table whose meta.schemaVersion is higher than the module knows is left untouched and collection is blocked.

## Records

Every record has seen (how often), first and last (time), firstBuild and lastBuild. Keys are numeric IDs unless noted.

| Category | Key | Fields |
|---|---|---|
| loot | item ID | name, quality, offered (quantity), taken, sources ("Creature:ID" or "GameObject:ID" to count), unsourced, areas (area key to count) |
| npcs | creature ID | name, minLevel, maxLevel, classification, creatureType, family, services (gossip, vendor, trainer, quest, flight, bank, repair to count), positions (at most five, outside instances: mapID, x, y), areas, lootSources |
| vendors | creature ID | goods (item ID to price, stack, stock, extendedCost, seen), taught (lesson name to cost, skillName, skillRank, level), scans |
| entities | "GameObject:ID" | kind, id, name, services, lootSources |
| quests | quest ID | title, giver ("Creature:ID" or "GameObject:ID"), accepted, turnedIn, rewards (item IDs), areas |
| areas | "mapID\|real zone\|zone\|subzone\|instance" | mapID, parentMapID, realZone, zone, subZone, instanceName, instanceType |
| skills | profession name | rank, maxRank |
| recipes | recipe ID | name, profession, professionID, parentProfessionID, outputItemID, quantityMin, quantityMax, reagents (list of quantity and items) |
| maps | map ID | name, mapType, parentMapID |

## What is never recorded

Chat, whispers, mail text, gossip text, quest text, player and pet GUIDs, player names, pet names, guild names and anything about the auction house. The privacy check (/tgfd audit, and the first part of /tgfd export) searches every string and key for a player or pet GUID and for the name of the current character, and an export is refused when it finds one.

## Checksums

The export stamp holds one checksum per category and one over all of them. A category checksum is the Adler-32 of a canonical text, written as eight lowercase hexadecimal digits (the high sixteen bits first). The text is the concatenation, for the keys of the category in a fixed order, of key, "=", record and ";". Keys are ordered by value when both are numbers, alphabetically when both are strings and by their text otherwise. Tables are written as "{" and, for every key in that order, key, "=", value and ","; then "}". Strings are written with the Lua %q format and numbers and booleans with tostring. The total checksum is the Adler-32 of the category checksums in category order, joined with commas. It is an integrity check, not a security feature.
