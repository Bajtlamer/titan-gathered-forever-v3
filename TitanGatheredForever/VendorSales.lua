local _, ns = ...
local Vendor = {}
ns.VendorSales = Vendor

local BUYBACK_CAPACITY, SETTLE_DELAY, LOG_LIMIT = 12, 0.5, 40
local walletRevision = 0

local function lootOwnsWallet()
    return ns.LootIncome and ns.LootIncome.WalletBusy()
end

local function integer(value)
    return type(value) == 'number' and value >= 0 and value < math.huge and value == math.floor(value)
end

local function publicInteger(value)
    if ns.IsPublic(value) and integer(value) then return value end
end

local function readMoney()
    local ok, money = pcall(GetMoney)
    if ok then return publicInteger(money) end
end

local function buybackID(index)
    if C_MerchantFrame and C_MerchantFrame.GetBuybackItemID then
        local ok, value = pcall(C_MerchantFrame.GetBuybackItemID, index)
        local id = ok and publicInteger(value)
        if id and id > 0 then return id end
    end
    local link = GetBuybackItemLink and GetBuybackItemLink(index)
    if ns.IsPublic(link) and type(link) == 'string' then return tonumber(link:match('item:(%d+)')) end
end

-- What the bags hold: { ['bag:slot'] = { itemID, count } }, or nil when the client cannot be read. It is an extra proof
-- for sales that the buyback list cannot show, so a failure here never fails the snapshot.
local function readBags()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return nil end
    local map = {}
    for bag = 0, (publicInteger(NUM_BAG_SLOTS) or 4) + 1 do
        local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
        slots = okSlots and publicInteger(slots) or 0
        for slot = 1, slots do
            local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            if ok and ns.IsPublic(info) and type(info) == 'table' then
                local itemID, count = publicInteger(info.itemID), publicInteger(info.stackCount)
                if itemID and itemID > 0 and count and count > 0 then map[bag .. ':' .. slot] = { itemID = itemID, count = count } end
            end
        end
    end
    return map
end

-- What "repair all" would cost now (nil when the client cannot say). After a repair the wallet is lower by exactly the
-- amount by which this falls, which tells a repair from a purchase.
local function readRepairCost()
    if type(GetRepairAllCost) ~= 'function' then return nil end
    local ok, cost = pcall(GetRepairAllCost)
    if ok then return publicInteger(cost) end
end

local function readSnapshot()
    if type(GetNumBuybackItems) ~= 'function' then return nil, 'buyback count API missing' end
    local count, money = publicInteger(GetNumBuybackItems()), readMoney()
    if not count or count > BUYBACK_CAPACITY then return nil, 'buyback count unavailable' end
    if not money then return nil, 'wallet balance unavailable' end
    if count > 0 and type(GetBuybackItemInfo) ~= 'function' then return nil, 'buyback details API missing' end
    local rows = {}
    for index = 1, count do
        local _, _, price, size = GetBuybackItemInfo(index)
        local itemID, quantity, copper = buybackID(index), publicInteger(size), publicInteger(price)
        if not itemID or itemID <= 0 then return nil, 'buyback item ID unavailable', index end
        if not quantity or quantity <= 0 then return nil, 'buyback quantity unavailable', index end
        if not copper then return nil, 'buyback price unavailable', index end
        rows[index] = { itemID = itemID, quantity = quantity, copper = copper }
    end
    local okBags, bags = pcall(readBags)
    local okRepair, repair = pcall(readRepairCost)
    return { rows = rows, money = money, bags = okBags and bags or nil, repair = okRepair and repair or nil }
end

