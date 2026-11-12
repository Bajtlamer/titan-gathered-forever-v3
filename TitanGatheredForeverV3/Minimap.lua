local _, ns = ...
local Mini = {}
Mini.__index = Mini
ns.Minimap = Mini

local function number(value)
    return ns.IsPublic(value) and type(value) == 'number' and value == value
end

function Mini.New(minimap, controller)
    local self = setmetatable({ minimap = minimap, controller = controller, pins = {} }, Mini)
    self.overlay = CreateFrame('Frame', nil, minimap)
    self.overlay:SetAllPoints(minimap)
    self.overlay:SetFrameLevel(minimap:GetFrameLevel() + 5)
    local elapsed = 0
    self.overlay:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.2 then elapsed = 0; self:Refresh() end
    end)
    self:Refresh()
    return self
end

function Mini:HidePins()
    for _, pin in ipairs(self.pins) do pin:Hide() end
    self.visibleCount = 0
end

function Mini:CreatePin()
    local pin = CreateFrame('Button', nil, self.overlay)
    pin:SetSize(14, 14)
    ns.PinStyle.Apply(pin, 'minimap')
    pin:SetScript('OnEnter', function(button)
        GameTooltip:SetOwner(button, 'ANCHOR_LEFT')
        if button.node.npcID and ns.NpcSources then
            ns.NpcSources.FillTooltip(GameTooltip, button.node)
            GameTooltip:Show()
            return
        end
        if button.node.kind == 'PvP' then
            GameTooltip:AddLine(ns.PinStyle.Label(button.node.kind))
            GameTooltip:AddLine('Open-world PvP honorable kills')
            GameTooltip:AddLine(string.format('%d honorable kills', button.node.count or 0))
            if button.node.honorEstimate and button.node.honorEstimate > 0 then
                GameTooltip:AddLine(string.format('Estimated honor: %d', button.node.honorEstimate))
            end
        else
            GameTooltip:AddLine(ns.Style.ItemName(button.node.itemID))
            GameTooltip:AddLine(ns.PinStyle.Label(button.node.kind))
            GameTooltip:AddLine(string.format('Observed %d times', button.node.count or 0))
            local history, note = ns.PinStyle.HistoryLines(button.node)
            for _, line in ipairs(history) do GameTooltip:AddLine(line) end
            ns.Style.Separator(GameTooltip)
            if note then GameTooltip:AddLine(note) end
            GameTooltip:AddLine('Previously gathered here; the resource may not have respawned.')
        end
        GameTooltip:Show()
    end)
    pin:SetScript('OnLeave', function() GameTooltip:Hide() end)
    self.pins[#self.pins + 1] = pin
    return pin
end

function Mini:Refresh()
    local npcs = ns.NpcSources and ns.NpcSources.Enabled()
    if not (ns.settings.gatheringMap or npcs) or ns.settings.mapMinimap == false then
        self.overlay:Hide(); self:HidePins(); return
    end
    self.overlay:Show()
    if not self.minimap:IsShown() then
        self:HidePins(); return
    end
    local ok, mapID, x, y, width, height, radius, facing = pcall(function()
        local id = C_Map.GetBestMapForUnit('player')
        if not number(id) then return end
        local position = C_Map.GetPlayerMapPosition(id, 'player')
        if not position then return end
        local px, py = position:GetXY()
        local w, h = C_Map.GetMapWorldSize(id)
        local angle = 0
        if GetCVar('rotateMinimap') == '1' and not C_Minimap.IsRotateMinimapIgnored() then angle = GetPlayerFacing() end
        return id, px, py, w, h, C_Minimap.GetViewRadius(), angle
    end)
    if not ok or not number(mapID) or not number(x) or not number(y)
        or not number(width) or not number(height) or not number(radius) or not number(facing)
        or width <= 0 or height <= 0 or radius <= 0 then self:HidePins(); return end
    local halfWidth, halfHeight = self.minimap:GetWidth() / 2, self.minimap:GetHeight() / 2
    local style = ns.PinStyle.Get('minimap')
    local extent = style.size / 2 * (style.shape == 'square' and math.sqrt(2) or 1) * (style.border and 1.1 or 1)
    local clip = math.min(0.85, math.max(0, 1 - extent / math.min(halfWidth, halfHeight)))
    local cosine, sine, visible = math.cos(facing), math.sin(facing), 0
    local combined = {}
    if ns.settings.gatheringMap then
        for _, node in ipairs(self.controller:List(mapID)) do combined[#combined + 1] = node end
    end
    if npcs then
        for _, node in ipairs(ns.NpcSources.List(mapID)) do combined[#combined + 1] = node end
    end
    for _, node in ipairs(combined) do
        local east, north = (node.x - x) * width, (y - node.y) * height
        local dx, dy = (east * cosine + north * sine) / radius, (-east * sine + north * cosine) / radius
        local px, py = dx * halfWidth, dy * halfHeight
        if halfWidth > 0 and halfHeight > 0 and (px / halfWidth)^2 + (py / halfHeight)^2 <= clip^2 then
            visible = visible + 1
            local pin = self.pins[visible] or self:CreatePin()
            pin:SetSize(style.size, style.size)
            ns.PinStyle.Apply(pin, 'minimap')
            pin.node = node
            pin:ClearAllPoints()
            pin:SetPoint('CENTER', self.overlay, 'CENTER', px, py)
            pin.texture:SetTexture(ns.PinStyle.Icon(node.itemID, node.kind))
            pin:Show()
        end
    end
    for index = visible + 1, #self.pins do self.pins[index]:Hide() end
    self.visibleCount = visible
end

function Mini.Attach()
    if Mini.instance or not Minimap or not ns.gathering then return end
    Mini.instance = Mini.New(Minimap, ns.gathering)
end

function Mini.Update()
    if Mini.instance then Mini.instance:Refresh() end
end
