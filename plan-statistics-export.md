# Versioned statistics export and user-initiated sharing

## Current status, 2026-11-08

Implemented, tested and installed. Clipboard/scroll round trips remain a live gate; offline transport validation is not a complete semantic audit. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective and format

Implement Milestone 5 with schema-versioned JSON, current-character/combined selection, identity opt-in and a native copy window. Preserve acquired quantities, complete-source numerators/denominators, recording policies, action counters and production distributions. No import into SavedVariables, automatic sharing, networking or live installation.

Ruling: JSON is the initial format. A single CSV cannot faithfully carry nested policies, coverage and quantity distributions without multiple related files or lossy flattening. Schema 1 retains those relationships; CSV conversion can be added later against the documented schema.

`Export.Build(sources, options)` receives the existing History, Actions and Production objects plus current character, addon version and export timestamp. It reads aggregates without constructing collectors, sealing receipts, changing counters or refreshing inventory. `options.scope` is character or combined. Combined exports retain pseudonymized per-character records and a weighted combined summary. Missing measurement-start times are labeled unknown rather than inferred from last-observed timestamps; unsupported future feature schemas are explicitly marked unavailable.

## Privacy and data contract

Whitelist every exported field. Default pseudonyms are export-local character-1, character-2 and so forth. Include original character GUID/name only when includeIdentity=true. Exclude raw receipt IDs, cast/item/source GUIDs, saved-data keys, policy keys, bank/bag snapshots, map coordinates and arbitrary free-form source/recipe labels even when identity is opted in. Preserve numeric item/recipe/source IDs, profession kinds, map IDs, instance context and gameplay timestamps. Identity-excluded does not imply that timestamps or zone information are removed.

Per-character history retains acquired item totals, all source groups (including zero-hit groups), complete-source counts, per-item complete-sample hits/quantities and recording-policy definitions with export-local references. Combined rate rows use the existing eligible-denominator logic, summing eligible trials rather than averaging percentages. Production retains attempts/completions, matched operations, explicit proc-field denominators, per-item quantities and distributions. Actions retain separate outcomes and first-recorded times. Export no invented continuous-coverage intervals.

`Export.Encode(value)` produces deterministic JSON, distinguishing empty arrays from objects, escaping control characters and rejecting nonfinite/cyclic/unsupported values. `Export.Parts(payload, maxBytes)` emits one complete JSON document when small; larger payloads use independently valid JSON part envelopes with index/count, total UTF-8 bytes, Adler-32 corruption checksum and string payload. Split only at UTF-8 boundaries. Adler-32 detects accidental corruption, not authenticity.

Ruling: copying large exports uses numbered parts to avoid silent edit-box truncation. The user saves each part and runs `tools/read_export.py` to reconstruct and validate the document. The tool rejects missing/duplicate/mixed/corrupt parts, invalid JSON and unsupported versions. It prints normalized JSON or writes a requested new output file, without changing game data. Users must copy every part; the UI never silently drops data to fit.

## UI and integration

Add `ExportView.lua`, opened by `/tgf export` and Export statistics under History and sources. Default to current character with identity off on every opening. Scope, identity and Generate controls regenerate an immutable snapshot only in response to user actions. Previous/Next select parts; Select text focuses/highlights the current part for manual copying. Restore generated text after accidental editing. Check the edit box retained the complete part. Clear text and identity preference on hide. Do not refresh snapshots automatically while the user copies.

## Implementation steps

1. Write failing Lua export tests and implement Export.lua: whitelist, policy references, current/combined aggregation, zero/partial history, coverage, future schemas, deterministic encoding, Unicode parts and read-only behavior. Add manifest/checker entries.
2. Add Python standard-library tests that parse real Lua output with json, verify escaping/privacy/counts, and exercise a local strict reconstruction CLI with complete, missing, duplicate and corrupt parts.
3. Add failing native-view/host tests and implement the copy window, reset behavior, explicit generation, readonly copy buffer and slash/menu entry points. Use only ordinary native EditBox/ScrollFrame APIs; no clipboard/network automation.
4. Run the full checker, obtain independent review and fix important findings with reproductions. Document schema, reconstruction, privacy controls and live acceptance. Update roadmap/progress. No commits, release publication or deployment.

## Review focus and success criteria

Check identity leaks in nested keys/labels, policy-specific combined denominators, partial-versus-complete quantities, empty/unknown datasets, unsupported feature schemas, Unicode chunk boundaries, JSON compatibility, large-part completeness, snapshot stability, edit restoration and identity reset. Full checks and shipped Lua compilation must pass. Real-client copy/selection/scroll behavior remains a live acceptance gate.

## Follow-up: import statistics into another installation

Add a user-initiated import path that accepts a previously validated schema-1 export and restores the selected character's statistics in another WoW installation. Reuse the existing numbered-part transport and strict reader rules; imports must not execute arbitrary payload content or alter game data before the user reviews the destination and import summary.

Decide merge and repeat-import behavior before implementation. Importing the same snapshot twice must not double counts. Combined exports contain per-character records and a derived aggregate; restore the per-character records and do not import the aggregate as an additional character. Define how identity-opted and pseudonymous records map to existing characters, what happens when a character already has data, and how unsupported future schemas are rejected. Preserve existing observations and settings unless the user explicitly chooses a documented replacement action.

Acceptance criteria:

1. A complete single-document export and a reconstructed multi-part export can be imported into a different installation.
2. Schema, framing, checksum, bounds and required fields are validated before any SavedVariables mutation.
3. The import preview identifies included characters, available statistic groups, identity mapping and merge/replacement effects.
4. Repeating an import cannot silently add the same cumulative snapshot twice.
5. Malformed, incomplete, corrupt, unsupported or oversized input leaves existing data unchanged and reports a useful error.
6. Tests cover current-character and combined exports, pseudonymous and identity-opted records, duplicate imports, existing destination data, and preservation of unrelated settings and history.

## Execution record

- Existing 258-check local candidate retained. This task uses the already authorized inline execution and final independent review workflow.
- Tasks 1 through 3 complete: watched Lua, Python and native-copy/host tests fail before implementation. JSON snapshots, privacy controls, part transport and the local reader are implemented. An explicit multibyte-boundary fixture verifies the UTF-8 split branch with Python's JSON parser.
- Independent review found an identity lookup traversing unsupported future stores. Reproduced it with a failing test and fixed schema/store guards. Also reproduced and fixed malformed future-version label leakage and finite-exponent overflow parsing. No saved-state mutation or denominator defects found.
- Final verification: 288 checks (48 Python and 240 Lua), including 14 export, seven copy-window and 53 host checks, plus shipped Lua compilation. Clipboard/scroll round trips remain unverified.
- Final: minor (deferred): truncation blocks Select text, but native manual selection can remain possible. Warnings and reconstruction checks prevent treating a truncated part as a validated export; documented for live acceptance.
- Task 4 complete: format, reconstruction, privacy and validation instructions added; roadmap/progress updated. No installation, publication, version change or commits.
