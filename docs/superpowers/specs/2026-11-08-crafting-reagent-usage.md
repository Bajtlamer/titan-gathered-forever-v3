# Crafting Reagent Usage: Short Design

## Intent

Show players how much of each reagent recorded crafting has used and which profession consumes the largest share. Keep this overview separate from acquisition quantities, output statistics and recipe operations.

## Approved approach

Track an estimate from completed recorded crafts using the recipe's fixed required reagent quantities. Exact inventory consumption is not observable with current data and would delay useful coverage. Report the values as estimated, with an explicit coverage start and percentage denominator.

## Behavior

- Add a separate Reagent usage report with one global row per reagent.
- Show reagent, estimated total quantity used, leading profession, and that profession's percentage of tracked use for the reagent.
- Open a row for its profession-by-profession quantities and shares.
- Count each completed recorded recipe operation once, using the recipe's fixed required quantity per reagent.
- Exclude optional finishing/modifier reagents and recipes with unsupported required alternatives, currencies or variable quantities from estimates. Keep their use unknown; never label it zero.
- Start coverage when the update is installed. Earlier recipe records have no reagent snapshot and cannot establish historical ingredient use.
- Clearly state that totals and percentages describe tracked supported crafts during recorded coverage, not all crafts or exact inventory deductions.
- Keep acquired totals, crafted outputs, completed casts and matched output operations independent. Preserve existing crafting history and settings. Do not use bag deltas, assumed proc quantities or requested queue length.

## Approaches considered

- Fixed-recipe estimates from completed recorded crafts: chosen because recipe schemas and completed cast observations already exist; adds useful profession shares with honest scope.
- Exact reagent consumption from inventory changes: rejected because bank/bag changes, concurrent looting and delayed inventory updates cannot identify which craft consumed each reagent reliably.

## Constraints and validation

Preserve Lua 5.1 compatibility, Forever APIs and separate profession add-ons. Keep unsupported or unavailable recipe coverage unknown. Add regressions for repeated and queued casts, partial/failed/interrupted operations, recipe metadata changes, unsupported required slots, profession attribution, combined characters, percentages and persistence. Automated validation does not replace live confirmation that recipe metadata is available during actual casts.
