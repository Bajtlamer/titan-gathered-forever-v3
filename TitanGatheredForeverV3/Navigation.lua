local _, ns = ...
local Nav = {}
ns.Nav = Nav

-- Shared shell of the statistics and recipes windows: one tab strip along the bottom of every window, one remembered
-- position, one size, and a classic scroll bar helper. The tabs are separate frames that replace each other, so a tab
-- keeps its own filters and scroll position while it looks like a single window with several pages.
Nav.WIDTH, Nav.HEIGHT = 985, 592
Nav.TAB_Y = -558
Nav.tabs = {
    { id = 'recipes', label = 'Unlearned recipes' },
    { id = 'trainers', label = 'Trainers' },
    { id = 'history', label = 'Lifetime materials' },
    { id = 'chances', label = 'Observed chances' },
    { id = 'actions', label = 'Profession actions' },
    { id = 'production', label = 'Crafting and cooking' },
    { id = 'reagentUsage', label = 'Reagent use' },
    { id = 'pvp', label = 'PvP Board' },
}

local function windowOf(id)
    if id == 'recipes' then return ns.RecipeBrowser and ns.RecipeBrowser.window end
    if id == 'trainers' then return ns.TrainerBrowser and ns.TrainerBrowser.window end
    return ns.Reports and ns.Reports.windows[id]
end

function Nav.Open(id)
    if id == 'recipes' then ns.RecipeBrowser.Show()
    elseif id == 'trainers' then ns.TrainerBrowser.Show()
    else ns.Reports.Show(id) end
end

-- The id of the tab window that is on screen, if any.
function Nav.Current()
    for _, tab in ipairs(Nav.tabs) do
        local window = windowOf(tab.id)
        if window and window:IsShown() then return tab.id, window end
    end
end

-- Opens the last used tab, or closes the window when one is already open (the minimap button).
function Nav.Toggle()
    local id, window = Nav.Current()
    if id then window:Hide() else Nav.Open(Nav.last or 'recipes') end
end

-- Called by every tab window when it opens: hides the other tabs and takes over the shared position.
function Nav.Activate(id, window)
    Nav.last = id
    for _, tab in ipairs(Nav.tabs) do
        local other = windowOf(tab.id)
        if other and other ~= window and other:IsShown() then other:Hide() end
    end
    if Nav.point then
        window:ClearAllPoints()
        window:SetPoint(Nav.point[1], UIParent, Nav.point[2], Nav.point[3], Nav.point[4])
    end
end

function Nav.Remember(window)
    if not window.GetPoint then return end
    local point, _, relative, x, y = window:GetPoint()
    if point then Nav.point = { point, relative or point, x or 0, y or 0 } end
end

-- Dragging, size and the tab strip common to all tab windows.
function Nav.Frame(window, id)
    window:SetSize(Nav.WIDTH, Nav.HEIGHT)
    window:SetScript('OnDragStart', function(self) self:StartMoving() end)
    window:SetScript('OnDragStop', function(self) self:StopMovingOrSizing(); Nav.Remember(self) end)
    Nav.Tabs(window, id)
end

-- Classic panel tabs hanging below the window (PanelTabButtonTemplate); plain buttons inside the window when the
-- client does not provide them, so the window never fails to open.
local function panelTabs(window, id)
    local previous
    window.Tabs = {}
    for index, tab in ipairs(Nav.tabs) do
        local b = CreateFrame('Button', nil, window, 'PanelTabButtonTemplate')
        b:SetID(index)
        b:SetText(tab.label)
        if previous then b:SetPoint('LEFT', previous, 'RIGHT', -16, 0)
        else b:SetPoint('TOPLEFT', window, 'BOTTOMLEFT', 15, 2) end
        local target = tab.id
        b:SetScript('OnClick', function() if target ~= id then Nav.Open(target) end end)
        window.Tabs[index] = b
        window.tabButtons[target] = b
        previous = b
        if target == id then window.activeTab = index end
    end
    PanelTemplates_SetNumTabs(window, #Nav.tabs)
    PanelTemplates_SetTab(window, window.activeTab or 1)
    -- The first window after the game starts cut its tab names ("Unlearn..."): the template measures the text
    -- with GetWidth, which is still 0 before the first layout pass. GetStringWidth is exact at once, so it is
    -- handed to the resize as the text width, and the resize is repeated a few times while the window is open.
    local function labelOf(b)
        return b.Text or (b.GetName and b:GetName() and _G[b:GetName() .. 'Text'])
    end
    local function fit()
        for _, b in ipairs(window.Tabs) do
            local label = labelOf(b)
            -- Measured live: a new tab text has a fixed width of 52, so GetStringWidth only reports the cut text
            -- ("Unlearn..." is about 50). Without the fixed width it reports the real 94.
            if label and label.SetWidth then label:SetWidth(0) end
            local width = label and label.GetStringWidth and label:GetStringWidth()
            if type(width) ~= 'number' or width <= 0 then width = nil end
            if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, nil, nil, nil, nil, width) end
            -- Still narrower than its own text: set the width directly.
            if width and b.GetWidth and b.SetWidth and (b:GetWidth() or 0) < width + 16 then b:SetWidth(width + 30) end
        end
    end
    local function onShow()
        fit()
        if C_Timer and C_Timer.After then
            for _, delay in ipairs({ 0.1, 0.5, 1.5 }) do
                C_Timer.After(delay, function() if window:IsShown() then fit() end end)
            end
        end
    end
    if window.HookScript then window:HookScript('OnShow', onShow) else window:SetScript('OnShow', onShow) end
    -- A new frame is already shown, so its first Show never fires OnShow: that was the whole bug, the fit ran only
    -- after the window had been hidden and shown again. Measure once now as well.
    onShow()
