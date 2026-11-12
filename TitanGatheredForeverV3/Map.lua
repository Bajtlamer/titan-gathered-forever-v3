local _, ns = ...
local Map = {}
Map.__index = Map
ns.Map = Map

function Map.New(world, controller)
    local canvas = world:GetCanvas()
    local self = setmetatable({ world = world, controller = controller, canvas = canvas, pins = {}, dirty = true }, Map)
    self.clearButton = CreateFrame('Button', nil, world, 'UIPanelButtonTemplate')
    self.clearButton:SetSize(82, 22)
    self.clearButton:SetPoint('TOPRIGHT', world, 'TOPRIGHT', -45, -30)
    self.clearButton:SetText('TGF v3 spots')
    self.clearButton:SetScript('OnClick', function(button) ns.Titan.ClearSpotsMenu(button, world) end)
    self.clearButton:Show()
    self.overlay = CreateFrame('Frame', nil, canvas)
    self.overlay:SetAllPoints(canvas)
    self.overlay:SetFrameLevel(canvas:GetFrameLevel() + 5)
    self:WatchCanvas(canvas)
    local elapsed = 0
    self.overlay:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.2 then elapsed = 0; self:Refresh() end
    end)
    world:HookScript('OnShow', function() self:Refresh(true) end)
    world:HookScript('OnHide', function() self:Hide() end)
    controller.changed = function() self.dirty = true; self:Refresh() end
    self:Refresh(true)
    return self
end

function Map:WatchCanvas(canvas)
    self.watched = self.watched or {}
    if self.watched[canvas] then return end
    self.watched[canvas] = true
    canvas:HookScript('OnSizeChanged', function() self:Refresh(true) end)
end

function Map:Hide()
    self.overlay:Hide()
    for _, pin in ipairs(self.pins) do pin:Hide() end
    self.visibleCount = 0
end

function Map:GatheringNodes(mapID)
    local result = {}
    for _, node in ipairs(self.controller:List(mapID)) do result[#result + 1] = node end
    if #result >= 500 then return result end
    local maps = self.controller.saved and self.controller.saved.maps
    if not maps or not C_Map or not C_Map.GetMapRectOnMap then return result end
    for sourceMap in pairs(maps) do
        if sourceMap ~= mapID and type(sourceMap) == 'number' then
            local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, sourceMap, mapID)
            if ok and ns.IsPublic(left) and ns.IsPublic(right) and ns.IsPublic(top) and ns.IsPublic(bottom)
                and type(left) == 'number' and type(right) == 'number'
                and type(top) == 'number' and type(bottom) == 'number' then
                for _, node in ipairs(self.controller:List(sourceMap)) do
                    local x, y = left + node.x * (right - left), top + node.y * (bottom - top)
                    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                        result[#result + 1] = { x = x, y = y, itemID = node.itemID, kind = node.kind, mapID = sourceMap,
                            count = node.count, honorEstimate = node.honorEstimate, lastSeen = node.lastSeen,
                            sourceX = node.x, sourceY = node.y }
                        if #result >= 500 then return result end
                    end
                end
            end
        end
    end
    return result
end

