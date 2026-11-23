local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function load(extra)
    local ns = { settings = {}, IsPublic = function() return true end, printed = {}, db = {} }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.Style = { red = 'red', Text = function(color, t) return '<' .. color .. '>' .. t end }
    dofile('tests/style_stub.lua')(ns.Style)
    assert(loadfile('TitanGatheredForever/Economy.lua'))('TitanGatheredForever', ns)
    ns.Economy.Coin = function(c) return c .. 'c' end
    ns.Economy.VendorSell = function() return 100 end
    for key, value in pairs(extra or {}) do ns[key] = value end
    assert(loadfile('TitanGatheredForever/AuctionUndercut.lua'))('TitanGatheredForever', ns)
    return ns
end

local function fixture(options)
    local ns = load()
    local f = { ns = ns, searches = {}, said = {}, set = {}, enabled = true, percent = 5, ready = true }
    for key, value in pairs(options or {}) do f[key] = value end
    f.undercut = ns.AuctionUndercut.New({
        Enabled = function() return f.enabled end, Percent = function() return f.percent end,
        Ready = function() return f.ready end, Search = function(key) f.searches[#f.searches + 1] = key end,
        Vendor = function() return f.vendor end, SetBuyout = function(copper) f.set[#f.set + 1] = copper end,
        Say = function(message) f.said[#f.said + 1] = message end,
    })
    return f
end

test('the price is the lowest minus the percent, rounded down, at least one copper', function()
    local U = load().AuctionUndercut
    eq(U.Price(10000, 5), 9500); eq(U.Price(999, 10), 899); eq(U.Price(1, 90), 1); eq(U.Price(2, 15), 1)
end)

test('a price below the vendor price is refused with a reason', function()
    local U = load().AuctionUndercut
    local price, reason = U.Price(1000, 10, 950)
    eq(price, nil); eq(reason, 'vendor'); eq(U.Price(1000, 10, 900), 900)
end)

test('a selection starts one search and the answer sets the buyout from the lowest foreign auction', function()
    local f = fixture()
    local key = {}
    f.undercut:Select(key)
    eq(#f.searches, 1); eq(f.searches[1], key)
    f.undercut:Results(key, { { price = 5000 }, { price = 4000, own = true }, { price = 6000 } })
    eq(f.set[1], 4750)
end)

test('only own auctions or none: nothing is set and the player is told', function()
    local f = fixture()
    local key = {}
    f.undercut:Select(key)
    f.undercut:Results(key, { { price = 100, own = true } })
    eq(#f.set, 0); eq(#f.said, 1)
    f.undercut:Results(key, {})
    eq(#f.set, 0); eq(#f.said, 2)
end)

test('an answer for an item that is no longer selected is discarded', function()
    local f = fixture()
    local a, b = {}, {}
    f.undercut:Select(a); f.undercut:Select(b)
    f.undercut:Results(a, { { price = 1000 } })
    eq(#f.set, 0)
    f.undercut:Results(b, { { price = 2000 } })
    eq(f.set[1], 1900)
end)

test('a manual edit stops the fill for that selection only', function()
    local f = fixture()
    local a, b = {}, {}
    f.undercut:Select(a); f.undercut:Edited()
    f.undercut:Results(a, { { price = 1000 } })
    eq(#f.set, 0)
    f.undercut:Select(b)
    f.undercut:Results(b, { { price = 1000 } })
    eq(#f.set, 1)
end)

test('disabled: no search and the answer is ignored; a busy queue sends no search but the answer is used', function()
    local f = fixture({ enabled = false })
    local key = {}
    f.undercut:Select(key); f.undercut:Results(key, { { price = 100 } })
    eq(#f.searches, 0); eq(#f.set, 0)
    local g = fixture({ ready = false })
    g.undercut:Select(key)
    eq(#g.searches, 0)
    g.undercut:Results(key, { { price = 1000 } })
    eq(g.set[1], 950)
end)

test('a changed percentage prices the same answer again, also over a typed price', function()
    local f = fixture()
    local key = {}
    f.undercut:Select(key)
    f.undercut:Results(key, { { price = 1000 }, { price = 2000 } })
    eq(f.set[1], 950)
    f.percent = 10
    f.undercut:Refill()
    eq(f.set[2], 900)
    f.undercut:Edited()
    f.percent = 15
    f.undercut:Refill()
    eq(f.set[3], 850)
    f.undercut:Select({})
    f.undercut:Refill()
    eq(#f.set, 3)
end)

test('an error while reading the vendor price does not stop the fill', function()
    local f = fixture()
    local key = {}
    f.undercut.api.Vendor = function() error('boom') end
    f.undercut:Select(key); f.undercut:Results(key, { { price = 1000 } })
    eq(f.set[1], 950)
end)

test('the vendor price floor sets the vendor price, warns in red and clears the warning at the next fill', function()
    local f = fixture({ vendor = 960 })
    local warned = {}
    f.undercut.api.Warn = function(reason, vendor) warned[#warned + 1] = tostring(reason) .. ':' .. tostring(vendor) end
    local key = {}
    f.undercut:Select(key)
    f.undercut:Results(key, { { price = 1000 } })
    eq(f.set[1], 960); eq(#f.said, 1)
    eq(warned[#warned], 'vendor:960')
    f.percent = 1
    f.undercut:Refill()
    eq(f.set[2], 990); eq(warned[#warned], 'nil:nil')
end)

test('the floor counts the fee: a price at the vendor price is lifted to the lowest price that beats a vendor', function()
    local f = fixture({ vendor = 100 })
    f.undercut.api.Floor = function(vendor) return 106 end
    local warned = {}
    f.undercut.api.Warn = function(reason, floor) warned[#warned + 1] = tostring(reason) .. ':' .. tostring(floor) end
    local key = {}
    f.undercut:Select(key)
    f.undercut:Results(key, { { price = 110 } })              -- 5 percent under 110 is 104, below the floor of 106
    eq(f.set[1], 106); eq(warned[#warned], 'vendor:106')
    f.undercut:Results(key, { { price = 200 } }); eq(f.set[2], 190)
    f.undercut.api.Floor = function() error('boom') end        -- a failing floor falls back to the vendor price
    f.undercut:Results(key, { { price = 110 } }); eq(f.set[3], 104)
end)

test('the listing shows what a sale earns after the cost and what a failed auction loses, nothing compared with others', function()
    local ns = load()
    local U, E = ns.AuctionUndercut, ns.Economy
    local sold, loss, threshold = U.ListingLines(E.Posting(1000, 5, 120, 100, 300))
    eq(sold, '<gold>If sold, profit: <green>+<white>3250c')
    eq(loss, '<gold>If unsold, loss: <red>-<white>120c')
    eq(threshold, '<gold>Break-even sales: <white>4%')
    sold, loss, threshold = U.ListingLines(E.Posting(100, 1, 40, 100, 100))
    eq(sold, '<gold>If sold, profit: <red>-<white>5c')
    eq(threshold, '<red>A sale does not cover the cost')
    sold, loss, threshold = U.ListingLines(E.Posting(1000, 1, nil, 100))                   -- no cost, no deposit
    eq(sold, '<gold>If sold, you get: <white>950c'); eq(loss, ''); eq(threshold, '')
    sold, loss, threshold = U.ListingLines(nil)
    eq(sold, ''); eq(loss, ''); eq(threshold, '')
end)

test('the narrow panel has separate lines for costs, vendor comparison, deposit and break-even', function()
    local ns = load()
    local U, E = ns.AuctionUndercut, ns.Economy
    local head, cost, vendor, deposit, threshold = U.InfoText(E.Posting(1000, 5, 120, 100, 300))
    eq(head, '<gold>AH sold: <white>4750c<gold>  Vendor: <white>500c')
    eq(cost, '<gold>Gain vs cost: <green>+<white>3250c')
    eq(vendor, '<gold>Gain vs vendor: <green>+<white>4250c')
    eq(deposit, '<gold>Unsold deposit: <red>-<white>120c')
    eq(threshold, '<gold>Break-even sales: <white>3%')
    head, cost, vendor, deposit, threshold = U.InfoText(E.Posting(100, 1, 40, 100, 100))
    eq(cost, '<gold>Gain vs cost: <red>-<white>5c')
    eq(vendor, '<gold>Gain vs vendor: <red>-<white>5c')
    eq(threshold, '<red>A sale does not beat a vendor')
    head, cost, vendor, deposit, threshold = U.InfoText(E.Posting(1000, 1, nil, nil))
    eq(head, '<gold>AH sold: <white>950c'); eq(cost, ''); eq(vendor, '')
    eq(deposit, '<gold>Unsold deposit: <gold>Unavailable'); eq(threshold, '')
    head, cost, vendor, deposit, threshold = U.InfoText(nil)
    eq(head, ''); eq(cost, ''); eq(vendor, ''); eq(deposit, ''); eq(threshold, '')
end)

-- The client layer with fake frames.
local function client()
    local created, hooks, texts = {}, {}, {}
    local function frame()
        local self = { scripts = {}, shown = true }
        function self:SetSize() end
        function self:SetHeight() end
        function self:SetWidth() end
        function self:SetPoint(...) self.point = { ... } end
        function self:SetText(t) self.text = t end
        function self:SetJustifyH() end
        function self:ClearAllPoints() self.points = 0 end
        function self:GetText() return self.text or '' end
        function self:SetAutoFocus() end
        function self:SetMaxLetters() end
        function self:SetShown(v) self.shown = v end
        function self:IsShown() return self.shown end
        function self:ClearFocus() end
        function self:Hide() self.shown = false end
        function self:Show() self.shown = true end
        function self:SetScript(name, fn) self.scripts[name] = fn end
        function self:HookScript(name, fn) self.hooked = self.hooked or {}; self.hooked[name] = fn end
        function self:CreateFontString() return frame() end
        function self:SetAmount(copper) self.amount = copper end
        function self:GetAmount() return self.amount end
        function self:RegisterEvent(e) self.events = (self.events or 0) + 1 end
        created[#created + 1] = self
        return self
    end
    local function money() return { GoldBox = frame(), SilverBox = frame(), CopperBox = frame() } end
    local function sellFrame()
        local s = { PriceInput = frame(), SecondaryPriceInput = frame() }
        s.PriceInput.MoneyInputFrame = money(); s.SecondaryPriceInput.MoneyInputFrame = money()
        function s:SetItem(item)
            self.location = item and { id = item.id, IsValid = function() return true end }
        end
        function s:GetItem() return self.location end
        s.deposit, s.quantity = 30, 4
        function s:GetDepositAmount() return self.deposit end
        function s:GetDuration() return 3 end
        function s:GetQuantity() return self.quantity end
        function s:GetPrice() return 4500 end
        function s:GetTotalPrice() return 18000 end
        function s:UpdateDeposit() end
        function s:HookScript(name, fn) self.hooked = self.hooked or {}; self.hooked[name] = fn end
        s.shown = true
        function s:IsShown() return self.shown end
        return s
    end
    local g = { AuctionHouseFrame = { CommoditiesSellFrame = sellFrame(), ItemSellFrame = sellFrame(), height = 538, shown = true } }
    function g.AuctionHouseFrame:GetHeight() return self.height end
    function g.AuctionHouseFrame:SetHeight() error('the auction window must never be resized') end
    function g.AuctionHouseFrame:IsShown() return self.shown end
    function g.AuctionHouseFrame:HookScript(name, fn) self.hooked = self.hooked or {}; self.hooked[name] = fn end
    g.addonChildren = {}
    g.CreateFrame = function(_, _, parent)
        local child = frame()
        if parent == g.AuctionHouseFrame then g.addonChildren[#g.addonChildren + 1] = child end
        return child
    end
    g.hooksecurefunc = function(object, name, fn)
        local original = object[name]
        object[name] = function(...) original(...); fn(...) end
    end
    g.searches, g.timers = {}, {}
    g.C_Timer = { After = function(_, fn) g.timers[#g.timers + 1] = fn end }
    g.C_AuctionHouse = {
        IsThrottledMessageSystemReady = function() return true end,
        SendSearchQuery = function(itemKey) g.searches[#g.searches + 1] = itemKey end,
        GetItemKeyFromItem = function(location) return { itemID = location.id } end,
        GetNumCommoditySearchResults = function() return 2 end,
        GetCommoditySearchResultInfo = function(_, i) return ({ { unitPrice = 5000, containsOwnerItem = false },
            { unitPrice = 6000, containsOwnerItem = false } })[i] end,
        GetNumItemSearchResults = function() return 1 end,
        GetItemSearchResultInfo = function() return { buyoutAmount = 20000, containsOwnerItem = false } end,
    }
    g.C_Item = { GetItemID = function(location) return location.id end }
    g.GetItemInfo = function() return 'n', nil, nil, nil, nil, nil, nil, nil, nil, nil, 100 end
    g.time = function() return 7 end
    g.dropdowns = {}
    return g
end

test('the client layer attaches once, searches on selection and fills the price', function()
    local g = client()
    for key, value in pairs(g) do _G[key] = value end
    local postings = {}
    local ns = load({ AuctionHistory = { UpdatePosting = function(sell, post, warning)
        postings[sell] = { post = post, warning = warning }
    end }, Nav = { Dropdown = function(_, _, _, _, options, get, set)
        g.dropdowns[#g.dropdowns + 1] = { options = options(), get = get, set = set }
        return {}
    end } })
    ns.settings = { auctionUndercutEnabled = true, auctionUndercutPreset = 10, auctionUndercutPercent = 10 }
    local U = ns.AuctionUndercut
    U.Initialize()
    eq(U.frame.events, 3)
    U.instance = U.instance
    eq(U.Attach(), true); eq(U.Attach(), true)
    eq(U.strip.shown, true); eq(#g.addonChildren, 1)
    -- The strip follows the Sell forms: hidden when none is shown (Buy and Auctions tabs).
    local forms = _G.AuctionHouseFrame
    forms.CommoditiesSellFrame.shown, forms.ItemSellFrame.shown = false, false
    forms.CommoditiesSellFrame.hooked.OnHide(); eq(U.strip.shown, false)
    forms.ItemSellFrame.shown = true
    forms.ItemSellFrame.hooked.OnShow(); eq(U.strip.shown, true)
    forms.CommoditiesSellFrame.shown = true
    eq(#g.dropdowns, 1)
    eq(#g.dropdowns[1].options, 4)                 -- 2, 5, 10, 15: no custom value
    eq(g.dropdowns[1].options[4].value, 15)
    -- Choosing a preset stores the percent; choosing custom keeps it for the text field.
    g.dropdowns[1].set(15); eq(ns.settings.auctionUndercutPercent, 15); eq(ns.settings.auctionUndercutPreset, 15)
    g.dropdowns[1].set(10)
    U.instance:Refill()      -- nothing selected yet: no effect
    -- Selecting an item in the commodities form sends one search; the answer fills the price input.
    local sell = _G.AuctionHouseFrame.CommoditiesSellFrame
    sell:SetItem({ id = 2589 })
    eq(#g.searches, 1); eq(g.searches[1].itemID, 2589)
    U.frame.scripts.OnEvent(U.frame, 'COMMODITY_SEARCH_RESULTS_UPDATED', 2589)
    eq(sell.PriceInput.amount, 4500)
    eq(#ns.db.auctionUndercutLog, 1); eq(ns.db.auctionUndercutLog[1].input, 'PriceInput')
    -- The fill also shows the posting lines: 4 units at 4500 each, deposit 30, vendor 100.
    eq(U.head.text, '<gold>AH sold: <white>17100c<gold>  Vendor: <white>400c')
    eq(postings[sell].post.gain, 16700); eq(postings[sell].post.loss, 30)
    ns.Economy.UnitCost = function() return 20 end             -- a known cost is shown as the profit against it
    sell:UpdateDeposit()
    eq(postings[sell].post.profit, 17020)
    ns.Economy.UnitCost = function() error('boom') end         -- an error while reading it only drops the figure
    sell:UpdateDeposit(); eq(postings[sell].post.gain, 16700); eq(postings[sell].post.profit, nil)
    ns.Economy.UnitCost = function() return nil end
    -- The client puts its own default price back after our fill: the check after a moment restores ours.
    sell.PriceInput.amount = 5000
    g.timers[#g.timers](); eq(sell.PriceInput.amount, 4500)
    eq(ns.db.auctionUndercutLog[1].readback, 5000); eq(ns.db.auctionUndercutLog[1].reapplied, true)
    -- Changing the percentage in the combo box prices the selected item again.
    g.dropdowns[1].set(15); eq(sell.PriceInput.amount, 4250)
    g.dropdowns[1].set(10); eq(sell.PriceInput.amount, 4500)
    -- The deposit the client asks is logged on every update of its form, once per different reading.
    sell:SetItem({ id = 2589 })
    sell:UpdateDeposit(); sell:UpdateDeposit()
    local deposits = ns.db.auctionDepositLog
    eq(#deposits, 1); eq(deposits[1].deposit, 30); eq(deposits[1].quantity, 4); eq(deposits[1].duration, 3)
    eq(deposits[1].itemID, 2589); eq(deposits[1].form, 'commodity'); eq(deposits[1].vendor, 100); eq(deposits[1].total, 18000)
    sell.quantity = 8; sell.deposit = 60; sell:UpdateDeposit()
    eq(#deposits, 2); eq(deposits[2].deposit, 60); eq(deposits[2].quantity, 8)
    eq(postings[sell].post.loss, 60)
    sell.PriceInput.MoneyInputFrame.GoldBox.hooked.OnTextChanged(nil, false)      -- a change of the price refreshes them too
    sell.deposit = nil; sell:UpdateDeposit(); eq(#deposits, 2)               -- an unknown deposit is not logged
    for i = 1, 40 do sell.deposit = 100 + i; sell:UpdateDeposit() end
    eq(#deposits, 30)
    -- A typed price stops the fill for the next answer of the same selection; the fill itself does not count as typing.
    local logged = #ns.db.auctionUndercutLog
    sell:SetItem({ id = 2592 })
    sell.PriceInput.MoneyInputFrame.GoldBox.hooked.OnTextChanged(nil, true)
    U.frame.scripts.OnEvent(U.frame, 'COMMODITY_SEARCH_RESULTS_UPDATED', 2592)
    eq(#ns.db.auctionUndercutLog, logged)
    -- The form of single items: the buyout goes into the secondary input when it is shown.
    local single = _G.AuctionHouseFrame.ItemSellFrame
    single.BuyoutModeCheckButton = {}
    single:SetItem({ id = 5 })
    -- The auction window keeps its native size, with only the Undercut strip attached by this module.
    local ah = _G.AuctionHouseFrame
    forms.ItemSellFrame.shown, forms.CommoditiesSellFrame.shown = false, false
    forms.ItemSellFrame.hooked.OnHide(); eq(U.strip.shown, false); eq(ah.height, 538)
    forms.ItemSellFrame.shown = true; forms.ItemSellFrame.hooked.OnShow(); eq(U.strip.shown, true); eq(ah.height, 538)
    -- The row keeps its place inside the window, a little higher on the commodity form.
    eq(U.strip.point[4], 32); eq(U.strip.point[5], 78)
    forms.ItemSellFrame.shown, forms.CommoditiesSellFrame.shown = false, true
    forms.CommoditiesSellFrame.hooked.OnShow(); eq(U.strip.point[5], 85); eq(U.strip.point[2], ah)
    eq(#g.addonChildren, 1)
    forms.ItemSellFrame.shown, forms.CommoditiesSellFrame.shown = true, false
    forms.ItemSellFrame.hooked.OnShow(); eq(U.strip.point[5], 78)
    U.frame.scripts.OnEvent(U.frame, 'ITEM_SEARCH_RESULTS_UPDATED', { itemID = 5 })
    eq(single.SecondaryPriceInput.amount, 18000)
    U.instance:Results(U.instance.key, { { price = 100 } })
    eq(single.SecondaryPriceInput.amount, 105)
    eq(postings[single].warning, '<red>Vendor floor applied: <white>105c')
    single.SecondaryPriceInput.MoneyInputFrame.CopperBox.hooked.OnTextChanged(nil, true)
    eq(postings[single].warning, nil)
    -- Answers for another item are ignored.
    single:SetItem({ id = 6 })
    local before = #ns.db.auctionUndercutLog
    U.frame.scripts.OnEvent(U.frame, 'ITEM_SEARCH_RESULTS_UPDATED', { itemID = 5 })
    eq(#ns.db.auctionUndercutLog, before)
    ns.settings.auctionUndercutEnabled = false
    single.SecondaryPriceInput.amount = 150
    single:SetItem({ id = 7 })
    eq(U.instance.key, nil)
    eq(postings[single].post.gain, 170)
    for key in pairs(g) do _G[key] = nil end
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS auction undercut ' .. #tests .. ' checks')
