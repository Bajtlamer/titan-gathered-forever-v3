local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local itemNames = { [100] = 'Recipe: Lesser Healing Potion', [101] = 'Recipe: Elixir of Wisdom', [102] = 'Recipe: Tender Wolf Steak' }
C_Item = { GetItemInfo = function(id) return itemNames[id] end }

local function newNs(seed)
    local ns = { IsPublic = function() return true end, characterID = 'C1', settings = {},
        db = { npcs = {}, knownRecipes = {} },
        Style = { gold = 'gold', gray = 'gray', green = 'green', white = 'white',
            Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end },
        ItemName = function(id) return itemNames[id] or ('Loading ' .. id) end }
    ns.NpcSeed = { npcs = seed }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

local function fresh()
    return newNs({
        [1] = { n = 'Alchemy Trainer', m = 0, x = 10, y = 20, p = 'Alchemy', t = {
            { 2259, 'Elixir of Minor Defense', 100, 1, 0 }, { 3101, 'Lesser Healing Potion', 500, 50, 0 },
            { 3102, 'Journeyman Alchemist', 5000, 50, 0 } } },
        [2] = { n = 'Recipe Vendor', m = 0, x = 11, y = 21, v = {
            { 100, 'Alchemy', 12000, 225 }, { 101, 'Alchemy', 20000, 0 }, { 102, 'Cooking', 300, 0 }, { 103, 'Alchemy', 1, 0 } } },
    })
end

-- One trainer teaching 40 recipes, so the list is longer than one screen.
local function big()
    local spells = {}
    for index = 1, 40 do spells[index] = { 5000 + index, string.format('Spell %02d', index), index * 10, index, 0 } end
    return newNs({ [1] = { n = 'Big Trainer', m = 0, x = 10, y = 20, p = 'Alchemy', t = spells } })
end

