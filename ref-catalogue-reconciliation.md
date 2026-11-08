# Catalogue reconciliation evidence

Reviewed 2026-11-08. This reference applies to the installed development candidate; see [current progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md) for deployment and remaining acceptance gates.

## Target and source provenance

Read-only inspection on 2026-11-07 found active wowf installation version 1.60.1.70862. The captured target record is catalogue/target-client.json. Expected interface 16001 is still the declared development target; this pass did not inspect GetBuildInfo in the running client.

The base dataset's declared target 70790 is retained. Neither the [pinned mirror Data.lua](https://github.com/masterred92/DwarfExplorersBible/blob/541dd23afba02f915a822d11acb19fd4c24df83e/Data.lua) nor its [generator](https://github.com/masterred92/DwarfExplorersBible/blob/541dd23afba02f915a822d11acb19fd4c24df83e/tools/gen_data.py) provides an exact extraction build. All 1,971 normalized spell/output/profession/reagent records match that file. Raw and normalized hashes are captured in catalogue/source-evidence.json.

A separate crosscheck used public Wago CSV exports for [SkillLineAbility](https://wago.tools/db2/SkillLineAbility/csv?product=wowf&build=1.60.1.70862), [SpellEffect](https://wago.tools/db2/SpellEffect/csv?product=wowf&build=1.60.1.70862), [SpellReagents](https://wago.tools/db2/SpellReagents/csv?product=wowf&build=1.60.1.70862) and [ItemSparse](https://wago.tools/db2/ItemSparse/csv?product=wowf&build=1.60.1.70862), retrieved 2026-11-07. All four Content-Disposition filenames identify 1.60.1.70862. Reconstructing the scoped item-output subset reproduces exactly all 1,971 base facts, with no additions, removals or changed reagent quantities. The independent evidence and four raw hashes are captured separately from mirror provenance in source-evidence.json. This uses the public service's build attribution rather than a local client extraction. It does not prove full recipe coverage or live obtainability. The global catalogue remains 532 items and 1,973 combined recipe records, including two supplementary output-free enchantments.

## Fishing corrections

The current Forever item database's Fishing Locations sections support adding these existing materials to the optional Fishing module:

- [Oily Blackmouth, 6358](https://www.wowhead.com/forever/item=6358/oily-blackmouth), already used by the captured Alchemy recipe 7836.
- [Firefin Snapper, 6359](https://www.wowhead.com/forever/item=6359/firefin-snapper), already used by Alchemy recipe 7837.
- [Deviate Fish, 6522](https://www.wowhead.com/forever/item=6522/deviate-fish), already used by Cooking recipe 8238 and Alchemy recipe 8240.
- [Stonescale Eel, 13422](https://www.wowhead.com/forever/item=13422/stonescale-eel), already used by Alchemy recipe 17551.
- [Raw Winter Squid, 13755](https://www.wowhead.com/forever/item=13755/raw-winter-squid), already used by Cooking recipe 18240.
- [Darkclaw Lobster, 13888](https://www.wowhead.com/forever/item=13888/darkclaw-lobster), already used by Cooking recipes including 18245.
- [Large Raw Mightfish, 13893](https://www.wowhead.com/forever/item=13893/large-raw-mightfish), already used by Cooking recipe 18246.

Fishing now publishes 23 supported materials, with consuming-use context intact even when Alchemy/Cooking are disabled. These references were retrieved on 2026-11-07 and do not identify an exact build. No locations, probabilities, prices or historical-comment claims were added to runtime data. Fishing remains a partial seed.

## Remaining evidence gaps

The deterministic catalogue/reconciliation.json report preserves 456 unresolved legacy IDs and all 128 inherited memberships. Their old local provenance paths now resolve to the captured legacy inventory rather than a removed data directory. Sixteen memberships have direct Forever references, including the seven additions; those references are not build-matched captures.

Eleven memberships overlap captured output recipes in another profession. Five are Grinding Stones in Mining, one is Enchanted Thorium Bar in Mining, and five are leather conversions in Skinning. These are review candidates, not proof of incorrect membership. A conversion recipe does not exclude a gathering source, and existing module inventories may intentionally include useful processed materials.

Beyond the scoped base-recipe build crosscheck, live obtainability, full output-free enchanting, inherited associations and broader useful auction/supply scope remain incomplete. The generator never promotes a declared complete flag into a release claim while these gates remain unresolved. Follow [book-catalogue-reconciliation.md](book-catalogue-reconciliation.md) for reproduction and updates.
