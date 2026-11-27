# Titan Gathered Forever 0.5.167

Update from 0.5.164. This text is the changelog for the website and the release page. Versions 0.5.165 and 0.5.166 were internal steps and are included here. New files were added: fully restart WoW after updating, a reload is not enough.

## Added

- **Journal tab.** A new tab in the main window (History and sources > Journal in the Titan menu, `/tgf journal`). A combo box picks the view: Levels, Quests, Creatures, Creature drops, Rare creatures, Deaths and Reputation. Every view has a character box, a search box (Escape clears it), sortable column headers and a scroll bar. Kills and Quests in the Titan menu, `/tgf kills` and `/tgf quests` open the Journal at those views.
- **Kills.** Creatures each character killed, from the killing blows the game reports: yours (your pet included) and your group's. Each creature has its level range, type, experience per kill, money per looted corpse, the zone where it was killed most and the last kill. The combat log is restricted on Forever and is not used; a kill whose identity the client hides is counted in the footer, never guessed. Experience per kill is measured only when exactly one kill met one experience gain.
- **Creature drops.** What each creature had in its loot window the first time a corpse was opened, taken or not, with the chance per looted corpse and the average quantity. Search for an item to see which creatures drop it. Pickpocketing, skinning and fishing are not counted here.
- **Rare creatures.** Rare and rare elite creatures seen on the realm by any of your characters, with times seen, your kills, zone, coordinates and last sighting. A click shows the place on the map.
- **Quests.** Every quest a character accepted, turned in or abandoned: status, turn-ins, experience, money, the average time from accepting to turning in, the zone of the turn-in and the last activity. The row tooltip adds the quest giver, the NPC it was turned in to and the items received with the chosen reward; a click shows the giver on the map. Quest names come from the game and are not saved.
- **Levels.** When each level was reached, the time logged in at it, experience from kills, quests and other sources, and the kills, quests and deaths at that level. The level under way when recording began shows its time as a lower bound.
- **Deaths.** When, where, at which level, in which kind of place and what dealt the lethal blow, from the death recap when the game gives it.
- **Reputation.** Per faction: gained and lost in total, today and in the last 7 days, and the number of gains, found by comparing the standings whenever they change.
- **Map pins for quest givers and rare creatures**, with their own switches: Show quest givers and Show rare creatures in the world map's Map options and in the Titan menu under Trainers, vendors and other pins (renamed from Trainers and recipe vendors). Like every other switch they only hide the pins; recording goes on.

## Changed

- **Windows fit every screen.** The main window and its tab strip are scaled down when the screen is smaller than the window (a low resolution or a large UI scale), refitted after a resolution or UI scale change, and kept on screen including the tabs. When the tab names are wider than the window, the strip shrinks as one piece instead of running past the edge.

## Fixed

- The sort arrow of a number column was drawn over the header text in every window. It now follows the text.

## Upgrading

Install over the old folders and fully restart WoW. Your saved data and settings are kept. Kill counts and quest acceptance start with this update; turn-ins recorded before it keep their money, but their experience, zone and time stay unknown. No positions are recorded inside instances. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
