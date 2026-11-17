local _, ns = ...
local Flight = {}
Flight.__index = Flight
ns.FlightPaths = Flight

local factions = { [0] = 'Neutral', [1] = 'Horde', [2] = 'Alliance' }
local labels = { discovered = 'Discovered', undiscovered = 'Undiscovered', unknown = 'Discovery not confirmed' }

local function number(value)
    return ns.IsPublic(value) and type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local colors = { discovered = { .45, 1, .45 }, undiscovered = { 1, .7, .3 }, unknown = { .65, .65, .65 } }
local function characterID()
    local id = ns.characterID or (UnitGUID and UnitGUID('player'))
    if ns.IsPublic(id) and type(id) == 'string' and id ~= '' then return id end
end
local function visited(id)
    local visits = ns.db and ns.db.flightVisits
    local character = characterID()
    return character and type(visits) == 'table' and type(visits[character]) == 'table' and visits[character][id] == true
end
local function appliedTint(saved)
    local color = {saved.texture:GetVertexColor()}
    for index = 1, 4 do if color[index] ~= saved.applied[index] then return false end end
    return true
end
local function restoreTint(pin)
    local saved = pin.tgfFlightTint
    if saved then
        if appliedTint(saved) then saved.texture:SetVertexColor(unpack(saved.color)) end
        pin.tgfFlightTint = nil
    end
end
local function tint(texture, status)
    if texture and texture.SetVertexColor then
        local color = colors[status]
        texture:SetVertexColor(color[1], color[2], color[3], 1)
    end
end

-- Called only during a flight-master interaction, never from map browsing.
function Flight:ObserveVisit()
    if not self.taxiOpen or not ns.db or not C_TaxiMap or not C_TaxiMap.GetAllTaxiNodes
        or not Enum or not Enum.FlightPathState then return end
    local character = characterID()
    if not character then return end
    local maps, seen = {}, {}
    local function addMap(mapID)
        if number(mapID) and mapID > 0 and not seen[mapID] then
            maps[#maps + 1] = mapID; seen[mapID] = true
        end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, 'player')
        if ok then addMap(mapID) end
    end
    if FlightMapFrame and FlightMapFrame.GetMapID and FlightMapFrame:IsShown() then
        addMap(FlightMapFrame:GetMapID())
    end
    local current, invalid
    for index = 1, 12 do
        local mapID = maps[index]
        if not mapID then break end
        local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
        if ok and ns.IsPublic(nodes) and type(nodes) == 'table' then
            for i, node in ipairs(nodes) do
                if i > 4096 then invalid = true; break end
                if ns.IsPublic(node) and type(node) == 'table' and ns.IsPublic(node.state)
                    and node.state == Enum.FlightPathState.Current then
                    local id = node.nodeID
                    if number(id) and id > 0 and id == math.floor(id) then
                        if current and current ~= id then invalid = true end
                        current = id
                    end
                end
            end
        end
        if C_Map and C_Map.GetMapInfo then
            local infoOK, info = pcall(C_Map.GetMapInfo, mapID)
            if infoOK and ns.IsPublic(info) and type(info) == 'table' then addMap(info.parentMapID) end
        end
    end
    if current and not invalid then
        if type(ns.db.flightVisits) ~= 'table' then ns.db.flightVisits = {} end
        if type(ns.db.flightVisits[character]) ~= 'table' then ns.db.flightVisits[character] = {} end
        ns.db.flightVisits[character][current] = true
    end
end

local function playerFaction()
    local ok, value = pcall(function() return UnitFactionGroup('player') end)
    if ok and ns.IsPublic(value) and (value == 'Alliance' or value == 'Horde') then return value end
end

local function readNode(row, faction)
    if not ns.IsPublic(row) or type(row) ~= 'table' then return end
    local id, side = row.nodeID, row.faction
    if not number(id) or id <= 0 or id ~= math.floor(id) or not number(side) or not factions[side] then return end
    if side ~= 0 and factions[side] ~= faction then return end
    if not ns.IsPublic(row.position) or not row.position then return end
    local x, y = row.position:GetXY()
    if not number(x) or not number(y) or x < 0 or x > 1 or y < 0 or y > 1 then return end
    local status = 'unknown'
    if visited(id) then status = 'discovered'
    elseif ns.IsPublic(row.isUndiscovered) and row.isUndiscovered == true then status = 'undiscovered' end
    local name = ns.IsPublic(row.name) and type(row.name) == 'string' and row.name ~= '' and row.name or ('Flight point ' .. id)
    local atlas = ns.IsPublic(row.atlasName) and type(row.atlasName) == 'string' and row.atlasName ~= '' and row.atlasName or 'FlightPath'
    return { nodeID = id, faction = factions[side], x = x, y = y, name = name, atlasName = atlas, status = status }
end

