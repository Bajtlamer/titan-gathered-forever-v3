local _, ns = ...
-- Prices from the auction house. One full scan (C_AuctionHouse.ReplicateItems, answered with
-- REPLICATE_ITEM_LIST_UPDATE) is read in small steps and reduced to the items of the profession catalogue: the
-- lowest buyout per unit, the quantity on offer and the number of auctions. Only buyout prices count, because a
-- bid-only auction has no price that can be paid at once. The client allows a full scan about every 15 minutes, and a
-- request goes through the throttled message system of the auction house, whose events are shown and logged.
local Scan = {}
Scan.__index = Scan
ns.AuctionScan = Scan

Scan.STEP = 250          -- auctions read per step
Scan.ANSWER_WAIT = 120   -- seconds to wait for the answer before giving up (the server answers a full scan slowly)
Scan.COOLDOWN = 900      -- seconds the client wants between full scans

function Scan.New(api)
    return setmetatable({ api = api, scanning = false }, Scan)
end

function Scan:Log(result, details)
    local log = self.api.Log
    if log then log(result, details) end
end

-- Tells the display what is going on: phase is nil (idle), 'waiting' for the answer or 'reading' the list.
function Scan:Progress(phase, done, total)
    self.phase, self.done, self.total = phase, done or 0, total or 0
    if self.api.Progress then self.api.Progress() end
end

-- What the scan is doing, in words, and how far it is (0 to 1).
function Scan:Describe()
    if self.phase == 'waiting' then
        local seconds = math.max(0, math.floor(self.api.Clock() - (self.waitStarted or 0)))
        return string.format('%s (%d s)', self.note or 'Waiting for the auction house to send its list...', seconds), 0
    end
    if self.phase == 'reading' then
        local fraction = self.total > 0 and self.done / self.total or 0
        return string.format('Reading auctions: %d%% (%d of %d)', math.floor(fraction * 100), self.done, self.total), fraction
    end
    return nil, 0
end

-- Asks for a full scan. Returns true when the request was sent, otherwise false and the reason.
function Scan:Request()
    if self.scanning then return false, 'busy' end
    if not self.api.Open() then return false, 'closed' end
    local now = self.api.Now()
    local last = self.api.LastRequest()
    if last and now - last < Scan.COOLDOWN then return false, 'cooldown', Scan.COOLDOWN - (now - last) end
    self.scanning = true
    self.generation = (self.generation or 0) + 1
    local generation = self.generation
    self.api.SetLastRequest(now)
    self.api.Replicate()
    self.note, self.waitStarted = nil, self.api.Clock()
    self:Log('requested', { ready = self.api.Ready and self.api.Ready() })
    self:Progress('waiting')
    -- The bar counts the seconds while the answer is awaited.
    local function tick()
        if self.scanning and not self.reading and self.generation == generation then
            self:Progress('waiting')
            self.api.After(1, tick)
        end
    end
    self.api.After(1, tick)
    self.api.After(Scan.ANSWER_WAIT, function()
        if self.scanning and not self.reading and self.generation == generation then
            self.scanning = false
            self:Progress(nil)
            self:Log('no-answer', { waited = Scan.ANSWER_WAIT })
            self.api.Say(string.format('The auction house gave no answer within %d seconds. It allows a full scan about every 15 minutes.', Scan.ANSWER_WAIT))
            self.api.Changed()
        end
    end)
    return true
end

-- The throttled message system of the auction house reports what became of the request.
local throttleText = {
    AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED = 'The auction house queued the request...',
    AUCTION_HOUSE_THROTTLED_MESSAGE_SENT = 'The request was sent to the server...',
    AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED = 'The server answered, receiving the list...',
}
function Scan:Throttle(event)
    self:Log('event', { name = event })
    if not self.scanning or self.reading then return end
    if event == 'AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED' then
        self.scanning = false
        self.generation = (self.generation or 0) + 1
        self:Progress(nil)
        self.api.Say('The auction house dropped the request because of too many requests. Try again in a minute.')
        self.api.Changed()
    elseif throttleText[event] then
        self.note = throttleText[event]
        self:Progress('waiting')
    end
end

-- The window of the auction house closed: nothing more is read.
function Scan:Closed()
    if self.scanning then self:Log('closed-during-scan') end
    self.scanning, self.reading = false, false
    self.generation = (self.generation or 0) + 1
    self:Progress(nil)
end

