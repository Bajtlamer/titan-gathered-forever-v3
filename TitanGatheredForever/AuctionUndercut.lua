local _, ns = ...
-- Fills the Buyout price of a new auction in the Sell tab of the auction house: the lowest existing buyout of the same
-- item minus a percentage chosen in a combo box (2, 5, 10, 15 percent or a custom value). The search is live, one query
-- per selected item (plans/plan-auction-undercut.md). Pure logic is behind a replaceable api table; the client wiring
-- follows it. Own auctions are ignored and the price never goes below what a vendor pays.
local Undercut = {}
Undercut.__index = Undercut
ns.AuctionUndercut = Undercut

Undercut.MIN, Undercut.MAX = 0.1, 90

-- "2,5" or "2.5" to 2.5, limited to MIN through MAX with one decimal; nil for anything else.
function Undercut.ParsePercent(text)
    if type(text) ~= 'string' then return nil end
    local trimmed = text:gsub('^%s+', ''):gsub('%s+$', ''):gsub(',', '.')
    local number = tonumber(trimmed)
    if not number then return nil end
    number = math.floor(number * 10 + 0.5) / 10
    if number < Undercut.MIN or number > Undercut.MAX then return nil end
    return number
end

-- Price in copper, or nil and 'vendor' when it would fall below what a vendor pays.
function Undercut.Price(lowest, percent, vendor)
    local price = math.max(1, math.floor(lowest * (1 - percent / 100)))
    if vendor and vendor > 0 and price < vendor then return nil, 'vendor' end
    return price
end

function Undercut.New(api)
    return setmetatable({ api = api }, Undercut)
end

-- An item was chosen in the Sell form. key identifies the item for the search and for the answer.
function Undercut:Select(key)
    self.key, self.edited, self.last = key, false, nil
    if self.api.Warn then self.api.Warn(nil) end
    local enabled, ready = self.api.Enabled(), self.api.Ready()
    if not enabled then self.key = nil; return end
    -- The client searches by itself when an item is chosen in the Sell form, so a busy message queue is no reason to
    -- give up: its answer is used. Only a free queue gets a search of our own.
    if ready then self.api.Search(key) end
end

-- The player typed a price: the fill leaves this selection alone.
function Undercut:Edited() self.edited = true end

-- The percentage was changed: price the selected item again from the last answer, also over a typed price, because
-- the player has just asked for another percentage.
function Undercut:Refill()
    if not self.key or not self.last or not self.api.Enabled() then return end
    self.edited = false
    self:Results(self.key, self.last)
end

