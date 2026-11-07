# Material History and Sources Implementation Plan

Use the executing-plans skill for inline execution. User authorized automatic implementation; no Git repository or worktree is required.

## Goal and decisions

Provide two independent native windows: lifetime obtained-material history and observed acquisition rates. Add Fishing, rare secondary gathering drops and useful ordinary corpse/container materials to source maps. Recipe-material tooltips share inventory, uses, history and source evidence. History is separate per character with an optional combined view, as selected by the user.

## Source and statistical rules

- A sample is a fully looted observed source, not a cast, kill, item stack or purchased item. Display obtained outcomes divided by complete samples for that source. Quantity is separate from the number of successful outcomes.
- Distinguish Mining, Herbalism, Skinning, Fishing, ordinary loot and Disenchanting. Group by source type/entry, zone and profession. Fishing percentages are per looted catch in a zone, including junk catches, not every cast.
- Lifetime totals include taken items from partial loot. Partial sources do not contribute to rates. Deduplicate repeated loot events and reopened sources. Do not infer old drop rates from saved map icons.
- For enchanting, group by the input item ID when its identity is known. Unknown input stays explicitly unknown; it is never attributed to guessed equipment. No enchanting map pins.
- Record only supported profession materials and rare/epic items from ordinary loot; record all observed items from actual gathering/fishing/disenchanting. Keep user-configurable recording, profession visibility and material filters. Avoid instances/raids for mapped sources.
- Keep map deletion independent of history. Preserve current saved data. Use bounded recent-source deduplication and aggregate lifetime counters rather than an unbounded raw-event journal.

## Implementation tasks

- [x] Add pure `History.lua` storage, deduplication, source-group rates, item totals and combined query models. Test quantity versus outcomes, partial loot, repeats, zero outcomes, character isolation and reload.
- [x] Add `Observations.lua` event collector and Core API adapter. Preserve early/autoloot metadata, per-source quantities, event order and successful spell correlation. Add Fishing/disenchant spells and ordinary loot. Test exclusion, partial and multi-source loot, delayed metadata, failure, cancellation and enchanting input identity.
- [x] Extend profession/material map configuration and shared pins for observed resource categories, including dynamically observed rare items. Retain old Mining/Herbalism/Skinning controls and independent history recording. Test loaded-module isolation and map deletion.
- [x] Add `Reports.lua`: two separate movable, paged windows with current-character/combined and profession filters; history totals and source rates with sample counts. Add menu and slash entry points.
- [x] Extend material tooltips with per-character lifetime totals and up to three source summaries with explicit observed samples. Include existing map locations when historical statistics do not yet exist. Do not claim recipe-craftability without recipe quantity evidence.
- [x] Run full checks, package a new alpha, verify runtime-only archive contents and update manual live acceptance. In-game event timing and window placement remain explicit live checks.

## Evidence and limits

Forever primary references: generated Loot events, generated C_Item.GetItemIDByGUID and item info APIs, Wowhead Forever Fishing spell 7620 and Disenchant spell 13262. Fishing source identity and disenchant source GUID availability require live acceptance. No server loot-table or guaranteed probability claims. The existing recipe catalogue is an alpha with unverified completeness.


## Implementation record

Completed in 0.4.0-alpha. The runtime collector is `Observations`; `Gathering` retains saved-spot storage and its earlier independently tested collector. Current verification: 167 checks plus compilation of every shipped Lua file with Lua 5.1 semantics. Independent review identified and resolved money-only source denominators, instance-history exclusion, stale-cast position attribution, partial fishing receipt identity, source-aware lifetime filters and recording-policy denominator mismatches.

Rulings: preserve lifetime history in instances, but never draw instance acquisition spots. Group those rate samples separately by instance context. Enchanting ignores geographical context and uses the input item ID; if unknown, say so. A reopened source-less item loot window without trustworthy disenchant identity retains eligible lifetime quantities as unattributed acquisition and contributes no rates. Recording pauses or configuration changes invalidate incomplete rate samples. Map display changes alone preserve active history collection.

Recording policies snapshot eligible catalogue IDs and rare-item coverage. Newly enabled professions cannot inherit ineligible earlier trials. Combined views sum eligible sample counts rather than averaging character percentages. Recent-source deduplication retains at most 1024 receipts per character and 1024 in-session source contexts. Lifetime summaries themselves are retained without map deletion or icon-cap eviction.

Live acceptance remains required for fishing/disenchant event ordering, input GUID availability, money-slot clearing, report window placement and recipe tooltip contexts. Old icons are not converted into lifetime quantities or probabilities.

Primary references: [Forever loot event declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua), [Forever item API declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua), [Fishing spell 7620](https://www.wowhead.com/forever/spell=7620/fishing), [Disenchant spell 13262](https://www.wowhead.com/forever/spell=13262/disenchant).
