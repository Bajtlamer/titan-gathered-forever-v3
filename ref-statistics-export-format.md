# TGF v3 statistics export format, schema 1

Reviewed 2026-11-08. This reference applies to the installed development candidate; see [current progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md) for deployment and remaining acceptance gates.

## Create and read an export

Use /tgf export or History and sources > Export statistics. The window opens on This character with Include names/GUIDs off. Choose the scope and identity setting, then Select text and Ctrl+C or Cmd+C. Generate captures a new snapshot; recording events never refresh it while copying. Closing clears its copy buffer and resets identity sharing.

Small exports are one complete JSON document. Large exports are numbered JSON part envelopes. Save every displayed part as a separate UTF-8 file outside the addon runtime folders. Never mix Generate actions. The UI checks edit-box retention; the clipboard/save round trip remains the user's operation.

Validate a complete export:

    python3 tools/read_export.py "/path/to/export.json" \
      --output "/path/to/ref-statistics-export.json"

Reconstruct numbered parts:

    python3 tools/read_export.py "/path/to/export-part-01.json" \
      "/path/to/export-part-02.json" \
      --output "/path/to/ref-statistics-export.json"

Supply every part. File order is immaterial. Missing, duplicate, mixed, malformed, unsupported-version or corrupt parts fail validation. The output path must be new; omit --output to print normalized JSON. The standard-library tool executes no export data and changes no game files.

The reader checks JSON syntax, finite number parsing, transport framing, version and character-selection metadata. It does not certify statistical consistency or live-client accuracy. Adler-32 detects accidental corruption, not sender authenticity.

## Selection and privacy

selection contains scope (character or combined), includeIdentity and characterCount. Combined selection includes the current character and saved characters visible through supported statistic schemas. Unsupported feature stores remain explicitly unavailable.

Each character has an export-local ref such as character-1, valid only within that snapshot. Identity off omits names and GUIDs. Explicit identity opt-in adds identity.guid and the recorded identity.name when available.

The export always excludes raw receipt/cast/item/source GUIDs, internal saved-data keys, policy keys, bank/bag contents, map coordinates and arbitrary free-form source/recipe labels. Identity opt-in does not enable these fields. Numeric item/recipe/source IDs, map IDs, instance contexts and gameplay timestamps remain in identity-excluded exports.

Exports are cumulative snapshots, not change journals. Do not sum repeated snapshots as separate acquisitions. This feature provides no import or automatic cross-export deduplication.

## Document header

The complete document contains:

- format: TGFv3-statistics.
- schemaVersion: integer 1, independent of addon/collector versions.
- exportedAt: the game's wall-clock snapshot timestamp.
- addon: version, WoW Forever clientVersion 1.60.1, interface 16001 and optional catalogueSourceSHA256.
- selection, definitions and characters.
- combined for combined scope, with aggregate history/actions/production.

definitions describes units, partial/complete quantities and denominators. coverageIntervalsRecorded, coordinatesIncluded, rawReceiptsIncluded and inventoryIncluded are false. historyIntroducedIn is 0.4.0, the feature introduction, not an individual character's start time.

Objects and record arrays are deterministic. Empty lists use [], not {}. Strings escape controls, quotes and backslashes; normal UTF-8 names remain when identity is enabled. Nonfinite numbers, cycles and unsupported serializer types fail generation.

## History

history.status is available or unavailable. startTimestampRecorded is false because the acquisition model does not retain a trustworthy first-observed time. Last observation is never substituted for measurement start.

items contains itemID, acquired quantity and optional lastSeen. Acquired quantities include partial loot and exclude separately recorded crafted output and current holdings.

sourceGroups retains all groups, including zero-hit/zero-complete-source observations. Each contains an export-local ref, kind, normalized source, mapID, instanceType, completeSources, optional lastSeen, trialPolicies and outcomes.

trialPolicies pairs policyRef with completeSources, retaining stored zero counts. outcomes contains itemID, complete-sample hits, complete-sample quantity and optional rarity quality. An outcome's complete-sample quantity can be zero despite positive acquired quantities from partial loot.

Normalized source.type is entry, input_item, catch, unattributed_item_loot or unknown. Numeric id is included for entry/input-item sources. An ordinary Loot entry ID alone does not distinguish a creature from a game object. Enchanting input-item groups have no geographical interpretation. Unknown strings never become free-form labels.

policies contains local ref, status (known or unknown_policy), all, rare, numeric items and numeric knownItems. Unknown policies are not unrestricted. Eligibility includes unrestricted samples, explicitly selected items, or enabled rare items with quality at least 3 that are absent from knownItems. The known-item exclusion prevents disabled supported materials from inheriting generic rare-loot samples.

rates contains positive-hit rows: itemID, kind, normalized source, mapID, instanceType, hits, eligibleCompleteSources and complete-sample quantity. The observed fraction is hits / eligibleCompleteSources. These are source/zone observations, not server probabilities or coordinate-specific chances. Zero-hit evidence remains in groups and policies.

Combined history sums acquired quantities and eligible rate numerators/denominators, never percentages. Per-character groups and policies remain available for analysis.

## Actions

actions contains sourceSchema, status and rows. Collector schema 1 is available; future schemas are unsupported_schema with no interpreted rows. Absent models are unavailable. Malformed nonnumeric source-version labels are omitted.

Rows retain kind, attempts, completed, failed, interrupted, stopped, unresolved, began and lastSeen. stopped means without a confirmed result, not proven manual cancellation. Fishing completion requires a catch window; other supported gathering completion means spell success. Attempts and loot samples are distinct units.

began is the character/profession's first recorded action. Combined rows use the earliest included observation, not continuous or equal coverage. Gap intervals are not reconstructed.

## Production

production contains collector schema/status, crafted items and per-recipe recipes. Crafted item quantities are separate from acquired history.

Recipe rows retain recipeID, primary itemID, kind, began, attempts, completed, failed, interrupted, unresolved, matched, quantity, bonusKnown, bonusHits, multicraftKnown, multicraftHits and outputs.

matched counts operations with attributable output results, not every completed cast. Explicit flag fractions use bonusHits / bonusKnown and multicraftHits / multicraftKnown. Unknown fields are excluded from those denominators; quantity variation is not itself a proc.

Each output has itemID, quantity, hits (matched operations containing the item) and distribution entries pairing quantity with operations. These describe observed matched outputs, not complete server tables. Unpaired, ambiguous, excluded and post-gap results can be missing. Production includes no map positions.

## Copy-part transport

Part envelopes contain format TGFv3-statistics-part, schemaVersion 1, one-based part, total, complete-document UTF-8 bytes, lowercase eight-digit hexadecimal Adler-32 checksum, and string payload.

Concatenate decoded payload strings by index, verify total bytes/checksum, then parse the complete document. Chunks are at most 8192 raw bytes, ending on UTF-8 character boundaries. Each envelope is valid JSON but is not a statistical document.

A truncation warning blocks Select text. Native manual selection may remain possible; copied incomplete parts must be rejected by reconstruction. Clipboard round trips, scrolling and key handling remain live-client acceptance gates.
