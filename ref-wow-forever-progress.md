# WoW Forever Development Progress

Updated 2026-11-10. Current roadmap: [plan-next-development.md](plan-next-development.md). Change summary: [unreleased development updates](release-notes/ref-unreleased.md). Detailed entries below are historical snapshots, including superseded designs and earlier test counts.

## Current state

The installed development candidate uses manifest version 0.4.10-alpha and the short panel caption TG3 Forever - v0.4.10. All 57 allowlisted runtime files across the shared core, twelve profession addons and Auction Items match the source package byte-for-byte, with no extra installed files. Previous folders are backed up at `Interface/.tgf-v3-backups/candidate-8yyuttu1`. `python3 tools/check.py` passes all Python and Lua suites, catalogue validation and Lua 5.1 compilation. Titan headings and profession menu labels use bright gold (#FFD100). Learned profession names and ranks use four percentage bands against the current maximum. Actual world-vein tooltips now have a guarded native Object callback for readable object IDs identified in mining history, with zone and character scoped complete sample counts, observed percentages and quantities. The screenshot verifies the previous version's running panel; live acceptance of the new native tooltip remains open. Run `/reload` for the Lua change; if the version caption is stale, restart the client to reread manifest metadata. No source push, release publication or hosting changes were performed. The 0.4.6-alpha update adds a divider above explanatory text on world vein, world-map pin and minimap pin tooltips. The 0.4.7-alpha update adds a divider above the Titan Panel hover footer.

Implemented features include profession action counters, crafting/cooking production, fixed-reagent recipe planning, manual JSON export/reconstruction, faction-aware flight points, the small icon appearance window and the PvP Board with outdoor kill spots. Each is integrated with independent settings and preserves earlier acquired history. The PvP client totals, rank functions, honor events and death-recap attribution still require live Forever-client acceptance. The user should run `/reload` to load this Lua-only update. See the focused plans for API evidence, review findings and regression fixes.

Map markers use exact recorded/projected coordinates and original WoW artwork. World-map materials, minimap materials and flight points have separate size/shape/optional Thin gold outline settings. Mining prefers ore rather than a covering byproduct; all output quantities remain in statistics. Legacy byproduct observations are retained, and unmatched standalone points are not guessed into ore.

Catalogue evidence remains partial: 532 supported items, 1,973 combined recipe records and 23 Fishing materials. The four-table public crosscheck labelled 1.60.1.70862 reproduces all 1,971 base facts, while the mirror extraction build remains unknown. Completeness is false; 456 legacy IDs, 11 producer associations, output-free enchantments and live obtainability remain open.

## Live feedback and open work

- The user confirms the icon configurator works and the revised borderless/exact-position map appearance improved. Optional outlines were subsequently changed from white to gold at their request.
- The user confirms shared Linen Cloth visibility works across First Aid and Tailoring. Cloth artwork currently looks correct; leave the earlier clipping/overlap report under observation without a speculative texture/offset change.
- A later screenshot confirmed overlapping report titles, descriptions and rows. The user confirms the compact report list changed, then requested per-item lifetime loot/gather occurrence totals in addition to quantities. The occurrence correction is covered below; detailed live event and layout acceptance remains open.
- Real-client action/production event order, bank readiness, clipboard export round trips, native flight styling and full persistence/combined-character flows still need the live checklist.
- Catalogue coverage and availability are separate evidence work; current checks do not certify all server content.

## Standing deployment preference

Automatically install each completed, verified runtime update into /Applications/World of Warcraft/_forever_/Interface/AddOns using tools/install.py, retaining backups and checking installed bytes. This is recorded in AGENTS.md and .cursor/rules/automatic-live-install.mdc. Preserve SavedVariables, other addons and the user's control of the running game. Use /reload for Lua-only updates and a full restart when new files/assets require it. An identical verified installation does not need another backup/replacement.

The latest 0.4.2-alpha candidate is retained in the client; the immediately preceding folders are backed up under Interface/.tgf-v3-backups/candidate-yndg5ybt. No account data was committed or edited directly, and no hosting change or new release tag was created.

## Implementation and installation history

### Expandable lifetime sources, 0.4.2-alpha

Replaced joined lifetime chance summaries with a compact parent material row and dedicated plus/minus expansion. Every source has a separate label, percentage and hits/samples. All source groups are retained, including more than three; continuation pages repeat the parent material, and the clicked material stays anchored to visible evidence. Collapsing clamps page bounds. Unknown evidence has no expander. Combined percentages continue to use summed complete trials, while item quantities and stored acquired/produced evidence stay unchanged.

The full checker passes 408 checks and all Lua 5.1 compilation. Independent review found no critical/important issue. Very long labels are height-bounded; full source actions/labels remain available through the item menu. Automated tests do not certify client font rendering. Safe installer preview/apply completed; all 57 installed runtime files across fourteen addons match the 0.4.2-alpha package byte-for-byte. Backup: Interface/.tgf-v3-backups/candidate-yndg5ybt. Run /reload for live acceptance.


### Interface refinements installed, 2026-11-09

Replaced the lifetime last-location column with up to three separate source/zone observed drop chances and hit/sample denominators; the full click menu remains available. Removed unnamed numeric source labels. Crafting/cooking now uses compact columns and completion percentages alongside attempts, completions, matched operations and items. Bonus/multicraft percentages retain readable-field denominators; Unknown stays explicit. Quantities, receipts, acquired/produced history and export semantics are preserved.

Item totals appear only when both bags and bank contain the item. Panel counts omit totals, use compact slash separators and keep zero-display behavior. The panel caption is TG3 Forever - v0.4.1. Supporting tooltip/menu notes use small fonts; original tooltip fonts restore on clear. Flight menu explanations are removed. Record PvP lifetime history independently controls new addon kills/deaths and spots, retaining historical observations and native totals.

Flight points use green for interaction-confirmed visits, amber for explicit undiscovered flags and gray for unconfirmed discovery. Only the Current taxi node during a flight-master interaction is persisted per character. Previous visits cannot be reconstructed and require another observed interaction. Tracking exists before the world map loads and remains active with flight display off. Native pin tint updates and click handlers survive decoration/removal. Two lifecycle issues found during independent review were reproduced and fixed with regressions.

Verification: 405 checks, shipped Lua compilation and clean whitespace checks. Safe installer preview/apply succeeded; all 57 runtime files match source across fourteen addons. Backup: Interface/.tgf-v3-backups/candidate-eqi9ea04. Live acceptance is deferred; /reload loads this Lua-only update.


### Lifetime acquisition occurrences installed, 2026-11-08

After confirming the compact report list changed, the user requested the lifetime number of times each item was looted or gathered. The report previously exposed acquired quantity without a per-item source occurrence total. Added Times obtained beside quantity: one occurrence per item per observed source receipt, including partial loot. Additional stacks or partial deliveries within that receipt do not add another occurrence. Empty outcomes and failed casts do not create item occurrences. Casting actions, completed-source samples and crafted output remain separate.

History stores additive per-item acquisitions and acquisitionsIncomplete fields. Legacy migration recovers completed-source item hits plus retained positive partial/invalidated receipts, without counting valid completed receipts twice. Because old partial receipts may have expired, legacy counts remain lower bounds: N+ when some evidence remains, otherwise Unknown. Reloads retain the migrated counters; current/combined views sum counts and propagate uncertainty. Receipt deduplication retains the existing bounded 1024-source history limitation. The acquired-item JSON export includes both fields additively within schema 1; production items do not receive acquired-source counters.

The initial regression failed because occurrence counts were missing. Four new history tests cover partial deliveries, complete duplicates, migration/unknown history, reload, receipt eviction and combined uncertainty. Report/export regressions cover distinct columns, lower-bound display and acquired-only fields. All 372 checks (76 Python,296 Lua), shipped Lua compilation and whitespace checks pass. Independent review found no important or critical issues. Real-client occurrence semantics and event timing remain a live acceptance gate.

Installer preview and apply completed; all 56 runtime files across fourteen addons match source exactly, with no extra installed files. Previous folders are backed up under Interface/.tgf-v3-backups/candidate-bqc6q0b1. No SavedVariables were edited directly. Run /reload and compare Times obtained with quantity after looting/gathering. Version remains 0.4.1-alpha; no commit, source push, tag or publication was performed.

### Compact report layout installed, 2026-11-08

User screenshot showed Lifetime materials, Observed chances and Profession actions rendering on top of one another. Reports.Show kept every report visible at nearly identical positions. The user approved exclusive report visibility, compact columns and wrapped source descriptions. Opening a report now hides the others, including the production report, while retaining each report’s character scope, profession filter and page.

The window is now 960 by 560 with 930 pixels of content width. Lifetime columns separate material, obtained quantity, crafted quantity and last obtained location. Chances separate material, observed percentage, hits/samples, obtained quantity and source/zone. Actions separate all outcome counts and recording start; stopped results and gaps remain explicit in the description. Production retains its detailed result format. Reusable rows measure wrapped text and paginate within the content area above the footer. Extremely long text is bounded within a page; item tooltips and source menus remain available. Statistics, SavedVariables and item/source identities were not rewritten.

A lifecycle regression reproduced the overlapping windows before implementation. The ten report scenarios now cover exclusive visibility, retained report state, column values, acquired/crafted separation, wrapped long names/sources, all-entry pagination, empty views and bounds, native item hover and production detail interactions. Full verification passes 366 checks (76 Python,290 Lua), shipped Lua compilation and whitespace checks. Independent review found no actionable issues. Live font wrapping, readability and native interaction acceptance remain pending.

Installer preview and apply completed successfully. All 56 runtime files across fourteen addons were byte-verified against source, with no extra installed files. Previous folders are backed up under Interface/.tgf-v3-backups/candidate-38za0z8r. Run /reload, then open the reports in succession and inspect the new columns. Version remains 0.4.1-alpha; no commit, push, new release tag or publication was performed.

### Shared material visibility installed, 2026-11-08

User screenshots and follow-up testing showed that Linen Cloth spots could be independently hidden under First Aid and Tailoring. Ordinary material loot is recorded under each consuming profession, and the old item filters were also keyed by profession. The user approved one shared visibility setting per item, accessible from either submenu.

Added item-ID-keyed visibility preferences and shared checkbox/bulk callbacks. Show all and Hide all apply globally to materials in that submenu; profession-wide switches remain independent. Any explicit legacy hidden material migrates to hidden globally unless a shared choice already exists. Later shared choices survive reloads. Existing spot records, coordinates, counts, history and collection while hidden remain intact. This correction does not deduplicate overlapping markers or establish a texture-clipping cause.

The new regression failed before implementation because hiding First Aid cloth left Tailoring cloth visible. Three new integration scenarios cover both submenu paths, shared bulk actions, mixed legacy settings, reload persistence, independent profession gates and continued recording/history while hidden. All 363 checks (76 Python,287 Lua), shipped Lua compilation and whitespace checks pass. Independent review found no actionable issues.

Installer preview and apply completed; all 56 runtime files across fourteen addons were byte-verified against source with no extra installed files. Previous folders are retained under Interface/.tgf-v3-backups/candidate-p1l5kps8. No SavedVariables were edited directly. Run /reload, then toggle Linen Cloth under First Aid and Tailoring to validate the shared live behavior. No commits, source push, version tag or publication were performed.

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

### Trainer and recipe vendor design, 2026-11-12

Design recorded in plan-npc-sources.md. The classic-db 1.12.1 dump was downloaded to a scratch directory, pinned by commit and SHA-256, and a throwaway parse found 284 profession trainers and 230 recipe vendors with spawns. GPL-3.0 `LICENSE` and `NOTICE` were added. No runtime code, manifest or version changed, so nothing was installed.

### Trainer and recipe vendor feature, 0.4.12-alpha, 2026-11-12

Implemented per plan-npc-sources-implementation.md: pinned seed generator and generated Data/NpcSeed.lua (190 KB, 458 NPCs: 247 trainers and 211 recipe vendors on continents only), NpcSources, NpcObserver, KnownRecipes and RecipeBrowser modules, world map and minimap pins, menu toggles with a profession filter, /tgf npc, /tgf recipes, and LICENSE/NOTICE packaging. All 86 Python tests and every Lua suite pass, including 14 NpcSources, 8 NpcObserver, 4 KnownRecipes and 4 RecipeBrowser checks, and all shipped Lua files compile with Lua 5.1 semantics. tools/check.py now closes stdin for its subprocesses after a LuaJIT compile step hung on an open pipe.

The candidate was installed with tools/install.py. All 64 installed files match the source candidate and all 14 manifests read 0.4.12-alpha. Previous folders: Interface/.tgf-v3-backups/candidate-zhwty_pc. New files and manifest entries require a full client restart.

Live validation (open, separate from automated checks):
- [ ] Pins appear on the world map and minimap at plausible positions; /tgf npc names a nearby trainer; /tgf npc swap fixes mirrored placement if needed.
- [ ] Continent UiMapIDs 1414 (Kalimdor) and 1415 (Eastern Kingdoms) are correct for Forever.
- [ ] Opening a profession trainer stores profession, services, skill and cost (trainer API behaviour).
- [ ] Opening a recipe vendor stores recipe items with price and the required skill parsed from the tooltip.
- [ ] Opening each profession window marks recipes as known; the Unlearned recipes window reflects it.
- [ ] Tooltip text, the 15-line cap and the menu toggles behave as designed; no Lua errors with /console scriptErrors 1.

### Menu covers every parameterless command, 0.4.13-alpha, 2026-11-12

The right-click menu gained Refresh inventory and Show status report (Diagnostics), Next and Previous summary page (Display), and Find nearest trainer or vendor pin plus a Swap map axes checkbox (Trainers and recipe vendors, Pin placement). Slash commands and menu share one implementation (ns.ShowStatus, ns.ChangeSummaryPage, ns.NpcNearest, ns.NpcToggleAxes). Only /tgf recipe <recipeID> [operations] stays documented, because it needs a parameter; other commands still work as undocumented shortcuts. tools/check.py and the pin outline check pass, including a new integration test for the menu entries. Installed with tools/install.py, all 64 installed files match the source and all 14 manifests read 0.4.13-alpha. Previous folders: Interface/.tgf-v3-backups/candidate-kwogl7e0. Lua-only changes to existing files plus no new files, so /reload is enough.


### Beta stage, 0.5.0-beta, 2026-11-12

The project left alpha at the owner's request. Version 0.5.0-beta was applied to the core manifest, generator VERSION and all generated profession manifests, with README, AGENTS.md versioning rule, roadmap baseline and unreleased notes updated. Earlier versioned notes and downloads keep their alpha names. Version-only change: runtime behavior equals 0.4.13-alpha. tools/check.py and the catalogue check pass. Installed with tools/install.py, all 64 installed files match the source and all 14 manifests read 0.5.0-beta. Previous folders: Interface/.tgf-v3-backups/candidate-kulx7m8v. Live validation checklists above remain open, so beta means feature complete with unverified client behavior. /reload is enough (no new files).

### First live finding and NPC recording log, 0.5.1-beta, 2026-11-12

Live test on Forever: map pins appeared and /tgf npc named the nearest trainer, but after opening a trainer window its pin tooltip still read Not yet confirmed in game, so no observation was stored. The cause is not yet known (event not delivered, NPC identity, empty or different trainer API answers, or no skill requirement from the client). 0.5.1-beta adds a bounded log of the last 12 trainer and merchant recording attempts (npcLog in SavedVariables) with the outcome and raw API answers, and Diagnostics > Show NPC recording log. Recording behavior is unchanged. All automated checks pass; installed with tools/install.py, all 64 files match and all 14 manifests read 0.5.1-beta. Previous folders: Interface/.tgf-v3-backups/candidate-liouj14j. /reload is enough. Next: read the log from the live client and fix the recording path.

### Trainer list timing fix, 0.5.2-beta, 2026-11-12

The 0.5.1 recording log from the live client showed TRAINER_SHOW delivering the NPC correctly (GUID, name, map 1426, not in an instance) while GetNumTrainerServices returned 0 at that moment; the C_TrainerUI table does not exist, so the classic trainer API is the one in use. The client fills the list shortly afterwards. 0.5.2-beta reads trainer and merchant data again on TRAINER_UPDATE and MERCHANT_UPDATE while the window is open and stops on the CLOSED events. All automated checks pass; installed with tools/install.py, all 64 files match and all 14 manifests read 0.5.2-beta. /reload is enough. Live re-test pending: the pin tooltip should read Confirmed in game after the trainer window is opened; whether GetTrainerServiceSkillReq returns a skill name is still unverified and the log will say so.

### Live validation results, trainers, 2026-11-12

Evidence from the 0.5.2-beta recording log and saved npcs table on WoW Forever 1.60.1 (character on a PvE realm, Ironforge, map 1426):
- Confirmed: the pin tooltip changes to Confirmed in game after a trainer window is opened.
- Confirmed: TRAINER_SHOW delivers the NPC (GUID, name, map, not in an instance) but GetNumTrainerServices returns 0 at that moment; TRAINER_UPDATE then returns the full list (10 services for Dank Drizzlecut, 7 for Cook Ghilm). Reading again on update fixed recording in 0.5.2-beta.
- Confirmed: GetTrainerServiceSkillReq returns the profession name and required rank (for example Mining, 125), so the profession is identified. GetTrainerServiceCost returns the copper cost. C_TrainerUI does not exist, so the classic trainer API is the one in use.
- Observed: Forever has recipes absent from the Classic 1.12.1 seed (for example Azerothium Bar at skill 275), which supports letting observed data replace seed data.
- Still open: recipe vendor recording (price and required skill parsed from the merchant tooltip), known recipe reading from profession windows with the Unlearned recipes window, continent UiMapIDs 1414 and 1415 for the row click, and the 15-line tooltip cap on a large vendor.

### Merchant API finding, 0.5.3-beta, 2026-11-12

Live merchant log (Kazan Mogosh, NPC 1237, 18 items): MERCHANT_SHOW delivered the NPC, GetMerchantNumItems returned 18 and item links work, but GetMerchantItemInfo does not exist in this client (probe: info=missing), so prices could not be read, and recording ended with no-recipes. It is not yet known whether this vendor sells recipe items or whether recipes were missed. 0.5.3-beta reads price and extended cost from C_MerchantFrame.GetItemInfo (fallback to the old function) and extends the merchant probe: item class counts over all items, and for the first four recipe items the raw info and tooltip lines. All automated checks pass; installed with tools/install.py, all 64 files match and all 14 manifests read 0.5.3-beta. /reload is enough. Live re-test pending with the same vendor and with a vendor known to sell recipes.

### Trainer and vendor tooltip layout, 0.5.4-beta, 2026-11-12

Pin tooltip reformatted at the owner's request: required skill in brackets right after the recipe name, only the price on the right in the classic gold, silver and copper icon format, a separator between the NPC header and the list, and colors that distinguish the NPC name (gold), the list (white) and additional information (gray, green for confirmed). Automated checks pass, including tests for the exact left and right text, the colors, the separator, extra cost and empty list; installed with tools/install.py, all 64 files match and all 14 manifests read 0.5.4-beta. /reload is enough. Live visual review pending: icon sizes in the right column, separator rendering and the color choices.

### Smaller tooltip text, 0.5.5-beta, 2026-11-12

After live review of the 0.5.4 layout ("tooltip is OK, maybe a smaller font") the pin tooltip lines other than the NPC name use the small tooltip font, through a new Style.Small helper that restores the original fonts when the tooltip is recycled. Automated checks pass, including a presentation test for both columns and the restore, and a test that exactly the role, status and list rows are shrunk; installed with tools/install.py, all 64 files match and all 14 manifests read 0.5.5-beta. /reload is enough. Live visual review of the size is pending.

### Unlearned recipes window: filter, green NPC names and location tooltip, 0.5.6-beta, 2026-11-12

Added at the owner's request after reviewing the window: a profession filter, green NPC names, and a hover tooltip over the NPC column that lists every source of the recipe with role, price in coin icons, zone and coordinates (observed position, or the seed's Classic world position converted with C_Map.GetMapPosFromWorldPos without an override map and marked not yet confirmed). Automated checks pass, including model tests for the filter and Location, a tooltip test, and a window test that fires the hover scripts; installed with tools/install.py, all 64 files match and all 14 manifests read 0.5.6-beta. /reload is enough. Live review pending: the zone and coordinates of seed NPCs depend on the unverified world-to-map conversion and axis order.

