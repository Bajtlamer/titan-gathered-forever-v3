local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

date = function() return '12:00:00' end
time = function() return 100 end
GetTime = function() return 5.25 end

local function fresh(debug)
    local ns = { IsPublic = function(value) return value ~= 'SECRET' end,
        settings = { debugMode = debug ~= false }, db = { debugLog = {} } }
    assert(loadfile('TitanGatheredForeverV3/DebugLog.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('entries are written only while debug mode is on, with a timestamp and a category', function()
    local ns = fresh(false)
    ns.DebugLog.Add('npc', 'ignored')
    eq(#ns.db.debugLog, 0)
    ns.settings.debugMode = true
    ns.DebugLog.Add('npc', 'TRAINER_UPDATE saved npc=1355')
    eq(#ns.db.debugLog, 1)
    eq(ns.db.debugLog[1], '12:00:00.250 npc TRAINER_UPDATE saved npc=1355')
end)

test('the log keeps the latest entries within a bounded size', function()
    local ns = fresh()
    for i = 1, 1250 do ns.DebugLog.Add('t', 'e' .. i) end
    assert(#ns.db.debugLog >= 1000 and #ns.db.debugLog <= 1100, 'size ' .. #ns.db.debugLog)
    assert(ns.db.debugLog[#ns.db.debugLog]:find('e1250', 1, true), 'newest entry missing')
    assert(not ns.db.debugLog[1]:find(' e1$'), 'oldest entry was not trimmed')
end)

test('important events are traced with readable arguments and noise is ignored', function()
    local ns = fresh()
    local log = ns.db.debugLog
    ns.DebugLog.Event('TRAINER_SHOW'); eq(log[#log], '12:00:00.250 event TRAINER_SHOW')
    ns.DebugLog.Event('LOOT_OPENED', true, false); eq(log[#log], '12:00:00.250 event LOOT_OPENED (true, false)')
    ns.DebugLog.Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'Cast-1-2-3', 2575)
    eq(log[#log], '12:00:00.250 event UNIT_SPELLCAST_SUCCEEDED unit=player spell=2575')
    ns.DebugLog.Event('CHAT_MSG_COMBAT_HONOR_GAIN', 'Foe dies, honorable kill (12 Honor Points)', '', '')
    eq(log[#log], '12:00:00.250 event CHAT_MSG_COMBAT_HONOR_GAIN (Foe dies, honorable kill (12 Honor Points))')
    local count = #log
    ns.DebugLog.Event('UNIT_SPELLCAST_SUCCEEDED', 'party1', 'Cast-9', 5)   -- other units
    ns.DebugLog.Event('BAG_UPDATE_DELAYED')                                  -- too frequent to be useful
    ns.DebugLog.Event('ITEM_DATA_LOAD_RESULT', 1, true)
    eq(#log, count)
    ns.DebugLog.Event('LOOT_CLOSED', 'SECRET'); eq(log[#log], '12:00:00.250 event LOOT_CLOSED')
end)

test('long text is truncated and clear empties the log in place', function()
    local ns = fresh()
    local log = ns.db.debugLog
    ns.DebugLog.Event('CHAT_MSG_COMBAT_HONOR_GAIN', string.rep('x', 200))
    assert(#log[1] < 140, 'entry is too long: ' .. #log[1])
    ns.DebugLog.Clear()
    eq(#log, 0); eq(ns.db.debugLog, log)
end)

test('nothing happens without a saved table', function()
    local ns = fresh()
    ns.db.debugLog = nil
    ns.DebugLog.Add('t', 'x'); ns.DebugLog.Event('TRAINER_SHOW'); ns.DebugLog.Clear()
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS debug log ' .. #tests .. ' checks')
