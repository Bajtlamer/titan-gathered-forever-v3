local _, ns = ...
local Income = {}
ns.LootIncome = Income

local function integer(value)
    return type(value) == 'number' and value >= 0 and value < math.huge and value == math.floor(value)
end

function Income.Total(store, realm)
    local records = type(store) == 'table' and store[realm]
    local total, pickups = 0, 0
    if type(records) == 'table' then
        for _, entry in pairs(records) do
            if type(entry) == 'table' and integer(entry.copper) and integer(entry.pickups) then
                total, pickups = total + entry.copper, pickups + entry.pickups
            end
        end
    end
    if pickups > 0 then return total, pickups end
end

local function readMoney()
    local ok, value = pcall(GetMoney)
    if ok and ns.IsPublic(value) and integer(value) then return value end
end

local function normalize(label)
    return label:lower():gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
        :gsub('|t([^:|]+):[^|]*|t', '|t%1|t'):gsub('[,%s]+', '')
end

-- Compare the reported amount using the client's own localized money formats.
local function matchesMoney(label, copper)
    local expected = normalize(label)
    local api = C_CurrencyInfo
    local coinText = api and api.GetCoinText or _G.GetCoinText
    local coinTexture = api and api.GetCoinTextureString or _G.GetCoinTextureString
    local ok, value = pcall(coinText, copper, ' ')
    if ok and ns.IsPublic(value) and type(value) == 'string' and normalize(value) == expected then return true end
    ok, value = pcall(coinTexture, copper)
    return ok and ns.IsPublic(value) and type(value) == 'string' and normalize(value) == expected
end

local corpseUnits = { 'mouseover', 'target', 'softinteract' }

local function isCorpse(guid)
    if not guid:match('^Creature%-') then return false end
    for _, unit in ipairs(corpseUnits) do
        local candidate = UnitGUID(unit)
        if ns.IsPublic(candidate) and candidate == guid then
            local dead = UnitIsDead(unit)
            if ns.IsPublic(dead) and type(dead) == 'boolean' then return dead end
        end
    end
end

