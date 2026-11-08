# WoW Forever Development Progress

Updated 2026-11-08. Current roadmap: [plan-next-development.md](plan-next-development.md). Change summary: [unreleased development updates](release-notes/ref-unreleased.md). Detailed entries below are historical snapshots, including superseded designs and earlier test counts.

## Current state

The installed development candidate retains manifest version 0.4.1-alpha. It contains the shared core, twelve profession addons and Auction Items, with 56 allowlisted runtime files. The latest local installation was byte-verified against source and backed up. Current verification passes 360 checks (76 Python,284 Lua) and compilation of every shipped Lua file. Source commit/push is authorized by the current user request; no new version tag or release publication is part of it.

Implemented features include profession action counters, crafting/cooking production, fixed-reagent recipe planning, manual JSON export/reconstruction, faction-aware flight points and the small icon appearance window. Each is integrated with independent settings and preserves earlier acquired history. See the focused plans for API evidence, review findings and regression fixes.

Map markers use exact recorded/projected coordinates and original WoW artwork. World-map materials, minimap materials and flight points have separate size/shape/optional Thin gold outline settings. Mining prefers ore rather than a covering byproduct; all output quantities remain in statistics. Legacy byproduct observations are retained, and unmatched standalone points are not guessed into ore.

Catalogue evidence remains partial: 532 supported items, 1,973 combined recipe records and 23 Fishing materials. The four-table public crosscheck labelled 1.60.1.70862 reproduces all 1,971 base facts, while the mirror extraction build remains unknown. Completeness is false; 456 legacy IDs, 11 producer associations, output-free enchantments and live obtainability remain open.

## Live feedback and open work

- The user confirms the icon configurator works and the revised borderless/exact-position map appearance improved. Optional outlines were subsequently changed from white to gold at their request.
- Partial artwork clipping/offset, especially Linen Cloth, is still reported in every shape/size and with or without borders. Root cause is unconfirmed. No speculative texture/offset fix was deployed. The user is taking more time to test; obtain a current screenshot/reproduction.
- Real-client action/production event order, bank readiness, clipboard export round trips, native flight styling and full persistence/combined-character flows still need the live checklist.
- Catalogue coverage and availability are separate evidence work; current checks do not certify all server content.

## Standing deployment preference

Automatically install each completed, verified runtime update into /Applications/World of Warcraft/_forever_/Interface/AddOns using tools/install.py, retaining backups and checking installed bytes. This is recorded in AGENTS.md and .cursor/rules/automatic-live-install.mdc. Preserve SavedVariables, other addons and the user's control of the running game. Use /reload for Lua-only updates and a full restart when new files/assets require it. An identical verified installation does not need another backup/replacement.

The latest installed candidate is retained in the client; the immediately preceding folders are backed up under Interface/.tgf-v3-backups/candidate-7untgdf_. No account data was committed or edited directly, and no hosting change or new release tag was created.

## Implementation and installation history

### Gold icon outlines installed, 2026-11-08

User requested a gold optional border instead of white while taking more time to test the artwork-clipping issue. The existing transparent outline textures are tinted gold (1,0.82,0,1), and the configurator now labels the enabled option Thin gold. No shape, size, thickness, background, item texture or preference changes.

All 360 checks, shipped Lua compilation and whitespace checks pass. Installed and byte-verified all 56 runtime files; previous folders are backed up in Interface/.tgf-v3-backups/candidate-7untgdf_. Run /reload to load the gold tint. The reported artwork clipping/offset remains unresolved: direct computer inspection timed out, and further user testing/current screenshot evidence is pending. No speculative cropping fix was deployed.

### Mining marker identity correction

User reported a vein displaying stone instead of ore. Confirmed that active Sources.Record mapped every mining output at the same coordinates, whereas the older Gathering.Finalize path already preferred primary ore. The active path now selects one canonical mining resource by the existing module priority before recording the map pin. All ore, stone and gem quantities remain in history and source statistics. Unknown stone-only receipts do not create guessed ore markers; partial reopenings can later record the observed ore.