### Debug log file and scrolling recipe list, 0.5.7-beta, 2026-11-12

Two requests after reviewing the unlearned recipes window. First, Debug mode is now the switch for a debug log of important events: DebugLog.lua keeps the latest 1,000 lines in the saved variables file (the only file an addon can influence; it is written on /reload and logout) and ns.Debug writes there instead of the chat, which can still repeat messages through Also show debug messages in chat. Events traced: player spell casts, loot, trainer and merchant windows, profession windows, bank and world changes, honor events and player death; NPC recording outcomes and profession recipe reads are added. Second, the unlearned recipes window scrolls with the mouse wheel and a native slider scroll bar instead of Previous and Next buttons. New core file DebugLog.lua, so a full client restart is needed once. Automated checks pass (new debug log suite, rewritten recipe browser suite with 7 checks, integration tests for the menu entries and event logging); installed with tools/install.py, all 65 files match and all 14 manifests read 0.5.7-beta. Live review pending: the scroll bar look and wheel behaviour, and the log contents after a /reload.

The local build in dist/releases/0.5.6-beta is stale and must be rebuilt for the version that is finally published; release-notes/ref-0.5.6-beta.md describes the first beta and is to be revised for that version.

### Skill colors and a minimap button, 0.5.8-beta, 2026-11-12