local function corpseSources(...)
    local count = select('#', ...)
    if count == 0 or count % 2 ~= 0 then return end
    local sources, allDead = {}, true
    for i = 1, count, 2 do
        local guid = select(i, ...)
        if not ns.IsPublic(guid) or type(guid) ~= 'string' or guid == '' then return end
        sources[#sources + 1] = guid
        local dead = isCorpse(guid)
        if dead == false then allDead = false
        elseif dead == nil and allDead then allDead = nil end
    end
    table.sort(sources)
    return table.concat(sources, '|'), allDead
end

local function coinSlot()
    local moneyType = Enum and Enum.LootSlotType and Enum.LootSlotType.Money or LOOT_SLOT_MONEY
    local count, coin = GetNumLootItems()
    if not moneyType or not ns.IsPublic(count) or not integer(count) then return nil, 'unreadable' end
    for slot = 1, count do
        local kind = GetLootSlotType(slot)
        if not ns.IsPublic(kind) then return nil, 'unreadable' end
        if kind == moneyType then
            if coin then return nil, 'multiple' end
            local _, label = GetLootSlotInfo(slot)
            local source, corpse = corpseSources(GetLootSourceInfo(slot))
            coin = { slot = slot, label = ns.IsPublic(label) and type(label) == 'string' and label or nil,
                source = source, corpse = corpse }
        end
    end
    return coin
end

-- READY can precede metadata. Later evidence can fill a gap, but an incompatible snapshot ends attribution.
local function snapshot(session, changedSlot)
    local previous = session.coin
    local ok, coin, status = pcall(coinSlot)
    if status == 'multiple' or (previous and (not ok or status == 'unreadable'
        or (not coin and changedSlot == previous.slot))) then
        session.ambiguous = true
    elseif ok and coin then
        if not previous then session.coin = coin; return end
        if previous.slot ~= coin.slot or (previous.source and coin.source and previous.source ~= coin.source)
            or (previous.label and coin.label and normalize(previous.label) ~= normalize(coin.label))
            or (previous.corpse ~= nil and coin.corpse ~= nil and previous.corpse ~= coin.corpse) then
            session.ambiguous = true
            return
        end
        previous.label, previous.source = previous.label or coin.label, previous.source or coin.source
        if previous.corpse == nil then previous.corpse = coin.corpse end
    end
end

local function observe(session)
    if not session or not session.balance then return end
    local balance = readMoney()
    if not balance then
        session.ambiguous = true
    elseif balance ~= session.balance then
        session.balance, session.changes = balance, session.changes + 1
    end
end

local function complete(session)
    local coin = session.coin
    if session.ambiguous or not session.fromWorld or not coin or not coin.corpse or not coin.label
        or not session.cleared or session.changes ~= 1 or not session.realm or not session.character then return end
    local delta = session.balance - session.before
    if delta <= 0 or not matchesMoney(coin.label, delta) then return end
    local store = ns.db.lootIncome
    local records = store[session.realm]
    if type(records) ~= 'table' then records = {}; store[session.realm] = records end
    local entry = records[session.character]
    if type(entry) ~= 'table' or not integer(entry.copper) or not integer(entry.pickups) then
        entry = { copper = 0, pickups = 0, firstAt = time() }
        records[session.character] = entry
    end
    entry.copper, entry.pickups, entry.lastAt = entry.copper + delta, entry.pickups + 1, time()
    if ns.EconomyView then ns.EconomyView.Refresh() end
end

function Income.Initialize()
    if Income.frame then return end
    if type(ns.db.lootIncome) ~= 'table' then ns.db.lootIncome = {} end
    local frame, active, pending = CreateFrame('Frame')
    Income.frame = frame
    function Income.WalletBusy()
        return pending ~= nil or (active ~= nil and active.coin ~= nil)
    end
    function Income.ExcludeWalletChanges()
        if active then active.ambiguous = true end
        if pending then pending.ambiguous = true end
    end
    local function flush()
        local session = pending
        pending = nil
        if session then complete(session) end
    end
    frame:SetScript('OnEvent', function(_, event, ...)
        if event == 'LOOT_READY' or event == 'LOOT_OPENED' then
            flush()
            if not active then
                local balance = readMoney()
                local realm = GetRealmName and GetRealmName()
                active = { before = balance, balance = balance, changes = 0,
                    realm = ns.IsPublic(realm) and realm or nil, character = ns.characterID }
            end
            if event == 'LOOT_OPENED' then
                local _, fromItem = ...
                local fromWorld = ns.IsPublic(fromItem) and fromItem == false
                if active.fromWorld ~= nil and active.fromWorld ~= fromWorld then active.ambiguous = true end
                active.fromWorld = fromWorld
            end
            snapshot(active)
        elseif event == 'LOOT_SLOT_CHANGED' then
            local slot = ...
            if active and not active.cleared and ns.IsPublic(slot) then
                snapshot(active, slot)
            end
        elseif event == 'LOOT_SLOT_CLEARED' then
            local slot = ...
            if active and active.coin and ns.IsPublic(slot) and active.coin.slot == slot then
                active.cleared = true
                observe(active)
            end
        elseif event == 'PLAYER_MONEY' then
            observe(active or pending)
        elseif event == 'LOOT_CLOSED' then
            local session = active
            active = nil
            if not session or not session.cleared then return end
            observe(session)
            pending = session
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if pending == session then flush() end
                end)
            else
                flush()
            end
        else
            active = nil
            flush()
        end
    end)
    for _, event in ipairs({ 'LOOT_READY', 'LOOT_OPENED', 'LOOT_SLOT_CHANGED', 'LOOT_SLOT_CLEARED', 'LOOT_CLOSED',
        'PLAYER_MONEY', 'PLAYER_ENTERING_WORLD', 'PLAYER_LEAVING_WORLD' }) do
        frame:RegisterEvent(event)
    end
end
