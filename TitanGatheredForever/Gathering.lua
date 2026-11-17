local _, ns = ...
local Gathering = {}
Gathering.__index = Gathering
ns.Gathering = Gathering
local spellKinds = { [2575] = 'Mining', [2576] = 'Mining', [3564] = 'Mining', [10248] = 'Mining',
                     [2366] = 'Herbs', [2368] = 'Herbs', [3570] = 'Herbs', [11993] = 'Herbs',
                     [8613] = 'Skinning', [8617] = 'Skinning', [8618] = 'Skinning', [10768] = 'Skinning' }
local function positionValid(p)
    return type(p) == 'table' and type(p.mapID) == 'number' and p.mapID > 0
        and p.mapID == math.floor(p.mapID) and type(p.x) == 'number' and type(p.y) == 'number'
        and p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1
end

function Gathering.New(api, saved, resources, enabled)
    if type(saved.maps) ~= 'table' then saved.maps = {} end
    return setmetatable({ api = api, saved = saved, resources = resources, enabled = enabled,
                          lastStatus = 'waiting for a gathering cast' }, Gathering)
end

function Gathering:Status(message)
    self.lastStatus = message
    if self.api.Trace then self.api.Trace('Gathering map: ' .. message) end
end

function Gathering:Cancel()
    self.cast, self.loot = nil, nil
end

function Gathering:CanRecord()
    local ok, allowed = pcall(self.api.CanRecord)
    if not ok or allowed ~= true then
        self:Cancel(); self:Status('recording excluded in instances or unavailable areas'); return false
    end
    return true
end

function Gathering:Cast(event, unit, castGUID, spellID)
    if unit ~= 'player' then return end
    local kind = spellKinds[spellID]
    if not kind then
        if event == 'UNIT_SPELLCAST_START' then self.cast, self.loot = nil, nil end
        if event == 'UNIT_SPELLCAST_START' or event == 'UNIT_SPELLCAST_SUCCEEDED' then
            self:Status('unrecognized player spell ' .. tostring(spellID))
        end
        return
    end
    if not self.enabled(kind) then self.cast, self.loot = nil, nil; self:Status(kind .. ' mapping disabled'); return end
    if not self:CanRecord() then return end
    if event == 'UNIT_SPELLCAST_FAILED' or event == 'UNIT_SPELLCAST_INTERRUPTED' then
        if self.cast and self.cast.guid == castGUID then
            self.cast, self.loot = nil, nil; self:Status(kind .. ' cast failed or interrupted')
        end
        return
    end
    if event == 'UNIT_SPELLCAST_START' then self.cast, self.loot = nil, nil end
    if not self.cast or self.cast.guid ~= castGUID then
        self.cast = { kind = kind, guid = castGUID, at = self.api.Now() }
        self.loot = nil
    end
    local p = self.api.Position()
    if positionValid(p) then self.cast.position = { mapID = p.mapID, x = p.x, y = p.y } end
    self:Status(kind .. ' spell ' .. tostring(spellID) .. ': ' .. event
        .. (self.cast.position and '' or '; player map position unavailable'))
    if event == 'UNIT_SPELLCAST_SUCCEEDED' then self.cast.succeeded = true; self:Finalize() end
end

