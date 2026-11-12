local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh(api)
    local ns = { IsPublic = function() return true end, settings = { recordNpcs = true }, db = { npcs = {}, npcLog = {} },
        printed = {} }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
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
        { name = 'Lesser Healing Potion', cost = 500, skillName = 'Alchemy', skillRank = 50, level = 10 },
        { name = 'Heal', cost = 10, skillName = nil } } end })
    observer:TrainerShown()
    local saved = ns.db.npcs[3167]
    eq(saved.name, 'Trainer Bob'); eq(saved.profession, 'Alchemy'); eq(saved.lastSeen, 1234)
    eq(saved.mapID, 1429); eq(saved.x, 0.4); eq(#saved.trainer, 2)
    eq(saved.trainer[2].name, 'Lesser Healing Potion'); eq(saved.trainer[2].skill, 50); eq(saved.trainer[2].cost, 500)
    eq(saved.trainer[2].level, 10); eq(saved.trainer[1].level, nil)
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

test('every trainer attempt is logged with the reason it did or did not record', function()
    local services = {}
    local npc = nil
    local ns, observer = fresh({ Npc = function() return npc end, TrainerServices = function() return services end })
    local function last() return ns.db.npcLog[#ns.db.npcLog] end
    observer:TrainerShown(); eq(last().result, 'no-npc'); eq(last().event, 'TRAINER_SHOW')
    npc = { id = 3167, name = 'Trainer Bob', mapID = 1429, x = 0.4, y = 0.5 }
    observer:TrainerShown(); eq(last().result, 'no-services'); eq(last().services, 0)
    services = { { name = 'Heal', cost = 10 }, { name = 'Smite', cost = 20 } }
    observer:TrainerShown(); eq(last().result, 'no-profession'); eq(last().services, 2); eq(last().first, 'Heal')
    services = { { name = 'A', cost = 1, skillName = 'Alchemy', skillRank = 1 } }
    observer:TrainerShown(); eq(last().result, 'saved'); eq(last().profession, 'Alchemy'); eq(last().npc, 3167)
    ns.settings.recordNpcs = false
    observer:TrainerShown(); eq(last().result, 'disabled')
    eq(#ns.db.npcLog, 5)
end)

test('merchant attempts are logged too', function()
    local rows = {}
    local ns, observer = fresh({ MerchantRecipes = function() return rows end })
    local function last() return ns.db.npcLog[#ns.db.npcLog] end
    observer:MerchantShown(); eq(last().event, 'MERCHANT_SHOW'); eq(last().result, 'no-recipes')
    rows = { { itemID = 100, kind = 'Alchemy' } }
    observer:MerchantShown(); eq(last().result, 'saved'); eq(last().recipes, 1)
end)

test('the log keeps only the latest entries and attaches raw api probes', function()
    local ns, observer = fresh({ Probe = function(which) return { 'probe-' .. which } end })
    for _ = 1, 15 do observer:TrainerShown() end
    eq(#ns.db.npcLog, 12)
    eq(ns.db.npcLog[12].probe[1], 'probe-trainer')
end)

test('printing the log summarises every entry or says there is none', function()
    local ns, observer = fresh({ Probe = function() return { 'GetNumTrainerServices=function' } end })
    ns.NpcObserver.PrintLog(); eq(ns.printed[1], 'No NPC recording attempts yet. Open a trainer or merchant window first.')
    observer:TrainerShown()
    ns.printed = {}
    ns.NpcObserver.PrintLog()
    assert(ns.printed[1]:find('TRAINER_SHOW', 1, true) and ns.printed[1]:find('saved', 1, true) == nil)
    assert(ns.printed[1]:find('no-services', 1, true), ns.printed[1])
    assert(ns.printed[2]:find('GetNumTrainerServices=function', 1, true))
end)

test('trainer services that arrive after the window opens are recorded on update', function()
    local services = {}
    local ns, observer = fresh({ TrainerServices = function() return services end })
    observer:TrainerShown()
    eq(next(ns.db.npcs), nil)
    services = { { name = 'Apprentice Cooking', cost = 10, skillName = 'Cooking', skillRank = 1 },
        { name = 'Spice Bread', cost = 100, skillName = 'Cooking', skillRank = 1 } }
    observer:TrainerUpdated()
    eq(ns.db.npcs[3167].profession, 'Cooking'); eq(#ns.db.npcs[3167].trainer, 2)
    local last = ns.db.npcLog[#ns.db.npcLog]
    eq(last.event, 'TRAINER_UPDATE'); eq(last.result, 'saved')
end)

test('updates are ignored when no trainer window is open and empty updates are logged once', function()
    local ns, observer = fresh({ TrainerServices = function() return {} end })
    observer:TrainerUpdated(); eq(#ns.db.npcLog, 0)
    observer:TrainerShown(); observer:TrainerUpdated(); observer:TrainerUpdated(); observer:TrainerUpdated()
    eq(#ns.db.npcLog, 2) -- the show plus a single empty update
    observer:TrainerClosed(); observer:TrainerUpdated()
    eq(#ns.db.npcLog, 2)
end)

test('repeated identical saves from updates are not logged again', function()
    local services = { { name = 'A', cost = 1, skillName = 'Cooking', skillRank = 1 } }
    local ns, observer = fresh({ TrainerServices = function() return services end })
    observer:TrainerShown(); observer:TrainerUpdated(); observer:TrainerUpdated()
    eq(#ns.db.npcLog, 2)
    services = { { name = 'A', cost = 1, skillName = 'Cooking', skillRank = 1 }, { name = 'B', cost = 2, skillName = 'Cooking', skillRank = 5 } }
    observer:TrainerUpdated()
    eq(#ns.db.npcLog, 3); eq(#ns.db.npcs[3167].trainer, 2)
end)

test('merchant stock that arrives after the window opens is recorded on update', function()
    local rows = {}
    local ns, observer = fresh({ MerchantRecipes = function() return rows end })
    observer:MerchantShown(); eq(next(ns.db.npcs), nil)
    rows = { { itemID = 100, kind = 'Alchemy', price = 5 } }
    observer:MerchantUpdated()
    eq(#ns.db.npcs[3167].vendor, 1)
    observer:MerchantClosed(); rows = {}; observer:MerchantUpdated()
    eq(#ns.db.npcs[3167].vendor, 1)
end)

test('modern merchant item info table yields price and extended cost', function()
    local ns = fresh()
    local price, extended = ns.NpcObserver.MerchantInfo({ price = 12000, hasExtendedCost = false })
    eq(price, 12000); eq(extended, nil)
    price, extended = ns.NpcObserver.MerchantInfo({ price = 0, hasExtendedCost = true })
    eq(price, 0); eq(extended, true)
    eq(ns.NpcObserver.MerchantInfo(nil), nil)
    eq(ns.NpcObserver.MerchantInfo({ price = 'x' }), nil)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS npc observer ' .. #tests .. ' checks')
