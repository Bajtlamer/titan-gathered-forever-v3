# Auction Buyout undercut Implementation Plan

> **Status 2026-11-17:** implemented and live checked on the commodity form in versions 0.5.85 to 0.5.97. The code in this plan is the first design; the shipped code differs: the manual-edit hook uses HookScript on the money boxes (not SetOnValueChangedCallback, which would replace the callback of the client), a busy message queue waits for the answer of the client instead of cancelling, the vendor price comes from ns.Economy.VendorSell, a percentage that would go below the vendor price sets the vendor price with a red warning, a changed percentage prices the selected item again, and there is no Sanitize helper (Settings.lua holds the defaults). The strip is in the row above the Buyout Mode check box. The form of single items is not yet checked live.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the Sell tab of the auction house, fill the Buyout price automatically with the lowest existing buyout minus x percent, chosen in a combo box (2, 5, 10, 15 percent or a custom value).

**Architecture:** A new core file `TitanGatheredForever/AuctionUndercut.lua` holds pure logic behind a replaceable `api` table (the pattern of `AuctionScan.New(api)`), plus a thin client layer (`DefaultAPI`, `Attach`, `Initialize`). The combo box reuses `ns.Nav.Dropdown`. The design is in `plans/plan-auction-undercut.md`.

**Tech Stack:** Lua 5.1 (LuaJIT for tests), WoW Forever 1.60.1 `C_AuctionHouse`, Python 3.10 tooling (`tools/check.py`).

Rules from AGENTS.md that apply to every task: no em dashes, no emoji, English add-on texts, commit messages without any AI attribution line, prices through `ns.Economy.Coin`, gold small informational text through `ns.Style.Label`, white data through `ns.Style.Value`.

---

### Task 1: Confirm the Sell frames in the client (done 2026-11-17, see spec section 8)

The names below are taken from the retail auction house and are not yet confirmed for WoW Forever 1.60.1. Task 5 depends on the answers.

- [ ] **Step 1: Ask the user to open the auction house, the Sell tab, and run in chat**

```
/dump AuctionHouseFrame ~= nil
/dump AuctionHouseFrame.CommoditiesSellFrame ~= nil
/dump AuctionHouseFrame.ItemSellFrame ~= nil
/dump AuctionHouseFrame.CommoditiesSellFrame.PriceInput ~= nil
/dump AuctionHouseFrame.CommoditiesSellFrame.SetItem ~= nil
/dump AuctionHouseFrame.ItemSellFrame.BuyoutPrice ~= nil
/dump C_AuctionHouse.GetItemCommodityStatus ~= nil
/dump C_AuctionHouse.SendSearchQuery ~= nil
```

Expected: `true` for each. Record every `false` and the real field names (use `/dump` on the frame to list children) in the Task 5 code before writing it.

- [ ] **Step 2: Write the answers into `plans/plan-auction-undercut.md` section 8** as "Confirmed on <date>: ..." so the evidence stays with the design.

---

### Task 2: Settings

**Files:**
- Modify: `TitanGatheredForever/Settings.lua:35` (after the `auctionAutoScan` line)
- Test: `tests/auction_undercut.lua` (created in Task 3; the settings test is added there)

- [ ] **Step 1: Add the defaults**

```lua
    if type(settings.auctionUndercutEnabled) ~= 'boolean' then settings.auctionUndercutEnabled = true end
    if type(settings.auctionUndercutPercent) ~= 'number' or settings.auctionUndercutPercent < 0.1
        or settings.auctionUndercutPercent > 90 then settings.auctionUndercutPercent = 5 end
    local preset = settings.auctionUndercutPreset
    if preset ~= 2 and preset ~= 5 and preset ~= 10 and preset ~= 15 and preset ~= 'custom' then
        settings.auctionUndercutPreset = 5
        settings.auctionUndercutPercent = 5
    end
```

- [ ] **Step 2: Run the existing suites to confirm nothing broke**

Run: `python3 tools/check.py </dev/null`
Expected: ends without error.

---

### Task 3: Pure logic with tests (TDD)

