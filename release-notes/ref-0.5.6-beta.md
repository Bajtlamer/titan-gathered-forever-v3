# Titan Gathered Forever v3 0.5.6-beta

First beta. It contains everything since the last built download set, 0.4.2-alpha. Per-step history is in ref-unreleased.md.

## Added

- Profession trainer and recipe vendor pins on the world map and minimap, with menu toggles, a per-profession filter and a switch for recording NPCs when their window opens. Pins work independently of the gathering map and never appear in instances.
- Pin tooltips: the NPC name in gold, role and confirmation state in gray (green when confirmed in game), a separator, then one recipe per line with the required skill in brackets after the name and only the price on the right, in gold, silver and copper icons. Known recipes are marked. The text uses the small tooltip font.
- Unlearned recipes window (menu): recipes the character has not learned with a Trainer or Vendor source, a vendor-only filter, a profession filter, green NPC names, and a hover tooltip with every source's role, price, zone and coordinates. Clicking a row opens the map. Professions never read for the character are named, not guessed.
- Recording of trainers, merchants and known recipes from the client windows. A diagnostic log of recording attempts is available in Diagnostics.
- The right-click menu now covers every function that needs no parameter: refresh, status report, summary paging, NPC recording log, nearest NPC pin and axis swap. `/tgf recipe <recipeID> [operations]` remains the documented command because it takes a parameter.
- Earlier unreleased refinements since 0.4.2-alpha: profession colors and mining pin statistics, near-cap skill colors, skill percentage bands, world-vein tooltips, tooltip and footer dividers and Titan label colors. See ref-unreleased.md.
- LICENSE (GPL-3.0) and NOTICE are packaged with the core addon.

## Data and evidence

The seed of 458 trainers and recipe vendors comes from CMaNGOS classic-db (GPL-3.0, pinned by commit and SHA-256) and is Classic 1.12.1 data. It is shown as not yet confirmed in game until the NPC window is opened. Observed data replaces seed data, and unknown skills and prices stay unknown. Live checks on WoW Forever showed that Forever has recipes the seed lacks and that trainer and merchant lists arrive on update events, which the addon now handles.

## Verification and limitations

All automated checks and Lua 5.1 compilation of every shipped file pass. Live acceptance on WoW Forever 1.60.1 so far confirms trainer recording (profession, skills, costs), known recipe reading, pin placement near NPCs and the tooltip layout. Still open: recipe vendor recording (price and required skill read from the merchant tooltip), the zone and coordinates of seed NPCs, and the other live gates listed in ref-wow-forever-progress.md. Beta means the feature set is complete for this stage and the remaining work is acceptance and fixes. The catalogue is not marked complete.

New files and manifest entries need a full client restart; Lua-only updates need only /reload. The addon targets WoW Forever 1.60.1, interface 16001, with Titan Panel installed separately.
