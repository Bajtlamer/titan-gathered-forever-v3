local _, ns = ...
-- Sales ledger: what the auction house really paid. A sold auction arrives as a mail with the proceeds; the inbox is read
-- whenever it changes and every sale mail that holds money is recorded once in ns.db.sales.entries (item, stack size,
-- money received, and the price, deposit, fee and buyer when the invoice is readable). Nothing is changed in the mailbox
-- and nothing is taken from it. What the client does not tell stays nil (unknown stays unknown). A short diagnostic log
-- (ns.db.mailLog) keeps the raw invoice values of new sales and of auction mails that were skipped, to verify the readings.
local Sales = {}
Sales.__index = Sales
ns.Sales = Sales

Sales.MAX = 10000         -- sales kept
Sales.LOG_MAX = 120       -- diagnostic rows kept
Sales.MAIL_DAYS = 30      -- life of a sale mail with money; the sale time is estimated from the days left
Sales.TOLERANCE = 30      -- seconds the estimated expiry of the same mail may differ between two readings
local DAY = 86400

local function copper(value)
    if type(value) ~= 'number' or value ~= value or value < 0 or value > 9007199254740991 then return nil end
    return math.floor(value)
end

local function escape(text) return (text:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0')) end

-- The subject of a sold auction mail as the client formats it ("Auction successful: %s"), optionally with a stack size
-- in brackets after the name. Returns the item name and the stack size (or nil), nil when it is another mail.
function Sales.ParseSubject(subject)
    if type(subject) ~= 'string' then return nil end
    local format = type(_G.AUCTION_SOLD_MAIL_SUBJECT) == 'string' and _G.AUCTION_SOLD_MAIL_SUBJECT or 'Auction successful: %s'
    local pattern = escape(format):gsub('%%%%s', '(.+)')
    local name = subject:match('^' .. pattern .. '$')
    if not name then return nil end
    local base, count = name:match('^(.-)%s*%((%d+)%)$')
    if base and base ~= '' then return base, tonumber(count) end
    return name, nil
end

function Sales.New(api, store, log)
    store.entries = type(store.entries) == 'table' and store.entries or {}
    return setmetatable({ api = api, store = store, log = log or {}, logged = {} }, Sales)
end

local function raw(invoice)
    local copy = {}
    for i = 1, 12 do
        local value = invoice and invoice[i]
        if value ~= nil then copy[i] = (type(value) == 'number' or type(value) == 'string') and value or tostring(value) end
    end
    return copy
end

-- Rows of the diagnostic log; a skipped mail is logged once per session.
function Sales:Log(row, once)
    if once then
        if self.logged[once] then return end
        self.logged[once] = true
    end
    row.at = self.api.Now()
    local log = self.log
    log[#log + 1] = row
    while #log > Sales.LOG_MAX do table.remove(log, 1) end
end

-- The same mail as an earlier reading: the same character, subject and money, and an estimated expiry within the
-- tolerance; a mail is claimed once per scan so identical mails stay separate sales.
local function find(entries, wanted, now, claimed)
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if type(entry.at) == 'number' and entry.at < now - (Sales.MAIL_DAYS + 2) * DAY then break end
        if not claimed[entry] and entry.character == wanted.character and entry.subject == wanted.subject
            and entry.received == wanted.received and type(entry.expiry) == 'number'
            and math.abs(entry.expiry - wanted.expiry) <= Sales.TOLERANCE then
            return entry
        end
    end
end

local FIELDS = { 'buyer', 'buyout', 'deposit', 'fee' }

function Sales:Consider(index, now, claimed)
    local api = self.api
    local header = api.Header(index)
    if type(header) ~= 'table' or type(header.subject) ~= 'string' then return 0 end
    local invoice = api.Invoice(index)
    local kind = invoice and invoice[1]
    local name, count = Sales.ParseSubject(header.subject)
    if not name and kind ~= 'seller' then
        if kind == 'seller_temp_invoice' then
            self:Log({ result = 'pending', subject = header.subject, money = header.money, invoice = raw(invoice) },
                'pending|' .. header.subject)
        elseif kind then
            self:Log({ result = 'other', subject = header.subject, money = header.money, invoice = raw(invoice) },
                'other|' .. header.subject .. '|' .. tostring(header.money))
        else
            -- A sample of the other mails, to learn the client's subjects and senders; once per session.
            self:Log({ result = 'other-mail', subject = header.subject, sender = header.sender, money = header.money,
                days = header.days }, 'other-mail|' .. header.subject .. '|' .. tostring(header.sender))
        end
        return 0
    end
    local received = copper(header.money)
    if type(header.money) ~= 'number' or not received then
        self:Log({ result = 'bad-money', subject = header.subject, money = tostring(header.money) },
            'bad-money|' .. header.subject)
        return 0
    end
    if received <= 0 then return 0 end                                  -- collected already, or no proceeds yet
    if type(header.days) ~= 'number' or header.days ~= header.days then
        self:Log({ result = 'bad-days', subject = header.subject, money = received, days = tostring(header.days) },
            'bad-days|' .. header.subject)
        return 0
    end
    local wanted = { character = api.Character(), realm = api.Realm(), subject = header.subject, received = received,
        expiry = now + header.days * DAY, itemName = name, count = count }
    if kind == 'seller' then
        if type(invoice[2]) == 'string' and invoice[2] ~= '' then wanted.itemName = invoice[2] end
        if type(invoice[3]) == 'string' and invoice[3] ~= '' then wanted.buyer = invoice[3] end
        wanted.buyout, wanted.deposit, wanted.fee = copper(invoice[5]), copper(invoice[6]), copper(invoice[7])
        wanted.source = 'invoice'
    end
    local entries = self.store.entries
    local entry = find(entries, wanted, now, claimed)
    if entry then
        claimed[entry] = true
        if wanted.source == 'invoice' and entry.source ~= 'invoice' then entry.source = 'invoice' end
        for _, field in ipairs(FIELDS) do
            if entry[field] == nil and wanted[field] ~= nil then entry[field] = wanted[field] end
        end
        return 0
    end
    local itemID
    if wanted.itemName then
        local ok, id = pcall(api.ItemID, wanted.itemName)
        if ok and type(id) == 'number' then itemID = id end
    end
    entry = { at = now, character = wanted.character, realm = wanted.realm, subject = wanted.subject,
        itemName = wanted.itemName, itemID = itemID, count = count, received = received, expiry = wanted.expiry,
        soldAt = math.floor(wanted.expiry - Sales.MAIL_DAYS * DAY), source = wanted.source or 'header',
        buyer = wanted.buyer, buyout = wanted.buyout, deposit = wanted.deposit, fee = wanted.fee }
    entries[#entries + 1] = entry
    claimed[entry] = true
    while #entries > Sales.MAX do table.remove(entries, 1) end
    self:Log({ result = 'recorded', subject = header.subject, sender = header.sender, money = received,
        days = header.days, invoice = raw(invoice) })
    return 1
end

-- Reads the whole inbox; returns how many new sales were recorded. A mail that cannot be read never stops the others.
function Sales:Scan(source)
    local api = self.api
    local ok, total = pcall(api.Count)
    if not ok or type(total) ~= 'number' then
        self:Log({ result = 'scan-failed', source = source }, 'scan-failed')
        return 0
    end
    local now, claimed, added = api.Now(), {}, 0
    for index = 1, total do
        local read, result = pcall(self.Consider, self, index, now, claimed)
        if read and type(result) == 'number' then added = added + result end
    end
    -- Every reading that found something new, or a different number of mails, is a row: the log shows that the inbox
    -- was read even when it held no sale.
    if added > 0 or total ~= self.lastTotal then
        self:Log({ result = 'scan', source = source, mails = total, recorded = added })
    end
    self.lastTotal = total
    return added
end

-- The real client.
function Sales.DefaultAPI()
    local api = {}
    api.Count = function()
        local ok, value = pcall(GetInboxNumItems)
        return ok and type(value) == 'number' and value or 0
    end
    -- packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, ...
    api.Header = function(index)
        local values = { pcall(GetInboxHeaderInfo, index) }
        if not values[1] or values[5] == nil then return nil end
        return { sender = values[4], subject = values[5], money = values[6], cod = values[7], days = values[8] }
    end
    -- invoiceType, itemName, playerName, bid, buyout, deposit, consignment, ...; nil for a mail without an invoice
    api.Invoice = function(index)
        local values = { pcall(GetInboxInvoiceInfo, index) }
        if not values[1] or values[2] == nil then return nil end
        local invoice = {}
        for i = 1, 12 do invoice[i] = values[i + 1] end
        return invoice
    end
    api.Now = function() return time() end
    api.Character = function() return UnitName('player') end
    api.Realm = function() return GetRealmName() end
    api.ItemID = function(name)
        local id = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(name)
        return type(id) == 'number' and id or nil
    end
    return api
end

-- Prints the number of recorded sales and the newest few.
function Sales.Report()
    local instance = Sales.instance
    local entries = instance and instance.store.entries or (ns.db and ns.db.sales and ns.db.sales.entries) or {}
    local Style = ns.Style
    if #entries == 0 then
        ns.Print(Style.Label('No sales recorded yet. They are read from the sale mails when you open a mailbox.'))
        return
    end
    ns.Print(Style.Label('Sales recorded from the mail: ') .. Style.Value(#entries))
    local format = _G.date or os.date
    for i = #entries, math.max(1, #entries - 4), -1 do
        local entry = entries[i]
        local stack = entry.count and (' x' .. entry.count) or ''
        local day = type(entry.soldAt) == 'number' and format('%Y-%m-%d', entry.soldAt) or '?'
        ns.Print(Style.Value((entry.itemName or '?') .. stack) .. Style.Label(': received ') .. ns.Economy.Coin(entry.received)
            .. Style.Label(' around ') .. Style.Date(day))
    end
end

function Sales.Initialize()
    if Sales.frame then return end
    if ns.db then
        if type(ns.db.sales) ~= 'table' then ns.db.sales = {} end
        if type(ns.db.mailLog) ~= 'table' then ns.db.mailLog = {} end
    end
    local store = ns.db and ns.db.sales or {}
    Sales.instance = Sales.New(Sales.DefaultAPI(), store, ns.db and ns.db.mailLog or {})
    local frame = CreateFrame('Frame')
    Sales.frame = frame
    local pending = false
    -- The inbox raises many updates in a row; one reading a moment after the last is enough. A failure is contained.
    local function schedule(source)
        if pending then return end
        pending = true
        local function run()
            pending = false
            pcall(Sales.instance.Scan, Sales.instance, source)
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, run) else run() end
    end
    local hooked = false
    frame:SetScript('OnEvent', function(_, event)
        if event == 'MAIL_SHOW' and not hooked and type(_G.OpenMail_Update) == 'function' then
            -- Opening a sale mail makes the client load its invoice: read the inbox again then.
            hooked = true
            hooksecurefunc('OpenMail_Update', function() pcall(schedule, 'OpenMail_Update') end)
        end
        schedule(event)
    end)
    frame:RegisterEvent('MAIL_SHOW')
    frame:RegisterEvent('MAIL_INBOX_UPDATE')
end
