local _, ns = ...
-- The character journal: what the game shows only as a current value, or not at all, kept as history.
--   levels[realm][character][level] = { reachedAt, played, kill, quest, other, kills, quests, deaths, partial }
--     played is the time logged in at that level, measured by the addon; partial marks a level that was already
--     under way when recording began, so its time and experience are a lower bound.
--   deaths[realm][character] = { { at, mapID, x, y, level, place, killer, spell }, ... } (newest last, at most
--     MAX_DEATHS); the killer is the source of the lethal blow in the death recap, when the client gives it.
--   reputation[realm][character][factionID] = { name, gained, lost, gains, lastAt, reaction, days = { [date] = n } }
local Journal = { factions = {} }
ns.Journal = Journal

local MAX_DEATHS, MAX_DAYS = 500, 60

local function integer(value)
    return type(value) == 'number' and value >= 0 and value < math.huge and value == math.floor(value)
end
local function public(value, kind) return ns.IsPublic(value) and type(value) == kind end
local function call(fn, ...)
    if type(fn) ~= 'function' then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function now() return GetTime and GetTime() or 0 end

local function bucket(key)
    local realm, character = GetRealmName and GetRealmName(), ns.characterID
    if not public(realm, 'string') or not public(character, 'string') or not ns.db then return end
    local store = ns.db[key]
    if type(store) ~= 'table' then store = {}; ns.db[key] = store end
    if type(store[realm]) ~= 'table' then store[realm] = {} end
    local own = store[realm][character]
    if type(own) ~= 'table' then own = {}; store[realm][character] = own end
    return own
end

local function playerLevel()
    local level = call(UnitLevel, 'player')
    if public(level, 'number') and integer(level) and level > 0 then return level end
end

local function levelEntry(level, partialIfNew)
    local levels = level and bucket('levels')
    if not levels then return end
    local entry = levels[level]
    if type(entry) ~= 'table' then
        entry = { played = 0, kill = 0, quest = 0, other = 0, kills = 0, quests = 0, deaths = 0, partial = partialIfNew or nil }
        levels[level] = entry
    end
    for _, key in ipairs({ 'played', 'kill', 'quest', 'other', 'kills', 'quests', 'deaths' }) do
        if not integer(entry[key]) then entry[key] = 0 end
    end
    return entry
end

-- Starts measuring the time at the current level (login, after a loading screen).
function Journal.Start()
    Journal.level = playerLevel()
    if not Journal.level then Journal.mark = nil; return end
    levelEntry(Journal.level, true)
    Journal.mark = now()
end

-- Adds the time since the last mark to the current level.
function Journal.Flush()
    if not Journal.mark or not Journal.level then return end
    local entry = levelEntry(Journal.level, true)
    local clock = now()
    if entry and clock >= Journal.mark then entry.played = entry.played + math.floor(clock - Journal.mark + 0.5) end
    Journal.mark = clock
end

function Journal.Stop()
    Journal.Flush()
    Journal.mark = nil
end

function Journal.LevelUp(level)
    if not (public(level, 'number') and integer(level) and level > 0) then level = playerLevel() end
    if not level then return end
    Journal.Flush()
    Journal.level = level
    local entry = levelEntry(level, false)
    if entry and not integer(entry.reachedAt) then entry.reachedAt = time(); entry.partial = nil end
    Journal.mark = now()
    if ns.JournalView then ns.JournalView.Refresh() end
end

-- Experience by source: 'kill', 'quest' or 'other', at the level it was earned on.
function Journal.Experience(amount, source, level)
    if not integer(amount) or amount <= 0 then return end
    local entry = levelEntry(level or Journal.level or playerLevel(), true)
    if not entry or not entry[source] then return end
    entry[source] = entry[source] + amount
end

-- Counts an event at the current level: 'kills', 'quests' or 'deaths'.
function Journal.Count(key)
    local entry = levelEntry(Journal.level or playerLevel(), true)
    if entry and entry[key] then entry[key] = entry[key] + 1 end
end

local function place()
    local inside, kind = call(IsInInstance)
    if not ns.IsPublic(inside) or not ns.IsPublic(kind) then return nil end
    if not inside then return 'world' end
    if type(kind) == 'string' then return kind end
end

-- The lethal blow of the death recap: the last hit with a readable overkill and source name.
function Journal.Killer(events)
    if type(events) ~= 'table' then return end
    local killer, spell
    local function inspect(entry)
        if type(entry) ~= 'table' then return end
        local overkill, source = entry.overkill, entry.sourceName
        if public(overkill, 'number') and overkill >= 0 and public(source, 'string') and source ~= '' then
            killer = source
            spell = public(entry.spellName, 'string') and entry.spellName ~= '' and entry.spellName or nil
        end
    end
    for _, entry in ipairs(events) do
        if type(entry) == 'table' and entry.sourceName ~= nil then inspect(entry)
        elseif type(entry) == 'table' then for _, hit in ipairs(entry) do inspect(hit) end end
    end
    return killer, spell
end

function Journal.Died(recap)
    local deaths = bucket('deaths')
    if not deaths then return end
    local mapID, x, y
    if ns.ListWindow then mapID, x, y = ns.ListWindow.PlayerSpot() end
    if not mapID then
        local id = C_Map and call(C_Map.GetBestMapForUnit, 'player')
        if public(id, 'number') then mapID = id end
    end
    local killer, spell = Journal.Killer(recap)
    deaths[#deaths + 1] = { at = time(), mapID = mapID, x = x, y = y, level = playerLevel(), place = place(),
        killer = killer, spell = spell }
    while #deaths > MAX_DEATHS do table.remove(deaths, 1) end
    Journal.Count('deaths')
    if ns.JournalView then ns.JournalView.Refresh() end
