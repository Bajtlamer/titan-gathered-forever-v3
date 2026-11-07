# WoW Forever Rewrite Progress

Current plan: `plan-wow-forever-tooltip-and-map.md`. Earlier implementation plans remain historical records.

## Decisions

- User authorized autonomous execution. Default auction scope is curated useful items with specific reasons; no live pricing or auction automation.
- The source copy originally had no Git metadata. The user subsequently requested a public GitHub repository: initialize the installed core as the repository, preserve `.work/original-addon.zip` locally and exclude unrelated addons.
- Installed game metadata confirms 1.60.1.70790, wowf; the existing Scout observation independently records interface 16001. Titan 9.3.5 and Gathered 0.2.0-alpha are now installed. Retain an explicit in-game verification gate for the new package.
- LuaJIT supplies Lua 5.1 semantics. Do not use the installed Lua 5.5 parser as a release gate.
- Bank inventory uses Forever's tab metadata, not the copied addon's old counting assumptions. Persist complete personal-bank snapshots by player GUID.
- Imported numeric recipe facts are from a documented Forever client-table mirror. Its exact extraction build is unspecified; completeness and live obtainability must remain unverified. Do not promote that evidence into a release-completeness claim.

## Current status: modular alpha 0.4.1

The user clarified that the original independently enabled profession-addon architecture must be preserved. The earlier combined-addon alpha was an agent decision and has been superseded.

- Shared core plus twelve profession addons and a separate optional Auction Items addon. Original six profession folder names are restored with new generated code.
- Core data is metadata only. Disabled addons load no item/recipe tables. Registered module records are deduplicated into a cached active index; recipe counts and two examples replace bulk runtime recipe tables.
- Bank controls Total automatically; there is no independent Total setting. Bags-only mode also hides timestamps and bank-only rows and suspends bank scans. The user clarified that unavailable counts must also display zero, regardless of bank visits. Total sums the displayed Bags and Bank values; scan status stays internal without fabricating observations. Bounded bank-readiness retries and `/tgf status` scan diagnostics are included.
- Saved game state now confirms three actual herb observations in Mulgore. Fixed world-map icon shrinking under canvas zoom and added related-map projection. Added nearby minimap item icons with movement, zoom, rotation and independent world/minimap visibility switches. World-map visibility is now directly confirmed by the 0.3.6 live diagnosis below; nearby minimap visibility remains pending.
- Fixed delayed loot-source metadata being ignored between `LOOT_READY` and `LOOT_OPENED`. A regression plus collector-to-map check confirms a supported herb records and draws its item icon. Live reproduction remains pending. Mapping status and optional debug traces identify missing cast/position/source/loot stages.
- Added a saved `Debug mode` menu checkbox, off by default. Diagnostic logging is gated; `/tgf status` explicitly prints a report, while ordinary refresh/paging/configuration actions stay silent.
- Restored colored TGF v3 sections, learned professions with current/max rank, and native item rarity colors for material names. In 0.3.1, fixed-length dash separators are replaced by resizing texture rules, including a break between learned skills and material columns. Repeated title headers are removed. Labels, profession uses, recipe names, use explanations and freshness/help notes have distinct colors.
- Added personally observed Mining/Herbalism spots on the world map with resource icons, nearby-resource merging, persistence and a 500-point limit per map. A master switch plus profession switches stop recording and hide pins while retaining saved data. Module/category disabling also suppresses its spots.
- `Other` was the combined non-profession-use category. It has been removed from the professions menu; the explicit Auction Items addon is configured separately.
- `dist/TitanGatheredForeverV3-0.4.0-alpha.zip` is the full bundle. `dist/modules/` contains fourteen independent core/module downloads per version. Packaging core alone cannot overwrite the bundle.
- Current verification: 177 automated checks pass: 28 Python, 17 inventory/catalogue, 38 host/tooltip, six optional-addon, eight presentation, 21 legacy gathering, nine lifetime/rate, 15 source collection, five report-window, 14 world-map, eight pin-style and eight minimap checks. Every shipped Lua file compiles with Lua 5.1 semantics.
- Removed a legacy misclassification that put Linen Cloth in Mining. Remaining inherited producer associations and partial Fishing membership are explicitly alpha data limitations, pending a full source audit.
- Direct Chrome inspection confirms the live Titan Gathered website and its separate module downloads. The prior RRsoft result came from the browsing service and was stale or mismatched, not evidence of a live redirect.

## Previous autonomous alpha pass

