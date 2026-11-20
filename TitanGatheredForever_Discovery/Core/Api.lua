local _, ns = ...
-- The adapter between the collectors and the game client. Every call is guarded and returns only public values, so a
-- changed or restricted API turns into "no data", never into an error in a collector. Shapes follow what the core
-- addon already relies on; the skill, quest and zone calls are live validation gates.
local Api = {}
ns.Api = Api

function Api.Default()
    local S = ns.Safe
    local api = {}

    api.Now = function() return time() end
    api.Build = function() return GetBuildInfo() end
    api.Locale = function() return GetLocale and GetLocale() or nil end

    api.Unit = function(unit)
        local guid = S.String(S.Call(UnitGUID, unit))
        if not guid then return nil end
        return { guid = guid, name = S.String(S.Call(UnitName, unit)), level = S.Number(S.Call(UnitLevel, unit)),
            classification = S.String(S.Call(UnitClassification, unit)), creatureType = S.String(S.Call(UnitCreatureType, unit)),
            family = S.String(S.Call(UnitCreatureFamily, unit)), isPlayer = S.Call(UnitIsPlayer, unit) == true,
            playerControlled = S.Call(UnitPlayerControlled, unit) == true }
    end

    api.Zone = function()
        local mapID = C_Map and S.Number(S.Call(C_Map.GetBestMapForUnit, 'player'))
        local info = mapID and C_Map.GetMapInfo and S.Call(C_Map.GetMapInfo, mapID)
        local instanceName, instanceType = S.Call(GetInstanceInfo)
        instanceName, instanceType = S.String(instanceName), S.String(instanceType)
        local inside = instanceType and instanceType ~= 'none'
        return { mapID = mapID, parentMapID = type(info) == 'table' and S.Number(info.parentMapID) or nil,
            realZone = S.String(S.Call(GetRealZoneText)), zone = S.String(S.Call(GetZoneText)),
            subZone = S.String(S.Call(GetSubZoneText)), instanceName = inside and instanceName or nil,
            instanceType = inside and instanceType or nil }
    end

    -- A map position only outside instances (no instance map spots).
    api.Position = function()
        local inside, kind = S.Call(IsInInstance)
        if not (S.Public(inside) and inside == false and S.Public(kind) and kind == 'none') then return nil end
        local mapID = C_Map and S.Number(S.Call(C_Map.GetBestMapForUnit, 'player'))
        local position = mapID and S.Call(C_Map.GetPlayerMapPosition, mapID, 'player')
        if not position or not S.Public(position) then return nil end
        local x, y = S.Call(position.GetXY, position)
        x, y = S.Number(x), S.Number(y)
        if not x or not y then return nil end
        return { mapID = mapID, x = x, y = y }
    end

    api.Loot = function()
        local ok, slots = pcall(function()
            local result = {}
            local count = S.Number(GetNumLootItems())
            if not count then return result end
            for slot = 1, count do
                local link = S.String(GetLootSlotLink(slot))
                local itemID = link and tonumber(link:match('item:(%d+)')) or nil
                local sources, raw = {}, { GetLootSourceInfo(slot) }
                for index = 1, #raw, 2 do
                    local guid = S.String(raw[index])
                    if guid then sources[#sources + 1] = guid end
                end
                local _, name, quantity, _, quality = GetLootSlotInfo(slot)
                result[#result + 1] = { slot = slot, itemID = itemID, name = S.String(name),
                    quantity = S.Number(quantity), quality = S.Number(quality), sources = sources }
            end
            return result
        end)
        return ok and slots or {}
    end

    api.Merchant = function()
        local result = {}
        local count = S.Number(S.Call(GetMerchantNumItems))
        if not count or count < 1 or count > 400 then return result end
        for index = 1, count do
            local link = S.String(S.Call(GetMerchantItemLink, index))
            local itemID = link and tonumber(link:match('item:(%d+)')) or nil
            if itemID then
                local info = C_MerchantFrame and S.Call(C_MerchantFrame.GetItemInfo, index)
                local good = { itemID = itemID }
                if type(info) == 'table' and S.Public(info) then
                    good.price, good.stack = S.Number(info.price), S.Number(info.stackCount)
                    local available = S.Number(info.numAvailable)
                    good.stock = available and available >= 0 and available or nil
                    good.extendedCost = info.hasExtendedCost == true or nil
                end
                result[#result + 1] = good
            end
        end
        return result
    end

    api.Trainer = function()
        local result = {}
        local count = S.Number(S.Call(GetNumTrainerServices))
        if not count or count < 1 or count > 400 then return result end
        for index = 1, count do
            local name, _, category, level = S.Call(GetTrainerServiceInfo, index)
            if S.String(name) and category ~= 'header' then
                local skillName, skillRank = S.Call(GetTrainerServiceSkillReq, index)
                local level = S.Number(level)
                result[#result + 1] = { name = name, cost = S.Number(S.Call(GetTrainerServiceCost, index)),
                    skillName = S.String(skillName), skillRank = S.Number(skillRank),
                    level = level and level > 0 and level or nil }
            end
        end
        return result
    end

    api.CanRepair = function() return S.Call(CanMerchantRepair) == true end

    api.Quest = function()
        local id = S.Number(S.Call(GetQuestID))
        if not id or id == 0 then return nil end
        return { id = id, title = S.String(S.Call(GetTitleText)) }
    end

    api.QuestChoices = function()
        local result = {}
        for _, which in ipairs({ 'choice', 'reward' }) do
            local count = S.Number(S.Call(which == 'choice' and GetNumQuestChoices or GetNumQuestRewards)) or 0
            for index = 1, count do
                local link = S.String(S.Call(GetQuestItemLink, which, index))
                local itemID = link and tonumber(link:match('item:(%d+)')) or nil
                if itemID then result[#result + 1] = itemID end
            end
        end
        return result
    end

    api.Skills = function()
        local result = {}
        if type(GetProfessions) == 'function' then
            for _, index in ipairs({ S.Call(GetProfessions) }) do
                local name, _, rank, maxRank = S.Call(GetProfessionInfo, index)
                if S.String(name) then result[#result + 1] = { name = name, rank = S.Number(rank), maxRank = S.Number(maxRank) } end
            end
            return result
        end
        local count = S.Number(S.Call(GetNumSkillLines)) or 0
        for index = 1, count do
            local name, header, _, rank, _, _, maxRank = S.Call(GetSkillLineInfo, index)
            if S.String(name) and not header then result[#result + 1] = { name = name, rank = S.Number(rank), maxRank = S.Number(maxRank) } end
        end
        return result
    end

    return api
end
