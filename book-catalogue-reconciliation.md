# Reconcile the Forever catalogue

Reviewed 2026-11-08. This reference applies to the installed development candidate; see [current progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md) for deployment and remaining acceptance gates.

## Current decision

The local target installation reports 1.60.1.70862. The base recipe snapshot declares target 70790 and has no exact extraction build. Its 1,971 normalized recipe records match both a pinned upstream file and four public CSV tables labelled 1.60.1.70862. This separate crosscheck does not establish the mirror extraction build, live obtainability or full coverage. Keep the catalogue incomplete.

Seven evidence-backed memberships now extend Fishing from 16 to 23 materials. The global supported item count remains 532 and combined recipe count remains 1,973. All 128 inherited memberships remain with repaired local provenance; 456 legacy IDs remain unresolved. Eleven cross-profession craft-output associations are review candidates, not proven errors.

## Inspect and reproduce

1. Work from the source checkout. Read catalogue/target-client.json, source-evidence.json and reconciliation.json. Target installation evidence and expected interface are separate from a live GetBuildInfo observation. Use the real-client checklist to confirm interface/API behavior.
2. Run the read-only summary and generated-report check:

       python3 tools/audit_catalog.py
       python3 tools/audit_catalog.py --check

3. To independently verify the pinned source, download the exact Data.lua URL in source-evidence.json into an ignored local archive, such as .work/recipe-mirror.lua. Then run:

       python3 tools/audit_catalog.py --check --mirror-file .work/recipe-mirror.lua

   Verification compares raw SHA-256 and normalized spell/output/profession/reagent facts without executing Lua. It does not compare output quantity/difficulty/vendor fields, which the captured normalized dataset does not contain. Source content is not downloaded by builds or bundled into runtime folders.
4. To reproduce the separate build-specific crosscheck, download the four clientTables URLs in source-evidence.json into .work/client-tables-70862, using filenames SkillLineAbility.csv, SpellEffect.csv, SpellReagents.csv and ItemSparse.csv. Confirm each response Content-Disposition names the recorded table and version/build before accepting new evidence. Then run:

       python3 tools/audit_catalog.py --check --client-tables .work/client-tables-70862

   The verifier checks all four pinned raw hashes, reconstructs the scoped CREATE_ITEM recipe subset and compares every normalized base fact. It rejects conflicting spell mappings. Its subset requires a supported skill, nonzero trade-skill category, positive reagents and an output in ItemSparse. It does not check output quantity, difficulty, vendor fields, the two supplementary enchantments or server availability. CSVs remain outside Git and runtime folders.
5. To write only the generated report after reviewed evidence changes, use --output catalogue/reconciliation.json. Other existing files cannot be overwritten. Source symlinks/hardlinks are rejected; the CLI stages a report and replaces its directory entry. Regenerating all catalogue outputs also checks report aliases before writing.

## Acquire missing evidence

1. The current separate client-table manifest records public Wago response filenames identifying 1.60.1.70862, all four URLs and content hashes. For future targets, obtain a source manifest that explicitly identifies the exact wowf client version/build, source tables, acquisition method and content hashes. A version number, commit date, current installation or matching item IDs cannot supply a missing extraction build.
2. Verify recipe identities, output items and reagent quantities against that source. Output-free enchanting requires its own coverage: the current item-output mirror plus two supplementary enchantments is not a full enchantment catalogue.
3. Establish live obtainability independently of client-table existence. Record profession availability, recipe acquisition, gathering/camping requirements and source conditions for the target build. Do not remove a legacy ID merely because it is absent from the current material-use union.
4. Review inherited module memberships separately from consuming professions. An item may be gathered and also produced by conversion recipes. For example, a Leatherworking recipe producing leather does not disprove Skinning. Mining grinding-stone associations warrant examination, but this audit does not remove them automatically.
5. Expand Fishing from direct current-version evidence rather than treating the present seed as exhaustive. Do not import historical comment rates, coordinates, seasonal assertions or prices as current server facts.
6. Curated auction/supply entries require exact use reasons and provenance; auction-only entries also require trade eligibility. The current curated scope is intentionally small. No price or auction automation is part of this work.

## Apply reviewed corrections

1. Keep numeric recipe facts in the base or supplementary inputs. Supplementary evidence must identify the same Forever spell ID. Add/remove items only with traceable evidence; preserve unresolved records for later review.
2. Record gathering/producer memberships in module-membership.json. Memberships must be unique, use a known profession module and identify an item already supported by recipe/use evidence. Local provenance must point to catalogue/legacy-items.json and match the archived item/file fragment exactly. HTTPS provenance is traceable evidence, not automatically exact-build verification.
3. Retain retrieved dates, evidence types and unknown source builds. Do not replace a null extraction build with the current target merely to make a check pass. Updating source provenance requires independently verified new evidence.
4. Run python3 tools/generate_catalog.py and inspect runtime changes. The core remains metadata-only; optional modules retain compact item records and two recipe examples. Catalogue source-policy hashes change with reviewed data inputs; saved history is not rewritten or converted into new observations.
5. Run python3 tools/check.py and the relevant live module checks. Verify new Fishing materials with only Fishing and the core enabled, then with consuming professions also enabled. Check counts, use explanations and source/map controls. No instance acquisition should create a map spot.

## Release gate

The generated reconciliation report intentionally remains incomplete. The independent build-specific base-recipe crosscheck passes for the current target. Live obtainability, unresolved legacy IDs, inherited producer associations, output-free enchanting and broader useful-item coverage remain explicit gates. A matching recipe build alone is insufficient. Completing the audit requires reviewed evidence and corresponding gate logic, not flipping the input complete flag. Packaging and publication remain separate from evidence reconciliation and live acceptance.