-- The search answer: a list of { price = copper per unit (or buyout), own = true for the player's auctions }.
function Undercut:Results(key, list)
    if key ~= self.key then return end
    self.last = list                       -- kept so a change of the percentage can price the same answer again
    if self.edited then return end
    local lowest
    for _, entry in ipairs(list) do
        if not entry.own and entry.price and entry.price > 0 and (not lowest or entry.price < lowest) then lowest = entry.price end
    end
    local vendor
    if lowest then
        local ok, value = pcall(self.api.Vendor, key)      -- an unknown vendor price must never stop the fill
        vendor = ok and value or nil
    end
    if not lowest then self.api.Say('No other auction of this item: set the Buyout yourself.'); return end
    local percent = self.api.Percent()
    local price, reason = Undercut.Price(lowest, percent, vendor)
    if self.api.Warn then self.api.Warn(nil) end
    if not price then
        -- The percentage would go below what a vendor pays: the Buyout is set to the vendor price and the player is told.
        price = vendor
        if self.api.Warn then self.api.Warn(reason, vendor) end
        self.api.Say('The percentage would go below the vendor price: Buyout set to the vendor price.')
    end
    self.api.SetBuyout(price, lowest, percent)
end

-- The real client.
function Undercut.DefaultAPI()
    local api = {}
    api.Enabled = function() return ns.settings.auctionUndercutEnabled == true end
    api.Percent = function() return ns.settings.auctionUndercutPercent end
    api.Ready = function()
        local ok, value = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        return not ok or value ~= false
    end
    api.Search = function(key) pcall(C_AuctionHouse.SendSearchQuery, key.itemKey, {}, true) end
    api.Vendor = function(key) return ns.Economy and ns.Economy.VendorSell(key.itemKey.itemID) or nil end
    api.SetBuyout = function(copper, lowest, percent)
        local input = Undercut.BuyoutInput(Undercut.sellFrame)
        if not input then return end
        local function put()
            Undercut.filling = true
            pcall(input.SetAmount, input, copper)
            Undercut.filling = false
        end
        put()
        local entry = { at = time(), copper = copper, lowest = lowest, percent = percent,
            input = input == Undercut.sellFrame.PriceInput and 'PriceInput' or 'SecondaryPriceInput',
            label = type(input.labelText) == 'string' and input.labelText or nil }
        local log = ns.db and ns.db.auctionUndercutLog
        if log then
            log[#log + 1] = entry
            while #log > 20 do table.remove(log, 1) end
        end
        -- The client sets its own default price when the same answer arrives; look again shortly and put ours back.
        local key = Undercut.instance and Undercut.instance.key
        if C_Timer and C_Timer.After then
            C_Timer.After(0.4, function()
                local current = Undercut.instance
                if not current or current.key ~= key or current.edited or not input.GetAmount then return end
                local ok, amount = pcall(input.GetAmount, input)
                entry.readback = ok and amount or nil
                Undercut.LogDeposit(Undercut.sellFrame)
                if ok and amount ~= copper then entry.reapplied = true; put() end
            end)
        end
        ns.Print(ns.Style.Label('Buyout set to ') .. ns.Economy.Coin(copper) .. ns.Style.Label(string.format(' (%s%% under the lowest, ', tostring(percent)))
            .. ns.Economy.Coin(lowest) .. ns.Style.Label(').'))
    end
    api.Say = function(message) ns.Print(ns.Style.Label(message)) end
    -- The red line above the strip: shown while the Buyout rests on the vendor price, cleared at the next fill.
    api.Warn = function(reason, vendor)
        local line = Undercut.warning
        if not line then return end
        if reason == 'vendor' and vendor then
            line:SetText(ns.Style.Text(ns.Style.red, 'Below the vendor price: Buyout set to ') .. ns.Economy.Coin(vendor))
            line:Show()
        else
            line:SetText('')
            line:Hide()
        end
    end
    return api
end

-- The price input that holds the Buyout. In the form of single items a second input is used for the Buyout when it
-- is enabled and the first one is the starting bid; the form of commodities has one price input.
function Undercut.BuyoutInput(sell)
    if not sell then return nil end
    local second = sell.SecondaryPriceInput
    if second and second.SetAmount and sell.BuyoutModeCheckButton and second.IsShown and second:IsShown() then return second end
    return sell.PriceInput
end

-- Evidence for the posting cost (plans/plan-auction-undercut.md): what the client asks as deposit for the form as it
-- stands now, with the quantity, duration and prices it belongs to. The last 30 different readings are kept in
-- ns.db.auctionDepositLog, to learn from the saved variables whether the deposit is for one unit or for the whole
-- auction, how it follows the duration and what the vendor price has to do with it. Nothing is shown from it yet.
local function read(sell, name)
    if type(sell[name]) ~= 'function' then return nil end
    local ok, value = pcall(sell[name], sell)
    if ok then return value end
    return nil
end

function Undercut.LogDeposit(sell)
    local log = ns.db and ns.db.auctionDepositLog
    if not log or not sell then return end
    local deposit = read(sell, 'GetDepositAmount')
    if type(deposit) ~= 'number' then return end
    local key = Undercut.instance and Undercut.instance.key
    local itemID = key and key.itemKey and key.itemKey.itemID
    local vendor = itemID and ns.Economy and ns.Economy.VendorSell(itemID) or nil
    local entry = { at = time(), form = (key and key.commodity) and 'commodity' or 'item', itemID = itemID,
        deposit = deposit, duration = read(sell, 'GetDuration'), quantity = read(sell, 'GetQuantity'),
        price = read(sell, 'GetPrice'), total = read(sell, 'GetTotalPrice'), vendor = vendor }
    local last = log[#log]
    if last and last.itemID == entry.itemID and last.deposit == deposit and last.duration == entry.duration
        and last.quantity == entry.quantity and last.price == entry.price then return end
    log[#log + 1] = entry
    while #log > 30 do table.remove(log, 1) end
end

local function keyOf(sell, itemLocation)
    if not itemLocation or not C_AuctionHouse.GetItemKeyFromItem then return nil end
    local ok, itemKey = pcall(C_AuctionHouse.GetItemKeyFromItem, itemLocation)
    if not ok or type(itemKey) ~= 'table' then return nil end
    return { itemKey = itemKey, commodity = sell == _G.AuctionHouseFrame.CommoditiesSellFrame }
end

-- The strip under the Sell form: label, combo box and the field for a custom percentage.
function Undercut.Attach()
    if Undercut.strip then return true end
    local frame = _G.AuctionHouseFrame
    if not frame or not frame.CommoditiesSellFrame or not frame.ItemSellFrame then return false end
    local strip = CreateFrame('Frame', nil, frame)
    Undercut.strip = strip
    strip:SetSize(220, 24)
    -- Inside the left panel, at the bottom of the left panel, in the row above the Buyout Mode check box (the position of the Create Auction button changes between the forms, this row is free in both), and only while a Sell form is shown.
    strip:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 110, 78)
    if strip.SetFrameLevel and frame.GetFrameLevel then strip:SetFrameLevel(frame:GetFrameLevel() + 20) end
    local label = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    label:SetPoint('LEFT', 0, 0)
    label:SetText('Undercut')
    local options = {
        { value = 2, label = '2 %' }, { value = 5, label = '5 %' }, { value = 10, label = '10 %' },
        { value = 15, label = '15 %' }, { value = 'custom', label = 'Custom' },
    }
    local warning = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    warning:SetPoint('BOTTOMLEFT', strip, 'TOPLEFT', 0, 2)
    warning:Hide()
    Undercut.warning = warning
    local box = CreateFrame('EditBox', nil, strip, 'InputBoxTemplate')
    box:SetSize(44, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5)
    box:SetPoint('LEFT', strip, 'LEFT', 172, 0)
    local function sync() box:SetShown(ns.settings.auctionUndercutPreset == 'custom') end
    Undercut.drop = ns.Nav.Dropdown(strip, 56, 0, 105, function() return options end,
        function() return ns.settings.auctionUndercutPreset end,
        function(value)
            ns.settings.auctionUndercutPreset = value
            if value ~= 'custom' then ns.settings.auctionUndercutPercent = value end
            box:SetText(tostring(ns.settings.auctionUndercutPercent))
            sync()
            Undercut.instance:Refill()
        end)
    local function commit(self)
        local value = Undercut.ParsePercent(self:GetText())
        local changed = value and value ~= ns.settings.auctionUndercutPercent
        if value then ns.settings.auctionUndercutPercent = value end
        self:SetText(tostring(ns.settings.auctionUndercutPercent))
        self:ClearFocus()
        if changed then Undercut.instance:Refill() end
    end
    box:SetScript('OnEnterPressed', commit)
    box:SetScript('OnEditFocusLost', commit)
    box:SetScript('OnEscapePressed', function(self)
        self:SetText(tostring(ns.settings.auctionUndercutPercent)); self:ClearFocus()
    end)
    box:SetText(tostring(ns.settings.auctionUndercutPercent))
    sync()
    Undercut.box = box

    local function refresh()
        local shown = false
        for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
            if sell.IsShown and sell:IsShown() then shown = true end
        end
        strip:SetShown(shown)
    end
    for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
        if sell.HookScript then
            sell:HookScript('OnShow', refresh)
            sell:HookScript('OnHide', refresh)
        end
        hooksecurefunc(sell, 'SetItem', function(self, itemLocation)
            Undercut.sellFrame = self
            local key = keyOf(self, itemLocation)
            if key then Undercut.instance:Select(key) else Undercut.instance.key = nil end
        end)
        -- The client works out its deposit again whenever the quantity, duration or price changes: read it then.
        if type(sell.UpdateDeposit) == 'function' then
            hooksecurefunc(sell, 'UpdateDeposit', function(self) Undercut.LogDeposit(self) end)
        end
        -- A typed price (userInput) stops the fill. HookScript keeps the handlers of the client, whose own value callback
        -- of the price inputs (deposit, post button) must not be replaced.
        for _, name in ipairs({ 'PriceInput', 'SecondaryPriceInput' }) do
            local money = sell[name] and sell[name].MoneyInputFrame
            for _, box in ipairs({ money and money.GoldBox, money and money.SilverBox, money and money.CopperBox }) do
                if box and box.HookScript then
                    box:HookScript('OnTextChanged', function(_, userInput)
                        if userInput and not Undercut.filling then Undercut.instance:Edited() end
                    end)
                end
            end
        end
    end
    refresh()
    return true
end

function Undercut.Initialize()
    if Undercut.frame then return end
    Undercut.instance = Undercut.New(Undercut.DefaultAPI())
    if ns.db and type(ns.db.auctionUndercutLog) ~= 'table' then ns.db.auctionUndercutLog = {} end
    if ns.db and type(ns.db.auctionDepositLog) ~= 'table' then ns.db.auctionDepositLog = {} end
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
        elseif event == 'ITEM_SEARCH_RESULTS_UPDATED' and not key.commodity and type(arg) == 'table' and arg.itemID == key.itemKey.itemID then
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
