local _, ns = ...
-- The kill views of the Journal tab, chosen in its combo box: Creatures (kills and loot per creature), Creature drops
-- (what each creature dropped, with the chance per looted corpse) and Rare creatures (rare spawns seen on the realm,
-- also on the map).
local View = {}
ns.KillsView = View

local Style, List = ns.Style, ns.ListWindow

local types = {
    normal = { 'Normal', Style.white }, elite = { 'Elite', Style.yellow }, rare = { 'Rare', Style.cyan },
    rareelite = { 'Rare elite', Style.violet }, worldboss = { 'Boss', Style.orange },
    trivial = { 'Trivial', Style.gray }, minus = { 'Minor', Style.gray },
}
local special = { elite = true, rare = true, rareelite = true, worldboss = true }
local typeChoices = { { value = 'all', label = 'All creatures' }, { value = 'special', label = 'Elite, rare and bosses' },
    { value = 'normal', label = 'Normal creatures' } }

local function typeLabel(row)
    local entry = types[row.classification or '']
    return entry and entry[1]
end
local function typeCell(row)
    local entry = types[row.classification or '']
    return entry and Style.Text(entry[2], entry[1]) or List.Unknown()
end

function View.Name(row) return row.name or ('Creature ' .. row.npcID) end
local function nameCell(row)
    return row.name and Style.Value(row.name) or Style.Text(Style.gray, View.Name(row))
end

function View.Level(row)
    if not row.minLevel then return nil end
    if row.minLevel == row.maxLevel then return tostring(row.minLevel) end
    return row.minLevel .. '-' .. row.maxLevel
end

function View.PerKill(row)
    if row.xpKills > 0 then return math.floor(row.xp / row.xpKills + 0.5) end
end

function View.PerLoot(row)
    if row.moneyCorpses > 0 then return row.copper / row.moneyCorpses end
end

local function count(value)
    return value > 0 and Style.Value(value) or Style.Text(Style.gray, '0')
end
local function zoneCell(mapID)
    local zone = List.Zone(mapID)
    return zone and Style.Value(zone) or List.Unknown()
end
local function lower(value) return value and string.lower(value) or nil end
local function realm() return GetRealmName and GetRealmName() end
local function line(tip, label, value)
    tip:AddDoubleLine(Style.Label(label), value)
    Style.Small(tip)
end
local function percent(value) return string.format('%.1f%%', value * 100) end
local function itemName(itemID)
    return Style.ItemName and Style.ItemName(itemID) or Style.Value(ns.ItemName and ns.ItemName(itemID) or ('Item ' .. itemID))
end
local function plainItem(itemID)
    local name = ns.ItemName and ns.ItemName(itemID)
    return type(name) == 'string' and name or ('Item ' .. itemID)
end

-- Creatures -----------------------------------------------------------------------------------------------------------

function View.Cells(row)
    local level, perKill, perLoot = View.Level(row), View.PerKill(row), View.PerLoot(row)
    return {
        nameCell(row),
        level and Style.Value(level) or List.Unknown(),
        typeCell(row),
        count(row.kills), count(row.group),
        perKill and Style.Value(perKill) or List.Unknown(),
        perLoot and Style.Value(ns.Economy.Coin(perLoot)) or List.Unknown(),
        zoneCell(row.mapID),
        List.Date(row.lastAt),
    }
end

function View.SortValue(row, column)
    if column == 1 then return lower(View.Name(row)) end
    if column == 2 then return row.minLevel and (row.minLevel * 1000 + row.maxLevel) or nil end
    if column == 3 then return lower(typeLabel(row)) end
    if column == 4 then return row.kills end
    if column == 5 then return row.group end
    if column == 6 then return View.PerKill(row) end
    if column == 7 then return View.PerLoot(row) end
    if column == 8 then return lower(List.Zone(row.mapID)) end
    return row.lastAt
end
function View.Tie(a, b)
    local nameA, nameB = string.lower(View.Name(a)), string.lower(View.Name(b))
    if nameA ~= nameB then return nameA < nameB end
    if a.npcID ~= b.npcID then return a.npcID < b.npcID end
    return (a.itemID or 0) < (b.itemID or 0)
