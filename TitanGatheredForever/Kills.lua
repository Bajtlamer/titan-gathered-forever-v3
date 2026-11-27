local _, ns = ...
-- Creature kills per character. The game keeps no count of which creatures a character killed, so the addon counts
-- the killing blows reported by PARTY_KILL: the player's own and the pet's as "yours", those of party or raid members
-- as "group". The combat log is restricted on Forever and is not used. A kill whose identity the client hides
-- (secret GUIDs) is only counted as restricted, never guessed.
--
-- Saved as ns.db.kills[realm][characterID] = { restricted = n, npcs = { [npcID] = entry } } with entry
-- { name, kills, group, xp, xpKills, minLevel, maxLevel, classification, firstAt, lastAt, zones = { [mapID] = n },
-- looted, moneyCorpses, copper, drops = { [itemID] = corpses }, quantities = { [itemID] = n } }. Loot is what the loot
-- window of a dead creature showed the first time it was opened, taken or not.
-- Rare creatures seen are kept for the realm: ns.db.rares[realm][npcID] = { name, level, classification, sightings,
-- firstAt, lastAt, spots = { { mapID, x, y, at } } } (no spots inside instances).
local Kills = { cache = {}, cached = 0, seen = {}, waiting = {}, looted = {}, lootedCount = 0, sighted = {}, sightedCount = 0 }
ns.Kills = Kills

local MAX_CACHE = 300           -- recently seen creatures kept for their name and level
local XP_AFTER = 1.5            -- seconds after a kill in which an experience gain is attributed to it
local XP_BEFORE = 0.5           -- the gain can also arrive just before the kill event
local QUEST_XP = 1.0            -- an experience gain this close to a quest turn-in belongs to the quest

local function integer(value)
    return type(value) == 'number' and value >= 0 and value < math.huge and value == math.floor(value)
end
local function public(value, kind) return ns.IsPublic(value) and type(value) == kind end
local function call(fn, ...)
    if type(fn) ~= 'function' then return end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end
local function now() return GetTime and GetTime() or 0 end

-- The creature ID inside a GUID: Creature-0-server-instance-zone-npcID-spawn. Players, pets and objects give nil.
function Kills.NpcID(guid)
    if not public(guid, 'string') then return end
    local kind, id = guid:match('^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-')
    if kind ~= 'Creature' and kind ~= 'Vehicle' then return end
    id = tonumber(id)
    if id and id > 0 then return id end
end

local function describe(unit)
    local name = call(UnitName, unit)
    if not public(name, 'string') or name == '' then return end
    local info = { name = name }
    local level = call(UnitLevel, unit)
    if public(level, 'number') and integer(level) and level > 0 then info.level = level end
    local classification = call(UnitClassification, unit)
    if public(classification, 'string') and classification ~= '' then info.classification = classification end
    return info
end

-- Remembers the name and level of a creature the player has seen, so a kill can be named after the unit is gone.
function Kills.Remember(unit)
    local guid = call(UnitGUID, unit)
    if not Kills.NpcID(guid) then return end
    local info = describe(unit)
    if not info then return end
    if not Kills.cache[guid] then
        Kills.cached = Kills.cached + 1
        if Kills.cached > MAX_CACHE then Kills.cache, Kills.cached = {}, 1 end
    end
    Kills.cache[guid] = info
    if info.classification == 'rare' or info.classification == 'rareelite' then Kills.Sighting(guid, info) end
end

