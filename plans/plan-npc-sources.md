# Plan: Profession Trainers and Recipe Vendors

Status: implemented and installed as 0.4.12-alpha on 2026-11-12; live acceptance pending. See plan-npc-sources-implementation.md. Target version: 0.4.12-alpha (patch increment, alpha suffix retained).

## Goal

Show profession trainers and recipe vendors on the world map and minimap, with independent menu toggles and a per-profession filter. Recipe vendor tooltips list the recipes they sell, the minimum required profession level and the price. Trainer tooltips list the profession and, once observed, trainable recipes with required skill and cost.

## Decisions

- Data source: a compact bundled seed plus live observation. Observed data overrides seed data field by field.
- Seed source (decided 2026-11-12): CMaNGOS classic-db (GPL-3.0), file `Full_DB/ClassicDB_1_12_1_z2815.sql.gz`, pinned by commit and SHA-256 and converted by `tools/generate_npc_seed.py`. Wowhead has no public bulk download and restricts scraping, so it is used only for manual spot checks. The data is Classic 1.12.1, so every seed entry stays "not yet confirmed in game" until observed, and recipe item IDs are cross-checked against `catalogue/forever-recipes.json`.
- Pinned source: classic-db commit c33f90b8eeb3f8bacb53d5cbfee45075c80b416c, dump SHA-256 4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0 (13 MB gzip, 73 MB SQL).
- License: `LICENSE` (GPL-3.0, added 2026-11-12 on the owner's instruction because the derived seed is GPL-3.0) and `NOTICE` at the repository root credits CMaNGOS, records GPL-3.0 for the derived seed and the non-commercial fair-use basis from the source `COPYRIGHT.md`. `tools/package.py` must include `NOTICE` in the runtime ZIPs that carry the seed. The GPL-3.0 grant sits beside the source's non-commercial fair-use statement; the repository owner accepts that and may revisit it. `LICENSE` must also ship in the runtime ZIPs.
- Unlearned recipes window (decided 2026-11-12): a new addon window opened from the Titan menu, in the style of Reports and CraftingView, listing the current character's unlearned recipes per profession.
- Menu: two toggles (Show profession trainers, Show recipe vendors) plus a per-profession filter reusing the existing profession colors. Defaults are on.
- Documentation and map rules from AGENTS.md apply: unknown evidence stays unknown, no instance map spots, no invented NPC identities, catalogue completeness stays false.

## Changes made during implementation planning

- One shared profession filter setting, `mapNpcProfessions`, covers trainers and vendors (earlier draft: `mapTrainerProfessions`).
- Observation lives in `NpcObserver.lua`, not in `NpcSources.lua`.
- A row in the unlearned recipes window opens the world map at the NPC's continent or zone instead of placing a waypoint.
- Seed faction is omitted because the dump has no usable faction data; pins for both factions appear.
- `settings.npcAxisSwap` and `/tgf npc swap` let the owner flip world axes live.
- Profession filter menu entries are labelled "<Profession> pins".

## Feasibility result (2026-11-12)

Extraction from the pinned dump was tested in a scratch directory (nothing committed):
- 284 profession trainers (`TrainerType` 2), 258 with direct `npc_trainer` rows (`spellcost`, `reqskill`, `reqskillvalue`). None use trainer templates.
- 913 NPCs with vendor stock via `npc_vendor` and `npc_vendor_template`; 230 sell items of class 9 (recipes). Spawns exist for all but 3 of them, and 495 of the 496 selected NPCs have a spawn.
- Vendor price is `item_template.BuyPrice` (no stock-specific price), required skill is `RequiredSkill` and `RequiredSkillRank`. 862 of 1,690 recipe items have `RequiredSkill` 0, so skill stays unknown for those and the generator must filter to profession recipe subclasses rather than trust class 9 alone.
- Coordinates in `creature` are world coordinates on continents 0 and 1 (178 and 158 spawns), not 0-1 map fractions. The seed stores world coordinates and continent ID, and `NpcSources.lua` converts them at runtime with the client map APIs (`C_Map.GetMapPosFromWorldPos`). This conversion is a live validation gate. Without it the pins cannot be placed.

## Architecture

New runtime module `TitanGatheredForeverV3/NpcSources.lua`, loaded after `Sources.lua` and before `PinStyle.lua`, owns NPC data, merging and observation. `Map.lua` and `Minimap.lua` request nodes from it for two new pin kinds, `Trainer` and `RecipeVendor`. No new addon folders are added.

### Data model

Seed (`Data/NpcSeed.lua`, generated, never edited by hand): per NPC `npcID`, `name`, `faction`, `continentID`, world `x`, `y`, `role` (trainer or vendor), `profession`, and for vendors a list of `{ itemID, requiredSkill, priceCopper }`. Prices with extended cost or unknown skill are omitted rather than guessed.

Observed (`saved.npcs[npcID]`, additive, schema guarded in `Settings.lua`): `mapID`, `x`, `y`, `lastSeen`, `role`, `profession`, trainer services `{ name, requiredSkill, costCopper }` and vendor recipes `{ itemID, requiredSkill, priceCopper, extendedCost }`.

Merge (read time, never persisted): observed value wins over seed value per field. Seed-only entries carry the label "Not yet confirmed in game". Missing price or skill is shown as unknown.

### Observation

- `TRAINER_SHOW`: read target NPC identity from the interaction, the trainer's profession and its services via the trainer service APIs. Record required skill and cost.
- `MERCHANT_SHOW`: record only recipe items, with name, required skill, price and extended-cost presence.
- Position is the player's position at interaction, labelled "recorded near". Skip recording in instances.
- Observation reads only during an explicit interaction, never from map browsing, matching the flight-point visit rule.
- Live validation gate: the exact Forever 1.60.1 behaviour of trainer service and merchant recipe skill APIs is unverified and must be confirmed in game before the feature is called accepted. Automated tests use stubs.

### Settings and menu

New settings in `Settings.lua`: `mapTrainers`, `mapRecipeVendors` (booleans, default true) and `mapTrainerProfessions` (table, per profession visibility). Existing settings are untouched. `Titan.lua` adds the two checkboxes and a profession filter submenu next to the existing flight point and map entries.

### Map and minimap

`Map.lua` and `Minimap.lua` include the two kinds only when the matching toggle and profession filter allow it. Pins use the existing `PinStyle` size, shape and border settings and the profession colors. Node cap behaviour of the current overlay is preserved.

### Tooltips

Vendor pin: NPC name, confirmation state, then recipes with required skill and price formatted as coin, recipes the character already knows marked, at most 15 lines followed by "and N more". Trainer pin: profession, trainable recipes with skill and cost when observed, confirmation state. All colors reuse `Style.lua`.

### Unlearned recipes window

New `RecipeBrowser` view (separate file, loaded after `CraftingView.lua`). It lists every recipe the current character has not learned and that has a known source, per profession, with columns: recipe, required skill, source (Trainer or Vendor), NPC, price and a button to show the NPC on the map. A filter switches between all unlearned recipes and vendor only, which hides every recipe a trainer can also teach. A recipe is "Trainer" when any trainer source exists, otherwise "Vendor".

Known-recipe state does not exist in the addon today. It is recorded per character as `saved.knownRecipes[characterID][profession]` when the profession window is opened, and stamped with the recording time. A profession whose recipes were never observed shows "Recipes not yet read for this character" rather than an assumed empty or full list. Unknown stays unknown, and no recipe is hidden or shown as unlearned without evidence. Required skill and price come from the merged seed and observed data and show as unknown when missing. Sorting, paging and rows-per-page reuse the existing report conventions.

## Testing

- Recipe browser: unlearned filtering per character, vendor-only filter hiding trainer-teachable recipes, unread professions showing the explicit message, pagination.
- Python: generator determinism, `--check` rejecting stale output, hash pin verification, rejection of entries without a map or coordinates.
- Lua (LuaJIT, 5.1 semantics) via `tests/`: merge precedence, unknown values staying unknown, observation parsing from stubbed APIs, settings migration, toggle and filter node selection, tooltip line cap, no pins for instance maps.
- `python3 tools/check.py` passes with every shipped Lua file compiled.

## Delivery

1. Add generator, pinned provenance, generated seed and packaging of `NOTICE`, with tests.
2. Add `NpcSources.lua`, settings migration and observation, with tests.
3. Wire map, minimap, menu and tooltips, with tests.
3a. Add known-recipe recording and the unlearned recipes window, with tests.
4. Bump version across the core manifest, generator VERSION and generated profession manifests.
5. Run `python3 tools/check.py`, preview then apply `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'`, and byte-verify installed files. The new file and manifest entry require a full client restart rather than `/reload`.
6. Update README.md, `release-notes/ref-unreleased.md`, `plan-next-development.md` and `ref-wow-forever-progress.md`. Record live validation results separately from automated checks.

## Out of scope

Publishing releases, pushing commits, importing recipe vendors from other installs, quest-reward recipes, auction-house recipe sources, and any change to existing catalogue completeness flags.

## Open items

- Before step 1, download the dump into a scratch directory, confirm trainer and vendor tables can be extracted, and record the commit and SHA-256.
- Decide the addon's own distribution license (GPL-3.0 seed implies compatibility requirements).
- Confirm in game that merchant recipe items expose a usable required-skill value, otherwise vendor skill levels stay unknown unless the seed provides them.