end

local function buttonTabs(window, id)
    local step = math.floor((Nav.WIDTH - 30) / #Nav.tabs)
    local x = 15
    for _, tab in ipairs(Nav.tabs) do
        local b = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
        b:SetSize(step - 6, 22)
        b:SetPoint('TOPLEFT', window, 'TOPLEFT', x, Nav.TAB_Y)
        b:SetText(tab.label)
        local target = tab.id
        b:SetScript('OnClick', function() if target ~= id then Nav.Open(target) end end)
        if target == id and b.LockHighlight then b:LockHighlight() end
        window.tabButtons[target] = b
        x = x + step
    end
end

function Nav.Tabs(window, id)
    window.tabButtons = {}
    if PanelTemplates_SetNumTabs and PanelTemplates_SetTab and pcall(panelTabs, window, id) then return end
    for _, b in pairs(window.tabButtons) do b:Hide() end
    window.tabButtons = {}
    buttonTabs(window, id)
end

-- A combo box in the Blizzard style: a drop down showing the selected choice. options() returns the list of
-- { value = ..., label = ... }; get() the current value; set(value) applies a choice. Falls back to a button with
-- a context menu when the client has no drop down template. The returned frame has Sync() to show a value that
-- was changed from code.
function Nav.Dropdown(parent, x, y, width, options, get, set)
    local function labelOf()
        local current = get()
        for _, option in ipairs(options()) do if option.value == current then return option.label end end
        return ''
    end
    local ok, drop = pcall(CreateFrame, 'DropdownButton', nil, parent, 'WowStyle1DropdownTemplate')
    if ok and drop and drop.SetupMenu then
        drop:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
        drop:SetWidth(width)
        drop:SetupMenu(function(_, root)
            for _, option in ipairs(options()) do
                local value = option.value
                root:CreateRadio(option.label, function() return get() == value end, function() set(value) end)
            end
            if root.SetScrollMode then root:SetScrollMode(350) end
        end)
        drop.Sync = function() if drop.GenerateMenu then drop:GenerateMenu() end end
        return drop
    end
    local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    b:SetSize(width, 22)
    b:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    b:SetScript('OnClick', function(owner)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, option in ipairs(options()) do
                local value = option.value
                root:CreateButton(option.label, function() set(value); b.Sync() end)
            end
        end)
    end)
    b.Sync = function() b:SetText(labelOf()) end
    b.Sync()
    return b
end

-- A vertical scroll bar. scrollTo(offset) receives the dragged position; wheel(delta) the mouse wheel over the bar.
function Nav.Scrollbar(window, x, y, height, scrollTo, wheel)
    local slider = CreateFrame('Slider', nil, window)
    slider:SetOrientation('VERTICAL')
    slider:SetPoint('TOPLEFT', window, 'TOPLEFT', x, y)
    slider:SetSize(16, height)
    slider:SetMinMaxValues(0, 0); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    local track = slider:CreateTexture(nil, 'BACKGROUND')
    track:SetAllPoints(slider); track:SetColorTexture(0, 0, 0, 0.35)
    slider:SetThumbTexture('Interface\\Buttons\\UI-ScrollBar-Knob')
    slider:GetThumbTexture():SetSize(16, 24)
    slider:EnableMouseWheel(true)
    slider:SetScript('OnMouseWheel', function(_, delta) wheel(delta) end)
    slider:SetScript('OnValueChanged', function(self, value)
        if not rawget(self, 'syncing') then scrollTo(value) end
    end)
    return slider
end

-- Mirrors the offset onto the bar without feeding it back, and hides the bar when everything fits.
function Nav.SyncScrollbar(slider, offset, last)
    slider.syncing = true
    slider:SetMinMaxValues(0, last)
    slider:SetValue(offset)
    slider.syncing = false
    if last > 0 then slider:Show() else slider:Hide() end
end
