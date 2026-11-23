local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function order(rows) local ids = {} for _, row in ipairs(rows) do ids[#ids + 1] = row.id end return table.concat(ids, ',') end

local function frame()
    local f = { scripts = {}, texCoord = nil, shown = true, points = {} }
    function f:SetAllPoints(target) self.allPoints = target end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:CreateTexture() local t = frame(); t.shown = false; return t end
    function f:SetTexture(path) self.texture = path end
    function f:SetSize() end
    function f:SetTexCoord(...) self.texCoord = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetStringWidth() return 30 end
    return f
end

local function fresh()
    local ns = { settings = {} }
    function CreateFrame() return frame() end
    assert(loadfile('TitanGatheredForever/ColumnSort.lua'))('TitanGatheredForever', ns)
    return ns, ns.ColumnSort
end

local rows = {
    { id = 1, name = 'Peacebloom', count = 5 }, { id = 2, name = 'silverleaf', count = 12 },
    { id = 3, name = 'Briarthorn', count = 5 }, { id = 4, name = 'Mageroyal', count = nil },
}
local function value(row, column) if column == 1 then return row.name and row.name:lower() end return row.count end
local function tie(a, b) if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end return a.id < b.id end

test('text goes a to z, numbers from the highest, a missing value is last in both directions', function()
    local _, CS = fresh()
    local copy = { unpack(rows) }
    CS.Sort(copy, value, { column = 1, descending = false }, tie); eq(order(copy), '3,4,1,2')
    CS.Sort(copy, value, { column = 1, descending = true }, tie); eq(order(copy), '2,1,4,3')
    CS.Sort(copy, value, { column = 2, descending = true }, tie); eq(order(copy), '2,3,1,4')
    CS.Sort(copy, value, { column = 2, descending = false }, tie); eq(order(copy), '3,1,2,4')
end)

test('equal values keep a fixed order, so repeated sorts never reshuffle', function()
    local _, CS = fresh()
    local a, b = { unpack(rows) }, { rows[4], rows[3], rows[2], rows[1] }
    CS.Sort(a, value, { column = 2, descending = true }, tie); CS.Sort(b, value, { column = 2, descending = true }, tie)
    eq(order(a), order(b))
end)

test('a click picks the first direction by kind and reverses on the same column', function()
    local _, CS = fresh()
    local state = CS.Next({ column = 1, descending = false }, 2, 'number'); eq(state.column, 2); eq(state.descending, true)
    state = CS.Next(state, 2, 'number'); eq(state.descending, false)
    state = CS.Next(state, 1, 'text'); eq(state.column, 1); eq(state.descending, false)
    state = CS.Next(state, 1, 'text'); eq(state.descending, true)
end)

test('the header cells become buttons, a click sorts, saves and calls back, and the arrow follows', function()
    local ns, CS = fresh()
    local header, calls = frame(), 0
    local cells = { frame(), frame(), frame() }
    local sorter = CS.Attach({ parent = header, cells = cells, kinds = { 'text', 'number', false }, key = 'demo',
        default = { column = 1, descending = false }, onChange = function() calls = calls + 1 end })
    eq(sorter.state.column, 1)
    eq(#sorter.buttons, 3)
    eq(sorter.buttons[3].scripts.OnClick, nil)                       -- a column marked false is plain text
    sorter.buttons[2].scripts.OnClick()
    eq(sorter.state.column, 2); eq(sorter.state.descending, true); eq(calls, 1)
    eq(ns.settings.columnSort.demo.column, 2); eq(ns.settings.columnSort.demo.descending, true)
    eq(sorter.arrow.shown, true)
    eq(sorter.arrow.texCoord[3], 1)                                  -- descending arrow
    sorter.buttons[2].scripts.OnClick(); eq(sorter.state.descending, false); eq(sorter.arrow.texCoord[3], 0)
end)

test('a saved order is restored, and a saved column that no longer exists falls back to the default', function()
    local ns, CS = fresh()
    ns.settings.columnSort = { demo = { column = 2, descending = true }, gone = { column = 9, descending = true } }
    local sorter = CS.Attach({ parent = frame(), cells = { frame(), frame() }, kinds = { 'text', 'number' }, key = 'demo',
        default = { column = 1, descending = false }, onChange = function() end })
    eq(sorter.state.column, 2); eq(sorter.state.descending, true)
    local other = CS.Attach({ parent = frame(), cells = { frame(), frame() }, kinds = { 'text', 'number' }, key = 'gone',
        default = { column = 1, descending = false }, onChange = function() end })
    eq(other.state.column, 1); eq(other.state.descending, false)
end)

test('without a saved or default order nothing is sorted and no arrow is shown', function()
    local _, CS = fresh()
    local sorter = CS.Attach({ parent = frame(), cells = { frame() }, kinds = { 'text' }, key = 'plain', onChange = function() end })
    eq(sorter.state, nil); eq(sorter.arrow.shown, false)
    local copy = { unpack(rows) }
    eq(sorter.Apply(copy, value, tie), false); eq(order(copy), '1,2,3,4')
end)

test('Apply sorts by the current state', function()
    local _, CS = fresh()
    local sorter = CS.Attach({ parent = frame(), cells = { frame(), frame() }, kinds = { 'text', 'number' }, key = 'a',
        default = { column = 2, descending = true }, onChange = function() end })
    local copy = { unpack(rows) }
    eq(sorter.Apply(copy, value, tie), true); eq(order(copy), '2,3,1,4')
end)

local failed = 0
for _, case in ipairs(tests) do
    local ok, err = pcall(case[2])
    if ok then print('PASS ' .. case[1]) else failed = failed + 1; print('FAIL ' .. case[1] .. ': ' .. tostring(err)) end
end
if failed > 0 then os.exit(1) end
print('PASS column sort ' .. #tests .. ' checks')
