# Titan Gathered Forever v3: WoW Forever Rewrite

Status: revised after the user's architecture correction on 2026-11-06. Preserve separately enabled profession addons and optional bank/total columns. The initial analysis below describes the source copy before rewriting. Current results are in `ref-wow-forever-progress.md`; `plan-wow-forever-modules.md` governs the modular correction.

## Objective and confirmed scope

Build a Titan Panel plugin exclusively for WoW Forever. Help players decide what to keep, use for professions, or sell through the auction house. Relevant item tooltips must explain usefulness and show quantities in bags, the character bank, and their sum.

The user authorizes removing obsolete features and data. Retain the profession addon-pack structure so each database can be independently enabled in WoW. Previous WoW clients and historical loot records need not be supported. This directory is a source copy without Git metadata.

Interpretation for this draft: include every obtainable item used by an available profession, irrespective of the player's learned professions. Additionally include a curated set of auctionable items with a specific documented use. Whether auction coverage should include every tradable equipment item remains open. Auction eligibility does not establish demand, price, or profitability.

## What the existing code actually does

The seven addon directories contain 14 Lua files totalling 2,736 lines. The core is 1,247 lines; the other six addons register profession categories and item data. XML loads English data before Lua logic, while `.toc` manifests declare dependencies on Titan and the shared core.

A static scan of `tag`/`name` rows in the six profession data files found:

- Cooking: 266 rows; Tailoring: 198; Mining: 96; Skinning: 86; Herbs: 74; Enchanting: 47.
- Total: 767 rows, 708 unique numeric item IDs, and 59 repeated ID occurrences. Repeated IDs across professions often represent legitimate shared usage; they should become relationships rather than duplicate item records.
- The core localization file separately contains five class-item rows. They are outside these totals and are not automatically evidence of tracked profession coverage.

These counts describe the copied files, not a verified Forever item inventory.

Important findings:

1. `TitanGatheredForeverV3_GetItemCount`, core line 1010, already returns bags, bank, and total using two `GetItemCount` calls. There is no explicit bank scan, freshness state, or persisted bank inventory implementation. A declared `bankHistory` default does not supply those behaviors.
2. The Titan summary at lines 215–264 renders bags or bags/bank; it calculates but omits total. The item tooltip at lines 288–320 can display all three counts, behind inverted settings.
3. `GetItemCategory`, line 920, scans English names and returns the first match. Item tooltip recognition reads `GameTooltipTextLeft1`. This makes identity depend on display text and loses multiple profession uses.
4. Item records contain `tag`, `name`, `cat`, and `skill`, with mixed string/numeric IDs. They have no recipe provenance, availability status, auction reason, or binding policy. Herb IDs `13466` and `3819` appear twice under different names. The Bloodthistle row stores `181166`; verify its identity rather than trusting the label.
5. There are no dedicated Alchemy, Blacksmithing, Engineering, Leatherworking, Fishing, or First Aid catalogues. Shared materials may already occur elsewhere, so absent modules alone do not prove absent items.
6. Fifteen candidate baseline enchanting reagents are absent from every profession table: IDs `10978`, `11084`, `10998`, `11082`, `11083`, `11134`, `11135`, `11137`, `11138`, `11139`, `11174`, `11175`, `11176`, `11177`, `11178`. Examples include Soul Dust and Vision Dust. These are audit candidates, not verified Forever additions.
7. Loot history is collected on `LOOT_OPENED`, before successful acquisition is established. Source IDs are used as sequence positions with `table.insert`/`table.remove`, and source lookup requires recognized names. This subsystem is unsuitable as an inventory ledger.
8. Skinning discovery uses English spell/creature names and passes an undeclared `unit` to `RegisterUnitEvent`. The item tooltip prints a required skill of `1` instead of a recipe-derived value. Both become unnecessary if these displays are removed.
9. Settings commonly mean enabled when false. Generic globals such as `trim`, `echo`, and `dump` increase collision risk. Every manifest repeats the Version field and targets interface `90001`.

The available compiler is Lua 5.5.1: 13 files pass its syntax check, while the core fails because it reassigns a generic-for variable at line 1201. This is a compiler-version mismatch finding, not proof of a Forever runtime failure. Validation must use the target client's Lua semantics.

## External evidence and limits

