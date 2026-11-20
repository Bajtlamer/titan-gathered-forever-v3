-- Titan Gathered Forever: Discovery, milestone 6: the scans that only a /tgfd command starts (recipes and maps).
local FOLDER = 'TitanGatheredForever_Discovery'
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function has(text, part) assert(tostring(text):find(part, 1, true), 'missing "' .. part .. '" in: ' .. tostring(text)) end

local function readAll(path)
    local file = assert(io.open(path, 'r')); local text = file:read('*a'); file:close(); return text
end
local function manifestFiles()
    local files = {}
    for line in readAll(FOLDER .. '/' .. FOLDER .. '.toc'):gmatch('[^\r\n]+') do
        if line:match('%.lua$') then files[#files + 1] = (line:gsub('\\', '/')) end
    end
    return files
end
local styleStub = dofile('tests/style_stub.lua')

local function fakeCore()
    local core = { Style = {} }
    styleStub(core.Style)
    core.Items = {}
    core.Recipes = { [2657] = { profession = 'Mining' }, [3292] = { profession = 'Blacksmithing' }, [7000] = { profession = 'FirstAid' } }
    core.Catalog = { Get = function(id) return core.Items[id] end, Modules = function() return {} end }
    core.NpcSeed = { npcs = {} }
    core.DataMetadata = { targetBuild = '70790' }
    return core
end

local recipeTable = {
    [2657] = { recipeID = 2657, name = 'Smelt Copper', profession = 'Mining', professionID = 186, outputItemID = 2840, quantityMin = 1, quantityMax = 1,
        reagents = { { quantity = 1, items = { 2770 } } } },
    [9999] = { recipeID = 9999, name = 'Scribe Something', profession = 'Inscription', professionID = 773, parentProfessionID = 773,
        reagents = {} },
}

local function fakeApi(over)
    local api = {
        Now = function() return 1000 end,
        Build = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end,
        Locale = function() return 'enUS' end,
        Zone = function() return {} end, Position = function() return nil end, Unit = function() return nil end,
        Loot = function() return {} end, Merchant = function() return {} end, Trainer = function() return {} end,
        CanRepair = function() return false end, Quest = function() return nil end, QuestChoices = function() return {} end,
        Skills = function() return {} end,
        RecipeIDs = function() return { 2657, 9999, 12345 } end,
        Recipe = function(id) return recipeTable[id] end,
        Map = function(id)
            if id == 1 then return { id = 1, name = 'Kalimdor', mapType = 2, parentMapID = 0 } end
            if id == 5 then return { id = 5, name = 'Mount Hyjal', mapType = 3, parentMapID = 1 } end
            return nil
        end,
    }
    for key, value in pairs(over or {}) do api[key] = value end
    return api
end

local function load(over)
    _G.TitanGatheredForeverV3 = fakeCore()
    styleStub(_G.TitanGatheredForeverV3.Style)
    local ns = { printed = {} }
    for _, file in ipairs(manifestFiles()) do
        if file ~= 'Start.lua' then assert(loadfile(FOLDER .. '/' .. file))(FOLDER, ns) end
    end
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.api = fakeApi(over)
    ns.env = { now = function() return 5000 end, build = ns.api.Build, date = function() return 'D' end,
        coreVersion = function() return '0.5.108' end, moduleVersion = '0.1.0',
        clock = function() return 0 end, inCombat = function() return false end }
    ns.db = ns.Database.Init(nil, '0.1.0', 1000)
    ns.runtime = {}
    ns.state.build = '70862'
    ns.frame = { RegisterEvent = function() end, UnregisterEvent = function() end }
    return ns
end

local function accepted(over)
    local ns = load(over)
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.printed = {}
    return ns
end

local function plain(text) return (tostring(text):gsub('|cgold', ''):gsub('|cwhite', ''):gsub('|cgreen', ''):gsub('|r', '')) end
local function printed(ns)
    local lines = {}
    for _, line in ipairs(ns.printed) do lines[#lines + 1] = plain(line) end
    return table.concat(lines, '\n')
end
local function runAll(ns)
    local guard = 0
    while ns.Runner.Active() do ns.Runner.Tick(); guard = guard + 1; assert(guard < 1000, 'operation never ended') end
end

test('recipes and maps are categories with labels, and the notice mentions the scans', function()
    local ns = load()
    local found = {}
    for _, category in ipairs(ns.Database.CATEGORIES) do found[category] = true end
    assert(found.recipes and found.maps)
    eq(ns.Compare.LABELS.recipes, 'Recipes'); eq(ns.Compare.LABELS.maps, 'Maps')
    eq(type(ns.db.data.recipes), 'table'); eq(type(ns.db.data.maps), 'table')
    has(table.concat(ns.Consent.Notice(), '\n'), '/tgfd scan')
end)

test('the recipe scan reads every listed recipe with its reagents and keeps unknown professions as they are', function()
    local ns = accepted()
    local spec, reason = ns.Scans.RecipeSpec()
    assert(spec, tostring(reason))
    eq(spec.name, 'Recipe scan')
    eq(ns.Runner.Start(spec), true); runAll(ns)
    local record = ns.db.data.recipes[2657]
    eq(record.name, 'Smelt Copper'); eq(record.profession, 'Mining'); eq(record.professionID, 186)
    eq(record.outputItemID, 2840); eq(record.quantityMin, 1); eq(record.quantityMax, 1)
    eq(record.reagents[1].quantity, 1); eq(record.reagents[1].items[1], 2770); eq(record.seen, 1)
    local other = ns.db.data.recipes[9999]
    eq(other.profession, 'Inscription'); eq(other.professionID, 773)
    eq(ns.db.data.recipes[12345], nil)             -- the client gave nothing for this one
    local text = printed(ns)
    has(text, 'Recorded 2 recipes'); has(text, '1 skipped'); has(text, 'Inscription'); has(text, 'Mining')
end)

test('a second recipe scan counts the recipes again instead of duplicating them', function()
    local ns = accepted()
    ns.Runner.Start(ns.Scans.RecipeSpec()); runAll(ns)
    ns.Runner.Start(ns.Scans.RecipeSpec()); runAll(ns)
    eq(ns.db.data.recipes[2657].seen, 2)
    eq(ns.Database.CategoryCount(ns.db, 'recipes'), 2)
end)

test('without an open profession window there is nothing to scan and the module does not open one', function()
    local ns = accepted({ RecipeIDs = function() return nil end })
    local spec, reason = ns.Scans.RecipeSpec()
    eq(spec, nil); eq(reason, 'nowindow')
    ns.Commands.Handle('scan recipes')
    has(printed(ns), 'profession window'); eq(ns.Runner.Active(), false)
end)

test('the map scan reads the map IDs in a range and records the ones the client knows', function()
    local ns = accepted()
    local spec = ns.Scans.AreaSpec(10)
    eq(spec.name, 'Map scan')
    eq(ns.Runner.Start(spec), true); runAll(ns)
    local hyjal = ns.db.data.maps[5]
    eq(hyjal.name, 'Mount Hyjal'); eq(hyjal.mapType, 3); eq(hyjal.parentMapID, 1); eq(hyjal.seen, 1)
    eq(ns.db.data.maps[1].name, 'Kalimdor')
    eq(ns.Database.CategoryCount(ns.db, 'maps'), 2)
    has(printed(ns), 'Recorded 2 maps'); has(printed(ns), '2 new')
    ns.Runner.Start(ns.Scans.AreaSpec(10)); runAll(ns)
    eq(ns.db.data.maps[5].seen, 2); has(printed(ns), '0 new')
end)

test('the map scan range has a default and sane limits', function()
    local ns = accepted()
    eq(ns.Scans.AreaSpec().phases[1].total(), ns.Scans.DEFAULT_MAPS)
    eq(ns.Scans.AreaSpec(0).phases[1].total(), 1)
    eq(ns.Scans.AreaSpec(10 ^ 9).phases[1].total(), ns.Scans.MAX_MAPS)
    eq(ns.Scans.AreaSpec('abc').phases[1].total(), ns.Scans.DEFAULT_MAPS)
end)

test('scan commands need the notice accepted, name their targets and explain a busy runner', function()
    local ns = load()
    ns.Commands.Handle('scan areas')
    has(printed(ns), 'accept'); eq(ns.Runner.Active(), false)
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.printed = {}
    ns.Commands.Handle('scan')
    has(printed(ns), '/tgfd scan recipes'); has(printed(ns), '/tgfd scan areas')
    ns.printed = {}
    ns.Commands.Handle('scan nonsense')
    has(printed(ns), 'Unknown scan')
    ns.printed = {}
    ns.Commands.Handle('scan areas 20')
    eq(ns.Runner.Active(), true); eq(ns.Runner.Progress().total, 20)
    ns.printed = {}
    ns.Commands.Handle('scan recipes')
    has(printed(ns), 'already running')
    ns.Runner.Cancel('test')
end)

test('a paused module does not scan', function()
    local ns = accepted()
    ns.Consent.Stop(ns.db, ns.runtime)
    ns.Commands.Handle('scan areas')
    has(printed(ns), '/tgfd start'); eq(ns.Runner.Active(), false)
end)

test('the help lists both scans', function()
    local ns = accepted()
    ns.Commands.Handle('help')
    has(printed(ns), '/tgfd scan recipes'); has(printed(ns), '/tgfd scan areas')
end)

test('a recipe is new outside the installed catalogue, different when the profession differs, otherwise unchanged', function()
    local ns = accepted()
    local baseline = assert(ns.Baseline.FromCore())
    eq(ns.Compare.Classify('recipes', 2657, { name = 'Smelt Copper', profession = 'Mining' }, baseline).state, 'unchanged')
    eq(ns.Compare.Classify('recipes', 7000, { name = 'Bandage', profession = 'First Aid' }, baseline).state, 'unchanged')
    local new = ns.Compare.Classify('recipes', 9999, { name = 'Scribe', profession = 'Inscription' }, baseline)
    eq(new.state, 'new'); has(new.why, 'catalogue')
    local different = ns.Compare.Classify('recipes', 3292, { name = 'X', profession = 'Engineering' }, baseline)
    eq(different.state, 'different'); eq(different.details[1].field, 'profession')
    eq(different.details[1].baseline, 'Blacksmithing'); eq(different.details[1].observed, 'Engineering')
    eq(ns.Compare.Classify('recipes', 2657, { name = 'Smelt Copper' }, baseline).state, 'unchanged')   -- profession unknown
    eq(ns.Compare.Classify('maps', 5, { name = 'Mount Hyjal' }, baseline).state, 'unbaselined')
end)

test('a profession difference reads well in the detail text', function()
    local ns = accepted()
    local text = plain(table.concat(ns.View.DetailText({ why = 'x', details = { { field = 'profession', baseline = 'Blacksmithing', observed = 'Engineering' } } }), '\n'))
    has(text, 'Profession'); has(text, 'Blacksmithing'); has(text, 'Engineering')
end)

test('the real client adapter reads recipes, schematics and maps in the shape the core relies on', function()
    _G.issecretvalue = function() return false end
    _G.C_TradeSkillUI = {
        GetAllRecipeIDs = function() return { 2657, 9999 } end,
        GetRecipeInfo = function(id) return { recipeID = id, name = id == 2657 and 'Smelt Copper' or 'Scribe', learned = false } end,
        GetProfessionInfoByRecipeID = function(id)
            if id == 2657 then return { professionID = 186, parentProfessionID = 186 } end
            return { professionID = 773, parentProfessionID = 773, professionName = 'Inscription' }
        end,
        GetRecipeSchematic = function(id)
            return { recipeID = id, outputItemID = 2840, quantityMin = 1, quantityMax = 2, reagentSlotSchematics = {
                { reagentType = 1, quantityRequired = 2, slotIndex = 1, reagents = { { itemID = 2770 }, { itemID = 2771 } } },
                { reagentType = 0, quantityRequired = 1, slotIndex = 2, reagents = { { itemID = 99 } } } } }
        end,
    }
    _G.C_Map = { GetMapInfo = function(id) if id == 5 then return { mapID = 5, name = 'Mount Hyjal', mapType = 3, parentMapID = 1 } end end }
    local ns = load()
    local api = ns.Api.Default()
    local ids = api.RecipeIDs()
    eq(#ids, 2); eq(ids[1], 2657)
    local copper = api.Recipe(2657)
    eq(copper.name, 'Smelt Copper'); eq(copper.profession, 'Mining'); eq(copper.professionID, 186)
    eq(copper.outputItemID, 2840); eq(copper.quantityMax, 2)
    eq(#copper.reagents, 1); eq(copper.reagents[1].quantity, 2); eq(copper.reagents[1].items[2], 2771)
    local unknown = api.Recipe(9999)
    eq(unknown.profession, 'Inscription'); eq(unknown.professionID, 773)
    local map = api.Map(5)
    eq(map.id, 5); eq(map.name, 'Mount Hyjal'); eq(map.mapType, 3); eq(map.parentMapID, 1)
    eq(api.Map(6), nil)
    _G.C_TradeSkillUI.GetAllRecipeIDs = function() return {} end
    eq(api.RecipeIDs(), nil)
    _G.C_TradeSkillUI.GetRecipeInfo = function() error('boom') end
    eq(api.Recipe(2657), nil)
    _G.C_TradeSkillUI, _G.C_Map = nil, nil
    eq(api.RecipeIDs(), nil); eq(api.Map(5), nil)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS discovery scans ' .. #tests .. ' checks')
