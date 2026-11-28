local _, ns = ...
-- Map pins from the journal: quest givers of quests in progress (gray question mark), at the place where the quest
-- was accepted, and the places where rare creatures were seen. They join the trainer and vendor pins (NpcSources.List) on the world map and the minimap. The switches
-- only hide them; recording goes on.
local Pins = {}
ns.JournalPins = Pins

local function realmStore(key)
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db[key]
    local own = type(store) == 'table' and store[realm]
    return type(own) == 'table' and own or {}
end

-- The quest log changed: redraw the pins once the client has updated it (a burst of events draws once).
function Pins.Redraw()
    if Pins.pending then return end
    Pins.pending = true
    local function draw()
        Pins.pending = nil
        if ns.Map and ns.Map.Update then pcall(ns.Map.Update) end
        if ns.Minimap and ns.Minimap.Update then pcall(ns.Minimap.Update) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, draw) else draw() end
end

function Pins.Enabled()
    local settings = ns.settings or {}
    return settings.mapQuestGivers ~= false or settings.mapRareCreatures ~= false
end

local function highlighted(npcID) return ns.NpcSources and ns.NpcSources.IsHighlighted(npcID) end

-- A quest of this character that is in the quest log now. The quest log answers when it can; otherwise the record
-- (accepted and not yet turned in or abandoned) does.
function Pins.InProgress(questID)
    local api = C_QuestLog
    if api and api.IsOnQuest then
        local ok, on = pcall(api.IsOnQuest, questID)
        if ok and ns.IsPublic(on) and type(on) == 'boolean' then return on end
    end
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db.questIncome
    local own = type(store) == 'table' and type(store[realm]) == 'table' and store[realm][ns.characterID]
    local entry = type(own) == 'table' and own[questID]
    return type(entry) == 'table' and entry.acceptedAt ~= nil
end

-- A quest in the log whose objectives are done: the game marks its turn-in with its own question mark, so the addon
-- draws none for it. Unknown (no answer from the client) counts as not done.
function Pins.Ready(questID)
    local api = C_QuestLog
    if not api then return false end
    for _, name in ipairs({ 'ReadyForTurnIn', 'IsComplete' }) do
        if api[name] then
            local ok, done = pcall(api[name], questID)
            if ok and ns.IsPublic(done) and done == true then return true end
        end
    end
    return false
end

-- In progress and not yet ready to turn in: the quests that get a pin.
function Pins.Pending(questID) return Pins.InProgress(questID) and not Pins.Ready(questID) end

local function openQuests(giver)
    local open = 0
    for questID in pairs(type(giver.quests) == 'table' and giver.quests or {}) do
        if type(questID) == 'number' and Pins.Pending(questID) then open = open + 1 end
    end
    return open
end