-- Permissive stand-ins for frames. Scripts are recorded so tests can fire them.
local function installFrames()
    local all = {}
    local function frame()
        local f = setmetatable({}, { __index = function(_, key)
            if key == 'SetScript' then
                return function(self, name, fn)
                    local scripts = rawget(self, 'scripts') or {}
                    scripts[name] = fn; rawset(self, 'scripts', scripts)
                end
            end
            return function(self, ...)
                if key:match('^Create') then return frame() end
                if key == 'GetNumPoints' then return 0 end
                return self
            end
        end })
        all[#all + 1] = f
        return f
    end
    CreateFrame = function() local f = frame(); f.TitleText = frame(); return f end
    local shown = { lines = {}, doubles = {} }
    function shown:SetOwner() end
    function shown:AddLine(text) self.lines[#self.lines + 1] = text end
    function shown:AddDoubleLine(left, right) self.doubles[#self.doubles + 1] = { left, right } end
    function shown:Show() self.visible = true end
    function shown:Hide() self.visible = false end
    UIParent, UISpecialFrames, GameTooltip = frame(), {}, shown
    return all, shown
end
local function scriptsOf(f) return rawget(f, 'scripts') or {} end

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

test('a profession filter limits recipes and the professions reported as unread', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 10)
    local rows, unread = ns.NpcSources.Unlearned('C1', false, 'Alchemy')
    for _, row in ipairs(rows) do eq(row.kind, 'Alchemy') end
    eq(#rows, 3); eq(#unread, 0)   -- Cooking is unread but filtered out
    rows, unread = ns.NpcSources.Unlearned('C1', false, 'Cooking')
    eq(#rows, 0); eq(#unread, 1); eq(unread[1], 'Cooking')
    local all = ns.NpcSources.RecipeKinds
    eq(#all, 9); eq(all[1], 'Alchemy'); eq(all[#all], 'Tailoring')
end)

test('browser cells, hover tooltip and profession filter', function()
    local ns = fresh()
    ns.KnownRecipes.Record('C1', 'Alchemy', { 'Elixir of Minor Defense' }, 10)
    local all, shown = installFrames()
    assert(loadfile('TitanGatheredForeverV3/RecipeBrowser.lua'))('TitanGatheredForeverV3', ns)
    local rows = ns.NpcSources.Unlearned('C1', false)
    local cells = ns.RecipeBrowser.Cells(rows[1])
    eq(cells[1], 'Lesser Healing Potion'); eq(cells[2], 'Alchemy'); eq(cells[3], '50'); eq(cells[4], 'Trainer')
    eq(cells[5], '<green>Alchemy Trainer</> (+1)'); eq(cells[6], '5s')
    ns.RecipeBrowser.Show()
    ns.RecipeBrowser.Refresh()
    -- Hovering the NPC column of a row shows where the NPCs are; leaving hides the tooltip.
    local hit
    for _, f in ipairs(all) do
        if scriptsOf(f).OnEnter and not hit then hit = f end
    end
    assert(hit, 'no hover region for the NPC column')
    scriptsOf(hit).OnEnter(hit)
    eq(shown.visible, true); eq(shown.lines[1], '<white>Lesser Healing Potion</>')
    eq(shown.doubles[1][1], '<green>Alchemy Trainer</> <gray>(Trainer)</>')
    scriptsOf(hit).OnLeave(hit); eq(shown.visible, false)
    -- Choosing a profession restarts the list and is passed to the model.
    local seen
    local original = ns.NpcSources.Unlearned
    ns.NpcSources.Unlearned = function(character, vendorOnly, kind) seen = { character, vendorOnly, kind }; return original(character, vendorOnly, kind) end
    ns.RecipeBrowser.offset = 3
    ns.RecipeBrowser.SetKind('Cooking')
    eq(ns.RecipeBrowser.kind, 'Cooking'); eq(ns.RecipeBrowser.offset, 0); eq(seen[3], 'Cooking')
    ns.RecipeBrowser.SetKind(nil)
    eq(ns.RecipeBrowser.kind, nil); eq(seen[3], nil)
end)

test('the visible range reads naturally', function()
    local ns = fresh()
    installFrames()
    assert(loadfile('TitanGatheredForeverV3/RecipeBrowser.lua'))('TitanGatheredForeverV3', ns)
    local B = ns.RecipeBrowser
    eq(B.RangeText(0, 40), 'Showing 1-16 of 40'); eq(B.RangeText(24, 40), 'Showing 25-40 of 40')
    eq(B.RangeText(0, 5), 'Showing 1-5 of 5'); eq(B.RangeText(0, 0), 'No recipes')
    eq(B.Clamp(-4, 40), 0); eq(B.Clamp(99, 40), 24); eq(B.Clamp(7.6, 40), 8); eq(B.Clamp(5, 10), 0)
end)

test('the list scrolls with the mouse wheel and a scroll bar instead of paging', function()
    local ns = big()
    ns.KnownRecipes.Record('C1', 'Alchemy', {}, 10)
    local all = installFrames()
    assert(loadfile('TitanGatheredForeverV3/RecipeBrowser.lua'))('TitanGatheredForeverV3', ns)
    local B = ns.RecipeBrowser
    B.Show()
    local w = B.window
    eq(B.total, 40); eq(B.offset, 0)
    eq(w.lines[1].row.name, 'Spell 01'); eq(w.lines[16].row.name, 'Spell 16')
    B.Scroll(3); eq(B.offset, 3); eq(w.lines[1].row.name, 'Spell 04'); eq(w.lines[16].row.name, 'Spell 19')
    B.Scroll(100); eq(B.offset, 24); eq(w.lines[16].row.name, 'Spell 40')   -- cannot scroll past the end
    B.Scroll(-100); eq(B.offset, 0)                                       -- nor before the start
    -- Mouse wheel: scrolling down (negative delta) moves the list by three rows.
    scriptsOf(w).OnMouseWheel(w, -1); eq(B.offset, 3)
    scriptsOf(w).OnMouseWheel(w, 1); eq(B.offset, 0)
    -- Dragging the scroll bar sets the offset.
    local slider
    for _, f in ipairs(all) do if scriptsOf(f).OnValueChanged then slider = f end end
    assert(slider, 'no scroll bar')
    scriptsOf(slider).OnValueChanged(slider, 10); eq(B.offset, 10); eq(w.lines[1].row.name, 'Spell 11')
    -- Changing the filter or the source mode returns to the top.
    B.SetKind('Alchemy'); eq(B.offset, 0)
    B.Scroll(5); B.SetKind('Cooking'); eq(B.offset, 0); eq(rawget(w.lines[1], 'row'), nil)
    B.SetKind(nil); B.Scroll(5)
    scriptsOf(w.filter).OnClick(w.filter); eq(B.offset, 0)
    eq(B.vendorOnly, true)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS recipe browser ' .. #tests .. ' checks')