Two requests after reviewing the unlearned recipes window. First, recipes the character lacks the skill for are shown in red (name and skill in the window, the skill in brackets in pin tooltips) so those that could be learned now stand out; the rank per profession comes from ns.Professions.Rows through new NpcSources.Skills and CanLearn, a profession the character does not have counts as insufficient skill, and an unknown requirement or unreadable professions stay neutral. Second, MinimapButton.lua adds a round TG3 button modelled on the TitanApproxDPS one (32 px, MEDIUM strata, minimap width/2 + 22 from the center, saved angle, drag, left click toggles the recipes window, right click opens the menu), with Display > Show minimap button. New core file, so a full client restart is needed once. Automated checks pass (new minimap button suite with 8 checks, 20 NpcSources checks, 10 recipe browser checks and a menu integration test); installed with tools/install.py, all 66 files match and all 14 manifests read 0.5.8-beta. Live review pending: the button look and position next to other minimap buttons, and the red coloring against real skill levels.

### Gold ring on the NPCs of a clicked recipe, 0.5.9-beta, 2026-11-12

After clicking a recipe in the unlearned recipes window the world map showed many vendor pins and the wanted one was hard to find. Clicking a row now opens the map at the zone of the first source (NpcSources.Location, continent fallback) and marks every source with a gold highlight: PinStyle.Highlight draws two concentric rings from the circle outline artwork in gold, pulsing by alpha, and raises the pin frame level; NpcSources keeps the marked NPC IDs for five minutes (SetHighlight, IsHighlighted, HasHighlight), shows them whatever the map toggles and profession filter say, and schedules one redraw at expiry. The same row clears the mark, another recipe replaces it, it is not saved across a reload. Automated checks pass (new tests in pin_style, npc_sources, map, minimap and recipe_browser); installed with tools/install.py, all 66 files match and all 14 manifests read 0.5.9-beta. No new file, so /reload is enough. Live review pending: whether two thin rings are visible enough on the world map and on the minimap at the chosen sizes, and how the pulse looks.

