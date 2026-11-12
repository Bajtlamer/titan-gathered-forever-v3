# Titan Gathered Forever v3 0.4.2-alpha

## Changed

Lifetime material history now uses expandable source evidence. Material rows stay compact, with obtained quantity and source count. The dedicated + / - control shows one source/zone per child row, with separate observed Chance and Hits / samples columns. No unrelated probabilities are combined and no three-source limit hides evidence. Continuation pages repeat the parent material, keeping every source reachable.

Acquired/crafted quantities, complete-source denominators, SavedVariables, combined-character rates, item hovers and source menus are preserved. Unknown evidence remains unknown. The panel caption updates to TG3 Forever - v0.4.2.

## Verification and limitations

All 408 automated checks pass, including nineteen report cases, plus Lua 5.1 compilation of every shipped file. Regressions cover separate denominators, unknown evidence, combined 2/3 rates, all fifty sources, very long labels, continuation context and collapse/page bounds. Independent review found no critical/important finding. Full labels remain available via source menus when height-bounded rows clip unusually long names.

The target remains WoW Forever 1.60.1/interface 16001 with Titan Panel installed separately. Live font/layout acceptance awaits /reload. Catalogue completeness and unrelated live event-order gates remain open. No GitHub release tag is created by this update.
