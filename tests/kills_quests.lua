local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function strip(text) return (tostring(text):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')) end

local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })
local clock, wall, timers
local units

local function newNs()
    clock, wall, timers = 100, 1000000, {}
    units = { player = { guid = 'Player-1-AAA', xp = 100, max = 1000, level = 10 }, pet = { guid = 'Pet-0-1-1-1-1-99-1' } }
    _G.GetTime = function() return clock end
    _G.time = function() return wall end
    _G.GetRealmName = function() return 'Realm' end
    _G.UnitGUID = function(unit) return units[unit] and units[unit].guid end
    _G.UnitName = function(unit) return units[unit] and units[unit].name end
    _G.UnitLevel = function(unit) return units[unit] and units[unit].level end
    _G.UnitClassification = function(unit) return units[unit] and units[unit].classification end
    _G.UnitXP = function() return units.player.xp end
    _G.UnitXPMax = function() return units.player.max end
    _G.IsInInstance = function() return false, 'none' end
    _G.C_Map = { GetBestMapForUnit = function() return 1429 end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.6 end } end,
        GetMapInfo = function(id) return { name = id == 1429 and 'Elwynn Forest' or ('Zone ' .. id) } end }
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.C_QuestLog = { GetTitleForQuestID = function(id) if id == 7 then return 'Wolves Across the Border' end end,
        RequestLoadQuestByID = function(id) _G.requestedQuest = id end }
    _G.date = function(format, at) at = at or wall; return format:find('%%H') and 'D ' .. at .. ' T' or 'D ' .. at end
    local ns = { characterID = 'Player-1-AAA', db = { characters = {} }, settings = { columnSort = {} },
        IsPublic = function(value) return value ~= SECRET end }
    ns.Style = { gold = 'ffffd100', white = 'ffffffff', gray = 'ff9d9d9d', green = 'ff20ff20', yellow = 'ffffff00',
        cyan = 'ff53c9ff', violet = 'ffb48cfa', orange = 'ffff8020', Small = function() end, Section = function(tip, title) tip:AddLine(title) end }
    dofile('tests/style_stub.lua')(ns.Style)
    ns.VendorSales = { ExcludeWalletChanges = function() end }
    ns.LootIncome = { ExcludeWalletChanges = function() end }
    ns.Economy = { Coin = function(copper) return copper .. 'c' end }
    ns.ItemName = function(id) return 'Item ' .. id end
    for _, file in ipairs({ 'QuestIncome.lua', 'Kills.lua', 'Journal.lua', 'ListWindow.lua' }) do
        assert(loadfile('TitanGatheredForever/' .. file))('TitanGatheredForever', ns)
    end
    return ns
end

local function creature(npcID, spawn) return 'Creature-0-1-2-3-' .. npcID .. '-' .. (spawn or '0001') end
local function own(ns, npcID) return ns.db.kills.Realm['Player-1-AAA'].npcs[npcID] end

test('creature IDs are read from creature GUIDs only', function()
    local ns = newNs()
    eq(ns.Kills.NpcID(creature(299)), 299)
    eq(ns.Kills.NpcID('Vehicle-0-1-2-3-500-0001'), 500)
    eq(ns.Kills.NpcID('Player-1-AAA'), nil)
    eq(ns.Kills.NpcID('Pet-0-1-1-1-1-99-1'), nil)
    eq(ns.Kills.NpcID(SECRET), nil)
end)

test('killing blows are counted as yours, your pet\'s or your group\'s, with name, level, type and zone', function()
    local ns = newNs()
    units.target = { guid = creature(299, 'a'), name = 'Diseased Young Wolf', level = 2, classification = 'normal' }
    ns.Kills.PartyKill('Player-1-AAA', creature(299, 'a'))
    ns.Kills.PartyKill('Player-1-AAA', creature(299, 'a'))          -- the same death reported twice counts once
    units.target = nil
    ns.Kills.PartyKill('Pet-0-1-1-1-1-99-1', creature(299, 'b'))
    ns.Kills.PartyKill('Player-1-BBB', creature(299, 'c'))
    local entry = own(ns, 299)
    eq(entry.kills, 2); eq(entry.group, 1)
    eq(entry.name, 'Diseased Young Wolf'); eq(entry.minLevel, 2); eq(entry.maxLevel, 2); eq(entry.classification, 'normal')
    eq(entry.zones[1429], 3); eq(entry.firstAt, wall); eq(entry.lastAt, wall)
    ns.Kills.PartyKill('Player-1-AAA', 'Player-1-CCC')                -- players are PvP, not creatures
    eq(own(ns, 299).kills, 2)
end)