### Red, temporary rings, 0.5.10-beta, 2026-11-12

Live review of 0.5.9: the ring stayed after the world map was closed and reopened, which would soon fill the map with rings, and the owner wanted it red and a different size (chosen: smaller and thicker). PinStyle.Highlight now draws three tight red rings (base max(1.7 x pin width, 24) px, 2.5 px apart) instead of two gold ones, and Map.lua ends the mark through NpcSources.SetHighlight(nil) when the world map is hidden, so a normally reopened map shows plain pins. Because the mark is one shared state, it also leaves the minimap then. Automated checks pass (updated pin_style test and a new map test for the clear on close); installed with tools/install.py, all 66 files match and all 14 manifests read 0.5.10-beta. No new file, so /reload is enough. Live review pending: size and visibility of the band, and whether the rings should stay on the minimap while walking to the NPC.

### One tabbed window, scrolling lists, search and grouping, 0.5.11-beta, 2026-11-12

Owner request: open the statistics windows from the minimap button, scroll instead of paging everywhere, and add filtering or grouping by item. Decision: instead of a menu of windows, the minimap button opens one tabbed window (seven bottom tabs, shared size 985x592 and remembered position) built from the existing frames through the new Navigation.lua (tab strip, Activate/Toggle, Scrollbar helper). Reports now flatten rows into measured entries and draw from a scroll offset (variable row heights kept; the last offset is the first one whose remaining rows still fill the window); the crafting planner scrolls by reagent row. Search by name in all tabs and the recipes window, and a group by item mode with expandable sources for observed chances. The export window keeps numbered parts (client text box limit). Automated checks pass (reports 22, crafting view, recipe browser and minimap button tests updated). Live review pending: tab look and spacing, scroll feel, search box look, grouped chances. New file: restart the client once.

