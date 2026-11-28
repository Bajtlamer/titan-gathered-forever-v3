# Repository Guidelines

## Structure and runtime

Titan Gathered Forever targets WoW Forever 1.60.1, interface 16001. Titan Panel is optional (since 0.5.177): the core declares OptionalDeps: Titan and must run alone without it; the panel entry is a LibDataBroker data source created only when the library exists. Do not change client APIs or manifest versions without matching evidence and live validation.

- TitanGatheredForever/ contains the shared runtime, English localization, generated metadata and required artwork. Its .toc loads Lua in the declared order.
- Twelve profession addons and a separate Auction house addon (folder TitanGatheredForever_AuctionItems) publish compact catalogue records. Use their matching TitanGatheredForever_* folder/manifest names and a dependency on the shared core only. Since 0.6.0 the Auction house addon also carries every auction feature (AuctionScan, AuctionUndercut, AuctionHistory, Sales): its files attach to the global TitanGatheredForever namespace, its manifest is generated with MODULE_EXTRAS in tools/generate_catalog.py, and the core must keep running without it (guard every ns.AuctionScan, ns.Sales, ns.AuctionUndercut and ns.AuctionHistory use). Its data stays in the core SavedVariables.
- TitanGatheredForever_Discovery is a standalone module with its own version line, listed in catalogue/standalone-modules.json and outside catalogue/modules.json. It is not part of the published collection or the fourteen ZIPs, and the shared-version rules below do not apply to it; build it with tools/package.py --standalone and install it with tools/install.py --standalone-only.
- catalogue/, tools/, tests/, release-notes/ and the ref- and book- Markdown documents live at repository root; every plan- document lives in plans/. Runtime folders contain only manifest-loaded code and allowlisted artwork. Keep private archives, generated distributions, SavedVariables and temporary files out of Git.
- Follow the user's document prefixes: plan-, ref-, book-, Codex-, budget-, bom- and tmp-. Every plan-* document lives in plans/ and nowhere else (not in the repository root); ref-, book- and release notes stay where they are. Temporary tmp-* files must be ignored and deleted after use. Avoid emoji, decorative glyphs and em dashes.

## Development and verification

There is no dependency installation/build step for runtime Lua. Use Python 3.10 or newer and LuaJIT with Lua 5.1 semantics for tooling/tests. Do not substitute the machine's Lua 5.5 compiler.

- python3 tools/check.py: all Python/Lua suites, generated-catalogue validation and compilation of every shipped Lua file.
- python3 tools/generate_catalog.py: regenerate catalogue publishers, metadata and evidence reports after reviewed data changes. --check rejects stale outputs.
- python3 tools/generate_pin_outlines.py --check: verify deterministic transparent outline assets.
- python3 tools/audit_catalog.py --check: validate the evidence report. Optional offline mirror/client-table inputs verify pinned bytes and scoped recipe facts; builds do not download or execute external sources.
- python3 tools/package.py: runtime-only collection, individual addon ZIPs, downloads.json and SHA256SUMS. See book-releases.md.
- /reload reloads Lua; new files/assets may require a full client restart. /console scriptErrors 1 enables in-game Lua error reporting.

## Code and data conventions

Follow nearby Lua formatting without unrelated reformatting. Keep exported TitanGatheredForever names and the legacy TitanGatheredForeverV3 alias and XML/manifest compatibility where relevant. Prefer local helpers. Do not put full recipe source records or development databases into runtime memory.

Preserve existing settings, acquired/produced statistics, per-character coverage and map observations. Keep attempts, completed casts, matched output operations, obtained quantities and complete-source denominators distinct. Unknown evidence must remain unknown. No instance map spots or invented ore/source identities. Catalogue completeness remains false until the documented evidence gates are actually satisfied.

## Documentation, commits and review

Commit messages and pull request descriptions carry no attribution to an AI tool: no Co-Authored-By trailer and no "Generated with" line. The owner does not want an assistant listed as a contributor. Check a message before committing.

README.md describes current behavior, plans/plan-live-verification-and-optimization.md is the continuation plan (live checks and the optimization backlog; plans/plan-next-development.md keeps the older milestone status), ref-wow-forever-progress.md records current status/history, and release-notes/ref-unreleased.md records changes since published versioned notes. Historical plans preserve original execution evidence; clearly mark superseded designs.

Run checks appropriate to changes and document live reproduction/results separately from automated validation. Before source publication, inspect staged files for private data and ignored artifacts. Use concise imperative commit subjects. PR descriptions should state behavior, affected modules, validation and remaining live/client limitations. Do not claim a source push publishes release assets or updates hosting.

## Text and price style in every window

Informational text (notes, summaries, footers, labels) is small and gold; product data is white or colored by meaning, so the two never run together. Prices always use the game money format with gold, silver and copper icons (ns.Economy.Coin, ns.NpcSources.CoinIcons), never plain "1g 2s" text. A label with a colon and its value, and the numbers inside a sentence, are told apart: Style.Label for the words, Style.Value for the data, Style.Range for "Showing a-b of n", and Style.Date (green) for every date or time of day. Check every new string against this and sweep the neighbouring windows. Tests that compare such text use tests/style_stub.lua.

## Automatic Live Installation

The user explicitly authorizes installing every completed addon update and new version into `/Applications/World of Warcraft/_forever_/Interface/AddOns` automatically. Do not leave tested runtime changes only in the source checkout or ask for this task authorization again.

- Run `python3 tools/check.py`, preview with `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'`, then apply the same command with `--apply` after checks pass.
- Use the installer so the previous candidate is backed up and unrelated addons, enablement and SavedVariables are preserved. Do not edit live files directly or change them while implementation is incomplete.
- Verify the installed runtime files against the source candidate after installation. If they already match exactly, report the verified state instead of making an identical installation.
- Respect sandbox approval requirements. Report installation failures or missing destinations clearly; do not claim a source-only update is installed.
- Tell the user to run `/reload` for Lua-only updates or fully restart WoW when new files/assets or manifests require it. Do not close or restart their game automatically.
- This authorization is for the local game installation. It does not authorize publishing releases, pushing commits or changing hosting.

The matching editor rule is `.cursor/rules/automatic-live-install.mdc`.

## Version every completed update

The user requires a version increment for every completed addon update or improvement. Increment the patch version for each completed update. A minor version (0.6.0) marks a milestone and is the owner's decision only (0.6.0 on 2026-11-28: Titan Panel optional and the Auction house module). On 2026-11-16 the user requested stable versions for all projects: use versions without alpha/beta suffixes. The official public product name is Titan Gathered Forever; the user subsequently requested matching folder names too. Runtime folders/manifests now use TitanGatheredForever (and profession suffixes); retain the TitanGatheredForeverV3 namespace alias and TitanGatheredForeverV3DB key for compatibility. The project left alpha at 0.5.0-beta; earlier 0.4.x-alpha versions are historical. Synchronize the shared core manifest, generator VERSION and all generated profession manifests before checks, installation and packaging. A source-only edit/test iteration or documentation evidence commit is not a separate deployed update. Website versions are independent and increment for each completed website update. Do not silently overwrite an existing versioned download set with different runtime bytes.
