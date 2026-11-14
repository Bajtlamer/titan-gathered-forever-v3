local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1', db = { knownRecipes = {} },
        settings = {} }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('names are stripped of recipe prefixes and normalised', function()
    local K = fresh().KnownRecipes
    eq(K.Strip('Recipe: Tender Wolf Steak'), 'Tender Wolf Steak')
    eq(K.Strip('Pattern: Blue Linen Vest'), 'Blue Linen Vest')
    eq(K.Strip('Plans: Sharp Claw'), 'Sharp Claw')
    eq(K.Strip('Elixir of Wisdom'), 'Elixir of Wisdom')
    eq(K.Strip('Some: Odd Name'), 'Some: Odd Name')
    eq(K.Normalize('Recipe: Tender Wolf Steak'), 'tender wolf steak')
    eq(K.Normalize(nil), '')
end)

test('unread professions are unknown, read ones are true or false', function()
    local K = fresh().KnownRecipes
    eq(K.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), nil)
    K.Record('C1', 'Alchemy', { 'Elixir of Wisdom' }, 100)
    eq(K.IsKnown('C1', 'Alchemy', 'Recipe: Elixir of Wisdom'), true)
    eq(K.IsKnown('C1', 'Alchemy', 'Lesser Healing Potion'), false)
    eq(K.IsKnown('C1', 'Cooking', 'Elixir of Wisdom'), nil)
    eq(K.IsKnown('C2', 'Alchemy', 'Elixir of Wisdom'), nil)
    eq(K.ReadAt('C1', 'Alchemy'), 100)
end)

test('scan records learned recipes per profession from the trade skill window', function()
    local ns = fresh()
    local info = {
        [1] = { name = 'Elixir of Wisdom', learned = true }, [2] = { name = 'Lesser Healing Potion', learned = false },
        [3] = { name = 'Tender Wolf Steak', learned = true }, [4] = { name = 'Odd', learned = true } }
    local profession = { [1] = 171, [2] = 171, [3] = 185, [4] = 9999 }
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() return { 1, 2, 3, 4 } end,
        GetRecipeInfo = function(id) return info[id] end,
        GetProfessionInfoByRecipeID = function(id) return { professionID = profession[id], parentProfessionID = profession[id] } end,
    }
    time = function() return 500 end
    ns.KnownRecipes.Scan()
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), true)
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Lesser Healing Potion'), false)
    eq(ns.KnownRecipes.IsKnown('C1', 'Cooking', 'Tender Wolf Steak'), true)
    eq(ns.KnownRecipes.ReadAt('C1', 'Alchemy'), 500)
    eq(ns.KnownRecipes.IsKnown('C1', 'Tailoring', 'Odd'), nil)
end)

test('scan ignores unreadable or empty data and keeps earlier records', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Wisdom' }, 1)
    C_TradeSkillUI = { GetAllRecipeIDs = function() return {} end }
    ns.KnownRecipes.Scan()
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), true)
    C_TradeSkillUI = nil
    ns.KnownRecipes.Scan()
    eq(ns.KnownRecipes.IsKnown('C1', 'Alchemy', 'Elixir of Wisdom'), true)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS known recipes ' .. #tests .. ' checks')