function Gathering:LootReady()
    if not self.cast then self:Status('loot received without a recognized gathering cast'); return end
    if not self.enabled(self.cast.kind) then return end
    local ok, slots = pcall(self.api.Loot)
    if not ok or type(slots) ~= 'table' then self:Status('loot API read failed: ' .. tostring(slots)); return end
    self.loot = self.loot or { slots = {} }
    for _, slot in ipairs(slots) do
        if type(slot.slot) == 'number' and slot.slot > 0 then
            local existing = self.loot.slots[slot.slot]
            if not existing then
                self.loot.slots[slot.slot] = { slot = slot.slot, itemID = slot.itemID, sources = slot.sources }
            elseif existing.itemID == slot.itemID and type(slot.sources) == 'table' and #slot.sources > 0 then
                -- LOOT_READY may precede source availability. Refresh metadata
                -- at LOOT_OPENED without losing a previously cleared slot.
                existing.sources = slot.sources
            end
        end
    end
    self:Status('read ' .. #slots .. ' loot slots for ' .. self.cast.kind)
end

function Gathering:SlotCleared(slot)
    if self.loot and self.loot.slots[slot] then
        self.loot.slots[slot].cleared = true; self:Status('loot slot ' .. slot .. ' taken')
    end
end

function Gathering:LootClosed()
    if self.loot then self.loot.closed = true; self:Finalize() end
end

function Gathering:Finalize()
    local cast, loot = self.cast, self.loot
    if not cast or not loot or not loot.closed then return end
    if not cast.succeeded then self:Status('loot closed; waiting for gathering spell success'); return end
    if not self:CanRecord() then return end
    self.cast, self.loot = nil, nil
    if not self.enabled(cast.kind) then self:Status(cast.kind .. ' mapping disabled'); return end
    if self.api.Now() - cast.at > 15 then self:Status('gathering cast expired'); return end
    if not positionValid(cast.position) then self:Status('player map position unavailable'); return end
    local resources = self.resources(cast.kind) or {}
    local chosen, priority, skins = nil, nil, {}
    local sourcePattern = cast.kind == 'Skinning' and '^Creature%-' or '^GameObject%-'
    for _, slot in pairs(loot.slots) do
        local rank = resources[slot.itemID]
        if slot.cleared and rank ~= nil and type(slot.sources) == 'table' and #slot.sources == 1
            and type(slot.sources[1]) == 'string' and slot.sources[1]:match(sourcePattern) then
            if cast.kind == 'Skinning' then skins[slot.itemID] = true
            elseif not chosen or rank < priority or (rank == priority and slot.itemID < chosen) then
                chosen, priority = slot.itemID, rank
            end
        end
    end
    if next(skins) then
        local ids = {}; for itemID in pairs(skins) do ids[#ids + 1] = itemID end
        table.sort(ids)
        for _, itemID in ipairs(ids) do self:Record(cast.kind, itemID, cast.position) end
        return
    end
    if chosen then self:Record(cast.kind, chosen, cast.position)
    else self:Status('no taken supported resource from a single ' .. (cast.kind == 'Skinning' and 'Creature' or 'GameObject') .. ' loot source') end
end

local mapKinds = { Mining=true, Herbs=true, Skinning=true, Fishing=true, Cooking=true, Alchemy=true,
    Blacksmithing=true, Engineering=true, FirstAid=true, Leatherworking=true, Tailoring=true, Rare=true, PvP=true }
local function validNode(node)
    return positionValid(node) and mapKinds[node.kind]
        and (node.kind=='PvP'or(type(node.itemID) == 'number' and node.itemID > 0 and node.itemID == math.floor(node.itemID)))
        and type(node.count) == 'number' and node.count > 0 and type(node.lastSeen) == 'number'
end

function Gathering:Count(mapID, kind)
    local count = 0
    local nodes = self.saved.maps[mapID]
    if type(nodes) ~= 'table' then return 0 end
    for _, node in ipairs(nodes) do
        if validNode(node) and node.kind == kind then count = count + 1 end
    end
    return count
end

function Gathering:Clear(mapID, kind)
    if not mapKinds[kind] then return 0 end
    local nodes = self.saved.maps[mapID]
    if type(nodes) ~= 'table' then return 0 end
    local removed = 0
    for index = #nodes, 1, -1 do
        if type(nodes[index]) == 'table' and nodes[index].kind == kind then
            table.remove(nodes, index); removed = removed + 1
        end
    end
    if self.cast and self.cast.kind == kind and self.cast.position and self.cast.position.mapID == mapID then
        self:Cancel()
    end
    if removed > 0 and self.changed then self.changed() end
    return removed
end

function Gathering:Record(kind, itemID, position)
    local nodes = self.saved.maps[position.mapID]
    if type(nodes) ~= 'table' then nodes = {}; self.saved.maps[position.mapID] = nodes end
    for index = #nodes, 1, -1 do
        if not validNode(nodes[index]) or nodes[index].mapID ~= position.mapID then table.remove(nodes, index) end
    end
    for _, node in ipairs(nodes) do
        if validNode(node) and node.kind == kind and node.itemID == itemID
            and (node.x - position.x)^2 + (node.y - position.y)^2 <= 0.0025^2 then
            node.count, node.lastSeen = node.count + 1, self.api.Timestamp()
            self:Status('updated ' .. kind .. ' item ' .. itemID .. ' on map ' .. position.mapID)
            if self.changed then self.changed() end
            return
        end
    end
    while #nodes >= 500 do
        local oldest = 1
        for index, node in ipairs(nodes) do
            if (node.lastSeen or 0) < (nodes[oldest].lastSeen or 0) then oldest = index end
        end
        table.remove(nodes, oldest)
    end
    nodes[#nodes + 1] = { mapID = position.mapID, x = position.x, y = position.y,
                          kind = kind, itemID = itemID, count = 1, lastSeen = self.api.Timestamp() }
    self:Status('recorded ' .. kind .. ' item ' .. itemID .. ' on map ' .. position.mapID)
    if self.changed then self.changed() end
end

function Gathering:RecordPvP(position,honorEstimate)
    if not positionValid(position)then return false end
    local nodes=self.saved.maps[position.mapID]
    if type(nodes)~='table'then nodes={};self.saved.maps[position.mapID]=nodes end
    for index=#nodes,1,-1 do
        if not validNode(nodes[index])or nodes[index].mapID~=position.mapID then table.remove(nodes,index)end
    end
    for _,node in ipairs(nodes)do
        if node.kind=='PvP'and(node.x-position.x)^2+(node.y-position.y)^2<=0.0025^2 then
            node.count=node.count+1;node.lastSeen=self.api.Timestamp()
            if type(honorEstimate)=='number'and honorEstimate>=0 and honorEstimate<math.huge then
                node.honorEstimate=(node.honorEstimate or 0)+honorEstimate
            end
            if self.changed then self.changed()end
            return true
        end
    end
    while #nodes>=500 do
        local oldest=1
        for index,node in ipairs(nodes)do if(node.lastSeen or 0)<(nodes[oldest].lastSeen or 0)then oldest=index end end
        table.remove(nodes,oldest)
    end
    nodes[#nodes+1]={mapID=position.mapID,x=position.x,y=position.y,kind='PvP',count=1,lastSeen=self.api.Timestamp(),
        honorEstimate=type(honorEstimate)=='number'and honorEstimate>=0 and honorEstimate<math.huge and honorEstimate or 0}
    if self.changed then self.changed()end
    return true
end

function Gathering:List(mapID)
    local result = {}
    local nodes = self.saved.maps[mapID]
    if type(nodes) ~= 'table' then return result end
    local mining = self.resources('Mining') or {}
    local ores = {}
    for _, node in ipairs(nodes) do
        if validNode(node) and node.mapID == mapID and node.kind == 'Mining' and mining[node.itemID] == 0 then
            ores[#ores + 1] = node
        end
    end
    for _, node in ipairs(nodes) do
        local covered = false
        if validNode(node) and node.mapID == mapID and node.kind == 'Mining' and mining[node.itemID] ~= 0 then
            for _, ore in ipairs(ores) do
                if (ore.x - node.x)^2 + (ore.y - node.y)^2 <= 0.0025^2 then covered = true; break end
            end
        end
        -- Older candidates saved every mining drop. Prefer a recorded ore at
        -- that spot without deleting byproduct observations or guessing ore.
        if not covered and validNode(node) and node.mapID == mapID and self.enabled(node.kind, node.itemID) then result[#result + 1] = node end
        if #result == 500 then break end
    end
    return result
end
