-- Titan Gathered Forever: Discovery, milestone 4: the comparison of observations with the baseline.
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

-- A small stand-in for the core: a catalogue with two items, a seed with a trainer and a vendor.
local function fakeCore()
    local core = { Style = {} }
    styleStub(core.Style)
    core.Items = { [765] = { professions = { 'Herbs' } }, [2770] = { professions = { 'Mining' } }, [4603] = { professions = { 'Cooking' } } }
    core.Catalog = { Get = function(id) return core.Items[id] end, Modules = function() return { { id = 'Herbalism' }, { id = 'Mining' } } end }
    core.NpcSeed = { npcs = {
        [223] = { n = 'Dan Golthas', m = 0, x = 1, y = 2, p = 'Leatherworking',
            t = { { 2338, 'Handstitched Leather Pants', 50, 15, 0 }, { 3782, 'Handstitched Leather Belt', 75, 25, 0 } } },
        [340] = { n = 'Kendor Kabonka', m = 0, x = 3, y = 4, v = { { 728, 'Cooking', 200, 75 }, { 2697, 'Cooking', 400, 50 } } },
        [999] = { n = 'Never Met', m = 0, x = 5, y = 6, v = { { 1, 'Cooking', 10, 1 } } },
    } }
    core.DataMetadata = { targetBuild = '70790' }
    return core
end

local function load(withCore)
    _G.TitanGatheredForeverV3 = withCore == false and { Style = {} } or fakeCore()
    styleStub(_G.TitanGatheredForeverV3.Style)
    local ns = { printed = {} }
    for _, file in ipairs(manifestFiles()) do
        if file ~= 'Start.lua' then assert(loadfile(FOLDER .. '/' .. file))(FOLDER, ns) end
    end
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    local clock = { ms = 0 }
    ns.clock = clock
    ns.env = { now = function() return 5000 end, build = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end,
        date = function() return 'D' end, coreVersion = function() return '0.5.108' end, moduleVersion = '0.1.0',
        clock = function() return clock.ms end, inCombat = function() return false end }
    ns.db = ns.Database.Init(nil, '0.1.0', 1000)
    ns.runtime = {}
    ns.state.build = '70862'
    return ns
end

