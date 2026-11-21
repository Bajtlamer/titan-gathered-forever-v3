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
                if ok and amount ~= copper then entry.reapplied = true; put() end
            end)
        end
        ns.Print(ns.Style.Label('Buyout set to ') .. ns.Economy.Coin(copper) .. ns.Style.Label(string.format(' (%s%% under the lowest, ', tostring(percent)))
            .. ns.Economy.Coin(lowest) .. ns.Style.Label(').'))
    end
    api.Say = function(message) ns.Print(ns.Style.Label(message)) end
    -- The red line above the posting lines: shown while the Buyout rests on the vendor price, cleared at the next fill.
    api.Warn = function(reason, vendor)
        local line = Undercut.warning
        if not line then return end
        if reason == 'vendor' and vendor then
            line:SetText(ns.Style.Text(ns.Style.red, 'Vendor floor after fee: Buyout set to ') .. ns.Economy.Coin(vendor))
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

-- A signed amount of coins: green with a plus, red with a minus.
local function signed(copper)
    local Style, Coin = ns.Style, ns.Economy.Coin
    if copper >= 0 then return Style.Text(Style.green, '+') .. Coin(copper) end
    return Style.Text(Style.red, '-') .. Coin(-copper)
end

-- The posting texts for an auction as it stands (Economy.Posting). The head goes next to the Undercut box: what a sale
-- brings after the fee and what a vendor pays for the same stack. The gains line (against the cost of the item and
-- against a vendor) and the unsold line (the deposit and the share of auctions that must sell for posting to pay) go
-- below it.
function Undercut.InfoText(post)
    if not post then return '', '', '' end
    local Style, Coin = ns.Style, ns.Economy.Coin
    local head = Style.Label('AH sold: ') .. Coin(post.net)
    if post.vendor and post.vendor > 0 then head = head .. Style.Label('  Vendor: ') .. Coin(post.vendor * post.quantity) end
    local parts = {}
    if post.profit then parts[#parts + 1] = signed(post.profit) .. Style.Label(' vs cost') end
    if post.gain then parts[#parts + 1] = signed(post.gain) .. Style.Label(' vs vendor') end
    local gains = #parts > 0 and (Style.Label('Gain: ') .. table.concat(parts, Style.Label(', '))) or ''
    local unsold = Style.Label('Unsold: ')
    if post.loss then
        unsold = unsold .. signed(-post.loss) .. Style.Label(' deposit')
        if post.needed == 'never' then
            unsold = unsold .. Style.Label(', ') .. Style.Text(Style.red, 'a sale does not beat a vendor')
        elseif post.needed then
            unsold = unsold .. Style.Label(', pays off if ') .. Style.Value(string.format('%d%%', math.ceil(post.needed * 100 - 1e-9))) .. Style.Label(' sell')
        end
    else
        unsold = unsold .. Style.Label('deposit unknown')
    end
    return head, gains, unsold
end

-- Room for the posting lines: while a Sell form is shown the auction house window is made EXTRA pixels taller. What the
-- client anchors to the top of the window stays, what it anchors to the bottom (Buyout Mode, the money bar, the tabs)
-- and our strip and lines move down with the edge, which leaves the free space between them. Restored when the form closes.
Undercut.EXTRA = 44

function Undercut.Resize(wanted)
    local frame = _G.AuctionHouseFrame
    if not frame or not frame.GetHeight or not frame.SetHeight then return end
    wanted = wanted and true or false
    if (Undercut.extended or false) == wanted then return end
    local ok, height = pcall(frame.GetHeight, frame)
    if not ok or type(height) ~= 'number' then return end
    Undercut.extended = wanted
    frame:SetHeight(height + (wanted and Undercut.EXTRA or -Undercut.EXTRA))
end

-- Reads the form as it stands and shows the lines; an empty form or a price of zero shows nothing.
function Undercut.Refresh(sell)
    local info = Undercut.info
    if not info or not sell then return end
    local input = Undercut.BuyoutInput(sell)
    local price = input and input.GetAmount and select(2, pcall(input.GetAmount, input))
    local quantity = read(sell, 'GetQuantity')
    local deposit = read(sell, 'GetDepositAmount')
    local key = Undercut.instance and Undercut.instance.key
    local itemID = key and key.itemKey and key.itemKey.itemID
    local vendor = itemID and ns.Economy.VendorSell(itemID) or nil
    -- The cost is the cheapest known way to buy one unit again (last auction scan or a merchant); unknown stays unknown.
    local okCost, cost = pcall(ns.Economy.UnitCost, itemID or 0)
    local post = type(price) == 'number' and itemID and ns.Economy.Posting(price, quantity, type(deposit) == 'number' and deposit or nil, vendor, okCost and cost or nil) or nil
    local head, gains, unsold = Undercut.InfoText(post)
    if Undercut.head then Undercut.head:SetText(head) end
    info:SetText(post and unsold or '')
    if Undercut.gains then Undercut.gains:SetText(post and gains or '') end
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
    strip:SetSize(400, 24)
    -- At the left edge of the panel, in the row above the Buyout Mode check box (free on every form), shown only while a
    -- Sell form is shown. The window is taller while it is (Undercut.Resize), so the rows below fit above the check box.
    strip:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 32, 78)
    if strip.SetFrameLevel and frame.GetFrameLevel then strip:SetFrameLevel(frame:GetFrameLevel() + 20) end
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
    -- The sale and the vendor price right after the box, then the gains and the unsold line below the strip from the
    -- left edge, and the red warning above them.
    local head = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    head:SetPoint('LEFT', strip, 'LEFT', 128, 0)
    head:SetJustifyH('LEFT')
    Undercut.head = head
    -- Two single-line texts instead of one with a large line spacing: the coin icons inside a text with extra spacing rose.
    local info = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    info:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 32, 114)
    info:SetJustifyH('LEFT')
    Undercut.info = info
    local gains = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    gains:SetPoint('BOTTOMLEFT', info, 'TOPLEFT', 0, 9)
    gains:SetJustifyH('LEFT')
    Undercut.gains = gains
    local warning = strip:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    warning:SetPoint('BOTTOMLEFT', gains, 'TOPLEFT', 0, 6)
    warning:Hide()
    Undercut.warning = warning

    local function refresh(later)
        local shown = false
        for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
            if sell.IsShown and sell:IsShown() then shown = true end
        end
        strip:SetShown(shown)
        local windowShown = frame.IsShown and frame:IsShown() or false
        if not windowShown and Undercut.extended and not later then
            -- The window is closing (ESC after a sale): the client is still releasing its scroll lists, and a resize now
            -- makes them lay out again over emptied data (errors in its own code). Restore the size a moment later.
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, function() Undercut.refreshForm(true) end)
            else
                Undercut.Resize(false)
            end
            return
        end
        Undercut.Resize(shown and windowShown)
    end
    Undercut.refreshForm = refresh
    if frame.HookScript then frame:HookScript('OnHide', function() refresh() end) end
    for _, sell in ipairs({ frame.CommoditiesSellFrame, frame.ItemSellFrame }) do
        if sell.HookScript then
            sell:HookScript('OnShow', function() refresh() end)
            sell:HookScript('OnHide', function() refresh() end)
        end
        hooksecurefunc(sell, 'SetItem', function(self, itemLocation)
            Undercut.sellFrame = self
            local key = keyOf(self, itemLocation)
            if key then Undercut.instance:Select(key) else Undercut.instance.key = nil end
            if Undercut.info then Undercut.info:SetText('') end
            if Undercut.gains then Undercut.gains:SetText('') end
            if Undercut.head then Undercut.head:SetText('') end
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
                        if userInput and not Undercut.filling then Undercut.instance:Edited() end
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
