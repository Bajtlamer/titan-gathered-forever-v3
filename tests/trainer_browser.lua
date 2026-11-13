local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function newNs()
    local ns = { IsPublic = function() return true end, characterID = 'C1', settings = {},
        db = { npcs = {}, knownRecipes = {} },
        Style = { gold = 'gold', gray = 'gray', green = 'green', white = 'white', red = 'red',
            Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end },
        ItemName = function(id) return 'Item ' .. id end }
    ns.NpcSeed = { npcs = {
        [1] = { n = 'Alchemy Trainer', m = 0, x = 10, y = 20, p = 'Alchemy', t = { { 3101, 'Lesser Healing Potion', 500, 50, 0 } } },
        [2] = { n = 'Mining Trainer', m = 0, x = 11, y = 21, p = 'Mining', t = { { 2575, 'Mining', 100, 1, 0 } } },
        [3] = { n = 'Another Alchemist', m = 1, x = 12, y = 22, p = 'Alchemy', t = { { 3101, 'Lesser Healing Potion', 500, 50, 0 } } },
        [4] = { n = 'Recipe Vendor', m = 0, x = 11, y = 21, v = { { 100, 'Alchemy', 12000, 225 } } },
    } }
    assert(loadfile('TitanGatheredForeverV3/KnownRecipes.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TitanGatheredForeverV3', ns)
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
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. ' ' .. right end
    function tip:Show() self.visible = true end
    function tip:Hide() self.visible = false end
    UIParent, UISpecialFrames, GameTooltip = frame(), {}, tip
    return tip
end
local function scriptsOf(f) return rawget(f, 'scripts') or {} end

CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function() return x, y end } end
C_Map = { GetMapPosFromWorldPos = function(continent, v) return continent == 0 and 1429 or 1411, CreateVector2D(v.x / 100, v.y / 100) end,
    GetMapInfo = function(id) return { name = 'Zone ' .. id } end }

test('trainers are listed by status and profession, with zone and coordinates', function()
    local ns = newNs()
    local rows = ns.NpcSources.Trainers('unvisited')
    eq(#rows, 3)                                          -- the vendor is not a trainer
    eq(rows[1].name, 'Another Alchemist'); eq(rows[1].zone, 'Zone 1411')   -- profession, then zone, then name
    eq(rows[2].name, 'Alchemy Trainer'); eq(rows[2].zone, 'Zone 1429'); eq(rows[2].visited, false)
    eq(string.format('%.0f %.0f', rows[2].x, rows[2].y), '10 20')
    eq(rows[3].kind, 'Mining')
    ns.db.npcs[1] = { name = 'Alchemy Trainer', mapID = 1429, x = 0.5, y = 0.5, lastSeen = 1000, trainer = {} }
    eq(#ns.NpcSources.Trainers('unvisited'), 2)
    eq(#ns.NpcSources.Trainers('visited'), 1); eq(ns.NpcSources.Trainers('visited')[1].lastSeen, 1000)
    eq(#ns.NpcSources.Trainers('all'), 3)
    eq(#ns.NpcSources.Trainers('all', 'Alchemy'), 2)
    ns.db.npcs[3] = { name = 'Another Alchemist', mapID = 1411, x = 0.1, y = 0.1, lastSeen = 5 } -- merchant visit only
    eq(#ns.NpcSources.Trainers('unvisited'), 2)           -- its trainer window was never recorded
end)

test('the list shows status, search and the profession filter', function()
    local ns = newNs()
    installFrames()
    assert(loadfile('TitanGatheredForeverV3/Navigation.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/TrainerBrowser.lua'))('TitanGatheredForeverV3', ns)
    local B = ns.TrainerBrowser
    B.Show()
    eq(B.total, 3)
    local cells = B.Cells(ns.NpcSources.Trainers('unvisited')[2])
    eq(cells[1], '<green>Alchemy Trainer</>'); eq(cells[3], 'Zone 1429'); eq(cells[4], '10.0, 20.0'); eq(cells[5], 'Not visited')
    B.searchText = 'mining'; B.Refresh(); eq(B.total, 1)
    B.searchText = 'zone 1411'; B.Refresh(); eq(B.total, 1)  -- the zone is searchable too
    B.searchText = nil; B.kind = 'Alchemy'; B.Refresh(); eq(B.total, 2)
    B.kind = nil; B.status = 'visited'; B.Refresh(); eq(B.total, 0); eq(B.RangeText(0, 0), 'No trainers')
    eq(B.Cells({ npcID = 9, name = 'X', kind = 'Mining', visited = true, lastSeen = nil })[5], '<green>Visited</>')
    eq(B.Cells({ npcID = 9, name = 'X', kind = 'Mining' })[4], 'Unknown')
end)

test('clicking a row opens the map at the trainer and marks it', function()
    local ns = newNs()
    local tip = installFrames()
    GetTime = function() return 100 end
    local opened, updates = {}, 0
    OpenWorldMap = function(id) opened[#opened + 1] = id end
    ns.Map = { Update = function() updates = updates + 1 end }
    assert(loadfile('TitanGatheredForeverV3/Navigation.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/TrainerBrowser.lua'))('TitanGatheredForeverV3', ns)
    local B = ns.TrainerBrowser
    B.Show()
    local line = B.window.lines[2]                        -- Alchemy Trainer (the first row is Another Alchemist)
    scriptsOf(line).OnClick(line)
    eq(opened[1], 1429); eq(ns.NpcSources.IsHighlighted(1), true); eq(updates, 1)
    scriptsOf(line).OnClick(line)                         -- the same trainer again clears the mark
    eq(ns.NpcSources.HasHighlight(), false); eq(#opened, 2)
    scriptsOf(line).OnEnter(line)                         -- hover shows what the trainer teaches
    eq(tip.visible, true); eq(tip.lines[1], '<gold>Alchemy Trainer</>')
    C_Map = nil                                           -- without a position the continent is the fallback
    B.Refresh(); line = B.window.lines[1]                 -- all zones unknown: sorted by name
    scriptsOf(line).OnClick(line)
    eq(opened[#opened], 1415)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS trainer browser ' .. #tests .. ' checks')