-- REPLICATE_ITEM_LIST_UPDATE: the list is ready; read it in steps so the game does not stall.
function Scan:Updated()
    if not self.scanning or self.reading then
        self:Log('update-ignored', { entries = self.api.Count() })
        return
    end
    local total = self.api.Count()
    if type(total) ~= 'number' or total < 1 then
        self.scanning = false
        self:Progress(nil)
        self:Log('empty')
        self.api.Say('The auction house sent an empty list.')
        self.api.Changed()
        return
    end
    self.reading = true
    self.api.Say(string.format('The auction house sent %d auctions. Reading them...', total))
    self:Progress('reading', 0, total)
    local milestone = 25
    local generation = self.generation
    local items, index, started = {}, 1, self.api.Clock()
    local function step()
        if not self.reading or self.generation ~= generation then return end
        local last = math.min(total, index + Scan.STEP - 1)
        for position = index, last do
            local itemID, count, buyout = self.api.Item(position)
            if itemID and count and buyout and count > 0 and buyout > 0 and self.api.Wanted(itemID) then
                local unit = math.max(1, math.floor(buyout / count + 0.5))
                local entry = items[itemID]
                if not entry then entry = { min = unit, qty = 0, n = 0 }; items[itemID] = entry end
                if unit < entry.min then entry.min = unit end
                entry.qty, entry.n = entry.qty + count, entry.n + 1
            end
        end
        index = last + 1
        if index <= total then
            self:Progress('reading', last, total)
            -- A line in the chat at every quarter, only for lists long enough to take a while.
            while total > 1000 and milestone < 100 and last * 100 >= milestone * total do
                self.api.Say(string.format('Auction scan: %d%% (%d of %d)', milestone, last, total))
                milestone = milestone + 25
            end
            self.api.After(0, step)
            return
        end
        local found = 0
        for _ in pairs(items) do found = found + 1 end
        self.api.Save({ at = self.api.Now(), entries = total, items = items })
        self.scanning, self.reading = false, false
        self:Progress(nil)
        self:Log('done', { entries = total, items = found, seconds = self.api.Clock() - started })
        self.api.Say(string.format('Auction scan done: %d auctions, %d profession items priced.', total, found))
        self.api.Changed()
    end
    step()
end

-- Price of an item from the last scan on this realm: { min, qty, n } or nil, and the time of the scan.
function Scan.Price(itemID)
    local saved = ns.db and ns.db.auction
    if type(saved) ~= 'table' or type(saved.items) ~= 'table' then return nil end
    if saved.realm and GetRealmName and saved.realm ~= GetRealmName() then return nil end
    return saved.items[itemID], saved.at
end

-- Text for an age in seconds: "5 min ago", "3 h ago", "2 d ago".
function Scan.Age(seconds)
    if seconds < 90 then return 'just now' end
    if seconds < 5400 then return math.floor(seconds / 60 + 0.5) .. ' min ago' end
    if seconds < 129600 then return math.floor(seconds / 3600 + 0.5) .. ' h ago' end
    return math.floor(seconds / 86400 + 0.5) .. ' d ago'
end

