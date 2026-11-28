local _, ns = ...
-- The My materials tab, the first of the main window: the materials of the installed professions with what this
-- character holds in the bags and the personal bank, and the learned professions with their skill. It carries what
-- the Titan Panel entry shows when pointed at, so the addon needs no panel.
local View = {}
ns.MaterialsView = View

local Style, List = ns.Style, ns.ListWindow

View.scope, View.group = 'held', false

local function counts(itemID)
    local count = ns.inventory and ns.inventory:Get(itemID) or {}
    return count.bags or 0, count.bank or 0, count.bankState
end

-- One row per catalogue material: the bags, the bank snapshot and the total, within the chosen group and scope.
function View.MaterialRows()
    local rows = {}
    if not ns.inventory then return rows end
    for _, itemID in ipairs(ns.Catalog.List(ns.settings)) do
        local record = ns.Items and ns.Items[itemID]
        local group = record and ns.Catalog.Group(record, ns.settings) or ''
        local bags, bank = counts(itemID)
        if (View.scope == 'all' or bags + bank > 0) and (not View.group or View.group == group) then
            rows[#rows + 1] = { itemID = itemID, group = group, bags = bags, bank = bank, total = bags + bank,
                name = string.lower(tostring(ns.ItemName(itemID) or '')) }
        end
    end
    return rows
end

local function count(value, field) return Style.Count(value, field) end

function View.MaterialCells(row)
    return { Style.ItemName(row.itemID), Style.Value(row.group), count(row.bags, 'bags'), count(row.bank, 'bank'),
        count(row.total, 'total') }
end

function View.MaterialSort(row, column)
    if column == 1 then return row.name end
    if column == 2 then return string.lower(row.group) end
    if column == 3 then return row.bags end
    if column == 4 then return row.bank end
    return row.total
end

function View.MaterialTie(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.name ~= b.name then return a.name < b.name end
    return a.itemID < b.itemID
end

function View.MaterialTooltip(tip, row)
    if tip.SetItemByID then tip:SetItemByID(row.itemID) else tip:AddLine(Style.ItemName(row.itemID)) end
end

function View.MaterialFooter(_, rows)
    local bags, bank = 0, 0
    for _, row in ipairs(rows) do bags, bank = bags + row.bags, bank + row.bank end
    local parts = { Style.Label('Items: ') .. Style.Value(bags + bank) .. Style.Label(' (bags ') .. Style.Value(bags)
        .. Style.Label(', bank ') .. Style.Value(bank) .. Style.Label(')') }
    local _, _, state = counts(0)
    local observation = ns.inventory and ns.Tooltips.BankObservation(ns.inventory:Get(0))
    if state == 'unknown' then parts[#parts + 1] = Style.Label('The bank was not opened yet: its counts are 0 until you visit it.')
    elseif observation then parts[#parts + 1] = Style.Label(observation) end
    if ns.settings and ns.settings.showBank == false then parts[#parts + 1] = Style.Label('Bank counts are switched off (Material list in Options).') end
    return table.concat(parts, Style.Label('  '))
end

-- Learned professions -------------------------------------------------------------------------------------------------

function View.ProfessionRows()
    local rows = {}
    for _, skill in ipairs(ns.Professions.Rows()) do
        rows[#rows + 1] = { name = skill.name, rank = skill.rank, maxRank = skill.maxRank, secondary = skill.secondary,
            share = skill.maxRank > 0 and skill.rank / skill.maxRank or 0 }
    end
    return rows
end

function View.ProfessionCells(row)
    return { Style.Text(Style.SkillColor(row.rank, row.maxRank), row.name), Style.Skill(row.rank, row.maxRank),
        Style.Value(string.format('%d%%', math.floor(row.share * 100 + 0.5))),
        Style.Value(row.secondary and 'Secondary' or 'Primary') }
end

function View.ProfessionSort(row, column)
    if column == 1 then return string.lower(row.name) end
    if column == 2 then return row.rank end
    if column == 3 then return row.share end
    return row.secondary and 1 or 0
end

function View.ProfessionTie(a, b)
    if a.secondary ~= b.secondary then return not a.secondary end
    return a.name < b.name
end

-- Filters -------------------------------------------------------------------------------------------------------------

local scopeFilter = { width = 190, modes = { materials = true },
    options = function()
        return { { value = 'held', label = 'In bags or bank' }, { value = 'all', label = 'All catalogue materials' } }
    end,
    get = function() return View.scope end, set = function(value) View.scope = value end }

local groupFilter = { width = 190, modes = { materials = true },
    options = function()
        local options, seen = { { value = false, label = 'All groups' } }, {}
        for _, itemID in ipairs(ns.Catalog.List(ns.settings)) do
            local record = ns.Items and ns.Items[itemID]
            local group = record and ns.Catalog.Group(record, ns.settings)
            if type(group) == 'string' and not seen[group] then seen[group] = true; options[#options + 1] = { value = group, label = group } end
        end
        table.sort(options, function(a, b)
            if not a.value then return true end
            if not b.value then return false end
            return a.label < b.label
        end)
        return options
    end,
    get = function() return View.group end, set = function(value) View.group = value end }

View.view = List.Create({
    id = 'materials', frameName = 'TitanGatheredForeverMaterialsWindow', title = 'Titan Gathered Forever My materials',
    modeWidth = 170, filters = { scopeFilter, groupFilter },
    modes = {
        { value = 'materials', label = 'Materials',
            note = 'The materials of your installed professions that this character holds. The bank counts are the last '
                .. 'snapshot, taken whenever the bank is open. Hover a row for the item tooltip. Escape in the search box clears it.',
            columns = { { 'Material', 0, 330, 'text' }, { 'Group', 335, 230, 'text' }, { 'Bags', 570, 100, 'number' },
                { 'Bank', 675, 100, 'number' }, { 'Total', 780, 100, 'number' } },
            sortKey = 'myMaterials', default = { column = 5, descending = true },
            rows = View.MaterialRows, cells = View.MaterialCells, sortValue = View.MaterialSort, tie = View.MaterialTie,
            search = function(row) return row.name .. ' ' .. string.lower(row.group) end,
            tooltip = View.MaterialTooltip, footer = View.MaterialFooter, what = 'materials',
            nothing = 'None of these materials is in your bags or bank. Choose All catalogue materials to list them anyway.',
            empty = 'No profession material is in your bags or bank. Install or switch on a profession module to list its materials.' },
        { value = 'professions', label = 'Learned professions',
            note = 'The professions this character has learned, with the skill and the highest skill of the current rank.',
            columns = { { 'Profession', 0, 300, 'text' }, { 'Skill', 305, 150, 'number' }, { 'Of the rank', 460, 120, 'number' },
                { 'Kind', 585, 150, 'text' } },
            sortKey = 'myProfessions', default = { column = 4 },
            rows = View.ProfessionRows, cells = View.ProfessionCells, sortValue = View.ProfessionSort, tie = View.ProfessionTie,
            search = function(row) return string.lower(row.name) end, what = 'professions',
            empty = 'No profession learned yet.' },
    },
})

function View.Show() View.view.Show() end
function View.Toggle() View.view.Toggle() end
function View.Refresh() View.view.Refresh() end
