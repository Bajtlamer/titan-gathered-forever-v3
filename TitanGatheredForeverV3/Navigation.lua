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
    { id = 'history', label = 'Lifetime materials' },
    { id = 'chances', label = 'Observed chances' },
    { id = 'actions', label = 'Profession actions' },
    { id = 'production', label = 'Crafting and cooking' },
    { id = 'reagentUsage', label = 'Reagent use' },
    { id = 'pvp', label = 'PvP Board' },
}

local function windowOf(id)
    if id == 'recipes' then return ns.RecipeBrowser and ns.RecipeBrowser.window end
    return ns.Reports and ns.Reports.windows[id]
end

function Nav.Open(id)
    if id == 'recipes' then ns.RecipeBrowser.Show() else ns.Reports.Show(id) end
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
    window.tabButtons = {}
    local x = 15
    for _, tab in ipairs(Nav.tabs) do
        local b = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
        b:SetSize(130, 22)
        b:SetPoint('TOPLEFT', window, 'TOPLEFT', x, Nav.TAB_Y)
        b:SetText(tab.label)
        local target = tab.id
        b:SetScript('OnClick', function() if target ~= id then Nav.Open(target) end end)
        if target == id and b.LockHighlight then b:LockHighlight() end
        window.tabButtons[target] = b
        x = x + 136
    end
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
