local _, ns = ...
local Browser = { offset = 0, total = 0, status = 'unvisited' }
ns.TrainerBrowser = Browser

local ROWS, ROW_HEIGHT, WHEEL_STEP = 16, 22, 3
local columns = { { 'Trainer', 0, 230 }, { 'Profession', 240, 130 }, { 'Zone', 380, 200 }, { 'Coordinates', 590, 110 },
    { 'Status', 710, 195 } }
local ROW_WIDTH = 910
local statuses = { { value = 'unvisited', label = 'Not visited' }, { value = 'visited', label = 'Visited' },
    { value = 'all', label = 'All trainers' } }

function Browser.Cells(row)
    local Style = ns.Style
    local status = 'Not visited'
    if row.visited then
        local when = row.lastSeen and date and (' ' .. Style.Date(date('%Y-%m-%d', row.lastSeen))) or ''
        status = Style.Text(Style.gold, 'Visited') .. when
    end
    return { Style.ProfessionIcon(row.kind) .. Style.Text(Style.green, row.name), ns.NpcSources.Label(row.kind), row.zone or 'Unknown',
        row.x and string.format('%.1f, %.1f', row.x, row.y) or 'Unknown', status }
end

-- Sorting by a header. Coordinates sort by x, then y; Status puts the visited trainers first (the newest visit on top).
local KINDS = { 'text', 'text', 'text', 'number', 'number' }
function Browser.SortValue(row, column)
    if column == 1 then return string.lower(tostring(row.name)) end
    if column == 2 then return string.lower(tostring(ns.NpcSources.Label(row.kind))) end
    if column == 3 then return row.zone and string.lower(tostring(row.zone)) or nil end
    if column == 4 then return row.x and (row.x * 1000 + (row.y or 0)) or nil end
    return row.visited and (row.lastSeen or 1) or 0
end
function Browser.Tie(a, b)
    local nameA, nameB = string.lower(tostring(a.name)), string.lower(tostring(b.name))
    if nameA ~= nameB then return nameA < nameB end
    return tostring(a.npcID) < tostring(b.npcID)
end

function Browser.Clamp(offset, total)
    local last = math.max(0, total - ROWS)
    return math.max(0, math.min(math.floor(offset + 0.5), last))
end

function Browser.RangeText(offset, total)
    if total == 0 then return 'No trainers' end
    return ns.Style.Range(offset + 1, math.min(total, offset + ROWS), total)
end

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

function Browser.Toggle()
    if Browser.window and Browser.window:IsShown() then Browser.window:Hide() else Browser.Show() end
end

function Browser.ScrollTo(offset)
    Browser.offset = Browser.Clamp(offset, Browser.total)
    Browser.Refresh()
end
function Browser.Scroll(delta) Browser.ScrollTo(Browser.offset + delta) end

-- Opens the world map at the trainer and marks the trainer with a red ring. Clicking the same trainer again
-- clears the mark, like in the recipes window.
local function openMap(line)
    local row = line.row
    if not row then return end
    if Browser.marked == row.npcID and ns.NpcSources.HasHighlight() then
        Browser.marked = nil
        ns.NpcSources.SetHighlight(nil)
    else
        Browser.marked = row.npcID
        ns.NpcSources.SetHighlight({ row.npcID })
    end
    local mapID = row.mapID or ns.NpcSources.ContinentMap(row.npcID)
    if mapID then
        ns.Nav.ShowMap(mapID)
    end
    if ns.Map and ns.Map.Update then ns.Map.Update() end
    if ns.Minimap and ns.Minimap.Update then ns.Minimap.Update() end
end

