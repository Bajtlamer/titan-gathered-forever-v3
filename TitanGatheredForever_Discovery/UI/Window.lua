local _, ns = ...
-- The overview window: what is new or different, with filters, search, paging and a detail panel. It uses the window
-- helpers of the core (drag position, dropdown, scroll bar). If the window cannot be built, a message says so and
-- nothing else is affected.
local Window = {}
ns.Window = Window

local ROW_HEIGHT, ROW_WIDTH, WHEEL_STEP = 22, 910, 3
local columns = { { 'Category', 0, 90 }, { 'ID', 95, 70 }, { 'Name', 170, 220 }, { 'State', 395, 90 }, { 'Seen', 490, 45 },
    { 'Last seen', 540, 90 }, { 'Notes', 635, 275 } }

local function text(parent, font, x, y, width)
    local fontString = parent:CreateFontString(nil, 'OVERLAY', font)
    fontString:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    fontString:SetWidth(width)
    fontString:SetJustifyH('LEFT')
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
    w.TitleText:SetText('Titan Gathered Forever: Discovery')
    w.header = text(w, 'GameFontNormalSmall', 15, -33, 950)
    w.showFilter = Nav.Dropdown(w, 15, -75, 190, function() return View.SHOWS end, function() return View.show end, function(value)
        View.show, View.offset = value, 0; Window.Refresh()
    end)
    w.categoryFilter = Nav.Dropdown(w, 215, -75, 190, function()
        local list = { { value = false, label = 'All categories' } }
        for _, category in ipairs(ns.Database.CATEGORIES) do list[#list + 1] = { value = category, label = ns.Compare.LABELS[category] } end
        return list
    end, function() return View.category end, function(value)
        View.category, View.offset = value, 0; Window.Refresh()
    end)
    w.rangeText = text(w, 'GameFontNormalSmall', 420, -80, 270)
    text(w, 'GameFontNormalSmall', 700, -80, 50):SetText('Search')
    local search = CreateFrame('EditBox', nil, w, 'InputBoxTemplate')
    w.search = search
    search:SetSize(150, 22); search:SetPoint('TOPLEFT', w, 'TOPLEFT', 755, -75); search:SetAutoFocus(false)
    search:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    search:SetScript('OnTextChanged', function(self, user)
        if not user then return end
        local value = self:GetText()
        View.search, View.offset = type(value) == 'string' and value or '', 0
        Window.Refresh()
    end)
    button(w, 'Clear', 910, -75, 60, function()
        search:SetText(''); search:ClearFocus(); View.search, View.offset = '', 0
        Window.Refresh()
    end)
    local head = CreateFrame('Frame', nil, w)
    head:SetSize(ROW_WIDTH, 30); head:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -108)
    for _, column in ipairs(columns) do text(head, 'GameFontNormalSmall', column[2], 0, column[3]):SetText(column[1]) end
    w.lines = {}
    for index = 1, View.ROWS do
        local line = CreateFrame('Button', nil, w)
        line:SetSize(ROW_WIDTH, ROW_HEIGHT)
        line:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -138 - (index - 1) * ROW_HEIGHT)
        line.cells = {}
        for i, column in ipairs(columns) do line.cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3]) end
        line:SetScript('OnClick', function(self)
            if self.row then View.selected = self.row; Window.Refresh() end
        end)
        w.lines[index] = line
    end
    w:EnableMouseWheel(true)
    w:SetScript('OnMouseWheel', function(_, delta) Window.Scroll(-delta * WHEEL_STEP) end)
    w.slider = Nav.Scrollbar(w, 15 + ROW_WIDTH + 8, -138, View.ROWS * ROW_HEIGHT, function(value) Window.ScrollTo(value) end,
        function(delta) Window.Scroll(-delta * WHEEL_STEP) end)
    w.detail = text(w, 'GameFontHighlightSmall', 15, -500, 950)
    w.detail:SetHeight(90)
    w.reviewButton = button(w, 'Mark reviewed', 855, -505, 115, function()
        if View.selected then View.ToggleReviewed(View.selected); Window.Refresh() end
    end)
    return w
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
    local ok, err = pcall(Window.Refresh)
    if not ok then ns.Print(ns.Text.Label('The window could not be filled: ') .. ns.Text.Value(tostring(err))) end
end

function Window.Toggle()
    if Window.window and Window.window:IsShown() then Window.window:Hide() else Window.Show() end
end
