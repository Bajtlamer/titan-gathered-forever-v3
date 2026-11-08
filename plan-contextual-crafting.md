# Contextual crafting assistance

## Current status, 2026-11-08

Implemented, tested and installed for fixed-reagent plans. Complex required choices and full live native-tooltip/selection acceptance remain open. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective and approach

Implement Milestone 4 with live recipe reagent quantities, material deficits, material-limited operation counts and nearby source evidence. Use on-demand C_TradeSkillUI schematics instead of publishing full recipe tables into each addon. Preserve the small profession publishers, independent recording settings and existing loot-rate definitions.

Pinned API evidence from the prior production implementation remains applicable: Forever UI source commit `9dc84f0d3bbae1768ac3405b3716000bd93eda06`, TradeSkillUIDocumentation.lua and TradeSkillUITypesDocumentation.lua. GetRecipeSchematic exposes reagentSlotSchematics, quantityRequired, required, reagentType, variableQuantities and reagent item/currency choices. ProfessionConstantsDocumentation.lua defines Basic reagent type 1. ProfessionsCraftingPageMixin registers `ProfessionsRecipeListMixin.Event.OnRecipeSelected`, consuming recipeInfo and recipeList, and treats selected list recipes as ordinary recipes.

TradeSkillUITypesDocumentation.lua defines TradeskillSlotDataType.Reagent=1, ModifiedReagent=2 and Currency=3. Use the live Enum value, with the pinned Reagent=1 fallback. Native selection follows Professions.GetHighestLearnedRecipe, matching the native schematic; explicit command IDs remain exact. If a rank transition cannot be resolved, omit native context rather than choose a different rank.

References: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua; https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsCrafting.lua.

## Scope and decisions

Add `Crafting.lua` with Read(recipeID), Compute(recipe, inventory, showBank, operations), Plan(recipeID, operations), Evidence(itemID, character), Context(itemID), Select(recipeInfo) and Initialize(). Live metadata identifies the profession and must belong to a loaded, enabled module. Ordinary item and enchantment recipe schematics can supply reagent planning; recraft, salvage, gathering and dummy contexts are excluded. Unlearned recipes may be planned, with a clear label.

Ruling: aggregate fixed single-item basic reagent requirements by item ID before calculating the minimum floor(available / per-operation quantity). Plans count operations, not output units. Apply the existing Bank display switch: Bags only when off, Bags plus Bank when on. Unknown values display as zero, but unknown inventory suppresses a definitive material limit. Cached counts remain estimates and expose their age/status. Never scan bank or change inventory/history while planning.

Ruling: unresolved required alternatives, currencies, variable quantities, protected or malformed slots suppress the overall material limit. Optional modifiers/finishing reagents are excluded explicitly. Zero-reagent or incomplete schematics cannot imply unlimited production. The result is a material limit only, independent of skill, tools, cooldowns and other execution requirements. This can withhold an estimate for complex recipes but avoids overstating craftability.

Add `CraftingView.lua`, a native paged reagent planner available through `/tgf recipe <recipeID> [operations]`, `/tgf recipe` for the selected recipe, the Titan menu, production recipe details and known recipe examples in source menus. Read-only recipe-selection callbacks supply at most two short contextual lines to native reagent tooltips; no secure crafting functions are called. The planner shows required/available/missing quantities, freshness and one source hint per reagent; clicking opens source evidence and recorded map locations.

Refine source menus and map tooltips to identify source/zone-wide observed samples. Saved positions remain separate from statistical trials. Source evidence is personal observation, never guaranteed availability, a best-location claim or a probability at a coordinate. Preserve instance grouping and no-map behavior for Enchanting.

## Implementation steps

1. Write failing tests/crafting.lua for quantity aggregation, targets, Bags/Bank scope, unknown/cached snapshots, zero materials, optional/alternative/currency/variable/protected data, invalid IDs and disabled modules. Implement the model and add its manifest/checker entries.
2. Add failing host tests for recipe selection, slash parsing, inventory refresh, compact native context, module isolation and unchanged acquired/produced/map data. Implement live metadata and event/menu integration.
3. Add failing native-view tests for deficits, paging, sources and invalid/empty states. Implement the planner and refine source menus/pin labels with regression coverage. Keep all runtime files manifest-listed.
4. Run the full checker, obtain independent review, fix important findings with reproductions, then update README, roadmap, progress and live acceptance steps. No install, publish, version bump or commit is part of this task.

## Review focus and completion criteria

Check repeated item IDs across slots, required alternatives sharing inventory, stale/unknown bank state, protected API fields, optional/automatic classification, malformed arrays, explicit recipe identity, recipe-selection reset, row reuse/paging and source/position labeling. Automated behavior and source API shapes must be verified; real-client selection callbacks, schema availability and UI layout remain pending live acceptance.

## Execution record

- Prior 232-check implementation retained in the requested workspace. Autonomy authorization covers this local implementation; no extra approval or branch changes needed.
- Task 1 complete: wrote failing calculation tests, implemented fixed-quantity aggregation and scope/freshness handling. Sparse schemas produce an explicit error; the corresponding test was corrected to accept that failure form.
- Task 2 complete: live metadata and selection tests failed before integration; callback, slash/menu entry points, compact tooltip context and inventory refresh are wired. Corrected a Lua multi-return expression exposed by the native-context regression.
- Task 3 complete: planner-window tests failed before implementation. Added the paged native view, source/position links, contextual recipe buttons and map-pin scope labels. Full checker passes 256 checks (40 Python and 216 Lua), plus shipped Lua compilation. Independent review pending; real-client behavior remains unverified.
- Final review complete: independent reviewer found the incorrect reagent-slot enum mirrored in fixtures and a stale open planner after module disabling. Corrected fixtures to pinned values first, observed failures, then fixed enum handling and immediate planner refresh. Added a failing highest-learned-rank selection regression and fixed native resolution while preserving explicit IDs.
- Final verification: 258 checks (40 Python and 218 Lua), plus shipped Lua compilation and clean whitespace checks. No deferred code findings. Rulings remain: unsupported requirements withhold estimates, cached counts stay estimates and source/zone observations never imply a probability at a coordinate. Real-client schema/selection/layout acceptance is pending. No installation, publication, version change or commits performed.