function Browser.Refresh()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    local rows = ns.NpcSources.Trainers(Browser.status, Browser.kind)
    if Browser.searchText and Browser.searchText ~= '' then
        local needle, kept = Browser.searchText:lower(), {}
        for _, row in ipairs(rows) do
            local haystack = (row.name .. ' ' .. ns.NpcSources.Label(row.kind) .. ' ' .. (row.zone or '')):lower()
            if haystack:find(needle, 1, true) then kept[#kept + 1] = row end
        end
        rows = kept
    end
    if Browser.sorter then Browser.sorter.Apply(rows, Browser.SortValue, Browser.Tie) end
    Browser.total = #rows
    Browser.offset = Browser.Clamp(Browser.offset, Browser.total)
    w.filter.Sync()
    w.kindButton.Sync()
    w.rangeText:SetText(Browser.RangeText(Browser.offset, Browser.total))
    for index = 1, ROWS do
        local line = w.lines[index]
        local row = rows[Browser.offset + index]
        line.row = row
        if row then
            for i, value in ipairs(Browser.Cells(row)) do line.cells[i]:SetText(value) end
            line:Show()
        else line:Hide() end
    end
    ns.Nav.SyncScrollbar(w.slider, Browser.offset, math.max(0, Browser.total - ROWS))
    local unknown = 0
    for _, row in ipairs(rows) do if not row.x then unknown = unknown + 1 end end
    w.footer:SetText(unknown > 0 and (unknown .. ' trainers have no known position and cannot be shown on the map.') or '')
end

function Browser.Show()
    local w = Browser.window
    if not w then
        local name = 'TitanGatheredForeverTrainerBrowserWindow'
        w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
        Browser.window = w
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        ns.Nav.Frame(w, 'trainers')
        w:SetScript('OnHide', function() GameTooltip:Hide() end)
        w.TitleText:SetText('Titan Gathered Forever Trainers')
        local note = text(w, 'GameFontNormalSmall', 15, -33, 930)
        note:SetText('Profession trainers from the Classic seed and from your visits. A trainer counts as visited once its window was opened and recorded. Positions of trainers not visited yet are converted from Classic data. Hover a row to see what the trainer teaches; click a row to open the map and mark the trainer.')
        w.filter = ns.Nav.Dropdown(w, 15, -65, 150, function() return statuses end,
            function() return Browser.status end, function(value)
                Browser.status, Browser.offset = value, 0; Browser.Refresh()
            end)
        w.kindButton = ns.Nav.Dropdown(w, 175, -65, 190, function()
            local list = { { value = false, label = 'All professions' } }
            for _, kind in ipairs(ns.NpcSources.InstalledKinds(ns.NpcSources.Kinds)) do list[#list + 1] = { value = kind, label = ns.NpcSources.Label(kind) } end
            return list
        end, function() return Browser.kind or false end, function(value)
            Browser.kind, Browser.offset = value or nil, 0; Browser.Refresh()
        end)
        w.rangeText = text(w, 'GameFontNormalSmall', 380, -70, 300)
        text(w, 'GameFontNormalSmall', 690, -70, 50):SetText('Search')
        local search = CreateFrame('EditBox', nil, w, 'InputBoxTemplate')
        w.search = search
        search:SetSize(150, 22); search:SetPoint('TOPLEFT', w, 'TOPLEFT', 745, -65); search:SetAutoFocus(false)
        search:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
        search:SetScript('OnTextChanged', function(self, user)
            if not user then return end
            Browser.searchText, Browser.offset = self:GetText(), 0
            Browser.Refresh()
        end)
        button(w, 'Clear', 905, -65, 60, function()
            search:SetText(''); search:ClearFocus(); Browser.searchText, Browser.offset = nil, 0
            Browser.Refresh()
        end)
        local header = CreateFrame('Frame', nil, w)
        header:SetSize(ROW_WIDTH, 30); header:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -100)
        local headCells = {}
        for index, column in ipairs(columns) do
            headCells[index] = text(header, 'GameFontNormalSmall', column[2], 0, column[3])
            headCells[index]:SetText(column[1])
        end
        if ns.ColumnSort then
            Browser.sorter = ns.ColumnSort.Attach({ parent = header, cells = headCells, kinds = KINDS, key = 'trainers',
                onChange = function() Browser.offset = 0; Browser.Refresh() end })
        end
        w.lines = {}
        for index = 1, ROWS do
            local line = CreateFrame('Button', nil, w)
            line:SetSize(ROW_WIDTH, ROW_HEIGHT)
            line:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -140 - (index - 1) * ROW_HEIGHT)
            line.cells = {}
            for i, column in ipairs(columns) do line.cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3]) end
            line:SetScript('OnClick', openMap)
            line:SetScript('OnEnter', function(self)
                if not self.row then return end
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                ns.NpcSources.FillTooltip(GameTooltip, { kind = 'Trainer', npcID = self.row.npcID })
                GameTooltip:Show()
            end)
            line:SetScript('OnLeave', function() GameTooltip:Hide() end)
            w.lines[index] = line
        end
        w:EnableMouseWheel(true)
        w:SetScript('OnMouseWheel', function(_, delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        ns.Nav.Divider(w, 15, -125, ROW_WIDTH)  -- the line between the headers and the rows, as on every list tab
        w.slider = ns.Nav.Scrollbar(w, 15 + ROW_WIDTH + 8, -140, ROWS * ROW_HEIGHT, function(value)
            Browser.ScrollTo(value)
        end, function(delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        w.footer = text(w, 'GameFontHighlightSmall', 15, -520, 930)
    end
    ns.Nav.Activate('trainers', w)
    w:Show()
    Browser.Refresh()
end
