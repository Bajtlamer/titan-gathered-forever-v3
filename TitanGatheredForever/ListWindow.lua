local _, ns = ...
-- A tab window holding one long list: combo boxes for the view and the filters, a search box, sortable column
-- headers, a scroll bar and the mouse wheel. Different lists of one tab are views chosen in the first combo box,
-- never buttons or pages. Escape in the search box clears the search. Used by the Journal tab (kills, quests,
-- levels, deaths and reputation).
local ListWindow = {}
ns.ListWindow = ListWindow

local ROWS, ROW_HEIGHT, WHEEL_STEP, ROW_WIDTH = 16, 22, 3, 910
-- The search label and box on the right of the combo box row; the "Showing" text takes the room between.
local SEARCH_LABEL_X, SEARCH_X, SEARCH_WIDTH = 735, 785, 180
ListWindow.ROWS = ROWS

local function text(parent, font, x, y, width)
    local fontString = parent:CreateFontString(nil, 'OVERLAY', font)
    fontString:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    fontString:SetWidth(width)
    fontString:SetJustifyH('LEFT')
    return fontString
end

function ListWindow.CharacterName(id)
    local record = ns.db and ns.db.characters and ns.db.characters[id]
    if type(record) == 'table' and type(record.economyName) == 'string' then return record.economyName end
end