function Map:Nodes(mapID)
    local result = {}
    if ns.settings.gatheringMap then result = self:GatheringNodes(mapID) end
    if ns.NpcSources and ns.NpcSources.Enabled() then
        for _, node in ipairs(ns.NpcSources.List(mapID)) do result[#result + 1] = node end
    end
    return result
end

function Map:CreatePin()
    local pin = CreateFrame('Button', nil, self.overlay)
    -- The native scroll-frame drawing pass covers MEDIUM addon children even
    -- when their frame levels exceed the tile frames. Verified on Forever.
    pin:SetFrameStrata('HIGH')
    pin:SetSize(14, 14)
    ns.PinStyle.Apply(pin)
    pin:SetScript('OnEnter', function(button)
        local node = button.node
        GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
        if node.npcID and ns.NpcSources then
            ns.NpcSources.FillTooltip(GameTooltip, node)
            GameTooltip:Show()
            return
        end
        if node.kind == 'PvP' then
            GameTooltip:AddLine(ns.PinStyle.Label(node.kind))
            GameTooltip:AddLine('Open-world PvP honorable kills')
            GameTooltip:AddLine(string.format('%d honorable kills', node.count or 0))
            if node.honorEstimate and node.honorEstimate > 0 then
                GameTooltip:AddLine(string.format('Estimated honor: %d', node.honorEstimate))
            end
            GameTooltip:AddLine(string.format('Recorded near %.1f, %.1f',
                (node.sourceX or node.x) * 100, (node.sourceY or node.y) * 100))
            if node.lastSeen then GameTooltip:AddLine('Last seen: ' .. date('%Y-%m-%d %H:%M', node.lastSeen)) end
        else
            GameTooltip:AddLine(ns.Style.ItemName(node.itemID))
            GameTooltip:AddLine(ns.PinStyle.Label(node.kind))
            GameTooltip:AddLine(string.format('Observed %d times near %.1f, %.1f', node.count,
                (node.sourceX or node.x) * 100, (node.sourceY or node.y) * 100))
            local history, note = ns.PinStyle.HistoryLines(node)
            for _, line in ipairs(history) do GameTooltip:AddLine(line) end
            ns.Style.Separator(GameTooltip)
            if note then GameTooltip:AddLine(note) end
            GameTooltip:AddLine('Recorded near your gathering position.')
        end
        GameTooltip:Show()
    end)
    pin:SetScript('OnLeave', function() GameTooltip:Hide() end)
    self.pins[#self.pins + 1] = pin
    return pin
end

function Map:Refresh(force)
    local npcs = ns.NpcSources and ns.NpcSources.Enabled()
    if not (ns.settings.gatheringMap or npcs) or ns.settings.mapWorld == false or not self.world:IsShown() then self:Hide(); return end
    local mapID, canvas = self.world:GetMapID(), self.world:GetCanvas()
    if not mapID or not canvas then self:Hide(); return end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if width <= 0 or height <= 0 then self:Hide(); return end
    local canvasScale, worldScale = canvas:GetEffectiveScale(), self.world:GetEffectiveScale()
    if canvasScale <= 0 or worldScale <= 0 then self:Hide(); return end
    local style = ns.PinStyle.Get('world')
    local iconSize = style.size * worldScale / canvasScale
    self.overlay:Show()
    if not force and not self.dirty and canvas == self.canvas and mapID == self.mapID and width == self.width
        and height == self.height and iconSize == self.iconSize then return end
    if canvas ~= self.canvas then
        self.canvas = canvas; self.overlay:SetParent(canvas); self.overlay:SetAllPoints(canvas)
        self.overlay:SetFrameLevel(canvas:GetFrameLevel() + 5)
        self:WatchCanvas(canvas)
    end
    self.mapID, self.width, self.height, self.dirty = mapID, width, height, false
    self.iconSize = iconSize
    local nodes = self:Nodes(mapID)
    self.visibleCount = #nodes
    for index, node in ipairs(nodes) do
        local pin = self.pins[index] or self:CreatePin()
        pin.node = node
        pin:SetSize(iconSize, iconSize)
        ns.PinStyle.Apply(pin, 'world')
        ns.PinStyle.Highlight(pin, node.npcID ~= nil and ns.NpcSources ~= nil and ns.NpcSources.IsHighlighted(node.npcID))
        pin:ClearAllPoints()
        pin:SetPoint('CENTER', self.overlay, 'TOPLEFT', node.x * width, -node.y * height)
        pin.texture:SetTexture(ns.PinStyle.Icon(node.itemID, node.kind))
        pin:Show()
    end
    for index = #nodes + 1, #self.pins do self.pins[index]:Hide() end
end

function Map.Attach()
    if Map.instance or not WorldMapFrame or not ns.gathering then return end
    Map.instance = Map.New(WorldMapFrame, ns.gathering)
end

function Map.Update()
    if Map.instance then Map.instance:Refresh(true) end
end