For saved data from earlier candidates, Gathering.List suppresses overlapping Mining byproduct pins only where a recorded primary ore lies within the existing 0.0025 merge radius. Original observations, counts and unmatched standalone material locations remain stored. Ordinary Loot recording and known scarce-resource fallback remain supported. Tests reproduce loot-order overlays and legacy display before the fixes; coverage includes partial loot, statistics retention and generic locations. Independent review found no important issues. All 360 checks (76 Python,284 Lua), shipped Lua compilation and whitespace checks pass. Installed the fix and byte-verified all 56 runtime files; previous folders are retained under Interface/.tgf-v3-backups/candidate-gff7901y. SavedVariables were not edited directly. Run /reload before mining to validate the live marker.

### Icon appearance configurator installed, 2026-11-08

User requested a small native window and confirmed separate settings for world-map materials, minimap materials and flight points. `/tgf icons` or Titan menu > Icon appearance opens the draggable window with sample previews, 12–40 px size controls, Circle/Full image choices and an optional thin white outline. Full image retains all source artwork; a larger circle still crops corners. Apply saves and refreshes all maps; Cancel/close discards unapplied changes; Reset group changes only its draft. Existing styles remain the defaults, saved locations do not move, and no item artwork is replaced.

Added normalized persistent settings, reusable masks and alpha-only outline assets, renderer size/shape wiring and reversible native flight-marker scaling/masking. Native provider ownership and click handlers remain intact. Independent review found diagonal square/outline minimap overflow; a failing regression preceded shape-aware containment. All 356 checks (76 Python,280 Lua) and shipped Lua compilation pass. No deferred findings. Actual UI, native flight-provider timing and readability require the new live checklist.

Installed the verified candidate into the live Forever AddOns directory. All 56 runtime files across fourteen addons match source exactly; previous folders are retained in Interface/.tgf-v3-backups/candidate-oviso3fq. Restart WoW fully because the update adds IconConfig.lua and two outline textures, then open `/tgf icons`. SavedVariables were not edited directly; only Apply in game saves appearance preferences. No version tag or publication created.

### Borderless flight points installed, 2026-11-08

User requested removal of the green square flight-marker border. Removed addon outlines from both custom flight markers and reused native markers; native artwork keeps its original shape. Discovery remains explicit in tooltip words, with faction filtering, undiscovered locations, native-marker deduplication and normal native click behavior preserved. This supersedes the earlier discovery-border color design. Gathering images remain circular and borderless.

Border-absence regressions failed before implementation; all 337 checks and shipped Lua compilation now pass. Updated the live Forever addon folders and verified all 53 runtime files match the candidate exactly. Previous folders are backed up in Interface/.tgf-v3-backups/candidate-6e26bqcx. SavedVariables and enablement were preserved. Run /reload for the next visual test; visual acceptance remains pending.

### Circular material icons installed, 2026-11-08

User confirmed the borderless exact-position map appearance and requested circular material images. Added only a circular alpha mask to gathering icons in PinStyle.Apply; no filled plates, rims, shadows or coordinate offsets return. World-map/minimap icons share this style. Flight icons and their separate discovery-status outlines remain unchanged.

The revised mask/pooling regression failed before implementation and passes afterward. All 337 checks and shipped Lua compilation pass. At explicit user request, installed the current candidate into the live Forever AddOns folder and verified all 53 runtime files match source exactly. Previous fourteen addon folders are backed up under Interface/.tgf-v3-backups/candidate-wn98hwjs. SavedVariables and enablement remain unchanged. Use /reload to load the revised Lua; visual acceptance is pending.

### Updated live candidate installation, 2026-11-07

At the user's explicit request, installed the current 0.4.1-alpha development candidate, including FlightPaths.lua and the dense-map icon correction, into /Applications/World of Warcraft/_forever_/Interface/AddOns. Ran all 337 checks successfully first, previewed, applied through tools/install.py, then verified all 53 runtime files across fourteen folders match the source candidate exactly. All fourteen previous v3 folders are retained under Interface/.tgf-v3-backups/candidate-7g6z4a3t. SavedVariables, addon enablement, Titan Panel and previous-generation addons were not changed.

WoW was running, so the installed files are updated on disk while the current session may still execute the earlier code. Restart WoW before live acceptance. This supersedes earlier notes that the flight feature and icon correction were not installed. No in-game result, version tag or published release is claimed.