-- Choices for a character combo box over a store keyed by realm, then character ID: all characters, this
-- character, then the others of the realm by name.
function ListWindow.Characters(store, realm)
    local choices = { { value = false, label = 'All characters' } }
    local ids = {}
    local characters = type(store) == 'table' and store[realm]
    for id in pairs(type(characters) == 'table' and characters or {}) do ids[id] = true end
    if ns.characterID then ids[ns.characterID] = true end
    local others = {}
    for id in pairs(ids) do
        if id == ns.characterID then choices[#choices + 1] = { value = id, label = 'This character' }
        else others[#others + 1] = { value = id, label = ListWindow.CharacterName(id) or tostring(id) } end
    end
    table.sort(others, function(a, b) return a.label < b.label end)
    for _, choice in ipairs(others) do choices[#choices + 1] = choice end
    return choices
end

function ListWindow.Clamp(offset, total)
    return math.max(0, math.min(math.floor(offset + 0.5), math.max(0, total - ROWS)))
end

-- spec: id (the tab), frameName, title, filters ({ width, options(), get(), set(value), modes = { [mode] = true } or
-- nil for every view }), modes (the views). A view: value, label, note, columns ({ label, x, width, kind }), sortKey,
-- default (first order), rows(view) -> rows, extra, cells(row), sortValue(row, column), tie(a, b),
-- search(row) -> lower-case text, tooltip(tip, row), click(row), footer(view, rows, extra), empty, nothing, what.
-- divider = false leaves out the golden line between the column headers and the rows (drawn by default).
-- A spec without modes is a single view.
function ListWindow.Create(spec)
    local modes = spec.modes or { spec }
    local view = { offset = 0, total = 0, spec = spec, sorters = {} }
    local saved = ns.settings and type(ns.settings.listModes) == 'table' and ns.settings.listModes[spec.id]
    view.mode = modes[1].value
    for _, mode in ipairs(modes) do if mode.value == saved then view.mode = saved end end

    function view.Current()
        for _, mode in ipairs(modes) do if mode.value == view.mode then return mode end end
        return modes[1]
    end

    local function visible(filter) return not filter.modes or filter.modes[view.mode] == true end

    -- Shows the header, cells, combo boxes and note of the current view.
    local function layout()
        local w = view.window
        local mode = view.Current()
        w.note:SetText(mode.note or spec.note or '')
        local x = 15
        for index, filter in ipairs(w.filterSpecs) do
            local drop = w.filters[index]
            if visible(filter) then
                drop:ClearAllPoints(); drop:SetPoint('TOPLEFT', w, 'TOPLEFT', x, -65); drop:Show()
                x = x + filter.width + 10
            else drop:Hide() end
        end
        w.rangeText:ClearAllPoints(); w.rangeText:SetPoint('TOPLEFT', w, 'TOPLEFT', x + 5, -70)
        w.rangeText:SetWidth(math.max(60, SEARCH_LABEL_X - 10 - (x + 5)))
        for value, header in pairs(w.headers) do if value == view.mode then header:Show() else header:Hide() end end
        for _, line in ipairs(w.lines) do
            for value, cells in pairs(line.cellSets) do
                for _, cell in ipairs(cells) do if value == view.mode then cell:Show() else cell:Hide() end end
            end
            line.cells = line.cellSets[view.mode]
        end
        view.sorter = view.sorters[view.mode]
    end

    function view.Refresh()
        local w = view.window
        if not w or not w:IsShown() then return end
        local mode = view.Current()
        local rows, extra = mode.rows(view)
        view.all = #rows
        local needle = view.searchText and view.searchText:lower() or ''
        if needle ~= '' then
            local kept = {}
            for _, row in ipairs(rows) do
                if mode.search(row):find(needle, 1, true) then kept[#kept + 1] = row end
            end
            rows = kept
        end
        if not (view.sorter and view.sorter.Apply(rows, mode.sortValue, mode.tie)) then table.sort(rows, mode.tie) end
        view.rows = rows
        view.total = #rows
        view.offset = ListWindow.Clamp(view.offset, view.total)
        for index, drop in ipairs(w.filters) do if visible(w.filterSpecs[index]) then drop.Sync() end end
        w.rangeText:SetText(view.total == 0 and '' or ns.Style.Range(view.offset + 1,
            math.min(view.total, view.offset + ROWS), view.total, mode.what))
        for index = 1, ROWS do
            local line = w.lines[index]
            local row = rows[view.offset + index]
            line.row = row
            if row then
                for i, value in ipairs(mode.cells(row)) do line.cells[i]:SetText(value) end
                line:Show()
            else line:Hide() end
        end
        w.empty:SetText(view.total > 0 and '' or ns.Style.Label(needle ~= '' and 'Nothing matches this search.'
            or (view.all > 0 and (mode.nothing or 'Nothing to show with these choices.') or mode.empty)))
        ns.Nav.SyncScrollbar(w.slider, view.offset, math.max(0, view.total - ROWS))
        w.footer:SetText(mode.footer and mode.footer(view, rows, extra) or '')
    end

    function view.ScrollTo(offset)
        view.offset = ListWindow.Clamp(offset, view.total)
        view.Refresh()
    end
    function view.Scroll(delta) view.ScrollTo(view.offset + delta) end

    -- Filters call this after a change.
    function view.Changed()
        view.offset = 0
        view.Refresh()
    end

    function view.SetMode(value)
        view.mode = value
        if ns.settings then
            if type(ns.settings.listModes) ~= 'table' then ns.settings.listModes = {} end
            ns.settings.listModes[spec.id] = value
        end
        if view.window then layout() end
        view.Changed()
    end

    -- within: optional list of view values; when the current view is not one of them, the first one is shown.
    function view.Show(within)
        if type(within) == 'table' and within[1] then
            local inside = false
            for _, value in ipairs(within) do if value == view.mode then inside = true end end
            if not inside then
                view.mode = within[1]
                if ns.settings then
                    if type(ns.settings.listModes) ~= 'table' then ns.settings.listModes = {} end
                    ns.settings.listModes[spec.id] = view.mode
                end
                view.offset = 0
                if view.window then layout() end
            end
        end
        local w = view.window
        if not w then
            w = CreateFrame('Frame', spec.frameName, UIParent, 'BasicFrameTemplateWithInset')
            view.window = w
            if UISpecialFrames then table.insert(UISpecialFrames, spec.frameName) end
            w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
            w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
            ns.Nav.Frame(w, spec.id)
            w:SetScript('OnHide', function() GameTooltip:Hide() end)
            w.TitleText:SetText(spec.title)
            w.note = text(w, 'GameFontNormalSmall', 15, -33, 950)
            w.filters, w.filterSpecs = {}, {}
            local all = {}
            if #modes > 1 then
                all[1] = { width = spec.modeWidth or 160, options = function()
                    local list = {}
                    for _, mode in ipairs(modes) do list[#list + 1] = { value = mode.value, label = mode.label } end
                    return list
                end, get = function() return view.mode end, set = view.SetMode, isMode = true }
            end
            for _, filter in ipairs(spec.filters or {}) do all[#all + 1] = filter end
            for index, filter in ipairs(all) do
                w.filterSpecs[index] = filter
                w.filters[index] = ns.Nav.Dropdown(w, 15, -65, filter.width, filter.options, filter.get,
                    filter.isMode and filter.set or function(value) filter.set(value); view.Changed() end)
            end
            w.rangeText = text(w, 'GameFontNormalSmall', 400, -70, 280)
            text(w, 'GameFontNormalSmall', SEARCH_LABEL_X, -70, 45):SetText('Search')
            local search = CreateFrame('EditBox', nil, w, 'InputBoxTemplate')
            w.search = search
            search:SetSize(SEARCH_WIDTH, 22); search:SetPoint('TOPLEFT', w, 'TOPLEFT', SEARCH_X, -65); search:SetAutoFocus(false)
            search:SetScript('OnEscapePressed', function(self)
                self:ClearFocus()
                if self:GetText() ~= '' then
                    self:SetText(''); view.searchText = nil; view.Changed()
                end
            end)
            search:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
            search:SetScript('OnTextChanged', function(self, user)
                if not user then return end
                view.searchText = self:GetText()
                view.Changed()
            end)
            -- With the divider (between the column headers and the rows) the rows start 8 px lower, so the line has
            -- room above and below it; the headers keep their place under the combo boxes.
            local top = spec.divider ~= false and -140 or -132
            w.headers = {}
            for _, mode in ipairs(modes) do
                local header = CreateFrame('Frame', nil, w)
                header:SetSize(ROW_WIDTH, 30); header:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -100)
                local headCells, kinds = {}, {}
                for index, column in ipairs(mode.columns) do
                    headCells[index] = text(header, 'GameFontNormalSmall', column[2], 0, column[3])
                    headCells[index]:SetText(column[1])
                    kinds[index] = column[4]
                end
                w.headers[mode.value or 1] = header
                view.sorters[mode.value or 1] = ns.ColumnSort.Attach({ parent = header, cells = headCells, kinds = kinds,
                    key = mode.sortKey, default = mode.default, onChange = view.Changed })
            end
            if spec.divider ~= false then w.divider = ListWindow.Divider(w, 15, -125, ROW_WIDTH) end
            w.lines = {}
            for index = 1, ROWS do
                local line = CreateFrame('Button', nil, w)
                line:SetSize(ROW_WIDTH, ROW_HEIGHT)
                line:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, top - (index - 1) * ROW_HEIGHT)
                line.cellSets = {}
                for _, mode in ipairs(modes) do
                    local cells = {}
                    for i, column in ipairs(mode.columns) do
                        cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3])
                    end
                    line.cellSets[mode.value or 1] = cells
                end
                line:SetScript('OnEnter', function(self)
                    local mode = view.Current()
                    if not self.row or not mode.tooltip then return end
                    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                    mode.tooltip(GameTooltip, self.row)
                    GameTooltip:Show()
                end)
                line:SetScript('OnLeave', function() GameTooltip:Hide() end)
                line:SetScript('OnClick', function(self)
                    local mode = view.Current()
                    if self.row and mode.click then mode.click(self.row) end
                end)
                w.lines[index] = line
            end
            w.empty = text(w, 'GameFontNormalSmall', 15, top - 4, 930)
            w:EnableMouseWheel(true)
            w:SetScript('OnMouseWheel', function(_, delta) view.Scroll(-delta * WHEEL_STEP) end)
            w.slider = ns.Nav.Scrollbar(w, 15 + ROW_WIDTH + 8, top, ROWS * ROW_HEIGHT, function(value)
                view.ScrollTo(value)
            end, function(delta) view.Scroll(-delta * WHEEL_STEP) end)
            w.footer = text(w, 'GameFontNormalSmall', 15, -500, 950)
            if view.mode == nil then view.mode = 1 end
            layout()
        end
        ns.Nav.Activate(spec.id, w)
        w:Show()
        view.Refresh()
    end

    function view.Toggle()
        if view.window and view.window:IsShown() then view.window:Hide() else view.Show() end
    end

    ns.Nav.views = ns.Nav.views or {}
    ns.Nav.views[spec.id] = view
    return view
end

-- The line between the column headers and the rows: Nav.Divider, shared with the other list tabs.
function ListWindow.Divider(...) return ns.Nav.Divider(...) end

-- Shared cell formats.
function ListWindow.Unknown() return ns.Style.Text(ns.Style.gray, 'Unknown') end

function ListWindow.Date(at)
    if not at or not date then return ListWindow.Unknown() end
    return ns.Style.Date(date('%Y-%m-%d', at))
end

function ListWindow.DateTime(at)
    if not at or not date then return ListWindow.Unknown() end
    return ns.Style.Date(date('%Y-%m-%d %H:%M', at))
end

function ListWindow.Zone(mapID)
    if not mapID then return nil end
    local ok, info = pcall(function() return C_Map and C_Map.GetMapInfo(mapID) end)
    local name = ok and type(info) == 'table' and info.name
    if ns.IsPublic(name) and type(name) == 'string' and name ~= '' then return name end
end

function ListWindow.Coordinates(x, y)
    if type(x) ~= 'number' or type(y) ~= 'number' then return nil end
    return string.format('%.1f, %.1f', x * 100, y * 100)
end

-- 45s, 12m, 2h 05m, 3d 4h.
function ListWindow.Duration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds < 60 then return seconds .. 's' end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return minutes .. 'm' end
    local hours = math.floor(minutes / 60)
    if hours < 24 then return string.format('%dh %02dm', hours, minutes % 60) end
    return string.format('%dd %dh', math.floor(hours / 24), hours % 24)
end

-- The player's position on the current zone map, or nil inside instances (no map spots there) or when restricted.
function ListWindow.PlayerSpot()
    local ok, mapID, x, y = pcall(function()
        if IsInInstance then
            local inside = IsInInstance()
            if not ns.IsPublic(inside) or inside then return end
        end
        local id = C_Map.GetBestMapForUnit('player')
        if not ns.IsPublic(id) or type(id) ~= 'number' then return end
        local position = C_Map.GetPlayerMapPosition(id, 'player')
        if not position then return id end
        local px, py = position:GetXY()
        if not ns.IsPublic(px) or not ns.IsPublic(py) or type(px) ~= 'number' or type(py) ~= 'number' then return id end
        return id, px, py
    end)
    if ok and mapID then return mapID, x, y end
end

-- Opens the world map at mapID and marks the pins of npcID with the red rings, like the trainers window.
function ListWindow.ShowOnMap(npcID, mapID)
    if ns.NpcSources and ns.NpcSources.SetHighlight then
        if ns.NpcSources.IsHighlighted(npcID) and ns.NpcSources.HasHighlight() then ns.NpcSources.SetHighlight(nil)
        else ns.NpcSources.SetHighlight({ npcID }) end
    end
    if mapID then
        ns.Nav.ShowMap(mapID)
    end
    if ns.Map and ns.Map.Update then ns.Map.Update() end
    if ns.Minimap and ns.Minimap.Update then ns.Minimap.Update() end
end
