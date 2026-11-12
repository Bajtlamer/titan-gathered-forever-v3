local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh(api)
    local ns = { IsPublic = function() return true end, settings = { recordNpcs = true }, db = { npcs = {} } }
    ns.NpcSources = { Invalidate = function() ns.invalidated = (ns.invalidated or 0) + 1 end }
    assert(loadfile('TitanGatheredForeverV3/NpcObserver.lua'))('TitanGatheredForeverV3', ns)
    local base = { Enabled = function() return ns.settings.recordNpcs end, Now = function() return 1234 end,
        Npc = function() return { id = 3167, name = 'Trainer Bob', mapID = 1429, x = 0.4, y = 0.5 } end,
        TrainerServices = function() return {} end, MerchantRecipes = function() return {} end }
    for key, value in pairs(api or {}) do base[key] = value end
    return ns, ns.NpcObserver.New(base)
end

test('creature guid yields the npc id and anything else is rejected', function()
    local ns = fresh()
    eq(ns.NpcObserver.NpcID('Creature-0-3134-0-0-3167-0000123ABC'), 3167)
    eq(ns.NpcObserver.NpcID('Player-0-0000ABCD'), nil)
    eq(ns.NpcObserver.NpcID(nil), nil)
    eq(ns.NpcObserver.NpcID(42), nil)
end)

test('requirement text parses profession and rank', function()
    local ns = fresh()
    local kind, rank = ns.NpcObserver.ParseRequirement('Requires Alchemy (225)')
    eq(kind, 'Alchemy'); eq(rank, 225)
    kind, rank = ns.NpcObserver.ParseRequirement('Requires First Aid (150)')
    eq(kind, 'FirstAid'); eq(rank, 150)
    eq(ns.NpcObserver.ParseRequirement('Requires Level 30'), nil)
    eq(ns.NpcObserver.ParseRequirement(nil), nil)
end)

test('trainer window stores the dominant profession and its services', function()
    local ns, observer = fresh({ TrainerServices = function() return {
        { name = 'Elixir of Minor Defense', cost = 100, skillName = 'Alchemy', skillRank = 1 },
        { name = 'Lesser Healing Potion', cost = 500, skillName = 'Alchemy', skillRank = 50 },
        { name = 'Heal', cost = 10, skillName = nil } } end })
    observer:TrainerShown()
    local saved = ns.db.npcs[3167]
    eq(saved.name, 'Trainer Bob'); eq(saved.profession, 'Alchemy'); eq(saved.lastSeen, 1234)
    eq(saved.mapID, 1429); eq(saved.x, 0.4); eq(#saved.trainer, 2)
    eq(saved.trainer[2].name, 'Lesser Healing Potion'); eq(saved.trainer[2].skill, 50); eq(saved.trainer[2].cost, 500)
    eq(ns.invalidated, 1)
end)

test('class trainers and disabled recording store nothing', function()
    local ns, observer = fresh({ TrainerServices = function() return { { name = 'Heal', cost = 10 } } end })
    observer:TrainerShown()
    eq(next(ns.db.npcs), nil)
    local ns2, off = fresh({ TrainerServices = function() return {
        { name = 'X', cost = 1, skillName = 'Alchemy', skillRank = 1 } } end })
    ns2.settings.recordNpcs = false
    off:TrainerShown()
    eq(next(ns2.db.npcs), nil)
end)

test('no recording without an npc such as inside an instance', function()
    local ns, observer = fresh({ Npc = function() return nil end, TrainerServices = function() return {
        { name = 'X', cost = 1, skillName = 'Alchemy', skillRank = 1 } } end })
    observer:TrainerShown(); observer:MerchantShown()
    eq(next(ns.db.npcs), nil)
end)

test('merchant window stores recipes only and replaces earlier stock', function()
    local rows = { { itemID = 100, kind = 'Alchemy', price = 12000, skill = 225, extendedCost = false } }
    local ns, observer = fresh({ MerchantRecipes = function() return rows end })
    observer:MerchantShown()
    eq(#ns.db.npcs[3167].vendor, 1); eq(ns.db.npcs[3167].vendor[1].price, 12000)
    rows = { { itemID = 101, kind = 'Cooking', price = 500 } }
    observer:MerchantShown()
    eq(#ns.db.npcs[3167].vendor, 1); eq(ns.db.npcs[3167].vendor[1].itemID, 101)
end)

test('a merchant without recipes does not create or erase a record', function()
    local ns, observer = fresh()
    observer:MerchantShown()
    eq(next(ns.db.npcs), nil)
    ns.db.npcs[3167] = { name = 'Old', vendor = { { itemID = 100, kind = 'Alchemy' } } }
    observer:MerchantShown()
    eq(#ns.db.npcs[3167].vendor, 1)
end)

test('trainer and vendor data for one npc are kept together', function()
    local ns, observer = fresh({
        TrainerServices = function() return { { name = 'A', cost = 1, skillName = 'Cooking', skillRank = 1 } } end,
        MerchantRecipes = function() return { { itemID = 5, kind = 'Cooking' } } end })
    observer:TrainerShown(); observer:MerchantShown()
    eq(ns.db.npcs[3167].profession, 'Cooking'); eq(#ns.db.npcs[3167].trainer, 1); eq(#ns.db.npcs[3167].vendor, 1)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS npc observer ' .. #tests .. ' checks')
