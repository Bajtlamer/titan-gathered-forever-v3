local _, ns = ...
local Button = {}
ns.MinimapButton = Button

-- A round button on the minimap edge: left click toggles the recipes and statistics window, right click opens the
-- addon menu, dragging moves it around the minimap. Same look and placement rules as other Titan plugins.
local DEFAULT_ANGLE, OFFSET = 205, 22

Button.HINTS = {
    'Left click: recipes and statistics. Right click: settings menu.',
    'Drag: move around the minimap. Mouse wheel: next page.',
}

function Button.Position(angle, width, height)
    local radians = math.rad(angle)
    return math.cos(radians) * (width / 2 + OFFSET), math.sin(radians) * (height / 2 + OFFSET)
end

function Button.AngleFromCursor(cursorX, cursorY, centerX, centerY)
    local angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    if angle < 0 then angle = angle + 360 end
    return angle
end

local function place()
    local button = Button.button
    if not button or not Minimap then return end
    local x, y = Button.Position(ns.settings.minimapButtonAngle or DEFAULT_ANGLE, Minimap:GetWidth(), Minimap:GetHeight())
    button:ClearAllPoints()
    button:SetPoint('CENTER', Minimap, 'CENTER', x, y)
end

function Button.Update()
    if Button.button then Button.button:SetShown(ns.settings.showMinimapButton ~= false) end
end

function Button.Attach()
    if Button.button or not Minimap then return end
    local button = CreateFrame('Button', 'TitanGatheredForeverMinimapButton', UIParent)
    Button.button = button
    button:SetSize(32, 32)
    button:SetFrameStrata('MEDIUM')
    button:SetFrameLevel(8)

    local background = button:CreateTexture(nil, 'BACKGROUND')
    background:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
    background:SetSize(24, 24)
    background:SetPoint('CENTER')
    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetTexture('Interface\\AddOns\\TitanGatheredForever\\Artwork\\AddonIcon')
    icon:SetSize(20, 20)
    icon:SetPoint('CENTER')
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    if button.CreateMaskTexture then
        local mask = button:CreateMaskTexture()
        if mask then
            mask:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask')
            mask:SetAllPoints(icon)
            icon:AddMaskTexture(mask)
        end
    end
    local border = button:CreateTexture(nil, 'OVERLAY')
    border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
    border:SetSize(54, 54)
    border:SetPoint('TOPLEFT')

    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    button:RegisterForDrag('LeftButton')
    button:SetScript('OnClick', function(self, which)
        if which == 'RightButton' then ns.Titan.Menu(self) else ns.Nav.Toggle() end
    end)
    -- Pointing at the button shows the material list, as the panel entry does, so it works without Titan Panel.
    button:SetScript('OnEnter', function(self)
        if ns.Titan and ns.Titan.Show and ns.inventory then ns.Titan.Show(self, 'ANCHOR_LEFT', Button.HINTS); return end
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:AddLine(ns.Style.Text(ns.Style.gold, 'Titan Gathered Forever'))
        for _, hint in ipairs(Button.HINTS) do GameTooltip:AddLine(ns.Style.Text(ns.Style.gray, hint)) end
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function()
        if ns.Titan and ns.Titan.Hide then ns.Titan.Hide() end
        GameTooltip:Hide()
    end)
    if button.EnableMouseWheel then button:EnableMouseWheel(true) end
    button:SetScript('OnMouseWheel', function(self, delta)
        if not (ns.Titan and ns.Titan.owner == self) then return end
        ns.Titan.page = math.max(1, (ns.Titan.page or 1) - delta)
        ns.Titan.Show(self, 'ANCHOR_LEFT', Button.HINTS)
    end)
    button:SetScript('OnDragStart', function(self)
        self:SetScript('OnUpdate', function()
            local centerX, centerY = Minimap:GetCenter()
            if not centerX then return end
            local scale = Minimap:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            ns.settings.minimapButtonAngle = Button.AngleFromCursor(cursorX / scale, cursorY / scale, centerX, centerY)
            place()
        end)
    end)
    button:SetScript('OnDragStop', function(self) self:SetScript('OnUpdate', nil) end)
    place()
    Button.Update()
end
