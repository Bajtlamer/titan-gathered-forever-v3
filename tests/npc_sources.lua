local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function near(a, b) assert(math.abs(a - b) < 0.0001, tostring(a) .. ' != ' .. tostring(b)) end

CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
local player = { mapID = 1429, x = 0.1, y = 0.2 }
C_Map = {
    GetMapPosFromWorldPos = function(_, vector, mapID)
        if mapID == 9999 then return mapID, nil end
        return mapID, CreateVector2D(vector.x / 100, vector.y / 100)
    end,
    GetMapRectOnMap = function() return nil end,
    GetBestMapForUnit = function() return player.mapID end,
    GetPlayerMapPosition = function() return CreateVector2D(player.x, player.y) end,
}

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1',
        settings = { mapNpcProfessions = {} }, db = { npcs = {} },
        Style = { gold = 'gold', gray = 'gray', white = 'white', green = 'green',
            Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end,
            Separator = function(tooltip) tooltip:AddLine('---') end },
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
    eq(#t.doubles, 15); eq(t.doubles[1][1], '<white>Recipe: Item201</> <gray>(1)</> <green>(known)</>')
    eq(t.doubles[2][1], '<white>Recipe: Item202</> <gray>(2)</>')
    eq(t.lines[#t.lines], '<gray>and 5 more</>')
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
