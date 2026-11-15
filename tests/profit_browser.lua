local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function plain(text) return (tostring(text):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')) end

local function newNs()
    local ns = { IsPublic = function() return true end, characterID = 'C1', db = { recipeMakes = {}, knownRecipes = {} },
        Style = { gold = 'gold', gray = 'gray', green = 'green', white = 'white', red = 'red', orange = 'orange',
            Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end } }
    ns.RecipeBook = { complete = false, professions = { 'Alchemy', 'First Aid' }, recipes = {
        [101] = { 5001, 1, { { 1, 2 }, { 2, 1 } } },
        [102] = { 5002, 1, { { 1, 1 } } },
        [103] = { 5003, 2, { { 3, 1 } } },
    } }
    ns.AuctionScan = { Price = function(id)
        local prices = { [1] = 100, [2] = 50, [5001] = 1000, [5002] = 80 }
        return prices[id] and { min = prices[id], n = 3 } or nil
    end }
    ns.NpcSources = { VendorsFor = function() return {} end, Label = function(kind) return kind == 'FirstAid' and 'First Aid' or kind end,
        Coin = function(copper) return copper .. 'c' end }
    C_Item = { GetItemInfo = function(id) if id == 5003 then return 'Bandage', nil, 1, 1, 1, 't', 's', 1, '', 1, 200 end return 'Item' .. id end }
    C_Spell = { GetSpellInfo = function(id) return ({ [101] = { name = 'Potion A' }, [102] = { name = 'Potion B' } })[id] end }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Economy.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Profit.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Navigation.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/ProfitBrowser.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

local function installFrames()
    local function frame()
        return setmetatable({}, { __index = function(_, key)
            if key == 'SetScript' then
                return function(self, name, fn)
                    local scripts = rawget(self, 'scripts') or {}
                    scripts[name] = fn; rawset(self, 'scripts', scripts)
                end
            end
            return function(self)
                if key:match('^Create') then return frame() end
                if key == 'GetNumPoints' then return 0 end
                return self
            end
        end })
    end
    CreateFrame = function() local f = frame(); f.TitleText = frame(); return f end
    local tip = { lines = {} }
    function tip:SetOwner() end
    function tip:SetItemByID(id) self.item = id end
    function tip:Show() self.visible = true end
    function tip:Hide() self.visible = false end
    UIParent, UISpecialFrames, GameTooltip = frame(), {}, tip
    return tip
end
local function scriptsOf(f) return rawget(f, 'scripts') or {} end

test('rows show the materials, the auction after the fee, the vendor, where to sell and the colored profit', function()
    local ns = newNs()
    installFrames()
    local B = ns.ProfitBrowser
    B.mine = false
    local rows = ns.Profit.Rows('C1', {})
    local cells = B.Cells(rows[1])                                   -- Potion A: profit 700, one per craft assumed
    eq(cells[1], '<green>Potion A</>'); eq(cells[2], 'Alchemy'); eq(cells[3], '250c'); eq(cells[4], '950c')
    eq(cells[5], '3'); eq(cells[6], '<gray>-</>'); eq(cells[7], 'Auction'); eq(cells[8], '<green>+700c</>*')
    cells = B.Cells(rows[2])                                         -- Potion B: a loss
    eq(cells[1], '<red>Potion B</>'); eq(cells[8], '<red>-24c</>*')
    cells = B.Cells(rows[3])                                         -- Bandage: a material has no price
    eq(cells[1], '<gray>Bandage</>'); eq(cells[3], '<gray>-</>'); eq(cells[4], '<gray>-</>'); eq(cells[5], '<gray>-</>')
    eq(cells[6], '200c'); eq(cells[7], 'Vendor'); eq(cells[8], '<gray>Unknown</>')
    ns.db.recipeMakes[101] = { 1, 1 }                                -- seen in the reagent window: no star any more
    rows = ns.Profit.Rows('C1', {}); eq(B.Cells(rows[1])[8], '<green>+700c</>')
    ns.db.recipeMakes[101] = { 2, 4 }                                -- a craft makes three on average: the name says so
    rows = ns.Profit.Rows('C1', {}); eq(B.Cells(rows[1])[1], '<green>Potion A</><gray> x3</>')
    ns.db.recipeMakes[101] = { 1, 2 }; rows = ns.Profit.Rows('C1', {}); eq(B.Cells(rows[1])[1], '<green>Potion A</><gray> x1.5</>')
end)

test('a few auctions behind a price are marked, and thin markets are hidden unless all markets are asked for', function()
    local ns = newNs()
    installFrames()
    ns.AuctionScan.Price = function(id)
        local prices = { [1] = { 100, 9 }, [2] = { 50, 9 }, [5001] = { 1000, 1 }, [5002] = { 80, 999 } }
        local p = prices[id]
        return p and { min = p[1], n = p[2] } or nil
    end
    local B = ns.ProfitBrowser
    local rows = ns.Profit.Rows('C1', {})
    eq(#rows, 3)
    eq(B.Cells(rows[1])[5], '<orange>1</>')                          -- one auction: thin
    local other
    for _, row in ipairs(rows) do if row.recipeID == 102 then other = row end end
    eq(B.Cells(other)[5], '999+')                                    -- capped number of auctions
    B.mine = false
    B.Show()
    eq(B.minAuctions, 3); eq(B.total, 2)                              -- the one-auction product is hidden by default
    eq(B.info.thinHidden, 1)
    B.minAuctions = 0; B.Refresh(); eq(B.total, 3); eq(B.info.thinHidden, 0)
    eq(ns.Profit.Thin({ best = 'vendor', auction = { n = 1 } }, 3), false)   -- the vendor pays more: the auction does not matter
    eq(ns.Profit.Thin({ best = 'auction', auction = { n = 2 } }, 3), true)
    eq(ns.Profit.Thin({ best = 'auction', auction = { n = 3 } }, 3), false)
    eq(ns.Profit.Thin({ best = 'auction', auction = { n = 1 } }, 0), false)  -- all markets
    eq(ns.Profit.Thin(nil, 3), false)
end)

test('the window lists recipes, filters, searches and scrolls', function()
    local ns = newNs()
    installFrames()
    local B = ns.ProfitBrowser
    B.Show()
    eq(B.mine, false)                                                -- nothing was read for the character: all recipes
    eq(B.total, 3); eq(rawget(ns, 'x'), nil)
    eq(B.window.lines[1].row.recipeID, 101); eq(rawget(B.window.lines[4], 'row'), nil)
    B.kind = 'FirstAid'; B.Refresh(); eq(B.total, 1)
    B.kind = nil; B.searchText = 'potion b'; B.Refresh(); eq(B.total, 1)
    B.searchText = nil
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 1, { 101 })
    B.mine = true; B.Refresh(); eq(B.total, 1); eq(B.window.lines[1].row.recipeID, 101)
    eq(B.RangeText(0, 0), 'No recipes'); eq(B.RangeText(16, 40), 'Showing 17-32 of 40'); eq(B.Clamp(99, 20), 4)
end)

test('the footer asks for a scan when there are no prices and says which professions were not read', function()
    local ns = newNs()
    installFrames()
    local B = ns.ProfitBrowser
    local text
    local original = B.window
    B.Show()
    local footer = B.window.footer
    function footer:SetText(value) text = value end
    B.mine = true; B.Refresh()
    assert(text:find('No auction prices yet: scan the auction house', 1, true))
    assert(text:find('Not read yet for this character: Alchemy, First Aid. Open each profession window once.', 1, true))
    assert(text:find('0 of 0 recipes could be priced, 0 of them earn a profit.', 1, true))
    ns.db.auction = { at = 1, items = {}, others = {} }
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 1, { 101 }); ns.KnownRecipes.Record('C1', 'FirstAid', {}, 1, {})
    B.Refresh()
    assert(not text:find('No auction prices yet', 1, true)); assert(not text:find('Not read yet', 1, true))
    assert(text:find('1 of 1 recipes could be priced, 1 of them earn a profit.', 1, true)); assert(text:find('* assumes one item per craft', 1, true))
    ns.db.recipeExtra = { [900] = { out = 5001, profession = 'Alchemy', reagents = { { 2, 1 } } } }
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 1, { 101, 900 }); B.Refresh()
    assert(text:find('1 of these recipes are not in the recipe table; they were taken from your profession windows.', 1, true))
end)

test('a click opens the reagents of the recipe and hovering shows the product', function()
    local ns = newNs()
    local tip = installFrames()
    local shown = {}
    ns.CraftingView = { Show = function(id, operations) shown[#shown + 1] = { id, operations } end }
    local B = ns.ProfitBrowser
    B.Show()
    local line = B.window.lines[2]                                   -- Potion B
    scriptsOf(line).OnClick(line); eq(shown[1][1], 102); eq(shown[1][2], 1)
    scriptsOf(line).OnEnter(line); eq(tip.item, 5002); eq(tip.visible, true)
    scriptsOf(line).OnLeave(line); eq(tip.visible, false)
end)

test('the tab strip has the profit tab and opens this window', function()
    local ns = newNs()
    installFrames()
    local found
    for _, tab in ipairs(ns.Nav.tabs) do if tab.id == 'profit' then found = tab end end
    assert(found); eq(found.label, 'Crafting profit')
    ns.Nav.Open('profit'); assert(ns.ProfitBrowser.window)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS profit browser ' .. #tests .. ' checks')