test('a creature seen before its death keeps its name; hidden kills are counted but not identified', function()
    local ns = newNs()
    units.nameplate3 = { guid = creature(6, 'x'), name = 'Kobold Vermin', level = 3, classification = 'elite' }
    ns.Kills.Remember('nameplate3')
    units.nameplate3 = nil
    ns.Kills.PartyKill('Player-1-AAA', creature(6, 'x'))
    eq(own(ns, 6).name, 'Kobold Vermin'); eq(own(ns, 6).classification, 'elite')
    ns.Kills.PartyKill(SECRET, creature(6, 'y'))
    ns.Kills.PartyKill('Player-1-AAA', SECRET)
    eq(ns.db.kills.Realm['Player-1-AAA'].restricted, 2)
    eq(own(ns, 6).kills, 1)
end)

test('experience is given to a kill only when one kill meets one gain', function()
    local ns = newNs()
    ns.Kills.ReadExperience()                                        -- baseline
    ns.Kills.PartyKill('Player-1-AAA', creature(1, 'a'))
    clock = clock + 0.3; units.player.xp = 145; ns.Kills.ReadExperience()
    eq(own(ns, 1).xp, 45); eq(own(ns, 1).xpKills, 1)
    -- the gain arrives just before the kill event
    clock = clock + 10; units.player.xp = 190; ns.Kills.ReadExperience()
    clock = clock + 0.2; ns.Kills.PartyKill('Player-1-AAA', creature(1, 'b'))
    eq(own(ns, 1).xp, 90); eq(own(ns, 1).xpKills, 2)
    -- two kills, one gain: nobody can tell, nothing is attributed
    clock = clock + 10
    ns.Kills.PartyKill('Player-1-AAA', creature(2, 'a')); ns.Kills.PartyKill('Player-1-AAA', creature(2, 'b'))
    units.player.xp = 280; ns.Kills.ReadExperience()
    eq(own(ns, 2).kills, 2); eq(own(ns, 2).xp, nil)
    -- a gain too late after the kill is not the kill's
    clock = clock + 10; ns.Kills.PartyKill('Player-1-AAA', creature(3, 'a'))
    clock = clock + 5; units.player.xp = 300; ns.Kills.ReadExperience()
    eq(own(ns, 3).xp, nil)
    -- a level up adds the rest of the old level
    clock = clock + 10; ns.Kills.PartyKill('Player-1-AAA', creature(4, 'a'))
    units.player.xp, units.player.level, units.player.max = 20, 11, 1200; ns.Kills.ReadExperience()
    eq(own(ns, 4).xp, 720)
    -- quest experience is the quest's
    clock = clock + 10; ns.Kills.PartyKill('Player-1-AAA', creature(5, 'a'))
    ns.QuestIncome.TurnedIn(7, 0, 300)
    units.player.xp = 320; ns.Kills.ReadExperience()
    eq(own(ns, 5).xp, nil)
end)