**Files:**
- Create: `tests/auction_undercut.lua`
- Create: `TitanGatheredForever/AuctionUndercut.lua`
- Modify: `tools/check.py` (add `[runtime, 'tests/auction_undercut.lua'],` after the `auction_scan.lua` line, line 48)

- [ ] **Step 1: Write the failing test file**

```lua
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function load()
    local ns = { settings = {} }
    assert(loadfile('TitanGatheredForever/AuctionUndercut.lua'))('TitanGatheredForever', ns)
    return ns
end

-- A fake client. Results are { price = copper, own = boolean } lists keyed by item key.
local function fixture(options)
    local ns = load()
    local f = { ns = ns, searches = {}, said = {}, set = {}, enabled = true, percent = 5, vendor = nil, ready = true }
    for key, value in pairs(options or {}) do f[key] = value end
    local api = {
        Enabled = function() return f.enabled end,
        Percent = function() return f.percent end,
        Ready = function() return f.ready end,
        Search = function(key) f.searches[#f.searches + 1] = key end,
        Vendor = function() return f.vendor end,
        SetBuyout = function(copper) f.set[#f.set + 1] = copper end,
        Say = function(message) f.said[#f.said + 1] = message end,
    }
    f.undercut = ns.AuctionUndercut.New(api)
    return f
end

test('percent text is parsed with a dot or a comma and limited to 0.1 through 90', function()
    local U = load().AuctionUndercut
    eq(U.ParsePercent('7'), 7)
    eq(U.ParsePercent('2,5'), 2.5)
    eq(U.ParsePercent(' 12.34 '), 12.3)
    eq(U.ParsePercent('0'), nil)
    eq(U.ParsePercent('0.05'), nil)
    eq(U.ParsePercent('91'), nil)
    eq(U.ParsePercent('abc'), nil)
    eq(U.ParsePercent(''), nil)
end)

test('the price is the lowest minus the percent, rounded down, at least one copper', function()
    local U = load().AuctionUndercut
    eq(U.Price(10000, 5), 9500)
    eq(U.Price(999, 10), 899)
    eq(U.Price(1, 90), 1)
    eq(U.Price(2, 15), 1)
end)

test('a price below the vendor price is refused with a reason', function()
    local U = load().AuctionUndercut
    local price, reason = U.Price(1000, 10, 950)
    eq(price, nil); eq(reason, 'vendor')
    eq(U.Price(1000, 10, 900), 900)
end)

test('a selection starts one search and the answer sets the buyout from the lowest foreign auction', function()
    local f = fixture()
    f.undercut:Select('item-1')
    eq(#f.searches, 1); eq(f.searches[1], 'item-1')
    f.undercut:Results('item-1', { { price = 5000, own = false }, { price = 4000, own = true }, { price = 6000, own = false } })
    eq(f.set[1], 4750)
end)

test('own auctions are ignored, so a player never undercuts himself', function()
    local f = fixture()
    f.undercut:Select('a')
    f.undercut:Results('a', { { price = 100, own = true } })
    eq(#f.set, 0); eq(#f.said, 1)
end)

test('no auctions: nothing is set and the player is told', function()
    local f = fixture()
    f.undercut:Select('a')
    f.undercut:Results('a', {})
    eq(#f.set, 0); eq(#f.said, 1)
end)

test('an answer for an item that is no longer selected is discarded', function()
    local f = fixture()
    f.undercut:Select('a')
    f.undercut:Select('b')
    f.undercut:Results('a', { { price = 1000, own = false } })
    eq(#f.set, 0)
    f.undercut:Results('b', { { price = 2000, own = false } })
    eq(f.set[1], 1900)
end)

test('a manual edit of the price stops the automatic fill for that selection only', function()
    local f = fixture()
    f.undercut:Select('a')
    f.undercut:Edited()
    f.undercut:Results('a', { { price = 1000, own = false } })
    eq(#f.set, 0)
    f.undercut:Select('b')
    f.undercut:Results('b', { { price = 1000, own = false } })
    eq(#f.set, 1)
end)

test('disabled, or the message system not ready: no search is sent', function()
    local f = fixture({ enabled = false })
    f.undercut:Select('a')
    eq(#f.searches, 0)
    local g = fixture({ ready = false })
    g.undercut:Select('a')
    eq(#g.searches, 0)
end)

test('the vendor price floor refuses the fill and says why', function()
    local f = fixture({ vendor = 960 })
    f.undercut:Select('a')
    f.undercut:Results('a', { { price = 1000, own = false } })
    eq(#f.set, 0); eq(#f.said, 1)
end)

test('settings defaults are valid and a bad saved value is repaired', function()
    local ns = { settings = { auctionUndercutPercent = 500, auctionUndercutPreset = 'x' } }
    -- Settings.lua is loaded by the addon tests; here the contract is checked on the helper.
    local U = load().AuctionUndercut
    eq(U.Sanitize(ns.settings), true)
    eq(ns.settings.auctionUndercutPercent, 5); eq(ns.settings.auctionUndercutPreset, 5); eq(ns.settings.auctionUndercutEnabled, true)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS auction undercut ' .. #tests .. ' checks')
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `luajit tests/auction_undercut.lua`
Expected: FAIL because `TitanGatheredForever/AuctionUndercut.lua` does not exist.

- [ ] **Step 3: Write the logic**

Settings.lua keeps its own defaults (Task 2); `Sanitize` here is the single implementation both call, so Task 2 Step 1 is replaced by one line `ns.AuctionUndercut.Sanitize(settings)` only if load order allows. AuctionUndercut.lua loads after Settings.lua, so Settings.lua keeps the inline block and `Sanitize` repeats the same rules for the test and the combo box. Keep both identical.

```lua
local _, ns = ...
-- Fills the Buyout price of a new auction from the lowest existing buyout of the same item minus a percentage the
-- player chooses in a combo box. The search is live (one query per selected item); a stored scan is not used.
-- Pure logic is here behind a replaceable api table; the client wiring is at the end of the file.
local Undercut = {}
Undercut.__index = Undercut
ns.AuctionUndercut = Undercut

