local _, ns = ...
local Quest = {}
ns.QuestIncome = Quest

local function integer(value)
    return type(value) == 'number' and value >= 0 and value < math.huge and value == math.floor(value)
end

local function publicInteger(value)
    return ns.IsPublic(value) and integer(value)
end

function Quest.Total(store, realm, character)
    local characters = type(store) == 'table' and store[realm]
    local copper, turnIns = 0, 0
    if type(characters) ~= 'table' then return end
    for id, quests in pairs(characters) do
        if (character == nil or id == character) and type(quests) == 'table' then
            for _, entry in pairs(quests) do
                if type(entry) == 'table' and integer(entry.copper) and integer(entry.turnIns) then
                    copper, turnIns = copper + entry.copper, turnIns + entry.turnIns
                end
            end
        end
    end
    if turnIns > 0 then return copper, turnIns end
end

local function store()
    local realm, character = GetRealmName and GetRealmName(), ns.characterID
    if not ns.IsPublic(realm) or type(realm) ~= 'string' or not ns.IsPublic(character) or not character or not ns.db then return end
    local quests = ns.db.questIncome
    if type(quests) ~= 'table' then quests = {}; ns.db.questIncome = quests end
    local characters = quests[realm]
    if type(characters) ~= 'table' then characters = {}; quests[realm] = characters end
    local own = characters[character]
    if type(own) ~= 'table' then own = {}; characters[character] = own end
    return own
end

-- The entry of one quest. copper and turnIns are always integers, so Total and older versions keep reading it; an
-- entry made when a quest was accepted has no turn-in yet.
local function entryOf(questID)
    local quests = store()
    if not quests then return end
    local entry = quests[questID]
    if type(entry) ~= 'table' or not integer(entry.copper) or not integer(entry.turnIns) then
        entry = { copper = 0, turnIns = 0 }
        quests[questID] = entry
    end
    return entry
end
Quest.Entry = entryOf

local function playerMap()
    local ok, mapID = pcall(function() return C_Map and C_Map.GetBestMapForUnit('player') end)
    if ok and publicInteger(mapID) and mapID > 0 then return mapID end
end
Quest.PlayerMap = playerMap

-- QUEST_TURNED_IN carries the awarded experience and money. A repeatable quest can legitimately send this event again.
-- Unreadable experience stays unknown (xpTurnIns counts the turn-ins whose experience is known).
function Quest.TurnedIn(questID, copper, xp)
    if not publicInteger(questID) or questID == 0 or not publicInteger(copper) then return end
    if copper > 0 then
        ns.VendorSales.ExcludeWalletChanges()
        ns.LootIncome.ExcludeWalletChanges()
    end
    if ns.Kills then ns.Kills.QuestExperience(xp) end
    local entry = entryOf(questID)
    if not entry then return end
    local at = time()
    entry.copper, entry.turnIns, entry.lastAt = entry.copper + copper, entry.turnIns + 1, at
    entry.firstAt = integer(entry.firstAt) and entry.firstAt or at
    if publicInteger(xp) then
        entry.xp = (integer(entry.xp) and entry.xp or 0) + xp
        entry.xpTurnIns = (integer(entry.xpTurnIns) and entry.xpTurnIns or 0) + 1
    end
    entry.mapID = playerMap()
    if integer(entry.acceptedAt) and at >= entry.acceptedAt then
        entry.timeTotal = (integer(entry.timeTotal) and entry.timeTotal or 0) + (at - entry.acceptedAt)
        entry.timed = (integer(entry.timed) and entry.timed or 0) + 1
    end
    entry.acceptedAt = nil
    local npc = Quest.pendingTurnIn
    if npc and (npc.questID == questID or npc.questID == nil) and (GetTime() - npc.at) < 600 then
        entry.turnInNpc, entry.turnInName = npc.npcID, npc.name
    end
    Quest.pendingTurnIn = nil
    local reward = Quest.pendingReward
    if reward and reward.questID == questID then
        if type(entry.rewards) ~= 'table' then entry.rewards = {} end
        for itemID, quantity in pairs(reward.items) do
            entry.rewards[itemID] = (integer(entry.rewards[itemID]) and entry.rewards[itemID] or 0) + quantity
        end
        if reward.choice then entry.chosen = reward.choice end
    end
    Quest.pendingReward = nil
    if ns.Journal then ns.Journal.Count('quests') end
    if ns.EconomyView then ns.EconomyView.Refresh() end
    if ns.QuestsView then ns.QuestsView.Refresh() end
