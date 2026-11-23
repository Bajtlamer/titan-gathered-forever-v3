local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function ids(rows) local out = {} for _, row in ipairs(rows) do out[#out + 1] = row.itemID end return table.concat(out, ',') end

-- Items: 1 Linen Cloth group A (3 bags, 2 bank), 2 Copper Ore group B (9 bags), 3 Bolt group A (4 bags),
-- 4 linen thread group A (3 bags, 2 bank), 5 Gem group B (1 bag, 20 bank).
local names = { 'Linen Cloth', 'Copper Ore', 'Bolt', 'linen thread', 'Gem' }
local groups = { 'A', 'B', 'A', 'A', 'B' }
local counts = { { bags = 3, bank = 2 }, { bags = 9, bank = 0 }, { bags = 4, bank = 0 }, { bags = 3, bank = 2 }, { bags = 1, bank = 20 } }

local function fresh(settings)
    local ns = { settings = settings or { showZero = false, showBank = true } }
    ns.Catalog = { List = function() return { 1, 2, 3, 4, 5 } end, Group = function(record) return record.group end }
    ns.Items = {}
    for id = 1, 5 do ns.Items[id] = { group = groups[id] } end
    ns.ItemName = function(id) return names[id] end
    ns.inventory = { Get = function(_, id) return counts[id] end }
    assert(loadfile('TitanGatheredForever/Titan.lua'))('TitanGatheredForever', ns)
    return ns
end

test('the default order is by item id inside each group, as before', function()
    local ns = fresh(); eq(ids(ns.Titan.Rows()), '1,3,4,2,5')
end)

test('most first and fewest first order each group by count, bags plus bank', function()
    local ns = fresh({ showZero = false, showBank = true, titanSort = 'most' })
    eq(ids(ns.Titan.Rows()), '1,4,3,5,2')            -- group A: Cloth 5, Thread 5 (equal: by name), Bolt 4; group B: Gem 21, Ore 9
end)

test('name order ignores case and ties go to the id', function()
    local ns = fresh({ showZero = false, showBank = true, titanSort = 'name' })
    eq(ids(ns.Titan.Rows()), '3,1,4,2,5')
end)

test('the bank counts only when it is shown', function()
    local ns = fresh({ showZero = false, showBank = false, titanSort = 'most' })
    eq(ids(ns.Titan.Rows()), '3,1,4,2,5')            -- bags only: Bolt 4, Cloth 3, Thread 3; Ore 9, Gem 1
end)

test('fewest first reverses the counts and still keeps the groups together', function()
    local ns = fresh({ showZero = false, showBank = true, titanSort = 'fewest' })
    eq(ids(ns.Titan.Rows()), '3,1,4,2,5')
end)

test('an unknown saved value behaves like the default order', function()
    local ns = fresh({ showZero = false, showBank = true, titanSort = 'nonsense' })
    eq(ids(ns.Titan.Rows()), '1,3,4,2,5')
end)

test('the four modes are listed for the menu with their labels', function()
    local ns = fresh()
    local labels = {}
    for _, mode in ipairs(ns.Titan.SORTS) do labels[#labels + 1] = mode.id .. '=' .. mode.label end
    eq(table.concat(labels, ';'), 'id=Item ID;name=Name;most=Most first;fewest=Fewest first')
end)

local failed = 0
for _, case in ipairs(tests) do
    local ok, err = pcall(case[2])
    if ok then print('PASS ' .. case[1]) else failed = failed + 1; print('FAIL ' .. case[1] .. ': ' .. tostring(err)) end
end
if failed > 0 then os.exit(1) end
print('PASS titan sort ' .. #tests .. ' checks')
