local _, ns = ...
-- The window of the module, with two tabs: the collected data (what is new or different, with filters, search, paging
-- and a detail panel) and a guide that explains how the module works and how to hand the data over. It uses the window
-- helpers of the core (drag position, dropdown, scroll bar). If the window cannot be built, a message says so and
-- nothing else is affected.
local Window = {}
ns.Window = Window

local ROW_HEIGHT, ROW_WIDTH, WHEEL_STEP = 22, 910, 3
local GUIDE_TOP, GUIDE_HEIGHT, GUIDE_LINE = -40, 520, 14       -- the text of the guide scrolls by lines of 14 pixels
local TABS = { { 'data', 'Collected data' }, { 'guide', 'How it works' } }
-- The last column ends at the right edge of the list, the first one has room for "Vendors and trainers", the name takes the rest.
local columns = { { 'Category', 0, 140 }, { 'ID', 145, 70 }, { 'Name', 220, 370 }, { 'State', 600, 150 }, { 'Seen', 755, 50 },
    { 'Last seen', 810, 100 } }

local function text(parent, font, x, y, width, single)
    local fontString = parent:CreateFontString(nil, 'OVERLAY', font)
    fontString:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    fontString:SetWidth(width)
    fontString:SetJustifyH('LEFT')
    -- A cell of a row is one line: a long text is cut instead of running into the next row.
    if single then
        fontString:SetWordWrap(false)
        if fontString.SetMaxLines then fontString:SetMaxLines(1) end
    end
    return fontString
end

local function button(parent, label, x, y, width, callback)
    local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    b:SetSize(width, 22)
    b:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    b:SetText(label)
    b:SetScript('OnClick', callback)
    return b
end

