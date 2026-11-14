local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function plain(text) return (tostring(text):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')) end

local function newNs()
    local ns = { IsPublic = function() return true end, characterID = 'C1', db = { recipeMakes = {}, knownRecipes = {} },
        Style = { gold = 'gold', gray = 'gray', green = 'green', white = 'white', red = 'red',
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
    eq(cells[5], '<gray>-</>'); eq(cells[6], 'Auction'); eq(cells[7], '<green>+700c</>*')
    cells = B.Cells(rows[2])                                         -- Potion B: a loss
    eq(cells[1], '<red>Potion B</>'); eq(cells[7], '<red>-24c</>*')
    cells = B.Cells(rows[3])                                         -- Bandage: a material has no price
    eq(cells[1], '<gray>Bandage</>'); eq(cells[3], '<gray>-</>'); eq(cells[5], '200c'); eq(cells[6], 'Vendor')
    eq(cells[7], '<gray>Unknown</>')
    ns.db.recipeMakes[101] = { 1, 1 }                                -- seen in the reagent window: no star any more
    rows = ns.Profit.Rows('C1', {}); eq(B.Cells(rows[1])[7], '<green>+700c</>')
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
    assert(text:find('0 of 0 recipes have a profit.', 1, true))
    ns.db.auction = { at = 1, items = {}, others = {} }
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 1, { 101 }); ns.KnownRecipes.Record('C1', 'FirstAid', {}, 1, {})
    B.Refresh()
    assert(not text:find('No auction prices yet', 1, true)); assert(not text:find('Not read yet', 1, true))
    assert(text:find('1 of 1 recipes have a profit.', 1, true)); assert(text:find('* assumes one item per craft', 1, true))
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
