local _, ns = ...
-- Quests offered, accepted, completed and turned in, with the giver and the rewards shown. Quest text is not kept.
local Quest = {}
ns.Quest = Quest

local function record(id, title)
    local entry = ns.Records.Ensure(ns.db.data.quests, id, ns.Records.Context())
    if type(title) == 'string' then entry.title = title end
    if ns.state.areaKey then ns.Records.Count(entry, 'areas', ns.state.areaKey) end
    return entry
end

function Quest.Detail()
    local quest = ns.api.Quest()
    local npc, id, kind = ns.Npc.Contact('npc', 'quest')
    if type(quest) ~= 'table' or not quest.id then return end
    local entry = record(quest.id, quest.title)
    entry.seen = entry.seen + 1
    if id and (npc or kind == 'GameObject') then entry.giver = ns.Privacy.Key(kind, id) end
end

function Quest.Accepted(id)
    if type(id) ~= 'number' then return end
    local entry = record(id)
    entry.accepted = (entry.accepted or 0) + 1
end

function Quest.TurnedIn(id)
    if type(id) ~= 'number' then return end
    local entry = record(id)
    entry.turnedIn = (entry.turnedIn or 0) + 1
end

function Quest.Complete()
    local quest = ns.api.Quest()
    ns.Npc.Contact('npc', 'quest')
    if type(quest) ~= 'table' or not quest.id then return end
    local entry = record(quest.id, quest.title)
    entry.rewards = entry.rewards or {}
    for _, itemID in ipairs(ns.api.QuestChoices()) do entry.rewards[itemID] = true end
end
