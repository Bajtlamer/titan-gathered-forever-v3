# Titan Gathered Forever v3 Rename Plan

## Current status, 2026-11-08

Historical implementation/design record. Some original decisions and task restrictions were superseded. Use README.md, ref-wow-forever-runtime.md and plan-next-development.md for current behavior and remaining work. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

Official display name: Titan Gathered Forever v3. Core identifier and folder: TitanGatheredForeverV3. All thirteen optional modules use TitanGatheredForeverV3_<Module>. Version: 0.4.1-alpha. Keep /tgf commands.

Update manifests, dependencies, runtime globals, broker registration, UI frames, icon paths, generated catalogue metadata, build/check/package tools, tests, CI, documentation and release filenames. Keep the modular layout and existing behavior.

Use TitanGatheredForeverV3DB for new SavedVariables. A one-time migration tool copies the previous saved table into the new namespace while preserving its content and original file. Previous identifiers appear only where required to identify migration input. Never fabricate history or reset stored observations during migration.

No Git initialization, commits, tagging or upload are authorized in this rename task. Preserve the copied repository metadata and private archives when applying the staged rename. The game installation is outside this task's destination.

Applied to `~/Sites/addons/titan-gathered-forever-v3` after workspace permissions were updated. All fourteen folders and matching manifests were renamed. Original files are backed up in `.work/pre-v3-rename-1794071774786922000.zip`; previous distributions and copied Git metadata were preserved. No Git commands or game-installation writes were performed.

Verification: all 174 checks and shipped Lua compilation pass. The apply script was simulated on a temporary copy and preserved Git metadata, private archives, previous packages and an unrelated addon sentinel. Independent review found no Important or Critical defect. Live installation and saved-data migration remain acceptance checks.
