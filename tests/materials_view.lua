local passed = 0
local function test(name, fn) local ok, err = pcall(fn); assert(ok, name .. ': ' .. tostring(err)); passed = passed + 1 end
local function eq(a, b) assert(a == b, tostring(a) .. ' != ' .. tostring(b)) end

local Style = { cyan = 'cyan', violet = 'violet', gray = 'gray' }
assert(loadfile('tests/style_stub.lua'))()(Style)
Style.Count = function(value, field) return Style.Text(field, value) end
Style.ItemName = function(id) return Style.Text('white', 'Item ' .. id) end
Style.Skill = function(rank, max) return rank .. '/' .. max end
Style.SkillColor = function() return 'skill' end

local held = { [2770] = { bags = 5, bank = 10 }, [2771] = { bags = 0, bank = 0 }, [765] = { bags = 3 }, [999] = { bags = 0, bank = 2 } }
local ns = {
    Style = Style, settings = { showBank = true },
    Items = { [2770] = { group = 'Mining' }, [2771] = { group = 'Mining' }, [765] = { group = 'Herbalism' }, [999] = { group = 'Auction' } },
    Catalog = { List = function() return { 765, 999, 2770, 2771 } end, Group = function(record) return record.group end },
    ItemName = function(id) return ({ [2770] = 'Copper Ore', [2771] = 'Tin Ore', [765] = 'Silverleaf', [999] = 'Zeta' })[id] end,
    inventory = { Get = function(_, id)
        local c = held[id] or {}
        return { bags = c.bags, bank = c.bank, bankState = id == 0 and 'cached' or 'cached' }
    end },
    Tooltips = { BankObservation = function() return 'Bank as seen 2026-11-28 10:00' end },
    Professions = { Rows = function()
        return { { name = 'Cooking', rank = 40, maxRank = 75, secondary = true }, { name = 'Mining', rank = 120, maxRank = 150 } }
    end },
    Nav = {},
    IsPublic = function() return true end,
}
assert(loadfile('TitanGatheredForever/Navigation.lua'))('TitanGatheredForever', ns)
assert(loadfile('TitanGatheredForever/ListWindow.lua'))('TitanGatheredForever', ns)
assert(loadfile('TitanGatheredForever/MaterialsView.lua'))('TitanGatheredForever', ns)
local View = ns.MaterialsView
local spec = View.view.spec