### Learned status in tooltips, 0.5.12-beta, 2026-11-12

Owner feedback: trainer and vendor tooltips did not make clear whether the recipe is already learned. The tooltip had only a small green "(known)" tag and said nothing when a profession was never read. Known recipes are now dimmed with a green "learned" tag, and a gray footer lists the professions whose learned status is unknown (open that profession window once). Automated checks pass (npc_sources, 24 checks). Live review pending.

### Rank spells in tooltips, 0.5.13-beta, 2026-11-12

Owner report: the Fishing trainer tooltip kept saying the learned status is unknown although the profession window was opened many times. The saved log showed recipe reads for FirstAid, Cooking, Mining and Engineering but never Fishing, and the Fishing trainer record holds one service, "Journeyman Fishing" (trainer 1683, services=1). Fishing has no trade skill recipe list, so KnownRecipes never records it, and rank spells are in no recipe list anywhere. NpcSources.RankSpellKnown now decides rank spells from Professions maxRank against the tier cap, and the unread note ignores them. Automated checks pass (npc_sources, 25 checks). Live review pending.


### Next profession rank in the window, 0.5.14-beta, 2026-11-12

Owner request: show the trainers where the next skill level can be learned once the maximum is reached or learning is possible. NpcSources.Unlearned now adds rank spells as trainer rows: per profession the player has, the lowest tier whose cap (75, 150, 225, 300, 375) exceeds the current skill cap, provided the trainer requirement is not above the current skill. Beyond that only Fishing, Herbs and Skinning joined RecipeKinds. Automated checks pass (npc_sources, recipe_browser updated). The data depends on the seed trainer rows for those professions; live review pending, especially whether Expert and Artisan trainers exist in the seed.

