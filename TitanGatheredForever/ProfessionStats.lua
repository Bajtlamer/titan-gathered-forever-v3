local _, ns = ...
local View = {}
ns.ProfessionStats = View

local Style = ns.Style
local ROWS, HEIGHT, TOP = 16, 23, -115
local PORTRAIT_WIDTH, PORTRAIT_BAND = 76, 40

-- The gathering professions have no recipes, so Production.Kind does not know them; their skill lines are named here.
local GATHERING_SKILLS = { [182] = 'Herbs', [393] = 'Skinning', [356] = 'Fishing' }

local function activeKind()
    local frame = View.host
    local page = frame and frame.CraftingPage
    if not (page and page:IsShown()) then return nil end
    local info = page.professionInfo or frame.professionInfo
    local kind = ns.Production.Kind(info)
    if kind then return kind end
    if ns.IsPublic(info) and type(info) == 'table' and ns.IsPublic(info.professionID) then
        return GATHERING_SKILLS[info.professionID]
    end
end
View.ActiveKind = activeKind

-- Drawing order. The native window shows skill bars (also frames of other add-ons that are anchored to it) that draw
-- above a panel placed only a few frame levels over the window; a higher frame level did not help, their strata or
-- level is higher. The panel is therefore raised above every frame of the window and every frame anchored to it, and what
-- was found is logged (professionLog) so the cause can be read from the saved variables.
local STRATA = { 'BACKGROUND', 'LOW', 'MEDIUM', 'HIGH', 'DIALOG', 'FULLSCREEN', 'FULLSCREEN_DIALOG', 'TOOLTIP' }
local STRATA_INDEX = {}
for index, name in ipairs(STRATA) do STRATA_INDEX[name] = index end
local STRATA_LIMIT = STRATA_INDEX.FULLSCREEN          -- the menus of the client stay above the panel
local LEVEL_LIMIT = 9990
local NODE_LIMIT = 4000

