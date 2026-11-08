# Restore Profession Addons and Optional Count Columns

## Current status, 2026-11-08

Historical implementation/design record. Some original decisions and task restrictions were superseded. Use README.md, ref-wow-forever-runtime.md and plan-next-development.md for current behavior and remaining work. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

User correction, 2026-11-06: retain the original addon-pack architecture. Each profession must be independently selectable in WoW's AddOns screen. Shared code and ID indexing do not require a combined addon or an always-loaded database.

## Required behavior

- Keep `TitanGatheredForeverV3` as the shared UI/inventory core. Move profession data into separate `TitanGatheredForeverV3_<Profession>` addons that depend on the core.
- Preserve original names: `Herbs`, `Mining`, `Skinning`, `Cooking`, `Enchanting`, and `Tailoring`. Add recipe-backed profession modules and a separate `Auction` module for curated auction uses. The UI label is `Auction items`, never `Other` under professions.
- A disabled addon loads no catalogue or recipe data. The core combines only loaded, enabled modules into one numeric-ID lookup index; shared items and recipe IDs are deduplicated.
- Gathering modules contain their gathered materials and relevant use reasons. Crafting modules contain their recipe reagents. Producer-module membership is recorded separately from consuming professions and remains subject to the catalogue's existing evidence limitations.
- Successfully scanned empty inventories show `0`. User confirmed that an unscanned bank must remain unknown.
- Add `Show bank counts` and `Show total counts`. Disabling bank counts hides Bank, Total, bank timestamps and bank-only rows in both summaries and item tooltips, and suspends bank scans. Bags remain visible. With bank enabled, total can be hidden independently.
- Preserve settings and bank snapshots through the upgrade. No website edits or installed-game edits.

## Implementation and checks

1. Add regression tests for empty inventories, bank-only rows, hidden columns, disabled bank scans, and optional module loading before changing runtime code.
2. Add deterministic module generation, metadata-only core data, compact per-module recipe-use records, source membership evidence and package tests.
3. Register modules through the core; rebuild the active index only at registration/settings changes, not every tooltip refresh. Show only loaded modules in configuration.
4. Package core plus optional module folders, validate every manifest and compile every shipped Lua file. Test core-only startup and loading a subset of profession addons.
5. Update runtime/validation documentation and verify that AGENTS.md is unchanged. Record automated checks separately from live validation.

Author's [CurseForge description](https://www.curseforge.com/wow/addons/titan-gathered) explicitly documents one separate addon per profession. Direct inspection in Chrome confirms that https://www.titan-gathered.com/ is the correct live addon site, documenting the shared core and six separately downloadable profession modules. An earlier browsing-service result showed stale or mismatched RRsoft content; it does not describe the live website.
