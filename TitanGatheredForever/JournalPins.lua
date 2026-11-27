local _, ns = ...
-- Map pins from the journal: quest givers where a quest was accepted from them, and the places where rare creatures
-- were seen. They join the trainer and vendor pins (NpcSources.List) on the world map and the minimap. The switches
-- only hide them; recording goes on.
local Pins = {}
ns.JournalPins = Pins

local function realmStore(key)
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db[key]
    local own = type(store) == 'table' and store[realm]
    return type(own) == 'table' and own or {}
end

function Pins.Enabled()
    local settings = ns.settings or {}
    return settings.mapQuestGivers ~= false or settings.mapRareCreatures ~= false
end

local function highlighted(npcID) return ns.NpcSources and ns.NpcSources.IsHighlighted(npcID) end

function Pins.List(mapID)
    local result, settings = {}, ns.settings or {}
    for npcID, giver in pairs(realmStore('questGivers')) do
        if type(giver) == 'table' and giver.mapID == mapID and type(giver.x) == 'number' and type(giver.y) == 'number'
            and (settings.mapQuestGivers ~= false or highlighted(npcID)) then
            result[#result + 1] = { kind = 'QuestGiver', npcID = npcID, mapID = mapID, x = giver.x, y = giver.y }
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
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db.questIncome
    local own = type(store) == 'table' and type(store[realm]) == 'table' and store[realm][ns.characterID]
    local entry = type(own) == 'table' and own[questID]
    if type(entry) ~= 'table' then return 'Not taken by this character' end
    if entry.acceptedAt then return statusLabels.open end
    if (entry.turnIns or 0) > 0 then return statusLabels.completed end
    if (entry.abandons or 0) > 0 then return statusLabels.abandoned end
    return 'Unknown'
end

function Pins.FillTooltip(tip, node)
    local Style = ns.Style
    local small = Style.Small or function() end
    if node.kind == 'QuestGiver' then
        local giver = realmStore('questGivers')[node.npcID] or {}
        tip:AddLine(Style.Text(Style.gold, giver.name or ('Creature ' .. node.npcID)))
        tip:AddLine(Style.Label('Quest giver'))
        local quests = {}
        for questID in pairs(type(giver.quests) == 'table' and giver.quests or {}) do
            if type(questID) == 'number' then quests[#quests + 1] = questID end
        end
        table.sort(quests)
        for index = 1, math.min(10, #quests) do
            local questID = quests[index]
            local title = ns.QuestsView and ns.QuestsView.Title(questID) or ('Quest ' .. questID)
            tip:AddDoubleLine(Style.Value(title or ('Quest ' .. questID)), Style.Label(questStatus(questID)))
            small(tip)
        end
        if #quests > 10 then Style.Note(tip, Style.Label('And ') .. Style.Value(#quests - 10) .. Style.Label(' more.')) end
        Style.Note(tip, Style.Label('Recorded where you accepted a quest from this character.'))
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
