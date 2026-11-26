# Titan Gathered Forever 0.5.164

Update from 0.5.161. This text is the changelog for the website and the release page. Versions 0.5.162 and 0.5.163 were internal steps and are included here. No new files were added: a plain reload is enough after updating.

## Added

- **One gathering switch per map.** "Show gathering spots on the world map" and "Show gathering spots on the minimap" each control one map. They are in the Map options menu of the world map and in the Titan menu under Gathering map, and the profession and material submenus are always available.

## Changed

- **Data collection is always on.** Lifetime history, map spots, profession actions, production, PvP, rare loot and trainer and vendor windows are recorded whatever the settings say. Only disabling an addon in the AddOns list stops it. The recording switches are gone from the menus (Record lifetime history, Record profession actions, Record production and their per-profession menus, Record PvP lifetime history, Include rare loot, Record trainers and vendors when I open their window).
- **Hiding never loses data.** The map switches only decide what is drawn: spots gathered while the map, a profession or a material is hidden are kept and appear when shown again. Turning a profession off in the Professions menu only hides it from the reports, maps and tooltips; its data keeps growing.
- **Clearer map menu.** The switches "Gathering spots", "On the world map" and "On the minimap" are replaced by the two per-map switches above. Trainer, recipe vendor and weapon master pins follow only their own switches, now named Show profession trainers, Show recipe vendors and Show weapon masters in the map menu too.

## Fixed

- Hiding a material or a profession on the map stopped its gathering spots from being recorded, so anything gathered while hidden was lost.

## Upgrading

Install over the old folders. Your saved data and settings are kept. A map shows gathering spots after the update only if the old Gathering spots switch and the old switch of that map were both on. Recording switches saved as off by older versions are ignored. Map spots are still not recorded inside instances; the statistics there are. The thirteen optional modules only carry the new version number: their catalogue data is unchanged.
