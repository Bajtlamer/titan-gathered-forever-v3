local _, ns = ...
-- The Quests view of the Journal tab: quests the selected character (or all characters of the realm) accepted, turned in or abandoned.
-- Quest names are not saved: the game provides them by quest ID, so they are asked for when the list is drawn.
local View = {}
ns.QuestsView = View

local Style, List = ns.Style, ns.ListWindow

local statuses = {
    completed = { 'Completed', Style.white }, open = { 'In progress', Style.cyan },
    abandoned = { 'Abandoned or failed', Style.orange }, unknown = { 'Unknown', Style.gray },
}
local statusChoices = { { value = 'all', label = 'All quests' }, { value = 'completed', label = 'Completed' },
    { value = 'open', label = 'In progress' }, { value = 'abandoned', label = 'Abandoned or failed' } }

local requested = {}
function View.Title(questID)
    local api = C_QuestLog
    if not api then return end
    local ok, title = pcall(api.GetTitleForQuestID, questID)
    if ok and ns.IsPublic(title) and type(title) == 'string' and title ~= '' then return title end
    if not requested[questID] and api.RequestLoadQuestByID then
        requested[questID] = true
        pcall(api.RequestLoadQuestByID, questID)
    end
end

function View.Name(row) return View.Title(row.questID) or ('Quest ' .. row.questID) end

function View.AverageTime(row)
    if row.timed > 0 then return row.timeTotal / row.timed end
end

function View.Cells(row)
    local status = statuses[row.status] or statuses.unknown
    local title, average = View.Title(row.questID), View.AverageTime(row)
    local zone = List.Zone(row.mapID)
    return {
        title and Style.Value(title) or Style.Text(Style.gray, 'Quest ' .. row.questID),
        Style.Text(status[2], status[1]),
        row.turnIns > 0 and Style.Value(row.turnIns) or Style.Text(Style.gray, '0'),
        row.xpTurnIns > 0 and Style.Value(row.xp) or List.Unknown(),
        row.copper > 0 and Style.Value(ns.Economy.Coin(row.copper))
            or (row.turnIns > 0 and Style.Text(Style.gray, 'None') or List.Unknown()),
        average and Style.Value(List.Duration(average)) or List.Unknown(),
        zone and Style.Value(zone) or List.Unknown(),
        List.Date(row.last),
    }
end

local order = { completed = 1, open = 2, abandoned = 3, unknown = 4 }
function View.SortValue(row, column)
    if column == 1 then return string.lower(View.Name(row)) end
    if column == 2 then return order[row.status] end
    if column == 3 then return row.turnIns end
    if column == 4 then return row.xpTurnIns > 0 and row.xp or nil end
    if column == 5 then return row.turnIns > 0 and row.copper or nil end
    if column == 6 then return View.AverageTime(row) end
    if column == 7 then local zone = List.Zone(row.mapID); return zone and string.lower(zone) or nil end
    return row.last
end
function View.Tie(a, b)
    local nameA, nameB = string.lower(View.Name(a)), string.lower(View.Name(b))
    if nameA ~= nameB then return nameA < nameB end
    return a.questID < b.questID
end

local function realm() return GetRealmName and GetRealmName() end