local function descendants(root, found, order)
    local queue, head = { root }, 1
    while queue[head] and #order < NODE_LIMIT do
        local node = queue[head]
        head = head + 1
        if node.GetChildren then
            for _, child in ipairs({ node:GetChildren() }) do
                if not found[child] then
                    found[child] = true
                    order[#order + 1] = child
                    queue[#queue + 1] = child
                end
            end
        end
    end
end

local function rank(frame)
    local okStrata, strata = pcall(frame.GetFrameStrata, frame)
    local okLevel, level = pcall(frame.GetFrameLevel, frame)
    return okStrata and STRATA_INDEX[strata] or STRATA_INDEX.MEDIUM, okLevel and type(level) == 'number' and level or 0
end

local function anchoredTo(frame, set)
    if not frame.GetNumPoints or not frame.GetPoint then return false end
    for point = 1, frame:GetNumPoints() do
        local _, relative = frame:GetPoint(point)
        if relative and set[relative] then return true end
    end
    return false
end

function View.Raise(panel, host)
    if not panel or not host or not panel.SetFrameLevel or not host.GetChildren then return end
    local own, ownOrder = { [panel] = true }, {}
    descendants(panel, own, ownOrder)
    local attached, order = { [host] = true }, {}
    descendants(host, attached, order)
    for _, frame in ipairs(order) do
        if own[frame] then attached[frame] = nil end
    end
    local screen = _G.UIParent
    if screen and screen.GetChildren then
        for _, frame in ipairs({ screen:GetChildren() }) do
            if not attached[frame] and not own[frame] and anchoredTo(frame, attached) then
                attached[frame] = true
                descendants(frame, attached, order)
                order[#order + 1] = frame
            end
        end
    end
    local list = { host }
    for _, frame in ipairs(order) do
        if attached[frame] and not own[frame] then list[#list + 1] = frame end
    end
    local target, top = 0, 0
    for _, frame in ipairs(list) do
        local strata, frameLevel = rank(frame)
        strata = math.min(strata, STRATA_LIMIT)
        if strata > target or (strata == target and frameLevel > top) then target, top = strata, frameLevel end
    end
    local currentStrata, currentLevel = rank(panel)
    local wanted = math.min(top + 20, LEVEL_LIMIT)
    if currentStrata < target or (currentStrata == target and currentLevel < wanted) then
        local delta = wanted - currentLevel
        if currentStrata < target and panel.SetFrameStrata then panel:SetFrameStrata(STRATA[target]) end
        panel:SetFrameLevel(wanted)
        for _, child in ipairs(ownOrder) do
            if child.GetFrameLevel and child.SetFrameLevel then child:SetFrameLevel(math.max(0, child:GetFrameLevel() + delta)) end
        end
    end
    local log = ns.db and ns.db.professionLog
    if type(log) == 'table' then
        local seen = (View.layerSeen or 0) + 1
        View.layerSeen = seen
        if seen <= 3 then                                                    -- the first openings are enough
            local highest = {}
            for _, frame in ipairs(list) do
                local strata, frameLevel = rank(frame)
                highest[#highest + 1] = { strata = strata, level = frameLevel, frame = frame }
            end
            table.sort(highest, function(a, b)
                if a.strata ~= b.strata then return a.strata > b.strata end
                return a.level > b.level
            end)
            local top5 = {}
            for index = 1, math.min(5, #highest) do
                local row = highest[index]
                local name = row.frame.GetName and row.frame:GetName() or nil
                local kind = row.frame.GetObjectType and row.frame:GetObjectType() or '?'
                top5[index] = string.format('%s %s strata=%s level=%d', tostring(name or '(unnamed)'), kind,
                    STRATA[row.strata] or '?', row.level)
            end
            log[#log + 1] = { at = time and time() or 0, stage = 'stats-layer', frames = #list, strata = STRATA[target],
                top = top, panelLevel = wanted, highest = top5 }
            while #log > 12 do table.remove(log, 1) end
        end
    end
end

local function text(parent, template)
    local label = parent:CreateFontString(nil, 'OVERLAY', template or 'GameFontNormalSmall')
    label:SetJustifyH('LEFT')
    label:SetWordWrap(false)
    return label
end

local function anchoredText(parent, y, value)
    local label = text(parent)
    label:SetPoint('TOPLEFT', parent, 'TOPLEFT', 12, y)
    label:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -12, y)
    label:SetText(value or '')
    return label
end

local function button(parent, label, width, callback)
    local control = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    control:SetSize(width, 22)
    control:SetText(label)
    control:SetScript('OnClick', callback)
    return control
end

-- Three views share one list and one header. Attempts: crafts and gathering in one list (recipe or profession, attempts,
-- completed, completed %). Materials: estimated use of reagents. Gathered: what was gathered and what it is worth, one
-- gathering profession at a time. Matched outputs, Items, Bonus and Multicraft were columns of the removed Crafting and
-- cooking window, but this client never gave a value for them, so they are only in the details of a recipe (click it).
local GAP = 3
local COLUMNS = 6
local LAYOUTS = {
    attempts = { widths = { false, 90, 100, 110 }, heads = { 'Recipe', 'Attempts', 'Completed', 'Completed %' } },
    materials = { widths = { false, 150, 80, 110 }, heads = { 'Material', 'Leading profession', 'Share', 'Est. used' } },
    gathered = { widths = { false, 80, 70, 100, 100, 100 },
        heads = { 'Item', 'Quantity', 'Share', 'Unit value', 'Total value', 'Best sale' } },
}

local function cells(frame)
    local cells = {}
    for index = 1, COLUMNS do cells[index] = text(frame, 'GameFontHighlightSmall') end
    return cells
end

-- Puts the cells of a row (or of the header) in the columns of a view: the right columns first, the name takes the rest.
local function place(list, frame, layout)
    local used = 0
    for index = COLUMNS, 2, -1 do
        local cell, width = list[index], layout.widths[index]
        if width and width > 0 then
            if cell.ClearAllPoints then cell:ClearAllPoints() end
            cell:SetPoint('RIGHT', frame, 'RIGHT', -used, 0)
            cell:SetWidth(width)
            cell:SetJustifyH('RIGHT')
            if cell.Show then cell:Show() end
            used = used + width + GAP
        else
            cell:SetText('')
            if cell.Hide then cell:Hide() end
        end
    end
    if list[1].ClearAllPoints then list[1]:ClearAllPoints() end
    list[1]:SetPoint('LEFT', frame, 'LEFT', 6, 0)
    list[1]:SetPoint('RIGHT', frame, 'RIGHT', -used, 0)
    return used
end

local function applyLayout(panel)
    local layout = LAYOUTS[panel.view]
    panel.nameRight = place(panel.head, panel.header, layout)
    for _, line in ipairs(panel.lines) do place(line.cells, line, layout) end
end

local function installed(kind)
    if ns.Catalog.Installed then return ns.Catalog.Installed(kind) end
    return ns.Catalog.modules[kind] ~= nil
end

local function gatheringLabel(kind)
    return ns.Actions and ns.Actions.labels and ns.Actions.labels[kind] or kind
end

-- The professions of the picker. Attempts: all professions, the crafts and the gathering ones together. Gathered: all
-- gathering professions, or one of those that are installed.
function View.KindOptions(panel)
    if panel.view == 'gathered' then
        local choices = { { value = false, label = 'All gathering' } }
        for _, kind in ipairs(ns.Yields and ns.Yields.Available() or {}) do
            choices[#choices + 1] = { value = kind, label = gatheringLabel(kind) }
        end
        return choices
    end
    local kinds = {}
    for kind in pairs(ns.Production.labels) do
        if ns.Catalog.modules[kind] then kinds[kind] = true end
    end
    for kind in pairs(ns.Actions and ns.Actions.labels or {}) do
        if installed(kind) then kinds[kind] = true end
    end
    local list = {}
    for kind in pairs(kinds) do
        local label = kind == 'Mining' and 'Mining' or ns.Production.labels[kind] or gatheringLabel(kind)
        list[#list + 1] = { value = kind, label = label }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    local choices = { { value = false, label = 'All professions' } }
    for _, choice in ipairs(list) do choices[#choices + 1] = choice end
    return choices
end

local function characterOptions()
    local choices = { { value = ns.characterID, label = 'This character' }, { value = false, label = 'All characters' } }
    local others = {}
    for id, character in pairs(ns.production.saved.characters or {}) do
        if id ~= ns.characterID then others[#others + 1] = { value = id, label = character.name or id } end
    end
    table.sort(others, function(a, b) return a.label < b.label end)
    for _, character in ipairs(others) do choices[#choices + 1] = character end
    return choices
end

-- The rows of the Attempts view: the recipes crafted, and one row for each gathering profession (and disenchanting).
function View.Rows(character, kind)
    local rows = {}
    for _, row in ipairs(ns.Reports.Rows('production', character, kind)) do
        rows[#rows + 1] = { name = row.name, attempts = row.attempts, completed = row.completed, id = row.recipeID, craft = row }
    end
    for _, row in ipairs(ns.Reports.Rows('actions', character, kind)) do
        rows[#rows + 1] = { name = gatheringLabel(row.kind), attempts = row.attempts, completed = row.completed,
            id = row.kind, action = row }
    end
    return rows
end

-- The profession shown in the Gathered view: false for all gathering professions, or the chosen one when it is installed.
-- At first it follows the profession filter of the other views when that is a gathering profession, else it is all.
local function gatheredKind(panel)
    local available = ns.Yields and ns.Yields.Available() or {}
    if panel.gatheredKind == false then return false end
    for _, kind in ipairs(available) do if panel.gatheredKind == kind then return kind end end
    for _, kind in ipairs(available) do if panel.kind == kind then panel.gatheredKind = kind; return kind end end
    panel.gatheredKind = false
    return false
end

-- The tabs of the Gathered view: the overview (the summary of every profession) and one tab for each gathering
-- profession, which is a table of its items under one header. A tab is a value of panel.gatheredKind (false = overview).
local function syncTabs(panel)
    panel.tabs = panel.tabs or {}
    local shown = panel.view == 'gathered'
    local choices = {}
    if shown then
        choices[1] = { value = false, label = 'Overview' }
        for _, kind in ipairs(ns.Yields and ns.Yields.Available() or {}) do
            choices[#choices + 1] = { value = kind, label = gatheringLabel(kind) }
        end
    end
    local current = shown and gatheredKind(panel)
    local x = 12
    for index = 1, math.max(#choices, #panel.tabs) do
        local choice, tab = choices[index], panel.tabs[index]
        if choice and not tab then
            tab = CreateFrame('Button', nil, panel)
            tab.label = text(tab, 'GameFontNormal')
            tab.label:SetJustifyH('CENTER')
            tab.label:SetPoint('CENTER', tab, 'CENTER', 0, 0)
            tab.line = tab:CreateTexture(nil, 'OVERLAY')
            tab.line:SetColorTexture(1, 0.82, 0, 1)
            tab.line:SetPoint('BOTTOMLEFT', tab, 'BOTTOMLEFT', 0, 0)
            tab.line:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', 0, 0)
            tab.line:SetHeight(2)
            tab:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
            tab:SetScript('OnClick', function(self) panel.SelectKind(self.value) end)
            panel.tabs[index] = tab
        end
        if tab then
            if choice then
                tab.value = choice.value
                tab.label:SetText(choice.value == current and Style.Value(choice.label) or Style.Label(choice.label))
                local width = tab.label.GetStringWidth and tab.label:GetStringWidth()
                if type(width) ~= 'number' then width = 70 end
                tab:SetSize(width + 24, 20)
                tab:ClearAllPoints()
                tab:SetPoint('TOPLEFT', panel, 'TOPLEFT', x, -68)
                x = x + width + 28
                if choice.value == current then tab.line:Show() else tab.line:Hide() end
                tab:Show()
            else
                tab:Hide()
            end
        end
    end
end

local function render(panel)
    local total = #(panel.data or {})
    local last = math.max(0, total - ROWS)
    panel.offset = math.min(last, math.max(0, math.floor(panel.offset + 0.5)))
    ns.Nav.SyncScrollbar(panel.slider, panel.offset, last)
    panel.range:SetText(total > 0 and Style.Range(panel.offset + 1, math.min(panel.offset + ROWS, total), total) or '')
    for index, line in ipairs(panel.lines) do
        local row = panel.data[panel.offset + index]
        line.data = row
        line:SetShown(row ~= nil)
        local cell = line.cells
        if row and panel.view == 'materials' then
            cell[1]:SetText(Style.ItemLabel(row.itemID))
            local leading = row.leading and ns.Production.labels[row.leading]
            cell[2]:SetText(leading and Style.Value(leading) or Style.Label('Unknown'))
            cell[3]:SetText(type(row.share) == 'number' and Style.Value(string.format('%.1f%%', row.share)) or Style.Label('Unknown'))
            cell[4]:SetText(Style.Value(row.quantity))
        elseif row and panel.view == 'gathered' then
            for column = 2, COLUMNS do cell[column]:SetText('') end
            if row.summary then
                -- A line of text across the columns: the summary of a profession.
                cell[1]:SetPoint('RIGHT', line, 'RIGHT', 0, 0)
                cell[1]:SetText(row.gold and Style.Text(Style.gold, row.text) or row.text)
            else
                cell[1]:SetPoint('RIGHT', line, 'RIGHT', -panel.nameRight, 0)
                cell[1]:SetText(Style.ItemLabel(row.itemID))
                cell[2]:SetText(Style.Value(row.quantity))
                cell[3]:SetText(Style.Value(string.format('%.1f%%', row.share)))
                cell[4]:SetText(row.unit and ns.Economy.Coin(row.unit) or Style.Label('No price'))
                cell[5]:SetText(row.value and ns.Economy.Coin(row.value) or Style.Label('Unknown'))
                cell[6]:SetText(Style.Value(row.source or ''))
            end
        elseif row then
            cell[1]:SetText(Style.Value(row.name)
                .. (row.action and row.action.kind ~= 'Enchanting' and Style.Label(' (gathering)') or ''))
            cell[2]:SetText(Style.Value(row.attempts))
            cell[3]:SetText(Style.Value(row.completed))
            cell[4]:SetText(row.attempts > 0 and Style.Value(string.format('%.1f%%', row.completed / row.attempts * 100))
                or Style.Label('Unknown'))
        end
    end
end

-- Sorting by a header. Names go a to z at the first click, numbers from the highest; the same column again reverses it.
-- Equal values keep a fixed order (the name, then the identity), so the list never jumps between two refreshes.
local function nameOf(row, view)
    if view == 'materials' then return ns.ItemName and ns.ItemName(row.itemID) or tostring(row.itemID) end
    return row.name or ''
end

local function sortValue(row, view, column)
    if view == 'materials' then
        if column == 1 then return string.lower(nameOf(row, view)) end
        if column == 2 then return string.lower(row.leading and ns.Production.labels[row.leading] or '') end
        if column == 3 then return row.share or -1 end
        return row.quantity
    end
    if column == 1 then return string.lower(nameOf(row, view)) end
    if column == 2 then return row.attempts end
    if column == 3 then return row.completed end
    return row.attempts > 0 and row.completed / row.attempts or -1
end

-- The rows whose name (or, for a material, its leading profession) contains the search text, ignoring case.
function View.Search(rows, view, needle)
    needle = type(needle) == 'string' and needle:lower() or ''
    if needle == '' then return rows end
    local kept = {}
    for _, row in ipairs(rows) do
        local haystack = nameOf(row, view)
        if view == 'materials' and row.leading then haystack = haystack .. ' ' .. (ns.Production.labels[row.leading] or '') end
        if string.lower(tostring(haystack)):find(needle, 1, true) then kept[#kept + 1] = row end
    end
    return kept
end

function View.SortRows(rows, view, state)
    local column, descending = state.column, state.descending
    local function tie(a, b)
        local nameA, nameB = nameOf(a, view), nameOf(b, view)
        if nameA ~= nameB then return nameA < nameB end
        local idA, idB = a.itemID or a.id or a.recipeID or 0, b.itemID or b.id or b.recipeID or 0
        return tostring(idA) < tostring(idB)
    end
    table.sort(rows, function(a, b)
        local first, second = sortValue(a, view, column), sortValue(b, view, column)
        if first ~= second then
            if descending then return first > second end
            return first < second
        end
        return tie(a, b)
    end)
end

-- The Gathered view lists the items of each profession under its own summary. Any column sorts the items inside every
-- profession (a row without a value is last); the first rows of a profession are still the most collected or the most
-- valuable ones, because that is what the rows were limited to.
local GATHERED_KINDS = { 'text', 'number', 'number', 'number', 'number', 'text' }
local MATERIAL_KINDS = { 'text', 'text', 'number', 'number' }
local function gatheredValue(row, column)
    if column == 1 then return string.lower(tostring(ns.ItemName and ns.ItemName(row.itemID) or row.itemID)) end
    if column == 2 then return row.quantity end
    if column == 3 then return row.share end
    if column == 4 then return row.unit end
    if column == 5 then return row.value end
    return row.source and string.lower(tostring(row.source)) or nil
end
local function gatheredTie(a, b)
    local nameA = string.lower(tostring(ns.ItemName and ns.ItemName(a.itemID) or a.itemID))
    local nameB = string.lower(tostring(ns.ItemName and ns.ItemName(b.itemID) or b.itemID))
    if nameA ~= nameB then return nameA < nameB end
    return tostring(a.itemID) < tostring(b.itemID)
end
function View.SortGathered(rows, state)
    if not (ns.ColumnSort and state) then return rows end
    local result, run = {}, {}
    local function flush()
        ns.ColumnSort.Sort(run, gatheredValue, state, gatheredTie)
        for _, row in ipairs(run) do result[#result + 1] = row end
        run = {}
    end
    for _, row in ipairs(rows) do
        if row.itemID then run[#run + 1] = row
        else flush(); result[#result + 1] = row end
    end
    flush()
    return result
end

-- The chosen order of a view is kept between sessions.
local function saveSort(view, state)
    if not ns.settings then return end
    ns.settings.columnSort = ns.settings.columnSort or {}
    ns.settings.columnSort['statistics_' .. view] = { column = state.column, descending = state.descending }
end
local function savedSort(view, default, kinds)
    local saved = ns.settings and ns.settings.columnSort and ns.settings.columnSort['statistics_' .. view]
    if type(saved) == 'table' and type(saved.column) == 'number' and kinds[saved.column]
        and type(saved.descending) == 'boolean' then
        return { column = saved.column, descending = saved.descending }
    end
    return default
end

local GATHERED_NOTE = 'Valued at the better of the vendor price and the auction price after the fee. Click an item for its sources.'
local ATTEMPTS_NOTE = 'Completed % = completed / observed attempts. Click a row for details.'

local function refreshPanel(panel)
    local character = panel.character or nil
    local view = panel.view
    if view == 'materials' then
        local rows, coverage = ns.production:ReagentUsage(character, panel.kind or nil)
        rows = View.Search(rows, 'materials', panel.searchText)
        View.SortRows(rows, 'materials', panel.sorts.materials)
        panel.data = rows
        panel.note:SetText(Style.Label('Estimated use from fixed required materials.'))
        local began = coverage.coverageBegan
        local note = began and Style.Label('Tracking began ')
            .. Style.Date(date and date('%Y-%m-%d', began) or tostring(began)) .. Style.Label('.') or ''
        if coverage.unsupportedCasts > 0 then
            note = note .. ' ' .. Style.Value(coverage.unsupportedCasts) .. Style.Label(' crafts without an estimate.')
        end
        panel.coverage:SetText(note)
    elseif view == 'gathered' then
        local kind = gatheredKind(panel)
        local rows = {}
        local available = ns.Yields and ns.Yields.Available() or {}
        local sort = panel.sorts.gathered.column == 5 and 'value' or 'quantity'
        local footer = {}
        for _, row in ipairs(#available > 0 and ns.Yields.Rows(character, kind or nil, sort) or {}) do
            -- The small gap under a summary is left out; the one between two professions stays.
            if kind then
                -- A tab of a profession is a table of its items; its summary lines are texts under the table.
                if not row.summary then rows[#rows + 1] = row
                elseif not (row.title or row.spacer) then footer[#footer + 1] = row.text end
            elseif not (row.spacer and row.small) and row.summary and not row.more then
                -- The overview has the summaries only: the items are in the tab of each profession.
                rows[#rows + 1] = row
            end
        end
        panel.data = View.SortGathered(rows, panel.sorts.gathered)
        panel.note:SetText(table.concat(footer, '\n'))
        panel.gatheredTable = kind and true or false
        panel.coverage:SetText(kind and '' or Style.Label(GATHERED_NOTE))
    else
        panel.data = View.Search(View.Rows(character, panel.kind or nil), 'attempts', panel.searchText)
        View.SortRows(panel.data, 'attempts', panel.sorts.attempts)
        local attempts, completed = 0, 0
        for _, row in ipairs(panel.data) do
            attempts, completed = attempts + row.attempts, completed + row.completed
        end
        panel.note:SetText(Style.Value(attempts) .. Style.Label(' attempts, ') .. Style.Value(completed)
            .. Style.Label(' completed.'))
        panel.coverage:SetText(Style.Label(ATTEMPTS_NOTE))
    end
    local heads = LAYOUTS[view].heads
    for index = 1, COLUMNS do
        local label = heads[index]
        panel.head[index]:SetText(label and label ~= '' and Style.Label(label) or '')
    end
    local message
    if #panel.data == 0 then
        if panel.searchText and panel.searchText ~= '' and view ~= 'gathered' then message = 'Nothing matches this search.'
        elseif view == 'materials' then message = 'No material use estimated for this view.'
        elseif view == 'gathered' then
            message = #(ns.Yields and ns.Yields.Available() or {}) == 0
                and 'No gathering profession (Mining, Herbalism, Skinning, Fishing) is installed or switched on.'
                or 'Nothing gathered is recorded for this view. Earlier loot history cannot be split by profession.'
        else message = 'No recipe operations or gathering actions recorded for this view. Earlier inventory cannot reconstruct them.' end
    end
    panel.empty:SetText(message and Style.Label(message) or '')
    local state = panel.sorts[view]
    local arrow = panel.sortArrow
    if panel.header.SetShown then panel.header:SetShown(view ~= 'gathered' or panel.gatheredTable == true) end
    if panel.kindPicker and panel.kindPicker.SetShown then panel.kindPicker:SetShown(view ~= 'gathered') end
    -- The Gathered view lists summaries and tables per profession; the search is for the two flat lists.
    if panel.search and panel.search.SetShown then panel.search:SetShown(view ~= 'gathered') end
    if panel.searchLabel and panel.searchLabel.SetShown then panel.searchLabel:SetShown(view ~= 'gathered') end
    syncTabs(panel)
    if arrow and arrow.SetTexCoord then
        local label = panel.head[state.column]
        if state.descending then arrow:SetTexCoord(0, 0.5625, 1, 0) else arrow:SetTexCoord(0, 0.5625, 0, 1) end
        if arrow.ClearAllPoints then arrow:ClearAllPoints() end
        local width = label.GetStringWidth and label:GetStringWidth() or 0
        if state.column == 1 then arrow:SetPoint('LEFT', label, 'LEFT', width + 4, 0)
        else arrow:SetPoint('RIGHT', label, 'RIGHT', -(width + 4), 0) end
        arrow:Show()
    end
    render(panel)
end

local function scrollTo(panel, offset)
    panel.offset = offset
    render(panel)
end

-- The native pages under the panel are made transparent while it is open (their skill bars drew over it) and are given
-- back their alpha when it closes; nothing of theirs is hidden or changed otherwise.
local PAGES = { 'CraftingPage', 'BookPage', 'SpecPage', 'OrdersPage' }

local function fadePages(panel, host)
    panel.alphas = panel.alphas or {}
    for _, key in ipairs(PAGES) do
        local page = host[key]
        if type(page) == 'table' and page.SetAlpha and panel.alphas[key] == nil then
            panel.alphas[key] = page.GetAlpha and page:GetAlpha() or 1
            page:SetAlpha(0)
        end
    end
end

local function restorePages(panel, host)
    for key, alpha in pairs(panel.alphas or {}) do
        local page = host[key]
        if type(page) == 'table' and page.SetAlpha then page:SetAlpha(alpha) end
    end
    panel.alphas = {}
end

-- The profession of the page that is open in the native window (nil when it cannot be read).
local function professionID()
    local frame = View.host
    local page = frame and frame.CraftingPage
    local info = page and page.professionInfo or frame and frame.professionInfo
    if not ns.IsPublic(info) or type(info) ~= 'table' then return nil end
    local id = info.professionID
    if ns.IsPublic(id) and type(id) == 'number' then return id end
end

-- Closes the panel: the native window shows again.
function View.Close()
    if View.panel and View.panel:IsShown() then View.panel:Hide() end
end

-- A click on any tab of a profession (the buttons beside the window) must leave Statistics. They are found by their
-- place, outside the right edge of the window, and each is hooked once.
local function hookTabs(host)
    if not host.GetRight or not host.GetChildren then return end
    local ok, right = pcall(host.GetRight, host)
    if not ok or type(right) ~= 'number' then return end
    View.hookedTabs = View.hookedTabs or {}
    local found, order = { [host] = true }, {}
    descendants(host, found, order)
    local added = 0
    for _, frame in ipairs(order) do
        local kind = frame.GetObjectType and frame:GetObjectType()
        if (kind == 'Button' or kind == 'CheckButton') and frame ~= View.tab and frame.HookScript
            and not View.hookedTabs[frame] and frame.GetLeft and frame.GetWidth and frame.GetHeight then
            local left, width, height = frame:GetLeft(), frame:GetWidth(), frame:GetHeight()
            if type(left) == 'number' and left >= right - 8 and type(width) == 'number' and width <= 100
                and type(height) == 'number' and height <= 100 then
                View.hookedTabs[frame] = true
                frame:HookScript('OnClick', function() View.Close() end)
                added = added + 1
            end
        end
    end
    local log = ns.db and ns.db.professionLog
    if added > 0 and type(log) == 'table' and (View.tabLogs or 0) < 3 then
        View.tabLogs = (View.tabLogs or 0) + 1
        log[#log + 1] = { at = time and time() or 0, stage = 'stats-tabs', hooked = added }
        while #log > 12 do table.remove(log, 1) end
    end
end

local function createPanel(frame)
    local panel = CreateFrame('Frame', nil, frame)
    panel:SetPoint('TOPLEFT', frame, 'TOPLEFT', 5, -24)
    panel:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -5, 5)
    panel:SetFrameLevel(math.min(frame:GetFrameLevel() + 500, 9000))
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    -- The round portrait of the native window reaches into the top-left corner of the panel: the background starts right of
    -- it in the top band, so the portrait is not covered.
    panel.backgrounds = {}
    local top = panel:CreateTexture(nil, 'BACKGROUND')
    top:SetPoint('TOPLEFT', panel, 'TOPLEFT', PORTRAIT_WIDTH, 0)
    top:SetPoint('BOTTOMRIGHT', panel, 'TOPRIGHT', 0, -PORTRAIT_BAND)
    local main = panel:CreateTexture(nil, 'BACKGROUND')
    main:SetPoint('TOPLEFT', panel, 'TOPLEFT', 0, -PORTRAIT_BAND)
    main:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', 0, 0)
    for _, texture in ipairs({ top, main }) do
        texture:SetColorTexture(0.08, 0.07, 0.06, 1)
        panel.backgrounds[#panel.backgrounds + 1] = texture
    end
    panel.character, panel.kind, panel.offset, panel.view = ns.characterID, false, 0, 'attempts'
    panel.sorts = {
        attempts = savedSort('attempts', { column = 1, descending = false }, { 'text', 'number', 'number', 'number' }),
        materials = savedSort('materials', { column = 4, descending = true }, MATERIAL_KINDS),
        gathered = savedSort('gathered', { column = 2, descending = true }, GATHERED_KINDS) }

    -- The view is chosen in a combo box on the row of the pickers (the portrait and the skill bar of the native window cover
    -- the top-left corner), like the other pickers.
    local function setView(view)
        panel.view, panel.offset = view, 0
        applyLayout(panel)
        if panel.viewPicker then panel.viewPicker.Sync() end
        if panel.kindPicker then panel.kindPicker.Sync() end
        refreshPanel(panel)
    end
    panel.SetView = setView
    panel.ViewOptions = function()
        return { { value = 'attempts', label = 'Attempts' }, { value = 'materials', label = 'Materials' },
            { value = 'gathered', label = 'Gathered items' } }
    end
    panel.viewPicker = ns.Nav.Dropdown(panel, 372, -40, 150, panel.ViewOptions, function() return panel.view end, setView)
    -- A search box beside the pickers (Escape clears it), for the Attempts and Materials lists.
    panel.searchLabel = text(panel, 'GameFontNormalSmall')
    panel.searchLabel:SetPoint('TOPLEFT', panel, 'TOPLEFT', 536, -46)
    panel.searchLabel:SetText('Search')
    local search = CreateFrame('EditBox', nil, panel, 'InputBoxTemplate')
    panel.search = search
    search:SetSize(170, 22); search:SetPoint('TOPLEFT', panel, 'TOPLEFT', 590, -41); search:SetAutoFocus(false)
    search:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
        if self:GetText() ~= '' then self:SetText(''); panel.searchText, panel.offset = nil, 0; refreshPanel(panel) end
    end)
    search:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
    search:SetScript('OnTextChanged', function(self, user)
        if not user then return end
        panel.searchText, panel.offset = self:GetText(), 0
        refreshPanel(panel)
    end)
    local back = button(panel, 'Back', 62, function() panel:Hide() end)
    back:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -12, -10)

    panel.kindPicker = ns.Nav.Dropdown(panel, 12, -40, 164, function() return View.KindOptions(panel) end,
        function() if panel.view == 'gathered' then return gatheredKind(panel) end return panel.kind end,
        function(value)
            if panel.view == 'gathered' then panel.gatheredKind = value else panel.kind = value end
            panel.offset = 0
            refreshPanel(panel)
        end)
    panel.SelectKind = function(value)
        if panel.view == 'gathered' then panel.gatheredKind = value else panel.kind = value end
        panel.offset = 0
        panel.kindPicker.Sync()
        refreshPanel(panel)
    end
    panel.characterPicker = ns.Nav.Dropdown(panel, 184, -40, 174, characterOptions, function() return panel.character end,
        function(value) panel.character, panel.offset = value, 0; refreshPanel(panel) end)
    local header = CreateFrame('Frame', nil, panel)
    header:SetPoint('TOPLEFT', panel, 'TOPLEFT', 12, -94)
    header:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -38, -94)
    header:SetHeight(18)
    panel.header = header
    panel.head = cells(header)
    -- A header cell is a button: the click sorts by that column. In the Gathered view the rows are limited to the most
    -- collected (or the most valuable, when Total value is chosen) and are sorted inside each profession.
    panel.headButtons = {}
    function panel.sortBy(index)
        local view = panel.view
        local state = panel.sorts[view]
        if view == 'materials' and index > 4 then return end
        if view == 'attempts' and index > 4 then return end
        if state.column == index then state.descending = not state.descending
        else
            local kind = view == 'gathered' and GATHERED_KINDS[index] or view == 'materials' and MATERIAL_KINDS[index]
                or (index == 1 and 'text' or 'number')
            state.column, state.descending = index, kind == 'number'
        end
        saveSort(view, state)
        refreshPanel(panel)
    end
    for index = 1, COLUMNS do
        local sortButton = CreateFrame('Button', nil, header)
        sortButton:SetAllPoints(panel.head[index])
        sortButton:SetScript('OnClick', function() panel.sortBy(index) end)
        panel.headButtons[index] = sortButton
    end
    if header.CreateTexture then
        local arrow = header:CreateTexture(nil, 'OVERLAY')
        if arrow.SetTexture then arrow:SetTexture('Interface\\Buttons\\UI-SortArrow') end
        if arrow.SetSize then arrow:SetSize(9, 8) end
        panel.sortArrow = arrow
    end
    panel.empty = anchoredText(panel, -122)
    panel.lines = {}
    for index = 1, ROWS do
        local line = CreateFrame('Button', nil, panel)
        line:SetHeight(HEIGHT)
        line:SetPoint('TOPLEFT', panel, 'TOPLEFT', 12, TOP - (index - 1) * HEIGHT)
        line:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -38, TOP - (index - 1) * HEIGHT)
        local band = line:CreateTexture(nil, 'BACKGROUND')
        band:SetAllPoints()
        local shade = index % 2 == 0 and 0.15 or 0.11
        band:SetColorTexture(shade, shade * 0.88, shade * 0.7, 1)
        line:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
        line.cells = cells(line)
        line:SetScript('OnClick', function(self)
            if not self.data then return end
            if panel.view == 'materials' then ns.Reports.ReagentDetails(self, self.data)
            elseif panel.view == 'gathered' then
                if not self.data.summary then ns.Reports.ItemSources(self, self.data.itemID, panel.character or nil) end
            elseif self.data.action then ns.Reports.ActionDetails(self, self.data.action)
            elseif self.data.craft then ns.Reports.ProductionDetails(self, self.data.craft) end
        end)
        panel.lines[index] = line
    end
    panel.range = anchoredText(panel, TOP - ROWS * HEIGHT - 8)
    -- Everything the list needs to say is under it: a gold line, then the notes of the view.
    panel.rule = panel:CreateTexture(nil, 'ARTWORK')
    panel.rule:SetColorTexture(1, 0.82, 0, 0.55)
    panel.rule:SetHeight(1)
    panel.rule:SetPoint('TOPLEFT', panel, 'TOPLEFT', 12, TOP - ROWS * HEIGHT - 27)
    panel.rule:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -38, TOP - ROWS * HEIGHT - 27)
    panel.note = anchoredText(panel, TOP - ROWS * HEIGHT - 35)
    panel.note:SetWordWrap(true)
    panel.coverage = anchoredText(panel, TOP - ROWS * HEIGHT - 35)
    panel.coverage:SetWordWrap(true)
    if panel.coverage.ClearAllPoints then
        panel.coverage:ClearAllPoints()
        panel.coverage:SetPoint('TOPLEFT', panel.note, 'BOTTOMLEFT', 0, -6)
        panel.coverage:SetPoint('TOPRIGHT', panel.note, 'BOTTOMRIGHT', 0, -6)
    end
    local function wheel(delta) scrollTo(panel, panel.offset - delta * 3) end
    panel.slider = ns.Nav.Scrollbar(panel, 0, TOP, ROWS * HEIGHT, function(offset) scrollTo(panel, offset) end, wheel)
    panel.slider:ClearAllPoints()
    panel.slider:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -16, TOP)
    applyLayout(panel)
    panel:SetScript('OnMouseWheel', function(_, delta) wheel(delta) end)
    panel:SetScript('OnShow', function()
        panel.professionID = professionID()
        pcall(View.Raise, panel, frame)
        pcall(fadePages, panel, frame)
        pcall(hookTabs, frame)
        View.tab:LockHighlight(); ns.ProfessionButton.Sync()
    end)
    panel:SetScript('OnHide', function()
        pcall(restorePages, panel, frame)
        View.tab:UnlockHighlight(); ns.ProfessionButton.Sync()
    end)
    panel:Hide()
    return panel
end

local function syncProfession()
    local panel = View.panel
    if not panel or not panel:IsVisible() then return end
    -- Another profession was chosen in the native window: Statistics are left, the profession is shown.
    local current = professionID()
    if panel.professionID == nil then panel.professionID = current                -- the window was still loading
    elseif current ~= nil and current ~= panel.professionID then panel:Hide(); return end
    panel.kind, panel.gatheredKind, panel.offset = activeKind() or false, nil, 0
    panel.kindPicker.Sync()
    refreshPanel(panel)
end

function View.Refresh()
    local panel = View.panel
    if panel and panel:IsVisible() then refreshPanel(panel) end
end

local function attach()
    local frame = ProfessionsFrame
    local page = frame and frame.CraftingPage
    if not page then return end
    if not View.tab then
        View.host = frame
        local tab = button(frame, 'Statistics', 104, function()
            if View.panel and View.panel:IsShown() then View.panel:Hide() else View.Open() end
        end)
        tab:SetPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', -14, 3)
        View.tab = tab
        frame:HookScript('OnHide', function() if View.panel then View.panel:Hide() end end)
        if frame.BookPage then frame.BookPage:HookScript('OnShow', function() View.Close() end) end
    end
end

function View.Open()
    if (not ProfessionsFrame or not ProfessionsFrame:IsShown()) and ShowProfessionsFrame then ShowProfessionsFrame() end
    attach()
    if not View.host or not View.host:IsShown() then return end
    if not View.panel then View.panel = createPanel(View.host) end
    View.panel:Show()
    View.panel.characterPicker.Sync()
    syncProfession()
end

-- Opens Statistics at a view ('attempts', 'materials' or 'gathered'): the Titan menu entry Reagent use estimates.
function View.OpenView(view)
    View.Open()
    if View.panel and View.panel:IsShown() and View.panel.SetView then View.panel.SetView(view) end
end

function View.Initialize()
    if View.listener then return end
    local listener = CreateFrame('Frame')
    View.listener = listener
    listener:SetScript('OnEvent', function(_, event, name)
        if event == 'ADDON_LOADED' and name ~= 'Blizzard_Professions' then return end
        if event == 'ITEM_DATA_LOAD_RESULT' then
            local panel = View.panel
            if panel and panel:IsVisible() and panel.view ~= 'attempts' then render(panel) end
            return
        end
        C_Timer.After(0, function() attach(); syncProfession() end)
    end)
    for _, event in ipairs({ 'ADDON_LOADED', 'TRADE_SKILL_SHOW', 'TRADE_SKILL_DATA_SOURCE_CHANGED', 'ITEM_DATA_LOAD_RESULT' }) do
        listener:RegisterEvent(event)
    end
    attach()
end
