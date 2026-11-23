local _, ns = ...
-- Fills the Buyout price of a new auction in the Sell tab of the auction house: the lowest existing buyout of the same
-- item minus a percentage chosen in a combo box (2, 5, 10 or 15 percent). The search is live, one query
-- per selected item (plans/plan-auction-undercut.md). Pure logic is behind a replaceable api table; the client wiring
-- follows it. Own auctions are ignored and the price never goes below what a vendor pays.
local Undercut = {}
Undercut.__index = Undercut
ns.AuctionUndercut = Undercut

-- Price in copper, or nil and 'vendor' when it would fall below the floor: the lowest price at which a sale, after the
-- fee, still brings what a vendor pays (Economy.MinPrice).
function Undercut.Price(lowest, percent, floor)
    local price = math.max(1, math.floor(lowest * (1 - percent / 100)))
    if floor and floor > 0 and price < floor then return nil, 'vendor' end
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
    -- The floor counts the fee of the auction house: at the vendor price itself a sale would bring less than a vendor.
    local floor = vendor
    if vendor and self.api.Floor then
        local okFloor, value = pcall(self.api.Floor, vendor)
        floor = okFloor and value or vendor
    end
    local price, reason = Undercut.Price(lowest, percent, floor)
    if self.api.Warn then self.api.Warn(nil) end
    if not price then
        -- The percentage would go below what a vendor pays: the Buyout is set to the vendor price and the player is told.
        price = floor
        if self.api.Warn then self.api.Warn(reason, floor) end
        self.api.Say('The percentage would go below what a vendor pays after the fee: Buyout set to the lowest price that beats a vendor.')
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
    api.Floor = function(vendor) return ns.Economy.MinPrice(vendor) end
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
        Undercut.Refresh(Undercut.sellFrame)
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
                if ok and amount ~= copper then
                    entry.reapplied = true
                    put()
                    Undercut.Refresh(Undercut.sellFrame)
                end
            end)
        end
        ns.Print(ns.Style.Label('Buyout set to ') .. ns.Economy.Coin(copper) .. ns.Style.Label(string.format(' (%s%% under the lowest, ', tostring(percent)))
            .. ns.Economy.Coin(lowest) .. ns.Style.Label(').'))
    end
    api.Say = function(message) ns.Print(ns.Style.Label(message)) end
    -- Keep the warning for the current selection so it can also be drawn when Market history is opened.
    api.Warn = function(reason, floor)
        local Style = ns.Style
        Undercut.warning = reason == 'vendor' and floor
            and (Style.Text(Style.red, 'Vendor floor applied: ') .. Style.Value(ns.Economy.Coin(floor))) or nil
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
    if ok and ns.IsPublic(value) then return value end
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

-- A signed amount of coins: green with a plus, red with a minus.
local function signed(copper)
    local Style, Coin = ns.Style, ns.Economy.Coin
    return Style.Text(copper >= 0 and Style.green or Style.red, copper >= 0 and '+' or '-')
        .. Style.Value(Coin(math.abs(copper)))
end

-- The first line belongs beside Undercut. The other lines fit the narrow Market history panel.
function Undercut.InfoText(post)
    if not post then return '', '', '', '', '' end
    local Style, Coin = ns.Style, ns.Economy.Coin
    local head = Style.Label('AH sold: ') .. Style.Value(Coin(post.net))
    if post.vendor and post.vendor > 0 then
        head = head .. Style.Label('  Vendor: ') .. Style.Value(Coin(post.vendor * post.quantity))
    end
    local profit = post.profit and (Style.Label('Gain vs cost: ') .. signed(post.profit)) or ''
    local gain = post.gain and (Style.Label('Gain vs vendor: ') .. signed(post.gain)) or ''
    local loss = Style.Label('Unsold deposit: ') .. (post.loss and signed(-post.loss) or Style.Label('Unavailable'))
    local threshold = ''
    if post.needed == 'never' then
        threshold = Style.Text(Style.red, 'A sale does not beat a vendor')
    elseif post.needed then
        threshold = Style.Label('Break-even sales: ')
            .. Style.Value(string.format('%d%%', math.ceil(post.needed * 100 - 1e-9)))
    end
    return head, profit, gain, loss, threshold
