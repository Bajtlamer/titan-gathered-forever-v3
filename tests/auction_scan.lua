local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function load()
    local ns = { IsPublic = function() return true end, db = {}, printed = {}, settings = {},
        Catalog = { Get = function(id) return (id == 2589 or id == 2592 or id == 4306) and {} or nil end } }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    assert(loadfile('TitanGatheredForeverV3/AuctionScan.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

-- A fake client: auctions are { itemID, count, buyout }; timers are collected and run by hand.
local function fixture(auctions)
    local ns = load()
    local f = { ns = ns, auctions = auctions, timers = {}, open = true, now = 1000, requests = 0, said = {}, changed = 0, logs = {}, progress = {} }
    local api = {
        Open = function() return f.open end, Now = function() return f.now end, Clock = function() return 0 end,
        After = function(_, fn) f.timers[#f.timers + 1] = fn end,
        LastRequest = function() return f.last end, SetLastRequest = function(v) f.last = v end,
        Replicate = function() f.requests = f.requests + 1 end,
        Count = function() return #f.auctions end,
        Item = function(index) local a = f.auctions[index]; return a[1], a[2], a[3] end,
        Wanted = function(id) return ns.Catalog.Get(id) ~= nil end,
        Save = function(result) f.saved = result end,
        Say = function(message) f.said[#f.said + 1] = message end,
        Changed = function() f.changed = f.changed + 1 end,
        Log = function(result, details) f.logs[#f.logs + 1] = result; f.lastDetails = details end,
        Progress = function() f.progress[#f.progress + 1] = { f.scan.phase, f.scan.done, f.scan.total } end,
    }
    f.scan = ns.AuctionScan.New(api)
    function f.run() while #f.timers > 0 do local fn = table.remove(f.timers, 1); fn() end end
    return f
end

test('a scan keeps the lowest buyout per unit of the profession items, with quantity and auction count', function()
    local f = fixture({ { 2589, 20, 1000 }, { 2589, 5, 200 }, { 2592, 1, 300 }, { 9999, 1, 50 }, { 2589, 10, 0 } })
    eq(f.scan:Request(), true); eq(f.requests, 1)
    f.scan:Updated(); f.run()
    local items = f.saved.items
    eq(items[2589].min, 40); eq(items[2589].qty, 25); eq(items[2589].n, 2)   -- 200 for 5 is 40 each; the bid-only one is ignored
    eq(items[2592].min, 300); eq(items[9999], nil)                         -- not a profession item
    eq(f.saved.entries, 5); eq(f.saved.at, 1000)
    assert(f.said[#f.said]:find('2 profession items priced', 1, true)); eq(f.scan.scanning, false)
end)

test('a big list is read in steps and each step leaves the game a moment', function()
    local auctions = {}
    for i = 1, 11 do auctions[i] = { 2589, 1, 100 + i } end
    local f = fixture(auctions)
    f.ns.AuctionScan.STEP = 4
    f.scan:Request(); f.timers = {}                                           -- ignore the answer timer
    f.scan:Updated()
    eq(f.saved, nil); eq(#f.timers, 1)                                        -- the first four are read, the rest waits
    f.run()
    eq(f.saved.items[2589].n, 11); eq(f.saved.items[2589].min, 101)
    f.ns.AuctionScan.STEP = 250
end)

test('the display is told what the scan is doing: waiting, reading with a fraction, then idle', function()
    local auctions = {}
    for i = 1, 8 do auctions[i] = { 2589, 1, 100 } end
    local f = fixture(auctions)
    f.ns.AuctionScan.STEP = 3
    eq(f.scan:Describe(), nil)
    f.scan:Request()
    eq(f.scan.phase, 'waiting'); eq((f.scan:Describe()), 'Waiting for the auction house to send its list...')
    f.timers = {}
    f.scan:Updated()                                                        -- the first step reads three of eight
    local text, fraction = f.scan:Describe()
    eq(text, 'Reading auctions: 37% (3 of 8)'); assert(math.abs(fraction - 0.375) < 0.0001)
    f.run()
    eq(f.scan.phase, nil); eq((f.scan:Describe()), nil)
    local phases = {}
    for _, entry in ipairs(f.progress) do phases[#phases + 1] = tostring(entry[1]) end
    eq(table.concat(phases, ','), 'waiting,reading,reading,reading,nil')   -- waiting, 0 read, 3, 6, finished
    f.ns.AuctionScan.STEP = 250
end)

test('long lists report every quarter in the chat, short ones only the start and the end', function()
    local auctions = {}
    for i = 1, 2000 do auctions[i] = { 2589, 1, 100 } end
    local f = fixture(auctions)
    f.scan:Request(); f.scan:Updated(); f.run()
    eq(f.said[1], 'The auction house sent 2000 auctions. Reading them...')
    eq(f.said[2], 'Auction scan: 25% (500 of 2000)'); eq(f.said[3], 'Auction scan: 50% (1000 of 2000)')
    eq(f.said[4], 'Auction scan: 75% (1500 of 2000)'); assert(f.said[5]:find('Auction scan done', 1, true)); eq(#f.said, 5)
    local small = fixture({ { 2589, 1, 10 }, { 2589, 1, 11 } })
    small.scan:Request(); small.scan:Updated(); small.run()
    eq(#small.said, 2)                                                         -- the answer and the result
    local g = fixture({ { 2589, 1, 10 } })
    g.scan:Request(); g.scan:Closed(); eq(g.scan.phase, nil)                  -- closing the window clears the display
end)

test('a request needs an open auction house, respects the cooldown and cannot overlap', function()
    local f = fixture({ { 2589, 1, 10 } })
    f.open = false
    local ok, reason = f.scan:Request(); eq(ok, false); eq(reason, 'closed'); eq(f.requests, 0)
    f.open = true
    f.last = 700                                                                -- 300 seconds ago
    local ok2, reason2, wait = f.scan:Request(); eq(ok2, false); eq(reason2, 'cooldown'); eq(wait, 600)
    f.last = 0
    eq(f.scan:Request(), true)
    local ok3, reason3 = f.scan:Request(); eq(ok3, false); eq(reason3, 'busy')
    eq(f.last, 1000)
end)

test('no answer from the auction house ends the wait with a message', function()
    local f = fixture({})
    f.scan:Request()
    f.run()
    eq(f.scan.scanning, false); assert(f.said[1]:find('15 minutes', 1, true)); eq(f.logs[#f.logs], 'no-answer')
end)

test('an empty answer and a closing window stop the scan without saving', function()
    local f = fixture({})
    f.scan:Request(); f.scan:Updated(); eq(f.scan.scanning, false); eq(f.saved, nil); eq(f.logs[#f.logs], 'empty')
    local g = fixture({ { 2589, 1, 10 }, { 2589, 1, 11 }, { 2589, 1, 12 } })
    g.ns.AuctionScan.STEP = 1
    g.scan:Request(); g.timers = {}; g.scan:Updated()
    g.scan:Closed(); g.run()                                                     -- the steps that were still waiting do nothing
    eq(g.saved, nil); eq(g.scan.scanning, false)
    g.ns.AuctionScan.STEP = 250
    eq(g.scan:Request(), false)                                                  -- the request counted: the cooldown still runs
    g.last = nil
    eq(g.scan:Request(), true)                                                   -- a new scan can start later
end)

test('an update without a request is ignored', function()
    local f = fixture({ { 2589, 1, 10 } })
    f.scan:Updated(); eq(f.saved, nil)
end)

test('prices are looked up for this realm and described with their age', function()
    local ns = load()
    GetRealmName = function() return 'Realm A' end
    ns.db.auction = { realm = 'Realm A', at = 1000, entries = 50, items = { [2589] = { min = 40, qty = 25, n = 2 } } }
    eq(ns.AuctionScan.Price(2589).min, 40); eq(ns.AuctionScan.Price(1), nil)
    GetRealmName = function() return 'Realm B' end
    eq(ns.AuctionScan.Price(2589), nil)                                            -- another realm has other prices
    GetRealmName = nil
    eq(ns.AuctionScan.Age(30), 'just now'); eq(ns.AuctionScan.Age(600), '10 min ago'); eq(ns.AuctionScan.Age(7200), '2 h ago')
    eq(ns.AuctionScan.Age(200000), '2 d ago')
    time = function() return 1600 end
    assert(ns.AuctionScan.Status():find('Scanned 10 min ago: 1 profession items priced from 50 auctions', 1, true))
    ns.AuctionScan.Clear(); eq(ns.db.auction, nil); assert(ns.AuctionScan.Status():find('No auction prices', 1, true))
    time = nil
end)

test('the client list is read at the documented positions and hidden values are dropped', function()
    local ns = load()
    local secret = {}
    ns.IsPublic = function(value) return value ~= secret end
    C_AuctionHouse = { GetReplicateItemInfo = function(index)
        if index == 1 then
            return 'Name', 1, 5, 1, true, 0, nil, 10, 1, 250, 0, nil, nil, 'Owner', 'Owner-Realm', 0, 2589, true
        end
        return 'Name', 1, secret, 1, true, 0, nil, 10, 1, 250, 0, nil, nil, 'Owner', 'Owner-Realm', 0, 2589, true
    end, GetNumReplicateItems = function() return 2 end }
    local api = ns.AuctionScan.DefaultAPI()
    local id, count, buyout = api.Item(1); eq(id, 2589); eq(count, 5); eq(buyout, 250)
    local id2, count2 = api.Item(2); eq(id2, 2589); eq(count2, nil)
    eq(api.Count(), 2); eq(api.Wanted(2589), true); eq(api.Wanted(5), false)
    C_AuctionHouse = nil
end)

test('the button appears with the auction house window and starts a scan with a message', function()
    local ns = load()
    local function frame()
        local f = { scripts = {} }
        function f:SetSize() end; function f:SetText(v) self.text = v end; function f:SetPoint(...) self.point = { ... } end
        function f:SetScript(name, fn) self.scripts[name] = fn end; function f:SetEnabled(v) self.enabled = v end
        function f:SetJustifyH() end
        function f:SetShown(v) self.shown = v end; function f:Hide() self.shown = false end
        function f:SetMinMaxValues() end; function f:SetValue(v) self.value = v end
        function f:SetStatusBarTexture() end; function f:SetStatusBarColor() end
        function f:SetAllPoints() end; function f:SetColorTexture() end
        function f:CreateTexture() return frame() end
        function f:CreateFontString() return frame() end
        function f:RegisterEvent(e) self.events = (self.events or 0) + 1 end
        return f
    end
    CreateFrame = function() return frame() end
    GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
    C_Timer = { After = function() end }
    _G.AuctionHouseFrame = nil
    eq(ns.AuctionScan.Attach(), false)
    local window = frame(); window.IsShown = function() return true end
    _G.AuctionHouseFrame = window
    eq(ns.AuctionScan.Attach(), true)
    local button = ns.AuctionScan.button
    eq(button.text, 'Scan prices'); eq(button.point[1], 'TOPRIGHT'); eq(button.point[3], 'BOTTOMRIGHT')
    ns.AuctionScan.instance = ns.AuctionScan.New({ Open = function() return false end, Now = function() return 1 end,
        LastRequest = function() end, SetLastRequest = function() end, Log = function() end })
    button.scripts.OnClick(); eq(ns.printed[1], 'Open the auction house first.')
    -- while a scan runs the bar shows the text and the fraction and the idle status is hidden
    local bar, label = ns.AuctionScan.bar, ns.AuctionScan.label
    eq(bar.shown, false); eq(label.shown, true)
    ns.AuctionScan.instance.phase, ns.AuctionScan.instance.done, ns.AuctionScan.instance.total = 'reading', 50, 200
    ns.AuctionScan.RefreshButton()
    eq(bar.shown, true); eq(label.shown, false); eq(bar.value, 0.25); eq(bar.text.text, 'Reading auctions: 25% (50 of 200)')
    ns.AuctionScan.instance.phase = nil
    ns.AuctionScan.RefreshButton()
    eq(bar.shown, false); eq(label.shown, true)
    ns.AuctionScan.Initialize()
    eq(ns.AuctionScan.frame.events, 3)
    _G.AuctionHouseFrame, CreateFrame, C_Timer = nil, nil, nil
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS auction scan ' .. #tests .. ' checks')
