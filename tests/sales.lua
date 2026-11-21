local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local DAY = 86400

local function load()
    local ns = { settings = {}, printed = {}, db = { sales = {}, mailLog = {} } }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.Style = {}
    assert(loadfile('tests/style_stub.lua'))()(ns.Style)
    ns.Economy = { Coin = function(copper) return copper .. 'c' end }
    assert(loadfile('TitanGatheredForever/Sales.lua'))('TitanGatheredForever', ns)
    return ns
end

-- A fake inbox: mails[i] = { subject, money, days, invoice = { 'seller', 'Linen Cloth', 'Buyer', 0, 5000, 20, 250 } }.
local function fixture(options)
    local ns = load()
    local f = { ns = ns, mails = {}, now = 1000000, character = 'Medyn', ids = { ['Linen Cloth'] = 2589 } }
    for key, value in pairs(options or {}) do f[key] = value end
    f.api = {
        Count = function() return #f.mails end,
        Header = function(i)
            local m = f.mails[i]
            return m and { sender = m.sender or 'Auction House', subject = m.subject, money = m.money, days = m.days } or nil
        end,
        Invoice = function(i) return f.mails[i] and f.mails[i].invoice or nil end,
        Now = function() return f.now end,
        Character = function() return f.character end,
        Realm = function() return 'Realm' end,
        ItemID = function(name) return f.ids[name] end,
    }
    f.ledger = ns.Sales.New(f.api, ns.db.sales, ns.db.mailLog)
    return f
end

local function sold(name, money, days, invoice)
    return { subject = 'Auction successful: ' .. name, money = money, days = days or 30, invoice = invoice }
end

test('the sold subject is read with the format of the client and an optional stack size', function()
    local ns = load()
    local name, count = ns.Sales.ParseSubject('Auction successful: Linen Cloth')
    eq(name, 'Linen Cloth'); eq(count, nil)
    name, count = ns.Sales.ParseSubject('Auction successful: Linen Cloth (20)')
    eq(name, 'Linen Cloth'); eq(count, 20)
    eq(ns.Sales.ParseSubject('Auction expired: Linen Cloth'), nil)
    eq(ns.Sales.ParseSubject('Auction won: Linen Cloth'), nil)
    eq(ns.Sales.ParseSubject(nil), nil)
    eq(ns.Sales.ParseSubject(42), nil)
    _G.AUCTION_SOLD_MAIL_SUBJECT = 'Aukce uspesna (%s)!'
    name = ns.Sales.ParseSubject('Aukce uspesna (Len)!')
    eq(name, 'Len')
    eq(ns.Sales.ParseSubject('Auction successful: Linen Cloth'), nil)
    _G.AUCTION_SOLD_MAIL_SUBJECT = nil
end)

test('a sold mail with money is recorded once with what is known', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth (20)', 3800, 30)
    eq(f.ledger:Scan(), 1)
    local entry = f.ns.db.sales.entries[1]
    eq(entry.itemName, 'Linen Cloth'); eq(entry.count, 20); eq(entry.itemID, 2589)
    eq(entry.received, 3800); eq(entry.character, 'Medyn'); eq(entry.realm, 'Realm'); eq(entry.at, f.now)
    eq(entry.source, 'header'); eq(entry.buyout, nil); eq(entry.fee, nil)
    eq(entry.expiry, f.now + 30 * DAY); eq(entry.soldAt, f.now)
    eq(f.ledger:Scan(), 0); eq(#f.ns.db.sales.entries, 1)
end)

test('an item the client does not know keeps an unknown id', function()
    local f = fixture()
    f.mails[1] = sold('Mystery', 100, 30)
    f.ledger:Scan()
    eq(f.ns.db.sales.entries[1].itemID, nil)
end)

test('mails that are not sales or have no money are skipped', function()
    local f = fixture()
    f.mails[1] = { subject = 'Auction expired: Linen Cloth', money = 0, days = 30 }
    f.mails[2] = sold('Linen Cloth', 0, 3)                                                    -- already collected
    f.mails[3] = { subject = 'Sale Pending: Linen Cloth', money = 0, days = 30,
        invoice = { 'seller_temp_invoice', 'Linen Cloth', 'Buyer', 0, 5000, 20, 250 } }
    f.mails[4] = { subject = 'Hello', money = 5000, days = 20 }                              -- a player mail with gold
    f.mails[5] = { subject = 'Auction won: Linen Cloth', money = 0, days = 30,
        invoice = { 'buyer', 'Linen Cloth', 'Seller', 0, 5000 } }
    eq(f.ledger:Scan(), 0)
    eq(#f.ns.db.sales.entries, 0)
end)

test('a seller invoice adds the buyer, the price, the deposit and the fee', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 4770, 30, { 'seller', 'Linen Cloth', 'Buyer', 0, 5000, 20, 250 })
    f.ledger:Scan()
    local entry = f.ns.db.sales.entries[1]
    eq(entry.source, 'invoice'); eq(entry.buyer, 'Buyer'); eq(entry.buyout, 5000); eq(entry.deposit, 20); eq(entry.fee, 250)
    eq(entry.received, 4770)
end)

test('an invoice type of seller counts even when the subject is not the usual one', function()
    local f = fixture()
    f.mails[1] = { subject = 'Something else', money = 900, days = 30, invoice = { 'seller', 'Linen Cloth', 'Buyer', 0, 1000, 5, 50 } }
    eq(f.ledger:Scan(), 1)
    eq(f.ns.db.sales.entries[1].itemName, 'Linen Cloth')
end)

test('invalid invoice numbers stay unknown', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 100, 30, { 'seller', 'Linen Cloth', 'Buyer', 0, 'x', -5, 0 / 0 })
    f.ledger:Scan()
    local entry = f.ns.db.sales.entries[1]
    eq(entry.buyout, nil); eq(entry.deposit, nil); eq(entry.fee, nil); eq(entry.buyer, 'Buyer')
end)

