-- Titan Gathered Forever: Discovery, milestone 3: passive collectors, privacy and the consent gate.
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

local PLAYER_GUID, PLAYER_NAME = 'Player-4711-0ABCDEF1', 'Radekovo'
local function creature(id, spawn) return 'Creature-0-1-2-3-' .. id .. '-' .. (spawn or '0000ABCD') end
local function object(id) return 'GameObject-0-1-2-3-' .. id .. '-0000BEEF' end

-- A fake client adapter. Every call can be overridden by a test.
local function fakeApi(over)
    local api = {
        Now = function() return 1000 end,
        Build = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end,
        Locale = function() return 'enUS' end,
        Zone = function() return { mapID = 1412, parentMapID = 1414, realZone = 'Mulgore', zone = 'Mulgore', subZone = 'Bloodhoof Village' } end,
        Position = function() return { mapID = 1412, x = 0.4, y = 0.5 } end,
        Unit = function() return nil end,
        Loot = function() return {} end,
        Merchant = function() return {} end,
        Trainer = function() return {} end,
        CanRepair = function() return false end,
        Quest = function() return nil end,
        QuestChoices = function() return {} end,
        Skills = function() return {} end,
    }
    for key, value in pairs(over or {}) do api[key] = value end
    return api
end

local function load(over)
    _G.TitanGatheredForeverV3 = { Style = {} }
    styleStub(_G.TitanGatheredForeverV3.Style)
    local ns = { printed = {} }
    for _, file in ipairs(manifestFiles()) do
        if file ~= 'Start.lua' then assert(loadfile(FOLDER .. '/' .. file))(FOLDER, ns) end
    end
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.api = fakeApi(over)
    ns.env = { now = function() return 1000 end, build = ns.api.Build, date = function() return 'D' end,
        coreVersion = function() return '0.5.108' end, moduleVersion = '0.1.0',
        clock = function() return 0 end, inCombat = function() return false end }
    ns.db = ns.Database.Init(nil, '0.1.0', 1000)
    ns.runtime = {}
    ns.frame = { events = {} }
    function ns.frame:RegisterEvent(event) self.events[event] = true end
    function ns.frame:UnregisterEvent(event) self.events[event] = nil end
    return ns
end

local function accepted(over)
    local ns = load(over)
    ns.Consent.Accept(ns.db, ns.runtime, 1000)
    return ns
end

local function walk(value, visit, seen)
    seen = seen or {}
    if type(value) == 'table' then
        if seen[value] then return end
        seen[value] = true
        for key, inner in pairs(value) do walk(key, visit, seen); walk(inner, visit, seen) end
    else
        visit(value)
    end
end

test('only creatures and game objects are entities; players, pets, items and garbage are not', function()
    local ns = load()
    local kind, id = ns.Privacy.Entity(creature(12345))
    eq(kind, 'Creature'); eq(id, 12345)
    kind, id = ns.Privacy.Entity(object(678))
    eq(kind, 'GameObject'); eq(id, 678)
    eq(ns.Privacy.Entity(PLAYER_GUID), nil)
    eq(ns.Privacy.Entity('Pet-0-1-2-3-99-0000ABCD'), nil)
    eq(ns.Privacy.Entity('Item-0-0-0000ABCD'), nil)
    eq(ns.Privacy.Entity('Creature-bad'), nil)
    eq(ns.Privacy.Entity(nil), nil)
    eq(ns.Privacy.Entity(42), nil)
    eq(ns.Privacy.Key('Creature', 12345), 'Creature:12345')
end)

