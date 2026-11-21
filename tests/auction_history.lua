local ns = { settings = {}, IsPublic = function() return true end }
local function load(name) assert(loadfile('TitanGatheredForever/' .. name .. '.lua'))('TitanGatheredForever', ns) end
local function eq(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local day = 86400
local now = 20 * day + 3600
_G.time, _G.date = function() return now end, os.date
_G.GetRealmName = function() return 'Forever' end
load('Style')
load('AuctionScan')
load('Economy')
load('AuctionUndercut')
load('AuctionHistory')
local History = ns.AuctionHistory
local ore, gear = 2770, 1234

local function snapshot(at, minimum)
    return { at = at, items = { [ore] = { min = minimum } }, others = { [gear] = 22002 } }
end

-- The live scan writer preserves a compatible previous snapshot and keeps the last result for each day.
ns.db = { auction = snapshot(now - 2 * day, 8000) }
ns.db.auction.realm = 'Forever'
local scan = ns.AuctionScan.DefaultAPI()
local points, latest = History.Prices(ns.db, 'Forever', ore, now)
eq(#points, 1); eq(latest.price, 8000)
scan.Save(snapshot(now - day - 200, 8600))
scan.Save(snapshot(now - day, 9000))
scan.Save(snapshot(now, 9200))
points, latest = History.Prices(ns.db, 'Forever', ore, now)
eq(#points, 3); eq(points[1].price, 8000); eq(points[2].price, 9000); eq(latest.price, 9200)
points = History.Prices(ns.db, 'Forever', gear, now)
eq(points[1].price, 22)
points, latest = History.Prices(ns.db, 'Another realm', ore, now)
eq(#points, 0); eq(latest, nil)
points, latest = History.Prices(ns.db, 'Forever', ore, now + 8 * day)
eq(#points, 0); eq(latest.price, 9200)
scan.Save(snapshot(now + 8 * day, 7500))
assert(next(ns.db.auctionHistory) == nil, 'expired snapshots should be pruned from storage')
ns.AuctionScan.Clear()
points, latest = History.Prices(ns.db, 'Forever', ore, now + 8 * day)
eq(#points, 0); eq(latest, nil)

-- A newer scan without stock leaves a missing observation. It cannot become a zero-price point.
ns.db = {}
scan.Save(snapshot(now - day, 7000))
scan.Save({ at = now, items = {}, others = {} })
points, latest = History.Prices(ns.db, 'Forever', ore, now)
eq(#points, 1); eq(latest.price, 7000)

local function sale(age, count, buyout, itemID, realm)
    return { soldAt = now - age * day, realm = realm or 'Forever', itemID = itemID or ore,
        itemName = 'Copper Ore', received = 999999, count = count, buyout = buyout, source = buyout and 'invoice' or 'header' }
end
local entries = {
    sale(3, 10, 10000), sale(4, 30, 15000), sale(2, 2), sale(1, nil, 100), sale(31, 99, 100),
    sale(0, 99, 100, gear), sale(0, 99, 100, ore, 'Another realm'),
}
local summary = History.Sales(entries, 'Forever', ore, now)
eq(summary.sales, 4); eq(summary.knownUnits, 42); eq(summary.completeQuantity, false)
eq(summary.average, 625); eq(summary.pricedSales, 2)
eq(summary.last.at, now - day); eq(summary.last.price, nil)
summary = History.Sales({ sale(1, nil) }, 'Forever', ore, now)
eq(summary.knownUnits, 0); eq(summary.completeQuantity, false); eq(summary.average, nil)

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
ns.db.sales = { entries = entries }
local view = assert(History.Attach(ah))
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
item:Show()
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
item:SetItem(location(gear))
assert(view.panel:IsVisible() and not view.toggle:IsVisible())
eq(view.panel.anchor[1], 'TOPRIGHT')
eq(view.item.text, ns.Style.Value('Test Gear'))
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
commodity:SetItem(location(ore))
assert(not view.panel:IsVisible() and view.toggle:IsVisible())
view.toggle.scripts.OnClick()
eq(view.item.text, ns.Style.Value('Copper Ore'))
assert(view.panel:IsVisible() and not view.toggle:IsVisible())
assert(view.posting[1].text:find('1144c', 1, true))
assert(view.posting[2].text:find('15c', 1, true))
assert(view.posting[3].text:find('2%', 1, true))
commodity.price = 100
History.UpdatePosting(commodity, ns.AuctionUndercut.Posting(commodity))
assert(view.posting[1].text:find('1600c', 1, true))
History.UpdatePosting(item, nil)
assert(view.posting[1].text:find('1600c', 1, true), 'the hidden item form cannot replace the commodity figures')
History.UpdatePosting(commodity, ns.AuctionUndercut.Posting(commodity), ns.Style.Label('Vendor floor applied'))
assert(view.posting[4].text:find('Vendor floor applied', 1, true))
History.UpdatePosting(commodity, ns.AuctionUndercut.Posting(commodity))
assert(not view.posting[4]:IsVisible())
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
ah.left = 360
view.panel.scripts.OnUpdate(view.panel, 1)
eq(view.panel.anchor[1], 'TOPRIGHT')
commodity:Hide()
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
commodity:Show()
ah:Hide()
assert(not view.panel:IsVisible() and not view.toggle:IsVisible())
print('PASS auction market history scan, sales and Sell panel checks')
