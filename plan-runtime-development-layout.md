# Runtime and Development Layout Plan

## Approved goal

Develop in the separate repository and install clean builds into WoW for testing. Keep all fourteen addon folders limited to game-required manifest files and artwork. Move development content to the repository root and upload the reorganized source without changing addon behavior.

## Changes

- Move tools, tests, catalogue inputs, release notes and prefixed documentation to the root. Move AGENTS.md verbatim and keep the root README canonical.
- Preserve private archives and previous repository metadata in root .work; move generated output to root dist. Archive redundant core README/ignore files instead of overwriting root files.
- Update generator, checker, packager, tests and GitHub workflow paths for root execution.
- Enforce runtime-only addon folders against manifest allowlists. Confirm every existing runtime byte and all fifteen package ZIPs remain unchanged.
- Verify a fresh source reconstruction, review the Git diff, commit and push main without release tags or live-game installation changes.

## Verification

Run the full test suite, package and hash checks, README link validation, fresh-source tests and GitHub CI. Keep private data, .work and dist excluded from Git. Preserve existing AGENTS.md contents while moving it.

## Implementation result

Moved all development and private generated content to the repository root. Redundant core README/ignore files and macOS metadata were preserved under .work/layout-before-root-development. Updated tools, tests, README/release playbook and GitHub workflow paths. All 177 checks pass, and independent review found no Important or Critical issue. Every runtime file and all seventeen release files match their pre-move hashes. A fresh staged-source reconstruction passes the full suite and reproduces the same upload files.