test('a record is created once, then counted, with the first and last time and build', function()
    local ns = load()
    local bucket = {}
    local record, isNew = ns.Records.Touch(bucket, 765, { now = 10, build = '1' })
    eq(isNew, true); eq(record.seen, 1); eq(record.first, 10); eq(record.last, 10); eq(record.firstBuild, '1'); eq(record.lastBuild, '1')
    local again, second = ns.Records.Touch(bucket, 765, { now = 20, build = '2' })
    eq(second, false); eq(again, record); eq(record.seen, 2); eq(record.first, 10); eq(record.last, 20)
    eq(record.firstBuild, '1'); eq(record.lastBuild, '2')
    ns.Records.Count(record, 'sources', 'Creature:1')
    ns.Records.Count(record, 'sources', 'Creature:1', 2)
    eq(record.sources['Creature:1'], 3)
end)

test('loot records the item, the quantity offered, the sources and the area', function()
    local ns = accepted({ Loot = function() return {
        { slot = 1, itemID = 765, name = 'Silverleaf', quantity = 2, quality = 1, sources = { creature(100), object(5) } },
        { slot = 2, itemID = nil, sources = { creature(100) } },
    } end })
    ns.Area.Changed()
    ns.Loot.Opened()
    local record = ns.db.data.loot[765]
    eq(record.name, 'Silverleaf'); eq(record.offered, 2); eq(record.quality, 1); eq(record.seen, 1)
    eq(record.sources['Creature:100'], 1); eq(record.sources['GameObject:5'], 1)
    eq(record.areas[ns.state.areaKey], 1)
    eq(ns.Database.CategoryCount(ns.db, 'loot'), 1)
    assert(ns.db.data.npcs[100] and ns.db.data.npcs[100].name == nil, 'creature source was not noted')
    assert(ns.db.data.entities['GameObject:5'], 'object source was not noted')
end)

test('the same loot window read twice (ready and opened) adds only the new sources', function()
    local slots = { { slot = 1, itemID = 765, name = 'Silverleaf', quantity = 1, sources = {} } }
    local ns = accepted({ Loot = function() return slots end })
    ns.Loot.Opened()
    eq(ns.db.data.loot[765].unsourced, 1)
    slots[1].sources = { object(5) }
    ns.Loot.Opened()
    local record = ns.db.data.loot[765]
    eq(record.offered, 1); eq(record.seen, 1); eq(record.sources['GameObject:5'], 1)
    ns.Loot.Closed()
    ns.Loot.Opened()
    eq(ns.db.data.loot[765].offered, 2); eq(ns.db.data.loot[765].seen, 2)
end)

test('loot taken is counted separately from loot offered', function()
    local ns = accepted({ Loot = function() return {
        { slot = 1, itemID = 765, name = 'Silverleaf', quantity = 3, sources = { object(5) } },
        { slot = 2, itemID = 2770, name = 'Copper Ore', quantity = 1, sources = { object(6) } } } end })
    ns.Loot.Opened()
    ns.Loot.SlotCleared(1)
    ns.Loot.SlotCleared(1)                       -- the same slot cannot be taken twice
    ns.Loot.SlotCleared(9)                       -- unknown slot
    eq(ns.db.data.loot[765].taken, 3); eq(ns.db.data.loot[765].offered, 3)
    eq(ns.db.data.loot[2770].taken, nil)
end)

test('a player source is never noted, and loot without a readable item is skipped', function()
    local ns = accepted({ Loot = function() return {
        { slot = 1, itemID = 765, name = 'Silverleaf', quantity = 1, sources = { PLAYER_GUID } } } end })
    ns.Loot.Opened()
    local record = ns.db.data.loot[765]
    eq(next(record.sources), nil); eq(record.unsourced, 1)
    local found = false
    walk(ns.db, function(value) if type(value) == 'string' and value:find('Player', 1, true) then found = true end end)
    eq(found, false)
end)