### Reported dense-map pin correction, local candidate

User screenshot showed material icons spread into rows with oversized joined gold backgrounds. Confirmed PinStyle.Offset was deliberately moving co-located icons in both renderers; new coordinate/count regressions failed before removing those offsets and pass afterward. Default pin styling now draws only the source image, preserving alpha without circular cropping, filled rim discs or shadows. The flight feature retains status colors through a thin edge-only frame with a transparent center.

The user confirmed keeping WoW's existing material images without added borders. Source alpha is preserved; any opaque background within the native artwork remains part of that artwork. No replacement cutouts are needed under this clarified scope. Independent review found no important defects. A further zoom regression exposed a status outline shrinking below one UI pixel; proportional edge sizing fixes it. Full verification passes 337 checks (75 Python, 262 Lua), all shipped Lua compilation and whitespace checks. No installed game files or saved observations changed.

### Faction-aware flight points, local candidate

User requested all flight-master locations, including undiscovered routes, filtered by character faction and with discovery indicated by border color. Added independent Flight points menu and persistent toggle, live C_TaxiMap map nodes, Alliance/Horde plus neutral filtering, and green/amber/gray discovery borders with text tooltips. Current API availability defines coverage; unknown discovery is not classified as undiscovered.

FlightPaths.lua owns a separate world-map overlay, works without gathering/profession modules, pools markers and decorates matching native flight pins without replacing their click handlers. Disabling it restores native marker appearance. World, faction, taxi-status, map/canvas and zoom changes refresh the display. No node/discovery store, acquisition history or source-policy changes. This feature has not been copied into the running client; the earlier installed 0.4.1-alpha remains unchanged. Independent review found first-layout readiness and stale native-tooltip cleanup issues; both were reproduced with failing tests and fixed. Final verification passes 336 checks (75 Python, 261 Lua), including 19 focused flight cases and 54 host scenarios, plus all shipped Lua compilation.

### Live candidate installation, 2026-11-07

At the user’s explicit request, installed the latest local 0.4.1-alpha candidate into /Applications/World of Warcraft/_forever_/Interface/AddOns using tools/install.py after a clean 316-check run and preview. All 52 runtime files across fourteen folders match the current source candidate byte for byte, with no extra files. This was the first installation under the TitanGatheredForeverV3 folder names: all fourteen existing TitanGathered2 folders remain. SavedVariables and addon enablement were not changed.

WoW was running during this additive installation. A full client restart is required before testing the newly added folders. Disable the old TitanGathered2 generation and enable the v3 core and desired optional modules with Titan Panel. In-game loading and behavior have not yet been observed. The installer created Interface/.tgf-v3-backups/candidate-o63u1qkp; it is empty because no v3 folders existed to replace. No publication or release tag was created.

### Catalogue reconciliation, evidence-backed local pass

Read-only installation metadata reports 1.60.1.70862; the captured dataset's target stays 70790 with unknown extraction build. Pinned Data.lua commit 541dd23afba02f915a822d11acb19fd4c24df83e matches all 1,971 base numeric facts. Neither it nor its generator supplies an exact build. A separate offline reconstruction from four public Wago CSVs whose response filenames identify 1.60.1.70862 matches every base fact. Pinned hashes and an offline verifier preserve that scoped evidence without relabelling the mirror.

Fishing now includes seven more direct-reference materials: Oily Blackmouth, Firefin Snapper, Deviate Fish, Stonescale Eel, Raw Winter Squid, Darkclaw Lobster and Large Raw Mightfish. Its 23 materials load independently of Alchemy/Cooking. Global counts remain 532 items / 1,973 recipes. All 128 inherited memberships remain with repaired local provenance; 11 cross-profession output associations are review candidates, not removals.

Added deterministic reconciliation.json and tools/audit_catalog.py for build distinctions, provenance, unresolved IDs, coverage gates and nonexecuting source verification. Review reproduced source-overwriting file aliases and inconsistent audit/generator validation. Shared validation, output protection and a generator preflight guard resolve both.

Full verification: 316 checks (75 Python, 241 Lua), shipped Lua compilation and pinned-source/report checks. Milestone 6 remains open: 456 unresolved IDs, producer associations, output-free enchants, obtainability and wider useful-item scope need evidence. No game files, SavedVariables, hosting or releases changed. Follow the reconciliation playbook and live gates.

