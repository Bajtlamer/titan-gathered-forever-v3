# Safe candidate installation

## Current status, 2026-11-08

Implementation complete and used for repeated live installations. Automatic installation is now authorized by AGENTS.md. The original no-install/no-commit constraints below describe the initial task only. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective and scope

Implement Milestone 1 of plan-next-development.md using Python's standard library and the existing package allowlist. Preserve unrelated addons, previous-generation folders and SavedVariables. This work does not install into the real game client.

## Design

Require an existing Interface/AddOns destination. Preview is the default; --apply authorizes replacement of the fourteen current addon folders. Build the candidate with tools/package.py and stage it on the destination filesystem before moving any installed folders. Reject overlapping source/destination paths, symlink destinations and managed entries that are symlinks or files.

Retain complete old addon folders in a uniquely named Interface/.tgf-v3-backups directory. Replace only the explicit package folder names. On failure, remove newly placed candidate folders and move originals back. If recovery fails, retain the backup and report its path. Serialize installations with an exclusive lock directory. No game data migration, old-generation cleanup or automatic live installation.

## Implementation steps

1. Add tests/test_install.py with temporary Interface/AddOns fixtures: preview without writes, first and repeated installation, runtime-only contents, backup retention, unrelated and legacy sentinels, invalid paths, missing source files, symlinks, lock contention and injected mid-install failure restoring the original tree.
2. Run the new tests and confirm failure because the installer is absent. Implement tools/install.py with install(root, destination, apply=False), returning destination, addon names and optional backup path; provide --addons-dir and --apply CLI options. Reuse package.package for the candidate archive.
3. Run focused tests and tools/check.py, then inspect failure recovery and filesystem boundaries separately. Document preview/apply, backup recovery, reload and live validation in book-releases.md.
4. Mark the milestone complete in the roadmap and progress record only after checks pass. Preserve the pre-existing README and progress edits. Do not commit or publish as part of this task.

## Success criteria and risks

Temporary fixtures demonstrate repeatable installation and rollback without touching unrelated files. The full checker passes. Filesystem permissions or storage failure can also prevent recovery; backups must survive and their location must be reported. Hard process termination and concurrent external file modification are outside automatic rollback guarantees. Close WoW before applying.

## Execution record

- Baseline: tools/check.py passed, 177 checks plus shipped Lua compilation.
- Ruling: work in the requested repository, preserving existing edits; no worktree or branch changes. This keeps the uncommitted continuation roadmap available and leaves reviewable local changes together.
- Tasks 1 and 2 complete: watched ten installer tests fail before implementation, then pass. Added backup-symlink and recovery-failure coverage; corrected the failure-injection fixture to account for macOS temporary-path resolution.
- Task 3 complete: release playbook updated; tools/check.py passes 189 checks (40 Python and 149 Lua) plus shipped Lua compilation. No runtime files changed.
- Final review: independent review found one recovery-documentation defect, reproduced with a partial rollback fixture. Fixed the playbook to distinguish complete successful-install backups from partial failed-install backups and preserve untouched/already-restored folders. No additional important code findings.
- Task 4 complete: roadmap and progress record updated. No commits, publication or live-client installation performed.
