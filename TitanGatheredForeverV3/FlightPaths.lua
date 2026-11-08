local _, ns = ...
local Flight = {}
Flight.__index = Flight
ns.FlightPaths = Flight

local factions = { [0] = 'Neutral', [1] = 'Horde', [2] = 'Alliance' }
local labels = { discovered = 'Discovered', undiscovered = 'Undiscovered', unknown = 'Discovery status unavailable' }

local function number(value)
    return ns.IsPublic(value) and type(value) == 'number' and value == value and value > -math.huge and value < math.huge
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
    if ns.IsPublic(row.isUndiscovered) and type(row.isUndiscovered) == 'boolean' then
        status = row.isUndiscovered and 'undiscovered' or 'discovered'
    end
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
    if force or mapID ~= self.mapID or faction ~= self.faction or not self.nodes
        or (self.status ~= 'ready' and now >= self.retryAt) then
        self.nodes, self.status = Flight.Read(mapID)
        self.retryAt = now + 2
        self.mapID, self.faction = mapID, faction
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
            pin:Show()
        end
    end
    for n = index + 1, #self.pins do
        if tooltipOwnedBy(self.pins[n]) then GameTooltip:Hide() end
        self.pins[n]:Hide()
    end
    self.visibleCount, self.customCount = #self.nodes, index
end

function Flight.New(world)
    local self = setmetatable({ world = world, pins = {}, nativePins = {}, watched = {} }, Flight)
    self.overlay = CreateFrame('Frame', nil, world:GetCanvas())
    self.events = CreateFrame('Frame')
    for _, event in ipairs({ 'TAXI_NODE_STATUS_CHANGED', 'TAXIMAP_OPENED', 'TAXIMAP_CLOSED',
        'PLAYER_ENTERING_WORLD', 'PLAYER_LEAVING_WORLD', 'UNIT_FACTION', 'ZONE_CHANGED_NEW_AREA' }) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript('OnEvent', function(_, event, unit)
        if event == 'UNIT_FACTION' and (not ns.IsPublic(unit) or unit ~= 'player') then return end
        if event == 'PLAYER_LEAVING_WORLD' then self.suspended = true; self.nodes = nil; self:Hide(); return end
        if event == 'PLAYER_ENTERING_WORLD' then self.suspended = false end
        self:Refresh(true)
    end)
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
    if not Flight.instance and WorldMapFrame and ns.settings then Flight.instance = Flight.New(WorldMapFrame) end
end

function Flight.Update()
    Flight.Attach()
    if Flight.instance then Flight.instance:Refresh(true) end
end