### Statistics export, local candidate

Added schema-1 JSON snapshots with current/combined selection, explicit character identity opt-in and a manual-copy window opened through `/tgf export`. Exports whitelist aggregates, source eligibility policies, zero/partial observation distinctions, action outcomes, production quantities/distributions and known-field proc denominators. Names/GUIDs are off by default, with no raw receipts, coordinates, arbitrary labels or inventory data. Combined summaries sum eligible counts; unknown starts remain unknown.

Snapshots remain fixed while copying and reset identity on hide. Large payloads use numbered checksum/byte-count envelopes. `tools/read_export.py` reconstructs and validates JSON framing/version/selection and part integrity, rejecting incomplete/mixed/duplicate data without overwriting files. It does not import, send data or certify statistical semantics. The format reference and live checklist document the workflow.

Review found identity lookup traversing unsupported future stores; a failing regression preceded the fix. Additional checks cover malformed version-label privacy, finite-number parsing and UTF-8 boundaries. Full local verification: 288 checks (48 Python, 240 Lua), including 14 export, seven copy-window and 53 host scenarios, plus shipped Lua compilation. No installation, publication or clipboard validation performed. Known minor: truncation blocks Select text but native manual selection can remain possible; rejected parts must not be used.

### Contextual crafting assistance, local candidate

Added on-demand live recipe planning in `Crafting.lua` and a six-row native reagent window in `CraftingView.lua`. `/tgf recipe <recipeID> [operations]`, native selection, Titan menu, production details and known recipe examples provide entry points. Plans aggregate repeated item slots and show required/available/missing quantities, material-limited operations and freshness for the selected Bags or Bags + Bank scope. Unknown inventory and complex required choices withhold the overall estimate. Optional reagents are excluded, and material limits do not certify skills, tools or cooldowns.

Native reagent tooltips add at most two short selected-recipe lines. Source hints prioritize larger personal samples; source menus expose saved positions separately from complete loot trials. Map pin and chance-report labels explicitly distinguish source/zone observations from probabilities at a coordinate. No bulk recipe catalogue is loaded and planning itself changes no acquired/produced history, actions or map data.

Independent review exposed an incorrect slot enum repeated by the fixtures and stale planner results after disabling a profession; corrected API-shaped fixtures failed before both fixes. Native rank selection now follows the highest learned schematic, while explicit IDs remain exact. Full checker: 258 checks, including 16 calculation/API, five planner-window and 52 host checks, plus shipped Lua compilation. No installation, publication or live-client validation performed. Follow the contextual-crafting checklist before release.

### Crafting and cooking production, local candidate

Added `Production.lua` with separate schema-1 per-character recipe aggregates, 1024 recent cast receipts, observed-start requirements and dedicated result-event attribution. `/tgf production` reports completed casts separately from matched result operations, observed output quantities/distributions and explicit proc-field denominators. Recording controls are independent of acquired history, gathering actions and map display. Tooltips and lifetime rows show crafted quantities separately; production does not enter loot-source samples or maps.

Pinned Forever metadata establishes recipe/profession/result API shape. Missing, protected, unsupported or ambiguous data is excluded. Recent sealed casts block post-gap attribution; first-craft rewards and secondary outputs arriving before primary binding are omitted. Explicit recraft/dummy/gathering/enchant/salvage recipe flags are excluded; recrafts that reuse ordinary identities remain a live acceptance concern. No complete coverage or server probability claim is made.

Independent review identified delayed-result misattribution across gaps and missing recraft flags; both were reproduced with failing tests and fixed. Full verification: 232 checks, including 18 production, 47 host and seven report checks, plus all shipped Lua compilation. No installation, publication or real-client execution was performed. Follow the new production checklist before release.

### Profession action counters, local candidate

Added schema-1 per-character action storage, bounded cast receipts and independent recording for Mining, Herbalism, Skinning, Fishing and Disenchanting. `/tgf actions` and its menu entry open a third native report with current/combined selection, profession filters and first-observation coverage dates. Counts distinguish attempts, completions, failures, interruptions, stops without confirmed results and unresolved observations. Fishing launch is not a completion; a confirmed fishing-loot window is required. Source rates, quantities and map observations remain independent.

