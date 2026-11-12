local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function near(a, b) assert(math.abs(a - b) < 0.0001, tostring(a) .. ' != ' .. tostring(b)) end

CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
local player = { mapID = 1429, x = 0.1, y = 0.2 }
C_Map = {
    GetMapPosFromWorldPos = function(_, vector, mapID)
        if mapID == 9999 then return mapID, nil end
        return mapID or 1429, CreateVector2D(vector.x / 100, vector.y / 100)
    end,
    GetMapInfo = function(id) return { name = 'Zone ' .. id } end,
    GetMapRectOnMap = function() return nil end,
    GetBestMapForUnit = function() return player.mapID end,
    GetPlayerMapPosition = function() return CreateVector2D(player.x, player.y) end,
}

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1',
        settings = { mapNpcProfessions = {} }, db = { npcs = {} },
        Style = { gold = 'gold', gray = 'gray', white = 'white', green = 'green', red = 'red',
            Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end,
            Separator = function(tooltip) tooltip:AddLine('---') end,
            Small = function(tooltip) tooltip.smallLines = (tooltip.smallLines or 0) + 1 end },
        ItemName = function(id) return 'Recipe: Item' .. id end }
    ns.NpcSeed = { npcs = {
        [1] = { n = 'Alchemy Trainer', m = 0, x = 10, y = 20, p = 'Alchemy',
            t = { { 2259, 'Elixir of Minor Defense', 100, 1, 0 }, { 3101, 'Lesser Healing Potion', 500, 50, 0 } } },
        [2] = { n = 'Recipe Vendor', m = 0, x = 11, y = 21,
            v = { { 100, 'Alchemy', 12000, 225 }, { 101, 'Cooking', 0, 0 } } },
    } }
    assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('seed only record is unconfirmed and unknown values stay unknown', function()
    local ns = fresh()
    local trainer = ns.NpcSources.Record(1)
    eq(trainer.confirmed, false); eq(trainer.profession, 'Alchemy'); eq(#trainer.trainer, 2)
    eq(trainer.trainer[1].skill, 1); eq(trainer.trainer[1].cost, 100)
    local vendor = ns.NpcSources.Record(2)
    eq(vendor.vendor[1].price, 12000); eq(vendor.vendor[1].skill, 225)
    eq(vendor.vendor[2].price, nil); eq(vendor.vendor[2].skill, nil)
    eq(ns.NpcSources.Record(99), nil)
end)

test('observed data overrides seed data', function()
    local ns = fresh()
    ns.db.npcs[1] = { name = 'Seen Trainer', profession = 'Alchemy', mapID = 1429, x = 0.5, y = 0.6, lastSeen = 7,
        trainer = { { name = 'Elixir of Minor Defense', skill = 1, cost = 90 } } }
    local record = ns.NpcSources.Record(1)
    eq(record.confirmed, true); eq(record.name, 'Seen Trainer'); eq(#record.trainer, 1); eq(record.trainer[1].cost, 90)
    eq(ns.NpcSources.Record(2).confirmed, false)
end)

test('observed vendor stock replaces seed stock completely', function()
    local ns = fresh()
    ns.db.npcs[2] = { name = 'Recipe Vendor', mapID = 1429, x = 0.2, y = 0.3, lastSeen = 1,
        vendor = { { itemID = 100, kind = 'Alchemy', price = 11000, skill = 225 } } }
    local record = ns.NpcSources.Record(2)
    eq(#record.vendor, 1); eq(record.vendor[1].price, 11000); eq(record.vendor[1].observed, true)
end)

test('seed npcs are placed through world coordinates', function()
    local ns = fresh()
    local nodes = ns.NpcSources.Nodes(1429)
    eq(#nodes, 2)
    eq(nodes[1].kind, 'Trainer'); near(nodes[1].x, 0.1); near(nodes[1].y, 0.2)
    eq(nodes[2].kind, 'RecipeVendor'); eq(nodes[2].professions.Alchemy, true); eq(nodes[2].professions.Cooking, true)
end)

test('observed position wins and is used only on its own map', function()
    local ns = fresh()
    ns.db.npcs[1] = { name = 'T', profession = 'Alchemy', mapID = 1429, x = 0.5, y = 0.6, lastSeen = 1, trainer = {} }
    near(ns.NpcSources.Nodes(1429)[1].x, 0.5)
    for _, node in ipairs(ns.NpcSources.Nodes(1430)) do assert(node.npcID ~= 1, 'observed npc leaked to another map') end
end)

test('axis swap exchanges world coordinates', function()
    local ns = fresh()
    ns.settings.npcAxisSwap = true
    near(ns.NpcSources.Nodes(1429)[1].x, 0.2); near(ns.NpcSources.Nodes(1429)[1].y, 0.1)
end)

test('unsupported continents and failed conversions are skipped', function()
    local ns = fresh()
    ns.NpcSeed.npcs[3] = { n = 'Far', m = 489, x = 1, y = 1, p = 'Cooking', t = {} }
    eq(#ns.NpcSources.Nodes(1429), 2)
    eq(#ns.NpcSources.Nodes(9999), 0)
end)

test('toggles and profession filter control visibility', function()
    local ns = fresh()
    local nodes = ns.NpcSources.Nodes(1429)
    eq(#ns.NpcSources.List(1429), 2)
    ns.settings.mapTrainers = false
    eq(#ns.NpcSources.List(1429), 1)
    ns.settings.mapTrainers = true; ns.settings.mapRecipeVendors = false
    eq(#ns.NpcSources.List(1429), 1); eq(ns.NpcSources.List(1429)[1].kind, 'Trainer')
    ns.settings.mapRecipeVendors = true; ns.settings.mapNpcProfessions.Alchemy = false
    local visible = ns.NpcSources.List(1429)
    eq(#visible, 1); eq(visible[1].kind, 'RecipeVendor')   -- vendor still sells a Cooking recipe
    ns.settings.mapNpcProfessions.Cooking = false
    eq(#ns.NpcSources.List(1429), 0)
    assert(nodes[1] ~= nil)
end)

local GOLD = '|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t'
local SILVER = '|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t'
local COPPER = '|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t'

test('coin icons follow the classic gold silver copper format', function()
    local ns = fresh()
    eq(ns.NpcSources.CoinIcons(12000), '1' .. GOLD .. ' 20' .. SILVER)
    eq(ns.NpcSources.CoinIcons(10101), '1' .. GOLD .. ' 1' .. SILVER .. ' 1' .. COPPER)
    eq(ns.NpcSources.CoinIcons(5), '5' .. COPPER)
    eq(ns.NpcSources.CoinIcons(0), '0' .. COPPER)
    eq(ns.NpcSources.CoinIcons(500), '5' .. SILVER)
end)

test('coin text', function()
    local ns = fresh()
    eq(ns.NpcSources.Coin(12000), '1g 20s'); eq(ns.NpcSources.Coin(0), '0c')
    eq(ns.NpcSources.Coin(5), '5c'); eq(ns.NpcSources.Coin(10101), '1g 1s 1c')
end)

local function tip()
    local t = { lines = {}, doubles = {} }
    function t:AddLine(text) self.lines[#self.lines + 1] = text end
    function t:AddDoubleLine(left, right) self.doubles[#self.doubles + 1] = { left, right } end
    return t
end

test('vendor tooltip lists recipes with skill and price and marks unconfirmed data', function()
    local ns = fresh()
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 2 })
    eq(t.lines[1], '<gold>Recipe Vendor</>')           -- vendor name
    eq(t.lines[2], '<gray>Recipe vendor</>')            -- additional information
    eq(t.lines[3], '<gray>Not yet confirmed in game</>')
    eq(t.lines[4], '---')                               -- separator between the header and the list
    eq(t.doubles[1][1], '<white>Recipe: Item100</> <gray>(225)</>')   -- list entry, skill in brackets after the name
    eq(t.doubles[1][2], '1' .. GOLD .. ' 20' .. SILVER)               -- right side: price only
    eq(t.doubles[2][1], '<white>Recipe: Item101</> <gray>(?)</>')
    eq(t.doubles[2][2], '<gray>price unknown</>')
    eq(#t.lines, 4)
    eq(t.smallLines, 4)   -- role, status and the two list rows are small; the NPC name and the rule are not
end)

test('trainer tooltip shows profession, skill and cost', function()
    local ns = fresh()
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 1 })
    eq(t.lines[2], '<gray>Alchemy trainer</>')
    eq(t.doubles[1][1], '<white>Elixir of Minor Defense</> <gray>(1)</>'); eq(t.doubles[1][2], '1' .. SILVER)
end)

test('tooltip is capped at fifteen recipes and marks known ones', function()
    local ns = fresh()
    local rows = {}
    for id = 1, 20 do rows[id] = { 200 + id, 'Alchemy', 100, id } end
    ns.NpcSeed.npcs[5] = { n = 'Big', m = 0, x = 1, y = 1, v = rows }
    ns.KnownRecipes = { IsKnown = function(_, _, name) return name == 'Recipe: Item201' end }
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 5 })
    eq(#t.doubles, 15); eq(t.doubles[1][1], '<gray>Recipe: Item201</> <gray>(1)</> <green>learned</>')
    eq(t.doubles[2][1], '<white>Recipe: Item202</> <gray>(2)</>')
    eq(t.lines[#t.lines], '<gray>and 5 more</>')
end)

test('recipes of a profession that was never read say the learned status is unknown', function()
    local ns = fresh()
    ns.KnownRecipes = { IsKnown = function(_, kind, name)
        if kind == 'Alchemy' then return name == 'Recipe: Item100' end
        return nil
    end }
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 2 })
    eq(t.doubles[1][1], '<gray>Recipe: Item100</> <gray>(225)</> <green>learned</>')
    eq(t.doubles[2][1], '<white>Recipe: Item101</> <gray>(?)</>')
    assert(t.lines[#t.lines]:find('(Cooking)', 1, true) and not t.lines[#t.lines]:find('Alchemy', 1, true))   -- only Cooking was never read
    ns.KnownRecipes = { IsKnown = function() return nil end }
    t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 2 })
    assert(t.lines[#t.lines]:find('Learned status unknown', 1, true) and t.lines[#t.lines]:find('Alchemy', 1, true))
end)

test('rank spells are known by the skill cap and never ask for a profession window', function()
    local ns = fresh()
    ns.NpcSeed.npcs[9] = { n = 'Angler', m = 0, x = 1, y = 1, p = 'Fishing',
        t = { { 7733, 'Apprentice Fishing', 100, 1, 0 }, { 7734, 'Journeyman Fishing', 500, 50, 0 }, { 7620, 'Expert Fishing', 5000, 125, 0 } } }
    ns.KnownRecipes = { IsKnown = function() return nil end }
    ns.Professions = { Rows = function() return { { kind = 'Fishing', rank = 80, maxRank = 150 } } end }
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 9 })
    eq(t.doubles[1][1], '<gray>Apprentice Fishing</> <gray>(1)</> <green>learned</>')
    eq(t.doubles[2][1], '<gray>Journeyman Fishing</> <gray>(50)</> <green>learned</>')
    eq(t.doubles[3][1], '<white>Expert Fishing</> <red>(125)</>')   -- skill 80 is below 125
    eq(#t.lines, 4)
    ns.Professions = { Rows = function() return {} end }
    t = tip(); ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 9 })
    eq(t.doubles[1][1], '<white>Apprentice Fishing</> <red>(1)</>')
end)

test('the window lists the next profession rank where it can be learned', function()
    local ns = fresh()
    ns.NpcSeed.npcs[9] = { n = 'Angler', m = 0, x = 1, y = 1, p = 'Fishing',
        t = { { 7733, 'Apprentice Fishing', 100, 1, 0 }, { 7734, 'Journeyman Fishing', 500, 50, 0 }, { 7620, 'Expert Fishing', 5000, 125, 0 } } }
    ns.NpcSeed.npcs[10] = { n = 'Other Angler', m = 0, x = 1, y = 1, p = 'Fishing',
        t = { { 7734, 'Journeyman Fishing', 400, 50, 0 } } }
    ns.KnownRecipes = { IsKnown = function() return false end, Normalize = function(n) return n:lower() end,
        Strip = function(n) return n end }
    local function rankRows(maxRank, rank)
        ns.Professions = { Rows = function() return { { kind = 'Fishing', rank = rank, maxRank = maxRank } } end }
        local rows = ns.NpcSources.Unlearned('C1', false, 'Fishing')
        return rows
    end
    local rows = rankRows(75, 75)               -- maximum reached: next is Journeyman, two trainers teach it
    eq(#rows, 1); eq(rows[1].name, 'Journeyman Fishing'); eq(rows[1].kind, 'Fishing'); eq(rows[1].trainer, true)
    eq(#rows[1].sources, 2); eq(rows[1].price, 400); eq(rows[1].skill, 50); eq(rows[1].canLearn, true)
    eq(#rankRows(150, 80), 0)                    -- Journeyman known, Expert needs 125, the player has 80
    eq(#rankRows(150, 130), 1); eq(rankRows(150, 130)[1].name, 'Expert Fishing')
    eq(#rankRows(75, 30), 0)                     -- Journeyman needs 50 and the player has 30
    ns.Professions = { Rows = function() return {} end }
    eq(#ns.NpcSources.Unlearned('C1', false, 'Fishing'), 0)   -- the player has no Fishing at all
    ns.Professions = { Rows = function() return { { kind = 'Fishing', rank = 75, maxRank = 75 } } end }
    eq(#ns.NpcSources.Unlearned('C1', true, 'Fishing'), 0)    -- trainer only rows are hidden by the vendor filter
end)

test('a required skill above the player rank is red and unknown requirements stay neutral', function()
    local ns = fresh()
    ns.Professions = { Rows = function() return { { kind = 'Alchemy', rank = 60 } } end }
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 2 })
    eq(t.doubles[1][1], '<white>Recipe: Item100</> <red>(225)</>')   -- needs 225, the player has 60
    eq(t.doubles[2][1], '<white>Recipe: Item101</> <gray>(?)</>')
    t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 1 })
    eq(t.doubles[1][1], '<white>Elixir of Minor Defense</> <gray>(1)</>')
    eq(t.doubles[2][1], '<white>Lesser Healing Potion</> <gray>(50)</>')   -- 60 is enough for 50
    ns.Professions = { Rows = function() return {} end }                   -- the player has no profession at all
    t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 1 })
    eq(t.doubles[1][1], '<white>Elixir of Minor Defense</> <red>(1)</>')
end)

test('skills come from the player professions and unknown evidence stays unknown', function()
    local ns = fresh()
    eq(ns.NpcSources.Skills(), nil)                                         -- no way to read professions
    eq(ns.NpcSources.CanLearn(nil, 'Alchemy', 50), nil)
    ns.Professions = { Rows = function() return { { kind = 'Alchemy', rank = 60 }, { kind = 'Cooking', rank = 5 } } end }
    local skills = ns.NpcSources.Skills()
    eq(skills.Alchemy, 60); eq(skills.Cooking, 5)
    eq(ns.NpcSources.CanLearn(skills, 'Alchemy', 60), true); eq(ns.NpcSources.CanLearn(skills, 'Alchemy', 61), false)
    eq(ns.NpcSources.CanLearn(skills, 'Tailoring', 1), false)                -- profession not learned
    eq(ns.NpcSources.CanLearn(skills, 'Alchemy', nil), nil)                  -- requirement unknown
    ns.Professions = { Rows = function() error('client unavailable') end }
    eq(ns.NpcSources.Skills(), nil)
end)

test('confirmed data is green, extra costs are noted and an empty list says so', function()
    local ns = fresh()
    ns.db.npcs[2] = { name = 'Seen Vendor', mapID = 1429, x = 0.2, y = 0.3, lastSeen = 1,
        vendor = { { itemID = 100, kind = 'Alchemy', price = 500, skill = 225, extendedCost = true } } }
    local t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'RecipeVendor', npcID = 2 })
    eq(t.lines[1], '<gold>Seen Vendor</>'); eq(t.lines[3], '<green>Confirmed in game</>')
    eq(t.doubles[1][2], '5' .. SILVER .. ' <gray>+ extra cost</>')
    ns.db.npcs[1] = { name = 'Empty Trainer', profession = 'Alchemy', mapID = 1429, x = 0.5, y = 0.6, lastSeen = 1, trainer = {} }
    t = tip()
    ns.NpcSources.FillTooltip(t, { kind = 'Trainer', npcID = 1 })
    eq(t.lines[#t.lines], '<gray>No recipes recorded yet.</>')
end)

test('location gives the zone and coordinates, observed first, seed through world coordinates', function()
    local ns = fresh()
    local seedLocation = ns.NpcSources.Location(1)
    eq(seedLocation.zone, 'Zone 1429'); near(seedLocation.x, 10); near(seedLocation.y, 20); eq(seedLocation.confirmed, false)
    ns.db.npcs[1] = { name = 'T', profession = 'Alchemy', mapID = 1455, x = 0.684, y = 0.545, lastSeen = 1, trainer = {} }
    local seen = ns.NpcSources.Location(1)
    eq(seen.zone, 'Zone 1455'); near(seen.x, 68.4); near(seen.y, 54.5); eq(seen.confirmed, true)
    eq(ns.NpcSources.Location(99), nil)
    ns.settings.npcAxisSwap = true
    ns.db.npcs[1] = nil
    near(ns.NpcSources.Location(1).x, 20)
end)

test('sources tooltip lists every source with colored names, location and price', function()
    local ns = fresh()
    local t = tip()
    local row = { name = 'Lesser Healing Potion', kind = 'Alchemy', trainer = true, sources = {
        { npcID = 1, name = 'Alchemy Trainer', role = 'Trainer', price = 500 },
        { npcID = 2, name = 'Recipe Vendor', role = 'Vendor', price = nil } } }
    ns.NpcSources.FillSourcesTooltip(t, row)
    eq(t.lines[1], '<white>Lesser Healing Potion</>')
    eq(t.doubles[1][1], '<green>Alchemy Trainer</> <gray>(Trainer)</>'); eq(t.doubles[1][2], '5' .. SILVER)
    eq(t.lines[2], '<gray>Zone 1429 10.0, 20.0, not yet confirmed in game</>')
    eq(t.doubles[2][1], '<green>Recipe Vendor</> <gray>(Vendor)</>'); eq(t.doubles[2][2], '<gray>price unknown</>')
    eq(t.lines[#t.lines], '<gray>Click the row to open the map and mark the NPCs; click again to clear the mark.</>')
    eq(t.smallLines, 5)
end)

local clock = 100
GetTime = function() return clock end

test('a highlighted npc is remembered for a while and overrides the visibility filters', function()
    local ns = fresh()
    clock = 100
    eq(ns.NpcSources.IsHighlighted(1), false); eq(ns.NpcSources.HasHighlight(), false)
    ns.settings.mapTrainers = false; ns.settings.mapRecipeVendors = false
    eq(ns.NpcSources.Enabled(), false); eq(#ns.NpcSources.List(1429), 0)
    ns.NpcSources.SetHighlight({ 1 })
    eq(ns.NpcSources.IsHighlighted(1), true); eq(ns.NpcSources.IsHighlighted(2), false)
    eq(ns.NpcSources.Enabled(), true)                      -- the pin must be drawn although the toggles are off
    local list = ns.NpcSources.List(1429)
    eq(#list, 1); eq(list[1].npcID, 1)
    ns.settings.mapNpcProfessions.Alchemy = false          -- a hidden profession cannot hide it either
    eq(#ns.NpcSources.List(1429), 1)
    clock = 100 + 299; eq(ns.NpcSources.IsHighlighted(1), true)
    clock = 100 + 301; eq(ns.NpcSources.IsHighlighted(1), false); eq(ns.NpcSources.HasHighlight(), false)
    eq(#ns.NpcSources.List(1429), 0)
    clock = 100
end)

test('setting a new highlight replaces the old one and an empty list clears it', function()
    local ns = fresh()
    clock = 100
    ns.NpcSources.SetHighlight({ 1, 2 })
    eq(ns.NpcSources.IsHighlighted(1), true); eq(ns.NpcSources.IsHighlighted(2), true)
    ns.NpcSources.SetHighlight({ 2 })
    eq(ns.NpcSources.IsHighlighted(1), false); eq(ns.NpcSources.IsHighlighted(2), true)
    ns.NpcSources.SetHighlight(nil)
    eq(ns.NpcSources.HasHighlight(), false)
    ns.NpcSources.SetHighlight({ 1 }); ns.NpcSources.SetHighlight({})
    eq(ns.NpcSources.HasHighlight(), false)
end)

test('a highlight expiry redraws the pins once', function()
    local ns = fresh()
    clock = 100
    local timers, redraws = {}, 0
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay, fn } end }
    ns.Map = { Update = function() redraws = redraws + 1 end }
    ns.Minimap = { Update = function() redraws = redraws + 1 end }
    ns.NpcSources.SetHighlight({ 1 })
    eq(#timers, 1); eq(timers[1][1], 301)
    clock = 100 + 301
    timers[1][2](); eq(redraws, 2)
    C_Timer = nil
    clock = 100
end)

test('nearest reports the closest visible pin to the player', function()
    local ns = fresh()
    player.mapID, player.x, player.y = 1429, 0.1, 0.2
    local node, distance = ns.NpcSources.Nearest()
    eq(node.npcID, 1); assert(distance < 0.001)
end)

test('settings defaults preserve explicit choices', function()
    local ns = {}
    assert(loadfile('TitanGatheredForeverV3/Settings.lua'))('TitanGatheredForeverV3', ns)
    local saved, settings = ns.Settings.Initialize({ schema = 1, settings = { mapTrainers = false } })
    eq(settings.mapTrainers, false); eq(settings.mapRecipeVendors, true); eq(settings.recordNpcs, true)
    eq(settings.npcAxisSwap, false); eq(type(settings.mapNpcProfessions), 'table')
    eq(type(saved.npcs), 'table'); eq(type(saved.knownRecipes), 'table')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS npc sources ' .. #tests .. ' checks')