local MAX_SPOTS = 10
-- A rare creature came into view: one sighting per spawn, with the player's position as the place.
function Kills.Sighting(guid, info)
    if Kills.sighted[guid] then return end
    local realm = GetRealmName and GetRealmName()
    local npcID = Kills.NpcID(guid)
    if not npcID or not public(realm, 'string') or not ns.db then return end
    Kills.sightedCount = Kills.sightedCount + 1
    if Kills.sightedCount > MAX_CACHE then Kills.sighted, Kills.sightedCount = {}, 1 end
    Kills.sighted[guid] = true
    local store = ns.db.rares
    if type(store) ~= 'table' then store = {}; ns.db.rares = store end
    if type(store[realm]) ~= 'table' then store[realm] = {} end
    local entry = store[realm][npcID]
    if type(entry) ~= 'table' then entry = { sightings = 0 }; store[realm][npcID] = entry end
    if not integer(entry.sightings) then entry.sightings = 0 end
    local at = time()
    entry.name, entry.classification = info.name, info.classification
    if info.level then entry.level = info.level end
    entry.sightings = entry.sightings + 1
    entry.firstAt = integer(entry.firstAt) and entry.firstAt or at
    entry.lastAt = at
    local mapID, x, y
    if ns.ListWindow then mapID, x, y = ns.ListWindow.PlayerSpot() end
    if mapID and x then
        if type(entry.spots) ~= 'table' then entry.spots = {} end
        local merged
        for _, spot in ipairs(entry.spots) do
            if spot.mapID == mapID and math.abs(spot.x - x) < 0.02 and math.abs(spot.y - y) < 0.02 then
                spot.at, spot.count, merged = at, (spot.count or 1) + 1, true
                break
            end
        end
        if not merged then
            table.insert(entry.spots, 1, { mapID = mapID, x = x, y = y, at = at, count = 1 })
            while #entry.spots > MAX_SPOTS do table.remove(entry.spots) end
        end
        if ns.Map and ns.Map.Update then ns.Map.Update() end
    end
    if ns.KillsView then ns.KillsView.Refresh() end
end

local units = { 'target', 'mouseover', 'focus', 'softenemy', 'softinteract', 'pettarget' }
local function lookup(guid)
    for _, unit in ipairs(units) do
        local candidate = call(UnitGUID, unit)
        if ns.IsPublic(candidate) and candidate == guid then
            local info = describe(unit)
            if info then return info end
        end
    end
    for index = 1, 40 do
        local unit = 'nameplate' .. index
        local candidate = call(UnitGUID, unit)
        if ns.IsPublic(candidate) and candidate == guid then
            local info = describe(unit)
            if info then return info end
        end
    end
    return Kills.cache[guid]
end

local function context()
    local realm, character = GetRealmName and GetRealmName(), ns.characterID
    if not public(realm, 'string') or not public(character, 'string') or not ns.db then return end
    return realm, character
end

local function record(realm, character)
    local store = ns.db.kills
    if type(store) ~= 'table' then store = {}; ns.db.kills = store end
    local characters = store[realm]
    if type(characters) ~= 'table' then characters = {}; store[realm] = characters end
    local entry = characters[character]
    if type(entry) ~= 'table' then entry = {}; characters[character] = entry end
    if type(entry.npcs) ~= 'table' then entry.npcs = {} end
    if not integer(entry.restricted) then entry.restricted = 0 end
    return entry
end

local function playerMap()
    local mapID = C_Map and call(C_Map.GetBestMapForUnit, 'player')
    if public(mapID, 'number') and integer(mapID) and mapID > 0 then return mapID end
end

function Kills.Entry(data, npcID)
    local entry = data.npcs[npcID]
    if type(entry) ~= 'table' then entry = { kills = 0, group = 0 }; data.npcs[npcID] = entry end
    if not integer(entry.kills) then entry.kills = 0 end
    if not integer(entry.group) then entry.group = 0 end
    return entry
end

local function isMine(guid)
    for _, unit in ipairs({ 'player', 'pet' }) do
        local own = call(UnitGUID, unit)
        if ns.IsPublic(own) and own == guid then return true end
    end
    return false
end

local function attribute(entry, amount)
    entry.xp = (integer(entry.xp) and entry.xp or 0) + amount
    entry.xpKills = (integer(entry.xpKills) and entry.xpKills or 0) + 1
end