- Runtime discovery: installed build confirmed; no game files modified.
- Baseline: original addon archived; 767 old rows (708 unique IDs) inventoried.
- Source acquisition: 1,971 output-producing recipe records captured from the Forever data mirror. Recipes with no conventional item output still require separate coverage.
- Initial implementation: a combined-addon alpha was produced, then replaced by the modular alpha above after the user's correction. Original source remains under ignored `.work/legacy/`.
- Data: 532 canonical item IDs, 1,973 recipe records, all 15 initial enchanting omissions represented. Of 708 legacy IDs, 252 appear in the current evidence and 456 remain unresolved. There are 280 IDs absent from the original tables. Unresolved entries are not silently promoted or declared unavailable.
- Initial automated validation: 9 Python tests, 17 catalogue/inventory tests, and 12 simulated host/tooltip integration tests passed. Current counts appear above.
- Independent final review: no confirmed blocking defect. Initial concern about all zero-capacity bank tabs was revised after checking Forever's bought-but-unequipped bank slots. Added a source-grounded safeguard for a placed bank bag with unreadable capacity, plus regressions for both cases.
- Superseded packages: 0.1.0 through 0.3.6 alpha. Use the modular 0.3.2 package above. No installation or publishing performed by this implementation pass.

## Implementation rulings and costs

- Use a LibDataBroker object and native context menu instead of retaining the old Titan XML/menu adapter. This reduces dependencies on deprecated APIs; the cost is that actual Titan registration timing and mouse-wheel forwarding still need host validation.
- The alpha includes captured Forever client-table recipe evidence while live obtainability remains unverified. The release catalogue must undergo the stricter reconciliation described in the design. This permits testing the runtime now; its cost is that some entries may be inactive or missing until live data is reconciled.
- Preserve the old source in ignored local archives rather than Git commits/worktrees because this project deliberately has no Git repository. The cost is that review/history depends on the retained archive and these records.
- Use per-character container snapshots rather than aggregate item counts. This excludes equipped gear and account storage and makes freshness explicit; snapshots remain last observations when the bank cannot be read.

## Pending release gates

- Test the new package with installed Titan on the real Forever client using `book-wow-forever-validation.md`.
- Pin the actual client UI-source revision and obtain a matching full recipe/material dataset with obtainability evidence.
- Complete coverage for output-free enchantments, gathering/camping uses, supply requirements and curated auction-use items. The current catalogue is an alpha baseline.
- Observe actual bank readiness and transfer timing, including unused purchased bank slots and immediate closure after transfers.
- Version 0.3.2 implements the clarified zero-display requirement without requiring bank visits. Live accuracy of bank observations remains a separate validation gate; `/tgf` reports blocking container/read conditions or caught API errors.
- Validate manual/autoloot event order, gathering-source correlation, pin alignment during zoom and gamepad interaction, and persistence across reload/relog. Pins record approximate player position, not exact node coordinates.

## Deferred review item

The test host simulates LibDataBroker; it cannot certify Titan's actual callback forwarding. Paging is also available through `/tgf next` and `/tgf prev`, and the manual checklist calls out the mouse-wheel check explicitly.

## 0.3.5 review

Independent review found no blocking issue and confirmed the scale/projection/rotation logic. A minor replacement-canvas lifecycle finding was fixed with a failing-then-passing regression. The full checker now passes 109 checks plus shipped Lua compilation. Live visibility remains unverified while the client is at login; no installed files were changed.

## 0.3.6 live map visibility fix

Verified installed 0.3.5 and inspected the running client. Data, icon frames, texture, geometry and opacity were valid; three icons remained visually absent in MEDIUM strata. Raising the real icon frames to HIGH immediately revealed all three herb icons on Mulgore. Applied that exact change to icon creation and added a regression assertion. The current session has the temporary fix; packaged 0.3.6 makes it persistent after installation/reload. All 109 automated checks and Lua compilation pass. No installed addon files were written. Minimap had no saved spots within range of the stationary player, so its nearby display is not yet live-verified.

## 0.3.7 icon styling and caption

The user approved a live preview of circular item icons with a thin golden border and soft down/right shadow. A shared helper applies the same native atlas styling to world-map and minimap pins, preserving frame reuse and zoom sizing. The panel caption now shows the installed addon version instead of a material count, removing its extra inventory-count loop. Counts remain in tooltips. Final checker: 116 checks plus Lua compilation. The preview is session-only until installing the new package.


## 0.3.8 Skinning and material visibility

Successful Skinning casts followed by taken Creature loot record supported skinning materials. Each distinct obtained material gets its own observation; overlapping Skinning icons are separated visually without changing saved coordinates. Mining and Herbalism retain their primary-resource selection.

The map menu now has Mining, Herbalism and Skinning switches plus material checkboxes grouped by profession, with Show all and Hide all actions. Individual material filters hide icons on both maps while retaining observations and continuing collection. Master/profession switches stop collection and hide spots. Preferences persist across reloads.

Recording requires an outdoor, non-instance context at both cast and finalization. World transitions cancel pending gathering. Instance, raid, PvP and scenario observations are excluded. Independent review found no blocking issue. Live Skinning event timing, multiple-material corpse loot, source correlation after a recent cast and visual separation remain acceptance checks.


## 0.3.9 configuration submenus