Undercut.MIN, Undercut.MAX = 0.1, 90
Undercut.PRESETS = { 2, 5, 10, 15 }

-- "2,5" or "2.5" to 2.5, limited to MIN through MAX with one decimal; nil for anything else.
function Undercut.ParsePercent(text)
    if type(text) ~= 'string' then return nil end
    local number = tonumber((text:gsub('^%s+', ''):gsub('%s+$', ''):gsub(',', '.')))
    if not number then return nil end
    number = math.floor(number * 10 + 0.5) / 10
    if number < Undercut.MIN or number > Undercut.MAX then return nil end
    return number
end

-- Price in copper, or nil and a reason ('vendor') when it would fall below what a vendor pays.
function Undercut.Price(lowest, percent, vendor)
    local price = math.max(1, math.floor(lowest * (1 - percent / 100)))
    if vendor and vendor > 0 and price < vendor then return nil, 'vendor' end
    return price
end

-- Repairs the saved values. Returns true.
function Undercut.Sanitize(settings)
    if type(settings.auctionUndercutEnabled) ~= 'boolean' then settings.auctionUndercutEnabled = true end
    local preset = settings.auctionUndercutPreset
    local valid = preset == 'custom'
    for _, value in ipairs(Undercut.PRESETS) do if preset == value then valid = true end end
    local percent = settings.auctionUndercutPercent
    if not valid or type(percent) ~= 'number' or percent < Undercut.MIN or percent > Undercut.MAX then
        settings.auctionUndercutPreset, settings.auctionUndercutPercent = 5, 5
    end
    return true
end

function Undercut.New(api)
    return setmetatable({ api = api }, Undercut)
end

-- An item was chosen in the Sell form. key identifies the item for the search and for the answer.
function Undercut:Select(key)
    self.key, self.edited = key, false
    if not self.api.Enabled() or not self.api.Ready() then self.key = nil; return end
    self.api.Search(key)
end

-- The player typed a price: the fill leaves this selection alone.
function Undercut:Edited() self.edited = true end

