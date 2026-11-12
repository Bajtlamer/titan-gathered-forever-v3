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

-- Bounded diagnostic log of recording attempts (Diagnostics > Show NPC recording log). It records why an
-- attempt did or did not store anything, plus raw client API answers, so live behaviour can be checked.
function Obs:Log(event, result, details)
    local log = ns.db and ns.db.npcLog
    if type(log) ~= 'table' then return end
    local entry = { at = self.api.Now(), event = event, result = result }
    for key, value in pairs(details or {}) do entry[key] = value end
    local previous = log[#log]
    if previous and previous.event == event and previous.result == result and previous.npc == entry.npc
        and previous.services == entry.services and previous.recipes == entry.recipes
        and (event == 'TRAINER_UPDATE' or event == 'MERCHANT_UPDATE') then
        return
    end
    if self.api.Probe and result ~= 'disabled' then
        local ok, probe = pcall(self.api.Probe, event:find('^TRAINER') and 'trainer' or 'merchant')
        if ok and type(probe) == 'table' then entry.probe = probe end
    end
    log[#log + 1] = entry
    while #log > 12 do table.remove(log, 1) end
end

function Obs.PrintLog()
    local log = ns.db and ns.db.npcLog
    if type(log) ~= 'table' or #log == 0 then
        ns.Print('No NPC recording attempts yet. Open a trainer or merchant window first.')
        return
    end
    for _, entry in ipairs(log) do
        local stamp = date and entry.at and date('%H:%M:%S', entry.at) or tostring(entry.at)
        local parts = { stamp, entry.event, entry.result }
        for _, key in ipairs({ 'npc', 'services', 'first', 'profession', 'recipes' }) do
            if entry[key] ~= nil then parts[#parts + 1] = key .. '=' .. tostring(entry[key]) end
        end
        ns.Print(table.concat(parts, ' '))
        for _, line in ipairs(entry.probe or {}) do ns.Print('  ' .. line) end
    end
end

-- The client fills trainer and merchant lists a moment after the SHOW event, so the same read runs again on
-- the matching UPDATE event while the window stays open.
function Obs:ReadTrainer(event)
    if not self.api.Enabled() then self:Log(event, 'disabled'); return end
    local npc = self.api.Npc()
    if not npc then self:Log(event, 'no-npc'); return end
    local counts, services = {}, {}
    for _, service in ipairs(self.api.TrainerServices()) do
        local kind = kindBySkillName[service.skillName or '']
        if kind then counts[kind] = (counts[kind] or 0) + 1 end
        services[#services + 1] = { name = service.name, cost = service.cost, skill = service.skillRank, kind = kind }
    end
    if #services == 0 then
        if event == 'TRAINER_UPDATE' then
            if self.emptyTrainerLogged then return end
            self.emptyTrainerLogged = true
        end
        self:Log(event, 'no-services', { npc = npc.id, services = 0 })
        return
    end
    local profession
    for kind, count in pairs(counts) do
        if not profession or count > counts[profession] or (count == counts[profession] and kind < profession) then
            profession = kind
        end
    end
    if not profession then -- class or non-profession trainer, or the client gave no skill requirement
        self:Log(event, 'no-profession', { npc = npc.id, services = #services, first = services[1].name })
        return
    end
    local rows = {}
    for _, service in ipairs(services) do
        if service.kind == profession then
            rows[#rows + 1] = { name = service.name, skill = service.skill, cost = service.cost }
        end
    end
    self:Save(npc, { profession = profession, trainer = rows })
    self:Log(event, 'saved', { npc = npc.id, profession = profession, services = #rows })
end

function Obs:TrainerShown()
    self.trainerOpen, self.emptyTrainerLogged = true, false
    self:ReadTrainer('TRAINER_SHOW')
end
function Obs:TrainerUpdated() if self.trainerOpen then self:ReadTrainer('TRAINER_UPDATE') end end
function Obs:TrainerClosed() self.trainerOpen = false end

function Obs:ReadMerchant(event)
    if not self.api.Enabled() then self:Log(event, 'disabled'); return end
    local npc = self.api.Npc()
    if not npc then self:Log(event, 'no-npc'); return end
    local rows = self.api.MerchantRecipes()
    if #rows == 0 then
        if event == 'MERCHANT_UPDATE' then
            if self.emptyMerchantLogged then return end
            self.emptyMerchantLogged = true
        end
        self:Log(event, 'no-recipes', { npc = npc.id, recipes = 0 })
        return
    end
    self:Save(npc, { vendor = rows })
    self:Log(event, 'saved', { npc = npc.id, recipes = #rows })
end

function Obs:MerchantShown()
    self.merchantOpen, self.emptyMerchantLogged = true, false
    self:ReadMerchant('MERCHANT_SHOW')
end
function Obs:MerchantUpdated() if self.merchantOpen then self:ReadMerchant('MERCHANT_UPDATE') end end
function Obs:MerchantClosed() self.merchantOpen = false end

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
    api.Probe = function(which)
        local out = {}
        local function describe(fn, ...)
            if type(fn) ~= 'function' then return 'missing' end
            local function pack(ok, ...)
                if not ok then return 'error' end
                local parts = {}
                for i = 1, select('#', ...) do
                    local value = (select(i, ...))
                    parts[i] = ns.IsPublic(value) and tostring(value) or '<secret>'
                end
                return '(' .. table.concat(parts, ', ') .. ')'
            end
            return pack(pcall(fn, ...))
        end
        out[#out + 1] = 'IsInInstance=' .. describe(IsInInstance)
        out[#out + 1] = 'UnitGUID(npc)=' .. describe(UnitGUID, 'npc') .. ' UnitName(npc)=' .. describe(UnitName, 'npc')
        out[#out + 1] = 'map=' .. describe(C_Map and C_Map.GetBestMapForUnit, 'player')
        if which == 'trainer' then
            out[#out + 1] = 'GetNumTrainerServices=' .. describe(GetNumTrainerServices)
                .. ' C_TrainerUI=' .. type(C_TrainerUI)
            local count = call(GetNumTrainerServices)
            for index = 1, math.min(public(count, 'number') and count or 0, 3) do
                out[#out + 1] = 'service' .. index .. ' info=' .. describe(GetTrainerServiceInfo, index)
                    .. ' skillReq=' .. describe(GetTrainerServiceSkillReq, index)
                    .. ' cost=' .. describe(GetTrainerServiceCost, index)
            end
        else
            local count = call(GetMerchantNumItems)
            out[#out + 1] = 'GetMerchantNumItems=' .. describe(GetMerchantNumItems)
                .. ' C_TooltipInfo=' .. type(C_TooltipInfo)
            for index = 1, math.min(public(count, 'number') and count or 0, 3) do
                local link = call(GetMerchantItemLink, index)
                out[#out + 1] = 'item' .. index .. ' link=' .. describe(GetMerchantItemLink, index)
                    .. ' info=' .. describe(GetMerchantItemInfo, index)
            end
        end
        return out
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
