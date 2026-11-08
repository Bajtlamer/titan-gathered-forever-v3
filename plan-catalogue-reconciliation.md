# Catalogue reconciliation and provenance

## Current status, 2026-11-08

Evidence-backed pass complete and installed, but Milestone 6 remains open. Separate 70862-labelled client tables match all 1,971 base facts; mirror extraction build is still unknown. Retain completeness=false, 456 unresolved legacy IDs and 11 producer review candidates. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective and verified findings

Execute the evidence-backed portion of Milestone 6. The installed wowf metadata now reports 1.60.1.70862, superseding the earlier observed 70790. Installation metadata is not live API/obtainability verification. Keep the captured dataset's declared target 70790 and unknown extraction build intact; record current target evidence separately.

The recipe mirror Data.lua at commit 541dd23afba02f915a822d11acb19fd4c24df83e has SHA-256 b9587a044d57ff3f1213caae50c15e23f2da1dc45edcba683c068fecf539bec4. Its 1,971 numeric recipe facts used by this addon exactly match the captured base dataset. Neither the file nor its generator supplies an exact extraction build. Pinning this content improves reproducibility, not build matching.

Direct Forever item pages list Fishing Locations for seven existing supported materials absent from Fishing: Oily Blackmouth 6358, Firefin Snapper 6359, Deviate Fish 6522, Stonescale Eel 13422, Raw Winter Squid 13755, Darkclaw Lobster 13888 and Large Raw Mightfish 13893. Their consuming recipe relationships already exist. Add only producer-module memberships with exact item-page provenance, retrieved date and unknown sourceBuild. Do not copy historical-comment rates, coordinates, prices or seasonality claims.

## Design and rulings

Ruling: preserve all unresolved legacy IDs and inherited memberships. A different profession crafting an item is a review candidate, not proof it cannot also be gathered. No unsupported removals or full-coverage claims. Complete remains false until build-matched, obtainability and comprehensive category evidence exist.

Repair inherited references from data/legacy-items.json to catalogue/legacy-items.json, preserving archived file fragments. Validate membership uniqueness, known module IDs, nonempty HTTPS evidence or exact local legacy references, and that each local reference identifies the same item/file in the captured legacy inventory.

Add catalogue/target-client.json with captured installation version/build/date and expected interface explicitly unverified on that build. Add catalogue/source-evidence.json pinning mirror commit, raw content hash, normalized numeric-fact hash and unknown extraction build. Do not download during builds or execute mirror Lua.

Extend the deterministic generator to emit catalogue/reconciliation.json: target/source build comparison, input hashes, per-profession recipe/output-free coverage, module membership evidence classes, unresolved IDs and producer-association review candidates. Build match alone never certifies live obtainability or complete coverage. The report must expose incomplete release gates.

Add tools/audit_catalog.py: read-only summary by default, --check for the generated report, optional --output and --mirror-file for strict pinned-byte/numeric-fact verification. Parse only the mirror's numeric recipe rows as data; never evaluate external Lua. Runtime publishers keep compact item records and two examples; no new runtime audit database or interface version change.

## Implementation steps

1. Write failing membership/audit tests, including wrong build/completeness claims, malformed local provenance, duplicates, unknown modules, zero-output coverage and numeric mirror parsing without execution. Implement pure validation/reconciliation helpers in tools/generate_catalog.py.
2. Add the two evidence inputs, normalize inherited references and add seven fishing memberships. Regenerate data/audits. Add a failing Lua optional-addon regression proving these materials load with Fishing while Alchemy/Cooking remain disabled; preserve consuming-use relationships.
3. Implement and test the audit CLI, check pinned mirror bytes/facts against the downloaded reference, and run the full suite. Obtain independent review and fix important findings with reproductions.
4. Document current findings and remaining gates, including exact build evidence, full output-free enchanting coverage, inherited association review and broader auction usefulness. Update roadmap/progress without marking Milestone 6 complete. No game installation, publication, source availability inference or commits.

## Review focus

Check unsupported build promotion, target metadata versus live observation, parser execution/ambiguity, provenance path traversal or mismatched legacy fragments, duplicated membership, accidental runtime data growth, changed source-policy hash compatibility, and deterministic regeneration. Counts must remain evidence-specific. Real-client reconciliation remains pending. The separate base-fact build crosscheck is scoped to the public CSV service attribution.

## Execution record

- Read installation metadata without changing game files. Pinned upstream Data.lua and generator inspected; extraction build remains unknown. Existing local implementation and user edits preserved.
- Tasks 1 and 2 complete: reconciliation/membership tests failed before implementation; Fishing-only loading failed before the seven additions. Added target/source provenance and repaired 128 local references without removing inherited associations. Global counts stay 532 items and 1,973 recipes.
- Task 3 complete: initial CLI tests failed before implementation. Exact pinned bytes and 1,971 normalized facts verify without Lua execution. Review reproduced source-overwriting output aliases and inconsistent audit/generator validation. Fixed both with failing symlink/hardlink, generator-preflight and unusable-input regressions in one pass.
- Final verification: 307 checks (66 Python and 241 Lua), shipped Lua compilation and clean whitespace checks. No deferred code findings. Seven optional-addon scenarios include Fishing without Alchemy/Cooking.
- Task 4 complete: evidence reference, playbook, README and target notes updated. Milestone 6 remains open: source build unknown, 456 unresolved legacy IDs and 11 producer-review candidates. Full output-free enchanting, obtainability and useful-item coverage remain unverified. No install, publish, version change or commits.

## Build-specific evidence follow-up

Ruling: the four public Wago CSV responses identify 1.60.1.70862 in Content-Disposition, and independently reconstructed CREATE_ITEM recipe facts exactly match all 1,971 base records. Preserve mirror sourceBuild as unknown. Add separate client-table crosscheck evidence, pinned raw hashes and build filenames, with an offline verifier. This proves the scoped base facts against a build-labelled public extraction, not live API behavior, the two supplementary enchantments or complete obtainability. Cost if the source labels are wrong: the crosscheck inherits that upstream attribution; no runtime completeness or source-build flag is promoted.

5. Add failing fixture tests for CSV reconstruction, raw hash/build filename mismatch, recipe fact differences, deterministic row ordering and separate report gates. Implement --client-tables DIRECTORY without downloads or executing source code. Capture all four table hashes and normalized facts, keep raw CSVs outside runtime and Git, regenerate the audit and update current evidence notes. Verify the full suite and obtain a focused independent review of this follow-up.

- Task 5 complete: nine focused tests cover table reconstruction, pinned bytes/build labels, changed facts, conflicting outputs, row ordering, separate gates and offline CLI behavior. All 1,971 base facts independently match the four pinned CSVs labelled 1.60.1.70862. The mirror sourceBuild remains null and the catalogue incomplete. Focused independent review found no important findings. Final verification passes 316 checks (75 Python and 241 Lua), shipped Lua compilation, the combined pinned mirror/table/report verification and whitespace checks. No deferred findings in this follow-up.