local function ids(rows) local list = {} for _, row in ipairs(rows) do list[#list + 1] = row.itemID end return table.concat(list, ',') end

test('the tab is the My materials view of the main window', function()
    eq(ns.Nav.views.materials, View.view)
    eq(spec.modes[1].value, 'materials'); eq(spec.modes[2].value, 'professions')
end)

test('the materials list holds what is in the bags or the bank, with the totals', function()
    local rows = View.MaterialRows()
    eq(ids(rows), '765,999,2770')
    local copper = rows[3]
    eq(copper.bags, 5); eq(copper.bank, 10); eq(copper.total, 15); eq(copper.group, 'Mining')
    eq(rows[1].bank, 0)               -- no bank snapshot counts as 0
    local cells = View.MaterialCells(copper)
    eq(#cells, #spec.modes[1].columns)
    eq(cells[3], Style.Text('bags', 5)); eq(cells[5], Style.Text('total', 15))
end)

test('the scope and group combo boxes narrow the list', function()
    View.scope = 'all'
    eq(ids(View.MaterialRows()), '765,999,2770,2771')
    View.group = 'Mining'
    eq(ids(View.MaterialRows()), '2770,2771')
    local groups = {}
    for _, option in ipairs(spec.filters[2].options()) do groups[#groups + 1] = option.label end
    eq(table.concat(groups, ','), 'All groups,Auction,Herbalism,Mining')
    View.scope, View.group = 'held', false
end)

test('sorting by a column and searching by name or group', function()
    local rows = View.MaterialRows()
    eq(View.MaterialSort(rows[3], 5), 15); eq(View.MaterialSort(rows[3], 1), 'copper ore')
    eq(spec.modes[1].search(rows[2]), 'zeta auction')
    table.sort(rows, View.MaterialTie)
    eq(ids(rows), '999,765,2770')
end)

test('the footer sums the items and says how old the bank counts are', function()
    local footer = View.MaterialFooter(nil, View.MaterialRows())
    assert(footer:find(Style.Value(20), 1, true), footer)
    assert(footer:find('Bank as seen', 1, true))
    ns.settings.showBank = false
    assert(View.MaterialFooter(nil, {}):find('switched off', 1, true))
    ns.settings.showBank = true
end)

test('the learned professions view lists skill and share, primary first', function()
    local rows = View.ProfessionRows()
    table.sort(rows, View.ProfessionTie)
    eq(rows[1].name, 'Mining'); eq(rows[2].name, 'Cooking')
    local cells = View.ProfessionCells(rows[1])
    eq(cells[2], '120/150'); eq(cells[3], Style.Value('80%')); eq(cells[4], Style.Value('Primary'))
end)

test('without an inventory the list is empty instead of failing', function()
    local inventory = ns.inventory
    ns.inventory = nil
    eq(#View.MaterialRows(), 0)
    ns.inventory = inventory
end)

test('list rows put the item icon before the name, with the border cropped', function()
    local real = { IsPublic = function() return true end, ItemName = function(id) return 'Copper Ore' end }
    C_Item = { GetItemIconByID = function(id) if id == 2770 then return 135232 end end,
        GetItemInfo = function() return nil, nil, 1 end }
    ITEM_QUALITY_COLORS = { [1] = { hex = '|cffffffff' } }
    assert(loadfile('TitanGatheredForever/Style.lua'))('TitanGatheredForever', real)
    local S = real.Style
    eq(S.ItemIcon(2770), '|T135232:14:14:0:0:64:64:5:59:5:59|t ')
    eq(S.ItemIcon(1), '')
    eq(S.ItemIcon('x'), '')
    assert(S.ItemLabel(2770):find('^|T135232:14:14:0:0:64:64:5:59:5:59|t |cffffffffCopper Ore'), S.ItemLabel(2770))
    C_Spell = { GetSpellTexture = function() return 'Interface\\Icons\\Spell' end }
    eq(S.SpellIcon(3273), '|TInterface\\Icons\\Spell:14:14:0:0:64:64:5:59:5:59|t ')
    C_Spell = { GetSpellTexture = function() error('restricted') end }
    eq(S.SpellIcon(3273), '')
    eq(S.ProfessionIcon('Mining'), '|TInterface\\Icons\\Trade_Mining:14:14:0:0:64:64:5:59:5:59|t ')
    eq(S.ProfessionIcon('Herbalism'), S.ProfessionIcon('Herbs'))
    eq(S.ProfessionIcon('Disenchanting'), S.ProfessionIcon('Enchanting'))
    eq(S.ProfessionIcon('Unknown'), '')
    eq(S.Icon('Interface\\GossipFrame\\ActiveQuestIcon', nil, true), '|TInterface\\GossipFrame\\ActiveQuestIcon:14:14:0:0|t ')
    C_Item, C_Spell, ITEM_QUALITY_COLORS = nil, nil, nil
end)

test('the tab draws the divider of the Options window between the headers and the rows', function()
    eq(spec.divider, nil)   -- the line is drawn on every list tab unless a tab sets divider = false
    local function texture(withAtlas, nativeHeight)
        local t = { calls = {} }
        if withAtlas then
            function t:SetAtlas(name, useSize) self.atlasName, self.useSize = name, useSize end
            function t:GetAtlas() return self.atlasName end
            function t:GetHeight() return nativeHeight end
        end
        for _, m in ipairs({ 'SetPoint', 'SetSize', 'SetColorTexture' }) do t[m] = function(self, ...) self.calls[m] = { ... } end end
        return t
    end
    -- the art keeps its own height (it was squeezed to a thick bar at 4 px in 0.5.183) and gets the list width
    local art = ns.ListWindow.Divider({ CreateTexture = function() return texture(true, 3) end }, 15, -125, 910)
    eq(art.atlasName, 'Options_HorizontalDivider'); eq(art.useSize, true)
    eq(art.calls.SetSize[1], 910); eq(art.calls.SetSize[2], 3); eq(art.calls.SetPoint[5], -125)
    eq(ns.ListWindow.Divider({ CreateTexture = function() return texture(true, 0) end }, 15, -125, 910).calls.SetSize[2], 2)
    -- without the art: the 1 px gold line of the Statistics panel
    local plain = ns.ListWindow.Divider({ CreateTexture = function() return texture(false) end }, 15, -125, 910)
    local color = plain.calls.SetColorTexture
    eq(color[1], 1); eq(color[2], 0.82); eq(color[4], 0.55); eq(plain.calls.SetSize[2], 1)
end)

print('PASS ' .. passed .. ' my materials checks')
