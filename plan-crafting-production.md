# Crafting and cooking production statistics

## Current status, 2026-11-08

Implemented, tested and installed. Live queued-craft/result attribution and recraft acceptance remain pending; matched observations do not imply complete production coverage. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective

Implement Milestone 3 with per-character recipe operations, observed output quantities, explicit proc flags, combined reporting and independent recording controls. Preserve inventory, loot/source denominators, maps and existing saved history. Live-client acceptance remains pending.

## Evidence and design

Pinned Forever UI source: `9dc84f0d3bbae1768ac3405b3716000bd93eda06`.

- `Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua` declares `GetProfessionInfoByRecipeID`, `GetRecipeInfo`, `GetRecipeSchematic` and `TRADE_SKILL_ITEM_CRAFTED_RESULT` carrying CraftingItemResultData.
- `TradeSkillUITypesDocumentation.lua` defines itemID, quantity, itemGUID, operationID, firstCraftReward, bonusCraft and multicraft. Recipe schematics expose recipe identity, outputItemID and recipe type; profession metadata exposes professionID/parentProfessionID.
- `Blizzard_Professions/Blizzard_ProfessionsCraftingOutputLog.lua` groups result rewards by operationID and separates first-craft rewards from primary outputs. This source is evidence for API shape, not certification of the installed build.

References: https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua and sibling TradeSkillUITypesDocumentation.lua; https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsCraftingOutputLog.lua.

Use live recipe metadata for enabled production professions, including Cooking and smelting under Mining. Never load bulk recipe catalogues into the core. Enchant applications, salvage, recrafting, gathering and first-craft rewards are outside item-production scope. Unknown or unavailable metadata fails closed.

`Production.New(saved, api)` owns schema-1 per-character recipe aggregates and 1024 recent cast receipts. `Cast(event, unit, guid, recipeID)` records distinct observed attempts and success/failure/interruption evidence, requiring a recorded enabled START. `Result(data)` binds a positive operation ID to a matching, recent player cast. A result before success may wait in its cast receipt; failure, recording changes, world transitions and reloads prevent it becoming output. Require one eligible recipe identity for a previously unbound operation; queued casts of that same recipe can pair in observation order. Mixed pending recipes sharing an output are ambiguous and skipped. Operation identities are session-local; persisted cast receipts preserve prior counts without assuming operation IDs remain unique across logins.

Ruling: count only dedicated crafted results with readable positive item/quantity/operation identity. Do not use bag deltas, generic loot chat or desired queue length. Unpaired results remain uncounted. Match the primary output against the live recipe's output IDs; additional outputs can join an already bound operation. Deduplicate each operation/item/item-GUID tuple; conflicting repeated quantities are not additional output. First-craft rewards and enchant results do not count as produced items.

Ruling: completed casts and matched result operations are distinct denominators. Per-item quantity distributions describe observed quantities in matched operations, not verified server proc probabilities or complete output coverage. Count bonusCraft and multicraft only when their fields are readable; retain explicit known-field denominators. No inferred extra-output/proc labels from stack size. Production has no map coordinates and never enters loot-source chance samples.

Ruling after review: sealed recent receipts remain attribution blockers for unbound results sharing their primary output, for the 60-second correlation window. After recording gaps this may omit new output quantities while retaining completed-cast counts, but prevents old delayed output from being credited to a new recipe operation. Require START before terminal evidence to exclude casts begun while recording was disabled. RecipeInfo flags, including isRecraft, must explicitly exclude recraft/dummy/gathering/enchant/salvage contexts. Recrafts that reuse ordinary recipe identities still require real-client validation; no fresh-item guarantee beyond the available API evidence is claimed.

Ruling: a secondary output arriving before the primary result cannot establish recipe identity and is skipped. This can undercount unusual multi-output flows; the native report labels matched observations rather than complete production coverage.

## Implementation steps

1. Write failing `tests/production.lua`: distinct queued casts, duplicate events, outputs before/after success, failures/interruptions, ambiguous recipes, missing metadata, protected/invalid fields, first rewards, multiple-item outputs, explicit proc denominators, stale contexts, pauses/reloads, combined counts and bounded receipts. Implement Production.lua and add manifest/checker entries. Public methods: Cast, Result, Pause, Rows(character), Totals(character), Total(character,itemID).
2. Write failing host tests and wire live metadata, production events, saved recordProduction/productionProfessions controls, reload/world/configuration sealing and `/tgf production`. Ordinary display/history/map changes preserve pending production. Recording requires the corresponding enabled addon/category.
3. Add a native production report with current/combined selection, profession filtering, paging, per-recipe counts and clickable observed output distributions. Add crafted quantities separately to item tooltips and lifetime material rows. Preserve existing acquired totals and source-rate definitions.
4. Run the full checker, obtain independent review, update README, roadmap, progress and real-client checklist. No deployment, publication, version bump or commits are part of this implementation.

## Review focus

Check result-to-recipe ambiguity, queued event order, duplicate/late events after policy gaps, operation identity reuse across reloads, output/proc denominators and separation from inventory/loot/maps. Failed or interrupted casts must never produce quantities. Validate unknown schemas without mutation. Run the live checklist before making real-client reliability claims.

## Execution record

- Existing local work retained. Source inspection confirmed dedicated result fields and their missing recipe identifier before implementation.
- Tasks 1 through 3 complete: initial collector tests failed before implementation; new host and report tests then failed before integration. Recording, controls, production report, output-distribution menu, separate lifetime rows and tooltips are implemented.
- Independent review found two important defects: delayed post-gap result attribution and incomplete recraft metadata checks. Reproduced both with failing tests, fixed in one pass, and added observed-START and early-secondary-output coverage. Full checker passes 232 checks, including 18 production, 47 host and seven report scenarios, plus shipped Lua compilation. No deferred code findings; live-client event order and layout remain unverified.