local function plain(text) return (tostring(text):gsub('|cgold', ''):gsub('|cwhite', ''):gsub('|cgreen', ''):gsub('|r', '')) end
local function printed(ns)
    local lines = {}
    for _, line in ipairs(ns.printed) do lines[#lines + 1] = plain(line) end
    return table.concat(lines, '\n')
end

local function baselineOf(ns) return assert(ns.Baseline.FromCore()) end

test('the baseline reads the catalogue, the NPC seed, the professions, the target build and the modules from the core', function()
    local ns = load()
    local baseline = baselineOf(ns)
    eq(baseline.item(765), true); eq(baseline.item(1), false)
    eq(baseline.npc(223).n, 'Dan Golthas'); eq(baseline.npc(1), nil)
    eq(baseline.professions['Mining'], true); eq(baseline.professions['First Aid'], true); eq(baseline.professions['Herbalism'], true)
    eq(baseline.professions['Inscription'], nil)
    eq(baseline.build, '70790'); eq(baseline.version, '0.5.108')
    eq(table.concat(baseline.modules, ','), 'Herbalism,Mining')
end)

test('without the core there is no baseline and the reason says so', function()
    local ns = load(false)
    local baseline, reason = ns.Baseline.FromCore()
    eq(baseline, nil); has(reason, 'core')
    _G.TitanGatheredForeverV3 = nil
    baseline, reason = ns.Baseline.FromCore()
    eq(baseline, nil); has(reason, 'core')
end)

test('loot is new when the item is not in the installed catalogue and unchanged when it is', function()
    local ns = load(); local baseline = baselineOf(ns)
    local known = ns.Compare.Classify('loot', 765, { name = 'Silverleaf', seen = 3, firstBuild = '70862', lastBuild = '70862' }, baseline)
    eq(known.state, 'unchanged'); eq(known.name, 'Silverleaf'); eq(known.seen, 3); eq(known.category, 'loot'); eq(known.key, 765)
    local new = ns.Compare.Classify('loot', 12345, { name = 'Strange Herb', seen = 1 }, baseline)
    eq(new.state, 'new'); has(new.why, 'catalogue')
end)

test('an NPC in the seed is unchanged or different by name; one outside the seed has no baseline', function()
    local ns = load(); local baseline = baselineOf(ns)
    eq(ns.Compare.Classify('npcs', 223, { name = 'Dan Golthas' }, baseline).state, 'unchanged')
    local different = ns.Compare.Classify('npcs', 223, { name = 'Dan Golthas the Elder' }, baseline)
    eq(different.state, 'different'); eq(#different.details, 1); eq(different.details[1].field, 'name')
    eq(different.details[1].baseline, 'Dan Golthas'); eq(different.details[1].observed, 'Dan Golthas the Elder')
    local outside = ns.Compare.Classify('npcs', 777, { name = 'Hogger', services = { vendor = 1 } }, baseline)
    eq(outside.state, 'unbaselined'); has(outside.why, 'seed')
end)

test('vendor goods are compared with the seed by price and by what is offered', function()
    local ns = load(); local baseline = baselineOf(ns)
    local same = ns.Compare.Classify('vendors', 340, { goods = { [728] = { price = 200 }, [2697] = { price = 400 } }, taught = {} }, baseline)
    eq(same.state, 'unchanged')
    local row = ns.Compare.Classify('vendors', 340, { goods = { [728] = { price = 250 } }, taught = {} }, baseline)
    eq(row.state, 'different'); eq(#row.details, 2)
    eq(row.details[1].field, 'price'); eq(row.details[1].itemID, 728); eq(row.details[1].baseline, 200); eq(row.details[1].observed, 250)
    eq(row.details[2].field, 'notOffered'); eq(row.details[2].itemID, 2697)
end)

test('a vendor window that was never read as a vendor is not compared as one', function()
    local ns = load(); local baseline = baselineOf(ns)
    eq(ns.Compare.Classify('vendors', 340, { goods = {}, taught = {} }, baseline).state, 'unchanged')
end)

test('trainer lessons are compared with the seed by cost, requirement and by what is taught', function()
    local ns = load(); local baseline = baselineOf(ns)
    local taught = { ['Handstitched Leather Pants'] = { cost = 50, skillName = 'Leatherworking', skillRank = 15 },
        ['Handstitched Leather Belt'] = { cost = 75, skillName = 'Leatherworking', skillRank = 25 } }
    eq(ns.Compare.Classify('vendors', 223, { goods = {}, taught = taught }, baseline).state, 'unchanged')
    taught['Handstitched Leather Belt'].cost = 90
    taught['Handstitched Leather Vest'] = { cost = 10, skillName = 'Leatherworking', skillRank = 5 }
    local row = ns.Compare.Classify('vendors', 223, { goods = {}, taught = taught }, baseline)
    eq(row.state, 'different')
    local fields = {}
    for _, detail in ipairs(row.details) do fields[#fields + 1] = detail.field .. ':' .. tostring(detail.name) end
    eq(table.concat(fields, ','), 'cost:Handstitched Leather Belt,notInSeed:Handstitched Leather Vest')
end)

test('a profession trainer outside the seed is new; other goods and lessons have no baseline', function()
    local ns = load(); local baseline = baselineOf(ns)
    local trainer = ns.Compare.Classify('vendors', 5000, { goods = {}, taught = { Smelting = { cost = 5, skillName = 'Mining', skillRank = 1 } } }, baseline)
    eq(trainer.state, 'new'); has(trainer.why, 'seed')
    local other = ns.Compare.Classify('vendors', 5001, { goods = { [1] = { price = 1 } }, taught = {} }, baseline)
    eq(other.state, 'unbaselined')
end)

test('a profession is new when it is not one of the twelve known ones', function()
    local ns = load(); local baseline = baselineOf(ns)
    eq(ns.Compare.Classify('skills', 'Mining', { rank = 5 }, baseline).state, 'unchanged')
    eq(ns.Compare.Classify('skills', 'First Aid', { rank = 5 }, baseline).state, 'unchanged')
    local new = ns.Compare.Classify('skills', 'Inscription', { rank = 1 }, baseline)
    eq(new.state, 'new'); has(new.why, 'twelve')
end)

test('areas, quests and entities have no baseline in the game and say so', function()
    local ns = load(); local baseline = baselineOf(ns)
    for _, category in ipairs({ 'areas', 'quests', 'entities' }) do
        local row = ns.Compare.Classify(category, 'x', { title = 'A', seen = 1 }, baseline)
        eq(row.state, 'unbaselined'); has(row.why, 'offline')
    end
end)

test('a row says when it was seen on another build than the baseline and on more than one build', function()
    local ns = load(); local baseline = baselineOf(ns)
    local other = ns.Compare.Classify('loot', 12345, { firstBuild = '70862', lastBuild = '70862' }, baseline)
    eq(other.otherBuild, true); eq(other.severalBuilds, false)
    local same = ns.Compare.Classify('loot', 12345, { firstBuild = '70790', lastBuild = '70790' }, baseline)
    eq(same.otherBuild, false)
    local several = ns.Compare.Classify('loot', 12345, { firstBuild = '70790', lastBuild = '70862' }, baseline)
    eq(several.severalBuilds, true); eq(several.otherBuild, true)
    baseline.build = nil
    eq(ns.Compare.Classify('loot', 12345, { firstBuild = '1', lastBuild = '1' }, baseline).otherBuild, false)
end)

local function populated(ns)
    local data = ns.db.data
    data.loot[765] = { name = 'Silverleaf', seen = 2, firstBuild = '70862', lastBuild = '70862' }
    data.loot[12345] = { name = 'Strange Herb', seen = 1 }
    data.npcs[223] = { name = 'Dan Golthas' }
    data.npcs[777] = { name = 'Hogger' }
    data.vendors[340] = { goods = { [728] = { price = 200 }, [2697] = { price = 400 } }, taught = {} }
    data.skills.Inscription = { rank = 1 }
    data.areas['1|A|A||'] = { zone = 'A' }
end

test('a run counts every category and lists the rows in a fixed order', function()
    local ns = load(); populated(ns)
    local results = ns.Compare.Run(ns.db, baselineOf(ns))
    eq(results.counts.loot.new, 1); eq(results.counts.loot.unchanged, 1); eq(results.counts.loot.total, 2)
    eq(results.counts.npcs.unchanged, 1); eq(results.counts.npcs.unbaselined, 1)
    eq(results.counts.vendors.unchanged, 1)
    eq(results.counts.skills.new, 1)
    eq(results.counts.areas.unbaselined, 1)
    eq(results.counts.quests.total, 0)
    eq(results.totals.new, 2); eq(results.totals.different, 0)
    eq(results.rows.loot[1].key, 765); eq(results.rows.loot[2].key, 12345)
end)

test('what the baseline holds and was never observed is counted and can be listed', function()
    local ns = load(); populated(ns)
    local baseline = baselineOf(ns)
    local results = ns.Compare.Run(ns.db, baseline)
    eq(results.notSeen.npcs, 1)                    -- 223 was met as an NPC, 340 as a vendor, only 999 never
    eq(results.notSeen.items, 2)                   -- of the three catalogue items only 765 was looted
end)

test('not seen lists the seed NPCs and catalogue items that no observation touched', function()
    local ns = load(); populated(ns)
    local baseline = baselineOf(ns)
    local npcs = ns.Compare.NotSeen(ns.db, baseline, 'npcs')
    eq(table.concat(npcs, ','), '999')
    local items = ns.Compare.NotSeen(ns.db, baseline, 'loot')
    eq(table.concat(items, ','), '2770,4603')
    eq(#ns.Compare.NotSeen(ns.db, baseline, 'areas'), 0)
end)

test('the compare operation shows its phases, fills the results and saves a summary', function()
    local ns = load(); populated(ns)
    local spec = ns.Compare.Spec(ns.db, baselineOf(ns))
    eq(ns.Runner.Start(spec), true)
    local guard = 0
    while ns.Runner.Active() do ns.Runner.Tick(); guard = guard + 1; assert(guard < 100) end
    local text = printed(ns)
    has(text, 'Comparison'); has(text, 'Loot'); has(text, 'Professions'); has(text, 'Finished')
    assert(ns.results and ns.results.counts.loot.new == 1)
    local saved = ns.db.compare
    eq(saved.ranAt, 5000); eq(saved.baselineVersion, '0.5.108'); eq(saved.targetBuild, '70790'); eq(saved.clientBuild, '70862')
    eq(saved.counts.loot.new, 1); eq(saved.totals.new, 2)
    eq(saved.rows, nil)                             -- only the counts are saved, the rows are rebuilt on demand
end)

test('an empty database still produces a summary', function()
    local ns = load()
    ns.Runner.Start(ns.Compare.Spec(ns.db, baselineOf(ns)))
    while ns.Runner.Active() do ns.Runner.Tick() end
    eq(ns.db.compare.totals.new, 0); eq(ns.results.counts.loot.total, 0)
end)

test('the compare command starts the operation, needs the core and the summary appears in the status', function()
    local without = load(false)
    without.Commands.Handle('compare')
    has(printed(without), 'core'); eq(without.Runner.Active(), false)
    local ns = load(); populated(ns)
    ns.Commands.Handle('compare')
    eq(ns.Runner.Active(), true); has(printed(ns), 'Comparison')
    local guard = 0
    while ns.Runner.Active() do ns.Runner.Tick(); guard = guard + 1; assert(guard < 100) end
    ns.printed = {}
    ns.Commands.Handle('status')
    has(printed(ns), 'Last comparison'); has(printed(ns), 'new')
    ns.printed = {}
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.Commands.Handle('help')
    has(printed(ns), '/tgfd compare')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS discovery compare ' .. #tests .. ' checks')
