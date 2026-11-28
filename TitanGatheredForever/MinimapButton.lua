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

-- The modules of the collection, from the game's addon list: each installed module with its state, Active (loaded and
-- switched on), Switched off (loaded, hidden in the TGF settings) or Disabled (off in the AddOns list), and every module
-- of the collection that is not in the list as Not installed (ns.KnownModules, generated with the catalogue). Every
-- installed module shows its version; Discovery has its own version line, the others share the core's.
local PREFIX = 'TitanGatheredForever_'
local FOLDER_IDS = { AuctionItems = 'Auction', Herbalism = 'Herbs' }   -- when the generated list is missing
function Button.Modules()
    local api = C_AddOns
    if not api or not api.GetNumAddOns or not api.GetAddOnInfo then return {} end
    local loaded = api.IsAddOnLoaded or IsAddOnLoaded
    local known = {}
    for _, module in ipairs(ns.KnownModules or {}) do known[module.folder] = module end
    local rows, seen = {}, {}
    local okCount, count = pcall(api.GetNumAddOns)
    for index = 1, okCount and type(count) == 'number' and count or 0 do
        local ok, name, title = pcall(api.GetAddOnInfo, index)
        if ok and type(name) == 'string' and name:sub(1, #PREFIX) == PREFIX then
            seen[name] = true
            local suffix = name:sub(#PREFIX + 1)
            local module = known[name]
            local label = type(title) == 'string' and title:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') or suffix
            label = label:gsub('^Titan Gathered Forever: ', ''):gsub('^Titan Gathered ', '')
            -- the settings key of the module (Herbs for the Herbalism folder), from the generated list
            local row = { name = name, id = module and module.id or FOLDER_IDS[suffix] or suffix, label = label, discovery = suffix == 'Discovery' }
            local okLoaded, isLoaded = false, nil
            if loaded then okLoaded, isLoaded = pcall(loaded, name) end
            if not okLoaded or isLoaded ~= true then row.state = 'disabled'
            -- Hiding the Auction items group only hides the material list group: the Auction house features keep running.
            elseif not row.discovery and row.id ~= 'Auction' and ns.settings and type(ns.settings.categories) == 'table'
                and ns.settings.categories[row.id] == false then row.state = 'off'
            else row.state = 'active' end
            if api.GetAddOnMetadata then
                local okVersion, version = pcall(api.GetAddOnMetadata, name, 'Version')
                if okVersion and type(version) == 'string' then row.version = version end
            end
            rows[#rows + 1] = row
        end
    end
    for _, module in ipairs(ns.KnownModules or {}) do
        if not seen[module.folder] then
            rows[#rows + 1] = { name = module.folder, id = module.id, label = module.label, state = 'missing',
                discovery = module.standalone == true }
        end
    end
    -- installed modules first, then Discovery, then what is not installed, each by name
    local function rank(row) return (row.state == 'missing' and 2 or 0) + (row.discovery and 1 or 0) end
    table.sort(rows, function(a, b)
        if rank(a) ~= rank(b) then return rank(a) < rank(b) end
        return a.label < b.label
    end)
    return rows
end

-- The modules that are not professions get a game icon of their own: a coin for the auction house, a spyglass for Discovery.
Button.MODULE_ICONS = { Auction = 'Interface\\Icons\\INV_Misc_Coin_01', Discovery = 'Interface\\Icons\\INV_Misc_Spyglass_02' }
function Button.Icon(id)
    local Style = ns.Style
    local icon = Style.ProfessionIcon and Style.ProfessionIcon(id) or ''
    if icon == '' and Button.MODULE_ICONS[id] and Style.Icon then icon = Style.Icon(Button.MODULE_ICONS[id]) end
    return icon
end

local STATES = { active = { 'Active', 'green' }, off = { 'Switched off', 'gray' }, disabled = { 'Disabled', 'orange' },
    missing = { 'Not installed', 'gray' } }

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
    local missing, outdated = false, false
    for _, row in ipairs(modules) do
        local state = STATES[row.state]
        local icon = Button.Icon(row.id)
        -- a module that is not installed is named in gray, so the installed ones stand out
        local color = row.state == 'missing' and Style.gray or (Style.white or 'ffffffff')
        -- a profession or auction module of another version than the core is shown in orange: update it
        local stale = row.version and not row.discovery and version ~= '' and row.version ~= version
        local label = icon .. Style.Text(color, row.label)
            .. (row.version and Style.Text(stale and (Style.orange or Style.gray) or Style.gray, ' v' .. row.version) or '')
        outdated = outdated or stale
        tip:AddDoubleLine(label, Style.Text(Style[state[2]] or Style.gray, state[1]))
        missing = missing or row.state == 'missing'
    end
    if outdated then tip:AddLine(Style.Text(Style.orange or Style.gray, 'A module in orange is of another version than the core: update it.')) end
    if missing then tip:AddLine(Style.Text(Style.gray, 'Modules not installed: CurseForge or titan-gathered.com')) end
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