end

-- The lines of the Current listing. When a sale does not beat the vendor, what the sale would bring is of no use (the
-- player should go to the vendor), so only the comparison and the loss of a failed auction are shown. Otherwise: what the
-- sale earns (the net after the fee; the deposit comes back), the comparison with the vendor when its price is known, what
-- a failed auction loses (the deposit) and the number of units that must sell to cover the deposit, or a red warning when
-- even a full sale gains less than the deposit (a cheap item: the risk is larger than the reward).
function Undercut.ListingLines(post)
    if not post then return '', '', '', '' end
    local Style, Coin = ns.Style, ns.Economy.Coin
    local worse = post.gain and post.gain <= 0
    local sold = worse and '' or (Style.Label('If sold, you earn: ') .. Style.Value(Coin(post.net)))
    local vendor = post.gain and (Style.Label('Auction vs vendor: ') .. signed(post.gain)
        .. (worse and Style.Text(Style.red, ' Vendor pays more') or '')) or ''
    local loss = post.loss and (Style.Label('If unsold, you lose: ') .. signed(-post.loss)) or ''
    local cover = ''
    if post.coverUnits and not worse then
        if post.coverUnits > post.quantity then
            -- Even when every unit sells the gain is smaller than the deposit that a failed auction loses.
            cover = Style.Text(Style.red, 'Not worth the risk: the gain is less than the deposit')
        elseif post.quantity == 1 then
            cover = Style.Label('To cover the deposit: ') .. Style.Value('the item must sell')
        elseif post.coverUnits >= post.quantity then
            cover = Style.Label('Units to cover the deposit: ') .. Style.Value('all ' .. post.quantity)
        else
            cover = Style.Label('Units to cover the deposit: ') .. Style.Value(post.coverUnits .. ' of ' .. post.quantity)
        end
    end
    return sold, vendor, loss, cover
end

local function readItemID(sell)
    local location = sell:GetItem()
    if ns.IsPublic(location) and location and location:IsValid() then
        local itemID = C_Item.GetItemID(location)
        if ns.IsPublic(itemID) and type(itemID) == 'number' and itemID > 0 then return itemID end
    end
end

function Undercut.SelectedItemID(sell)
    local ok, itemID = pcall(readItemID, sell)
    if ok then return itemID end
end

-- Valuation uses the form's actual selection, even when automatic fill is disabled.
function Undercut.Posting(sell, itemID)
    itemID = itemID or Undercut.SelectedItemID(sell)
    if not itemID then return end
    local input = Undercut.BuyoutInput(sell)
    local price = input and read(input, 'GetAmount')
    if type(price) ~= 'number' or price <= 0 then return end
    local quantity = read(sell, 'GetQuantity')
    local deposit = read(sell, 'GetDepositAmount')
    local vendor = ns.Economy.VendorSell(itemID)
    local okCost, cost = pcall(ns.Economy.UnitCost, itemID)
    local post = ns.Economy.Posting(price, quantity, type(deposit) == 'number' and deposit or nil, vendor, okCost and cost or nil)
    return post, Undercut.sellFrame == sell and Undercut.warning or nil
end

function Undercut.Refresh(sell)
    if not Undercut.head or not sell or not sell:IsShown() then return end
    Undercut.Place(sell)
    local post, warning = Undercut.Posting(sell)
    local head = Undercut.InfoText(post)
    Undercut.head:SetText(head)
    if ns.AuctionHistory then ns.AuctionHistory.UpdatePosting(sell, post, warning) end
end

