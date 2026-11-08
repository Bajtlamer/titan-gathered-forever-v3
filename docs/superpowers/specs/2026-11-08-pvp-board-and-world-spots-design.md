# PvP Board and Open-World Spots Design

## Intent

Add a PvP Board that makes the character's overall PvP results easy to review across open-world PvP, Battlegrounds and arenas where the client exposes those results. Add persistent map and minimap markers for confirmed open-world honorable kills. The board must keep client-wide historical totals distinct from new addon observations.

## Goals

- Show the PvP totals and rank that the WoW Forever client exposes, including all modes represented by those totals.
- Show a clearly labeled PvP-death counter recorded by this addon from the feature's first supported observation. The client API does not provide a lifetime death total suitable for reconstruction.
- Record open-world PvP spots only when the client reports an honorable kill against an opposing-faction player. This accepts an honor-awarded assist as participation and does not require the player to deliver the killing blow.
- Reuse existing persistent map spots, world-map/minimap rendering, nearby-point merging, map visibility settings and per-map clearing where practical.
- Keep the PvP Board available without profession addons.

## Non-goals

- Reconstructing historical PvP deaths or world-only totals from the client's global history.
- Counting kills that receive no honor award as confirmed open-world spots.
- Adding Battleground or arena pins to the world map.
- Claiming that the honor estimate printed for an individual kill is the final honor contribution after diminishing returns or other adjustments.
- Reporting a world/Battleground/arena split for historical API totals when the client does not expose one.

## Proposed board

Add a native, movable **PvP Board** window and a Titan menu entry. Present distinct groups:

1. **Client PvP summary:** lifetime honorable-kill total, current rank and lifetime highest rank where supported by the installed client APIs. These values cover the PvP modes included by the client and are not split by mode.
2. **Tracked PvP events:** honor-confirmed kills and the per-kill honor amount reported by named kill messages, marked as an estimate and separated by outdoor, Battleground and arena context. Generic honor awards are excluded. These values cover this addon's observations from feature activation. Only outdoor events back map spots.
3. **Tracked PvP deaths:** confirmed player-caused deaths observed after the feature is enabled, with the supported context scope identified. Do not backfill or label this as a lifetime total.

Unavailable or unsupported fields must display as unavailable, not zero. Keep honorable kills, dishonorable kills and player deaths as separate concepts. The board must not label dishonorable-kill API values as player deaths.

## Map behavior

- Listen for the Forever client's honor-gain chat event. Record only the localized/known message form that identifies an honorable player kill; generic honor-award messages are insufficient for a location pin.
- Require a valid player map position and an outdoor, non-instance context (`IsInInstance()` returns `false, 'none'`). This excludes Battlegrounds and arenas from map spots.
- The honor-gain event confirms the player received honor for the kill, including eligible assists. Capture the current player's map and normalized position when the event is handled.
- Add a distinct PvP marker kind with a PvP-specific icon and tooltip. Never use a fabricated item ID or route PvP nodes through material history, profession filters or acquisition statistics.
- Merge repeated PvP kills within the map controller's existing proximity threshold; show count and last recorded time in the tooltip. Keep a dedicated PvP map-visibility switch and allow PvP nodes to be cleared by map and kind.

## Data and coverage

- Preserve existing gathering/map SavedVariables and history schema. Extend node validation in an additive, backward-compatible way for PvP nodes without an item ID.
- Store the PvP tracking start time, per-character observed honorable kills, event-reported honor estimates and deaths in an additive SavedVariables section. All character records remain independently scoped.
- For PvP death classification, use the local player's death recap and count only a lethal event whose source flags identify a hostile player or player-controlled pet/guardian. A generic `PLAYER_DEAD` event or a killer name by itself is insufficient because it includes PvE deaths. If the recap is absent or ambiguous, do not count the death.
- Read client-provided summary APIs defensively. Validate API presence, return types and native rank data at runtime; never make startup depend on optional PvP APIs.
- The PvP Board should refresh on relevant PvP statistic/death events and on open. It must remain usable with missing API functions.

## Approaches considered

1. **Client-wide native totals plus separate addon observations (selected).** Provides the real overall PvP results the user asked for while preserving explicit coverage and source labels for world-only spots and observed deaths.
2. **A new event ledger as the primary board.** Could attempt a world/Battleground/arena breakdown, but starts at installation, risks incomplete event classification and cannot reproduce historical rank or totals. It is not the requested overall-results view.
3. **One blended total from native totals and addon logs.** Rejected because it would double count and combine different coverage windows and definitions.

## Constraints and validation

- Target WoW Forever 1.60.1, interface 16001. Do not change the manifest or depend on later-only APIs without exact client evidence.
- Existing map spots are normally material records with an `itemID`; PvP is a non-material source and must stay explicit throughout validation, rendering, tooltips and clearing.
- The public reference API documents honor-gain messages, the restricted combat-log event and the death-recap API. Forever withholds the combat-log event from addons, while its death-recap API exposes the source flags used for player attribution. Validate actual event payloads and rank/stat function results in client build 70862 or the currently installed build before claiming live support.
- Automated host tests must cover message parsing, map eligibility, assist-compatible reward confirmation, repeated-location merging, PvE/instance rejection, per-character death persistence, missing APIs, invalid API returns and report labeling.
- Live acceptance must cover an outdoor credited/assisted honorable kill, a repeat at the same spot, an honorable kill in a Battleground, a PvP death, a PvE death and a character with no rank. Battleground kills must affect client-wide summaries if the client API reports them, but must not create outdoor map spots.

## Source references

- Blizzard Vanilla honor panel reads session, yesterday, weekly, last-week and lifetime honor data and displays lifetime rank: [InspectHonorFrame.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_InspectUI/Vanilla/InspectHonorFrame.lua).
- `GetPVPLifetimeStats` returns lifetime honorable kills and maximum rank: [API reference](https://warcraft.wiki.gg/wiki/API_GetPVPLifetimeStats).
- The legacy honor event fires for honor gains and its kill message names the honored victim: [event reference](https://warcraft.wiki.gg/wiki/Event:CHAT_MSG_COMBAT_HONOR_GAIN).
- A generic PvP death total is not returned by the lifetime PvP API; the Blizzard UI's `lifetimeDK` field means dishonorable kills, not deaths.