function Flight.Read(mapID)
    if not C_TaxiMap or type(C_TaxiMap.GetTaxiNodesForMap) ~= 'function' then return {}, 'unsupported' end
    if not number(mapID) or mapID <= 0 or mapID ~= math.floor(mapID) then return {}, 'unavailable' end
    local faction = playerFaction()
    local ok, result = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
    if not ok or not ns.IsPublic(result) or type(result) ~= 'table' then return {}, 'unavailable' end
    local nodes, seen = {}, {}
    for index, row in ipairs(result) do
        if index > 4096 then return {}, 'unavailable' end
        local valid, node = pcall(readNode, row, faction)
        if valid and node then
            if seen[node.nodeID] then return {}, 'unavailable' end
            seen[node.nodeID] = true
            nodes[#nodes + 1] = node
        end
    end
    table.sort(nodes, function(a, b) return a.nodeID < b.nodeID end)
    return nodes, 'ready'
end

local function tooltipOwnedBy(pin)
    return GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == pin
end

local function showTooltip(pin)
    local node = pin.node
    GameTooltip:SetOwner(pin, 'ANCHOR_RIGHT')
    GameTooltip:AddLine(node.name)
    GameTooltip:AddLine(node.faction .. ' flight point')
    GameTooltip:AddLine(labels[node.status])
    if node.status == 'undiscovered' then GameTooltip:AddLine('Visit this flight master to discover the route.') end
    GameTooltip:Show()
end

local function clearNativeTooltip(pin)
    if pin.tgfFlightTooltipStatus and tooltipOwnedBy(pin) then GameTooltip:Hide() end
    pin.tgfFlightTooltipStatus = nil
end

function Flight:ClearNative(keep)
    for pin in pairs(self.nativePins) do
        if not keep or not keep[pin] then
            clearNativeTooltip(pin)
            ns.PinStyle.RestoreNative(pin)
            restoreTint(pin)
            pin.tgfFlightStatus, pin.tgfFlightNodeID = nil, nil
            self.nativePins[pin] = nil
        end
    end
end

function Flight:Hide()
    self.overlay:Hide()
    for _, pin in ipairs(self.pins) do
        if tooltipOwnedBy(pin) then GameTooltip:Hide() end
        pin:Hide()
    end
    self:ClearNative()
    self.visibleCount, self.customCount = 0, 0
end

function Flight:Decorate(pin, node)
    if not pin.tgfFlightHooked then
        pin.tgfFlightHooked = true
        pin:HookScript('OnEnter', function(button)
            if button.tgfFlightStatus and tooltipOwnedBy(button) then
                GameTooltip:AddLine('Flight point: ' .. labels[button.tgfFlightStatus])
                button.tgfFlightTooltipStatus = button.tgfFlightStatus
                GameTooltip:Show()
            end
        end)
        pin:HookScript('OnLeave', function(button) button.tgfFlightTooltipStatus = nil end)
    end
    if pin.tgfFlightStatus ~= node.status or pin.tgfFlightNodeID ~= node.nodeID then clearNativeTooltip(pin) end
    self.nativePins[pin] = true
    pin.tgfFlightStatus, pin.tgfFlightNodeID = node.status, node.nodeID
    local config = ns.settings.iconAppearance
    if type(config) == 'table' and type(config.flight) == 'table' then
        ns.PinStyle.Native(pin, ns.PinStyle.Get('flight'), self.world:GetEffectiveScale())
    else ns.PinStyle.RestoreNative(pin) end
    local texture = pin.Texture
    if pin.tgfFlightTint and pin.tgfFlightTint.texture ~= texture then restoreTint(pin) end
    if texture and texture.GetVertexColor and texture.SetVertexColor then
        if not pin.tgfFlightTint or not appliedTint(pin.tgfFlightTint) then
            pin.tgfFlightTint = {texture=texture, color={texture:GetVertexColor()}}
        end
        tint(texture, node.status)
        pin.tgfFlightTint.applied = {texture:GetVertexColor()}
    end
end

function Flight:NativeNodes(nodes)
    local result, current = {}, {}
    if not self.world.EnumeratePinsByTemplate then return result, current end
    local byID = {}
    for _, node in ipairs(nodes) do byID[node.nodeID] = node end
    for pin in self.world:EnumeratePinsByTemplate('FlightPointPinTemplate') do
        local info = pin.poiInfo
        local id = info and info.nodeID
        if number(id) and byID[id] and pin:IsShown() then
            result[id] = true
            current[pin] = true
            self:Decorate(pin, byID[id])
        end
    end
    return result, current
end

function Flight:CreatePin()
    local pin = CreateFrame('Button', nil, self.overlay)
    pin:SetFrameStrata('HIGH')
    pin:SetSize(18, 18)
    ns.PinStyle.Apply(pin, true)
    pin:SetScript('OnEnter', showTooltip)
    pin:SetScript('OnLeave', function(button) if tooltipOwnedBy(button) then GameTooltip:Hide() end end)
    self.pins[#self.pins + 1] = pin
    return pin
end

function Flight:WatchCanvas(canvas)
    if self.watched[canvas] then return end
    self.watched[canvas] = true
    canvas:HookScript('OnSizeChanged', function() self:Refresh() end)
end

function Flight:Refresh(force)
    if self.suspended or ns.settings.flightPoints == false or not self.world:IsShown() then self:Hide(); return end
    local mapID, canvas = self.world:GetMapID(), self.world:GetCanvas()
    if not number(mapID) or not canvas then self:Hide(); return end
    -- Watch readiness before hiding a not-yet-laid-out canvas: hidden overlays
    -- do not receive OnUpdate and therefore cannot poll for its first size.
    self:WatchCanvas(canvas)
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local scale, worldScale = canvas:GetEffectiveScale(), self.world:GetEffectiveScale()
    if not number(width) or not number(height) or not number(scale) or not number(worldScale)
        or width <= 0 or height <= 0 or scale <= 0 or worldScale <= 0 then self:Hide(); return end
    if canvas ~= self.canvas then
        self.canvas = canvas
        self.overlay:SetParent(canvas)
        self.overlay:SetAllPoints(canvas)
        self.overlay:SetFrameLevel(canvas:GetFrameLevel() + 5)
        self:WatchCanvas(canvas)
    end
    local faction, now = playerFaction(), GetTime()
    local character = characterID()
    if force or mapID ~= self.mapID or faction ~= self.faction or character ~= self.character or not self.nodes
        or (self.status ~= 'ready' and now >= self.retryAt) then
        self.nodes, self.status = Flight.Read(mapID)
        self.retryAt = now + 2
        self.mapID, self.faction, self.character = mapID, faction, character
    end
    local nativeNodes, current = self:NativeNodes(self.nodes)
    self:ClearNative(current)
    self.overlay:Show()
    local index, size = 0, ns.PinStyle.Get('flight').size * worldScale / scale
    for _, node in ipairs(self.nodes) do
        if not nativeNodes[node.nodeID] then
            index = index + 1
            local pin = self.pins[index] or self:CreatePin()
            if pin.node and pin.node.nodeID ~= node.nodeID and tooltipOwnedBy(pin) then GameTooltip:Hide() end
            local previous = pin.node
            pin.node = node
            if tooltipOwnedBy(pin) and (not previous or previous.status ~= node.status
                or previous.name ~= node.name or previous.faction ~= node.faction) then showTooltip(pin) end
            pin:SetSize(size, size)
            ns.PinStyle.Apply(pin, 'flight')
            pin:ClearAllPoints()
            pin:SetPoint('CENTER', self.overlay, 'TOPLEFT', node.x * width, -node.y * height)
            local ok = pcall(pin.texture.SetAtlas, pin.texture, node.atlasName)
            if not ok then pin.texture:SetAtlas('FlightPath') end
            tint(pin.texture, node.status)
            pin:Show()
        end
    end
    for n = index + 1, #self.pins do
        if tooltipOwnedBy(self.pins[n]) then GameTooltip:Hide() end
        self.pins[n]:Hide()
    end
    self.visibleCount, self.customCount = #self.nodes, index
end

-- Tracking exists even before Blizzard's world-map UI is loaded.
function Flight.StartTracking()
    if Flight.tracker then return Flight.tracker end
    local tracker = setmetatable({}, Flight)
    tracker.events = CreateFrame('Frame')
    for _, event in ipairs({ 'TAXI_NODE_STATUS_CHANGED', 'TAXIMAP_OPENED', 'TAXIMAP_CLOSED',
        'PLAYER_ENTERING_WORLD', 'PLAYER_LEAVING_WORLD', 'UNIT_FACTION', 'ZONE_CHANGED_NEW_AREA' }) do
        tracker.events:RegisterEvent(event)
    end
    tracker.events:SetScript('OnEvent', function(_, event, unit)
        if event == 'UNIT_FACTION' and (not ns.IsPublic(unit) or unit ~= 'player') then return end
        if event == 'TAXIMAP_OPENED' then tracker.taxiOpen = true
        elseif event == 'TAXIMAP_CLOSED' or event == 'PLAYER_LEAVING_WORLD' then tracker.taxiOpen = false end
        if tracker.taxiOpen then tracker:ObserveVisit() end
        local renderer = tracker.renderer
        if not renderer then return end
        if event == 'PLAYER_LEAVING_WORLD' then renderer.suspended = true; renderer.nodes = nil; renderer:Hide(); return end
        if event == 'PLAYER_ENTERING_WORLD' then renderer.suspended = false end
        renderer:Refresh(true)
    end)
    Flight.tracker = tracker
    return tracker
end

function Flight.New(world)
    local self = setmetatable({ world = world, pins = {}, nativePins = {}, watched = {} }, Flight)
    self.overlay = CreateFrame('Frame', nil, world:GetCanvas())
    local tracker = Flight.StartTracking()
    tracker.renderer = self
    self.events = tracker.events
    local elapsed = 0
    self.overlay:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.2 then elapsed = 0; self:Refresh() end
    end)
    world:HookScript('OnShow', function() self:Refresh(true) end)
    world:HookScript('OnHide', function() self:Hide() end)
    self:Refresh(true)
    return self
end

function Flight.Attach()
    if not ns.settings then return end
    Flight.StartTracking()
    if not Flight.instance and WorldMapFrame and ns.settings then Flight.instance = Flight.New(WorldMapFrame) end
end

function Flight.Update()
    Flight.Attach()
    if Flight.instance then Flight.instance:Refresh(true) end
end