local function build()
    local View, Nav = ns.View, _G.TitanGatheredForeverV3.Nav
    local name = 'TitanGatheredForeverDiscoveryWindow'
    local w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    w:SetSize(985, 600)
    w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
    Nav.Draggable(w, 'discovery')
    w.TitleText:SetText('Titan Gathered Discovery')
    -- Two pages over the same area, one for each tab.
    local data, guide = CreateFrame('Frame', nil, w), CreateFrame('Frame', nil, w)
    data:SetAllPoints(w); guide:SetAllPoints(w)
    w.pages, w.page = { data = data, guide = guide }, 'data'
    w.header = text(data, 'GameFontNormalSmall', 15, -33, 950)
    w.showFilter = Nav.Dropdown(data, 15, -75, 190, function() return View.SHOWS end, function() return View.show end, function(value)
        View.show, View.offset = value, 0; Window.Refresh()
    end)
    w.categoryFilter = Nav.Dropdown(data, 215, -75, 190, function()
        local list = { { value = false, label = 'All categories' } }
        for _, category in ipairs(ns.Database.CATEGORIES) do list[#list + 1] = { value = category, label = ns.Compare.LABELS[category] } end
        return list
    end, function() return View.category end, function(value)
        View.category, View.offset = value, 0; Window.Refresh()
    end)
    w.rangeText = text(data, 'GameFontNormalSmall', 420, -80, 270)
    text(data, 'GameFontNormalSmall', 700, -80, 50):SetText('Search')
    local search = CreateFrame('EditBox', nil, data, 'InputBoxTemplate')
    w.search = search
    search:SetSize(150, 22); search:SetPoint('TOPLEFT', data, 'TOPLEFT', 755, -75); search:SetAutoFocus(false)
    search:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    search:SetScript('OnTextChanged', function(self, user)
        if not user then return end
        local value = self:GetText()
        View.search, View.offset = type(value) == 'string' and value or '', 0
        Window.Refresh()
    end)
    button(data, 'Clear', 910, -75, 60, function()
        search:SetText(''); search:ClearFocus(); View.search, View.offset = '', 0
        Window.Refresh()
    end)
    local head = CreateFrame('Frame', nil, data)
    head:SetSize(ROW_WIDTH, 30); head:SetPoint('TOPLEFT', data, 'TOPLEFT', 15, -108)
    for _, column in ipairs(columns) do text(head, 'GameFontNormalSmall', column[2], 0, column[3]):SetText(column[1]) end
    w.lines = {}
    for index = 1, View.ROWS do
        local line = CreateFrame('Button', nil, data)
        line:SetSize(ROW_WIDTH, ROW_HEIGHT)
        line:SetPoint('TOPLEFT', data, 'TOPLEFT', 15, -138 - (index - 1) * ROW_HEIGHT)
        line.cells = {}
        for i, column in ipairs(columns) do line.cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3], true) end
        line:SetScript('OnClick', function(self)
            if self.row then View.selected = self.row; Window.Refresh() end
        end)
        w.lines[index] = line
    end
    w:EnableMouseWheel(true)
    w:SetScript('OnMouseWheel', function(_, delta)
        if w.page == 'guide' then Window.GuideScroll(-delta * WHEEL_STEP) else Window.Scroll(-delta * WHEEL_STEP) end
    end)
    w.slider = Nav.Scrollbar(data, 15 + ROW_WIDTH + 8, -138, View.ROWS * ROW_HEIGHT, function(value) Window.ScrollTo(value) end,
        function(delta) Window.Scroll(-delta * WHEEL_STEP) end)
    w.detail = text(data, 'GameFontHighlightSmall', 15, -500, 950)
    w.detail:SetHeight(90)
    w.reviewButton = button(data, 'Mark reviewed', 855, -505, 115, function()
        if View.selected then View.ToggleReviewed(View.selected); Window.Refresh() end
    end)
    -- The guide: one wrapped text in a clipped area that scrolls.
    local clip = CreateFrame('Frame', nil, guide)
    clip:SetSize(ROW_WIDTH, GUIDE_HEIGHT); clip:SetPoint('TOPLEFT', guide, 'TOPLEFT', 15, GUIDE_TOP)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local content = CreateFrame('Frame', nil, clip)
    content:SetSize(ROW_WIDTH - 10, GUIDE_HEIGHT); content:SetPoint('TOPLEFT', clip, 'TOPLEFT', 0, 0)
    w.guideText = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    w.guideText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
    w.guideText:SetWidth(ROW_WIDTH - 10); w.guideText:SetJustifyH('LEFT')
    if w.guideText.SetWordWrap then w.guideText:SetWordWrap(true) end
    w.guideContent, w.guideOffset = content, 0
    w.guideSlider = Nav.Scrollbar(guide, 15 + ROW_WIDTH + 8, GUIDE_TOP, GUIDE_HEIGHT, function(value) Window.GuideScrollTo(value) end,
        function(delta) Window.GuideScroll(-delta * WHEEL_STEP) end)
    guide:Hide()
    -- The tabs hang below the window like the tabs of the core windows; plain buttons inside the window when the client
    -- has no panel tabs, so the window never fails to open.
    w.tabButtons, w.Tabs = {}, {}
    local previous
    for index, tab in ipairs(TABS) do
        local id = tab[1]
        local ok, b = pcall(CreateFrame, 'Button', nil, w, 'PanelTabButtonTemplate')
        if ok and b then
            b:SetID(index); b:SetText(tab[2])
            if previous then b:SetPoint('LEFT', previous, 'RIGHT', -16, 0) else b:SetPoint('TOPLEFT', w, 'BOTTOMLEFT', 15, 2) end
        else
            b = button(w, tab[2], 15 + (index - 1) * 130, -572, 125, function() end)
        end
        b:SetScript('OnClick', function() Window.SetPage(id) end)
        w.tabButtons[id] = b
        w.Tabs[index] = b
        previous = b
    end
    if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, w, #TABS) end
    -- A panel tab measures its text before the first layout pass and cuts it: fit the tabs when the window opens, and
    -- again a moment later (the same way the tabs of the core windows are fitted).
    local function fit()
        Window.FitTabs(w)
        if C_Timer and C_Timer.After then
            for _, delay in ipairs({ 0.1, 0.5, 1.5 }) do
                C_Timer.After(delay, function() if w:IsShown() then Window.FitTabs(w) end end)
            end
        end
    end
    if w.HookScript then w:HookScript('OnShow', fit) end
    fit()                    -- a new frame is already shown, so its first Show never raises OnShow
    return w
end

function Window.FitTabs(w)
    w = w or Window.window
    if not w or not w.tabButtons then return end
    for _, b in pairs(w.tabButtons) do
        local name = b.GetName and b:GetName()
        local label = b.Text or (type(name) == 'string' and _G[name .. 'Text'])
        if type(label) ~= 'table' then label = nil end
        if label and label.SetWidth then label:SetWidth(0) end
        local width = label and label.GetStringWidth and label:GetStringWidth()
        if type(width) ~= 'number' or width <= 0 then width = nil end
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, nil, nil, nil, nil, width) end
        local current = b.GetWidth and b:GetWidth()
        if width and b.SetWidth and type(current) == 'number' and current < width + 16 then b:SetWidth(width + 30) end
    end