end

-- The game knows which quests are in the log, not when they were taken or where.
function Quest.Accepted(questID)
    if not publicInteger(questID) or questID == 0 then return end
    local entry = entryOf(questID)
    if not entry then return end
    entry.acceptedAt, entry.acceptMapID = time(), playerMap()
    entry.accepts = (integer(entry.accepts) and entry.accepts or 0) + 1
    local giver = Quest.pendingGiver
    if giver and (giver.questID == questID or giver.questID == nil) and (GetTime() - giver.at) < 600 then
        entry.giver = giver.npcID
        Quest.RecordGiver(giver, questID)
    end
    Quest.pendingGiver = nil
    if ns.QuestsView then ns.QuestsView.Refresh() end
end

-- A quest left the log. A turn-in clears acceptedAt first; when the client sends the removal before the turn-in, the
-- check waits a moment, and a quest that is still open then was abandoned (or failed).
function Quest.Removed(questID, replay)
    if not publicInteger(questID) or questID == 0 or (ns.IsPublic(replay) and replay == true) then return end
    local quests = store()
    local entry = quests and quests[questID]
    if type(entry) ~= 'table' or not integer(entry.acceptedAt) then return end
    local accepted, turnIns = entry.acceptedAt, entry.turnIns
    local function decide()
        if entry.acceptedAt ~= accepted or entry.turnIns ~= turnIns then return end
        entry.acceptedAt = nil
        entry.abandons = (integer(entry.abandons) and entry.abandons or 0) + 1
        entry.abandonedAt = time()
        if ns.QuestsView then ns.QuestsView.Refresh() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(1, decide) else decide() end
end

-- The NPC of the open quest window: its creature ID and name, and the player's position (next to it).
local function questNpc()
    local ok, guid = pcall(UnitGUID, 'questnpc')
    local npcID = ok and ns.Kills and ns.Kills.NpcID(guid)
    if not npcID then return end
    local okName, name = pcall(UnitName, 'questnpc')
    if not okName or not ns.IsPublic(name) or type(name) ~= 'string' or name == '' then return end
    local questID
    if GetQuestID then
        local okID, id = pcall(GetQuestID)
        if okID and publicInteger(id) and id > 0 then questID = id end
    end
    return { npcID = npcID, name = name, questID = questID, at = GetTime() }
end

-- QUEST_DETAIL: a quest offered by an NPC. Remembered until it is accepted.
function Quest.Detail()
    local npc = questNpc()
    if npc and ns.ListWindow then
        npc.mapID, npc.x, npc.y = ns.ListWindow.PlayerSpot()
    end
    Quest.pendingGiver = npc
end

-- QUEST_COMPLETE: the reward window of an NPC; the turn-in follows.
function Quest.Complete() Quest.pendingTurnIn = questNpc() end

-- Hooked after GetQuestReward(choice): the items the quest gives, with the chosen one.
function Quest.RewardChosen(choice)
    local questID
    if GetQuestID then
        local ok, id = pcall(GetQuestID)
        if ok and publicInteger(id) and id > 0 then questID = id end
    end
    if not questID then return end
    local items, chosen = {}, nil
    local function add(kind, index)
        local okLink, link = pcall(GetQuestItemLink, kind, index)
        if not okLink or not ns.IsPublic(link) or type(link) ~= 'string' then return end
        local itemID = tonumber(link:match('item:(%d+)'))
        if not itemID then return end
        local okInfo, _, _, count = pcall(GetQuestItemInfo, kind, index)
        local quantity = okInfo and publicInteger(count) and count > 0 and count or 1
        items[itemID] = (items[itemID] or 0) + quantity
        return itemID
    end
    local okRewards, rewards = pcall(GetNumQuestRewards)
    if okRewards and publicInteger(rewards) then for index = 1, rewards do add('reward', index) end end
    local okChoices, choices = pcall(GetNumQuestChoices)
    if okChoices and publicInteger(choices) and choices > 0 and publicInteger(choice) and choice >= 1 and choice <= choices then
        chosen = add('choice', choice)
    end
    Quest.pendingReward = { questID = questID, items = items, choice = chosen }
end

