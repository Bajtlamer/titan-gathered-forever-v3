local _, ns = ...
local Nav = {}
ns.Nav = Nav

-- Shared shell of the statistics and recipes windows: one tab strip along the bottom of every window, one remembered
-- position, one size, and a classic scroll bar helper. The tabs are separate frames that replace each other, so a tab
-- keeps its own filters and scroll position while it looks like a single window with several pages.
Nav.WIDTH, Nav.HEIGHT = 985, 592
Nav.TAB_Y = -558
Nav.tabs = {
    { id = 'materials', label = 'My materials' },
    { id = 'recipes', label = 'Unlearned recipes' },
    { id = 'trainers', label = 'Trainers' },
    { id = 'history', label = 'Lifetime materials' },
    { id = 'chances', label = 'Observed chances' },
    { id = 'profit', label = 'Crafting profit' },
    { id = 'pvp', label = 'PvP Board' },
    { id = 'economy', label = 'Economy' },
    { id = 'journal', label = 'Journal' },
}
-- List windows built by ListWindow.Create register themselves here by tab id. Kills and quests are views of the
-- Journal tab (the strip ran out of room at eleven tabs); their ids still open the Journal at those views.
Nav.views = Nav.views or {}
Nav.aliases = { kills = { 'creatures', 'drops', 'rares' }, quests = { 'quests' } }

local function windowOf(id)
    if Nav.views[id] then return Nav.views[id].window end
    if id == 'recipes' then return ns.RecipeBrowser and ns.RecipeBrowser.window end
    if id == 'trainers' then return ns.TrainerBrowser and ns.TrainerBrowser.window end
    if id == 'profit' then return ns.ProfitBrowser and ns.ProfitBrowser.window end
    if id == 'economy' then return ns.EconomyView and ns.EconomyView.window end
    return ns.Reports and ns.Reports.windows[id]
end

function Nav.Open(id)
    if Nav.aliases[id] and Nav.views.journal then Nav.views.journal.Show(Nav.aliases[id])
    elseif Nav.views[id] then Nav.views[id].Show()
    elseif id == 'recipes' then ns.RecipeBrowser.Show()
    elseif id == 'trainers' then ns.TrainerBrowser.Show()
    elseif id == 'profit' then ns.ProfitBrowser.Show()
    elseif id == 'economy' then ns.EconomyView.Show()
    elseif id == 'production' then ns.ProfessionStats.Open()
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
    if id then window:Hide() else Nav.Open(Nav.last or 'materials') end
end

-- Window positions are kept in the saved variables (windowPositions), one per window or group of windows, so a
-- moved window opens where it was left, also after /reload and a restart. A position is { point, relative point, x, y }
-- relative to the screen. Without saved variables (tests) it is kept in memory only.
local memory = {}
local function positions()
    if ns.db then
        if type(ns.db.windowPositions) ~= 'table' then ns.db.windowPositions = {} end
        return ns.db.windowPositions
    end
    return memory
end

local function validPosition(saved)
    return type(saved) == 'table' and type(saved[1]) == 'string' and type(saved[2]) == 'string'
        and type(saved[3]) == 'number' and type(saved[4]) == 'number'
        and saved[3] == saved[3] and saved[4] == saved[4] and math.abs(saved[3]) < 1e5 and math.abs(saved[4]) < 1e5
end

function Nav.SavePosition(key, window)
    if not window or not window.GetPoint then return end
    local point, _, relative, x, y = window:GetPoint()
    if point then positions()[key] = { point, relative or point, x or 0, y or 0 } end
end

-- Puts a window where it was left. Returns whether a saved position was used.
function Nav.RestorePosition(key, window)
    local saved = positions()[key]
    if not validPosition(saved) then return false end
    window:ClearAllPoints()
    window:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    return true
end

-- Forgets every saved position; the windows open in the middle of the screen again.
function Nav.ResetPositions()
    for key in pairs(positions()) do positions()[key] = nil end
    Nav.point = nil
end

