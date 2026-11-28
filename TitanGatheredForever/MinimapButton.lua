local _, ns = ...
local Button = {}
ns.MinimapButton = Button

-- A round button on the minimap edge: left click toggles the recipes and statistics window, right click opens the
-- addon menu, dragging moves it around the minimap. Same look and placement rules as other Titan plugins.
local DEFAULT_ANGLE, OFFSET = 205, 22

Button.HINTS = {
    'Left click: your materials, recipes and statistics',
    'Right click: settings menu',
    'Drag: move around the minimap',
}

-- The addons of the collection that are installed, from the game's addon list: each module with its state, Active
-- (loaded and switched on), Switched off (loaded, hidden in the TGF settings) or Disabled (off in the AddOns list).
-- Discovery has its own version line, so its version is shown.
local PREFIX = 'TitanGatheredForever_'
local moduleIDs = { AuctionItems = 'Auction' }
function Button.Modules()
    local api = C_AddOns
    if not api or not api.GetNumAddOns or not api.GetAddOnInfo then return {} end
    local loaded = api.IsAddOnLoaded or IsAddOnLoaded
    local rows = {}
    local okCount, count = pcall(api.GetNumAddOns)
    for index = 1, okCount and type(count) == 'number' and count or 0 do
        local ok, name, title = pcall(api.GetAddOnInfo, index)
        if ok and type(name) == 'string' and name:sub(1, #PREFIX) == PREFIX then
            local suffix = name:sub(#PREFIX + 1)
            local label = type(title) == 'string' and title:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') or suffix
            label = label:gsub('^Titan Gathered Forever: ', ''):gsub('^Titan Gathered ', '')
            local row = { name = name, id = moduleIDs[suffix] or suffix, label = label, discovery = suffix == 'Discovery' }
            local okLoaded, isLoaded = false, nil
            if loaded then okLoaded, isLoaded = pcall(loaded, name) end
            if not okLoaded or isLoaded ~= true then row.state = 'disabled'
            elseif not row.discovery and ns.settings and type(ns.settings.categories) == 'table'
                and ns.settings.categories[row.id] == false then row.state = 'off'
            else row.state = 'active' end
            if row.discovery and api.GetAddOnMetadata then
                local okVersion, version = pcall(api.GetAddOnMetadata, name, 'Version')
                if okVersion and type(version) == 'string' then row.version = version end
            end
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        if a.discovery ~= b.discovery then return not a.discovery end
        return a.label < b.label
    end)
    return rows
end

local STATES = { active = { 'Active', 'green' }, off = { 'Switched off', 'gray' }, disabled = { 'Disabled', 'orange' } }

-- What the button shows when pointed at: the version, the installed modules with their state, the Titan Panel
-- entry and the clicks.
function Button.Tooltip(tip)
    local Style = ns.Style
    local version
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, 'TitanGatheredForever', 'Version')
        if ok and type(value) == 'string' then version = value end
    end
    version = version or (ns.Titan and ns.Titan.version) or ''
    tip:AddDoubleLine(Style.Text(Style.gold, 'Titan Gathered Forever'), Style.Text(Style.white or 'ffffffff', 'v' .. version))
    local modules = Button.Modules()
    tip:AddLine(' ')
    tip:AddLine(Style.Text(Style.gold, 'Modules'))
    if #modules == 0 then tip:AddLine(Style.Text(Style.gray, 'No profession module installed.')) end
    for _, row in ipairs(modules) do
        local state = STATES[row.state]
        local icon = Style.ProfessionIcon and Style.ProfessionIcon(row.id) or ''
        local label = icon .. Style.Text(Style.white or 'ffffffff', row.label) .. (row.version and Style.Text(Style.gray, ' v' .. row.version) or '')
        tip:AddDoubleLine(label, Style.Text(Style[state[2]] or Style.gray, state[1]))
    end
    local panel = ns.Titan and ns.Titan.PanelState and ns.Titan.PanelState() or 'missing'
    local panelStates = { active = { 'Active', 'green' }, disabled = { 'Disabled', 'orange' }, missing = { 'Not installed', 'gray' } }
    local shown = panelStates[panel] or panelStates.missing
    tip:AddDoubleLine(Style.Text(Style.gold, 'Titan Panel'), Style.Text(Style[shown[2]] or Style.gray, shown[1]))
    tip:AddLine(' ')
    for _, hint in ipairs(Button.HINTS) do tip:AddLine(Style.Text(Style.gray, hint)) end
end

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
    button:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        Button.Tooltip(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function() GameTooltip:Hide() end)
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