end

function View.Rows()
    local rows, restricted = ns.Kills.Rows(ns.db and ns.db.kills, realm(), View.character or nil)
    if View.kind ~= 'all' then
        local kept = {}
        for _, row in ipairs(rows) do
            local isSpecial = special[row.classification or ''] or false
            if (View.kind == 'special') == isSpecial and (View.kind ~= 'normal' or row.classification) then
                kept[#kept + 1] = row
            end
        end
        rows = kept
    end
    return rows, restricted
end

function View.Tooltip(tip, row)
    tip:AddLine(Style.Value(View.Name(row)))
    line(tip, 'Creature ID', Style.Value(row.npcID))
    if typeLabel(row) then line(tip, 'Type', Style.Value(typeLabel(row))) end
    if View.Level(row) then line(tip, 'Level seen', Style.Value(View.Level(row))) end
    line(tip, 'Your killing blows', Style.Value(row.kills))
    line(tip, 'Group killing blows', Style.Value(row.group))
    if row.xpKills > 0 then
        line(tip, 'Experience per kill', Style.Value(View.PerKill(row)))
        line(tip, 'Experience measured', Style.Value(row.xp) .. Style.Label(' over ') .. Style.Value(row.xpKills)
            .. Style.Label(row.xpKills == 1 and ' kill' or ' kills'))
    end
    line(tip, 'First kill', List.DateTime(row.firstAt))
    line(tip, 'Last kill', List.DateTime(row.lastAt))
    if row.looted > 0 then
        Style.Section(tip, 'Loot')
        line(tip, 'Corpses looted', Style.Value(row.looted))
        if row.moneyCorpses > 0 then
            line(tip, 'Money', Style.Value(ns.Economy.Coin(row.copper)) .. Style.Label(' from ') .. Style.Value(row.moneyCorpses)
                .. Style.Label(row.moneyCorpses == 1 and ' corpse' or ' corpses'))
        end
        local drops = {}
        for itemID, corpses in pairs(row.drops) do drops[#drops + 1] = { itemID = itemID, corpses = corpses } end
        table.sort(drops, function(a, b) if a.corpses ~= b.corpses then return a.corpses > b.corpses end return a.itemID < b.itemID end)
        for index = 1, math.min(8, #drops) do
            line(tip, plainItem(drops[index].itemID), Style.Value(percent(drops[index].corpses / row.looted)))
        end
        if #drops > 8 then Style.Note(tip, Style.Label('The Drops view lists all ') .. Style.Value(#drops) .. Style.Label(' items.')) end
    end
    local zones = {}
    for mapID, n in pairs(row.zones) do zones[#zones + 1] = { name = List.Zone(mapID) or ('Map ' .. mapID), count = n } end
    table.sort(zones, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.name < b.name end)
    if #zones > 0 then
        Style.Section(tip, 'Where')
        for index = 1, math.min(5, #zones) do line(tip, zones[index].name, Style.Value(zones[index].count)) end
    end
end

function View.Footer(_, rows, restricted)
    local mine, group = 0, 0
    for _, row in ipairs(rows) do mine, group = mine + row.kills, group + row.group end
    local text = Style.Label('Listed: ') .. Style.Value(mine) .. Style.Label(' killing blows by you, ')
        .. Style.Value(group) .. Style.Label(' by your group.')
    if restricted and restricted > 0 then
        text = text .. Style.Label(' Kills the game kept hidden and that could not be identified: ') .. Style.Value(restricted)
            .. Style.Label('.')
    end
    return text
end

-- Drops ---------------------------------------------------------------------------------------------------------------

function View.DropRows()
    local rows = View.Rows()
    return ns.Kills.Drops(rows)
end

function View.DropCells(row)
    return {
        itemName(row.itemID),
        nameCell(row),
        Style.Value(row.corpses),
        Style.Value(row.looted),
        row.chance and Style.Value(percent(row.chance)) or List.Unknown(),
        Style.Value(string.format('%.1f', row.quantity / row.corpses)),
        zoneCell(row.mapID),
    }
end

function View.DropSort(row, column)
    if column == 1 then return string.lower(plainItem(row.itemID)) end
    if column == 2 then return lower(View.Name(row)) end
    if column == 3 then return row.corpses end
    if column == 4 then return row.looted end
    if column == 5 then return row.chance end
    if column == 6 then return row.quantity / row.corpses end
    return lower(List.Zone(row.mapID))
end
function View.DropTie(a, b)
    local itemA, itemB = string.lower(plainItem(a.itemID)), string.lower(plainItem(b.itemID))
    if itemA ~= itemB then return itemA < itemB end
    return View.Tie(a, b)
end

function View.DropTooltip(tip, row)
    tip:AddLine(itemName(row.itemID))
    line(tip, 'Dropped by', Style.Value(View.Name(row)))
    line(tip, 'In the loot of', Style.Value(row.corpses) .. Style.Label(' of ') .. Style.Value(row.looted)
        .. Style.Label(' looted corpses'))
    line(tip, 'Quantity', Style.Value(row.quantity) .. Style.Label(' in total'))
    Style.Note(tip, Style.Label('Counted from the loot window when a corpse was first opened, taken or not.'))
end

-- Rare creatures ------------------------------------------------------------------------------------------------------

function View.RareRows()
    return ns.Kills.Rares(ns.db and ns.db.rares, ns.db and ns.db.kills, realm(), View.character or nil)
end

function View.RareCells(row)
    return {
        row.name and Style.Text(Style.violet, row.name) or Style.Text(Style.gray, View.Name(row)),
        row.level and Style.Value(row.level) or List.Unknown(),
        typeCell(row),
        Style.Value(row.sightings),
        count(row.kills),
        zoneCell(row.mapID),
        List.Coordinates(row.x, row.y) and Style.Value(List.Coordinates(row.x, row.y)) or List.Unknown(),
        List.Date(row.lastAt),
    }
end

function View.RareSort(row, column)
    if column == 1 then return lower(View.Name(row)) end
    if column == 2 then return row.level end
    if column == 3 then return lower(typeLabel(row)) end
    if column == 4 then return row.sightings end
    if column == 5 then return row.kills end
    if column == 6 then return lower(List.Zone(row.mapID)) end
    if column == 7 then return row.x and (row.x * 1000 + row.y) or nil end
    return row.lastAt
end

function View.RareTooltip(tip, row)
    tip:AddLine(Style.Text(Style.violet, View.Name(row)))
    line(tip, 'Creature ID', Style.Value(row.npcID))
    line(tip, 'Seen', Style.Value(row.sightings) .. Style.Label(row.sightings == 1 and ' time' or ' times'))
    line(tip, 'First seen', List.DateTime(row.firstAt))
    line(tip, 'Last seen', List.DateTime(row.lastAt))
    line(tip, 'Killing blows', Style.Value(row.kills) .. Style.Label(' yours, ') .. Style.Value(row.group) .. Style.Label(' group'))
    if #row.spots > 0 then
        Style.Section(tip, 'Places')
        for index = 1, math.min(5, #row.spots) do
            local spot = row.spots[index]
            line(tip, (List.Zone(spot.mapID) or ('Map ' .. spot.mapID)) .. ' ' .. (List.Coordinates(spot.x, spot.y) or ''),
                List.Date(spot.at))
        end
    end
    Style.Note(tip, Style.Label('Click to show it on the map.'))
end

function View.RareClick(row)
    if row.mapID then List.ShowOnMap(row.npcID, row.mapID) end
end

View.kind = 'all'
View.character = false

-- The kill views live in the Journal tab (JournalView builds the window); this file gives their columns and filters.
View.typeFilter = { width = 175, options = function() return typeChoices end, modes = { creatures = true, drops = true },
    get = function() return View.kind end, set = function(value) View.kind = value end }

View.modes = {
    { value = 'creatures', label = 'Creatures',
        note = 'Creatures killed since version 0.5.165, from the killing blows the game reports. Your kills include your pet; '
            .. 'group kills are those of party and raid members. Experience per kill is measured only when exactly one kill '
            .. 'was followed by one gain. Money per loot is the average coin of a looted corpse. Escape in the search box clears it.',
        columns = { { 'Creature', 0, 200, 'text' }, { 'Level', 205, 50, 'number' }, { 'Type', 260, 75, 'text' },
            { 'Your kills', 340, 65, 'number' }, { 'Group kills', 410, 65, 'number' }, { 'XP per kill', 480, 65, 'number' },
            { 'Money per loot', 550, 100, 'number' }, { 'Zone', 655, 145, 'text' }, { 'Last kill', 805, 105, 'number' } },
        sortKey = 'kills', default = { column = 4, descending = true },
        rows = View.Rows, cells = View.Cells, sortValue = View.SortValue, tie = View.Tie,
        search = function(row)
            return string.lower(View.Name(row) .. ' ' .. (typeLabel(row) or '') .. ' ' .. (List.Zone(row.mapID) or '')
                .. ' ' .. row.npcID)
        end,
        tooltip = View.Tooltip, footer = View.Footer, what = 'creatures',
        empty = 'No kills recorded yet. Kills are counted from now on.',
        nothing = 'No creature of this type was killed.' },
    { value = 'drops', label = 'Creature drops',
        note = 'What dead creatures had in their loot window the first time it was opened, taken or not. The chance is the '
            .. 'share of looted corpses of that creature that held the item. Search finds an item or a creature. '
            .. 'Escape in the search box clears it.',
        columns = { { 'Item', 0, 230, 'text' }, { 'Creature', 240, 190, 'text' }, { 'Dropped', 440, 65, 'number' },
            { 'Looted', 510, 65, 'number' }, { 'Chance', 580, 70, 'number' }, { 'Avg quantity', 655, 85, 'number' },
            { 'Zone', 745, 165, 'text' } },
        sortKey = 'killDrops', default = { column = 3, descending = true },
        rows = View.DropRows, cells = View.DropCells, sortValue = View.DropSort, tie = View.DropTie,
        search = function(row)
            return string.lower(plainItem(row.itemID) .. ' ' .. View.Name(row) .. ' ' .. (List.Zone(row.mapID) or ''))
        end,
        tooltip = View.DropTooltip, what = 'drops',
        empty = 'No creature loot recorded yet. It is counted from now on.',
        nothing = 'No loot of this type of creature was recorded.' },
    { value = 'rares', label = 'Rare creatures',
        note = 'Rare creatures seen on this realm by any of your characters, with the place where they came into view '
            .. '(not inside instances). Kills are those of the selected characters. Click a row to show it on the map. '
            .. 'Escape in the search box clears it.',
        columns = { { 'Creature', 0, 200, 'text' }, { 'Level', 205, 50, 'number' }, { 'Type', 260, 80, 'text' },
            { 'Seen', 345, 60, 'number' }, { 'Your kills', 410, 70, 'number' }, { 'Zone', 485, 170, 'text' },
            { 'Coordinates', 660, 110, 'number' }, { 'Last seen', 775, 135, 'number' } },
        sortKey = 'killRares', default = { column = 8, descending = true },
        rows = View.RareRows, cells = View.RareCells, sortValue = View.RareSort, tie = View.Tie,
        search = function(row)
            return string.lower(View.Name(row) .. ' ' .. (List.Zone(row.mapID) or '') .. ' ' .. row.npcID)
        end,
        tooltip = View.RareTooltip, click = View.RareClick, what = 'rare creatures',
        empty = 'No rare creature seen yet. They are recorded when one comes into view.' },
}
View.store = { creatures = 'kills', drops = 'kills', rares = 'kills' }

local function journal() return ns.JournalView and ns.JournalView.view end
function View.Show() if journal() then journal().Show({ 'creatures', 'drops', 'rares' }) end end
function View.Refresh() if journal() then journal().Refresh() end end
