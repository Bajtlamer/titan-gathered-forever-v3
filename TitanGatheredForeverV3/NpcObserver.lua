local _, ns = ...
local Obs = {}
Obs.__index = Obs
ns.NpcObserver = Obs

local kindBySkillName = { Alchemy = 'Alchemy', Blacksmithing = 'Blacksmithing', Cooking = 'Cooking',
    Enchanting = 'Enchanting', Engineering = 'Engineering', ['First Aid'] = 'FirstAid', Fishing = 'Fishing',
    Herbalism = 'Herbs', Leatherworking = 'Leatherworking', Mining = 'Mining', Skinning = 'Skinning',
    Tailoring = 'Tailoring' }
-- Item class 9 (recipes) subclass to profession.
local kindBySubclass = { [1] = 'Leatherworking', [2] = 'Tailoring', [3] = 'Engineering', [4] = 'Blacksmithing',
    [5] = 'Cooking', [6] = 'Alchemy', [7] = 'FirstAid', [8] = 'Enchanting', [9] = 'Fishing' }

function Obs.NpcID(guid)
    if type(guid) ~= 'string' or not ns.IsPublic(guid) then return nil end
    return tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$'))
end

function Obs.ParseRequirement(text)
    if type(text) ~= 'string' then return nil end
    local name, rank = text:match('^Requires ([%a ]+) %((%d+)%)$')
    if not name then return nil end
    return kindBySkillName[name], tonumber(rank)
end

function Obs.New(api) return setmetatable({ api = api }, Obs) end

function Obs:Save(npc, fields)
    local store = ns.db.npcs
    local record = store[npc.id] or {}
    record.name, record.mapID, record.x, record.y = npc.name, npc.mapID, npc.x, npc.y
    record.lastSeen = self.api.Now()
    for key, value in pairs(fields) do record[key] = value end
    store[npc.id] = record
    if ns.NpcSources then ns.NpcSources.Invalidate() end
    if self.api.Changed then self.api.Changed() end
end

function Obs:TrainerShown()
    if not self.api.Enabled() then return end
    local npc = self.api.Npc()
    if not npc then return end
    local counts, services = {}, {}
    for _, service in ipairs(self.api.TrainerServices()) do
        local kind = kindBySkillName[service.skillName or '']
        if kind then counts[kind] = (counts[kind] or 0) + 1 end
        services[#services + 1] = { name = service.name, cost = service.cost, skill = service.skillRank, kind = kind }
    end
    local profession
    for kind, count in pairs(counts) do
        if not profession or count > counts[profession] or (count == counts[profession] and kind < profession) then
            profession = kind
        end
    end
    if not profession then return end -- class or non-profession trainer
    local rows = {}
    for _, service in ipairs(services) do
        if service.kind == profession then
            rows[#rows + 1] = { name = service.name, skill = service.skill, cost = service.cost }
        end
    end
    self:Save(npc, { profession = profession, trainer = rows })
end

function Obs:MerchantShown()
    if not self.api.Enabled() then return end
    local npc = self.api.Npc()
    if not npc then return end
    local rows = self.api.MerchantRecipes()
    if #rows == 0 then return end
    self:Save(npc, { vendor = rows })
end

-- Client adapter. The exact Forever 1.60.1 behaviour of these calls is a live validation gate.
local function call(fn, ...)
    if type(fn) ~= 'function' then return end
    local results = { pcall(fn, ...) }
    if not results[1] then return end
    return unpack(results, 2)
end
local function public(value, kind)
    return ns.IsPublic(value) and type(value) == kind
end

function Obs.DefaultAPI()
    local api = {}
    api.Enabled = function() return ns.settings and ns.settings.recordNpcs ~= false end
    api.Now = function() return time() end
    api.Changed = function() if ns.RecipeBrowser and ns.RecipeBrowser.Refresh then ns.RecipeBrowser.Refresh() end end
    api.Npc = function()
        local inside, kind = IsInInstance()
        if not (ns.IsPublic(inside) and inside == false and ns.IsPublic(kind) and kind == 'none') then return end
        local id = Obs.NpcID(UnitGUID and UnitGUID('npc'))
        local name = UnitName and UnitName('npc')
        local mapID = call(C_Map.GetBestMapForUnit, 'player')
        local position = mapID and call(C_Map.GetPlayerMapPosition, mapID, 'player')
        if not id or not public(name, 'string') or not public(mapID, 'number') or not position then return end
        local x, y = position:GetXY()
        if not public(x, 'number') or not public(y, 'number') then return end
        return { id = id, name = name, mapID = mapID, x = x, y = y }
    end
    api.TrainerServices = function()
        local result = {}
        local count = call(GetNumTrainerServices)
        if not public(count, 'number') or count < 1 or count > 400 then return result end
        for index = 1, count do
            local name, _, category = call(GetTrainerServiceInfo, index)
            if public(name, 'string') and category ~= 'header' then
                local cost = call(GetTrainerServiceCost, index)
                local skillName, skillRank = call(GetTrainerServiceSkillReq, index)
                result[#result + 1] = { name = name, cost = public(cost, 'number') and cost or nil,
                    skillName = public(skillName, 'string') and skillName or nil,
                    skillRank = public(skillRank, 'number') and skillRank or nil }
            end
        end
        return result
    end
    api.MerchantRecipes = function()
        local result = {}
        local count = call(GetMerchantNumItems)
        if not public(count, 'number') or count < 1 or count > 400 then return result end
        for index = 1, count do
            local link = call(GetMerchantItemLink, index)
            local itemID = public(link, 'string') and tonumber(link:match('item:(%d+)')) or nil
            local classID, subclassID
            if itemID then
                local _, _, _, _, _, class, subclass = call(C_Item.GetItemInfoInstant, itemID)
                classID, subclassID = class, subclass
            end
            if itemID and classID == 9 and kindBySubclass[subclassID] then
                local _, _, price, _, _, _, _, extended = call(GetMerchantItemInfo, index)
                local skill
                local data = C_TooltipInfo and call(C_TooltipInfo.GetMerchantItem, index)
                if public(data, 'table') and public(data.lines, 'table') then
                    for _, line in ipairs(data.lines) do
                        local kind, rank = Obs.ParseRequirement(line.leftText)
                        if kind == kindBySubclass[subclassID] then skill = rank end
                    end
                end
                result[#result + 1] = { itemID = itemID, kind = kindBySubclass[subclassID],
                    price = public(price, 'number') and price or nil, skill = skill,
                    extendedCost = extended == true or nil }
            end
        end
        return result
    end
    return api
end
