local _, ns = ...
-- Sorting by a column header for every window with columns. The rules are those of the Statistics panel: a text column
-- starts from A to Z, a numeric column from the highest, a second click on the same column reverses it, an arrow marks the
-- column, a row without a value is always last, and equal values keep a fixed order (the tie function of the window), so
-- a list never jumps between two refreshes. The order a player chose is saved per window and restored.
local ColumnSort = {}
ns.ColumnSort = ColumnSort

-- The state after a click on a column. kind is 'text' or 'number'.
function ColumnSort.Next(state, column, kind)
    if state and state.column == column then return { column = column, descending = not state.descending } end
    return { column = column, descending = kind == 'number' }
end

-- Sorts rows in place. valueOf(row, column) is a number, a lower-case string or nil (no value, always last).
-- tie(a, b) decides between equal values and should give a total order (name, then identity).
function ColumnSort.Sort(rows, valueOf, state, tie)
    local column, descending = state.column, state.descending
    table.sort(rows, function(a, b)
        local first, second = valueOf(a, column), valueOf(b, column)
        if first == nil or second == nil then
            if first == nil and second == nil then return tie(a, b) end
            return first ~= nil
        end
        if first ~= second then
            if descending then return first > second end
            return first < second
        end
        return tie(a, b)
    end)
end

local function validState(saved, kinds)
    return type(saved) == 'table' and type(saved.column) == 'number' and kinds[saved.column]
        and type(saved.descending) == 'boolean'
end

-- options: parent (the header frame), cells (the header texts, one per column), kinds ('text', 'number' or false for a
-- column that does not sort), key (the name under which the order is saved), default (the order before the first click,
-- or nil for the order the window has today), onChange (called after a click, redraws the window).
-- Returns { state, buttons, arrow, Apply(rows, valueOf, tie), Sync() }.
function ColumnSort.Attach(options)
    local kinds, cells = options.kinds, options.cells
    local sorter = { buttons = {} }
    local saved = ns.settings and ns.settings.columnSort and ns.settings.columnSort[options.key]
    if validState(saved, kinds) then sorter.state = { column = saved.column, descending = saved.descending }
    elseif options.default and kinds[options.default.column] then
        sorter.state = { column = options.default.column, descending = options.default.descending and true or false }
    end

    local arrow = options.parent:CreateTexture(nil, 'OVERLAY')
    if arrow.SetTexture then arrow:SetTexture('Interface\\Buttons\\UI-SortArrow') end
    if arrow.SetSize then arrow:SetSize(9, 8) end
    sorter.arrow = arrow

    function sorter.Sync()
        local state = sorter.state
        if not state then if arrow.Hide then arrow:Hide() end return end
        local label = cells[state.column]
        if arrow.SetTexCoord then
            if state.descending then arrow:SetTexCoord(0, 0.5625, 1, 0) else arrow:SetTexCoord(0, 0.5625, 0, 1) end
        end
        if arrow.ClearAllPoints then arrow:ClearAllPoints() end
        local width = label.GetStringWidth and label:GetStringWidth()
        if type(width) ~= 'number' then width = 0 end
        if kinds[state.column] == 'number' then arrow:SetPoint('RIGHT', label, 'RIGHT', -(width + 4), 0)
        else arrow:SetPoint('LEFT', label, 'LEFT', width + 4, 0) end
        if arrow.Show then arrow:Show() end
    end

    for index = 1, #cells do
        local button = CreateFrame('Button', nil, options.parent)
        button:SetAllPoints(cells[index])
        if kinds[index] then
            button:SetScript('OnClick', function()
                sorter.state = ColumnSort.Next(sorter.state, index, kinds[index])
                if ns.settings then
                    ns.settings.columnSort = ns.settings.columnSort or {}
                    ns.settings.columnSort[options.key] = { column = sorter.state.column, descending = sorter.state.descending }
                end
                sorter.Sync()
                if options.onChange then options.onChange() end
            end)
        end
        sorter.buttons[index] = button
    end

    -- Sorts rows by the current order. false (and the rows untouched) when the player has not chosen one.
    function sorter.Apply(rows, valueOf, tie)
        if not sorter.state then return false end
        ColumnSort.Sort(rows, valueOf, sorter.state, tie)
        return true
    end

    sorter.Sync()
    return sorter
end