-- Sales proven by the bags: the items that left them, at their vendor price, add up to exactly the money gained. Moved
-- stacks cancel out (counted per item), and an item without a known vendor price proves nothing. One entry per stack
-- that changed, so the number of stacks sold is kept.
local function bagSale(before, after, gained)
    if not before or not after or gained <= 0 then return end
    local had, has = {}, {}
    for _, entry in pairs(before) do had[entry.itemID] = (had[entry.itemID] or 0) + entry.count end
    for _, entry in pairs(after) do has[entry.itemID] = (has[entry.itemID] or 0) + entry.count end
    local net, total = {}, 0
    for itemID, units in pairs(had) do
        local gone = units - (has[itemID] or 0)
        if gone > 0 then
            local ok, price = pcall(ns.Economy.VendorSell, itemID)
            price = ok and publicInteger(price)
            if not price or price <= 0 then return end
            net[itemID] = { units = gone, price = price }
            total = total + gone * price
        end
    end
    if total ~= gained or next(net) == nil then return end
    local rows = {}
    for key, entry in pairs(before) do
        local left = net[entry.itemID]
        local now = after[key]
        local removed = (now and now.itemID == entry.itemID) and math.max(0, entry.count - now.count) or entry.count
        if left and left.units > 0 and removed > 0 then
            local units = math.min(removed, left.units)
            left.units = left.units - units
            rows[#rows + 1] = { itemID = entry.itemID, quantity = units, copper = units * left.price }
        end
    end
    local covered = 0
    for _, row in ipairs(rows) do covered = covered + row.copper end
    if covered ~= gained then return end
    return rows
end

local function equal(left, right)
    return right and left.itemID == right.itemID and left.quantity == right.quantity and left.copper == right.copper
end

local function sameList(before, after)
    if #before ~= #after then return false end
    for i, row in ipairs(before) do
        if not equal(row, after[i]) then return false end
    end
    return true
end

local function retained(before, after, firstNew)
    local added = #after - firstNew + 1
    local dropped = math.max(0, #before + added - BUYBACK_CAPACITY)
    if firstNew - 1 ~= #before - dropped then return false end
    for i = 1, firstNew - 1 do
        if not equal(before[i + dropped], after[i]) then return false end
    end
    return true
end

local function sold(before, after, expected)
    local price, first = 0
    -- The client appends new sales, dropping the oldest slots when the buyback list fills.
    for i = #after, 1, -1 do
        price = price + after[i].copper
        if price > expected then break end
        if price == expected and retained(before, after, i) then
            if first then return end
            first = i
        end
    end
    if not first then return end
    local rows = {}
    for i = first, #after do rows[#rows + 1] = after[i] end
    return rows
end

local function boughtBack(before, after, expected)
    if #after >= #before then return end
    local rows, index, price = {}, 1, 0
    for _, row in ipairs(before) do
        if equal(row, after[index]) then
            index = index + 1
        else
            rows[#rows + 1], price = row, price + row.copper
        end
    end
    if index == #after + 1 and price == expected then return rows end
end

local function sum(items)
    local units, copper, stacks = 0, 0, 0
    if type(items) == 'table' then
        for _, row in pairs(items) do
            if type(row) == 'table' and integer(row.units) and integer(row.copper) and integer(row.stacks) then
                units, copper, stacks = units + row.units, copper + row.copper, stacks + row.stacks
            end
        end
    end
    return units, copper, stacks
end

function Vendor.Totals(store, realm, character)
    local total = { soldUnits = 0, soldCopper = 0, sales = 0, buybackUnits = 0, buybackCopper = 0, buybacks = 0,
        repairCopper = 0, repairs = 0 }
    local characters = type(store) == 'table' and store[realm]
    if type(characters) == 'table' then
        for id, record in pairs(characters) do
            if (character == nil or id == character) and type(record) == 'table' then
                local units, copper, stacks = sum(record.sale)
                total.soldUnits, total.soldCopper, total.sales =
                    total.soldUnits + units, total.soldCopper + copper, total.sales + stacks
                units, copper, stacks = sum(record.buyback)
                total.buybackUnits, total.buybackCopper, total.buybacks =
                    total.buybackUnits + units, total.buybackCopper + copper, total.buybacks + stacks
                local repair = record.repair
                if type(repair) == 'table' and integer(repair.copper) and integer(repair.count) then
                    total.repairCopper, total.repairs = total.repairCopper + repair.copper, total.repairs + repair.count
                end
            end
        end
    end
    return total
end

local function log(result, before, after, items, event, reason, slot)
    local rows = ns.db.vendorLog
    rows[#rows + 1] = { at = time(), result = result, before = before and #before.rows, after = after and #after.rows,
        walletDelta = before and after and after.money - before.money or nil, items = items,
        event = event, reason = reason, slot = slot }
    if #rows > LOG_LIMIT then table.remove(rows, 1) end
end

local function record(session, kind, items)
    local store = ns.db.vendorSales
    local characters = store[session.realm]
    if type(characters) ~= 'table' then characters = {}; store[session.realm] = characters end
    local entry = characters[session.character]
    if type(entry) ~= 'table' then entry = {}; characters[session.character] = entry end
    local at = time()
    if kind == 'repair' then
        -- One running total per character: what repairs cost in all, and how many there were.
        local repair = entry.repair
        if type(repair) ~= 'table' or not integer(repair.copper) or not integer(repair.count) then
            repair = { copper = 0, count = 0, firstAt = at }
            entry.repair = repair
        end
        repair.copper, repair.count, repair.lastAt = repair.copper + items[1].copper, repair.count + 1, at
        if ns.EconomyView then ns.EconomyView.Refresh() end
        return
    end
    if type(entry[kind]) ~= 'table' then entry[kind] = {} end
    local totals = entry[kind]
    for _, item in ipairs(items) do
        local row = totals[item.itemID]
        if type(row) ~= 'table' or not integer(row.units) or not integer(row.copper) or not integer(row.stacks) then
            row = { units = 0, copper = 0, stacks = 0, firstAt = at }
            totals[item.itemID] = row
        end
        row.units, row.copper, row.stacks, row.lastAt =
            row.units + item.quantity, row.copper + item.copper, row.stacks + 1, at
    end
    if ns.EconomyView then ns.EconomyView.Refresh() end
end

local function match(before, after, balance)
    local delta = after.money - balance
    if delta > 0 then return 'sale', sold(before.rows, after.rows, delta) end
    if delta < 0 then return 'buyback', boughtBack(before.rows, after.rows, -delta) end
end

local function confirm(session, kind, before, after, items, event, via)
    local revision = walletRevision
    local function settled()
        if revision ~= walletRevision or lootOwnsWallet() then
            log('overlapping-credit', before, after, nil, event)
            return
        end
        log(kind, before, after, items, event, via)
        record(session, kind, items)
    end
    -- The wallet and the explicit quest reward may arrive in either order within the same event batch.
    if C_Timer and C_Timer.After then C_Timer.After(0, settled) else settled() end
end

-- Advance the baseline only after the wallet and list agree, or after the unsettled batch has expired.
local function reconcile(session, after, final, event)
    local before = session.baseline
    if not before then
        session.baseline = after
        log('baseline', nil, after, nil, event)
        return true
    end
    if sameList(before.rows, after.rows) then
        if after.money == before.money then
            session.balances = nil
            return true
        end
        -- The wallet fell by exactly what "repair all" fell by: a repair, whatever else happens at the merchant.
        local spent = before.money - after.money
        if spent > 0 and before.repair and after.repair and before.repair - after.repair == spent then
            session.baseline, session.balances = after, nil
            confirm(session, 'repair', before, after, { { copper = spent } }, event)
            return true
        end
        if not final then
            -- Wallet-only changes still have the same buyback rows. A purchase can precede a sale.
            session.balances = session.balances or {}
            local balances = session.balances
            if balances[#balances] ~= after.money then
                balances[#balances + 1] = after.money
                if #balances > BUYBACK_CAPACITY then table.remove(balances, 1) end
            end
        end
    else
        local kind, items = match(before, after, before.money)
        local matchedBalance, ambiguous = items and before.money or nil, false
        for _, balance in ipairs(session.balances or {}) do
            local nextKind, nextItems = match(before, after, balance)
            if nextItems and matchedBalance ~= balance then
                if matchedBalance then ambiguous = true; break end
                kind, items, matchedBalance = nextKind, nextItems, balance
            end
        end
        if items and not ambiguous then
            session.baseline, session.balances = after, nil
            confirm(session, kind, { rows = before.rows, money = matchedBalance }, after, items, event)
            return true
        end
    end
    if not final then return false end
    session.baseline, session.balances = after, nil
    -- The buyback list could not prove it (Sell All Junk Items can sell more stacks than it holds): the bags may.
    local items = bagSale(before.bags, after.bags, after.money - before.money)
    if items then
        confirm(session, 'sale', before, after, items, event, 'bags')
        return true
    end
    log('unmatched', before, after, nil, event)
    return true
end

function Vendor.Initialize()
    if Vendor.Handle then return end
    if type(ns.db.vendorSales) ~= 'table' then ns.db.vendorSales = {} end
    if type(ns.db.vendorLog) ~= 'table' then ns.db.vendorLog = {} end
    local active
    log('started')
    function Vendor.ExcludeWalletChanges()
        walletRevision = walletRevision + 1
        if active then
            active.baseline, active.latest, active.balances, active.timer = nil, nil, nil, nil
        end
    end
    local function observe(session, final, event)
        if lootOwnsWallet() then Vendor.ExcludeWalletChanges(); return end
        local ok, snapshot, reason, slot = pcall(readSnapshot)
        if ok and snapshot then
            session.latest = snapshot
            if reconcile(session, snapshot, final, event) then session.timer = nil; return end
        else
            log('read-failed', session.baseline, nil, nil, event, ok and reason or 'buyback API call failed', slot)
            if final then
                session.baseline, session.latest, session.timer, session.balances = nil, nil, nil, nil
                return
            end
        end
        if session.timer then return end
        local token = {}
        session.timer = token
        local function settle()
            if active == session and session.timer == token then observe(session, true, 'settle') end
        end
        if C_Timer and C_Timer.After then C_Timer.After(SETTLE_DELAY, settle) else settle() end
    end
    local function handle(event)
        if active and lootOwnsWallet() then Vendor.ExcludeWalletChanges() end
        if event == 'MERCHANT_SHOW' then
            log('opened', nil, nil, nil, event)
            local ok, realm = pcall(GetRealmName)
            -- Forever can return an empty realm name. Economy reads that same key.
            if not ok or not ns.IsPublic(realm) or type(realm) ~= 'string' then
                log('unavailable', nil, nil, nil, event, 'realm unavailable')
                return
            end
            if not ns.IsPublic(ns.characterID) or not ns.characterID then
                log('unavailable', nil, nil, nil, event, 'character ID unavailable')
                return
            end
            active = active or { realm = realm, character = ns.characterID }
        elseif event == 'MERCHANT_CLOSED' then
            local session = active
            active = nil
            if session and session.latest then
                local ok, snapshot = pcall(readSnapshot)
                -- A populated list may expose the final sale here. An empty list can be caused by closing.
                if not ok or not snapshot or (#snapshot.rows == 0 and #session.latest.rows > 0) then
                    local money = readMoney()
                    local okBags, bags = pcall(readBags)
                    snapshot = money and { rows = session.latest.rows, money = money, bags = okBags and bags or nil } or nil
                end
                if snapshot then reconcile(session, snapshot, true, event) end
            elseif session then
                log('closed', nil, nil, nil, event, 'no readable buyback snapshot')
            end
            return
        elseif event == 'PLAYER_LEAVING_WORLD' then
            active = nil
            return
        end
        if active then observe(active, false, event) end
    end
    function Vendor.Handle(event)
        local ok, errorText = pcall(handle, event)
        if not ok then
            local reason = ns.IsPublic(errorText) and type(errorText) == 'string' and errorText or 'merchant callback failed'
            log('handler-error', nil, nil, nil, event, reason)
        end
    end
end