### Skill reading on rank rows, 0.5.15-beta, 2026-11-12

Owner report: with Fishing 75/75 the Warg Deepwater trainer is circled although the owner believes he teaches only up to 75. The saved record of trainer 1683 (observed, 21:56:31, mapID 1432) lists one service, Journeyman Fishing, state available, skill requirement 50 met, cost 500, so the recorded data says he teaches Journeyman. The rank logic already uses rank and maxRank from Professions.Rows (Fishing 75/75 selects Journeyman). To make the input visible, rank rows now show "Your <profession> skill is a / b." at the top of the hover tooltip. Open: what the Warg trainer window really lists for the owner, and which skill reading the tooltip prints.

### Character level for rank rows, 0.5.16-beta, 2026-11-12

Owner screenshot of Warg Deepwater (Fishing 75/75, character level 14): the trainer window lists Journeyman Fishing, Requires: Level 10, Fishing (50), 5 silver, so the recorded and seed data match the game and Warg correctly appears as the source of the next rank. The screenshot exposed an unchecked requirement, the character level. NpcObserver now records the level per trainer service and NpcSources hides rank rows above the player level, with classic tier levels as the fallback. The seed carries no level (its fifth field is 0), so regenerating it would need the pinned dump. Automated checks pass.

### Combo boxes and classic tabs, 0.5.17-beta, 2026-11-12