test('a target or mouseover creature is recorded once per session with its description', function()
    local unit = { guid = creature(200), name = 'Hogger', level = 11, classification = 'elite', creatureType = 'Humanoid', family = nil }
    local ns = accepted({ Unit = function() return unit end })
    ns.Area.Changed()
    ns.Npc.Seen('target')
    ns.Npc.Seen('mouseover')
    local record = ns.db.data.npcs[200]
    eq(record.name, 'Hogger'); eq(record.minLevel, 11); eq(record.maxLevel, 11); eq(record.classification, 'elite')
    eq(record.creatureType, 'Humanoid'); eq(record.seen, 1); eq(record.areas[ns.state.areaKey], 1)
    unit.level = 12
    ns.Npc.Seen('target')                        -- same session, same creature: nothing new
    eq(record.maxLevel, 11)
    ns.Npc.ResetSession()
    ns.Npc.Seen('target')
    eq(record.maxLevel, 12); eq(record.minLevel, 11); eq(record.seen, 2)
end)

test('contact with an NPC counts the service and keeps the position outside instances', function()
    local unit = { guid = creature(201), name = 'Innkeeper', level = 20 }
    local ns = accepted({ Unit = function() return unit end })
    ns.Npc.Contact('npc', 'gossip')
    ns.Npc.Contact('npc', 'gossip')
    ns.Npc.Contact('npc', 'vendor')
    local record = ns.db.data.npcs[201]
    eq(record.services.gossip, 2); eq(record.services.vendor, 1)
    eq(#record.positions, 1); eq(record.positions[1].mapID, 1412)
end)

test('a position far from the known ones is added, a near one is not, at most five are kept, none inside instances', function()
    local where = { mapID = 1412, x = 0.4, y = 0.5 }
    local unit = { guid = creature(202), name = 'Walker', level = 5 }
    local ns = accepted({ Unit = function() return unit end, Position = function() return where end })
    ns.Npc.Contact('npc', 'gossip')
    where = { mapID = 1412, x = 0.405, y = 0.5 }
    ns.Npc.Contact('npc', 'gossip')
    eq(#ns.db.data.npcs[202].positions, 1)
    for i = 1, 8 do where = { mapID = 1412, x = 0.4 + i * 0.05, y = 0.5 }; ns.Npc.Contact('npc', 'gossip') end
    eq(#ns.db.data.npcs[202].positions, 5)
    local inside = accepted({ Unit = function() return { guid = creature(203), name = 'Deep', level = 60 } end, Position = function() return nil end })
    inside.Npc.Contact('npc', 'gossip')
    eq(#inside.db.data.npcs[203].positions, 0)
end)

test('players and player controlled units are never recorded, with their names', function()
    local units = { { guid = PLAYER_GUID, name = PLAYER_NAME, level = 60, isPlayer = true },
        { guid = creature(300), name = 'Fluffy ' .. PLAYER_NAME, level = 10, playerControlled = true },
        { guid = 'Pet-0-1-2-3-301-0000ABCD', name = 'Biter', level = 3 } }
    local index = 0
    local ns = accepted({ Unit = function() index = index + 1; return units[index] end })
    ns.Npc.Seen('target'); ns.Npc.Seen('target'); ns.Npc.Contact('npc', 'gossip')
    eq(ns.Database.CategoryCount(ns.db, 'npcs'), 0)
    local found = false
    walk(ns.db, function(value) if type(value) == 'string' and (value:find(PLAYER_NAME, 1, true) or value:find('Player-', 1, true)) then found = true end end)
    eq(found, false)
end)

test('a game object met through the npc unit is an entity, not an npc', function()
    local ns = accepted({ Unit = function() return { guid = object(900), name = 'Mailbox' } end })
    ns.Npc.Contact('npc', 'gossip')
    local entity = ns.db.data.entities['GameObject:900']
    eq(entity.name, 'Mailbox'); eq(entity.services.gossip, 1)
    eq(ns.Database.CategoryCount(ns.db, 'npcs'), 0)
end)

test('a vendor window records the goods with price, stack, stock and extended cost, and each re-read', function()
    local goods = { { itemID = 2589, price = 50, stack = 5, stock = nil, extendedCost = nil },
        { itemID = 12345, price = nil, stack = 1, stock = 3, extendedCost = true } }
    local ns = accepted({ Unit = function() return { guid = creature(400), name = 'Trader', level = 30 } end,
        Merchant = function() return goods end, CanRepair = function() return true end })
    ns.Vendor.MerchantShown()
    local record = ns.db.data.vendors[400]
    eq(record.goods[2589].price, 50); eq(record.goods[2589].stack, 5)
    eq(record.goods[12345].stock, 3); eq(record.goods[12345].extendedCost, true); eq(record.scans, 1)
    eq(ns.db.data.npcs[400].services.vendor, 1); eq(ns.db.data.npcs[400].services.repair, 1)
    goods[1].price = 60
    ns.Vendor.MerchantShown()
    eq(ns.db.data.vendors[400].goods[2589].price, 60); eq(ns.db.data.vendors[400].scans, 2)
end)

test('a trainer window records what is taught with cost, skill requirement and level', function()
    local ns = accepted({ Unit = function() return { guid = creature(401), name = 'Teacher', level = 40 } end,
        Trainer = function() return { { name = 'Apprentice Mining', cost = 100, skillName = 'Mining', skillRank = 1, level = 5 },
            { name = 'Plain', cost = nil } } end })
    ns.Vendor.TrainerShown()
    local taught = ns.db.data.vendors[401].taught
    eq(taught['Apprentice Mining'].cost, 100); eq(taught['Apprentice Mining'].skillName, 'Mining')
    eq(taught['Apprentice Mining'].level, 5); eq(taught['Plain'].cost, nil)
    eq(ns.db.data.npcs[401].services.trainer, 1)
end)

test('a merchant that is not a creature is not recorded', function()
    local ns = accepted({ Unit = function() return { guid = PLAYER_GUID, name = PLAYER_NAME, isPlayer = true } end,
        Merchant = function() return { { itemID = 1, price = 1, stack = 1 } } end })
    ns.Vendor.MerchantShown()
    eq(ns.Database.Count(ns.db), 0)
end)

test('quests record the title, the giver, acceptance, turn in and the rewards offered', function()
    local ns = accepted({ Unit = function() return { guid = creature(500), name = 'Quest giver', level = 10 } end,
        Quest = function() return { id = 77, title = 'A Rite of Passage' } end,
        QuestChoices = function() return { 2589, 2592 } end })
    ns.Quest.Detail()
    ns.Quest.Accepted(77)
    ns.Quest.Complete()
    ns.Quest.TurnedIn(77)
    local record = ns.db.data.quests[77]
    eq(record.title, 'A Rite of Passage'); eq(record.giver, 'Creature:500'); eq(record.accepted, 1); eq(record.turnedIn, 1)
    eq(record.rewards[2589], true); eq(record.rewards[2592], true)
    eq(ns.db.data.npcs[500].services.quest, 2)
end)

test('a quest from a player is recorded without a giver', function()
    local ns = accepted({ Unit = function() return { guid = PLAYER_GUID, name = PLAYER_NAME, isPlayer = true } end,
        Quest = function() return { id = 78, title = 'Shared' } end })
    ns.Quest.Detail()
    eq(ns.db.data.quests[78].giver, nil)
end)

test('every new area name is recorded, repeated events for the same area are not counted again', function()
    local zone = { mapID = 1412, parentMapID = 1414, realZone = 'Mulgore', zone = 'Mulgore', subZone = 'Bloodhoof Village' }
    local ns = accepted({ Zone = function() return zone end })
    ns.Area.Changed()
    ns.Area.Changed()
    local key = ns.state.areaKey
    local record = ns.db.data.areas[key]
    eq(record.mapID, 1412); eq(record.parentMapID, 1414); eq(record.realZone, 'Mulgore'); eq(record.subZone, 'Bloodhoof Village')
    eq(record.seen, 1)
    zone = { mapID = 1412, parentMapID = 1414, realZone = 'Mulgore', zone = 'Mulgore', subZone = 'Red Cloud Mesa' }
    ns.Area.Changed()
    eq(ns.Database.CategoryCount(ns.db, 'areas'), 2)
    zone = { mapID = 1412, parentMapID = 1414, realZone = 'Mulgore', zone = 'Mulgore', subZone = 'Bloodhoof Village' }
    ns.Area.Changed()
    eq(ns.db.data.areas[key].seen, 2)
end)

test('instances are recorded with their name and type; an empty zone answer is ignored', function()
    local ns = accepted({ Zone = function() return { mapID = 249, realZone = 'Onyxia\'s Lair', zone = '', subZone = '',
        instanceName = 'Onyxia\'s Lair', instanceType = 'raid' } end })
    ns.Area.Changed()
    local record = ns.db.data.areas[ns.state.areaKey]
    eq(record.instanceName, 'Onyxia\'s Lair'); eq(record.instanceType, 'raid')
    local empty = accepted({ Zone = function() return {} end })
    empty.Area.Changed()
    eq(empty.Database.CategoryCount(empty.db, 'areas'), 0)
end)

test('professions are recorded with rank and maximum and updated when they change', function()
    local skills = { { name = 'Mining', rank = 5, maxRank = 75 } }
    local ns = accepted({ Skills = function() return skills end })
    ns.Skill.Changed()
    skills[1].rank = 20
    ns.Skill.Changed()
    local record = ns.db.data.skills.Mining
    eq(record.rank, 20); eq(record.maxRank, 75); eq(record.seen, 2)
end)

test('the client build is recorded with the time it was first seen', function()
    local ns = accepted()
    ns.Client.Record()
    eq(ns.db.meta.client.build, '70862'); eq(ns.db.meta.client.version, '1.60.1'); eq(ns.db.meta.client.interface, 16001)
    eq(ns.db.meta.client.locale, 'enUS'); eq(ns.db.meta.builds['70862'], 1000)
    eq(ns.state.build, '70862')
end)

test('events are handled only while collecting, and the collector events follow the consent', function()
    local ns = load({ Zone = function() return { mapID = 1, realZone = 'A', zone = 'A', subZone = '' } end })
    ns.Manager.Refresh()
    eq(next(ns.frame.events), nil)
    ns.Manager.Handle('ZONE_CHANGED_NEW_AREA')
    eq(ns.Database.Count(ns.db), 0)
    ns.Consent.Accept(ns.db, ns.runtime, 1000)
    ns.Manager.Refresh()
    assert(ns.frame.events.LOOT_OPENED and ns.frame.events.ZONE_CHANGED and ns.frame.events.MERCHANT_SHOW and ns.frame.events.QUEST_DETAIL)
    ns.Manager.Handle('ZONE_CHANGED_NEW_AREA')
    eq(ns.Database.CategoryCount(ns.db, 'areas'), 1)
    ns.Consent.Stop(ns.db, ns.runtime)
    ns.Manager.Refresh()
    eq(next(ns.frame.events), nil)
    ns.Manager.Handle('ZONE_CHANGED')
    eq(ns.Database.CategoryCount(ns.db, 'areas'), 1)
end)

test('an error in a collector is contained, counted and shown in the status', function()
    local ns = accepted({ Zone = function() error('boom') end })
    ns.Manager.Refresh()
    ns.Manager.Handle('ZONE_CHANGED')
    ns.Manager.Handle('ZONE_CHANGED')
    eq(ns.runtime.errors, 2); has(ns.runtime.lastError, 'boom')
    ns.Commands.Handle('status')
    local text = table.concat(ns.printed, '\n')
    has(text, 'boom'); has(text, 'errors')
end)

test('accept, stop and start register and unregister the collectors', function()
    local ns = load()
    ns.Commands.Handle('accept')
    assert(ns.frame.events.LOOT_OPENED)
    ns.Commands.Handle('stop')
    eq(ns.frame.events.LOOT_OPENED, nil)
    ns.Commands.Handle('start')
    assert(ns.frame.events.LOOT_OPENED)
end)

test('a play session with players around never leaves a player GUID or name in the saved data', function()
    local unit = { guid = creature(600), name = 'Boar', level = 5 }
    local ns = accepted({ Unit = function(which)
            if which == 'player' then return { guid = PLAYER_GUID, name = PLAYER_NAME, isPlayer = true } end
            return unit
        end,
        Loot = function() return { { slot = 1, itemID = 769, name = 'Chunk of Boar Meat', quantity = 1, sources = { unit.guid, PLAYER_GUID } } } end,
        Quest = function() return { id = 9, title = 'Boars' } end })
    ns.Manager.Refresh()
    for _, event in ipairs({ 'ZONE_CHANGED', 'PLAYER_TARGET_CHANGED', 'UPDATE_MOUSEOVER_UNIT', 'LOOT_READY', 'LOOT_OPENED',
        'LOOT_SLOT_CLEARED', 'LOOT_CLOSED', 'GOSSIP_SHOW', 'MERCHANT_SHOW', 'QUEST_DETAIL' }) do
        ns.Manager.Handle(event, 1)
    end
    assert(ns.Database.Count(ns.db) > 0)
    walk(ns.db, function(value)
        if type(value) == 'string' then
            assert(not value:find(PLAYER_NAME, 1, true), 'player name stored: ' .. value)
            assert(not value:find('Player-', 1, true), 'player guid stored: ' .. value)
        end
    end)
end)

test('the real client adapter reads loot, merchant and trainer data in the shape the core uses', function()
    _G.issecretvalue = function() return false end
    _G.GetNumLootItems = function() return 1 end
    _G.GetLootSlotLink = function() return '|cff1eff00|Hitem:765::::::::|h[Silverleaf]|h|r' end
    _G.GetLootSlotInfo = function() return nil, 'Silverleaf', 2, nil, 1 end
    _G.GetLootSourceInfo = function() return 'Creature-0-1-2-3-100-0000ABCD', 2 end
    _G.GetMerchantNumItems = function() return 1 end
    _G.GetMerchantItemLink = function() return '|Hitem:2589::::|h[Linen Cloth]|h' end
    _G.C_MerchantFrame = { GetItemInfo = function() return { price = 50, stackCount = 5, numAvailable = -1, hasExtendedCost = false } end }
    _G.GetNumTrainerServices = function() return 2 end
    _G.GetTrainerServiceInfo = function(i) if i == 1 then return 'Header', nil, 'header', 0 end return 'Apprentice Mining', 'available', 'used', 5 end
    _G.GetTrainerServiceCost = function() return 100 end
    _G.GetTrainerServiceSkillReq = function() return 'Mining', 1 end
    local ns = load()
    ns.api = nil
    local api = ns.Api.Default()
    local loot = api.Loot()
    eq(#loot, 1); eq(loot[1].itemID, 765); eq(loot[1].name, 'Silverleaf'); eq(loot[1].quantity, 2); eq(loot[1].sources[1], 'Creature-0-1-2-3-100-0000ABCD')
    local goods = api.Merchant()
    eq(goods[1].itemID, 2589); eq(goods[1].price, 50); eq(goods[1].stack, 5); eq(goods[1].stock, nil)
    local taught = api.Trainer()
    eq(#taught, 1); eq(taught[1].name, 'Apprentice Mining'); eq(taught[1].cost, 100); eq(taught[1].skillName, 'Mining'); eq(taught[1].level, 5)
    _G.GetNumLootItems = function() error('no window') end
    eq(#api.Loot(), 0)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS discovery collectors ' .. #tests .. ' checks')