Blizzard lists nine primary professions and three secondary professions: Herbalism, Mining, Skinning, Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, Fishing, and First Aid. This is the initial profession scope; unsupported professions must not be imported from later expansions. See [Blizzard's camping and professions article](https://worldofwarcraft.blizzard.com/en-us/news/24301516/gather-around-the-campfire-in-world-of-warcraft-forever).

Blizzard also describes more than 600 new recipes. Consequently, pruning the old database to a Classic baseline cannot establish Forever completeness. See [the Forever deep dive](https://worldofwarcraft.blizzard.com/en-gb/news/24303313/world-of-warcraft-forever-deep-dive-panel-recap).

The [Forever client UI source mirror](https://github.com/Gethe/wow-ui-source/tree/forever) exposes modern namespaces. Its generated [item documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) defines `C_Item.GetItemCount` with separate bank, reagent-bank, and account-bank flags, plus asynchronous item loading. The [container documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua) defines `BAG_UPDATE_DELAYED`; the [bank documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua) defines bank open/close and slot-change events. The [tooltip processor](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua) provides `TooltipDataProcessor.AddTooltipPostCall`.

These are implementation candidates from a moving branch. Pin a source revision matching the installed build and test its behavior in game. API declarations alone do not prove that a storage type exists or that bank counts remain authoritative after relogging.

[Titan Panel's maintainer page](https://www.curseforge.com/wow/addons/titan-panel) lists Forever support and recommends the newer `Titan_Menu` wrapper. Inspect the installed release before replacing the old `L_UIDROPDOWNMENU_*` integration.

An existing [Forever recipe addon](https://github.com/masterred92/DwarfExplorersBible) documents generation from client tables and recipe-to-reagent relationships. It is a useful extraction reference, not independent proof of obtainable recipes or an automatically complete source.

### Wowhead cross-check, 2026-11-06

Use [Wowhead's Forever database](https://www.wowhead.com/forever/database), specifically its `/forever/` branch, to cross-check item identity, profession recipe reagents, sources, and item-use descriptions. Separate learned crafting spells from tradable recipe items: [the recipe-item listing](https://www.wowhead.com/forever/items/recipes) is not a complete list of crafting operations or reagents. Search results can be capped, so one unpartitioned result page cannot establish coverage.

Concrete findings against this source copy:

- [Glimmering Staff, spell 1248703](https://www.wowhead.com/forever/spell=1248703/glimmering-staff), lists Star Wood, Pyrite, Greater Astral Essence, and both sizes of Glimmering Shard among its reagents. This provides a specific Forever crafting-use reason for several missing entries, rather than relying on their historical Classic use.
- [Star Wood, item 11291](https://www.wowhead.com/forever/item=11291/star-wood), and [Pyrite, item 249391](https://www.wowhead.com/forever/item=249391/pyrite), are absent from the copied item tables. The latter is marked new in Forever. The existing Mining entry `52183`, Pyrite Ore, is a different item and must not be substituted by name similarity.
- [Orb of Souls, spell 1248748](https://www.wowhead.com/forever/spell=1248748/orb-of-souls), lists Soul Dust, Greater Astral Essence, and Small Glimmering Shard. Its output binds on pickup: a valid material-use reason does not imply the crafted result is auctionable. The direct page fetch was blocked, but its indexed spell record was readable; recheck against the client before release.
- [Waylaid Crate: Expert Curiosities, item 248694](https://www.wowhead.com/forever/item=248694/waylaid-crate-expert-curiosities), accepts alternative bundles including Vision Dust. This supports a separate supply-turn-in reason. Do not interpret all listed alternatives as simultaneously required reagents.
- [Craftsman's Writs](https://www.wowhead.com/forever/guide/professions/craftsmans-writs-overview-recipes-rewards) are described as tradable quest-starting items. Treat verified writs as candidates for curated auction coverage, with the reason identifying the profession task and reward purpose. Verify each writ's actual availability and restrictions before inclusion.

Wowhead's [profession overview](https://www.wowhead.com/forever/guide/professions/overview) acknowledges incomplete beta recipe coverage. Item pages can also contain inherited comments dated long before Forever. Prefer current structured item/spell relationships; label community observations separately and do not import old comments, auction prices, or drop percentages as Forever facts. Resolve conflicting or missing data against the pinned client and live observations. Browsing access is partial, so this cross-check does not establish a complete export.

## Approach options

1. Patch the existing seven addons: smaller initial edits, but retains duplicated data, name matching, and unrelated history machinery.
2. Rewrite the shared Titan core and generate separate optional profession addons: selected after the user's correction. It provides one identity model, one settings store and consistent counts while preserving independent addon loading.
3. Build a general auction and profession suite: significantly broader than the requested information tool and would require additional product decisions.

## Recommended design

### Item identity, relevance, and reasons

Use one catalogue keyed by numeric item ID. Each item has category IDs, a set of profession uses, optional recipe references, availability evidence, and optional auction-use reasons. Item names and rarity come from the client, with asynchronous loading and a safe pending display.

Separate producer/source information from consumer information. Ore obtained through Mining can be consumed by Blacksmithing or Engineering; cloth can serve Tailoring and First Aid. A profession label must express a verified relationship, not whichever file happened to contain the item.

Use stable reason codes with localized text. Profession reasons should identify actual uses, such as a verified recipe or intermediate material. Represent supply-turn-in and quest-starting uses separately from recipe consumption; these are candidates under the curated auction scope. Auction-only entries require a specific reason, such as a tradable recipe teaching a named craft. Do not claim an item sells well merely because it is tradable. Static item eligibility and the binding status of an individual item instance are separate checks.

Keep raw source snapshots and an evidence manifest outside the shipped addon. Record client build, extraction date, source revision, and per-item evidence. Generate the shipped Lua catalogue deterministically. Keep uncertain entries in a review dataset, excluded from the release catalogue.

### Inventory and bank behavior

Default to the current character's carried bag contents and personal bank. Exclude equipped gear, mail, auction listings, guild storage, other characters, and account storage from this initial sum. Confirm how the target client's counting APIs treat equipped items before using aggregate counts as bag counts.

Return one inventory result containing `bags`, `bank`, `total`, `bankState`, and `bankObservedAt`. Distinguish known zero from unknown. Until a bank has been observed, display `Bank: unknown` and `Total: unknown`; keep the known bags count visible.

If the target client does not retain reliable bank counts between sessions, persist a per-character bank snapshot. Identify characters with a stable client identity rather than an English character name alone. Mark snapshots as last observed, refresh on confirmed bank updates, and never replace a valid snapshot with zeros while the bank is inaccessible. If bank access is restricted, retain the last observation and label it.

Coalesce inventory events so one transfer does not produce several intermediate renders. For a known bank, require `total = bags + bank`. Transfers between included storage locations must preserve total after events settle. Do not include account/reagent storage merely because the API declares flags for it; confirm what Forever actually makes available.

### Player-facing behavior

Keep the Titan bar entry, a grouped material summary, item tooltip enrichment, and a small settings menu. The bar summary defaults to owned relevant items and supports category filtering and a show-zero toggle. The catalogue covers all supported professions, not just those learned by the player.

An item tooltip should show its verified use reasons and Bags counts. Bank and Total are optional columns; disabling Bank also hides Total, bank timestamps and bank-only rows, and suspends bank scans. A scanned empty inventory shows zero. An unscanned bank stays unknown. Both summary and tooltip use the same count service.

Use item IDs supplied through the target tooltip API. Do not scan the tooltip title. Handle missing item data without errors, and ensure repeated tooltip processing does not append duplicate sections. Leave tooltip placement under the existing UI's control.

Remove historical gathering totals, node/NPC learning, drop percentages, spellcast tracking, profession-rank summaries, class-resource lists, forced tooltip anchors, and expansion-specific category switches from the first rewrite. These are proposed removals enabled by the user's scope, not additional requirements.

### Proposed file responsibilities

- `TitanGatheredForeverV3/TitanGatheredForeverV3.toc`: Forever-only metadata and deterministic load order; keep Titan as a required dependency.
- `TitanGatheredForeverV3/Core.lua`: namespace, initialization, and event coordination.
- `TitanGatheredForeverV3/Catalog.lua`: ID lookup and relevance decisions.
- `TitanGatheredForeverV3/Data/Metadata.lua`: small source/coverage metadata, without item databases.
- `TitanGatheredForeverV3_<Profession>/`: independently enabled generated data addons, each with its own manifest and dependency on the core. Preserve `Herbs`, `Mining`, `Skinning`, `Cooking`, `Enchanting` and `Tailoring` names; add supported profession modules.
- `TitanGatheredForeverV3_Auction/`: optional curated auction-use items, distinct from professions.
- `TitanGatheredForeverV3/Inventory.lua`: bag counts, bank observations, and freshness.
- `TitanGatheredForeverV3/Tooltips.lua`: item tooltip integration and rendering.
- `TitanGatheredForeverV3/Titan.lua`: plugin registration, summary, and current menu API.
- `TitanGatheredForeverV3/Settings.lua` and `Localization/enUS.lua`: explicit booleans, storage schema, and display strings.
- `tools/`, `data/`, and `tests/`: reproducible catalogue generation, source evidence, validators, and focused Lua tests; exclude these from the addon package.

Use the existing icon and core directory name. Replace the legacy code inside the existing profession addon structure rather than eliminating its manifests. Disabled addons load no database. Shared item identities are deduplicated in the core's active index. Preserve preferences and bank snapshots from the first Forever alpha.

## Delivery sequence and acceptance checks

### 1. Establish the actual runtime contract

- [ ] Record `GetBuildInfo()`, locale, installed Titan version, and the matching client-source revision.
- [ ] Verify addon manifest flavor, Lua version, Titan registration/menu APIs, item tooltip processing, item loading, and bank/container semantics on that build.
- [ ] Check bag counting for equipped items and bank counting before opening the bank, while open, after closing, after reload, and after relogging.

Exit: a reproducible runtime reference and an explicit choice of counting strategy. Do not select the target `.toc` number solely by guessing from interface `90001`.

### 2. Establish the Forever data baseline

- [ ] Export build-matched recipes, reagent quantities, profession associations, item records, and obtainable-source evidence. Check extraction coverage for enchantments and recipes without conventional output items.
- [ ] Derive the union of reagents for all confirmed available recipes, including intermediate materials and profession vendor supplies. A player's known recipe list is supplementary evidence, not the global catalogue.
- [ ] Cross-check IDs and recipe uses against Wowhead's Forever branch, including new materials, camping recipes, writs, and supply-turn-in candidates. Record exact item/spell URLs and verification dates. Preserve alternative ingredient/turn-in groups rather than flattening them into mandatory requirements.
- [ ] Reconcile each of the 708 old IDs as retained, corrected, removed, or unresolved. Add every verified new reagent absent from the old set.
- [ ] Review auction-only candidates separately. Reject entries without a concrete use reason or evidence of auction eligibility.
- [ ] Report unmatched reagents, inactive/unobtainable recipes, unresolved identities, duplicate canonical IDs, and missing reasons.

Exit: zero unexplained omissions relative to the pinned verified recipe dataset, with a published list of remaining source limitations. Item existence in client data or a successful item-info query is not proof of live availability. Do not use an item-ID cutoff or expansion label as the deletion rule.

### 3. Build a small working plugin

- [ ] Implement the new namespace, fresh settings schema, required Titan integration, and one verified item through catalogue lookup, bag/bank counting, and tooltip display.
- [ ] Prove identity works independently of English names and delayed item metadata.
- [ ] Test unknown bank, known zero bank, and retained last-observed bank states before expanding the catalogue.

Exit: one correct end-to-end item on the target client, including successful bank transfer and reload behavior.

### 4. Complete catalogue and presentation

- [ ] Load the generated catalogue and reason relationships; render all relevant profession uses once per item.
- [ ] Add grouped Titan summary, owned-item default, show-zero option, and category filters using explicit enabled/disabled values.
- [ ] Verify multiple-category membership does not inflate counts or repeat tooltip sections.
- [ ] Remove legacy source/history systems; package the shared core and separate optional profession addon folders, with individual downloads as well as a bundle.

Exit: a coherent Forever-only addon pack, independently selectable profession data, and no legacy client integration path.

### 5. Validate and release

- [ ] Use a client-compatible Lua parser and linter, plus mocked tests for catalogue lookup, relevance, asynchronous metadata, storage transitions, and tooltip idempotence.
- [ ] Validate catalogue invariants and recipe coverage with a deterministic generation check. Reject unknown professions, invalid IDs, missing evidence/reasons, and inconsistent references.
- [ ] In game, test looting, crafting consumption, purchases/sales, split stacks, trade, mailing, bank deposits/withdrawals, empty slots, full bags, reload, relog, and a second character.
- [ ] Check item hovers in bags, bank, loot, chat links, recipe reagent displays, and the auction UI where supported. Check startup without Titan for a clear dependency failure, not a Lua crash.
- [ ] Record tested builds and residual data limitations. Update contributor guidance only as a separate authorized change; preserve the existing `AGENTS.md` during this planning task.

Release criteria: no Lua errors in these flows; correct known counts and explicitly unknown counts; no duplicate tooltip sections; all released items have Forever evidence and at least one inclusion reason; all verified available recipe reagents are accounted for. Completeness is relative to a named build and evidence set, not an unqualified claim about every possible live item.

## Execution decisions and remaining validation

1. The installed Forever client has been identified as `1.60.1.70790`, interface `16001`. Titan is not installed locally; its actual adapter remains an in-game validation gate.
2. Autonomous execution uses curated auction-use items, each with a specific reason. It does not add every tradable equipment item.

Implementation follows `plan-wow-forever-implementation.md`. The alpha may be tested before full live catalogue reconciliation; neither the package nor source mirror is a completed release-completeness claim.