Reloads, world transitions and recording-policy changes seal old receipts. Disabled modules retain existing totals. A regression prevents late old fishing events from invalidating the current catch. Full local checker: 208 checks, including 14 action checks, 42 host scenarios and six report scenarios, plus shipped Lua compilation. No live installation or real-client validation was performed. The pinned Forever UI source establishes handler payloads but not the exact installed build or Fishing lifecycle; follow the new validation checklist before claiming reliable live coverage.

### Safe candidate installer

Milestone 1 adds `tools/install.py`: explicit Interface/AddOns destination, preview by default, runtime-only candidate staging through the package allowlist, retained backups outside AddOns and rollback on installation errors. Unrelated addons, previous-generation folders and SavedVariables are preserved. The release playbook documents development, preview/apply, recovery and live validation. Twelve temporary-directory installer tests pass; full verification is 189 checks plus Lua 5.1 compilation. No real-client installation or runtime addon changes were performed.

### Decisions

- User authorized autonomous execution. Default auction scope is curated useful items with specific reasons; no live pricing or auction automation.
- The source copy originally had no Git metadata. The user subsequently requested a public GitHub repository: initialize the installed core as the repository, preserve `.work/original-addon.zip` locally and exclude unrelated addons.
- Installed game metadata confirms 1.60.1.70790, wowf; the existing Scout observation independently records interface 16001. Titan 9.3.5 and Gathered 0.2.0-alpha are now installed. Retain an explicit in-game verification gate for the new package.
- LuaJIT supplies Lua 5.1 semantics. Do not use the installed Lua 5.5 parser as a release gate.
- Bank inventory uses Forever's tab metadata, not the copied addon's old counting assumptions. Persist complete personal-bank snapshots by player GUID.
- Imported numeric recipe facts are from a documented Forever client-table mirror. Its exact extraction build is unspecified; completeness and live obtainability must remain unverified. Do not promote that evidence into a release-completeness claim.

### Historical modular alpha 0.4.1 baseline

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

### Previous autonomous alpha pass

- Runtime discovery: installed build confirmed; no game files modified.
- Baseline: original addon archived; 767 old rows (708 unique IDs) inventoried.
- Source acquisition: 1,971 output-producing recipe records captured from the Forever data mirror. Recipes with no conventional item output still require separate coverage.
- Initial implementation: a combined-addon alpha was produced, then replaced by the modular alpha above after the user's correction. Original source remains under ignored `.work/legacy/`.
- Data: 532 canonical item IDs, 1,973 recipe records, all 15 initial enchanting omissions represented. Of 708 legacy IDs, 252 appear in the current evidence and 456 remain unresolved. There are 280 IDs absent from the original tables. Unresolved entries are not silently promoted or declared unavailable.
- Initial automated validation: 9 Python tests, 17 catalogue/inventory tests, and 12 simulated host/tooltip integration tests passed. Current counts appear above.
- Independent final review: no confirmed blocking defect. Initial concern about all zero-capacity bank tabs was revised after checking Forever's bought-but-unequipped bank slots. Added a source-grounded safeguard for a placed bank bag with unreadable capacity, plus regressions for both cases.
- Superseded packages: 0.1.0 through 0.3.6 alpha. Use the modular 0.3.2 package above. No installation or publishing performed by this implementation pass.

### Implementation rulings and costs

- Use a LibDataBroker object and native context menu instead of retaining the old Titan XML/menu adapter. This reduces dependencies on deprecated APIs; the cost is that actual Titan registration timing and mouse-wheel forwarding still need host validation.
- The alpha includes captured Forever client-table recipe evidence while live obtainability remains unverified. The release catalogue must undergo the stricter reconciliation described in the design. This permits testing the runtime now; its cost is that some entries may be inactive or missing until live data is reconciled.
- Preserve the old source in ignored local archives rather than Git commits/worktrees because this project deliberately has no Git repository. The cost is that review/history depends on the retained archive and these records.
- Use per-character container snapshots rather than aggregate item counts. This excludes equipped gear and account storage and makes freshness explicit; snapshots remain last observations when the bank cannot be read.

### Pending release gates