end

-- Reputation: the game shows the standing now; the gains are found by comparing two readings of every faction.
local function factionData(index, byID)
    local api = C_Reputation
    if not api then return end
    local data = call(byID and api.GetFactionDataByID or api.GetFactionDataByIndex, index)
    if type(data) ~= 'table' then return end
    local id, name, standing = data.factionID, data.name, data.currentStanding
    if not (public(id, 'number') and public(name, 'string') and public(standing, 'number')) then return end
    if data.isHeader == true and data.isHeaderWithRep ~= true then return end
    local reaction = data.reaction
    return id, { name = name, standing = standing, reaction = public(reaction, 'number') and reaction or nil }
end

local function today() return date and date('%Y-%m-%d') or 'unknown' end

function Journal.ScanFactions()
    local api = C_Reputation
    if not api then return end
    local found = {}
    local count = call(api.GetNumFactions)
    if public(count, 'number') then
        for index = 1, count do
            local id, data = factionData(index, false)
            if id then found[id] = data end
        end
    end
    for id in pairs(Journal.factions) do
        if not found[id] then
            local same, data = factionData(id, true)
            if same then found[id] = data end
        end
    end
    local store, changed
    for id, data in pairs(found) do
        local previous = Journal.factions[id]
        if previous and data.standing ~= previous then
            store = store or bucket('reputation')
            if not store then break end
            local entry = store[id]
            if type(entry) ~= 'table' then entry = { gained = 0, lost = 0, gains = 0 }; store[id] = entry end
            for _, key in ipairs({ 'gained', 'lost', 'gains' }) do if not integer(entry[key]) then entry[key] = 0 end end
            local delta = data.standing - previous
            if delta > 0 then entry.gained, entry.gains = entry.gained + delta, entry.gains + 1
            else entry.lost = entry.lost - delta end
            entry.name, entry.reaction, entry.lastAt = data.name, data.reaction, time()
            if type(entry.days) ~= 'table' then entry.days = {} end
            local day = today()
            entry.days[day] = (type(entry.days[day]) == 'number' and entry.days[day] or 0) + delta
            local days = {}
            for key in pairs(entry.days) do days[#days + 1] = key end
            if #days > MAX_DAYS then
                table.sort(days)
                for index = 1, #days - MAX_DAYS do entry.days[days[index]] = nil end
            end
            changed = true
        end
        Journal.factions[id] = data.standing
    end
    if changed and ns.JournalView then ns.JournalView.Refresh() end
end

-- Rows ---------------------------------------------------------------------------------------------------------------

local function characters(key, realm, character)
    local store = ns.db and ns.db[key]
    local realmStore = type(store) == 'table' and store[realm]
    local result = {}
    if type(realmStore) ~= 'table' then return result end
    for id, own in pairs(realmStore) do
        if (not character or id == character) and type(own) == 'table' then result[id] = own end
    end
    return result
end

-- One row per level. With all characters, each character's level is its own row.
function Journal.LevelRows(realm, character)
    local rows = {}
    for id, levels in pairs(characters('levels', realm, character)) do
        for level, entry in pairs(levels) do
            if type(level) == 'number' and type(entry) == 'table' and integer(entry.played) then
                local row = { character = id, level = level, reachedAt = entry.reachedAt, played = entry.played,
                    kill = entry.kill or 0, quest = entry.quest or 0, other = entry.other or 0, kills = entry.kills or 0,
                    quests = entry.quests or 0, deaths = entry.deaths or 0, partial = entry.partial == true }
                if id == ns.characterID and level == Journal.level and Journal.mark then
                    row.played = row.played + math.max(0, math.floor(now() - Journal.mark + 0.5))
                    row.current = true
                end
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

function Journal.DeathRows(realm, character)
    local rows = {}
    for id, deaths in pairs(characters('deaths', realm, character)) do
        for index, entry in ipairs(deaths) do
            if type(entry) == 'table' and integer(entry.at) then
                rows[#rows + 1] = { character = id, index = index, at = entry.at, mapID = entry.mapID, x = entry.x,
                    y = entry.y, level = entry.level, place = entry.place, killer = entry.killer, spell = entry.spell }
            end
        end
    end
    return rows
end

local function sinceDays(days, count)
    if type(days) ~= 'table' or not date or not time then return 0 end
    local total, clock = 0, time()
    for offset = 0, count - 1 do
        local key = date('%Y-%m-%d', clock - offset * 86400)
        if type(days[key]) == 'number' then total = total + days[key] end
    end
    return total
end

-- One row per faction, summed over the chosen characters.
function Journal.ReputationRows(realm, character)
    local rows, byID = {}, {}
    for _, factions in pairs(characters('reputation', realm, character)) do
        for id, entry in pairs(factions) do
            if type(id) == 'number' and type(entry) == 'table' and integer(entry.gained) then
                local row = byID[id]
                if not row then
                    row = { factionID = id, gained = 0, lost = 0, gains = 0, today = 0, week = 0 }
                    byID[id] = row
                    rows[#rows + 1] = row
                end
                row.gained, row.lost = row.gained + entry.gained, row.lost + (integer(entry.lost) and entry.lost or 0)
                row.gains = row.gains + (integer(entry.gains) and entry.gains or 0)
                row.today, row.week = row.today + sinceDays(entry.days, 1), row.week + sinceDays(entry.days, 7)
                if integer(entry.lastAt) and (not row.lastAt or entry.lastAt > row.lastAt) then
                    row.lastAt, row.reaction = entry.lastAt, entry.reaction
                end
                if type(entry.name) == 'string' then row.name = row.name or entry.name end
            end
        end
    end
    return rows
end
