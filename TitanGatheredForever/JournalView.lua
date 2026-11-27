local _, ns = ...
-- The Journal tab: one window whose views are chosen in a combo box. Levels (time and experience per level), Quests
-- (QuestsView), Creatures, Creature drops and Rare creatures (KillsView), Deaths (where and when) and Reputation (what
-- was gained per faction, today and in the last seven days).
local View = {}
ns.JournalView = View

local Style, List = ns.Style, ns.ListWindow

local function realm() return GetRealmName and GetRealmName() end
local function line(tip, label, value)
    tip:AddDoubleLine(Style.Label(label), value)
    Style.Small(tip)
end
local function number(value) return value > 0 and Style.Value(value) or Style.Text(Style.gray, '0') end
local function characterLabel(id)
    if id == ns.characterID then return 'This character' end
    return List.CharacterName(id) or tostring(id)
end
local function characterTie(a, b)
    local nameA, nameB = characterLabel(a.character), characterLabel(b.character)
    if nameA ~= nameB then return nameA < nameB end
    return tostring(a.character) < tostring(b.character)
end

-- Levels --------------------------------------------------------------------------------------------------------------

function View.LevelRows() return ns.Journal.LevelRows(realm(), View.character or nil) end

local function played(row)
    local text = Style.Value(List.Duration(row.played))
    if row.partial then text = Style.Label('at least ') .. text end
    return text
end

function View.LevelCells(row)
    return {
        Style.Value(row.level) .. (row.current and Style.Label(' now') or ''),
        row.reachedAt and List.Date(row.reachedAt) or List.Unknown(),
        played(row),
        number(row.kill), number(row.quest), number(row.other),
        number(row.kills), number(row.quests), number(row.deaths),
        View.character and '' or Style.Value(characterLabel(row.character)),
    }
end

function View.LevelSort(row, column)
    if column == 1 then return row.level end
    if column == 2 then return row.reachedAt end
    if column == 3 then return row.played end
    local keys = { [4] = 'kill', [5] = 'quest', [6] = 'other', [7] = 'kills', [8] = 'quests', [9] = 'deaths' }
    if keys[column] then return row[keys[column]] end
    return string.lower(characterLabel(row.character))
