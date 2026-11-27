# Titan Gathered Forever 0.5.171

Update from 0.5.167. This text is the changelog for the website and the release page. Versions 0.5.168 to 0.5.170 were internal steps and are included here. No new files were added: a plain reload is enough after updating.

## Changed

- **Quest pins show only quests in progress.** A quest giver gets a pin only while your character has a quest from them in the quest log. The pin disappears when the quest is turned in or abandoned. The quest log is asked directly, so the pins follow it even after playing without the addon.
- **A silver question mark instead of the yellow exclamation mark.** The addon never draws the yellow exclamation mark any more: on the map and the minimap it is the game's own sign of a quest that can still be taken. A quest in progress is the game's silver question mark with a small drop shadow, so it reads on light maps.
- **Renamed switch.** "Show quest givers" is now "Show quests in progress", in the world map's Map options and in the Titan menu under Trainers, vendors and other pins.
- **Tooltip.** The pin tooltip lists the quests in progress first, then the earlier quests from that NPC.
- A quest giver opened from the Quests list of the Journal whose quests are all done is shown with a plain note icon.

## Fixed

- Every NPC a quest had ever been taken from looked like an available quest on the map and minimap, because the quest giver pins used the game's yellow exclamation mark.

## Upgrading

Install over the old folders. Your saved data and settings are kept. A pin is placed where you stood when you accepted the quest, next to the quest giver. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