function View.Rows()
    local rows = ns.QuestIncome.Rows(ns.db and ns.db.questIncome, realm(), View.character or nil)
    if View.status ~= 'all' then
        local kept = {}
        for _, row in ipairs(rows) do
            if row.status == View.status or (View.status == 'abandoned' and row.abandons > 0) then kept[#kept + 1] = row end
        end
        rows = kept
    end
    return rows
end

local function line(tip, label, value)
    tip:AddDoubleLine(Style.Label(label), value)
    Style.Small(tip)
end

function View.Tooltip(tip, row)
    local status = statuses[row.status] or statuses.unknown
    tip:AddLine(Style.Value(View.Name(row)))
    line(tip, 'Quest ID', Style.Value(row.questID))
    line(tip, 'Status', Style.Text(status[2], status[1]))
    line(tip, 'Turned in', Style.Value(row.turnIns) .. Style.Label(row.turnIns == 1 and ' time' or ' times'))
    if row.xpTurnIns > 0 then
        line(tip, 'Experience', Style.Value(row.xp) .. (row.xpTurnIns < row.turnIns
            and Style.Label(' from ') .. Style.Value(row.xpTurnIns) .. Style.Label(' of the turn-ins') or ''))
    end
    if row.turnIns > 0 then line(tip, 'Money', row.copper > 0 and Style.Value(ns.Economy.Coin(row.copper)) or Style.Value('None')) end
    if View.AverageTime(row) then
        line(tip, 'Average time taken', Style.Value(List.Duration(View.AverageTime(row))))
    end
    if row.firstAt then line(tip, 'First turn-in', List.DateTime(row.firstAt)) end
    if row.lastAt then line(tip, 'Last turn-in', List.DateTime(row.lastAt)) end
    if List.Zone(row.mapID) then line(tip, 'Turned in at', Style.Value(List.Zone(row.mapID))) end
    if row.acceptedAt then
        line(tip, 'Accepted', List.DateTime(row.acceptedAt))
        if List.Zone(row.acceptMapID) then line(tip, 'Accepted in', Style.Value(List.Zone(row.acceptMapID))) end
    end
    if row.accepts > 0 then line(tip, 'Times accepted', Style.Value(row.accepts)) end
    if row.giver then
        local name = ns.QuestIncome.GiverName(row.giver)
        line(tip, 'Given by', Style.Value(name or ('Creature ' .. row.giver)))
    end
    if row.turnInName then line(tip, 'Turned in to', Style.Value(row.turnInName)) end
    if row.rewards and next(row.rewards) then
        Style.Section(tip, 'Items received')
        local items = {}
        for itemID, n in pairs(row.rewards) do items[#items + 1] = { itemID = itemID, n = n } end
        table.sort(items, function(a, b) return a.itemID < b.itemID end)
        for _, item in ipairs(items) do
            local name = ns.ItemName and ns.ItemName(item.itemID) or ('Item ' .. item.itemID)
            line(tip, (name or ('Item ' .. item.itemID)) .. (item.itemID == row.chosen and ' (chosen)' or ''), Style.Value(item.n))
        end
    end
    if row.giver then Style.Note(tip, Style.Label('Click to show the quest giver on the map.')) end
    if row.abandons > 0 then
        line(tip, 'Abandoned or failed', Style.Value(row.abandons) .. Style.Label(row.abandons == 1 and ' time' or ' times'))
        line(tip, 'Last abandoned', List.DateTime(row.abandonedAt))
    end
end

function View.Click(row)
    if not row.giver then return end
    local _, giver = ns.QuestIncome.GiverName(row.giver)
    if giver and giver.mapID then List.ShowOnMap(row.giver, giver.mapID) end
end

function View.Footer(_, rows)
    local turnIns, xp, copper = 0, 0, 0
    for _, row in ipairs(rows) do turnIns, xp, copper = turnIns + row.turnIns, xp + row.xp, copper + row.copper end
    return Style.Label('Listed: ') .. Style.Value(turnIns) .. Style.Label(' turn-ins, ') .. Style.Value(xp)
        .. Style.Label(' experience, ') .. Style.Value(ns.Economy.Coin(copper)) .. Style.Label('. ')
        .. Style.Label('Time taken runs from accepting to turning in, time logged out included. Turn-ins before 0.5.165 have no experience, zone or time.')
end

-- A quest name arrived from the server: redraw once for a burst of them.
function View.DataLoaded()
    local view = ns.JournalView and ns.JournalView.view
    if View.pending or not (view and view.window and view.window:IsShown() and view.mode == 'quests') then return end
    View.pending = true
    local function redraw() View.pending = nil; view.Refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, redraw) else redraw() end
end

View.status = 'all'
View.character = false

-- The window is the Journal tab's (JournalView); this is the quest view and its status filter.
View.statusFilter = { width = 170, options = function() return statusChoices end, modes = { quests = true },
    get = function() return View.status end, set = function(value) View.status = value end }

View.modes = {
    { value = 'quests', label = 'Quests',
        note = 'Quests you accepted, turned in or abandoned, with what they gave and how long they took. Accepting and '
            .. 'abandoning are recorded since version 0.5.165; turn-ins and their money since quest income was added. Hover '
            .. 'a row for the giver and the items received; click it to show the giver on the map. Escape in the search '
            .. 'box clears it.',
        columns = { { 'Quest', 0, 250, 'text' }, { 'Status', 255, 95, 'text' }, { 'Turn-ins', 355, 60, 'number' },
            { 'Experience', 420, 80, 'number' }, { 'Money', 505, 105, 'number' }, { 'Time taken', 615, 80, 'number' },
            { 'Turned in at', 700, 115, 'text' }, { 'Last activity', 820, 90, 'number' } },
        sortKey = 'quests', default = { column = 8, descending = true },
        rows = View.Rows, cells = View.Cells, sortValue = View.SortValue, tie = View.Tie,
        search = function(row)
            return string.lower(View.Name(row) .. ' ' .. row.questID .. ' ' .. (List.Zone(row.mapID) or '')
                .. ' ' .. (List.Zone(row.acceptMapID) or '') .. ' ' .. (row.giver and ns.QuestIncome.GiverName(row.giver) or '')
                .. ' ' .. (row.turnInName or ''))
        end,
        tooltip = View.Tooltip, footer = View.Footer, what = 'quests', click = View.Click,
        empty = 'No quests recorded yet.',
        nothing = 'No quest has this status.' },
}
View.store = { quests = 'questIncome' }

local function journal() return ns.JournalView and ns.JournalView.view end
function View.Show() if journal() then journal().Show({ 'quests' }) end end
function View.Refresh() if journal() then journal().Refresh() end end