end
function View.LevelTie(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return characterTie(a, b)
end

function View.LevelTooltip(tip, row)
    tip:AddLine(Style.Value('Level ' .. row.level) .. Style.Label('  ' .. characterLabel(row.character)))
    line(tip, 'Reached', row.reachedAt and List.DateTime(row.reachedAt) or List.Unknown())
    line(tip, 'Time logged in at this level', played(row))
    local total = row.kill + row.quest + row.other
    line(tip, 'Experience from kills', Style.Value(row.kill))
    line(tip, 'Experience from quests', Style.Value(row.quest))
    line(tip, 'Other experience', Style.Value(row.other))
    if total > 0 and row.played > 0 then
        line(tip, 'Experience per hour', Style.Value(math.floor(total / row.played * 3600 + 0.5)))
    end
    if row.partial then
        Style.Note(tip, Style.Label('Recording began during this level, so its time and experience are a lower bound.'))
    end
    Style.Note(tip, Style.Label('Other experience: exploration, gathering and anything not from a kill or a quest.'))
end

-- Deaths --------------------------------------------------------------------------------------------------------------

local places = { world = 'Open world', party = 'Dungeon', raid = 'Raid', pvp = 'Battleground', arena = 'Arena' }

function View.DeathRows() return ns.Journal.DeathRows(realm(), View.character or nil) end

function View.DeathCells(row)
    local zone = List.Zone(row.mapID)
    local coordinates = List.Coordinates(row.x, row.y)
    return {
        List.DateTime(row.at),
        zone and Style.Value(zone) or List.Unknown(),
        coordinates and Style.Value(coordinates) or List.Unknown(),
        row.level and Style.Value(row.level) or List.Unknown(),
        row.place and Style.Value(places[row.place] or row.place) or List.Unknown(),
        row.killer and Style.Value(row.killer) or List.Unknown(),
        Style.Value(characterLabel(row.character)),
    }
end

function View.DeathSort(row, column)
    if column == 1 then return row.at end
    if column == 2 then local zone = List.Zone(row.mapID); return zone and string.lower(zone) or nil end
    if column == 3 then return row.x and (row.x * 1000 + row.y) or nil end
    if column == 4 then return row.level end
    if column == 5 then return row.place and string.lower(places[row.place] or row.place) or nil end
    if column == 6 then return row.killer and string.lower(row.killer) or nil end
    return string.lower(characterLabel(row.character))
end
function View.DeathTie(a, b)
    if a.at ~= b.at then return a.at > b.at end
    return characterTie(a, b)
end

function View.DeathTooltip(tip, row)
    tip:AddLine(Style.Value(row.killer or 'Unknown killer'))
    if row.spell then line(tip, 'Lethal blow', Style.Value(row.spell)) end
    line(tip, 'When', List.DateTime(row.at))
    line(tip, 'Where', Style.Value((List.Zone(row.mapID) or 'Unknown') .. ' ' .. (List.Coordinates(row.x, row.y) or '')))
    if row.level then line(tip, 'Level', Style.Value(row.level)) end
    line(tip, 'Character', Style.Value(characterLabel(row.character)))
end

function View.DeathFooter(_, rows)
    local zones, top, most = {}, nil, 0
    for _, row in ipairs(rows) do
        local zone = List.Zone(row.mapID)
        if zone then
            zones[zone] = (zones[zone] or 0) + 1
            if zones[zone] > most or (zones[zone] == most and zone < top) then top, most = zone, zones[zone] end
        end
    end
    local text = Style.Label('Listed: ') .. Style.Value(#rows) .. Style.Label(#rows == 1 and ' death.' or ' deaths.')
    if top then text = text .. Style.Label(' Most deaths: ') .. Style.Value(top) .. Style.Label(' (') .. Style.Value(most) .. Style.Label(').') end
    return text .. Style.Label(' The killer is the lethal blow of the death recap when the game gives it.')
end

-- Reputation ----------------------------------------------------------------------------------------------------------

function View.ReputationRows() return ns.Journal.ReputationRows(realm(), View.character or nil) end

local function standing(reaction)
    local label = reaction and _G['FACTION_STANDING_LABEL' .. reaction]
    if type(label) == 'string' then return label end
end

local function signed(value)
    if value > 0 then return Style.Text(Style.cyan, '+' .. value) end
    if value < 0 then return Style.Text(Style.orange, tostring(value)) end
    return Style.Text(Style.gray, '0')
end

function View.ReputationCells(row)
    return {
        Style.Value(row.name or ('Faction ' .. row.factionID)),
        standing(row.reaction) and Style.Value(standing(row.reaction)) or List.Unknown(),
        number(row.gained),
        row.lost > 0 and Style.Text(Style.orange, row.lost) or Style.Text(Style.gray, '0'),
        signed(row.today), signed(row.week),
        number(row.gains),
        List.Date(row.lastAt),
    }
end

function View.ReputationSort(row, column)
    if column == 1 then return string.lower(row.name or '') end
    if column == 2 then return row.reaction end
    local keys = { [3] = 'gained', [4] = 'lost', [5] = 'today', [6] = 'week', [7] = 'gains' }
    if keys[column] then return row[keys[column]] end
    return row.lastAt
end
function View.ReputationTie(a, b)
    local nameA, nameB = string.lower(a.name or ''), string.lower(b.name or '')
    if nameA ~= nameB then return nameA < nameB end
    return a.factionID < b.factionID
end

function View.ReputationTooltip(tip, row)
    tip:AddLine(Style.Value(row.name or ('Faction ' .. row.factionID)))
    line(tip, 'Gained in total', Style.Value(row.gained) .. Style.Label(' in ') .. Style.Value(row.gains)
        .. Style.Label(row.gains == 1 and ' gain' or ' gains'))
    if row.gains > 0 then line(tip, 'Average gain', Style.Value(math.floor(row.gained / row.gains + 0.5))) end
    line(tip, 'Lost', Style.Value(row.lost))
    line(tip, 'Today', signed(row.today))
    line(tip, 'Last 7 days', signed(row.week))
    line(tip, 'Last change', List.DateTime(row.lastAt))
end

View.character = false

-- One character choice for every view of the tab; each view lists the characters of its own records.
local stores = { levels = 'levels', deaths = 'deaths', reputation = 'reputation' }
local function storeOf(mode)
    return stores[mode] or (ns.KillsView and ns.KillsView.store[mode]) or (ns.QuestsView and ns.QuestsView.store[mode])
        or 'levels'
end
local characterFilter = { width = 160, get = function() return View.character end,
    set = function(value)
        View.character = value
        if ns.KillsView then ns.KillsView.character = value end
        if ns.QuestsView then ns.QuestsView.character = value end
    end,
    options = function()
        return List.Characters(ns.db and ns.db[storeOf(View.view and View.view.mode or 'levels')], realm())
    end }

local journalModes = {
    { value = 'levels', label = 'Levels',
        note = 'Each level since version 0.5.166: when it was reached, the time logged in at it, and where the experience came '
            .. 'from. The level that was under way when recording began shows its time as a lower bound. Escape in the '
            .. 'search box clears it.',
        columns = { { 'Level', 0, 60, 'number' }, { 'Reached', 65, 90, 'number' }, { 'Time played', 160, 120, 'number' },
            { 'XP from kills', 285, 85, 'number' }, { 'XP from quests', 375, 90, 'number' }, { 'Other XP', 470, 70, 'number' },
            { 'Kills', 545, 50, 'number' }, { 'Quests', 600, 55, 'number' }, { 'Deaths', 660, 55, 'number' },
            { 'Character', 720, 190, 'text' } },
        sortKey = 'journalLevels', default = { column = 1, descending = true },
        rows = View.LevelRows, cells = View.LevelCells, sortValue = View.LevelSort, tie = View.LevelTie,
        search = function(row) return string.lower(row.level .. ' ' .. characterLabel(row.character)) end,
        tooltip = View.LevelTooltip, what = 'levels',
        empty = 'No level recorded yet. It starts with this version.' },
    { value = 'deaths', label = 'Deaths',
        note = 'Every death since version 0.5.166: when, where, at which level and what dealt the lethal blow. Inside '
            .. 'instances only the zone is kept. Hover a row for the spell. '
            .. 'Escape in the search box clears it.',
        columns = { { 'When', 0, 120, 'number' }, { 'Zone', 125, 170, 'text' }, { 'Coordinates', 300, 85, 'number' },
            { 'Level', 390, 45, 'number' }, { 'Place', 440, 95, 'text' }, { 'Killed by', 540, 210, 'text' },
            { 'Character', 755, 155, 'text' } },
        sortKey = 'journalDeaths', default = { column = 1, descending = true },
        rows = View.DeathRows, cells = View.DeathCells, sortValue = View.DeathSort, tie = View.DeathTie,
        search = function(row)
            return string.lower((List.Zone(row.mapID) or '') .. ' ' .. (places[row.place] or '') .. ' '
                .. characterLabel(row.character) .. ' ' .. (row.level or '') .. ' ' .. (row.killer or ''))
        end,
        footer = View.DeathFooter, what = 'deaths', tooltip = View.DeathTooltip,
        empty = 'No death recorded. Long may it last.' },
    { value = 'reputation', label = 'Reputation',
        note = 'Reputation gained and lost per faction since version 0.5.166, found by comparing the standings whenever '
            .. 'they change. Standing is the last one recorded. Escape in the search box clears it.',
        columns = { { 'Faction', 0, 220, 'text' }, { 'Standing', 225, 100, 'number' }, { 'Gained', 330, 80, 'number' },
            { 'Lost', 415, 70, 'number' }, { 'Today', 490, 75, 'number' }, { 'Last 7 days', 570, 85, 'number' },
            { 'Gains', 660, 60, 'number' }, { 'Last change', 725, 185, 'number' } },
        sortKey = 'journalReputation', default = { column = 6, descending = true },
        rows = View.ReputationRows, cells = View.ReputationCells, sortValue = View.ReputationSort,
        tie = View.ReputationTie,
        search = function(row) return string.lower(row.name or '') end,
        tooltip = View.ReputationTooltip, what = 'factions',
        empty = 'No reputation change recorded yet.' },
}

-- The views in the combo box: the character's progress first, then quests, then the kill lists, then deaths and
-- reputation.
local modes, filters = { journalModes[1] }, { characterFilter }
for _, mode in ipairs(ns.QuestsView and ns.QuestsView.modes or {}) do modes[#modes + 1] = mode end
for _, mode in ipairs(ns.KillsView and ns.KillsView.modes or {}) do modes[#modes + 1] = mode end
modes[#modes + 1] = journalModes[2]
modes[#modes + 1] = journalModes[3]
if ns.KillsView and ns.KillsView.typeFilter then filters[#filters + 1] = ns.KillsView.typeFilter end
if ns.QuestsView and ns.QuestsView.statusFilter then filters[#filters + 1] = ns.QuestsView.statusFilter end

View.view = List.Create({
    id = 'journal', frameName = 'TitanGatheredForeverJournalWindow', title = 'Titan Gathered Forever Journal', modeWidth = 150,
    filters = filters, modes = modes,
})

function View.Show() View.view.Show() end
function View.Toggle() View.view.Toggle() end
function View.Refresh() View.view.Refresh() end