function Kills.PartyKill(attackerGUID, targetGUID)
    local realm, character = context()
    if not realm then return end
    local data = record(realm, character)
    if not ns.IsPublic(attackerGUID) or not ns.IsPublic(targetGUID) then
        data.restricted = data.restricted + 1
        return
    end
    local npcID = Kills.NpcID(targetGUID)
    if not npcID or Kills.seen[targetGUID] then return end
    Kills.seenCount = (Kills.seenCount or 0) + 1
    if Kills.seenCount > MAX_CACHE then Kills.seen, Kills.seenCount = {}, 1 end
    Kills.seen[targetGUID] = true
    local entry = Kills.Entry(data, npcID)
    local info = lookup(targetGUID)
    if info then
        entry.name = info.name
        if info.level then
            if not integer(entry.minLevel) or info.level < entry.minLevel then entry.minLevel = info.level end
            if not integer(entry.maxLevel) or info.level > entry.maxLevel then entry.maxLevel = info.level end
        end
        if info.classification then entry.classification = info.classification end
    end
    if isMine(attackerGUID) then
        entry.kills = entry.kills + 1
        if ns.Journal then ns.Journal.Count('kills') end
    else entry.group = entry.group + 1 end
    local at = time()
    entry.firstAt = integer(entry.firstAt) and entry.firstAt or at
    entry.lastAt = at
    local mapID = playerMap()
    if mapID then
        if type(entry.zones) ~= 'table' then entry.zones = {} end
        entry.zones[mapID] = (integer(entry.zones[mapID]) and entry.zones[mapID] or 0) + 1
    end
    -- Experience: a gain that arrived just before this kill is its own; otherwise wait for the next one.
    local clock, gain = now(), Kills.gain
    Kills.gain = nil
    if gain and clock - gain.at <= XP_BEFORE and #Kills.waiting == 0 then
        attribute(entry, gain.amount)
        Kills.Source(gain.amount, 'kill', gain.level)
    else
        if gain then Kills.Source(gain.amount, 'other', gain.level) end
        Kills.waiting[#Kills.waiting + 1] = { entry = entry, at = clock }
    end
    if ns.KillsView then ns.KillsView.Refresh() end
end

-- Reads the experience of the player. The first reading only sets the baseline.
function Kills.ReadExperience()
    local xp, maximum, level = call(UnitXP, 'player'), call(UnitXPMax, 'player'), call(UnitLevel, 'player')
    if not (public(xp, 'number') and public(maximum, 'number') and public(level, 'number')) then
        Kills.xp = nil
        return
    end
    local previous = Kills.xp
    Kills.xp = { xp = xp, maximum = maximum, level = level }
    if not previous then return end
    local gained
    if level == previous.level then gained = xp - previous.xp
    elseif level == previous.level + 1 then gained = (previous.maximum - previous.xp) + xp end
    if not gained or gained <= 0 or not integer(gained) then return end
    Kills.Gained(gained, previous.level)
end

-- Where an experience gain came from, for the levels journal: kill, quest or other.
function Kills.Source(amount, source, level)
    if ns.Journal then ns.Journal.Experience(amount, source, level) end
end

-- One experience gain. It goes to the single kill waiting for it; with two or more kills waiting nobody can tell
-- which kill gave how much, so none of them gets it.
-- A gain that no kill claimed shortly after it came from something else (exploration, gathering, a reward).
function Kills.Gained(amount, level)
    local clock = now()
    if Kills.questAt and clock - Kills.questAt <= QUEST_XP then
        Kills.questAt = nil
        Kills.Source(amount, 'quest', level)
        return
    end
    local live = {}
    for _, waiting in ipairs(Kills.waiting) do
        if clock - waiting.at <= XP_AFTER then live[#live + 1] = waiting end
    end
    Kills.waiting = {}
    if #live >= 1 then
        if #live == 1 then attribute(live[1].entry, amount) end
        Kills.Source(amount, 'kill', level)
        if ns.KillsView then ns.KillsView.Refresh() end
        return
    end
    if Kills.gain then Kills.Source(Kills.gain.amount, 'other', Kills.gain.level) end
    local gain = { amount = amount, at = clock, level = level }
    Kills.gain = gain
    if C_Timer and C_Timer.After then
        C_Timer.After(XP_BEFORE + 0.1, function()
            if Kills.gain == gain then Kills.gain = nil; Kills.Source(gain.amount, 'other', gain.level) end
        end)
    end
end

-- A quest turn-in with an experience reward: the next gain is the quest's.
function Kills.QuestExperience(xp)
    if public(xp, 'number') and xp > 0 then Kills.questAt = now() end
end

local function isDead(guid)
    if Kills.seen[guid] then return true end
    for _, unit in ipairs(units) do
        local candidate = call(UnitGUID, unit)
        if ns.IsPublic(candidate) and candidate == guid then
            local dead = call(UnitIsDead, unit)
            return ns.IsPublic(dead) and dead == true
        end
    end
    return false
end

local function moneySlot(slot)
    local moneyType = Enum and Enum.LootSlotType and Enum.LootSlotType.Money or LOOT_SLOT_MONEY
    if not moneyType or type(GetLootSlotType) ~= 'function' then return nil end
    local kind = call(GetLootSlotType, slot)
    if not ns.IsPublic(kind) then return nil end
    return kind == moneyType
end

-- The loot window of one or more dead creatures opened. slots come from the gathering reader (itemID, sources,
-- sourceQuantities, quantity, unreadableItem). Each corpse counts once, the first time its window opens; a corpse with
-- an unreadable slot is left out rather than counted with a gap. Pickpocketing (a living creature) is not loot.
function Kills.Loot(slots)
    local realm, character = context()
    if not realm or type(slots) ~= 'table' then return end
    local corpses = {}
    for _, slot in ipairs(slots) do
        local sources = slot.sources or {}
        local isMoney = moneySlot(slot.slot)
        for _, guid in ipairs(sources) do
            local npcID = Kills.NpcID(guid)
            if npcID and not Kills.looted[guid] and isDead(guid) then
                local corpse = corpses[guid]
                if not corpse then corpse = { npcID = npcID, items = {}, copper = 0 }; corpses[guid] = corpse end
                local quantity = slot.sourceQuantities and slot.sourceQuantities[guid]
                if not quantity and #sources == 1 then quantity = slot.quantity end
                if isMoney == nil and not slot.itemID then corpse.broken = true
                elseif isMoney then
                    if integer(quantity) then corpse.copper = corpse.copper + quantity else corpse.moneyUnknown = true end
                elseif slot.itemID and not slot.unreadableItem then
                    corpse.items[slot.itemID] = (corpse.items[slot.itemID] or 0) + (integer(quantity) and quantity or 1)
                else corpse.broken = true end
            end
        end
    end
    local data, changed = nil, false
    for guid, corpse in pairs(corpses) do
        if not corpse.broken then
            Kills.lootedCount = Kills.lootedCount + 1
            if Kills.lootedCount > MAX_CACHE then Kills.looted, Kills.lootedCount = {}, 1 end
            Kills.looted[guid] = true
            data = data or record(realm, character)
            local entry = Kills.Entry(data, corpse.npcID)
            entry.looted = (integer(entry.looted) and entry.looted or 0) + 1
            if not corpse.moneyUnknown then
                entry.moneyCorpses = (integer(entry.moneyCorpses) and entry.moneyCorpses or 0) + 1
                entry.copper = (integer(entry.copper) and entry.copper or 0) + corpse.copper
            end
            if type(entry.drops) ~= 'table' then entry.drops = {} end
            if type(entry.quantities) ~= 'table' then entry.quantities = {} end
            for itemID, quantity in pairs(corpse.items) do
                entry.drops[itemID] = (integer(entry.drops[itemID]) and entry.drops[itemID] or 0) + 1
                entry.quantities[itemID] = (integer(entry.quantities[itemID]) and entry.quantities[itemID] or 0) + quantity
            end
            if not entry.name then
                local info = Kills.cache[guid]
                if info then entry.name = info.name end
            end
            changed = true
        end
    end
    if changed and ns.KillsView then ns.KillsView.Refresh() end
end

-- Rows for the list: one per creature, summed over the chosen character or over all characters of the realm.
function Kills.Rows(store, realm, character)
    local characters = type(store) == 'table' and store[realm]
    local rows, byID, restricted = {}, {}, 0
    if type(characters) ~= 'table' then return rows, restricted end
    for id, data in pairs(characters) do
        if (not character or id == character) and type(data) == 'table' then
            if integer(data.restricted) then restricted = restricted + data.restricted end
            for npcID, entry in pairs(type(data.npcs) == 'table' and data.npcs or {}) do
                if type(npcID) == 'number' and type(entry) == 'table' and integer(entry.kills) and integer(entry.group) then
                    local row = byID[npcID]
                    if not row then
                        row = { npcID = npcID, kills = 0, group = 0, xp = 0, xpKills = 0, zones = {}, looted = 0,
                            moneyCorpses = 0, copper = 0, drops = {}, quantities = {} }
                        byID[npcID] = row
                        rows[#rows + 1] = row
                    end
                    row.kills, row.group = row.kills + entry.kills, row.group + entry.group
                    if integer(entry.xp) and integer(entry.xpKills) then
                        row.xp, row.xpKills = row.xp + entry.xp, row.xpKills + entry.xpKills
                    end
                    local newer = integer(entry.lastAt) and (not row.lastAt or entry.lastAt > row.lastAt)
                    if newer then row.lastAt = entry.lastAt end
                    if type(entry.name) == 'string' and (newer or not row.name) then row.name = entry.name end
                    if type(entry.classification) == 'string' and (newer or not row.classification) then
                        row.classification = entry.classification
                    end
                    if integer(entry.firstAt) and (not row.firstAt or entry.firstAt < row.firstAt) then row.firstAt = entry.firstAt end
                    if integer(entry.minLevel) and (not row.minLevel or entry.minLevel < row.minLevel) then row.minLevel = entry.minLevel end
                    if integer(entry.maxLevel) and (not row.maxLevel or entry.maxLevel > row.maxLevel) then row.maxLevel = entry.maxLevel end
                    if integer(entry.looted) then row.looted = row.looted + entry.looted end
                    if integer(entry.moneyCorpses) and integer(entry.copper) then
                        row.moneyCorpses, row.copper = row.moneyCorpses + entry.moneyCorpses, row.copper + entry.copper
                    end
                    for itemID, n in pairs(type(entry.drops) == 'table' and entry.drops or {}) do
                        if type(itemID) == 'number' and integer(n) then
                            row.drops[itemID] = (row.drops[itemID] or 0) + n
                            local q = type(entry.quantities) == 'table' and entry.quantities[itemID]
                            row.quantities[itemID] = (row.quantities[itemID] or 0) + (integer(q) and q or n)
                        end
                    end
                    for mapID, count in pairs(type(entry.zones) == 'table' and entry.zones or {}) do
                        if type(mapID) == 'number' and integer(count) then row.zones[mapID] = (row.zones[mapID] or 0) + count end
                    end
                end
            end
        end
    end
    for _, row in ipairs(rows) do
        row.total = row.kills + row.group
        local best, most = nil, 0
        for mapID, count in pairs(row.zones) do
            if count > most or (count == most and best and mapID < best) then best, most = mapID, count end
        end
        row.mapID = best
    end
    return rows, restricted
end

-- One row per item and creature: how often it was in the loot of that creature's corpses.
function Kills.Drops(rows)
    local drops = {}
    for _, row in ipairs(rows) do
        for itemID, corpses in pairs(row.drops) do
            drops[#drops + 1] = { npcID = row.npcID, name = row.name, itemID = itemID, corpses = corpses,
                quantity = row.quantities[itemID] or corpses, looted = row.looted, mapID = row.mapID,
                chance = row.looted > 0 and corpses / row.looted or nil }
        end
    end
    return drops
end

-- One row per rare creature seen on the realm, with the kills of all its characters.
function Kills.Rares(rareStore, killStore, realm, character)
    local rows = {}
    local rares = type(rareStore) == 'table' and rareStore[realm]
    if type(rares) ~= 'table' then return rows end
    local killed = {}
    for _, row in ipairs((Kills.Rows(killStore, realm, character))) do killed[row.npcID] = row end
    for npcID, entry in pairs(rares) do
        if type(npcID) == 'number' and type(entry) == 'table' and integer(entry.sightings) then
            local spot = type(entry.spots) == 'table' and entry.spots[1] or nil
            local kills = killed[npcID]
            rows[#rows + 1] = { npcID = npcID, name = entry.name, level = entry.level, classification = entry.classification,
                sightings = entry.sightings, firstAt = entry.firstAt, lastAt = entry.lastAt,
                spots = type(entry.spots) == 'table' and entry.spots or {}, mapID = spot and spot.mapID,
                x = spot and spot.x, y = spot and spot.y, kills = kills and kills.kills or 0, group = kills and kills.group or 0 }
        end
    end
    return rows
end