test('a later scan of the same mail does not duplicate it, also when the clock jitters', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 3800, 30)
    f.ledger:Scan()
    local expiry = f.now + 30 * DAY
    f.now = f.now + 3600
    f.mails[1].days = (expiry + 2 - f.now) / DAY                                              -- two seconds off
    eq(f.ledger:Scan(), 0)
    f.now = f.now + 5 * DAY
    f.mails[1].days = (expiry - 2 - f.now) / DAY
    eq(f.ledger:Scan(), 0)
    eq(#f.ns.db.sales.entries, 1)
end)

test('two identical mails are two sales, and stay two', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 3800, 30)
    f.mails[2] = sold('Linen Cloth', 3800, 30)
    eq(f.ledger:Scan(), 2)
    eq(f.ledger:Scan(), 0)
    f.mails[3] = sold('Linen Cloth', 3800, 30 - 60 / DAY)                                     -- a minute later: a new sale
    eq(f.ledger:Scan(), 1)
    eq(#f.ns.db.sales.entries, 3)
end)

test('another character with the same mail is a separate sale', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 3800, 30)
    f.ledger:Scan()
    f.character = 'Alt'
    eq(f.ledger:Scan(), 1)
end)

test('opening the mail later adds the invoice to the same sale', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 4770, 30)
    f.ledger:Scan()
    f.mails[1].invoice = { 'seller', 'Linen Cloth', 'Buyer', 0, 5000, 20, 250 }
    eq(f.ledger:Scan(), 0)
    local entry = f.ns.db.sales.entries[1]
    eq(#f.ns.db.sales.entries, 1); eq(entry.source, 'invoice'); eq(entry.buyout, 5000); eq(entry.at, f.now)
end)

test('collecting the money later does not erase or duplicate the sale', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 3800, 30)
    f.ledger:Scan()
    f.mails[1].money, f.mails[1].days = 0, 3                                                  -- emptied: 3 days left
    eq(f.ledger:Scan(), 0)
    eq(#f.ns.db.sales.entries, 1); eq(f.ns.db.sales.entries[1].received, 3800)
end)

test('bad data never raises and stops nothing', function()
    local f = fixture()
    f.mails[1] = { subject = nil, money = 100, days = 30 }
    f.mails[2] = { subject = 'Auction successful: A', money = 'lots', days = 30 }
    f.mails[3] = { subject = 'Auction successful: B', money = 100, days = 'soon' }
    f.mails[4] = sold('Linen Cloth', 3800, 30)
    local ok, added = pcall(f.ledger.Scan, f.ledger)
    assert(ok, tostring(added))
    eq(added, 1)
    f.api.Header = function() error('boom') end
    ok = pcall(f.ledger.Scan, f.ledger)
    assert(ok, 'a failing client call is contained')
end)