Reorganized the context menu using the same nested description pattern as the installed Titan Panel's `Titan_Menu.AddButton`. Top-level entries now open Display, Professions, Additional items, Gathering map and Diagnostics sections. All checkboxes live inside a section. Gathering map includes Visibility, Professions and Map materials submenus, with material filters still grouped by profession. Existing saved settings and callbacks are retained. A hierarchical menu regression checks parent paths while the existing callback tests verify toggles, persistence and filtering. All 127 checks and Lua compilation pass; live menu navigation is pending reload.


## 0.3.10 map category clearing

Added a TGF v3 spots button on the world map. Its menu identifies the displayed map and counts saved Mining, Herbalism and Skinning spots, including hidden records. Each category opens an explicit confirmation action; zero-count categories are informational. Clearing affects only that map ID and category, cancels matching pending gathering, persists the deletion and refreshes both map renderers. Map changes before confirmation prevent deletion. Projected child-zone observations require selecting their source zone. All 131 automated checks and Lua compilation pass. Live button positioning and map-menu interaction await reload acceptance.


## 0.4.0 crafter history and acquisition evidence

Added separate movable Lifetime materials and Observed chances windows, available in History and sources or through `/tgf history` and `/tgf chances`. Each defaults to the current character and offers a combined view, profession filters, paging and clickable source lists. Combined percentages use summed eligible samples. Lifetime filters include both known consuming professions and personally observed profession outputs, including uncatalogued fish and secondary drops.

Added Fishing catches, all obtained mining/herbalism secondary resources, supported ordinary corpse/container materials and rare-quality or better ordinary drops. Material-source pins can be controlled by each loaded profession and individual item. Enchanting collects input-item outcomes without map pins. Rare ordinary loot requires the Include rare loot setting; known materials retain their profession recording rules.

History recording, rare acquisition, each profession and ordinary loot can be controlled independently of map visibility. Map switches stop map writes, while enabled history can continue. Instance acquisition is retained in history and separate rate groups; instance map recording is blocked. Clearing spots preserves lifetime totals. Map hover information adds observed zone/source rates.

Item tooltips, including recipe-material item tooltips, retain bags/bank/total and recipe-use information and add current-character lifetime quantities, up to three observed source rates, or existing map coordinates when no complete samples exist. Rates show outcomes/sample counts; quantities and current inventory remain separate.

Independent review found and resolved statistical and attribution defects with regressions. Final automated checker passes 167 checks. Live acceptance still covers native windows, recipe hover contexts, fishing/disenchant timing, money-slot events and input identity. The new history cannot reconstruct earlier lifetime totals or server drop tables. See `plan-wow-forever-history-and-sources.md` for rules and limitations.


## Public repository and release preparation

The user clarified the full product goal: lifetime statistics for every supported material and acquisition/production method, operation counts, contextual crafter assistance and later sharing/analysis. README.md distinguishes that goal from the current acquisition-only alpha. Crafting/cooking operation counters and dataset export remain planned.

Initialized source control inside the installed core as explicitly requested. Development JSON inputs moved to `catalogue/` to avoid the macOS data/Data collision and permit case-sensitive Linux builds. The generator reconstructs optional addon siblings from versioned inputs. Runtime files and saved game data are unaffected by that move.

The packager now stages a clean `dist/releases/0.4.0-alpha/` upload set: fifteen ZIPs, downloads.json and SHA256SUMS. Individual core and collection assets have unique filenames. A GitHub Actions workflow checks fresh source, creates the same downloads and publishes tagged releases. External GitHub creation currently fails because the CLI cannot connect to api.github.com; publication must be verified separately before claiming a live repository or release.


Release-preparation verification passes 169 checks. Fresh staged-source reconstruction regenerates all profession addons and reproduces the 17-file website download set byte-for-byte. Workflow YAML and an independent review pass. GitHub publication is blocked by api.github.com DNS resolution in the current environment; the local repository is prepared, but no remote publication is claimed.


## Official v3 name, 0.4.1-alpha

The official identity is Titan Gathered Forever v3, using TitanGatheredForeverV3 for the core folder, namespace and broker identifier. All thirteen optional addon folders and manifests use the same prefix. UI abbreviations use TGF v3; /tgf remains the command. Package filenames omit the redundant Forever segment because the new identifier already includes it.

The renamed saved table is TitanGatheredForeverV3DB. A non-destructive one-time migration tool preserves the previous data and refuses existing targets. No Git actions are part of this rename. The rename has been applied to the user's new development copy; the installed game copy has not been changed.


## Separate runtime from development content

The project now develops outside the game installation. All fourteen addon folders contain only game-required manifest files and artwork. Tools, tests, catalogue JSON, release notes, contributor guidance and prefixed documents moved to the collection root. Private archives and old repository metadata remain preserved in root .work; generated packages moved to root dist. The redundant core README/ignore files were archived privately.

Root commands and GitHub workflow paths were updated. A strict manifest-based regression verifies every addon folder's contents. The addon version remains 0.4.1-alpha because runtime behavior and packaged files are unchanged. All 177 checks and shipped Lua compilation pass; runtime/package hash verification accompanies this structural change. AGENTS.md was moved without changing its contents.
