local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local itemNames = { [100] = 'Recipe: Lesser Healing Potion', [101] = 'Recipe: Elixir of Wisdom', [102] = 'Recipe: Tender Wolf Steak' }
C_Item = { GetItemInfo = function(id) return itemNames[id] end }

local function fresh()
    local ns = { IsPublic = function() return true end, characterID = 'C1', settings = {},
        db = { npcs = {}, knownRecipes = {} },
        Style = { gold = 'gold', gray = 'gray', Text = function(_, text) return text end },
        ItemName = function(id) return itemNames[id] or ('Loading ' .. id) end }
    ns.NpcSeed = { npcs = {
        [1] = { n = 'Alchemy Trainer', m = 0, x = 10, y = 20, p = 'Alchemy', t = {
            { 2259, 'Elixir of Minor Defense', 100, 1, 0 }, { 3101, 'Lesser Healing Potion', 500, 50, 0 },
            { 3102, 'Journeyman Alchemist', 5000, 50, 0 } } },
        [2] = { n = 'Recipe Vendor', m = 0, x = 11, y = 21, v = {
            { 100, 'Alchemy', 12000, 225 }, { 101, 'Alchemy', 20000, 0 }, { 102, 'Cooking', 300, 0 }, { 103, 'Alchemy', 1, 0 } } },
    } }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('unlearned recipes exclude known and rank spells and label the source', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Minor Defense' }, 10)
    local rows, unread, pending = ns.NpcSources.Unlearned('C1', false)
    eq(#rows, 2)
    eq(rows[1].name, 'Lesser Healing Potion'); eq(rows[1].trainer, true); eq(rows[1].skill, 50)
    eq(#rows[1].sources, 2); eq(rows[1].price, 500)
    eq(rows[2].name, 'Elixir of Wisdom'); eq(rows[2].trainer, false); eq(rows[2].skill, nil)
    eq(rows[2].sources[1].role, 'Vendor')
    eq(#unread, 1); eq(unread[1], 'Cooking')
    eq(pending, 1)
end)

test('vendor only hides recipes a trainer can also teach', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 10)
    local rows = ns.NpcSources.Unlearned('C1', true)
    eq(#rows, 1); eq(rows[1].name, 'Elixir of Wisdom')
end)

test('professions never read for the character are reported, not guessed', function()
    local ns = fresh()
    local rows, unread = ns.NpcSources.Unlearned('C1', false)
    eq(#rows, 0); eq(#unread, 2)
end)

test('browser cells and permissive frame construction', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Minor Defense' }, 10)
    local function frame()
        return setmetatable({}, { __index = function(_, key)
            return function(self, ...)
                if key:match('^Create') then return frame() end
                if key == 'GetNumPoints' then return 0 end
                return self
            end
        end })
    end
    CreateFrame = function() local f = frame(); f.TitleText = frame(); return f end
    UIParent, UISpecialFrames, GameTooltip = frame(), {}, frame()
    assert(loadfile('TitanGatheredForeverV3/RecipeBrowser.lua'))('TitanGatheredForeverV3', ns)
    local rows = ns.NpcSources.Unlearned('C1', false)
    local cells = ns.RecipeBrowser.Cells(rows[1])
    eq(cells[1], 'Lesser Healing Potion'); eq(cells[2], 'Alchemy'); eq(cells[3], '50'); eq(cells[4], 'Trainer')
    eq(cells[5], 'Alchemy Trainer (+1)'); eq(cells[6], '5s')
    ns.RecipeBrowser.Show()
    ns.RecipeBrowser.Refresh()
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS recipe browser ' .. #tests .. ' checks')