- Test the new package with installed Titan on the real Forever client using `book-wow-forever-validation.md`.
- Pin the actual client UI-source revision and obtain a matching full recipe/material dataset with obtainability evidence.
- Complete coverage for output-free enchantments, gathering/camping uses, supply requirements and curated auction-use items. The current catalogue is an alpha baseline.
- Observe actual bank readiness and transfer timing, including unused purchased bank slots and immediate closure after transfers.
- Version 0.3.2 implements the clarified zero-display requirement without requiring bank visits. Live accuracy of bank observations remains a separate validation gate; `/tgf` reports blocking container/read conditions or caught API errors.
- Validate manual/autoloot event order, gathering-source correlation, pin alignment during zoom and gamepad interaction, and persistence across reload/relog. Pins record approximate player position, not exact node coordinates.

### Deferred review item

The test host simulates LibDataBroker; it cannot certify Titan's actual callback forwarding. Paging is also available through `/tgf next` and `/tgf prev`, and the manual checklist calls out the mouse-wheel check explicitly.

### 0.3.5 review

Independent review found no blocking issue and confirmed the scale/projection/rotation logic. A minor replacement-canvas lifecycle finding was fixed with a failing-then-passing regression. The full checker now passes 109 checks plus shipped Lua compilation. Live visibility remains unverified while the client is at login; no installed files were changed.

### 0.3.6 live map visibility fix

Verified installed 0.3.5 and inspected the running client. Data, icon frames, texture, geometry and opacity were valid; three icons remained visually absent in MEDIUM strata. Raising the real icon frames to HIGH immediately revealed all three herb icons on Mulgore. Applied that exact change to icon creation and added a regression assertion. The current session has the temporary fix; packaged 0.3.6 makes it persistent after installation/reload. All 109 automated checks and Lua compilation pass. No installed addon files were written. Minimap had no saved spots within range of the stationary player, so its nearby display is not yet live-verified.

### 0.3.7 icon styling and caption

The user approved a live preview of circular item icons with a thin golden border and soft down/right shadow. A shared helper applies the same native atlas styling to world-map and minimap pins, preserving frame reuse and zoom sizing. The panel caption now shows the installed addon version instead of a material count, removing its extra inventory-count loop. Counts remain in tooltips. Final checker: 116 checks plus Lua compilation. The preview is session-only until installing the new package.


### 0.3.8 Skinning and material visibility

Successful Skinning casts followed by taken Creature loot record supported skinning materials. Each distinct obtained material gets its own observation; overlapping Skinning icons are separated visually without changing saved coordinates. Mining and Herbalism retain their primary-resource selection.

The map menu now has Mining, Herbalism and Skinning switches plus material checkboxes grouped by profession, with Show all and Hide all actions. Individual material filters hide icons on both maps while retaining observations and continuing collection. Master/profession switches stop collection and hide spots. Preferences persist across reloads.

Recording requires an outdoor, non-instance context at both cast and finalization. World transitions cancel pending gathering. Instance, raid, PvP and scenario observations are excluded. Independent review found no blocking issue. Live Skinning event timing, multiple-material corpse loot, source correlation after a recent cast and visual separation remain acceptance checks.


### 0.3.9 configuration submenus

Reorganized the context menu using the same nested description pattern as the installed Titan Panel's `Titan_Menu.AddButton`. Top-level entries now open Display, Professions, Additional items, Gathering map and Diagnostics sections. All checkboxes live inside a section. Gathering map includes Visibility, Professions and Map materials submenus, with material filters still grouped by profession. Existing saved settings and callbacks are retained. A hierarchical menu regression checks parent paths while the existing callback tests verify toggles, persistence and filtering. All 127 checks and Lua compilation pass; live menu navigation is pending reload.


### 0.3.10 map category clearing

Added a TGF v3 spots button on the world map. Its menu identifies the displayed map and counts saved Mining, Herbalism and Skinning spots, including hidden records. Each category opens an explicit confirmation action; zero-count categories are informational. Clearing affects only that map ID and category, cancels matching pending gathering, persists the deletion and refreshes both map renderers. Map changes before confirmation prevent deletion. Projected child-zone observations require selecting their source zone. All 131 automated checks and Lua compilation pass. Live button positioning and map-menu interaction await reload acceptance.


