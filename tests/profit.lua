local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

-- Three recipes: A makes a profit, B makes a loss, C has a material without any price.
local function fresh()
    local ns = { IsPublic = function() return true end, db = { recipeMakes = {}, knownRecipes = {} }, characterID = 'C1' }
    assert(loadfile('TitanGatheredForeverV3/Catalog.lua'))('TitanGatheredForeverV3', ns)
    -- The books of two installed profession addons.
    ns.Catalog.RegisterModule({ id = 'Alchemy', label = 'Alchemy', items = {}, recipes = {}, book = {
        [101] = { 5001, { { 1, 2 }, { 2, 1 } } },        -- product 5001, 2 x item 1 and 1 x item 2
        [102] = { 5002, { { 1, 1 } } } } })
    ns.Catalog.RegisterModule({ id = 'FirstAid', label = 'First Aid', items = {}, recipes = {}, book = {
        [103] = { 5003, { { 3, 1 } } } } })                -- material 3 has no price
    ns.AuctionScan = { Price = function(id)
        local prices = { [1] = 100, [2] = 50, [5001] = 1000, [5002] = 80 }
        return prices[id] and { min = prices[id], n = 3 } or nil
    end }
    ns.NpcSources = { VendorsFor = function() return {} end, Coin = function(c) return c .. 'c' end }
    C_Item = { GetItemInfo = function(id) if id == 5003 then return 'Bandage', nil, 1, 1, 1, 't', 's', 1, '', 1, 200 end return 'Item' .. id end }
    C_Spell = { GetSpellInfo = function(id) return ({ [101] = { name = 'Potion A' }, [102] = { name = 'Potion B' } })[id] end,
        RequestLoadSpellData = function() end }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Economy.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Profit.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('every recipe gets its profit: product after the auction fee minus the materials, best first', function()
    local ns = fresh()
    local rows, info = ns.Profit.Rows('C1', {})
    eq(#rows, 3); eq(info.looked, 3)
    eq(rows[1].recipeID, 101); eq(rows[1].name, 'Potion A'); eq(rows[1].profession, 'Alchemy')
    eq(rows[1].profit, 700)                                           -- 1000 less 5% is 950, the materials cost 250
    eq(rows[1].product.best, 'auction'); eq(rows[1].product.materials, 250)
    eq(rows[2].recipeID, 102); eq(rows[2].profit, -24)                -- 80 less 5% is 76, the material costs 100
    eq(rows[3].recipeID, 103); eq(rows[3].profit, nil)                -- a material without a price: no profit
    eq(rows[3].name, 'Bandage')                                       -- no spell name: the product name
    eq(rows[3].product.vendor, 200); eq(rows[3].product.unpriced, 1)
    eq(rows[1].assumed, true)                                         -- one per craft is assumed
end)

test('the number a craft makes comes from the reagent window when it was seen', function()
    local ns = fresh()
    ns.db.recipeMakes[101] = { 2, 4 }                                 -- three on average
    local rows = ns.Profit.Rows('C1', {})
    eq(rows[1].recipeID, 101); eq(rows[1].assumed, false); eq(rows[1].product.quantity, 3)
    eq(rows[1].profit, 2850 - 250)                                    -- 3 x 950 less the materials
    local low, high, assumed = ns.Profit.Makes(5); eq(low, 1); eq(high, 1); eq(assumed, true)
end)

test('a profession filter and a search limit the rows', function()
    local ns = fresh()
    eq(#ns.Profit.Rows('C1', { kind = 'Alchemy' }), 2)
    eq(#ns.Profit.Rows('C1', { kind = 'FirstAid' }), 1)               -- the book says First Aid, the kind is FirstAid
    eq(ns.Profit.Rows('C1', { search = 'potion b' })[1].recipeID, 102)
    eq(#ns.Profit.Rows('C1', { search = 'alchemy' }), 2)              -- the profession is searched too
    eq(#ns.Profit.Rows('C1', { search = 'zzz' }), 0)
end)

test('only the recipes of the character: by recipe ID first, then by name, and unread professions are reported', function()
    local ns = fresh()
    local rows, info = ns.Profit.Rows('C1', { mine = true })
    eq(#rows, 0); eq(#info.unread, 2); eq(info.unread[1], 'Alchemy'); eq(info.unread[2], 'FirstAid')   -- nothing was ever read
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Potion B' }, 1, { 101 })   -- the ID 101 is learned, and the name of 102
    rows, info = ns.Profit.Rows('C1', { mine = true })
    eq(#rows, 2); eq(rows[1].recipeID, 101); eq(rows[2].recipeID, 102)
    eq(#info.unread, 1); eq(info.unread[1], 'FirstAid')
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Potion A' }, 1)            -- an older record without IDs: names only
    rows = ns.Profit.Rows('C1', { mine = true, kind = 'Alchemy' })
    eq(#rows, 1); eq(rows[1].recipeID, 101)
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 1, { 999 })               -- read, nothing learned that is in the book
    eq(#ns.Profit.Rows('C1', { mine = true, kind = 'Alchemy' }), 0)
    eq(ns.Profit.Learned('C1', 'Alchemy', 101, 'Potion A'), false); eq(ns.Profit.Learned('C1', 'FirstAid', 103, 'Bandage'), nil)
end)

test('products on a thin auction market are hidden when asked, and counted', function()
    local ns = fresh()
    ns.AuctionScan.Price = function(id)
        local prices = { [1] = { 100, 9 }, [2] = { 50, 9 }, [5001] = { 1000, 1 }, [5002] = { 80, 2 } }
        local p = prices[id]
        return p and { min = p[1], n = p[2] } or nil
    end
    local rows, info = ns.Profit.Rows('C1', {})
    eq(#rows, 3); eq(info.thinHidden, 0)                              -- no limit: everything
    rows, info = ns.Profit.Rows('C1', { minAuctions = 3 })
    eq(#rows, 1); eq(rows[1].recipeID, 103); eq(info.thinHidden, 2)  -- both potions rest on one or two auctions
    rows, info = ns.Profit.Rows('C1', { minAuctions = 2 })
    eq(#rows, 2); eq(info.thinHidden, 1)                              -- two auctions pass a limit of two
    -- a product the vendor pays more for is not a thin market: the auction does not decide
    ns.AuctionScan.Price = function(id) return ({ [1] = { 100, 9 }, [5003] = { 100, 1 } })[id] and { min = ({ [1] = 100, [5003] = 100 })[id], n = ({ [1] = 9, [5003] = 1 })[id] } or nil end
    rows = ns.Profit.Rows('C1', { minAuctions = 3, kind = 'FirstAid' })
    eq(#rows, 1); eq(rows[1].product.best, 'vendor')                  -- the bandage sells to the vendor for 200
end)

test('recipes the profession windows showed and the book lacks are listed too, and the book wins for the same recipe', function()
    local ns = fresh()
    ns.db.recipeExtra = {
        [900] = { out = 5001, profession = 'Alchemy', reagents = { { 2, 1 } } },     -- not in the book: product 5001 for 50 copper of materials
        [101] = { out = 7777, profession = 'Alchemy', reagents = { { 1, 1 } } },     -- also in the book: ignored
        [901] = { profession = 'Alchemy' },                                            -- damaged: ignored
    }
    local rows, info = ns.Profit.Rows('C1', {})
    eq(#rows, 4); eq(info.looked, 4)
    local added
    for _, row in ipairs(rows) do if row.recipeID == 900 then added = row end end
    assert(added); eq(added.fromWindow, true); eq(added.profit, 900); eq(added.name, 'Item5001')
    eq(added.profession, 'Alchemy'); eq(added.kind, 'Alchemy')
    for _, row in ipairs(rows) do if row.recipeID == 101 then eq(row.fromWindow, nil); eq(row.productID, 5001) end end
    eq(#ns.Profit.Rows('C1', { kind = 'Alchemy' }), 3)
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 1, { 900 })
    local mine = ns.Profit.Rows('C1', { mine = true, kind = 'Alchemy' })
    eq(#mine, 1); eq(mine[1].recipeID, 900)                                           -- learned by recipe ID
end)

test('the professions with recipes are those of the installed addons, and the extras count', function()
    local ns = fresh()
    local kinds = ns.Profit.Kinds(); eq(#kinds, 2); eq(kinds[1], 'Alchemy'); eq(kinds[2], 'FirstAid')
    ns.db.recipeExtra = { [900] = { out = 5001, profession = 'Mining', reagents = { { 2, 1 } } } }
    ns.Catalog.productCache = nil
    eq(#ns.Profit.Kinds(), 2)                                          -- Mining is not installed: its recipe is not carried
    ns.Catalog.RegisterModule({ id = 'Mining', label = 'Mining', items = {}, recipes = {} })
    kinds = ns.Profit.Kinds(); eq(#kinds, 3); eq(kinds[3], 'Mining')
    ns.Catalog.modules = {}; ns.Catalog.bookCache = nil
    eq(#ns.Profit.Kinds(), 0)
end)

test('without a recipe book or prices the list is empty or unpriced, never invented', function()
    local ns = fresh()
    ns.Catalog.modules = {}; ns.Catalog.bookCache = nil
    local rows, info = ns.Profit.Rows('C1', {}); eq(#rows, 0); eq(info.looked, 0)      -- no profession addon installed
    ns = fresh(); ns.AuctionScan.Price = function() return nil end
    rows = ns.Profit.Rows('C1', {})
    for _, row in ipairs(rows) do eq(row.profit, nil) end
    eq(ns.Profit.Name(7, 5003), 'Bandage'); eq(ns.Profit.Name(7, 0), 'Item0')
    C_Item.GetItemInfo = function() return nil end
    eq(ns.Profit.Name(7, 0), 'Recipe 7')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS profit ' .. #tests .. ' checks')
