local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function load()
    local ns = { printed = {} }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.Style = { Label = function(t) return t end, Value = function(t) return '[' .. t .. ']' end }
    assert(loadfile('TitanGatheredForever/LegacyFolders.lua'))('TitanGatheredForever', ns)
    return ns
end

test('only the old folders that are loaded are found; an error in the check counts as not loaded', function()
    local L = load().Legacy
    local loaded = { TitanGatheredForeverV3 = true, TitanGatheredForeverV3_Mining = true, TitanGatheredForever = true }
    local found = L.Found(function(name) return loaded[name] end)
    eq(#found, 2); eq(found[1], 'TitanGatheredForeverV3'); eq(found[2], 'TitanGatheredForeverV3_Mining')
    eq(#L.Found(function() error('boom') end), 0)
    eq(#L.Found(function() return false end), 0)
    eq(#L.FOLDERS, 14)
end)

test('nothing is said when no old folder is loaded; otherwise two lines name the folders and the saved file', function()
    local ns = load()
    eq(ns.Legacy.Messages({}), nil)
    local first, second = ns.Legacy.Messages({ 'TitanGatheredForeverV3', 'TitanGatheredForeverV3_Herbs' })
    assert(first:find('[TitanGatheredForeverV3, TitanGatheredForeverV3_Herbs]', 1, true))
    assert(second:find('TitanGatheredForeverV3.lua', 1, true) and second:find('TitanGatheredForever.lua', 1, true))
end)

test('the check prints at login only when an old folder is loaded', function()
    local ns = load()
    _G.C_AddOns = { IsAddOnLoaded = function(name) return name == 'TitanGatheredForeverV3_Auction' end }
    ns.Legacy.Check(); eq(#ns.printed, 2)
    _G.C_AddOns = { IsAddOnLoaded = function() return false end }
    ns.printed = {}; ns.Legacy.Check(); eq(#ns.printed, 0)
    _G.C_AddOns = nil
    ns.Legacy.Check(); eq(#ns.printed, 0)                    -- no API at all: nothing happens
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS legacy folders ' .. #tests .. ' checks')
