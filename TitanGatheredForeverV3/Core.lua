local addonName, ns = ...
TitanGatheredForeverV3 = ns
local pendingItems, scheduled, bankAttempts, bankVisit = {}, false, 0, 0

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(message)
end

function ns.Debug(message)
    if ns.settings and ns.settings.debugMode then ns.Print(message) end
end

function ns.IsPublic(value)
    return not issecretvalue(value)
end

function ns.ItemName(itemID)
    local name = C_Item.GetItemInfo(itemID)
    if ns.IsPublic(name) and type(name) == 'string' then return name end
    if pendingItems[itemID] == nil then
        pendingItems[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return string.format(ns.L.loading, itemID)
end

local function inventoryAPI(build)
    local bankOrdinals = {}
    return {
        Build = build, Time = time,
        GetCharacterID = function() return UnitGUID('player') end,
        GetBags = function()
            local bags = {}
            for id = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do bags[#bags + 1] = id end
            return bags
        end,
        CanViewBank = function() return C_Bank.CanViewBank(Enum.BankType.Character) end,
        GetBankTabs = function()
            local metadata = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
            if not metadata then return nil end
            local tabs = {}
            bankOrdinals = {}
            for ordinal, tab in ipairs(metadata) do
                tabs[#tabs + 1] = tab.ID
                bankOrdinals[tab.ID] = ordinal
            end
            return tabs
        end,
        IsBankTabReady = function(id, slots)
            if slots > 0 then return true end
            local ordinal = bankOrdinals[id]
            -- The first tab is the base bank. Additional purchased tabs are
            -- bag slots: zero capacity is legitimate only when no bag is placed.
            if not ordinal or ordinal == 1 then return false end
            local bag = C_Container.GetContainerItemInfo(Enum.BagIndex.Characterbanktab, ordinal)
            return bag == nil
        end,
        GetSlots = function(id)
            local slots = C_Container.GetContainerNumSlots(id)
            if not ns.IsPublic(slots) then error('Container slots are restricted') end
            return slots
        end,
        GetItem = function(id, slot)
            local item = C_Container.GetContainerItemInfo(id, slot)
            if item and (not ns.IsPublic(item.itemID) or not ns.IsPublic(item.stackCount)) then
                error('Container item is restricted')
            end
            return item
        end,
    }
end

function ns.ScheduleRefresh()
    if scheduled or not ns.inventory then return end
    scheduled = true
    C_Timer.After(0.1, function()
        scheduled = false
        ns.inventory:RefreshBags()
        if ns.settings.showBank and ns.inventory.bankOpen then
            if ns.inventory:RefreshBank() then bankAttempts = 0
            elseif bankAttempts < 4 then
                bankAttempts = bankAttempts + 1
                local visit = bankVisit
                C_Timer.After(0.4, function()
                    if visit == bankVisit and ns.inventory.bankOpen and ns.settings.showBank then ns.ScheduleRefresh() end
                end)
            end
        end
        ns.Titan.Refresh()
        ns.Reports.Refresh()
    end)
end

local frame = CreateFrame('Frame')
ns.eventFrame = frame
local gatheringEvents = { 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP',
    'LOOT_READY', 'LOOT_OPENED', 'LOOT_SLOT_CLEARED', 'LOOT_CLOSED' }

function ns.GatheringEnabled(kind, itemID) return ns.Sources.Enabled(kind, itemID) end

function ns.UpdateGathering()
    if not ns.gathering then return end
    ns.Sources.SettingsChanged()
    ns.Actions.SettingsChanged()
    ns.Production.SettingsChanged()
    ns.gathering:Cancel()
    if ns.observations and ns.observations.cast and not ns.Sources.Active(ns.observations.cast.kind) then ns.observations:Cancel() end
    local enabled = ns.settings.recordHistory or ns.settings.recordActions
    for _, category in ipairs(ns.Sources.Categories()) do enabled = enabled or ns.Sources.Enabled(category.id) end
    for _, event in ipairs(gatheringEvents) do
        if enabled or (ns.settings.recordProduction and event:match('^UNIT_SPELLCAST_')) then
            frame:RegisterEvent(event)
        else frame:UnregisterEvent(event) end
    end
    if ns.settings.recordProduction then frame:RegisterEvent('TRADE_SKILL_ITEM_CRAFTED_RESULT')
    else frame:UnregisterEvent('TRADE_SKILL_ITEM_CRAFTED_RESULT') end
    for _,event in ipairs({'CHAT_MSG_COMBAT_HONOR_GAIN','PLAYER_DEAD','PLAYER_PVP_KILLS_CHANGED','PLAYER_PVP_RANK_CHANGED'})do
        frame:RegisterEvent(event)
    end
    ns.Map.Attach()
    ns.Map.Update()
    ns.Minimap.Attach()
    ns.Minimap.Update()
end

local function gatheringAPI()
    return {
        Now = GetTime,
        Timestamp = time,
        Trace = ns.Debug,
        CanRecord = function(kind)
            if kind == 'Enchanting' then return true end
            local inside, kind = IsInInstance()
            return ns.IsPublic(inside) and ns.IsPublic(kind) and inside == false and kind == 'none'
        end,
        Position = function()
            local mapID = C_Map.GetBestMapForUnit('player')
            if not ns.IsPublic(mapID) or type(mapID) ~= 'number' then return nil end
            local position = C_Map.GetPlayerMapPosition(mapID, 'player')
            if not position then return nil end
            local x, y = position:GetXY()
            if ns.IsPublic(x) and ns.IsPublic(y) then return { mapID = mapID, x = x, y = y } end
        end,
        Loot = function()
            local slots = {}
            local count = GetNumLootItems()
            if not ns.IsPublic(count) then return slots end
            for slot = 1, count do
                local link = GetLootSlotLink(slot)
                local itemID
                if ns.IsPublic(link) and type(link) == 'string' then itemID = tonumber(link:match('item:(%d+)')) end
                local rawSources, sources, quantities = { GetLootSourceInfo(slot) }, {}, {}
                for index = 1, #rawSources, 2 do
                    if not ns.IsPublic(rawSources[index]) then error('Loot source is restricted') end
                    sources[#sources + 1] = rawSources[index]
                    if ns.IsPublic(rawSources[index + 1]) and type(rawSources[index + 1]) == 'number' then
                        quantities[rawSources[index]] = rawSources[index + 1]
                    end
                end
                local quantity, quality
                if GetLootSlotInfo then
                    local _, _, amount, _, rarity = GetLootSlotInfo(slot)
                    if ns.IsPublic(amount) then quantity = amount end
                    if ns.IsPublic(rarity) then quality = rarity end
                end
                local unreadableItem = false
                if not itemID and GetLootSlotType and LOOT_SLOT_ITEM then
                    local slotType = GetLootSlotType(slot)
                    unreadableItem = not ns.IsPublic(slotType) or slotType == LOOT_SLOT_ITEM
                end
                slots[#slots + 1] = { slot = slot, itemID = itemID, sources = sources,
                    sourceQuantities = quantities, quantity = quantity, quality = quality, unreadableItem = unreadableItem }
            end
            return slots
        end,
    }
end

local function start()
    if ns.inventory or ns.disabled then return end
    local version, build, _, interface = GetBuildInfo()
    if interface ~= 16001 or version ~= '1.60.1' then
        ns.disabled = true; ns.Print(ns.L.unsupported); return
    end
    if not UnitGUID('player') then return end
    ns.characterID = UnitGUID('player')
    ns.db, ns.settings = ns.Settings.Initialize(TitanGatheredForeverV3DB)
    TitanGatheredForeverV3DB = ns.db
    ns.Catalog.Rebuild(ns.settings)
    ns.inventory = ns.Inventory.New(inventoryAPI(build), ns.db)
    ns.gathering = ns.Gathering.New(gatheringAPI(), ns.db.gathering,
        function(kind)
            local module = ns.Catalog.modules[kind]
            return module and module.gatheringResources or {}
        end, ns.GatheringEnabled)
    ns.history = ns.History.New(ns.db.history)
    ns.history:InvalidatePending(UnitGUID('player'))
    ns.actions = ns.Actions.New(ns.db.actions, {
        Character=function() return ns.characterID end,
        Name=function() return (UnitName and UnitName('player') or ns.characterID)
            .. ' - ' .. (GetRealmName and GetRealmName() or '') end,
        Timestamp=time, Now=GetTime, Enabled=ns.Actions.Enabled,
        Changed=function() ns.Reports.Refresh() end,
    })
    ns.production = ns.Production.New(ns.db.production, {
        Character=function() return ns.characterID end,
        Name=function() return (UnitName and UnitName('player') or ns.characterID)
            .. ' - ' .. (GetRealmName and GetRealmName() or '') end,
        Timestamp=time, Now=GetTime, Enabled=ns.Production.Enabled, Public=ns.IsPublic,
        Recipe=ns.Production.Recipe, Changed=function() ns.Reports.Refresh() end,
    })
    local pvpAPI=gatheringAPI()
    pvpAPI.Character=function()return ns.characterID end
    pvpAPI.Name=function()return UnitName and UnitName('player')or ns.characterID end
    pvpAPI.LifetimeStats=function()
        if not GetPVPLifetimeStats then return end
        local honorableKills,highestRank=GetPVPLifetimeStats()
        return honorableKills,highestRank
    end
    pvpAPI.RankName=function(rank)
        if not GetPVPRankInfo then return end
        return GetPVPRankInfo(rank,'player')
    end
    pvpAPI.CurrentRank=function()
        if not UnitPVPRank then return end
        local rank=UnitPVPRank('player')
        if type(rank)~='number' then return end
        local name
        if GetPVPRankInfo then name=GetPVPRankInfo(rank,'player') end
        return rank,type(name)=='string' and name or nil
    end
    pvpAPI.Changed=function()ns.Reports.Refresh()end
    ns.pvp=ns.PvP.New(ns.db.pvp,pvpAPI)
    local observationAPI = gatheringAPI()
    local outdoor = observationAPI.CanRecord
    observationAPI.CanRecord = function(kind) return ns.Sources.Track(kind) or outdoor(kind) end
    observationAPI.Context = function()
        local inside, kind = IsInInstance()
        if ns.IsPublic(inside) and ns.IsPublic(kind) and type(kind) == 'string' then return kind end
        return 'unknown'
    end
    observationAPI.Track, observationAPI.Active = ns.Sources.Track, ns.Sources.Active
    observationAPI.Eligible, observationAPI.Commit = ns.Sources.Eligible, ns.Sources.Record
    observationAPI.IsFishing = function()
        local value = IsFishingLoot and IsFishingLoot()
        return ns.IsPublic(value) and value == true
    end
    observationAPI.SourceItem = function(guid)
        local itemID = C_Item.GetItemIDByGUID and C_Item.GetItemIDByGUID(guid)
        if ns.IsPublic(itemID) and type(itemID) == 'number' then return itemID end
    end
    observationAPI.Trace = function(message) ns.gathering.lastStatus = message; ns.Debug('Sources: ' .. message) end
    observationAPI.SourceName = function(guid)
        local target = UnitGUID('target')
        if ns.IsPublic(target) and target == guid and UnitName then
            local name = UnitName('target')
            if ns.IsPublic(name) and type(name) == 'string' then return name end
        end
    end
    observationAPI.Inputs = function()
        local inputs = {}
        if not ItemLocation or not C_Item.GetItemGUID then return inputs end
        for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local item = C_Container.GetContainerItemInfo(bag, slot)
                if item and ns.IsPublic(item.itemID) then
                    local guid = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
                    if ns.IsPublic(guid) and guid then inputs[guid] = item.itemID end
                end
            end
        end
        return inputs
    end
    ns.observations = ns.Observations.New(observationAPI)
    ns.UpdateGathering()
    ns.FlightPaths.Attach()
    ns.Tooltips.Initialize()
    ns.Crafting.Initialize()
    ns.Titan.Initialize()
    for _, event in ipairs({ 'BAG_UPDATE_DELAYED', 'BANKFRAME_OPENED', 'BANKFRAME_CLOSED',
                            'BANK_TABS_CHANGED', 'PLAYERBANKSLOTS_CHANGED', 'PLAYER_ENTERING_WORLD',
                            'PLAYER_LEAVING_WORLD', 'ITEM_DATA_LOAD_RESULT', 'SKILL_LINES_CHANGED',
                            'TRADE_SKILL_DATA_SOURCE_CHANGING', 'TRADE_SKILL_DATA_SOURCE_CHANGED',
                            'TRADE_SKILL_DETAILS_UPDATE', 'TRADE_SKILL_CLOSE' }) do frame:RegisterEvent(event) end
    SlashCmdList.TITANGATHEREDFOREVERV3 = function(command)
        if command=='icons' then ns.IconConfig.Show(); return end
        if command=='export'then ns.ExportView.Show();return end
        if command=='recipe'or command:match('^recipe%s')then
            local id,target=command:match('^recipe%s+(%d+)%s*(%d*)%s*$')
            if command=='recipe'then id=ns.Crafting.selectedID;target=1 end
            if not id then ns.Print('Usage: /tgf recipe <recipeID> [operations], or select a recipe and use /tgf recipe.');return end
            ns.CraftingView.Show(tonumber(id),tonumber(target)or 1);return
        end
        if command == 'refresh' then ns.ScheduleRefresh(); return end
        if command == 'next' or command == 'prev' then
            ns.Titan.page = math.max(1, ns.Titan.page + (command == 'next' and 1 or -1))
            ns.Titan.Refresh(); return
        end
        if command == 'history' or command == 'chances' or command == 'actions' or command == 'production' or command == 'pvp' then ns.Reports.Show(command); return end
        if command == 'settings' then ns.Titan.Menu(UIParent); return end
        local help = 'Commands: /tgf settings, /tgf icons, /tgf refresh, /tgf next, /tgf prev, /tgf history, /tgf chances, /tgf actions, /tgf production, /tgf recipe <recipeID> [operations], /tgf export, /tgf status.'
        if command ~= 'status' and not ns.settings.debugMode then ns.Print(help); return end
        local report = command == 'status' and ns.Print or ns.Debug
        local count = ns.inventory:Get(0)
        report(string.format('Titan Gathered Forever v3 %s; client %s.%s; bank %s; catalogue %d materials / %d recipes.',
            C_AddOns.GetAddOnMetadata(addonName, 'Version') or 'unknown', version, build,
            count.bankState, ns.DataMetadata.itemCount, ns.DataMetadata.recipeCount))
        report(help .. ' Catalogue live completeness is unverified.')
        report('Personal bank scan: ' .. ns.inventory.lastBankStatus)
        local savedSpots = 0
        for _, nodes in pairs(ns.db.gathering.maps) do
            if type(nodes) == 'table' then savedSpots = savedSpots + #nodes end
        end
        local world, mini = ns.Map.instance, ns.Minimap.instance
        report('Gathering map: ' .. (ns.settings.gatheringMap and 'on' or 'off')
            .. '; Herbalism ' .. (ns.GatheringEnabled('Herbs') and 'on' or 'off')
            .. '; Mining ' .. (ns.GatheringEnabled('Mining') and 'on' or 'off')
            .. '; Skinning ' .. (ns.GatheringEnabled('Skinning') and 'on' or 'off')
            .. '; ' .. ns.gathering.lastStatus .. '; saved spots ' .. savedSpots
            .. '; world map ' .. (world and tostring(world.mapID or 'not opened') or 'not attached')
            .. ' / icons ' .. (world and world.visibleCount or 0)
            .. '; minimap icons ' .. (mini and mini.visibleCount or 0))
    end
    SLASH_TITANGATHEREDFOREVERV31 = '/tgf'
    ns.ScheduleRefresh()
end

frame:SetScript('OnEvent', function(_, event, ...)
    if event == 'ADDON_LOADED' then
        if (...) == addonName then frame:RegisterEvent('PLAYER_LOGIN')
        else ns.Map.Attach(); ns.Minimap.Attach(); ns.FlightPaths.Attach() end
        return
    end
    if event == 'PLAYER_LOGIN' then start(); return end
    if not ns.inventory then return end
    if event=='TRADE_SKILL_DATA_SOURCE_CHANGING'or event=='TRADE_SKILL_CLOSE'or event=='PLAYER_LEAVING_WORLD'then ns.Crafting.Select(nil)end
    if event=='CHAT_MSG_COMBAT_HONOR_GAIN'then
        local args={...};local message=args[1]
        local inside,instanceType=IsInInstance()
        local position
        if inside==false and instanceType=='none'then position=gatheringAPI().Position()end
        local lineID=args[11]
        local observation={context=inside==false and instanceType=='none'and'none'or instanceType,
            eventToken=ns.IsPublic(lineID)and tostring(lineID)or nil}
        if position then observation.mapID,observation.x,observation.y=position.mapID,position.x,position.y end
        local result=ns.pvp:HonorMessage(message,observation)
        if result and result.position then
            ns.gathering:RecordPvP(result.position,result.estimatedHonor)
            ns.Map.Update();ns.Minimap.Update()
        end
        ns.Reports.Refresh();return
    elseif event=='PLAYER_DEAD'then
        local recap=C_DeathRecap
        if recap and recap.GetRecapEvents then
            local ok,events=pcall(recap.GetRecapEvents)
            if ok then
                local _,instanceType=IsInInstance()
                ns.pvpDeathSerial=(ns.pvpDeathSerial or 0)+1
                if ns.pvp:DeathRecap(events,instanceType,tostring(ns.pvpDeathSerial))then ns.Reports.Refresh()end
            end
        end
        return
    elseif event=='PLAYER_PVP_KILLS_CHANGED'or event=='PLAYER_PVP_RANK_CHANGED'then
        ns.Reports.Refresh();return
    end
    if event:match('^UNIT_SPELLCAST_') then
        local unit, castGUID, spellID = ...
        if ns.IsPublic(unit) and ns.IsPublic(castGUID) and ns.IsPublic(spellID) then
            ns.actions:Cast(event, unit, castGUID, spellID)
            ns.production:Cast(event, unit, castGUID, spellID)
            if event == 'UNIT_SPELLCAST_START' or event == 'UNIT_SPELLCAST_SUCCEEDED'
                or event == 'UNIT_SPELLCAST_FAILED' or event == 'UNIT_SPELLCAST_INTERRUPTED' then
                ns.observations:Cast(event, unit, castGUID, spellID)
            end
        end
        return
    elseif event == 'TRADE_SKILL_ITEM_CRAFTED_RESULT' then ns.production:Result(...); return
    elseif event == 'LOOT_READY' or event == 'LOOT_OPENED' then
        local fishing = IsFishingLoot and IsFishingLoot()
        if ns.IsPublic(fishing) and fishing == true then ns.actions:FishingLoot() end
        local _, fromItem = ...
        ns.observations:LootReady(event == 'LOOT_OPENED' and ns.IsPublic(fromItem) and fromItem == true); return
    elseif event == 'LOOT_SLOT_CLEARED' then
        local slot = ...
        if ns.IsPublic(slot) then ns.observations:SlotCleared(slot) end
        return
    elseif event == 'LOOT_CLOSED' then ns.observations:LootClosed(); return end
    if event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_LEAVING_WORLD' then
        ns.gathering:Cancel(); ns.observations:Cancel(true); ns.actions:Pause(); ns.production:Pause()
    end
    if event == 'BANKFRAME_OPENED' then
        bankAttempts, bankVisit = 0, bankVisit + 1
        ns.inventory:SetBankOpen(true)
    elseif event == 'BANKFRAME_CLOSED' or event == 'PLAYER_LEAVING_WORLD' then
        bankVisit = bankVisit + 1
        ns.inventory:SetBankOpen(false)
    elseif event == 'ITEM_DATA_LOAD_RESULT' then
        local itemID, success = ...
        if not ns.IsPublic(itemID) or type(itemID) ~= 'number' then return end
        if success then pendingItems[itemID] = nil else pendingItems[itemID] = false end
        ns.Reports.Refresh()
    end
    ns.ScheduleRefresh()
end)
frame:RegisterEvent('ADDON_LOADED')