test('the ledger and the log are bounded', function()
    local f = fixture()
    f.ns.Sales.MAX = 5
    for i = 1, 8 do
        f.mails[#f.mails + 1] = sold('Linen Cloth', 1000 + i, 30 - i)
    end
    f.ledger:Scan()
    eq(#f.ns.db.sales.entries, 5)
    eq(f.ns.db.sales.entries[5].received, 1008)
    assert(#f.ns.db.mailLog <= f.ns.Sales.LOG_MAX)
end)

test('the diagnostic log records new sales and skipped auction mails once', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth', 4770, 30, { 'seller', 'Linen Cloth', 'Buyer', 0, 5000, 20, 250 })
    f.mails[2] = { subject = 'Sale Pending: X', money = 0, days = 30, invoice = { 'seller_temp_invoice', 'X', 'B', 0, 1, 1, 1 } }
    f.ledger:Scan(); f.ledger:Scan()
    eq(#f.ns.db.mailLog, 2)
    eq(f.ns.db.mailLog[1].result, 'recorded'); eq(f.ns.db.mailLog[1].invoice[1], 'seller')
    eq(f.ns.db.mailLog[2].result, 'pending')
end)

test('the report lists the newest sales with prices in the money format', function()
    local f = fixture()
    f.mails[1] = sold('Linen Cloth (20)', 3800, 30)
    f.ledger:Scan()
    f.ns.Sales.instance = f.ledger
    f.ns.Sales.Report()
    local text = table.concat(f.ns.printed, '\n')
    assert(text:find('Linen Cloth', 1, true), text); assert(text:find('3800c', 1, true), text)
    assert(text:find('1', 1, true))
end)

test('the client layer scans after the inbox settles and hooks the open mail once', function()
    local f = fixture()
    local ns = f.ns
    local created, timers, hooks = {}, {}, {}
    _G.CreateFrame = function()
        local self = { scripts = {}, events = {} }
        function self:RegisterEvent(e) self.events[e] = true end
        function self:SetScript(name, fn) self.scripts[name] = fn end
        created[#created + 1] = self
        return self
    end
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.OpenMail_Update = function() end
    _G.hooksecurefunc = function(name, fn) hooks[#hooks + 1] = { name, fn } end
    _G.time = function() return f.now end
    ns.Sales.DefaultAPI = function() return f.api end
    f.mails[1] = sold('Linen Cloth', 3800, 30)
    ns.Sales.Initialize()
    ns.Sales.Initialize()
    eq(#created, 1)
    local frame = created[1]
    assert(frame.events.MAIL_INBOX_UPDATE and frame.events.MAIL_SHOW)
    frame.scripts.OnEvent(frame, 'MAIL_INBOX_UPDATE')
    frame.scripts.OnEvent(frame, 'MAIL_INBOX_UPDATE')
    eq(#timers, 1)                                                                            -- batched
    eq(#ns.db.sales.entries, 0)
    timers[1]()
    eq(#ns.db.sales.entries, 1)
    frame.scripts.OnEvent(frame, 'MAIL_SHOW'); frame.scripts.OnEvent(frame, 'MAIL_SHOW')
    eq(#hooks, 1); eq(hooks[1][1], 'OpenMail_Update')
    eq(#timers, 2); timers[2]()
    hooks[1][2]()                                                                             -- a hook never raises
    eq(#timers, 3)
    f.api.Count = function() error('boom') end
    timers[#timers]()
    for _, key in ipairs({ 'CreateFrame', 'C_Timer', 'OpenMail_Update', 'hooksecurefunc', 'time' }) do _G[key] = nil end
end)

test('the default api reads the mail functions of the client', function()
    local ns = load()
    _G.GetInboxNumItems = function() return 2 end
    _G.GetInboxHeaderInfo = function(i)
        if i == 1 then return 'icon', 'stationery', 'Auction House', 'Auction successful: Linen Cloth', 3800, 0, 29.5, 0, false end
        error('no such mail')
    end
    _G.GetInboxInvoiceInfo = function(i)
        if i == 1 then return 'seller', 'Linen Cloth', 'Buyer', 0, 5000, 20, 250, 0, 0 end
    end
    _G.UnitName = function() return 'Medyn' end
    _G.GetRealmName = function() return 'Realm' end
    _G.time = function() return 5 end
    _G.C_Item = { GetItemInfoInstant = function(name) if name == 'Linen Cloth' then return 2589 end end }
    local api = ns.Sales.DefaultAPI()
    eq(api.Count(), 2)
    local header = api.Header(1)
    eq(header.sender, 'Auction House'); eq(header.subject, 'Auction successful: Linen Cloth')
    eq(header.money, 3800); eq(header.days, 29.5)
    eq(api.Header(2), nil)
    local invoice = api.Invoice(1)
    eq(invoice[1], 'seller'); eq(invoice[5], 5000); eq(invoice[7], 250)
    eq(api.Invoice(2), nil)
    eq(api.Character(), 'Medyn'); eq(api.Realm(), 'Realm'); eq(api.Now(), 5); eq(api.ItemID('Linen Cloth'), 2589)
    eq(api.ItemID('Nothing'), nil)
    _G.GetInboxNumItems = function() error('boom') end
    eq(api.Count(), 0)
    for _, key in ipairs({ 'GetInboxNumItems', 'GetInboxHeaderInfo', 'GetInboxInvoiceInfo', 'UnitName', 'GetRealmName', 'time', 'C_Item' }) do _G[key] = nil end
end)

local failed = 0
for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    print((ok and 'PASS ' or 'FAIL ') .. entry[1] .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failed = failed + 1 end
end
os.exit(failed == 0 and 0 or 1)