Owner request: use Blizzard style combo boxes instead of buttons with menus, and noted that classic tabs are possible. Navigation.lua gained Nav.Dropdown (WowStyle1DropdownTemplate with SetupMenu and radio choices, the same API another installed addon uses on this client; fallback button and context menu) and Nav.Tabs (PanelTabButtonTemplate with PanelTemplates_SetNumTabs and SetTab; fallback button row), both guarded by pcall. The profession filters of the recipes window and all statistics tabs use the drop down. Two state toggles (This character, All unlearned, All sources) stay buttons. New tests/navigation.lua covers the template and fallback paths. Live review pending: if the tabs or drop down look wrong or the fallback is used, the log of Lua errors (/console scriptErrors 1) shows why.

### Combo boxes everywhere, 0.5.18-beta, 2026-11-12

Owner request: replace choice buttons with combo boxes wherever possible. Nav.Dropdown now also serves the two state choices: scope in the statistics tabs and the export window, the recipes source filter, chances grouping and the export identity setting. Controls that perform an action stay buttons. Tests drive the choices through the same options and setters (recipe_browser captures them, reports and export_view pick from the fallback menu). Live review pending, together with the look of the drop downs from 0.5.17.

## 0.5.19-beta, trainers whose services are all known

Live finding: Bronk Guzzlegear (npc 1702) stayed "Not yet confirmed in game". The NPC recording log showed GetNumTrainerServices=0 on both TRAINER_SHOW and TRAINER_UPDATE, while another trainer in the same session returned 10. Probable cause: the default trainer window filter hides already known services, so a trainer with nothing left to teach reads as empty. Fix: with an empty list the observer switches the available, unavailable and used filters on for one read per opened window and restores them. Pending live check: that the client rebuilds the list synchronously after SetTrainerServiceTypeFilter, and that Bronk is then recorded (confirmed). If the log still shows services=0, the probe line "type filters" shows the filter states.

