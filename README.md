# Titan Gathered Forever v3

TGF v3 helps World of Warcraft Forever crafters understand their materials: what an item is used for, how much they have, where it comes from, and what their own observations say about obtaining it.

The long-term goal is a useful lifetime record for every item supported by the profession catalogues. This includes looting, mining, herbalism, skinning, fishing, disenchanting, crafting and cooking. Statistics should help players plan professions, compare sources, share results and perform later analysis.

Website: [titan-gathered.com](https://www.titan-gathered.com/).

## Current beta

The current development candidate is version `0.5.24-beta` and targets **WoW Forever 1.60.1, interface 16001**, with Titan Panel installed separately. It is installed in the local test client. The latest source changes are listed in [the unreleased changelog](release-notes/ref-unreleased.md); they do not represent a new tagged release. Other WoW editions are outside this project's scope.

Validation: all Python and Lua suites pass, plus Lua 5.1 compilation of every shipped Lua file. The user confirms the icon configurator works; the full [live acceptance checklist](book-wow-forever-validation.md) remains open.

Implemented:

- Profession-use information and current Bags and Bank counts in item tooltips, including recipe-material item tooltips. Total appears only when both locations contain the item. Supporting explanations use smaller text.
- Titan summaries show bag/bank counts without a redundant total, joined with `/` (for example, `3/7`). Zero values and their separators are omitted when Display > Show items with zero counts is off. The panel caption is `TG3 Forever - v0.4.11`; the manifest version is 0.4.11-alpha.
- Titan uses gold for headings and profession menu labels. Learned profession names and ranks use colors based on current rank / current maximum: below 25% red, 25% to below 50% brown, 50% to below 75% yellow, and 75% or higher green. Material names retain item rarity colors.
- World ore-vein tooltips use native object IDs matched to previously recorded mining sources. With History in item tooltips enabled, they show the current character's complete mining loot sample count and each observed drop's percentage, hits/samples and sampled quantity for that source, zone and instance context. Identified veins without matching samples show Unknown; unrecognized object IDs are left alone. These are personal observations, not server drop tables or counts of fully depleted veins.
- Mining map and minimap hovers list observed ore, stone and gem drops with complete loot sample counts, hit/sample percentages and quantities, grouped by source and zone. Saved spot observations are distinct from completed casts and fully depleted veins; missing rate evidence displays Unknown.
- Per-character lifetime obtained-item totals, with an optional combined-character view. Reports open one at a time and retain their own scope, filter and page. Lifetime materials, observed chances and profession actions use compact columns with wrapped rows and pagination. Lifetime materials show combined acquired/crafted quantities with a compact source count. Use + or - to expand/collapse individual source rows, each with its own source/zone, chance and hit/sample denominator. All sources remain accessible across pages, with material context repeated on continuation pages. Click a material for source actions. Acquisition occurrences remain stored/exported separately; older incomplete occurrence totals remain lower bounds or unknown.
- Observed acquisition rates for readable loot sources, including mining and herbalism byproducts, skinning, fishing and supported ordinary material drops.
- Outdoor world-map and minimap source icons, controlled by profession and material. Material visibility is shared across profession menus: toggling Linen Cloth under either First Aid or Tailoring affects all eligible cloth spots on both maps. Show all / Hide all applies to the selected submenu’s materials across professions; profession-wide switches remain independent. Clearing map spots preserves lifetime statistics. Material icons use the original WoW artwork, default to no border, and remain centered at recorded/projected coordinates, including when markers overlap. Appearance is configurable.
- PvP Board (Titan > History and sources) shows client lifetime honorable kills and rank, plus separate addon-observed honorable kills and per-kill honor estimates by outdoor, Battleground and arena context. Other honor awards are excluded from these estimates. PvP map/minimap spots require an outdoor honorable-kill message and honor assist credit; Battleground and arena events never create map spots. PvP deaths require a hostile player or player-controlled source in the death recap and are tracked after this feature is enabled. The client lifetime kill total is not added to addon counters. History and sources > Record PvP lifetime history independently controls addon kill/death recording and new PvP spots, preserving earlier observations and native totals.
- Mining map markers prioritize primary ore rather than stones/gems. All outputs remain in statistics; old overlapping byproduct pins are hidden only where ore is recorded.
- Disenchanting outcomes grouped by input item when its identity is readable. Enchanting creates no map spots.
- Separate per-character action counters for Mining, Herbalism, Skinning, Fishing and Disenchanting, with combined reports and independent recording controls. Real-client event order remains under validation.
- per-recipe crafting/cooking compact columns for attempts, completed operations, completion percentage, matched operations, item quantities and bonus/multicraft percentages with readable-field denominators. Click a recipe for output distributions and recording details. Recording and reports are independent of gathering actions and acquired loot; live validation is pending.
- live recipe reagent plans with required/available/missing quantities, material-limited operation estimates, cached-inventory labels and personal source evidence. Native reagent tooltips show a compact selected-recipe summary.
- schema-versioned JSON statistics export with current/combined selection, identity opt-in and a manual copy window. Large snapshots use numbered parts and a local reconstruction tool.
- faction-aware world-map flight points, including undiscovered routes. Markers retain native artwork and use green for confirmed flight-master visits, amber for client-reported undiscovered nodes and gray for unconfirmed discovery. Only opening the taxi map at the current master confirms that node for the current character; previously visited nodes require a new observed visit. Map-wide false discovery flags do not confirm discovery. The Flight points menu contains its visibility switch.
- Small icon appearance window: Titan menu > Icon appearance. Configure world-map materials, minimap materials and flight points independently: 12–40 px, circular crop or full image, and an optional thin gold outline. Preview before Apply; Cancel discards edits.
- Independent profession addons, optional Auction Items and a shared core.

Open issues and next work:

- Live validation of gathering action counters and crafting/cooking production, particularly queued casts, result identities and recording gaps.
- Live validation of JSON copying, scrolling and numbered-part reconstruction in the actual client.
- Reported partial artwork clipping/offset, especially Linen Cloth, remains unresolved across shapes/sizes. Further testing and a current screenshot are needed; no speculative offset fix has been applied.
- Broader recipe and material coverage, support for complex reagent choices and richer analysis of source conditions. Catalogue completeness remains false, with 456 legacy IDs unresolved and 11 producer associations awaiting review.

The prioritized continuation roadmap is stored in [plan-next-development.md](plan-next-development.md).

The catalogue currently contains 532 supported item IDs and 1,973 recipe relationships. Fishing now includes 23 materials, adding seven direct-reference omissions, including Alchemy fish. Live availability and completeness remain under verification.

Latest installation metadata reports build 70862. The recipe snapshot retains target 70790 and an unknown extraction build; its 1,971 base facts match both the pinned mirror and the four public CSV tables labelled 1.60.1.70862. The crosscheck covers item-output recipe facts, while live obtainability and complete coverage remain unverified. See [ref-catalogue-reconciliation.md](ref-catalogue-reconciliation.md) for evidence and [book-catalogue-reconciliation.md](book-catalogue-reconciliation.md) for the audit workflow.

## What the percentages mean

TGF v3 distinguishes **items obtained**, **successful outcomes**, **complete observed source samples**, and **observed profession actions**.

For example, a gem obtained from 3 of 20 complete observed mining sources has an observed acquisition rate of **15% (3 / 20)**. Obtaining five gems in one source adds five items but only one successful outcome. This does not establish the server's guaranteed drop rate or the probability of success for an unobserved action.

Fishing percentages describe complete looted catches in a zone, including junk catches, rather than every cast. Ordinary loot groups comparable source entries, zones and instance contexts. Disenchanting groups input item IDs; unreadable identity is explicitly unknown. Partial or unreadable loot does not create a complete rate sample. Recording policies prevent newly enabled materials from inheriting samples collected while they were excluded. Combined rates sum eligible samples rather than averaging character percentages.

Lifetime history begins with acquisitions recorded in `0.4.0`. Earlier versions saved map locations and observation counts, which cannot reconstruct item quantities or drop-rate denominators. Purchases, trades, bank transfers and current bag contents are not treated as gathered items. Instance acquisitions may contribute to history, while instance and raid locations are excluded from map recording.

Profession actions use separate schema-1 storage. An attempt requires a readable cast identity and a recognized start, channel start, success, failure or interruption event. Duplicate events share one attempt. A mining, herbalism, skinning or disenchanting completion means spell success, regardless of loot quantity. Fishing spell success only launches the line; its completion requires a confirmed fishing-loot window, even if you leave the loot behind. Stops without a confirmed result, explicit failures, interruptions and unresolved observations are reported separately. A stop does not prove manual cancellation or failure.

Profession actions (Titan > History and sources) shows the first recorded action time for each profession, current-character or combined counts, and profession filters. Combined coverage begins at the earliest included character observation; it does not mean all characters recorded continuously since then. Recording gaps are not reconstructed. Reloads, world transitions and action-recording changes seal pending observations without inventing outcomes. Recent cast receipts are bounded to 1024 per character; lifetime aggregates remain. These counters do not change source-rate percentages or reconstruct actions from earlier history.

Crafting/cooking production also uses separate schema-1 storage. It requires a readable player cast start while recording is enabled and live recipe metadata from the corresponding profession. Supported item recipes include Cooking, Alchemy, Blacksmithing, Engineering, First Aid, Leatherworking, Tailoring, smelting under Mining and item-producing Enchanting recipes that the client identifies as ordinary item recipes. Recraft, dummy, gathering, enchanting-application and salvage recipe flags are excluded. Unknown metadata or protected fields do not produce guessed records.

Crafting and cooking (Titan > History and sources) separates completed casts from operations with matched dedicated crafted-item results. Item totals use actual reported quantities, not requested queue lengths, bag changes, loot chat or recipe defaults. Click a recipe for observed output-quantity distributions, failed/interrupted/unresolved attempts and matched-operation counts. Bonus and multicraft counts use only readable explicit fields as denominators; quantity variation alone is not labeled a proc. These observations do not establish server probabilities or complete production coverage.

Production result events have no recipe ID. Matching therefore requires an unambiguous recent output/recipe context and a positive operation identity, within 60 seconds of the cast start. Secondary outputs arriving before a primary binding, first-craft rewards, unpaired results and ambiguous recipes are skipped. After a recording gap, recent sealed casts can suppress new output attribution for the remainder of that window while completed casts remain counted. Reloads preserve aggregates and seal pending contexts. Ordinary recipe identities used for recrafts and the actual Forever event sequence still require live validation. Lifetime material rows and item tooltips show crafted quantities separately from acquired loot; crafting creates no map spots or loot-rate samples.

## Install only what you need

Download the **complete collection ZIP**, or download the **core ZIP plus the individual profession ZIPs** you want. Every optional module requires both the core and Titan Panel. A profession ZIP does not include the core.

Extract ZIPs into the Forever client's `Interface/AddOns/` directory. The resulting folders must be siblings:

```text
AddOns/
  Titan/                       # Titan Panel, installed separately
  TitanGatheredForeverV3/               # TGF v3 shared core
  TitanGatheredForeverV3_Mining/        # Optional
  TitanGatheredForeverV3_Herbs/         # Optional Herbalism module
  TitanGatheredForeverV3_Skinning/      # Optional
```

Available modules: Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Fishing, Herbalism, Leatherworking, Mining, Skinning and Tailoring. Auction Items is an additional optional module. Disabled modules do not load their catalogue tables.

Install the renamed folders and disable the previous-generation addon folders. Do not enable both generations together. Enable the new Titan broker entry if Titan still displays the previous one.

## Preserve existing saved data after the rename

WoW names its account SavedVariables file after the core addon folder. Renaming the folder therefore requires a one-time migration to retain settings, inventory snapshots, spots and lifetime history.

Runtime ZIPs contain runtime files only. If you installed from ZIPs, first download the [migration tool](tools/migrate_savedvariables.py) from the source and adjust its script path in the command below.

1. Close WoW so its current data is saved, and back up the account's SavedVariables directory.
2. From the source checkout, run the migration tool, using the old and new files in that same account directory:

```sh
python3 tools/migrate_savedvariables.py \
  "/path/to/WTF/Account/ACCOUNT/SavedVariables/TitanGathered2.lua" \
  "/path/to/WTF/Account/ACCOUNT/SavedVariables/TitanGatheredForeverV3.lua"
```

The tool changes the old `TitanGathered2ForeverDB` assignment to `TitanGatheredForeverV3DB`, preserving the table contents and original file. It refuses to overwrite existing new data. Repeat for each account whose data you want to retain. This is data migration, not compatibility with another WoW edition.


## Use TGF v3

Right-click the Titan entry for Display, Professions, Additional items, Icon appearance, Flight points, Trainers and recipe vendors, Gathering map, History and sources, and Diagnostics settings. History recording and map visibility have separate controls.

Everything that needs no parameter is in the right-click menu of the Titan entry:

- Display: Show minimap button, Next summary page and Previous summary page. The round minimap button opens the unlearned recipes window with a left click, the menu with a right click, and can be dragged around the minimap edge.
- Icon appearance: the small icon appearance window.
- Trainers and recipe vendors: map toggles, profession filter, Unlearned recipes, and Pin placement (find the nearest pin, swap map axes if pins look mirrored).
- History and sources: Lifetime materials, Observed chances, Profession actions, Crafting and cooking, PvP Board, Export statistics and recording switches.
- Diagnostics: Debug mode, Also show debug messages in chat, Clear debug log, Refresh inventory, Show status report and Show NPC recording log (why the last trainer or merchant windows did or did not record, with raw client answers). Debug mode writes important events (casts, loot, trainer and merchant windows, profession windows, bank and world changes, honor events), status messages and recording outcomes to a bounded debug log of the latest 1,000 lines. The log lives in the saved variables file, which the client writes on /reload and logout, so debug messages no longer fill the chat unless Also show debug messages in chat is on.

A command is only needed when it takes a parameter:

- `/tgf recipe <recipeID> [operations]`: reagent plan for a recipe; omit the ID after selecting a native profession recipe. Plan selected recipe reagents in the menu does the same for the selected recipe.

The earlier parameterless commands (`/tgf settings`, `icons`, `history`, `chances`, `actions`, `production`, `pvp`, `recipes`, `export`, `refresh`, `status`, `next`, `prev`, `npc`, `npc swap`) still work as shortcuts but are no longer documented, because the menu covers them.

Click a material in a report for its recorded sources. Use **TGF v3 spots** on the world map to clear a category from the displayed map after confirmation. Debug mode prints local diagnostics and is normally off.

History and sources includes Record profession actions and Action recording by profession. These switches are independent of lifetime item history and map visibility. Recording requires the corresponding profession addon and enabled profession category. Disabling a module retains its recorded counts for later reporting.

Record production and Production recording by profession control crafting/cooking independently. The corresponding addon and profession category must be enabled. Turning off item-history or map display does not stop production recording; disabling a production module retains its prior statistics.

## Trainers and recipe vendors

Trainers and Recipe vendors are separate map switches in the menu, with a per-profession filter, and they work on the world map and minimap without the gathering map. Pins start from a bundled Classic seed and show as not yet confirmed in game until you open that NPC's window, which records its recipes, required skill and price. Observed data replaces seed data, and unknown values stay unknown. Vendor and trainer tooltips show the NPC name in gold, role and confirmation state in gray (green when confirmed in game), a rule, then one white line per recipe with the required skill in brackets after the name and only the price on the right in the classic gold, silver and copper icon format. Recipes you know are marked once that profession window has been opened. The Unlearned recipes window lists recipes you have not learned and shows whether a trainer or only a vendor provides them. It scrolls with the mouse wheel or a scroll bar, shows recipes that need more skill than you have in red (so the ones you could learn now stand out), has a profession filter, shows NPC names in green, and hovering an NPC name shows every source of that recipe with its zone, coordinates and price. Clicking a row opens the map at the zone of the first source and marks every trainer or vendor of that recipe with a pulsing red ring on the world map and minimap, even when the map filters would hide them. The rings belong to the map opened from the window: closing the world map removes them, and so does clicking the same row again, choosing another recipe or waiting five minutes. Reopening the map normally shows no rings. Pins never appear in instances.

## Plan recipe materials

Select a recipe in the profession UI, then use `/tgf recipe` or Plan selected recipe reagents in the Titan menu. You can also enter an explicit recipe spell ID and operation target, such as `/tgf recipe 2536 3`. Production recipe details and known recipe examples in material source menus link to the same planner. More/Fewer adjusts the target; Refresh requests the normal inventory refresh. Planning does not craft or reserve anything.

Native selection follows the highest learned rank used by the profession schematic; explicit recipe IDs remain exact. If a native rank transition cannot be resolved, select an explicit ID instead of receiving a guessed rank's requirements.

Reagent quantities come from live client schematics on demand. The planner aggregates repeated item requirements, shows available and missing quantities for the requested operations, and estimates the material limit. Display > Show bank counts selects Bags or Bags + Bank for both the planner and reagent context. Cached snapshots are labeled estimates with bank observation time where available. Unknown counts display zero and suppress the overall material limit. A material limit does not certify learned skill, tools, cooldowns, location or other crafting requirements; unlearned recipes are labeled.

Fixed single-item basic reagent slots are supported. Required alternatives, currency, variable quantities, protected data and unsupported slots leave the overall estimate unresolved; fixed rows may still be shown as a partial plan. Optional modifiers and finishing reagents are excluded. Recraft, gathering, salvage and dummy contexts are excluded. Ordinary enchantment recipes can be planned for their reagent requirements. Planning requires the recipe's loaded, enabled profession addon/category and does not load bulk recipe tables into the core.

Each reagent links to personal acquisition evidence and recorded map positions. Source suggestions prioritize larger observed samples; they do not establish the best place to farm. Source/zone rates and saved positions are distinct: a zone-wide observed rate is not a probability at a particular coordinate, and an old position does not establish current resource availability. Native reagent tooltips add only a short per-operation deficit and material-limit summary for the selected recipe. Live recipe selection, slot availability and planner layout remain under validation.

## Export statistics

Use Export statistics under History and sources. The default is This character with names and GUIDs excluded. All characters retains per-character policy/coverage records plus a weighted combined summary. Include names/GUIDs is an explicit opt-in that resets on closing. Numeric game IDs, map IDs and gameplay timestamps remain in identity-excluded exports.

Select text, copy with Ctrl+C or Cmd+C and save UTF-8 JSON outside addon folders. The addon sends nothing. Its snapshot stays fixed while copying; Generate captures a new one. Small exports are complete schema-1 JSON. Large exports are numbered JSON parts: save every part from the same snapshot and reconstruct with `tools/read_export.py`. The reader rejects missing, duplicate, mixed or corrupt parts and refuses to overwrite files.

Exports preserve acquired/produced quantities separately, source policies and eligible denominators, action outcomes, production distributions and explicit proc-field counts. They exclude inventory snapshots, raw event receipts, coordinates and arbitrary saved labels. Unknown starts and unsupported feature schemas remain explicit. Exports are cumulative snapshots: do not sum repeated exports as independent observations.

See [ref-statistics-export-format.md](ref-statistics-export-format.md) for fields and reconstruction commands. JSON is the initial format because one flat CSV would lose policy/distribution relationships. Clipboard round trips remain a live-client validation gate.

## Development layout

The repository root contains the shared core and thirteen separate optional addon folders. All addon folders contain only game-required files. Development tools, tests, catalogue inputs, documentation and release notes live at the repository root. Generated packages are written to `dist/`; private local archives remain in ignored `.work/`.

`python3 tools/audit_catalog.py` reports evidence gaps without writes or downloads. Use `--check` for the generated report, `--mirror-file` for pinned mirror verification and `--client-tables` for offline build-labelled CSV verification. Audit/generation share input validation and protect report output from source-file aliases. Unresolved IDs and inherited associations remain; completeness is false.

```sh
git clone https://github.com/Bajtlamer/titan-gathered-forever-v3.git
cd titan-gathered-forever-v3
python3 tools/generate_catalog.py
python3 tools/check.py
python3 tools/package.py
```

The project's standing instruction is to install each completed, verified runtime update automatically into the local Forever client with tools/install.py, retaining backups and verifying installed bytes. This does not publish GitHub releases or change hosting.

Python 3.10 or newer and LuaJIT with Lua 5.1 semantics are required. No Git initialization is required to run these local tools. The generator reconstructs profession addon folders from `catalogue/`. Runtime Lua lives in `TitanGatheredForeverV3/`, including its `Data/` and `Localization/` folders. Tests and tools live in root `tests/` and `tools/`. Avoid editing unrelated addons.

See [AGENTS.md](AGENTS.md) for current repository conventions and automatic local-installation instructions, [the runtime reference](ref-wow-forever-runtime.md) for implementation evidence, and [the roadmap](plan-next-development.md) for outstanding work.

## Releases and website downloads

Every release must provide:

- One full collection ZIP.
- Fourteen independent ZIPs: the core, twelve profession modules and Auction Items.
- A download index with version, dependencies, filenames, sizes and SHA-256 hashes.
- Checksums for the downloadable archives.

`python3 tools/package.py` builds the normal distributions and a clean upload directory at `dist/releases/<version>/`. Upload the contents of that version directory to the website's download area. The collection ZIP installs all modules; individual ZIPs let users select only their professions. Source archives supplied automatically by GitHub are development source, not installable addon packages.

Tagged GitHub releases use the same build and verification pipeline. Runtime ZIPs exclude tests, catalogue source JSON, private archives, Git metadata, development documents and unrelated addons. See [the release playbook](book-releases.md) for publishing steps.

## Contributing and evidence

Report the client and Titan versions, TGF v3 version, affected item/spell IDs, expected results, observed results and reproduction steps. Visible UI changes benefit from screenshots. Run the full checks and the relevant [in-game validation steps](book-wow-forever-validation.md).

Recipe evidence includes the documented [DwarfExplorersBible client-table mirror](https://github.com/masterred92/DwarfExplorersBible/blob/main/Data.lua), supplementary Forever spell references and curated uses retained in `catalogue/`. Titan Panel is an external dependency. Original artwork and upstream material retain their attribution; this README does not assign a new blanket license to third-party content.

## License and notices

The repository is licensed under GPL-3.0, see [LICENSE](LICENSE). The planned trainer and recipe vendor seed is derived from CMaNGOS classic-db data under the same license and with its non-commercial fair-use basis, see [NOTICE](NOTICE). World of Warcraft is a trademark of Blizzard Entertainment, and this project is not affiliated with it.
