# Plan: auction house logic in the Auction items module

Written 2026-11-18 at version 0.5.108. Status: proposed, not scheduled. The user wants the plan to exist but leaves the code as it is for now (auction logic stays in the core). Nothing in this plan is implemented.

## 1. Why

- TitanGatheredForever_AuctionItems is today a generated data catalogue with one item (264019). Its name and icon suggest auction functions, so the module is misleading: switching it off changes nothing about prices, the Sell tab or tooltips.
- The scan, the Buyout undercut and the posting figures live in the core. A new auction function means a new release of the core and all fourteen addons.
- Goal: the Auction items module owns the auction logic. Switching it off removes every auction function and price, and a new auction function ships as a new version of that module alone.

Decision options already discussed with the user (2026-11-18):

- A. Everything in the core, the module stays a catalogue (current state).
- B. Auction logic moves into the module (this plan).
- C. Code stays in the core, the module acts as the switch (cheapest, no independent release).

## 2. Current state (facts from the 0.5.108 sources)

- Core files, in .toc order: AuctionScan.lua (385 lines), AuctionUndercut.lua (396 lines), Economy.lua (pure posting and price math, also used for crafting profit).
- Callers outside those files:
  - Core.lua:289-290 calls AuctionScan.Initialize and AuctionUndercut.Initialize without a guard.
  - Tooltips.lua:38-68 uses AuctionScan.Price and Age (the first line checks that the table exists).
  - CraftingView.lua:78-107, Reports.lua:248-251 and Economy.lua:74 guard with `ns.AuctionScan and ...`.
  - Titan.lua:210-222 builds the "Auction prices" menu with AuctionScan.Status, the scan button and Clear.
- Settings.lua:35-42 holds auctionAutoScan, auctionTooltips, auctionUndercutEnabled, auctionUndercutPreset and auctionUndercutPercent; line 91 creates auctionLog. The data is in TitanGatheredForeverV3DB (ns.db), which the module also reaches through ns.
- Tests: tests/auction_scan.lua, auction_undercut.lua, economy.lua, integration.lua (file list), style_stub.lua.
- The module folder is generated: tools/generate_catalog.py writes Data.lua and the .toc (lines 383-387 build modules['Auction']). Hand-written Lua cannot simply be dropped there.

## 3. Target design

### 3.1 What moves into TitanGatheredForever_AuctionItems

- AuctionScan.lua, AuctionUndercut.lua.
- The auction part of Economy: Fee, Posting, MinPrice, Auction (scan price) and the cost lookup that reads the scan. The vendor and recipe part (VendorSell, Sale, Product, Coin) stays in the core.
- The auction menu entries, the tooltip price lines and the auction settings defaults.

### 3.2 What stays in the core: a price provider interface

A small table `ns.Prices` in a new core file Prices.lua (loaded before its callers):

- `Register(provider, apiVersion)`: the module calls it at load. A provider with a lower apiVersion than the core requires is refused with one chat message.
- `Price(itemID)` returns the lowest buyout and scan time, or nil. `Age(seconds)`, `Status()` and `Clear()` pass through.
- `Menu(add)` lets the provider add its entries to the "Auction prices" menu.
- `Tooltip(itemID)` lets the provider add its tooltip lines.
- Without a provider every call returns nil or does nothing, so profit and sale values stay unknown (the existing rule), while vendor and merchant prices keep working.

Callers listed in section 2 use ns.Prices only. Core.lua calls `ns.Prices.Initialize()`, which calls the provider when present.

### 3.3 Data and settings

- The scan data, the deposit log and the settings keep their names and stay in TitanGatheredForeverV3DB. No new SavedVariables file, so the folder rename problem does not repeat.
- Settings defaults stay in Settings.lua (they are only values); the module reads them.
- With the module off the data is kept and used again when it is switched on.

### 3.4 Packaging and versions

- generate_catalog.py must emit the Lua files and .toc entries for the module (the folder stops being data-only); the hand-written files live in a source directory the generator copies, so Data.lua stays generated.
- The rule of one synchronized version for all addons is relaxed for the module: package.py, the CI workflow and downloads.json must accept a module version that differs from the core version, with a minimum core API version in the module .toc comment or a Lua check.
- The module .toc keeps `## Dependencies: Titan, TitanGatheredForever`.

## 4. Impact on players

- A player without the module loses the auction functions after updating. A one-time login chat line says so (the same pattern as LegacyFolders.lua). The CurseForge description of the module changes to say what it does.
- Players who already have the module keep everything; their saved scan data and settings stay.
- The module name and folder do not change (a rename already caused problems in 0.5.84).

## 5. Steps

1. Core: add Prices.lua with the interface and tests (tests/prices.lua) for the empty case and a fake provider. No behavior change; AuctionScan registers itself as the provider.
2. Core: convert Tooltips, Titan, Core, CraftingView, Reports and Economy to ns.Prices. All suites must pass unchanged.
3. Move AuctionScan, AuctionUndercut and the auction part of Economy into the module source; adapt generate_catalog.py, package.py, the .toc files and the CI workflow; add the apiVersion check.
4. Add the login hint for players without the module; update README, ref-wow-forever-progress.md, book-releases.md and the CurseForge description.
5. Tests: the three auction suites load the module files; integration.lua gets a run without the module (nothing auction related appears, vendor prices still work) and a run with it.
6. Install into the live folder, check live: Sell tab on both forms, tooltips, the Titan menu, scan with the module off and on, /reload. Document the result separately from automated checks.

## 6. Risks and open questions

- Size: this touches about ten files, the generator, packaging and the CI workflow. Expect more than one session.
- The interface must stay small. A growing provider table recreates the coupling in another form.
- A change to the interface needs both the core and the module released together; the apiVersion check makes a mismatch visible instead of silent.
- Open: whether the 171 players of the core also have the module installed is unknown; the login hint depends on it.
- Open: whether the Auction items catalogue (one item) should become part of the new module data or move into the core.
- Open: whether the generated module should keep the name "Auction items" or get a clearer one in the game (display name only, never the folder).

## 7. Verification

- python3 tools/check.py, the new prices suite and the three auction suites.
- Run the integration suite with and without the module files.
- Live checks as in step 6, recorded in plans/plan-live-verification-and-optimization.md.