function Quest.HookRewards()
    if Quest.hooked or not hooksecurefunc or type(GetQuestReward) ~= 'function' then return end
    Quest.hooked = true
    hooksecurefunc('GetQuestReward', function(choice) pcall(Quest.RewardChosen, choice) end)
end

-- Quest givers of the realm, with the place where a quest was accepted from them (none inside instances).
function Quest.RecordGiver(giver, questID)
    local realm = GetRealmName and GetRealmName()
    if not ns.IsPublic(realm) or type(realm) ~= 'string' or not ns.db then return end
    local store = ns.db.questGivers
    if type(store) ~= 'table' then store = {}; ns.db.questGivers = store end
    if type(store[realm]) ~= 'table' then store[realm] = {} end
    local entry = store[realm][giver.npcID]
    if type(entry) ~= 'table' then entry = { quests = {} }; store[realm][giver.npcID] = entry end
    if type(entry.quests) ~= 'table' then entry.quests = {} end
    entry.name, entry.lastAt = giver.name, time()
    entry.quests[questID] = true
    if giver.mapID and giver.x then entry.mapID, entry.x, entry.y = giver.mapID, giver.x, giver.y end
    if ns.Map and ns.Map.Update then ns.Map.Update() end
end

function Quest.GiverName(npcID)
    local realm = GetRealmName and GetRealmName()
    local store = ns.db and ns.db.questGivers
    local entry = type(store) == 'table' and type(store[realm]) == 'table' and store[realm][npcID]
    return type(entry) == 'table' and entry.name or nil, type(entry) == 'table' and entry or nil
end

-- One row per quest for the quest log, over one character or all characters of the realm.
function Quest.Rows(store, realm, character)
    local characters = type(store) == 'table' and store[realm]
    local rows, byID = {}, {}
    if type(characters) ~= 'table' then return rows end
    for id, quests in pairs(characters) do
        if (character == nil or character == false or id == character) and type(quests) == 'table' then
            for questID, entry in pairs(quests) do
                if type(questID) == 'number' and type(entry) == 'table' and integer(entry.copper) and integer(entry.turnIns) then
                    local row = byID[questID]
                    if not row then
                        row = { questID = questID, turnIns = 0, copper = 0, xp = 0, xpTurnIns = 0, timeTotal = 0, timed = 0,
                            abandons = 0, accepts = 0, open = 0 }
                        byID[questID] = row
                        rows[#rows + 1] = row
                    end
                    row.turnIns, row.copper = row.turnIns + entry.turnIns, row.copper + entry.copper
                    for _, key in ipairs({ 'xp', 'xpTurnIns', 'timeTotal', 'timed', 'abandons', 'accepts' }) do
                        if integer(entry[key]) then row[key] = row[key] + entry[key] end
                    end
                    if integer(entry.acceptedAt) then
                        row.open = row.open + 1
                        if not row.acceptedAt or entry.acceptedAt > row.acceptedAt then
                            row.acceptedAt, row.acceptMapID = entry.acceptedAt, entry.acceptMapID
                        end
                    end
                    if integer(entry.lastAt) and (not row.lastAt or entry.lastAt > row.lastAt) then
                        row.lastAt, row.mapID = entry.lastAt, entry.mapID
                        row.turnInNpc, row.turnInName, row.chosen = entry.turnInNpc, entry.turnInName, entry.chosen
                    end
                    if type(entry.giver) == 'number' then row.giver = entry.giver end
                    if type(entry.rewards) == 'table' then
                        row.rewards = row.rewards or {}
                        for itemID, n in pairs(entry.rewards) do
                            if type(itemID) == 'number' and integer(n) then row.rewards[itemID] = (row.rewards[itemID] or 0) + n end
                        end
                    end
                    if integer(entry.firstAt) and (not row.firstAt or entry.firstAt < row.firstAt) then row.firstAt = entry.firstAt end
                    if integer(entry.abandonedAt) and (not row.abandonedAt or entry.abandonedAt > row.abandonedAt) then
                        row.abandonedAt = entry.abandonedAt
                    end
                end
            end
        end
    end
    for _, row in ipairs(rows) do
        if row.open > 0 then row.status = 'open'
        elseif row.turnIns > 0 then row.status = 'completed'
        elseif row.abandons > 0 then row.status = 'abandoned'
        else row.status = 'unknown' end
        row.last = math.max(row.lastAt or 0, row.acceptedAt or 0, row.abandonedAt or 0)
        if row.last == 0 then row.last = nil end
    end
    return rows
end
