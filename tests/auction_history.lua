local ns = { settings = {}, IsPublic = function() return true end }
local function load(name) assert(loadfile('TitanGatheredForever/' .. name .. '.lua'))('TitanGatheredForever', ns) end
local function eq(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local day = 86400
local now = 20 * day + 3600
_G.time, _G.date = function() return now end, os.date
_G.GetRealmName = function() return 'Forever' end
_G.UnitName = function() return 'Seller' end
load('Style')
load('AuctionScan')
load('Economy')
load('Sales')
load('AuctionUndercut')
load('AuctionHistory')
local History = ns.AuctionHistory
local ore, gear = 2770, 1234

local function snapshot(at, minimum)
    return { at = at, items = { [ore] = { min = minimum } }, others = { [gear] = 22002 } }
end

-- The scan is one snapshot: the lowest buyout of the last scan. No daily history of scans is kept (it would be a large
-- file), so a scan never writes an archive and an old one is dropped.
ns.db = { auction = snapshot(now - 2 * day, 8000), auctionHistory = { Forever = { [18] = { at = 1, prices = {} } } } }
ns.db.auction.realm = 'Forever'
local scan = ns.AuctionScan.DefaultAPI()
local latest, reason = History.ScanPrice(ns.db, 'Forever', ore, now)
eq(latest.price, 8000); eq(reason, nil)
eq(History.ScanPrice(ns.db, 'Forever', gear, now).price, 22)                -- a packed item outside the catalogue
latest, reason = History.ScanPrice(ns.db, 'Forever', 555, now)
eq(latest, nil); eq(reason, 'missing')                                     -- scanned, but the item is not in the scan
latest, reason = History.ScanPrice(ns.db, 'Another realm', ore, now)
eq(latest, nil); eq(reason, 'noscan')                                      -- no scan of this realm
latest, reason = History.ScanPrice({}, 'Forever', ore, now)
eq(latest, nil); eq(reason, 'noscan')
scan.Save(snapshot(now - day, 9000))
scan.Save(snapshot(now, 9200))
eq(ns.db.auctionHistory, nil)                                              -- no archive of scans, the old one is dropped
eq(History.ScanPrice(ns.db, 'Forever', ore, now).price, 9200)
ns.AuctionScan.Clear()
latest, reason = History.ScanPrice(ns.db, 'Forever', ore, now)
eq(latest, nil); eq(reason, 'noscan')

-- A newer scan without stock leaves the item missing. It cannot become a zero-price point.
ns.db = {}
scan.Save(snapshot(now - day, 7000))
scan.Save({ at = now, items = {}, others = {} })
latest, reason = History.ScanPrice(ns.db, 'Forever', ore, now)
eq(latest, nil); eq(reason, 'missing')

local function sale(age, count, buyout, itemID, realm)
    local fee = buyout and math.floor(buyout * 0.05)
    return { soldAt = now - age * day, realm = realm or 'Forever', itemID = itemID or ore, character = 'Seller',
        itemName = 'Copper Ore', received = buyout and buyout - fee + 20 or 98, count = count,
        bid = buyout, buyout = buyout, fee = fee, deposit = 20, source = buyout and 'invoice' or 'header' }
end
local entries = {
    sale(3, 10, 10000), sale(4, 30, 15000), sale(2, 2), sale(1, nil, 100), sale(31, 99, 100),
    sale(0, 99, 100, gear), sale(0, 99, 100, ore, 'Another realm'),
}
local summary = History.Sales(entries, 'Forever', ore, now)
eq(summary.sales, 3); eq(summary.knownUnits, 40); eq(summary.completeQuantity, false)
eq(summary.average, 625); eq(summary.pricedSales, 2)
eq(summary.averageNet, 593.75); eq(summary.netSales, 2)
eq(summary.received, 23905)
eq(summary.last.at, now - day); eq(summary.last.price, nil)
summary = History.Sales({ sale(1, nil, 100) }, 'Forever', ore, now)
eq(summary.knownUnits, 0); eq(summary.completeQuantity, false); eq(summary.average, nil)
summary = History.Sales({ sale(1, 200) }, 'Forever', ore, now)
eq(summary.sales, 0); eq(summary.received, nil)

local otherSeller = sale(1, 1, 100)
otherSeller.character = 'Alt'
local unreconciled = sale(1, 1, 100)
unreconciled.received = 1
summary = History.Sales({ sale(2, 1, 100), sale(2, 3, 600), sale(1, 2, 600), otherSeller, unreconciled },
    'Forever', ore, now, 'Seller')
eq(#summary.points, 2)
eq(summary.points[1].price, 166.25)
eq(summary.points[2].price, 285)

-- The best sale of an item (the highest net price per unit the player ever got) is kept apart from the ledger, which is
-- bounded, and covers every day, not only the last 30. Only the player's own sales count, never the auction house.
local store2 = { entries = { sale(3, 10, 10000), sale(60, 1, 5000), sale(4, 30, 15000), sale(1, 2, 100, gear),
    sale(2, 1, 9000, ore, 'Another realm') } }
ns.Sales.UpdateBest(store2)
local best = History.BestSale(store2, 'Forever', ore)
eq(best.price, 4750); eq(best.units, 1); eq(best.at, now - 60 * day)
eq(History.BestSale(store2, 'Another realm', ore).price, 8550)
eq(History.BestSale(store2, 'Forever', 987654), nil)
store2.entries = {}                                  -- the ledger forgets, the best sale does not
eq(History.BestSale(store2, 'Forever', ore).price, 4750)
store2.entries = { sale(1, 1, 20000) }               -- a better sale replaces it, a worse one never does
ns.Sales.UpdateBest(store2, 'Forever', ore)
eq(History.BestSale(store2, 'Forever', ore).price, 19000)
store2.entries = { sale(1, 1, 100) }
ns.Sales.UpdateBest(store2)
eq(History.BestSale(store2, 'Forever', ore).price, 19000)

-- A real ledger pass carries the confirmed invoice values through to the selected item's comparison basis.
local store = {}
local ledger = ns.Sales.New({
    Count = function() return 2 end,
    Header = function(i)
        return { subject = 'Auction successful: Copper Ore', money = i == 1 and 430 or 500, days = 29 }
    end,
    Invoice = function(i)
        if i == 1 then return { 'seller', 'Copper Ore', nil, 440, 900, 12, 22, nil, nil, nil, 5 } end
        return { 'seller_temp_invoice', 'Copper Ore' }
    end,
    ItemID = function() return ore end,
    Now = function() return now end,
    Character = function() return 'Seller' end,
    Realm = GetRealmName,
}, store)
eq(ledger:Scan(), 1)
summary = History.Sales(store.entries, 'Forever', ore, now)
eq(summary.knownUnits, 5); eq(summary.received, 430)
eq(summary.average, 88); eq(summary.averageNet, 83.6)

-- The UI uses the actual displayed item, including when the client rejects a SetItem request.
local function frame(parent)
    local f = { parent = parent, shown = true, scripts = {} }
    for _, method in ipairs({ 'SetPoint', 'SetAllPoints', 'SetClampedToScreen', 'SetFrameLevel', 'SetSize',
        'SetBackdrop', 'SetBackdropColor', 'SetBackdropBorderColor', 'EnableMouse', 'SetJustifyH', 'SetWordWrap',
        'SetColorTexture', 'SetStartPoint', 'SetEndPoint', 'SetThickness', 'SetWidth', 'SetHeight', 'RegisterEvent' }) do
        f[method] = function() end
    end
    function f:SetText(value) self.text = value end
    function f:SetShown(shown)
        if shown == self.shown then return end
        self.shown = shown
        local hook = self.scripts[shown and 'OnShow' or 'OnHide']
        if hook then hook(self) end
    end
    function f:Hide() self:SetShown(false) end
    function f:Show() self:SetShown(true) end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:GetFrameLevel() return 1 end
    function f:GetEffectiveScale() return 1 end
    function f:GetLeft() return self.left or 0 end
    function f:ClearAllPoints() self.anchor = nil end
    function f:SetPoint(point, _, relative, x, y) self.anchor = { point, relative, x, y } end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    f.HookScript = f.SetScript
    function f:CreateFontString() return frame(self) end
    f.CreateTexture, f.CreateLine = f.CreateFontString, f.CreateFontString
    return f
end
_G.UIParent = frame()
_G.AuctionHouseFrame = frame(UIParent)
local ah = AuctionHouseFrame
ah.left = 360
ah.ItemSellFrame, ah.CommoditiesSellFrame = frame(ah), frame(ah)
local item, commodity = ah.ItemSellFrame, ah.CommoditiesSellFrame
for _, form in ipairs({ item, commodity }) do
    form:Hide()
    function form:GetItem() return self.selected end
    function form:SetItem(location)
        if location and location.rejected then return end
        self.selected = location
    end
    form.PriceInput = { GetAmount = function() return form.price end }
    function form:GetQuantity() return 20 end
    function form:GetDepositAmount() return 15 end
end
_G.CreateFrame = function(_, _, parent) return frame(parent) end
_G.hooksecurefunc = function(target, method, hook)
    local old = target[method]
    target[method] = function(self, ...) old(self, ...); hook(self, ...) end
end
_G.C_Item = { GetItemID = function(location) return location.id end }
ns.Economy.VendorSell = function() return 15 end
ns.ItemName = function(id) return id == ore and 'Copper Ore' or 'Test Gear' end
local function location(id) return { id = id, IsValid = function(self) return not self.invalid end } end
ns.db.sales = { entries = {} }                     -- no sale of anything at first
ns.db.auction = nil                                -- and no scan yet
local view = assert(History.Attach(ah))
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
item:Show()
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
item:SetItem(location(gear))
assert(view.panel:IsVisible() and not view.toggle:IsVisible())
eq(view.panel.anchor[1], 'TOPRIGHT')
eq(view.item.text, ns.Style.Value('Test Gear'))
eq(view.chartTitle.text, ns.Style.Label('Last scan buyout / unit'))
assert(view.chart.note.text:find('No scan yet', 1, true), view.chart.note.text)                 -- never scanned
assert(view.chart.note.shown ~= false)
assert(view.posting[1].text:find('Enter a buyout', 1, true))
item:SetItem({ id = ore, rejected = true })
eq(view.item.text, ns.Style.Value('Test Gear'))
view.hide.scripts.OnClick()
assert(not view.panel:IsVisible() and view.toggle:IsVisible())
eq(view.toggle.anchor[3], 200)
eq(view.toggle.anchor[4], -40)
item:Hide()
commodity:Show()
commodity.price = 76
ns.db.sales.entries = entries
ns.db.auction = { realm = 'Forever', at = now, items = {}, others = { [gear] = 22002, [ore] = ns.AuctionScan.Pack(7000, 1) } }
commodity:SetItem(location(ore))
assert(not view.panel:IsVisible() and view.toggle:IsVisible())
view.toggle.scripts.OnClick()
eq(view.item.text, ns.Style.Value('Copper Ore'))
eq(view.chartTitle.text, ns.Style.Label('Your sales net / unit'))
assert(view.trend.text:find('+100.0%', 1, true))
local function has(part) for i = 1, #view.posting do if view.posting[i].shown ~= false and view.posting[i].text and view.posting[i].text:find(part, 1, true) then return true end end end
assert(view.panel:IsVisible() and not view.toggle:IsVisible())
assert(has('If sold, profit') and has('138556c'), 'the profit after the cost of one unit at the scan price')
assert(has('If unsold, loss') and has('15c'), 'a failed auction loses the deposit')
assert(has('does not cover the cost'))
assert(not has('Gain vs vendor') and not has('last scan') and not has('sales avg'), 'no comparison with other auctions')
assert(view.received.text:find('23905c', 1, true))
assert(view.averageNet.text:find('594c', 1, true))
commodity.price = 100
History.UpdatePosting(commodity, ns.AuctionUndercut.Posting(commodity))
assert(has('138100c'))
History.UpdatePosting(item, nil)
assert(has('138100c'), 'the hidden item form cannot replace the commodity figures')
History.UpdatePosting(commodity, ns.AuctionUndercut.Posting(commodity), ns.Style.Label('Vendor floor applied'))
assert(has('Vendor floor applied'))
History.UpdatePosting(commodity, ns.AuctionUndercut.Posting(commodity))
assert(not has('Vendor floor applied'))
commodity:SetItem(nil)
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
ah.left = 20
commodity:SetItem(location(ore))
assert(not view.panel:IsVisible() and view.toggle:IsVisible())
view.toggle.scripts.OnClick()
eq(view.panel.anchor[1], 'TOPLEFT')
assert(view.panel:IsVisible())
commodity:SetItem(nil)
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
commodity:SetItem(location(gear))
assert(view.panel:IsVisible(), 'a native clear-and-replace must restore the open overlay')
eq(view.item.text, ns.Style.Value('Test Gear'))
-- No sale of the item: the last scan gives one point, and the missing data is explained in words.
ns.db.sales.entries = {}
ns.db.auction = { realm = 'Forever', at = now - 3600, items = {}, others = { [gear] = 22002 } }
History.Refresh()
eq(view.chartTitle.text, ns.Style.Label('Last scan buyout / unit'))
eq(view.chart.dots[1].shown, true); eq(view.chart.dots[2].shown, false); eq(view.chart.note.shown, false)
assert(view.chart.high.text:find('22c', 1, true), view.chart.high.text)
eq(view.trend.text, '')
ns.db.auction = { realm = 'Forever', at = now - 3600, items = {}, others = {} }
History.Refresh()
eq(view.chart.dots[1].shown, false); assert(view.chart.note.text:find('not in the last scan', 1, true), view.chart.note.text)
ns.db.auction = nil
History.Refresh()
assert(view.chart.note.text:find('No scan yet', 1, true))
ns.db.sales.entries = { sale(3, 10, 10000, gear), sale(60, 1, 5000, gear) }
History.Refresh()
assert(view.best.text:find('4750c', 1, true), view.best.text)                      -- the best sale, though older than 30 days
ns.db.sales.entries = { sale(2, 5, 1000, gear) }
History.Refresh()
assert(view.best.text:find('4750c', 1, true), 'the best sale stays in the saved data after the ledger forgot it')
ns.db.sales.best = nil
ns.db.sales.entries = {}
-- One day of sales is already the player's own history: one point, no trend.
ns.db.sales.entries = { sale(2, 5, 1000, gear) }
History.Refresh()
eq(view.chartTitle.text, ns.Style.Label('Your sales net / unit'))
eq(view.chart.dots[1].shown, true); eq(view.chart.dots[2].shown, false); eq(view.trend.text, '')
ah.left = 360
view.panel.scripts.OnUpdate(view.panel, 1)
eq(view.panel.anchor[1], 'TOPRIGHT')
commodity:Hide()
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
commodity:Show()
ah:Hide()
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
print('PASS auction market history scan, sales and Sell panel checks')
