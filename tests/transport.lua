local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

-- Map 1 is the world, maps 2 and 3 are continents inside it, maps 4 and 5 are zones of 2 and 3.
local parents = { [2] = 1, [3] = 1, [4] = 2, [5] = 3 }
local rects = { [2] = { 0, .5, 0, 1 }, [3] = { .5, 1, 0, 1 }, [4] = { .2, .4, .5, .75 }, [5] = { 0, .5, 0, .5 } }
local function fresh()
    local printed = {}
    local ns = { db = {}, settings = {}, Print = function(text) printed[#printed + 1] = text end }
    C_Map = {
        GetMapInfo = function(id) return { parentMapID = parents[id] or 0 } end,
        GetMapRectOnMap = function(id) local r = rects[id]; return r[1], r[2], r[3], r[4] end,
    }
    assert(loadfile('TitanGatheredForeverV3/Transport.lua'))('TitanGatheredForeverV3', ns)
    return ns, printed
end

test('a point is carried up through the parent maps', function()
    local ns = fresh()
    local x, y = ns.Transport.ToMap(4, .5, .5, 1)
    assert(math.abs(x - (.5 * (.2 + .5 * .2))) < 1e-9 and math.abs(y - (.5 + .5 * .25) * 1) < 1e-9, x .. ' ' .. y)
    eq(select(1, ns.Transport.ToMap(4, .5, .5, 4)), .5)
    eq(ns.Transport.ToMap(4, .5, .5, 3), nil)               -- not an ancestor
end)

test('dock names match by unique prefix and refuse ambiguity', function()
    local ns = fresh()
    eq(ns.Transport.Match('menethil'), 'Menethil Harbor')
    eq(ns.Transport.Match('  BOOTY bay '), 'Booty Bay')
    local name, problem = ns.Transport.Match('s'); eq(name, nil); eq(problem, 'ambiguous')
    name, problem = ns.Transport.Match('zzz'); eq(problem, 'unknown')
end)

test('recording validates the position and stores the dock', function()
    local ns = fresh()
    eq(ns.Transport.Record('Auberdine', 1439, 1.5, .2), false)
    eq(ns.Transport.Record('Auberdine', 1439, .4, .2), true)
    eq(ns.Transport.Dock('Auberdine').map, 1439)
    ns.Transport.Forget('Auberdine'); eq(ns.Transport.Dock('Auberdine'), nil)
end)

test('a route is a line only on a map that holds both docks, a dock is a point on its own map', function()
    local ns = fresh()
    ns.Transport.Record('Auberdine', 5, .5, .5); ns.Transport.Record('Menethil Harbor', 4, .5, .5)
    local points, lines = ns.Transport.Layout(1)
    assert(points['Auberdine'] and points['Menethil Harbor']); eq(#lines, 1); eq(lines[1].route[3], 'Alliance')
    points, lines = ns.Transport.Layout(5)
    assert(points['Auberdine']); eq(points['Menethil Harbor'], nil); eq(#lines, 0)
    eq(#points['Auberdine'].routes, 4)                      -- Stormwind, Menethil, Southshore and Rut'theran routes name it
end)

test('dashes cover the segment with gaps and stay bounded', function()
    local ns = fresh()
    local d = ns.Transport.Dashes(0, 0, 100, 0, 7, 6)
    eq(#d, 8); eq(d[1][1], 0); eq(d[1][3], 7); eq(d[2][1], 13)
    eq(#ns.Transport.Dashes(0, 0, 0, 0, 7, 6), 0)
    assert(#ns.Transport.Dashes(0, 0, 1e6, 0, 7, 6) <= 400)
end)

test('the dock command lists, records and forgets', function()
    local ns, printed = fresh()
    C_Map.GetBestMapForUnit = function() return 5 end
    C_Map.GetPlayerMapPosition = function() return { GetXY = function() return .25, .75 end } end
    ns.Transport.Command('rut')
    assert(printed[#printed]:find('Recorded'), printed[#printed]); eq(ns.Transport.Dock("Rut'theran Village").y, .75)
    ns.Transport.Command(''); assert(printed[#printed]:find('1 of 15'), printed[#printed])
    ns.Transport.Command('forget rut'); eq(ns.Transport.Dock("Rut'theran Village"), nil)
    ns.Transport.Command('s'); assert(printed[#printed]:find('More than one'))
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then error(entry[1] .. ': ' .. tostring(err), 0) end
end
print('PASS transport ' .. #tests .. ' checks')