function Scan.Status()
    local saved = ns.db and ns.db.auction
    if type(saved) ~= 'table' or not saved.at then
        local log = ns.db and ns.db.auctionLog
        local last = log and log[#log]
        if last and last.result == 'no-answer' then return 'The last scan got no answer from the auction house.' end
        return 'No auction prices scanned yet.'
    end
    local count = 0
    for _ in pairs(saved.items or {}) do count = count + 1 end
    return string.format('Scanned %s: %d profession items priced from %d auctions.',
        Scan.Age(math.max(0, (time and time() or saved.at) - saved.at)), count, saved.entries or 0)
end

function Scan.Clear()
    if ns.db then ns.db.auction = nil end
end

-- The real client.
function Scan.DefaultAPI()
    local api = {}
    api.Open = function() return _G.AuctionHouseFrame ~= nil and _G.AuctionHouseFrame:IsShown() end
    api.Now = function() return time() end
    api.Clock = function() return GetTime and GetTime() or 0 end
    api.After = function(seconds, fn) C_Timer.After(seconds, fn) end
    api.LastRequest = function() return ns.db and ns.db.auctionRequestedAt end
    api.SetLastRequest = function(value) if ns.db then ns.db.auctionRequestedAt = value end end
    api.Replicate = function() C_AuctionHouse.ReplicateItems() end
    api.Ready = function()
        local ok, value = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        if ok and ns.IsPublic(value) and type(value) == 'boolean' then return value end
    end
    api.Count = function()
        local ok, value = pcall(C_AuctionHouse.GetNumReplicateItems)
        if ok and ns.IsPublic(value) and type(value) == 'number' then return value end
    end
    -- itemID, count and buyout price of one auction, nil when the client hides a value. GetReplicateItemInfo returns:
    -- name, texture, count, qualityID, usable, level, levelType, minBid, minIncrement, buyoutPrice, bidAmount,
    -- highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo (client documentation).
    api.Item = function(index)
        local result = { pcall(C_AuctionHouse.GetReplicateItemInfo, index) }
        if not result[1] then return nil end
        local function number(value) return ns.IsPublic(value) and type(value) == 'number' and value or nil end
        return number(result[18]), number(result[4]), number(result[11])
    end
    api.Wanted = function(itemID) return ns.Catalog and ns.Catalog.Get(itemID) ~= nil end
    api.Save = function(result)
        if not ns.db then return end
        ns.db.auction = { realm = GetRealmName and GetRealmName() or nil, at = result.at, entries = result.entries,
            items = result.items }
    end
    api.Say = function(message) ns.Print(message) end
    api.Progress = function() if Scan.RefreshButton then Scan.RefreshButton() end end
    api.Changed = function()
        if ns.CraftingView and ns.CraftingView.Refresh then ns.CraftingView.Refresh() end
        if Scan.RefreshButton then Scan.RefreshButton() end
    end
    api.Log = function(result, details)
        local log = ns.db and ns.db.auctionLog
        if not log then return end
        local entry = { at = time(), result = result }
        for key, value in pairs(details or {}) do entry[key] = value end
        log[#log + 1] = entry
        while #log > 30 do table.remove(log, 1) end
    end
    return api
end

-- The button, the idle status and the progress bar below the window of the auction house.
function Scan.RefreshButton()
    local button, label, bar = Scan.button, Scan.label, Scan.bar
    if not button then return end
    local instance = Scan.instance
    local text, fraction
    if instance then text, fraction = instance:Describe() end
    local busy = text ~= nil
    button:SetEnabled(not (instance and instance.scanning))
    label:SetShown(not busy)
    bar:SetShown(busy)
    if busy then
        bar:SetValue(fraction)
        bar.text:SetText(text)
    else
        label:SetText(Scan.Status())
    end
end

function Scan.Attach()
    if Scan.button then return true end
    local frame = _G.AuctionHouseFrame
    if not frame then return false end
    local button = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
    Scan.button = button
    button:SetSize(130, 22)
    button:SetText('Scan prices')
    button:SetPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', -10, 2)
    button:SetScript('OnClick', function() Scan.Run() end)
    button:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:AddLine('Read the prices of the profession items')
        GameTooltip:AddLine('Reads the whole auction house once (the client allows this about every 15 minutes) and keeps the lowest buyout of each profession item for the reagent window.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function() GameTooltip:Hide() end)
    local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    Scan.label = label
    label:SetPoint('RIGHT', button, 'LEFT', -8, 0)
    label:SetJustifyH('RIGHT')
    local bar = CreateFrame('StatusBar', nil, frame)
    Scan.bar = bar
    bar:SetSize(300, 16)
    bar:SetPoint('RIGHT', button, 'LEFT', -8, 0)
    bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')
    bar:SetStatusBarColor(0.1, 0.6, 0.9)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local background = bar:CreateTexture(nil, 'BACKGROUND')
    background:SetAllPoints(bar)
    background:SetColorTexture(0, 0, 0, 0.5)
    bar.text = bar:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    bar.text:SetPoint('CENTER')
    bar:Hide()
    Scan.RefreshButton()
    return true
end

-- The button and the menu start a scan with a short answer for the player.
function Scan.Run()
    local ok, reason, wait = Scan.instance:Request()
    if ok then
        ns.Print('Scanning the auction house...')
    elseif reason == 'closed' then ns.Print('Open the auction house first.')
    elseif reason == 'cooldown' then
        ns.Print(string.format('The auction house allows a full scan about every 15 minutes: %d min left.', math.ceil(wait / 60)))
    end
    Scan.RefreshButton()
end

function Scan.Initialize()
    if Scan.frame then return end
    Scan.instance = Scan.New(Scan.DefaultAPI())
    local frame = CreateFrame('Frame')
    Scan.frame = frame
    frame:SetScript('OnEvent', function(_, event)
        if event == 'AUCTION_HOUSE_SHOW' then
            Scan.Attach()
            Scan.RefreshButton()
            local automatic = ns.settings and ns.settings.auctionAutoScan
            if automatic then
                local last = ns.db and ns.db.auction and ns.db.auction.at
                if not last or time() - last > 1800 then Scan.instance:Request() end
            end
        elseif event == 'AUCTION_HOUSE_CLOSED' then
            Scan.instance:Closed()
        elseif event == 'REPLICATE_ITEM_LIST_UPDATE' then
            Scan.instance:Updated()
        else
            Scan.instance:Throttle(event)
        end
    end)
    for _, event in ipairs({ 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'REPLICATE_ITEM_LIST_UPDATE',
        'AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED', 'AUCTION_HOUSE_THROTTLED_MESSAGE_SENT',
        'AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED', 'AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED' }) do
        frame:RegisterEvent(event)
    end
end
