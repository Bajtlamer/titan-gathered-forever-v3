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

-- QUEST_TURNED_IN carries the awarded amount. A repeatable quest can legitimately send this event again.
function Quest.TurnedIn(questID, copper)
    if not publicInteger(questID) or questID == 0 or not publicInteger(copper) then return end
    if copper > 0 then
        ns.VendorSales.ExcludeWalletChanges()
        ns.LootIncome.ExcludeWalletChanges()
    end
    local realm, character = GetRealmName and GetRealmName(), ns.characterID
    if not ns.IsPublic(realm) or type(realm) ~= 'string' or not ns.IsPublic(character) or not character then return end
    local store = ns.db.questIncome
    if type(store) ~= 'table' then store = {}; ns.db.questIncome = store end
    local characters = store[realm]
    if type(characters) ~= 'table' then characters = {}; store[realm] = characters end
    local quests = characters[character]
    if type(quests) ~= 'table' then quests = {}; characters[character] = quests end
    local at, entry = time(), quests[questID]
    if type(entry) ~= 'table' or not integer(entry.copper) or not integer(entry.turnIns) then
        entry = { copper = 0, turnIns = 0, firstAt = at }
        quests[questID] = entry
    end
    entry.copper, entry.turnIns, entry.lastAt = entry.copper + copper, entry.turnIns + 1, at
    if ns.EconomyView then ns.EconomyView.Refresh() end
end