-- The art of a window frame is partly transparent, so windows that overlap showed through each other. A solid dark
-- layer behind the art makes a window opaque, and a click raises a window above the others.
function Nav.Solid(window)
    if window.CreateTexture then
        local background = window:CreateTexture(nil, 'BACKGROUND', nil, -8)
        background:SetPoint('TOPLEFT', window, 'TOPLEFT', 3, -3)
        background:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -3, 3)
        background:SetColorTexture(0.07, 0.07, 0.08, 1)
        window.solidBackground = background
    end
    if window.SetToplevel then window:SetToplevel(true) end
end

-- Moving a window keeps the position; the dragging itself is the same for every window.
function Nav.Draggable(window, key)
    Nav.Solid(window)
    window:SetScript('OnDragStart', function(self) self:StartMoving() end)
    window:SetScript('OnDragStop', function(self) self:StopMovingOrSizing(); Nav.SavePosition(key, self) end)
    Nav.RestorePosition(key, window)
end

-- Called by every tab window when it opens: hides the other tabs and takes over the shared position.
function Nav.Activate(id, window)
    Nav.last = id
    for _, tab in ipairs(Nav.tabs) do
        local other = windowOf(tab.id)
        if other and other ~= window and other:IsShown() then other:Hide() end
    end
    Nav.RestorePosition('nav', window)
end

function Nav.Remember(window)
    Nav.SavePosition('nav', window)
end

-- The tab strip hangs below the window: keep it on screen too.
Nav.TAB_DEPTH = 32

-- A window and its tab strip larger than the screen (a small resolution or a large UI scale) are scaled down to
-- fit, so nothing is cut off; on screens with room they keep their normal size.
function Nav.FitToScreen(window)
    if not (window and window.SetScale and UIParent and UIParent.GetWidth) then return end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if type(width) ~= 'number' or type(height) ~= 'number' or width <= 0 or height <= 0 then return end
    local scale = math.min(1, (width - 8) / Nav.WIDTH, (height - 8) / (Nav.HEIGHT + Nav.TAB_DEPTH))
    if scale <= 0 then return end
    if not window.GetScale or math.abs((window:GetScale() or 1) - scale) > 0.001 then window:SetScale(scale) end
end

local fitted = {}
-- Dragging, size and the tab strip common to all tab windows.
function Nav.Frame(window, id)
    window:SetSize(Nav.WIDTH, Nav.HEIGHT)
    if window.SetClampRectInsets then window:SetClampRectInsets(0, 0, 0, -Nav.TAB_DEPTH) end
    Nav.FitToScreen(window)
    fitted[#fitted + 1] = window
    if window.HookScript then window:HookScript('OnShow', function(self) Nav.FitToScreen(self) end) end
    Nav.Draggable(window, 'nav')
    Nav.Tabs(window, id)
end

-- A changed resolution or UI scale refits the windows already made.
if CreateFrame then
    local ok, watcher = pcall(CreateFrame, 'Frame')
    if ok and watcher and watcher.RegisterEvent and watcher.SetScript then
        pcall(watcher.RegisterEvent, watcher, 'DISPLAY_SIZE_CHANGED')
        pcall(watcher.RegisterEvent, watcher, 'UI_SCALE_CHANGED')
        watcher:SetScript('OnEvent', function()
            for _, window in ipairs(fitted) do Nav.FitToScreen(window) end
        end)
    end
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
        -- The whole strip must stay under the window: when the names (another font or language) are wider than
        -- the window, the strip is scaled down as one piece instead of running past the right edge.
        local total = 0
        for _, b in ipairs(window.Tabs) do total = total + ((b.GetWidth and b:GetWidth()) or 0) end
        total = total - 16 * (#window.Tabs - 1)
        local room = Nav.WIDTH - 30
        local scale = (total > room and total > 0) and room / total or 1
        for _, b in ipairs(window.Tabs) do if b.SetScale then b:SetScale(scale) end end
        local first = window.Tabs[1]
        if first and first.ClearAllPoints then
            first:ClearAllPoints()
            first:SetPoint('TOPLEFT', window, 'BOTTOMLEFT', 15 / scale, 2 / scale)
        end
        window.tabScale = scale
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
