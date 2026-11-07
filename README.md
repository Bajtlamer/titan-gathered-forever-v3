# Titan Gathered Forever v3

TGF v3 helps World of Warcraft Forever crafters understand their materials: what an item is used for, how much they have, where it comes from, and what their own observations say about obtaining it.

The long-term goal is a useful lifetime record for every item supported by the profession catalogues. This includes looting, mining, herbalism, skinning, fishing, disenchanting, crafting and cooking. Statistics should help players plan professions, compare sources, share results and perform later analysis.

Website: [titan-gathered.com](https://www.titan-gathered.com/).

## Current alpha

Version `0.4.1-alpha` targets **WoW Forever 1.60.1, interface 16001**, with Titan Panel installed separately. Other WoW editions are outside this project's scope.

Implemented:

- Profession-use information and current Bags, Bank and Total counts in item tooltips, including recipe-material item tooltips. Disabling Bank also hides Total.
- Learned profession skill ranks, item rarity colors and organized Titan configuration menus.
- Per-character lifetime obtained-item totals, with an optional combined-character view.
- Observed acquisition rates for readable loot sources, including mining and herbalism byproducts, skinning, fishing and supported ordinary material drops.
- Outdoor world-map and minimap source icons, controlled by profession and material. Clearing map spots preserves lifetime statistics.
- Disenchanting outcomes grouped by input item when its identity is readable. Enchanting creates no map spots.
- Independent profession addons, optional Auction Items and a shared core.

Still planned:

- Dedicated counters for actions performed, including mining attempts, skinning operations, fishing casts, crafting and cooking operations. Current complete-loot sample counts are not a complete action counter.
- Crafting/cooking output and proc statistics, with recipe and action context.
- Exportable, shareable lifetime datasets with documented formats and controls over shared character information.
- Broader recipe and material coverage, additional contextual crafting assistance and richer analysis of source conditions.

The catalogue currently contains 532 supported item IDs and 1,973 recipe relationships. Live availability and completeness remain under verification.

## What the percentages mean

TGF v3 distinguishes **items obtained**, **successful outcomes**, **complete observed source samples**, and the future **action counters**.

For example, a gem obtained from 3 of 20 complete observed mining sources has an observed acquisition rate of **15% (3 / 20)**. Obtaining five gems in one source adds five items but only one successful outcome. This does not establish the server's guaranteed drop rate or the probability of success for an unobserved action.

Fishing percentages describe complete looted catches in a zone, including junk catches, rather than every cast. Ordinary loot groups comparable source entries, zones and instance contexts. Disenchanting groups input item IDs; unreadable identity is explicitly unknown. Partial or unreadable loot does not create a complete rate sample. Recording policies prevent newly enabled materials from inheriting samples collected while they were excluded. Combined rates sum eligible samples rather than averaging character percentages.

Lifetime history begins with acquisitions recorded in `0.4.0`. Earlier versions saved map locations and observation counts, which cannot reconstruct item quantities or drop-rate denominators. Purchases, trades, bank transfers and current bag contents are not treated as gathered items. Instance acquisitions may contribute to history, while instance and raid locations are excluded from map recording.

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

Runtime ZIPs contain runtime files only. If you installed from ZIPs, first download the [migration tool](TitanGatheredForeverV3/tools/migrate_savedvariables.py) from the source and adjust its script path in the command below.

1. Close WoW so its current data is saved, and back up the account's SavedVariables directory.
2. From the source checkout, run the migration tool, using the old and new files in that same account directory:

```sh
python3 TitanGatheredForeverV3/tools/migrate_savedvariables.py \
  "/path/to/WTF/Account/ACCOUNT/SavedVariables/TitanGathered2.lua" \
  "/path/to/WTF/Account/ACCOUNT/SavedVariables/TitanGatheredForeverV3.lua"
```

The tool changes the old `TitanGathered2ForeverDB` assignment to `TitanGatheredForeverV3DB`, preserving the table contents and original file. It refuses to overwrite existing new data. Repeat for each account whose data you want to retain. This is data migration, not compatibility with another WoW edition.


## Use TGF v3

Right-click the Titan entry for Display, Professions, Additional items, Gathering map, History and sources, and Diagnostics settings. History recording and map visibility have separate controls.

- `/tgf history`: lifetime materials window.
- `/tgf chances`: observed acquisition rates and source samples.
- `/tgf settings`: configuration menu.
- `/tgf refresh`: refresh accessible inventory.
- `/tgf status`: explicit diagnostic report.
- `/tgf next` and `/tgf prev`: page the Titan summary.

Click a material in a report for its recorded sources. Use **TGF v3 spots** on the world map to clear a category from the displayed map after confirmation. Debug mode prints local diagnostics and is normally off.

## Development layout

The repository root contains the shared core and thirteen separate optional addon folders. Development tools, tests, documentation and catalogue inputs live inside `TitanGatheredForeverV3/`. The root README and GitHub workflow cover the complete collection.

```sh
git clone https://github.com/Bajtlamer/titan-gathered-forever-v3.git
cd titan-gathered-forever-v3
python3 TitanGatheredForeverV3/tools/generate_catalog.py
python3 TitanGatheredForeverV3/tools/check.py
python3 TitanGatheredForeverV3/tools/package.py
```

Python 3.10 or newer and LuaJIT with Lua 5.1 semantics are required. No Git initialization is required to run these local tools. The generator reconstructs profession addon folders from `catalogue/`. Runtime Lua lives in `TitanGatheredForeverV3/`, including its `Data/` and `Localization/` folders. Tests and tools live in that core folder too. Avoid editing unrelated addons.

The contributor guide retains its historical structure descriptions with the new addon identity. This README describes the current layout and commands.

## Releases and website downloads

Every release must provide:

- One full collection ZIP.
- Fourteen independent ZIPs: the core, twelve profession modules and Auction Items.
- A download index with version, dependencies, filenames, sizes and SHA-256 hashes.
- Checksums for the downloadable archives.

`python3 TitanGatheredForeverV3/tools/package.py` builds the normal distributions and a clean upload directory at `TitanGatheredForeverV3/dist/releases/<version>/`. Upload the contents of that version directory to the website's download area. The collection ZIP installs all modules; individual ZIPs let users select only their professions. Source archives supplied automatically by GitHub are development source, not installable addon packages.

Tagged GitHub releases use the same build and verification pipeline. Runtime ZIPs exclude tests, catalogue source JSON, private archives, Git metadata, development documents and unrelated addons. See [the release playbook](TitanGatheredForeverV3/book-releases.md) for publishing steps.

## Contributing and evidence

Report the client and Titan versions, TGF v3 version, affected item/spell IDs, expected results, observed results and reproduction steps. Visible UI changes benefit from screenshots. Run the full checks and the relevant [in-game validation steps](TitanGatheredForeverV3/book-wow-forever-validation.md).

Recipe evidence includes the documented [DwarfExplorersBible client-table mirror](https://github.com/masterred92/DwarfExplorersBible/blob/main/Data.lua), supplementary Forever spell references and curated uses retained in `catalogue/`. Titan Panel is an external dependency. Original artwork and upstream material retain their attribution; this README does not assign a new blanket license to third-party content.