## 0.5.20-beta, delayed read after the trainer filters change

Live log after 0.5.19: Bronk (npc 1702) still returned GetNumTrainerServices=0, with the type filters available/unavailable/used = true/true/false when probed (after the toggle and restore). The list is therefore not rebuilt synchronously. The observer now logs filters-on, reads again after 0.3 s (event TRAINER_FILTER) and restores the filters afterwards or on close. Pending live check: Bronk recorded as saved, and the player's trainer filter back to its previous state.

## 0.5.21-beta, trainer filter diagnostics

Live log after 0.5.20: filters-on was logged for Bronk (npc 1702), but the probe still showed used=false and the delayed TRAINER_FILTER read still returned 0 services. Either SetTrainerServiceTypeFilter(name, 1) is not accepted by this client or the empty list has another cause. 0.5.21 tries 1 then true and writes the client answers into the filters-on log entry (field first). Pending live check of that report.

## 0.5.22-beta, Bronk recorded

Live log after 0.5.21: SetTrainerServiceTypeFilter(name, 1) fails with "Missing on/off parameter", SetTrainerServiceTypeFilter(name, true) works. After the delayed read Bronk (npc 1702) was saved with 11 Engineering services. 0.5.22 uses true and false only. Pending live check: the player's "Already known" filter is back to off after the window closes.

## 0.5.23-beta, trainer list no longer flashes

Live report (screenshot, 0.5.21): the Bronk window showed several services and then emptied. This was the addon switching the type filters on for the read and back at once; it is not a client bug. 0.5.23 keeps the filters on until the trainer window closes. Pending live check that the filter is back off after closing.

## 0.5.24-beta, filters restored right after the read

Live report on 0.5.23: the filter returned to off after closing, but the window showed already known services meanwhile, which looked wrong. 0.5.24 restores the filters in the same handler as the successful read. Pending live check: how short the remaining flash is (the list is rebuilt after the filter change, so some flash may remain).

## 0.5.25-beta, C stack overflow fixed

Live error on 0.5.24 when a Mining trainer was opened: C stack overflow in NpcObserver.lua (Log, ReadTrainer, TrainerUpdated, RestoreFilters in a loop). The client delivers TRAINER_UPDATE inside SetTrainerServiceTypeFilter. 0.5.25 ignores nested reads and clears the changed filter list before restoring. Pending live check: Mining trainer opens without an error and is recorded.

## 0.5.26-beta, filters touched only for an empty update

Live log on 0.5.25: the Mining trainer (npc 5392) was recorded without an error, but the filters were also switched for it (filters-on on SHOW, 15 services saved, then 10 on the restore). TRAINER_SHOW is always empty. 0.5.26 switches the filters only when TRAINER_UPDATE is still empty. Pending live check: Mining trainer saved with the player's filters (no filters-on entry), Bronk still recorded.

## 0.5.27-beta, Trainers tab

New tab Trainers (TrainerBrowser.lua, NpcSources.Trainers): all profession trainers with zone, coordinates and status, default list of trainers not visited yet, status and profession combo boxes, search over name, profession and zone, hover tooltip of what the trainer teaches and a map click that rings the trainer. Visited means a recorded trainer window, not only a merchant visit. Pending live check: the look of the eight tabs along the bottom (they may be wider than the window), the converted coordinates of unvisited trainers and the map click.

## 0.5.28-beta, first opening of the recipes window

Live report: the first opening after the game starts lags. Cause found by measurement: Unlearned() requests the names of about 550 vendor recipe items; each ITEM_DATA_LOAD_RESULT redrew the list (one computation takes about 6 ms in LuaJIT on a desktop, so hundreds of them add up). 0.5.28 coalesces the redraw (0.3 s after the first answer) and requests item names only for the professions in view. Pending live check of the first opening. The window construction itself and the item requests (about 550 at once on an All professions list) were not measured in game.

## 0.5.29-beta, tab widths on the first window

Live report with screenshot: the first window after starting the game shows narrow, cut tabs ("Unlearn...", "Lifetime..."); later windows are right. Probable cause: the tab texts are measured before the fonts are ready. 0.5.29 calls PanelTemplates_TabResize again on show and 0.1 s later. The cause is inferred, not proven. Pending live check on the first open after a game start.