-- The search answer: list of { price = copper per unit or buyout, own = true for the player's auctions }.
function Undercut:Results(key, list)
    if key ~= self.key or self.edited then return end
    local lowest
    for _, entry in ipairs(list) do
        if not entry.own and entry.price and entry.price > 0 and (not lowest or entry.price < lowest) then lowest = entry.price end
    end
    if not lowest then self.api.Say('No other auction of this item: set the Buyout yourself.'); return end
    local price, reason = Undercut.Price(lowest, self.api.Percent(), self.api.Vendor(key))
    if not price then
        self.api.Say('The undercut price would be below the vendor price: Buyout left unchanged.')
        return
    end
    self.api.SetBuyout(price)
end
```

- [ ] **Step 4: Register the test in `tools/check.py`** and run

Run: `luajit tests/auction_undercut.lua`
Expected: `PASS auction undercut 10 checks`

- [ ] **Step 5: Commit**

```bash
git add tests/auction_undercut.lua TitanGatheredForever/AuctionUndercut.lua TitanGatheredForever/Settings.lua tools/check.py
git commit -m "Add the pure logic of the Buyout undercut"
```

---

### Task 4: Manifest and load order

**Files:**
- Modify: `TitanGatheredForever/TitanGatheredForever.toc:44` (add `AuctionUndercut.lua` after `AuctionScan.lua`)
- Modify: `TitanGatheredForever/Core.lua:289` (add `ns.AuctionUndercut.Initialize()` after `ns.AuctionScan.Initialize()`)

- [ ] **Step 1: Add both lines**, then add a stub `function Undercut.Initialize() end` at the end of AuctionUndercut.lua so Core does not fail until Task 5.
- [ ] **Step 2: Run** `python3 tools/check.py </dev/null`. Expected: passes, `tests/addon_loading.lua` loads the new file.

---

### Task 5: Client layer: combo box, hooks, live search

**Files:**
- Modify: `TitanGatheredForever/AuctionUndercut.lua` (replace the stub; uses the names confirmed in Task 1)
- Test: `tests/auction_undercut.lua` (add a client-layer test with fake frames, like the `Attach` test in `tests/auction_scan.lua`)

- [ ] **Step 1: Write the failing test.** Fake `AuctionHouseFrame` with `CommoditiesSellFrame` and `ItemSellFrame` tables whose `SetItem` is replaceable, a fake `PriceInput:SetAmount`, a fake `CreateFrame` returning recording frames, and fake `C_AuctionHouse`. Assert: after `Attach()` the strip exists once (second `Attach()` returns true without creating another); calling the hooked `SetItem` sends one `SendSearchQuery`; firing `COMMODITY_SEARCH_RESULTS_UPDATED` with two results calls `SetAmount` with the undercut price; `Nav.Dropdown` was called with the five options 2, 5, 10, 15, custom.

- [ ] **Step 2: Run it and confirm it fails**

Run: `luajit tests/auction_undercut.lua`
Expected: FAIL on the new test.

- [ ] **Step 3: Implement** (replace the stub). Field names marked with a comment are the ones to correct from Task 1.

```lua
function Undercut.DefaultAPI()
    local api = {}
    local frame
    api.Enabled = function() return ns.settings.auctionUndercutEnabled == true end
    api.Percent = function() return ns.settings.auctionUndercutPercent end
    api.Ready = function()
        local ok, value = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        return not ok or value ~= false
    end
    api.Search = function(key)
        pcall(C_AuctionHouse.SendSearchQuery, key.itemKey, {}, true)
    end
    api.Vendor = function(key)
        local sell = select(11, GetItemInfo(key.itemKey.itemID))
        return ns.IsPublic(sell) and type(sell) == 'number' and sell or nil
    end
    api.SetBuyout = function(copper)
        local sell = Undercut.sellFrame
        if sell and sell.PriceInput and sell.PriceInput.SetAmount then       -- name confirmed in Task 1
            Undercut.filling = true
            sell.PriceInput:SetAmount(copper)
            Undercut.filling = false
            ns.Print('Buyout set to ' .. ns.Economy.Coin(copper) .. ' (' .. ns.Style.Value(Undercut.Describe()) .. ').')
        end
    end
    api.Say = function(message) ns.Print(ns.Style.Label(message)) end
    return api
end

function Undercut.Describe()
    return string.format('%s%% under the lowest', tostring(ns.settings.auctionUndercutPercent))
end

local function keyOf(sell, itemLocation)
    if not itemLocation or not C_AuctionHouse.GetItemKeyFromItem then return nil end
    local ok, itemKey = pcall(C_AuctionHouse.GetItemKeyFromItem, itemLocation)
    if not ok or not itemKey then return nil end
    return { itemKey = itemKey, commodity = sell == _G.AuctionHouseFrame.CommoditiesSellFrame }
end

-- The strip under the Sell form: label, combo box and the custom percent field.
function Undercut.Attach()
    if Undercut.strip then return true end
    local frame = _G.AuctionHouseFrame
    if not frame or not frame.CommoditiesSellFrame then return false end   -- names confirmed in Task 1
    local strip = CreateFrame('Frame', nil, frame)
    Undercut.strip = strip
    strip:SetSize(330, 24)
    strip:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 12, 6)
    local label = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    label:SetPoint('LEFT', 0, 0)
    label:SetText('Buyout undercut')
    local options = {
        { value = 2, label = '2 %' }, { value = 5, label = '5 %' }, { value = 10, label = '10 %' },
        { value = 15, label = '15 %' }, { value = 'custom', label = 'Custom' },
    }
    local box = CreateFrame('EditBox', nil, strip, 'InputBoxTemplate')
    box:SetSize(44, 20); box:SetAutoFocus(false); box:SetMaxLetters(5)
    box:SetPoint('LEFT', strip, 'LEFT', 220, 0)
    local function show() box:SetShown(ns.settings.auctionUndercutPreset == 'custom') end
    local drop = ns.Nav.Dropdown(strip, 100, 0, 110, function() return options end,
        function() return ns.settings.auctionUndercutPreset end,
        function(value)
            ns.settings.auctionUndercutPreset = value
            if value ~= 'custom' then ns.settings.auctionUndercutPercent = value else box:SetText(tostring(ns.settings.auctionUndercutPercent)) end
            show()
        end)
    box:SetScript('OnEnterPressed', function(self)
        local value = Undercut.ParsePercent(self:GetText())
        if value then ns.settings.auctionUndercutPercent = value end
        self:SetText(tostring(ns.settings.auctionUndercutPercent)); self:ClearFocus()
    end)
    box:SetScript('OnEscapePressed', function(self) self:SetText(tostring(ns.settings.auctionUndercutPercent)); self:ClearFocus() end)
    box:SetText(tostring(ns.settings.auctionUndercutPercent))
    show()
    Undercut.drop, Undercut.box = drop, box

    -- Hook points, one place. SetItem is called by the client when an item is chosen in a Sell form.
    for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
        hooksecurefunc(sell, 'SetItem', function(self, itemLocation)
            Undercut.sellFrame = self
            local key = keyOf(self, itemLocation)
            if key then Undercut.instance:Select(key) end
        end)
        local input = sell.PriceInput
        if input and input.MoneyInputFrame and input.MoneyInputFrame.SetScript then
            hooksecurefunc(input, 'SetOnValueChangedCallback', function()      -- confirmed in Task 1; check how the callback is stored before relying on this hook
                if not Undercut.filling then Undercut.instance:Edited() end
            end)
        end
    end
    return true
