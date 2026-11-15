local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh(settings)
    local ns = { IsPublic = function() return true end, db = { recipeExtra = {} }, settings = settings or { categories = {} } }
    assert(loadfile('TitanGatheredForeverV3/Catalog.lua'))('TitanGatheredForeverV3', ns)
    return ns
end
local function module(ns, id, label, book, items)
    ns.Catalog.RegisterModule({ id = id, label = label, items = items or {}, recipes = {}, book = book })
end

test('only the books of the installed profession addons are in the recipe book', function()
    local ns = fresh()
    eq(next(ns.Catalog.Book()), nil)                                       -- nothing installed: nothing carried
    module(ns, 'Engineering', 'Engineering', { [10] = { 500, { { 1, 2 } } } })
    local book = ns.Catalog.Book()
    eq(book[10][1], 500); eq(book[10][2], 'Engineering'); eq(book[10][3][1][1], 1); eq(book[10][4], 'Engineering')
    eq(book[20], nil)                                                      -- Alchemy is not installed
    module(ns, 'Alchemy', 'Alchemy', { [20] = { 600, { { 2, 1 } } } })
    book = ns.Catalog.Book(); eq(book[20][1], 600); eq(book[10][1], 500)    -- a module installed later joins at once
    module(ns, 'FirstAid', 'First Aid', { [30] = { 700, { { 3, 1 } } } })
    eq(ns.Catalog.Book()[30][2], 'FirstAid'); eq(ns.Catalog.Book()[30][4], 'First Aid')
    module(ns, 'Fishing', 'Fishing', nil)                                   -- a module without a book is fine
    eq(ns.Catalog.Installed('Fishing'), true)
end)

test('a profession that is switched off is not installed for the books, the products and the kinds', function()
    local ns = fresh()
    module(ns, 'Engineering', 'Engineering', { [10] = { 500, { { 1, 2 } } } })
    module(ns, 'Alchemy', 'Alchemy', { [20] = { 600, { { 2, 1 } } } })
    eq(ns.Catalog.Installed('Alchemy'), true); eq(ns.Catalog.Installed('Mining'), false)
    ns.settings.categories.Alchemy = false
    ns.Catalog.Rebuild(ns.settings)                                         -- the settings change rebuilds the catalogue
    eq(ns.Catalog.Installed('Alchemy'), false); eq(ns.Catalog.Book()[20], nil); eq(ns.Catalog.IsProduct(600), false)
    eq(ns.Catalog.IsProduct(500), true)
    local kinds = ns.Catalog.InstalledKinds(); eq(#kinds, 1); eq(kinds[1], 'Engineering')
    ns.settings.categories.Alchemy = nil; ns.Catalog.Rebuild(ns.settings)
    eq(#ns.Catalog.InstalledKinds(), 2); eq(ns.Catalog.IsProduct(600), true)
end)

test('products are the outputs of the installed books and of the recipes taken from the profession windows', function()
    local ns = fresh()
    module(ns, 'Engineering', 'Engineering', { [10] = { 500, { { 1, 2 } } } })
    eq(ns.Catalog.IsProduct(500), true); eq(ns.Catalog.IsProduct(501), false)
    ns.db.recipeExtra = {
        [11] = { out = 501, kind = 'Engineering', profession = 'Engineering', reagents = { { 1, 1 } } },
        [12] = { out = 502, profession = 'First Aid', reagents = { { 3, 1 } } },    -- no kind kept: the label names it, not installed
        [10] = { out = 999, kind = 'Engineering', profession = 'Engineering', reagents = {} },   -- in the book: the book wins
        [13] = { profession = 'Engineering' },                                       -- damaged
    }
    ns.Catalog.productCache = nil
    local extra = ns.Catalog.ExtraRecipes()
    eq(extra[11][1], 501); eq(extra[11][2], 'Engineering'); eq(extra[12], nil); eq(extra[10], nil); eq(extra[13], nil)
    eq(ns.Catalog.IsProduct(501), true); eq(ns.Catalog.IsProduct(502), false); eq(ns.Catalog.IsProduct(999), false)
    module(ns, 'FirstAid', 'First Aid', nil)
    ns.Catalog.productCache = nil
    eq(ns.Catalog.ExtraRecipes()[12][2], 'FirstAid')                                 -- installed later: the label gives the kind
    eq(ns.Catalog.KindOfLabel('First Aid'), 'FirstAid'); eq(ns.Catalog.KindOfLabel('Herbalism'), 'Herbs')
    eq(ns.Catalog.KindOfLabel('Mining'), 'Mining')
end)

test('a module with a book of a wrong shape is refused', function()
    local ns = fresh()
    local ok = pcall(ns.Catalog.RegisterModule, { id = 'X', label = 'X', items = {}, recipes = {}, book = 5 })
    eq(ok, false)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS catalog book ' .. #tests .. ' checks')