### 0.4.0 crafter history and acquisition evidence

Added separate movable Lifetime materials and Observed chances windows, available in History and sources or through `/tgf history` and `/tgf chances`. Each defaults to the current character and offers a combined view, profession filters, paging and clickable source lists. Combined percentages use summed eligible samples. Lifetime filters include both known consuming professions and personally observed profession outputs, including uncatalogued fish and secondary drops.

Added Fishing catches, all obtained mining/herbalism secondary resources, supported ordinary corpse/container materials and rare-quality or better ordinary drops. Material-source pins can be controlled by each loaded profession and individual item. Enchanting collects input-item outcomes without map pins. Rare ordinary loot requires the Include rare loot setting; known materials retain their profession recording rules.

History recording, rare acquisition, each profession and ordinary loot can be controlled independently of map visibility. Map switches stop map writes, while enabled history can continue. Instance acquisition is retained in history and separate rate groups; instance map recording is blocked. Clearing spots preserves lifetime totals. Map hover information adds observed zone/source rates.

Item tooltips, including recipe-material item tooltips, retain bags/bank/total and recipe-use information and add current-character lifetime quantities, up to three observed source rates, or existing map coordinates when no complete samples exist. Rates show outcomes/sample counts; quantities and current inventory remain separate.

Independent review found and resolved statistical and attribution defects with regressions. Final automated checker passes 167 checks. Live acceptance still covers native windows, recipe hover contexts, fishing/disenchant timing, money-slot events and input identity. The new history cannot reconstruct earlier lifetime totals or server drop tables. See `plan-wow-forever-history-and-sources.md` for rules and limitations.


### Public repository and release preparation

The user clarified the full product goal: lifetime statistics for every supported material and acquisition/production method, operation counts, contextual crafter assistance and later sharing/analysis. README.md distinguishes that goal from the published acquisition alpha and local action/production/planning/export candidate. Build-matched catalogue reconciliation and real-client acceptance remain pending.

Initialized source control inside the installed core as explicitly requested. Development JSON inputs moved to `catalogue/` to avoid the macOS data/Data collision and permit case-sensitive Linux builds. The generator reconstructs optional addon siblings from versioned inputs. Runtime files and saved game data are unaffected by that move.

The packager now stages a clean `dist/releases/0.4.0-alpha/` upload set: fifteen ZIPs, downloads.json and SHA256SUMS. Individual core and collection assets have unique filenames. A GitHub Actions workflow checks fresh source, creates the same downloads and publishes tagged releases. External GitHub creation currently fails because the CLI cannot connect to api.github.com; publication must be verified separately before claiming a live repository or release.


Release-preparation verification passes 169 checks. Fresh staged-source reconstruction regenerates all profession addons and reproduces the 17-file website download set byte-for-byte. Workflow YAML and an independent review pass. GitHub publication is blocked by api.github.com DNS resolution in the current environment; the local repository is prepared, but no remote publication is claimed.


### Official v3 name, 0.4.1-alpha

The official identity is Titan Gathered Forever v3, using TitanGatheredForeverV3 for the core folder, namespace and broker identifier. All thirteen optional addon folders and manifests use the same prefix. UI abbreviations use TGF v3; /tgf remains the command. Package filenames omit the redundant Forever segment because the new identifier already includes it.

The renamed saved table is TitanGatheredForeverV3DB. A non-destructive one-time migration tool preserves the previous data and refuses existing targets. No Git actions are part of this rename. The rename has been applied to the user's new development copy; the installed game copy has not been changed.


### Separate runtime from development content

The project now develops outside the game installation. All fourteen addon folders contain only game-required manifest files and artwork. Tools, tests, catalogue JSON, release notes, contributor guidance and prefixed documents moved to the collection root. Private archives and old repository metadata remain preserved in root .work; generated packages moved to root dist. The redundant core README/ignore files were archived privately.

Root commands and GitHub workflow paths were updated. A strict manifest-based regression verifies every addon folder's contents. The addon version remains 0.4.1-alpha because runtime behavior and packaged files are unchanged. All 177 checks and shipped Lua compilation pass; runtime/package hash verification accompanies this structural change. AGENTS.md was moved without changing its contents.