test('kill rows sum the characters and pick the most common zone', function()
    local ns = newNs()
    ns.db.kills = { Realm = {
        A = { restricted = 1, npcs = { [299] = { name = 'Wolf', kills = 3, group = 1, xp = 90, xpKills = 2, minLevel = 2,
            maxLevel = 3, firstAt = 50, lastAt = 70, zones = { [12] = 3, [40] = 1 } } } },
        B = { restricted = 2, npcs = { [299] = { name = 'Wolf', kills = 2, group = 0, minLevel = 1, maxLevel = 2,
            firstAt = 40, lastAt = 60, zones = { [40] = 1 } }, [6] = { kills = 1, group = 0 } } },
    } }
    local rows, restricted = ns.Kills.Rows(ns.db.kills, 'Realm')
    eq(#rows, 2); eq(restricted, 3)
    local wolf = rows[1].npcID == 299 and rows[1] or rows[2]
    eq(wolf.kills, 5); eq(wolf.group, 1); eq(wolf.total, 6); eq(wolf.xp, 90); eq(wolf.xpKills, 2)
    eq(wolf.minLevel, 1); eq(wolf.maxLevel, 3); eq(wolf.firstAt, 40); eq(wolf.lastAt, 70); eq(wolf.mapID, 12)
    rows, restricted = ns.Kills.Rows(ns.db.kills, 'Realm', 'B')
    eq(#rows, 2); eq(restricted, 2)
    eq(#ns.Kills.Rows(ns.db.kills, 'Other'), 0)
end)

test('quests record acceptance, experience, money, zone and the time taken', function()
    local ns = newNs()
    ns.QuestIncome.Accepted(7)
    wall = wall + 600
    ns.QuestIncome.TurnedIn(7, 250, 450)
    ns.QuestIncome.Removed(7, false)                                 -- the turn-in already closed it
    eq(#timers, 0)
    local entry = ns.db.questIncome.Realm['Player-1-AAA'][7]
    eq(entry.copper, 250); eq(entry.turnIns, 1); eq(entry.xp, 450); eq(entry.xpTurnIns, 1)
    eq(entry.timeTotal, 600); eq(entry.timed, 1); eq(entry.mapID, 1429); eq(entry.acceptedAt, nil); eq(entry.accepts, 1)
    eq(entry.firstAt, wall); eq(entry.abandons, nil)
    eq(select(1, ns.QuestIncome.Total(ns.db.questIncome, 'Realm')), 250)
end)

test('a quest that leaves the log without a turn-in was abandoned; a turn-in right after the removal is not', function()
    local ns = newNs()
    ns.QuestIncome.Accepted(8)
    ns.QuestIncome.Removed(8, false)
    eq(#timers, 1); timers[1]()
    local entry = ns.db.questIncome.Realm['Player-1-AAA'][8]
    eq(entry.abandons, 1); eq(entry.acceptedAt, nil); eq(entry.abandonedAt, wall); eq(entry.turnIns, 0)
    ns.QuestIncome.Accepted(9)
    ns.QuestIncome.Removed(9, false)
    ns.QuestIncome.TurnedIn(9, 0, 100)
    timers[2]()
    eq(ns.db.questIncome.Realm['Player-1-AAA'][9].abandons, nil)
    ns.QuestIncome.Accepted(10)
    ns.QuestIncome.Removed(10, true)                                -- a replay quest is not abandoned
    eq(#timers, 2)
end)

test('quest rows give each quest a status and keep older turn-ins without experience unknown', function()
    local ns = newNs()
    ns.db.questIncome = { Realm = {
        A = { [1] = { copper = 10, turnIns = 1, firstAt = 5, lastAt = 5 },
              [2] = { copper = 0, turnIns = 0, acceptedAt = 9, acceptMapID = 12, accepts = 1 },
              [3] = { copper = 0, turnIns = 0, abandons = 1, abandonedAt = 8 } },
        B = { [1] = { copper = 5, turnIns = 2, xp = 300, xpTurnIns = 2, timeTotal = 100, timed = 2, firstAt = 3, lastAt = 20, mapID = 40 } },
    } }
    local rows = ns.QuestIncome.Rows(ns.db.questIncome, 'Realm')
    table.sort(rows, function(a, b) return a.questID < b.questID end)
    eq(#rows, 3)
    eq(rows[1].status, 'completed'); eq(rows[1].turnIns, 3); eq(rows[1].copper, 15); eq(rows[1].xp, 300)
    eq(rows[1].xpTurnIns, 2); eq(rows[1].firstAt, 3); eq(rows[1].lastAt, 20); eq(rows[1].mapID, 40); eq(rows[1].last, 20)
    eq(rows[2].status, 'open'); eq(rows[2].acceptedAt, 9); eq(rows[2].last, 9)
    eq(rows[3].status, 'abandoned'); eq(rows[3].last, 8)
    eq(#ns.QuestIncome.Rows(ns.db.questIncome, 'Realm', 'A'), 3)
    eq(#ns.QuestIncome.Rows(ns.db.questIncome, 'Realm', 'B'), 1)
end)

-- Window stubs: every frame records its template and scripts; texts are kept.
local created
local function installFrames()
    created = {}
    local function frame(template)
        local f = { template = template, scripts = {}, shown = true }
        created[#created + 1] = f
        return setmetatable(f, { __index = function(_, key)
            if key == 'SetScript' then return function(self, name, fn) self.scripts[name] = fn end end
            if key == 'SetText' then return function(self, value) rawset(self, 'text', value) end end
            if key == 'GetText' then return function(self) return rawget(self, 'text') or '' end end
            if key == 'IsShown' then return function(self) return self.shown end end
            if key == 'Show' then return function(self) self.shown = true end end
            if key == 'Hide' then return function(self) self.shown = false end end
            if key == 'GetStringWidth' then return function() return 40 end end
            return function(self)
                if key:match('^Create') then return frame() end
                if key == 'GetNumPoints' then return 0 end
                return self
            end
        end })
    end
    _G.CreateFrame = function(_, _, _, template) local f = frame(template); f.TitleText = frame(); return f end
    local tip = { lines = {} }
    function tip:SetOwner() self.lines = {} end
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. ' ' .. right end
    function tip:Show() end
    function tip:Hide() end
    _G.UIParent, _G.UISpecialFrames, _G.GameTooltip = frame(), {}, tip
    _G.PanelTemplates_SetNumTabs, _G.PanelTemplates_SetTab = nil, nil
    return tip
end

local function loadViews(ns)
    for _, file in ipairs({ 'Navigation.lua', 'ColumnSort.lua', 'ListWindow.lua', 'KillsView.lua', 'QuestsView.lua',
        'JournalView.lua', 'JournalPins.lua' }) do
        assert(loadfile('TitanGatheredForever/' .. file))('TitanGatheredForever', ns)
    end
end

local function cellsOf(window, index)
    local out = {}
    for i, cell in ipairs(window.lines[index].cells) do out[i] = strip(cell:GetText()) end
    return out
end

test('the Kills tab lists creatures sorted by your kills, with search, filters and no buttons', function()
    local ns = newNs()
    local tip = installFrames()
    loadViews(ns)
    ns.db.characters['Player-1-BBB'] = { economyName = 'Alt' }
    ns.db.kills = { Realm = {
        ['Player-1-AAA'] = { restricted = 4, npcs = {
            [299] = { name = 'Diseased Young Wolf', kills = 12, group = 0, xp = 90, xpKills = 2, minLevel = 1, maxLevel = 2,
                classification = 'normal', firstAt = 10, lastAt = 20, zones = { [1429] = 12 } },
            [6] = { name = 'Kobold Vermin', kills = 30, group = 2, classification = 'normal', lastAt = 30, zones = { [1429] = 1 } },
            [61] = { name = 'Thuros Lightfingers', kills = 1, group = 0, classification = 'rareelite', lastAt = 40, zones = {} } } },
        ['Player-1-BBB'] = { restricted = 0, npcs = { [113] = { kills = 3, group = 0 } } },
    } }
    local view = ns.Nav.views.journal
    eq(ns.Nav.tabs[#ns.Nav.tabs].id, 'journal'); eq(#ns.Nav.tabs, 9)   -- kills and quests are views of the Journal tab
    ns.Nav.Open('kills')
    eq(view.mode, 'creatures')
    local w = view.window
    eq(view.total, 4)
    local first = cellsOf(w, 1)
    eq(first[1], 'Kobold Vermin'); eq(first[4], '30'); eq(first[5], '2'); eq(first[6], 'Unknown')
    eq(first[7], 'Unknown'); eq(first[8], 'Elwynn Forest'); eq(first[9], 'D 30')
    local wolf = cellsOf(w, 2)
    eq(wolf[2], '1-2'); eq(wolf[3], 'Normal'); eq(wolf[6], '45')
    eq(cellsOf(w, 3)[1], 'Creature 113')
    assert(strip(w.footer:GetText()):find('46 killing blows by you, 2 by your group', 1, true))
    assert(strip(w.footer:GetText()):find('identified: 4', 1, true))
    -- hover
    w.lines[1].scripts.OnEnter(w.lines[1])
    assert(strip(table.concat(tip.lines, '\n')):find('Your killing blows 30', 1, true))
    -- search, then Escape clears it
    w.search:SetText('wolf'); w.search.scripts.OnTextChanged(w.search, true)
    eq(view.total, 1)
    w.search.scripts.OnEscapePressed(w.search)
    eq(view.total, 4); eq(w.search:GetText(), '')
    w.search:SetText('zzz'); w.search.scripts.OnTextChanged(w.search, true)
    eq(strip(w.empty:GetText()), 'Nothing matches this search.')
    w.search.scripts.OnEscapePressed(w.search)
    -- type filter and character filter
    ns.KillsView.kind = 'special'; view.Changed()
    eq(view.total, 1); eq(cellsOf(w, 1)[3], 'Rare elite')
    ns.KillsView.kind = 'all'; ns.KillsView.character = 'Player-1-BBB'; view.Changed()
    eq(view.total, 1)
    local choices = ns.ListWindow.Characters(ns.db.kills, 'Realm')
    eq(choices[1].label, 'All characters'); eq(choices[2].label, 'This character'); eq(choices[3].label, 'Alt')
    -- sorting by the name column
    ns.KillsView.character = false
    view.sorter.buttons[1].scripts.OnClick()
    eq(cellsOf(w, 1)[1], 'Creature 113'); eq(cellsOf(w, 2)[1], 'Diseased Young Wolf')
    eq(ns.settings.columnSort.kills.column, 1)
    -- opening Kills again keeps the kill view that is shown; Quests switches to the quest view
    view.SetMode('rares'); ns.Nav.Open('kills'); eq(view.mode, 'rares')
    ns.Nav.Open('quests'); eq(view.mode, 'quests')
    view.SetMode('creatures')
    -- the only plain buttons are the fallback tab strip
    local buttons = 0
    for _, f in ipairs(created) do if f.template == 'UIPanelButtonTemplate' then buttons = buttons + 1 end end
    eq(buttons, #ns.Nav.tabs)
end)

test('the Quests tab lists quests with names from the game, status filter, money, time and zone', function()
    local ns = newNs()
    installFrames()
    loadViews(ns)
    ns.db.questIncome = { Realm = { ['Player-1-AAA'] = {
        [7] = { copper = 250, turnIns = 1, xp = 450, xpTurnIns = 1, timeTotal = 3900, timed = 1, firstAt = 50, lastAt = 50, mapID = 1429 },
        [8] = { copper = 0, turnIns = 0, acceptedAt = 60, acceptMapID = 1429, accepts = 1 },
        [9] = { copper = 40, turnIns = 1, firstAt = 30, lastAt = 30 },
    } } }
    _G.requestedQuest = nil
    ns.Nav.Open('quests')
    local view = ns.Nav.views.journal
    eq(view.mode, 'quests')
    local w = view.window
    eq(view.total, 3)
    local open = cellsOf(w, 1)                                       -- newest activity first
    eq(open[1], 'Quest 8'); eq(open[2], 'In progress'); eq(open[3], '0'); eq(open[4], 'Unknown')
    assert(_G.requestedQuest ~= nil)
    local done = cellsOf(w, 2)
    eq(done[1], 'Wolves Across the Border'); eq(done[2], 'Completed'); eq(done[4], '450'); eq(done[5], '250c')
    eq(done[6], '1h 05m'); eq(done[7], 'Elwynn Forest'); eq(done[8], 'D 50')
    local old = cellsOf(w, 3)
    eq(old[4], 'Unknown'); eq(old[6], 'Unknown'); eq(old[7], 'Unknown')
    ns.QuestsView.status = 'open'; view.Changed()
    eq(view.total, 1)
    ns.QuestsView.status = 'all'; view.Changed()
    w.search:SetText('wolves'); w.search.scripts.OnTextChanged(w.search, true)
    eq(view.total, 1)
    -- a quest name that arrives later redraws the list once
    ns.QuestsView.DataLoaded(); ns.QuestsView.DataLoaded()
    eq(#timers, 1)
    assert(strip(w.footer:GetText()):find('Listed: 1 turn-ins, 450 experience, 250c', 1, true))
end)

test('durations are short and readable', function()
    local ns = newNs()
    installFrames()
    loadViews(ns)
    local D = ns.ListWindow.Duration
    eq(D(45), '45s'); eq(D(720), '12m'); eq(D(7500), '2h 05m'); eq(D(3 * 86400 + 4 * 3600), '3d 4h')
end)

test('the loot window of dead creatures is counted once per corpse, with money and items', function()
    local ns = newNs()
    _G.Enum = { LootSlotType = { Item = 1, Money = 2 } }
    local slotTypes = { [1] = 2, [2] = 1, [3] = 1, [4] = 1 }
    _G.GetLootSlotType = function(slot) return slotTypes[slot] end
    ns.Kills.PartyKill('Player-1-AAA', creature(299, 'a'))
    ns.Kills.PartyKill('Player-1-BBB', creature(299, 'b'))
    local slots = {
        { slot = 1, sources = { creature(299, 'a'), creature(299, 'b') },
            sourceQuantities = { [creature(299, 'a')] = 50, [creature(299, 'b')] = 30 } },
        { slot = 2, itemID = 2589, quantity = 2, sources = { creature(299, 'a') }, sourceQuantities = {} },
        { slot = 3, itemID = 2589, quantity = 1, sources = { creature(299, 'b') }, sourceQuantities = {} },
        { slot = 4, itemID = 765, quantity = 1, sources = { creature(299, 'b'), creature(7, 'alive') },
            sourceQuantities = { [creature(299, 'b')] = 1, [creature(7, 'alive')] = 1 } },
    }
    ns.Kills.Loot(slots)
    ns.Kills.Loot(slots)                                             -- LOOT_READY and LOOT_OPENED: still once
    local entry = own(ns, 299)
    eq(entry.looted, 2); eq(entry.moneyCorpses, 2); eq(entry.copper, 80)
    eq(entry.drops[2589], 2); eq(entry.quantities[2589], 3); eq(entry.drops[765], 1)
    eq(own(ns, 7), nil)                                              -- a living creature (pickpocket) is not loot
    local rows = ns.Kills.Rows(ns.db.kills, 'Realm')
    local drops = ns.Kills.Drops(rows)
    eq(#drops, 2)
    table.sort(drops, function(a, b) return a.itemID < b.itemID end)
    eq(drops[1].itemID, 765); eq(drops[1].chance, 0.5); eq(drops[2].chance, 1); eq(drops[2].quantity, 3)
end)

test('rare creatures are recorded once per spawn with the place they were seen', function()
    local ns = newNs()
    units.target = { guid = creature(61, 'one'), name = 'Thuros Lightfingers', level = 15, classification = 'rareelite' }
    ns.Kills.Remember('target'); ns.Kills.Remember('target')
    units.target.guid = creature(61, 'two')
    ns.Kills.Remember('target')
    units.target = { guid = creature(6, 'x'), name = 'Kobold', level = 2, classification = 'normal' }
    ns.Kills.Remember('target')
    local rare = ns.db.rares.Realm[61]
    eq(rare.sightings, 2); eq(rare.name, 'Thuros Lightfingers'); eq(#rare.spots, 1); eq(rare.spots[1].count, 2)
    eq(rare.spots[1].mapID, 1429); eq(rare.spots[1].x, 0.4)
    eq(ns.db.rares.Realm[6], nil)
    ns.Kills.PartyKill('Player-1-AAA', creature(61, 'two'))
    local rows = ns.Kills.Rares(ns.db.rares, ns.db.kills, 'Realm')
    eq(#rows, 1); eq(rows[1].kills, 1); eq(rows[1].sightings, 2); eq(rows[1].mapID, 1429)
    _G.IsInInstance = function() return true, 'party' end
    units.target = { guid = creature(62, 'i'), name = 'Dungeon Rare', classification = 'rare' }
    ns.Kills.Remember('target')
    eq(ns.db.rares.Realm[62].sightings, 1); eq(ns.db.rares.Realm[62].spots, nil)   -- no map spots inside instances
end)

test('levels keep the time played and the experience by source', function()
    local ns = newNs()
    ns.Journal.Start()
    local levels = ns.db.levels.Realm['Player-1-AAA']
    eq(levels[10].partial, true)
    ns.Kills.ReadExperience()
    ns.Kills.PartyKill('Player-1-AAA', creature(1, 'a'))
    clock = clock + 0.2; units.player.xp = 150; ns.Kills.ReadExperience()          -- kill
    ns.QuestIncome.TurnedIn(7, 0, 200); units.player.xp = 350; ns.Kills.ReadExperience()   -- quest
    clock = clock + 20; units.player.xp = 400; ns.Kills.ReadExperience()          -- exploration: waits for a kill
    eq(#timers, 1); timers[1]()
    eq(levels[10].kill, 50); eq(levels[10].quest, 200); eq(levels[10].other, 50)
    eq(levels[10].kills, 1); eq(levels[10].quests, 1)
    clock = clock + 100
    ns.Journal.LevelUp(11)
    eq(levels[10].played, 120); eq(levels[11].reachedAt, wall); eq(levels[11].partial, nil)
    clock = clock + 30
    local rows = ns.Journal.LevelRows('Realm')
    table.sort(rows, function(a, b) return a.level < b.level end)
    eq(#rows, 2); eq(rows[2].played, 30); eq(rows[2].current, true)
    ns.Journal.Stop()
    eq(levels[11].played, 30)
end)

test('deaths keep the place, the level and the lethal blow of the death recap', function()
    local ns = newNs()
    ns.Journal.Start()
    ns.Journal.Died({ { overkill = -1, sourceName = 'Young Wolf' }, { overkill = 12, sourceName = 'Hogger', spellName = 'Melee' } })
    ns.Journal.Died(nil)
    local deaths = ns.db.deaths.Realm['Player-1-AAA']
    eq(#deaths, 2); eq(deaths[1].killer, 'Hogger'); eq(deaths[1].spell, 'Melee'); eq(deaths[1].mapID, 1429)
    eq(deaths[1].x, 0.4); eq(deaths[1].level, 10); eq(deaths[1].place, 'world'); eq(deaths[2].killer, nil)
    eq(ns.db.levels.Realm['Player-1-AAA'][10].deaths, 2)
    eq(#ns.Journal.DeathRows('Realm'), 2)
    eq(ns.Journal.Killer({ { overkill = SECRET, sourceName = 'Hidden' } }), nil)
end)

test('reputation gains and losses are found by comparing two readings', function()
    local ns = newNs()
    local factions = { { factionID = 72, name = 'Stormwind', currentStanding = 3000, reaction = 5 },
        { factionID = 1, name = 'Alliance', isHeader = true, currentStanding = 0 } }
    local hidden = { factionID = 47, name = 'Ironforge', currentStanding = 100, reaction = 4 }
    _G.C_Reputation = {
        GetNumFactions = function() return #factions end,
        GetFactionDataByIndex = function(index) return factions[index] end,
        GetFactionDataByID = function(id) if id == 47 then return hidden end; for _, f in ipairs(factions) do if f.factionID == id then return f end end end,
    }
    factions[3] = hidden
    ns.Journal.ScanFactions()                                        -- baseline, nothing recorded
    eq(ns.db.reputation, nil)
    factions[1].currentStanding = 3025
    factions[3] = nil                                                -- its header was collapsed
    hidden.currentStanding = 110
    ns.Journal.ScanFactions()
    factions[1].currentStanding = 3015
    ns.Journal.ScanFactions()
    local rep = ns.db.reputation.Realm['Player-1-AAA']
    eq(rep[72].gained, 25); eq(rep[72].lost, 10); eq(rep[72].gains, 1); eq(rep[72].reaction, 5)
    eq(rep[47].gained, 10); eq(rep[1], nil)
    local rows = ns.Journal.ReputationRows('Realm')
    table.sort(rows, function(a, b) return a.factionID < b.factionID end)
    eq(rows[2].today, 15); eq(rows[2].week, 15); eq(rows[2].name, 'Stormwind')
end)

test('quest givers, the turn-in NPC and the items received are recorded', function()
    local ns = newNs()
    units.questnpc = { guid = creature(197, 'g'), name = 'Marshal McBride' }
    _G.GetQuestID = function() return 7 end
    ns.QuestIncome.Detail()
    ns.QuestIncome.Accepted(7)
    local entry = ns.db.questIncome.Realm['Player-1-AAA'][7]
    eq(entry.giver, 197)
    local giver = ns.db.questGivers.Realm[197]
    eq(giver.name, 'Marshal McBride'); eq(giver.mapID, 1429); eq(giver.x, 0.4); eq(giver.quests[7], true)
    units.questnpc = { guid = creature(198, 't'), name = 'Deputy Willem' }
    ns.QuestIncome.Complete()
    _G.GetNumQuestRewards = function() return 1 end
    _G.GetNumQuestChoices = function() return 3 end
    _G.GetQuestItemLink = function(kind, index) return 'item:' .. (kind == 'reward' and 100 or 200 + index) .. ':0' end
    _G.GetQuestItemInfo = function(kind) return 'x', 'icon', kind == 'reward' and 5 or 1 end
    ns.QuestIncome.RewardChosen(2)
    ns.QuestIncome.TurnedIn(7, 10, 100)
    eq(entry.turnInNpc, 198); eq(entry.turnInName, 'Deputy Willem'); eq(entry.rewards[100], 5); eq(entry.rewards[202], 1)
    eq(entry.chosen, 202)
    local rows = ns.QuestIncome.Rows(ns.db.questIncome, 'Realm')
    eq(rows[1].giver, 197); eq(rows[1].turnInName, 'Deputy Willem'); eq(rows[1].rewards[202], 1)
end)

test('only givers of quests in progress get a pin, a round gray question mark, never the yellow exclamation mark', function()
    local ns = newNs()
    installFrames()
    loadViews(ns)
    ns.db.questGivers = { Realm = {
        [197] = { name = 'Marshal McBride', mapID = 1429, x = 0.4, y = 0.6, quests = { [7] = true, [8] = true } },
        [198] = { name = 'Done Giver', mapID = 1429, x = 0.3, y = 0.3, quests = { [9] = true } } } }
    ns.db.rares = { Realm = { [61] = { name = 'Thuros', sightings = 2, classification = 'rareelite',
        spots = { { mapID = 1429, x = 0.5, y = 0.5, at = 9, count = 2 }, { mapID = 12, x = 0.1, y = 0.1, at = 8 } } } } }
    ns.db.questIncome = { Realm = { ['Player-1-AAA'] = { [7] = { copper = 0, turnIns = 1 }, [9] = { copper = 0, turnIns = 1 } } } }
    local onQuest = { [8] = true }
    _G.C_QuestLog.IsOnQuest = function(id) return onQuest[id] == true end
    local lit = {}
    ns.NpcSources = { IsHighlighted = function(id) return lit[id] == true end }
    local nodes = ns.JournalPins.List(1429)
    eq(#nodes, 2); eq(nodes[1].kind, 'QuestGiver'); eq(nodes[1].npcID, 197); eq(nodes[2].kind, 'RareCreature')
    eq(nodes[2].count, 2)
    -- the gray question mark of the game, never its yellow exclamation mark
    assert(loadfile('TitanGatheredForever/PinStyle.lua'))('TitanGatheredForever', ns)
    local icon = ns.PinStyle.Icon(nil, 'QuestGiver')
    assert(icon:find('IncompleteQuestIcon', 1, true)); assert(not icon:find('Available', 1, true))
    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = strip(text) end
    function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = strip(left) .. ' ' .. strip(right) end
    ns.Style.Note = function(t, text) t:AddLine(text) end
    ns.JournalPins.FillTooltip(tip, nodes[1])
    eq(tip.lines[1], 'Marshal McBride'); eq(tip.lines[3], 'Quest 8 In progress')     -- in progress first
    eq(tip.lines[4], 'Wolves Across the Border Completed')
    -- the quest is turned in: the pin goes away
    onQuest[8] = nil
    eq(#ns.JournalPins.List(1429), 1)
    -- a giver shown from the Quests list keeps a pin, as a plain note
    lit[198] = true
    local shown = ns.JournalPins.List(1429)
    eq(#shown, 2); eq(shown[1].kind, 'QuestGiverPast')
    assert(not ns.PinStyle.Icon(nil, 'QuestGiverPast'):find('Quest', 1, true))
    lit[198] = nil
    -- without the quest log API the record decides
    _G.C_QuestLog.IsOnQuest = nil
    ns.db.questIncome.Realm['Player-1-AAA'][8] = { copper = 0, turnIns = 0, acceptedAt = 5 }
    eq(ns.JournalPins.List(1429)[1].kind, 'QuestGiver')
    ns.settings.mapQuestGivers = false
    eq(#ns.JournalPins.List(1429), 1)
    ns.settings.mapRareCreatures = false
    eq(#ns.JournalPins.List(1429), 0); eq(ns.JournalPins.Enabled(), false)
end)

test('views are chosen in a combo box; the Journal tab lists levels, deaths and reputation', function()
    local ns = newNs()
    installFrames()
    loadViews(ns)
    ns.db.kills = { Realm = { ['Player-1-AAA'] = { restricted = 0, npcs = {
        [299] = { name = 'Wolf', kills = 2, group = 0, looted = 2, moneyCorpses = 2, copper = 30, drops = { [2589] = 1 },
            quantities = { [2589] = 2 } } } } } }
    ns.db.rares = { Realm = { [61] = { name = 'Thuros', sightings = 1, spots = { { mapID = 1429, x = 0.5, y = 0.5, at = 9 } } } } }
    local kills = ns.Nav.views.journal
    ns.Nav.Open('kills')
    local w = kills.window
    eq(cellsOf(w, 1)[7], '15c')                                     -- money per looted corpse
    kills.SetMode('drops')
    eq(kills.total, 1); eq(cellsOf(w, 1)[1], 'Item 2589'); eq(cellsOf(w, 1)[5], '50.0%'); eq(cellsOf(w, 1)[6], '2.0')
    eq(ns.settings.listModes.journal, 'drops')
    kills.SetMode('rares')
    eq(kills.total, 1); eq(cellsOf(w, 1)[1], 'Thuros'); eq(cellsOf(w, 1)[7], '50.0, 50.0')
    eq(w.filters[3].shown, false); eq(w.filters[2].shown, true)    -- the type filter belongs to the other views
    eq(w.filters[4].shown, false)                                  -- the status filter to the quest view
    eq(w.headers.rares.shown, true); eq(w.headers.creatures.shown, false)
    ns.db.levels = { Realm = { ['Player-1-AAA'] = { [10] = { played = 3700, kill = 100, quest = 50, other = 5, kills = 4,
        quests = 1, deaths = 0, partial = true } } } }
    ns.db.deaths = { Realm = { ['Player-1-AAA'] = { { at = 77, mapID = 1429, x = 0.1, y = 0.2, level = 10, place = 'world',
        killer = 'Hogger' } } } }
    ns.Nav.Open('journal')
    local journal = ns.Nav.views.journal
    local jw = journal.window
    journal.SetMode('levels')
    eq(journal.total, 1)
    local level = cellsOf(jw, 1)
    eq(level[1], '10'); eq(level[3], 'at least 1h 01m'); eq(level[4], '100')
    journal.SetMode('deaths')
    local death = cellsOf(jw, 1)
    eq(death[2], 'Elwynn Forest'); eq(death[3], '10.0, 20.0'); eq(death[5], 'Open world'); eq(death[6], 'Hogger')
    jw.search:SetText('hogger'); jw.search.scripts.OnTextChanged(jw.search, true)
    eq(journal.total, 1)
    jw.search.scripts.OnEscapePressed(jw.search)
    journal.SetMode('reputation')
    eq(journal.total, 0); eq(strip(jw.empty:GetText()), 'No reputation change recorded yet.')
end)

test('a window larger than the screen is scaled down to fit, tabs included; on a large screen it keeps its size', function()
    local ns = newNs()
    installFrames()
    loadViews(ns)
    local scaled
    local window = { SetScale = function(_, v) scaled = v end, GetScale = function() return scaled or 1 end }
    _G.UIParent.GetWidth = function() return 1920 end
    _G.UIParent.GetHeight = function() return 1080 end
    ns.Nav.FitToScreen(window)
    eq(scaled, nil)
    _G.UIParent.GetWidth = function() return 800 end
    _G.UIParent.GetHeight = function() return 600 end
    ns.Nav.FitToScreen(window)
    assert(scaled < 1 and scaled * ns.Nav.WIDTH <= 800 - 8 + 1e-6)
    assert(scaled * (ns.Nav.HEIGHT + ns.Nav.TAB_DEPTH) <= 600 - 8 + 1e-6)
end)

test('a quest pin is the silver question mark with a drop shadow; a reused pin hides the shadow', function()
    local ns = newNs()
    installFrames()
    loadViews(ns)
    assert(loadfile('TitanGatheredForever/PinStyle.lua'))('TitanGatheredForever', ns)
    local function region()
        local r = { shown = false }
        function r:SetTexture(t) self.file = t end
        function r:SetVertexColor(...) self.color = { ... } end
        function r:ClearAllPoints() end
        function r:SetPoint() end
        function r:Show() self.shown = true end
        function r:Hide() self.shown = false end
        return r
    end
    local pin = { texture = region() }
    function pin:CreateTexture() return region() end
    ns.PinStyle.Badge(pin, 'QuestGiver')
    local shadow = pin.tgfShadow
    eq(shadow.shown, true); assert(shadow.file:find('IncompleteQuestIcon', 1, true)); eq(shadow.color[1], 0)
    ns.PinStyle.Badge(pin, 'Trainer')
    eq(shadow.shown, false)
end)

local failed = 0
for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if ok then print('PASS ' .. entry[1]) else failed = failed + 1; print('FAIL ' .. entry[1] .. ': ' .. tostring(err)) end
end
if failed > 0 then os.exit(1) end