end

function Undercut.Initialize()
    if Undercut.frame then return end
    Undercut.Sanitize(ns.settings)
    Undercut.instance = Undercut.New(Undercut.DefaultAPI())
    local frame = CreateFrame('Frame')
    Undercut.frame = frame
    frame:SetScript('OnEvent', function(_, event, arg)
        if event == 'AUCTION_HOUSE_SHOW' then Undercut.Attach(); return end
        local key = Undercut.instance.key
        if not key then return end
        local list = {}
        if event == 'COMMODITY_SEARCH_RESULTS_UPDATED' and key.commodity and arg == key.itemKey.itemID then
            for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(arg) do
                local info = C_AuctionHouse.GetCommoditySearchResultInfo(arg, i)
                if info then list[#list + 1] = { price = info.unitPrice, own = info.containsOwnerItem } end
            end
            Undercut.instance:Results(key, list)
        elseif event == 'ITEM_SEARCH_RESULTS_UPDATED' and not key.commodity then
            for i = 1, C_AuctionHouse.GetNumItemSearchResults(arg) do
                local info = C_AuctionHouse.GetItemSearchResultInfo(arg, i)
                if info then list[#list + 1] = { price = info.buyoutAmount, own = info.containsOwnerItem } end
            end
            Undercut.instance:Results(key, list)
        end
    end)
    for _, event in ipairs({ 'AUCTION_HOUSE_SHOW', 'COMMODITY_SEARCH_RESULTS_UPDATED', 'ITEM_SEARCH_RESULTS_UPDATED' }) do
        frame:RegisterEvent(event)
    end
end
```

Note: `Select(key)` stores the table `key` and `Results(key, list)` compares identity; the event handler passes `Undercut.instance.key` back, which is correct because only one selection is current and a newer `Select` replaces it before an older answer can match. The item-search answer is compared with the selection by its item key inside the handler in the first live test (Task 7).

- [ ] **Step 4: Run** `luajit tests/auction_undercut.lua`
Expected: `PASS auction undercut` with the new count.

- [ ] **Step 5: Commit** `git commit -am "Wire the Buyout undercut to the Sell tab"` after `git add` of the touched files.

---

### Task 6: Titan menu option

**Files:**
- Modify: `TitanGatheredForever/Titan.lua:215` (after the `auctionTooltips` check box)

- [ ] **Step 1: Add**

```lua
        auction:CreateCheckbox('Fill Buyout in the Sell tab (lowest price minus a percentage)', function() return ns.settings.auctionUndercutEnabled ~= false end, function()
            ns.settings.auctionUndercutEnabled = ns.settings.auctionUndercutEnabled == false
        end)
```

- [ ] **Step 2: Run** `python3 tools/check.py </dev/null`. Expected: passes.

---

### Task 7: Version, documentation, installation, live check

**Files:**
- Modify: version `0.5.84` to `0.5.85` in `README.md`, `tools/generate_catalog.py:14`, every `TitanGatheredForever*/*.toc` (run `python3 tools/generate_catalog.py` for the generated ones)
- Modify: `README.md` (new behavior paragraph), `release-notes/ref-unreleased.md` (newest on top), `ref-wow-forever-progress.md` (live result, separate from automated validation), `plans/plan-live-verification-and-optimization.md` (add the live check)

- [ ] **Step 1: Bump the version** and run `python3 tools/generate_catalog.py`, then `python3 tools/generate_catalog.py --check`. Expected: no stale outputs.
- [ ] **Step 2: Write the documentation entries** (behavior, combo box values, limits, live search, the risk list from the spec).
- [ ] **Step 3: Full check:** `python3 tools/check.py </dev/null`. Expected: passes.
- [ ] **Step 4: Preview the installation:** `python3 tools/install.py --addons-dir '/Applications/World of Warcraft/_forever_/Interface/AddOns'`, then the same command with `--apply`. Verify the installed bytes against the source.
- [ ] **Step 5: Tell the user** to fully restart WoW (a new Lua file is added, `/reload` is not enough), then run this live check and report: open the auction house, choose an item in Sell, the Buyout fills within about a second; change the combo box to 10 % and choose another item; choose Custom, type `7,5`, choose another item; edit the price by hand and confirm it is not overwritten; `/reload` and confirm the value stays. Enable `/console scriptErrors 1` first.
- [ ] **Step 6: Record the live result** in `ref-wow-forever-progress.md`, then commit the code and documents as separate, concise imperative commits. No attribution lines. Do not push or publish a release.

---

## Self-review against the spec

- Spec 3 interface (combo box with presets and custom, field limits, check box): Tasks 3 (`ParsePercent`), 5 (combo box, field), 6 (check box).
- Spec 4 settings: Task 2 and `Sanitize` in Task 3.
- Spec 5 flow (live search, commodity and item answers, own auctions, vendor floor, manual edit, stale answers, throttle readiness): Task 3 logic and tests, Task 5 client layer.
- Spec 6 structure (api table): Task 3 and Task 5 `DefaultAPI`.
- Spec 7 tests: Task 3 and Task 5. Spec 8 risk (frame names): Task 1 gate. Spec 9 release steps: Task 7.
- Known gap handled in text: the item-search answer is matched by the single current selection; Task 7 live check confirms it.