end

-- Fills the guide and fits the scroll bar to the length of its text.
function Window.RefreshGuide()
    local w, Nav = Window.window, _G.TitanGatheredForeverV3.Nav
    if not w then return end
    w.guideText:SetText(ns.Guide.Text())
    local height = w.guideText.GetStringHeight and w.guideText:GetStringHeight()
    if type(height) ~= 'number' or height <= 0 then height = 40 * GUIDE_LINE end
    w.guideContent:SetHeight(height)
    w.guideLines = math.max(0, math.ceil((height - GUIDE_HEIGHT) / GUIDE_LINE))
    w.guideOffset = math.max(0, math.min(w.guideOffset or 0, w.guideLines))
    w.guideContent:SetPoint('TOPLEFT', w.guideContent:GetParent() or w, 'TOPLEFT', 0, w.guideOffset * GUIDE_LINE)
    Nav.SyncScrollbar(w.guideSlider, w.guideOffset, w.guideLines)
end

function Window.GuideScrollTo(offset)
    local w = Window.window
    if not w then return end
    w.guideOffset = math.max(0, math.min(math.floor(offset + 0.5), w.guideLines or 0))
    w.guideContent:SetPoint('TOPLEFT', w.guideContent:GetParent() or w, 'TOPLEFT', 0, w.guideOffset * GUIDE_LINE)
    _G.TitanGatheredForeverV3.Nav.SyncScrollbar(w.guideSlider, w.guideOffset, w.guideLines or 0)
end
function Window.GuideScroll(delta)
    local w = Window.window
    if w then Window.GuideScrollTo((w.guideOffset or 0) + delta) end
end

-- Shows one of the two tabs ('data' or 'guide').
function Window.SetPage(page)
    local w = Window.window
    if not w then return end
    if page ~= 'guide' then page = 'data' end
    w.page = page
    if page == 'guide' then w.pages.data:Hide(); w.pages.guide:Show() else w.pages.guide:Hide(); w.pages.data:Show() end
    if PanelTemplates_SetTab then
        for index, tab in ipairs(TABS) do if tab[1] == page then pcall(PanelTemplates_SetTab, w, index) end end
    end
    if page == 'guide' then
        local ok, err = pcall(Window.RefreshGuide)
        if not ok then ns.Print(ns.Text.Label('The guide could not be filled: ') .. ns.Text.Value(tostring(err))) end
    else
        pcall(Window.Refresh)
    end
end

function Window.ScrollTo(offset)
    ns.View.offset = offset
    Window.Refresh()
end
function Window.Scroll(delta) Window.ScrollTo(ns.View.offset + delta) end

function Window.Refresh()
    local w, View = Window.window, ns.View
    if not w or not w:IsShown() then return end
    local rows = View.Rows() or {}
    View.offset = View.Clamp(View.offset, #rows)
    w.header:SetText(View.Header())
    w.showFilter.Sync()
    w.categoryFilter.Sync()
    w.rangeText:SetText(View.RangeText(View.offset, #rows))
    for index = 1, View.ROWS do
        local line, row = w.lines[index], rows[View.offset + index]
        line.row = row
        if row then
            for i, value in ipairs(View.Cells(row)) do line.cells[i]:SetText(value) end
            line:Show()
        else
            line:Hide()
        end
    end
    _G.TitanGatheredForeverV3.Nav.SyncScrollbar(w.slider, View.offset, math.max(0, #rows - View.ROWS))
    w.detail:SetText(View.selected and table.concat(View.DetailText(View.selected), '\n') or '')
    w.reviewButton:SetText(View.selected and View.IsReviewed(View.selected) and 'Clear reviewed mark' or 'Mark reviewed')
end

function Window.Show()
    if not Window.window then
        local ok, result = pcall(build)
        if not ok then
            ns.Print(ns.Text.Label('The window could not be built: ') .. ns.Text.Value(tostring(result)))
            return
        end
        Window.window = result
    end
    Window.window:Show()
    Window.SetPage('data')                  -- the window opens on the collected data
    local ok, err = pcall(Window.Refresh)
    if not ok then ns.Print(ns.Text.Label('The window could not be filled: ') .. ns.Text.Value(tostring(err))) end
end

function Window.Toggle()
    if Window.window and Window.window:IsShown() then Window.window:Hide() else Window.Show() end
end