local function keyOf(sell, itemLocation)
    if not itemLocation or not C_AuctionHouse.GetItemKeyFromItem then return nil end
    local ok, itemKey = pcall(C_AuctionHouse.GetItemKeyFromItem, itemLocation)
    if not ok or type(itemKey) ~= 'table' then return nil end
    return { itemKey = itemKey, commodity = sell == _G.AuctionHouseFrame.CommoditiesSellFrame }
end

-- The row sits in the free line above the Buyout Mode check box; the commodity form needs it a little higher.
function Undercut.Place(sell)
    local strip, frame = Undercut.strip, _G.AuctionHouseFrame
    if not strip or not frame or not sell then return end
    local commodity = sell == frame.CommoditiesSellFrame
    if Undercut.placedCommodity == commodity then return end
    Undercut.placedCommodity = commodity
    strip:ClearAllPoints()
    strip:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 32, commodity and 85 or 78)
end

function Undercut.Attach()
    if Undercut.strip then return true end
    local frame = _G.AuctionHouseFrame
    if not frame or not frame.CommoditiesSellFrame or not frame.ItemSellFrame then return false end
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or nil
    local strip = CreateFrame('Frame', nil, frame)
    Undercut.strip = strip
    strip:SetSize(400, 24)
    strip:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 32, 78)
    if strip.SetFrameLevel and level then strip:SetFrameLevel(level + 20) end
    local label = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    label:SetPoint('LEFT', 0, 0)
    label:SetText('Undercut')
    local options = {
        { value = 2, label = '2 %' }, { value = 5, label = '5 %' }, { value = 10, label = '10 %' }, { value = 15, label = '15 %' },
    }
    Undercut.drop = ns.Nav.Dropdown(strip, 54, 0, 64, function() return options end,
        function() return ns.settings.auctionUndercutPreset end,
        function(value)
            ns.settings.auctionUndercutPreset = value
            ns.settings.auctionUndercutPercent = value
            Undercut.instance:Refill()
        end)
    -- What a sale brings and what a vendor pays, right after the box.
    local head = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    head:SetPoint('LEFT', strip, 'LEFT', 128, 0)
    head:SetJustifyH('LEFT')
    Undercut.head = head
    local function refresh()
        local shown
        for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
            if sell.IsShown and sell:IsShown() then shown = shown or sell end
        end
        strip:SetShown(shown ~= nil)
        if shown then Undercut.Refresh(shown) end
    end
    for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
        if sell.HookScript then
            sell:HookScript('OnShow', function() refresh() end)
            sell:HookScript('OnHide', function() refresh() end)
        end
        hooksecurefunc(sell, 'SetItem', function(self, itemLocation)
            Undercut.sellFrame = self
            Undercut.warning = nil
            local key = keyOf(self, itemLocation)
            if key then Undercut.instance:Select(key) else Undercut.instance.key = nil end
            Undercut.Refresh(self)
        end)
        -- The client works out its deposit again whenever the quantity, duration or price changes: read it then.
        if type(sell.UpdateDeposit) == 'function' then
            hooksecurefunc(sell, 'UpdateDeposit', function(self) Undercut.LogDeposit(self); Undercut.Refresh(self) end)
        end
        -- A typed price (userInput) stops the fill. HookScript keeps the handlers of the client, whose own value callback
        -- of the price inputs (deposit, post button) must not be replaced.
        for _, name in ipairs({ 'PriceInput', 'SecondaryPriceInput' }) do
            local money = sell[name] and sell[name].MoneyInputFrame
            for _, box in ipairs({ money and money.GoldBox, money and money.SilverBox, money and money.CopperBox }) do
                if box and box.HookScript then
                    box:HookScript('OnTextChanged', function(_, userInput)
                        if userInput and not Undercut.filling then
                            Undercut.instance:Edited()
                            if Undercut.sellFrame == sell then Undercut.warning = nil end
                        end
                        Undercut.Refresh(sell)
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
    if ns.db then ns.db.auctionUndercutTrace = nil end          -- the trace of 0.5.99 is gone, its saved rows too
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
