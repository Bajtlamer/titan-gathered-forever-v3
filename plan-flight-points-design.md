# Faction-aware flight points design

## Current status, 2026-11-08

Implemented and installed. The mandatory discovery-color borders in the initial design were superseded by native artwork plus tooltip status; the icon window now offers an optional gold outline and configurable size/shape. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Intent and scope

Show flight-master locations on the world map so the player can find undiscovered routes. The user requested all locations usable by their faction, including undiscovered locations, with border colors distinguishing discovery. World map only in this feature; minimap flight points and route automation are outside scope.

Use an independent, persistent Show flight points setting, enabled by default. Alliance characters see Alliance and neutral nodes; Horde characters see Horde and neutral nodes. If faction is unavailable, show only explicitly neutral nodes. Unknown node factions are excluded. Per-character discovery comes from the current client, never from another character's saved data.

Keep each flight icon's artwork and use green borders for discovered, amber for undiscovered and gray when discovery is unavailable. Tooltips state the name, faction and discovery status in words. Colors and default enablement are implementation choices under the user's existing auto-mode instruction.

## Approaches

Use client data rather than a bundled coordinate catalogue. A fixed catalogue would require build-specific flight locations, phasing and faction maintenance and would still need live discovery data. The chosen approach queries C_TaxiMap.GetTaxiNodesForMap for the displayed map. Its MapTaxiNodeInfo has nodeID, position, name, atlasName, faction and isUndiscovered. It does not depend on visiting a flight master first. Show all valid returned nodes, including explicit isUndiscovered=true; do not gate queries on native ShouldMapShowTaxiNodes.

Use an independent world-map layer and reuse native flight markers when the same node is already drawn. Native markers receive an addon-owned border and tooltip status; missing markers receive pooled addon pins. Do not replace native click handlers or remove another provider's pins. Turning the feature off removes the addon layer and decorations, leaving the normal Blizzard map behavior intact. This avoids duplicate markers while supporting maps on which the native provider does not draw them.

## Constraints and behavior

The separate flight layer attaches without profession addons, works with gathering disabled, handles canvas changes/zoom, and updates after map, world, faction or taxi-status changes. Missing API or malformed/restricted data hides unsupported results safely. A missing/nonboolean discovery flag is unknown, never assumed undiscovered. No persistent node or discovery database and no material/history/export/source-policy changes.

All locations means all valid nodes the current client exposes for the selected map. API support and actual Forever coverage require live acceptance. No unavailable nodes or coordinates are invented. New functionality remains a local candidate until requested installation; the already installed 0.4.1-alpha is not changed by development.

## Evidence

Forever UI declarations: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TaxiMapDocumentation.lua
Native provider: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedMapDataProviders/FlightPointDataProvider.lua
Map pin enumeration: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua

These inspected branch files declare the faction enum Neutral=0, Horde=1, Alliance=2 and explicit isUndiscovered boolean. The native provider filters faction and registers TAXI_NODE_STATUS_CHANGED. These references establish API shape, not observed live compatibility.

## Acceptance

Test faction/neutral filtering, unknown/restricted flags, all discovery states, empty/error API responses, no-module startup, independent persistent toggle, map/canvas/zoom lifecycle, event refresh, pooled pins and native-marker reuse/cleanup. Run the full checker, obtain independent review and document the live checklist. No automatic installation, publication or commits.