-- QUEST_LOG_UPDATE comes often: the pins are redrawn only when a quest of this character entered, left or finished
-- its objectives since the last look.
function Pins.LogChanged()
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db.questIncome
    local own = type(store) == 'table' and type(store[realm]) == 'table' and store[realm][ns.characterID]
    local ids = {}
    for questID, entry in pairs(type(own) == 'table' and own or {}) do
        if type(questID) == 'number' and type(entry) == 'table' and entry.acceptedAt then ids[#ids + 1] = questID end
    end
    table.sort(ids)
    local parts = {}
    for _, questID in ipairs(ids) do parts[#parts + 1] = questID .. (Pins.Pending(questID) and 'p' or 'd') end
    local signature = table.concat(parts, ',')
    if signature ~= Pins.signature then
        local first = Pins.signature == nil
        Pins.signature = signature
        if not first then
            Pins.Redraw()
            if ns.QuestsView and ns.QuestsView.Refresh then ns.QuestsView.Refresh() end
        end
    end
end

-- A quest giver gets a pin only while this character has a quest from them in progress with objectives still open
-- (a finished quest has the game's own question mark at its turn-in): the game's silver question mark
-- with a drop shadow (PinStyle.Badge). The yellow exclamation mark is the game's own sign of a quest that can be taken: the addon never
-- draws it, because it cannot know which quests are still available. A giver shown from the Quests list
-- (highlighted) whose quests are all done gets a plain note icon.
function Pins.List(mapID)
    local result, settings = {}, ns.settings or {}
    for npcID, giver in pairs(realmStore('questGivers')) do
        if type(giver) == 'table' and giver.mapID == mapID and type(giver.x) == 'number' and type(giver.y) == 'number' then
            local open = openQuests(giver)
            local kind
            if open > 0 and (settings.mapQuestGivers ~= false or highlighted(npcID)) then kind = 'QuestGiver'
            elseif highlighted(npcID) then kind = 'QuestGiverPast' end
            if kind then
                result[#result + 1] = { kind = kind, npcID = npcID, mapID = mapID, x = giver.x, y = giver.y, open = open }
            end
        end
    end
    for npcID, rare in pairs(realmStore('rares')) do
        if type(rare) == 'table' and type(rare.spots) == 'table' and (settings.mapRareCreatures ~= false or highlighted(npcID)) then
            for _, spot in ipairs(rare.spots) do
                if spot.mapID == mapID and type(spot.x) == 'number' and type(spot.y) == 'number' then
                    result[#result + 1] = { kind = 'RareCreature', npcID = npcID, mapID = mapID, x = spot.x, y = spot.y,
                        lastSeen = spot.at, count = spot.count }
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.npcID ~= b.npcID then return a.npcID < b.npcID end
        return a.x < b.x
    end)
    return result
end

local statusLabels = { completed = 'Completed', open = 'In progress', abandoned = 'Abandoned or failed' }

local function questStatus(questID)
    if Pins.InProgress(questID) then return Pins.Ready(questID) and 'Ready to turn in' or statusLabels.open end
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db.questIncome
    local own = type(store) == 'table' and type(store[realm]) == 'table' and store[realm][ns.characterID]
    local entry = type(own) == 'table' and own[questID]
    if type(entry) ~= 'table' then return 'Not taken by this character' end
    if (entry.turnIns or 0) > 0 then return statusLabels.completed end
    if (entry.abandons or 0) > 0 then return statusLabels.abandoned end
    return 'Unknown'
end

function Pins.FillTooltip(tip, node)
    local Style = ns.Style
    local small = Style.Small or function() end
    if node.kind == 'QuestGiver' or node.kind == 'QuestGiverPast' then
        local giver = realmStore('questGivers')[node.npcID] or {}
        tip:AddLine(Style.Text(Style.gold, giver.name or ('Creature ' .. node.npcID)))
        tip:AddLine(Style.Label(node.kind == 'QuestGiver' and 'Gave you a quest that is in progress' or 'Quest giver'))
        -- Quests in progress first, then the others, each by ID.
        local quests = {}
        for questID in pairs(type(giver.quests) == 'table' and giver.quests or {}) do
            if type(questID) == 'number' then quests[#quests + 1] = { id = questID, open = Pins.Pending(questID) } end
        end
        table.sort(quests, function(a, b)
            if a.open ~= b.open then return a.open end
            return a.id < b.id
        end)
        for index = 1, math.min(10, #quests) do
            local questID = quests[index].id
            local title = ns.QuestsView and ns.QuestsView.Title(questID) or ('Quest ' .. questID)
            tip:AddDoubleLine(Style.Value(title or ('Quest ' .. questID)), Style.Label(questStatus(questID)))
            small(tip)
        end
        if #quests > 10 then Style.Note(tip, Style.Label('And ') .. Style.Value(#quests - 10) .. Style.Label(' more.')) end
        Style.Note(tip, Style.Label('Recorded where you accepted a quest from this character. Quests that can still be '
            .. 'taken are shown by the game itself.'))
        return
    end
    local rare = realmStore('rares')[node.npcID] or {}
    tip:AddLine(Style.Text(Style.violet, rare.name or ('Creature ' .. node.npcID)))
    tip:AddLine(Style.Label(rare.classification == 'rareelite' and 'Rare elite creature' or 'Rare creature'))
    if rare.level then tip:AddDoubleLine(Style.Label('Level seen'), Style.Value(rare.level)); small(tip) end
    tip:AddDoubleLine(Style.Label('Seen'), Style.Value(rare.sightings or 0) .. Style.Label(' times')); small(tip)
    if node.count then tip:AddDoubleLine(Style.Label('Seen here'), Style.Value(node.count) .. Style.Label(' times')); small(tip) end
    if node.lastSeen and date then
        tip:AddDoubleLine(Style.Label('Last seen here'), Style.Date(date('%Y-%m-%d %H:%M', node.lastSeen))); small(tip)
    end
    Style.Note(tip, Style.Label('Recorded near your position when the creature came into view.'))
end
