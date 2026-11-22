-- Titan Gathered Forever: Discovery, milestone 5: the overview window, its view model and the Titan Panel statistics.
local FOLDER = 'TitanGatheredForever_Discovery'
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function has(text, part) assert(tostring(text):find(part, 1, true), 'missing "' .. part .. '" in: ' .. tostring(text)) end
local function lacks(text, part) assert(not tostring(text):find(part, 1, true), 'unexpected "' .. part .. '" in: ' .. tostring(text)) end

local function readAll(path)
    local file = assert(io.open(path, 'r')); local text = file:read('*a'); file:close(); return text
end
local function manifestFiles()
    local files = {}
    for line in readAll(FOLDER .. '/' .. FOLDER .. '.toc'):gmatch('[^\r\n]+') do
        if line:match('%.lua$') then files[#files + 1] = (line:gsub('\\', '/')) end
    end
    return files
end
local styleStub = dofile('tests/style_stub.lua')

local function widget(kind)
    local object = { kind = kind, shown = false, events = {} }
    return setmetatable(object, { __index = function(_, key)
        return function(self, ...)
            if key:sub(1, 6) == 'Create' then return widget(key) end
            return self
        end
    end })
end

local frames
local function installFrames()
    frames = {}
    _G.CreateFrame = function(kind, name, _, template)
        local frame = widget(kind)
        frame.name = name
        function frame:SetText(text) self.text = text end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:IsShown() return self.shown end
        function frame:SetScript(script, fn) self[script] = fn end
        function frame:CreateFontString() local fs = widget('FontString'); function fs:SetText(t) self.text = t end; return fs end
        if template == 'BasicFrameTemplateWithInset' then frame.TitleText = widget('Title'); function frame.TitleText:SetText(t) self.text = t end end
        frames[#frames + 1] = frame
        return frame
    end
    _G.UIParent = widget('UIParent')
    _G.UISpecialFrames = {}
    _G.date = function(format, time) return 'D' .. tostring(time) end
end

local function fakeCore()
    local core = { Style = {} }
    styleStub(core.Style)
    core.Style.cyan, core.Style.orange, core.Style.gray, core.Style.violet = 'cyan', 'orange', 'gray', 'violet'
    core.Items = { [765] = {}, [2770] = {}, [4603] = {} }
    core.Catalog = { Get = function(id) return core.Items[id] end, Modules = function() return { { id = 'Mining' } } end }
    core.NpcSeed = { npcs = {
        [223] = { n = 'Dan Golthas', t = { { 2338, 'Handstitched Leather Pants', 50, 15, 0 } } },
        [340] = { n = 'Kendor Kabonka', v = { { 728, 'Cooking', 200, 75 } } },
        [999] = { n = 'Never Met', v = { { 1, 'Cooking', 10, 1 } } } } }
    core.DataMetadata = { targetBuild = '70790' }
    core.Economy = { Coin = function(copper) return '<' .. tostring(copper) .. 'c>' end }
    core.ItemName = function(id) return 'Item' .. id end
    core.Nav = {
        Dropdown = function(parent, x, y, width, options, get, set)
            local d = { options = options, get = get, set = set }
            d.Sync = function() d.synced = (d.synced or 0) + 1 end
            return d
        end,
        Scrollbar = function() return widget('Slider') end,
        SyncScrollbar = function() end,
        Draggable = function() end,
    }
    return core
end

local function load(options)
    options = options or {}
    installFrames()
    _G.TitanGatheredForeverV3 = fakeCore()
    local ns = { printed = {} }
    for _, file in ipairs(manifestFiles()) do
        if file ~= 'Start.lua' then assert(loadfile(FOLDER .. '/' .. file))(FOLDER, ns) end
    end
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.env = { now = function() return 5000 end, build = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end,
        date = function(_, time) return 'D' .. tostring(time) end, coreVersion = function() return '0.5.108' end, moduleVersion = '0.1.0',
        clock = function() return 0 end, inCombat = function() return false end }
    ns.api = { Now = function() return 1000 end }
    ns.db = ns.Database.Init(nil, '0.1.0', 1000)
    ns.runtime = {}
    ns.state.build = '70862'
    ns.frame = { events = {}, RegisterEvent = function() end, UnregisterEvent = function() end }
    return ns
end

local function plain(text) return (tostring(text):gsub('|cgold', ''):gsub('|cwhite', ''):gsub('|cgreen', ''):gsub('|ccyan', ''):gsub('|corange', ''):gsub('|cgray', ''):gsub('|cviolet', ''):gsub('|r', '')) end
local function printed(ns)
    local lines = {}
    for _, line in ipairs(ns.printed) do lines[#lines + 1] = plain(line) end
    return table.concat(lines, '\n')
end

-- A database with a few records of every state, compared.
local function compared()
    local ns = load()
    local data = ns.db.data
    data.loot[765] = { name = 'Silverleaf', seen = 2, last = 3000, firstBuild = '70862', lastBuild = '70862' }
    data.loot[12345] = { name = 'Strange Herb', seen = 1, last = 4000, firstBuild = '70790', lastBuild = '70862' }
    data.npcs[223] = { name = 'Dan the Elder', seen = 1 }
    data.npcs[777] = { name = 'Hogger', seen = 1 }
    data.vendors[340] = { goods = { [728] = { price = 250 } }, taught = {} }
    data.skills.Inscription = { rank = 1, seen = 1 }
    data.areas['1|A|A||'] = { zone = 'A', seen = 1 }
    ns.results = ns.Compare.Run(ns.db, assert(ns.Baseline.FromCore()))
    return ns
end

test('without a comparison there are no rows and the header says how to get them', function()
    local ns = load()
    eq(ns.View.Rows(), nil)
    has(plain(ns.View.Header()), '/tgfd compare')
end)

test('by default the rows are what is new or different, in category order', function()
    local ns = compared()
    local rows = ns.View.Rows()
    local keys = {}
    for _, row in ipairs(rows) do keys[#keys + 1] = row.category .. ':' .. tostring(row.key) end
    eq(table.concat(keys, ','), 'loot:12345,npcs:223,vendors:340,skills:Inscription')
end)

test('the show filter, the category filter and the search narrow the rows', function()
    local ns = compared()
    ns.View.show = 'new'
    eq(#ns.View.Rows(), 2)
    ns.View.show = 'different'
    eq(#ns.View.Rows(), 2)
    ns.View.show = 'unbaselined'
    eq(#ns.View.Rows(), 2)                       -- npc 777 and the area
    ns.View.show = 'unchanged'
    eq(#ns.View.Rows(), 1)
    ns.View.show = 'all'
    eq(#ns.View.Rows(), 7)
    ns.View.category = 'loot'
    eq(#ns.View.Rows(), 2)
    ns.View.category = false
    ns.View.search = 'hogger'
    eq(#ns.View.Rows(), 1)
    ns.View.search = 'Vendors and trainers'     -- the category label counts as text
    eq(#ns.View.Rows(), 1)
    ns.View.search = '12345'
    eq(#ns.View.Rows(), 1)
end)

test('not yet seen lists the seed NPCs and the catalogue items nobody observed, with names', function()
    local ns = compared()
    ns.View.show = 'notseen'
    local rows = ns.View.Rows()
    eq(#rows, 3)
    eq(rows[1].category, 'loot'); eq(rows[1].key, 2770); eq(rows[1].name, 'Item2770'); eq(rows[1].state, 'notseen')
    eq(rows[3].category, 'npcs'); eq(rows[3].key, 999); eq(rows[3].name, 'Never Met')
    ns.View.category = 'npcs'
    eq(#ns.View.Rows(), 1)
end)

test('paging clamps the offset and the range text is plain when empty and styled otherwise', function()
    local ns = load()
    eq(ns.View.Clamp(5, 3), 0); eq(ns.View.Clamp(-4, 100), 0)
    eq(ns.View.Clamp(99, 100), 100 - ns.View.ROWS)
    eq(plain(ns.View.RangeText(0, 0)), 'No records')
    eq(plain(ns.View.RangeText(0, 40)), 'Showing 1-' .. ns.View.ROWS .. ' of 40')
end)

test('a row becomes cells with the category, key, name, colored state, count, date and notes', function()
    local ns = compared()
    local rows = ns.View.Rows()
    local cells = ns.View.Cells(rows[1])                -- loot 12345: new, seen on two builds, another build than the baseline
    eq(#cells, 7)
    eq(plain(cells[1]), 'Loot'); eq(plain(cells[2]), '12345'); eq(plain(cells[3]), 'Strange Herb')
    has(cells[4], '|ccyan'); eq(plain(cells[4]), 'New'); eq(plain(cells[5]), '1')
    has(cells[6], '|cgreen'); has(cells[6], 'D4000')
    has(plain(cells[7]), 'other build'); has(plain(cells[7]), 'several builds')
    local different = ns.View.Cells(rows[3])            -- vendors 340
    has(different[4], '|corange'); eq(plain(different[4]), 'Different'); has(plain(different[7]), '1 difference')
    eq(plain(ns.View.Cells({ category = 'npcs', key = 1, state = 'notseen' })[4]), 'Not yet seen')
end)

test('the detail text lists the reason and every difference, prices in game money', function()
    local ns = compared()
    local lines = ns.View.DetailText(ns.View.Rows()[3])
    local text = table.concat(lines, '\n')
    has(text, 'Goods or lessons differ')
    has(text, 'Item728'); has(text, '<200c>'); has(text, '<250c>')
    local trainer = table.concat(ns.View.DetailText({ why = 'x', details = {
        { field = 'cost', name = 'Belt', baseline = 75, observed = 90 }, { field = 'notInSeed', name = 'Vest' },
        { field = 'notTaught', name = 'Pants' }, { field = 'notOffered', itemID = 5 }, { field = 'skill', name = 'Belt', baseline = 25, observed = 30 },
        { field = 'name', baseline = 'A', observed = 'B' } } }), '\n')
    has(trainer, 'Belt'); has(trainer, '<75c>'); has(trainer, '<90c>'); has(trainer, 'Vest'); has(trainer, 'Pants'); has(trainer, 'Item5')
    has(trainer, '25'); has(trainer, '30'); has(trainer, 'A'); has(trainer, 'B')
end)

test('the header names the baseline, the builds and the date of the comparison', function()
    local ns = compared()
    ns.db.compare = { ranAt = 5000, baselineVersion = '0.5.108', targetBuild = '70790', clientBuild = '70862', totals = { new = 2, different = 2 } }
    local header = plain(ns.View.Header())
    has(header, '0.5.108'); has(header, '70790'); has(header, '70862'); has(header, 'D5000'); has(header, 'unverified')
end)

test('the statistics text follows the state: off, paused, blocked, records or the last comparison', function()
    local ns = load()
    eq(ns.Stats.Text(ns.db, ns.runtime), 'off')
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    eq(ns.Stats.Text(ns.db, ns.runtime), '0 records')
    ns.db.data.loot[1] = {}; ns.db.data.areas.a = {}
    eq(ns.Stats.Text(ns.db, ns.runtime), '2 records')
    ns.db.compare = { totals = { new = 12, different = 3 } }
    eq(ns.Stats.Text(ns.db, ns.runtime), '12 new, 3 different')
    ns.Consent.Stop(ns.db, ns.runtime)
    eq(ns.Stats.Text(ns.db, ns.runtime), 'paused')
    ns.runtime.schemaBlocked = true
    eq(ns.Stats.Text(ns.db, ns.runtime), 'blocked')
end)

test('the tooltip lists every category with what was observed and, after a comparison, what is new or different', function()
    local ns = compared()
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    local lines = ns.Stats.TooltipLines(ns.db, ns.runtime)
    local text = {}
    for _, line in ipairs(lines) do text[#text + 1] = plain(line.left) .. ' | ' .. plain(line.right or '') end
    local all = table.concat(text, '\n')
    has(all, 'Loot | 2 observed'); has(all, 'Areas | 1 observed'); has(all, 'Professions | 1 observed')
    ns.db.compare = { ranAt = 5000, baselineVersion = '0.5.108', totals = { new = 2, different = 2 },
        counts = { loot = { new = 1, different = 0 }, npcs = { new = 0, different = 1 }, vendors = { new = 0, different = 1 },
            skills = { new = 1, different = 0 }, areas = { new = 0, different = 0 }, quests = { new = 0, different = 0 }, entities = { new = 0, different = 0 } } }
    text = {}
    for _, line in ipairs(ns.Stats.TooltipLines(ns.db, ns.runtime)) do text[#text + 1] = plain(line.left) .. ' | ' .. plain(line.right or '') end
    all = table.concat(text, '\n')
    has(all, 'Loot | 2 observed, 1 new, 0 different'); has(all, 'D5000'); has(all, '0.5.108'); has(all, 'no baseline')
end)

test('the Titan Panel plugin is a data source that opens the window and updates its text', function()
    local ns = load()
    local made
    _G.LibStub = { GetLibrary = function() return { NewDataObject = function(_, name, object) made = { name = name, object = object }; return object end } end }
    eq(ns.Stats.Initialize(), true)
    eq(made.name, 'TitanGatheredForeverDiscovery'); eq(made.object.type, 'data source'); eq(made.object.label, 'Titan Gathered Discovery')
    eq(made.object.text, 'off')
    local toggled = 0
    ns.Window.Toggle = function() toggled = toggled + 1 end
    made.object.OnClick(widget('owner'), 'LeftButton')
    eq(toggled, 1)
    made.object.OnClick(widget('owner'), 'RightButton')
    eq(toggled, 1)
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.Stats.Refresh()
    eq(made.object.text, '0 records')
    _G.LibStub = nil
    eq(ns.Stats.Initialize(), false)
end)

test('the statistics are refreshed at most once in a while after the data changed', function()
    local ns = load()
    local scheduled = {}
    _G.C_Timer = { After = function(seconds, fn) scheduled[#scheduled + 1] = { seconds = seconds, fn = fn } end }
    local object = { text = '' }
    _G.LibStub = { GetLibrary = function() return { NewDataObject = function() return object end } end }
    ns.Stats.Initialize()
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.Stats.Dirty(); ns.Stats.Dirty(); ns.Stats.Dirty()
    eq(#scheduled, 1); assert(scheduled[1].seconds >= 5)
    ns.db.data.loot[1] = {}
    scheduled[1].fn()
    eq(object.text, '1 records')
    ns.Stats.Dirty()
    eq(#scheduled, 2)
    _G.C_Timer = nil; _G.LibStub = nil
end)

test('a handled event marks the statistics dirty and accept refreshes them at once', function()
    local ns = load()
    local dirty, refreshed = 0, 0
    ns.Stats.Dirty = function() dirty = dirty + 1 end
    ns.Stats.Refresh = function() refreshed = refreshed + 1 end
    ns.api = { Now = function() return 1 end, Zone = function() return { mapID = 1, zone = 'A' } end, Build = function() return '1', '2', '3', 4 end,
        Locale = function() return 'enUS' end, Skills = function() return {} end }
    ns.Commands.Handle('accept')
    assert(refreshed >= 1)
    ns.Manager.Handle('ZONE_CHANGED')
    eq(dirty, 1)
    local before = refreshed
    ns.Commands.Handle('stop')
    eq(refreshed, before + 1)
end)

test('the window is built once, fills its lines from the rows and hides the unused ones', function()
    local ns = compared()
    ns.Window.Show()
    local count = #frames
    local window = ns.Window.window
    assert(window and window.shown)
    eq(#window.lines, ns.View.ROWS)
    eq(plain(window.lines[1].cells[3].text), 'Strange Herb')
    eq(window.lines[1].shown, true); eq(window.lines[5].shown, false)
    has(plain(window.rangeText.text), 'Showing 1-4 of 4')
    ns.Window.Show()
    eq(#frames, count)                          -- the second show reuses the window
    ns.Window.Toggle()
    eq(window.shown, false)
    ns.Window.Toggle()
    eq(window.shown, true)
end)

test('the filters of the window change the rows and a click on a row shows its detail', function()
    local ns = compared()
    ns.Window.Show()
    local window = ns.Window.window
    window.showFilter.set('all')
    eq(ns.View.show, 'all'); eq(window.lines[7].shown, true); eq(window.lines[8].shown, false)
    window.categoryFilter.set('loot')
    eq(ns.View.category, 'loot'); eq(window.lines[3].shown, false)
    window.categoryFilter.set(false)
    ns.View.show = 'changes'; ns.View.Refresh = nil
    window.showFilter.set('changes')
    window.lines[3].OnClick(window.lines[3])
    has(plain(window.detail.text), 'Goods or lessons differ')
    window.search.OnTextChanged(window.search, true)
end)

test('without a comparison Everything observed still lists what was observed', function()
    local ns = load()
    local data = ns.db.data
    data.loot[765] = { name = 'Silverleaf', seen = 2, first = 2000, last = 3000 }
    data.npcs[223] = { name = 'Dan the Elder', seen = 1, last = 100 }
    data.areas['1|A|A||'] = { zone = 'A', seen = 1 }
    ns.View.show = 'changes'
    eq(ns.View.Rows(), nil)                                    -- new and different need the comparison
    ns.View.show = 'all'
    local rows = ns.View.Rows()
    eq(#rows, 3)
    for _, row in ipairs(rows) do eq(row.state, 'observed') end
    has(plain(ns.View.DetailText(rows[1])[1]), '/tgfd compare')
    has(plain(ns.View.Cells(rows[1])[4]), 'Observed')
    ns.View.search = 'silver'
    eq(#ns.View.Rows(), 1)
    ns.View.search = ''; ns.View.category = 'npcs'
    eq(#ns.View.Rows(), 1)
    ns.View.category = false
    ns.Window.Show()
    ns.View.show = 'all'; ns.Window.Refresh()
    local window = ns.Window.window
    eq(window.lines[1].shown, true); eq(window.lines[3].shown, true); eq(window.lines[4].shown, false)
    has(plain(window.rangeText.text), 'Showing 1-3 of 3')
    ns.db.data.loot[765] = nil; ns.db.data.npcs[223] = nil; ns.db.data.areas['1|A|A||'] = nil
    eq(#ns.View.Rows(), 0)
end)

test('the window has two tabs: the collected data and how the module works', function()
    local ns = compared()
    ns.Window.Show()
    local window = ns.Window.window
    eq(window.TitleText.text, 'Titan Gathered Discovery')
    eq(window.page, 'data'); eq(window.pages.data.shown, true); eq(window.pages.guide.shown, false)
    assert(window.tabButtons.data and window.tabButtons.guide, 'both tabs exist')
    window.tabButtons.guide.OnClick()
    eq(window.page, 'guide'); eq(window.pages.guide.shown, true); eq(window.pages.data.shown, false)
    has(plain(window.guideText.text), 'What it records')
    window.tabButtons.data.OnClick()
    eq(window.page, 'data'); eq(window.pages.data.shown, true); eq(window.pages.guide.shown, false)
    has(plain(window.lines[1].cells[3].text), 'Strange Herb')
    ns.Window.Toggle(); ns.Window.Toggle()
    eq(window.page, 'data')                                   -- the window opens on the data again
end)

test('the guide explains the module, the data, their use and how to hand them over', function()
    local ns = load()
    local text = plain(table.concat(ns.Guide.Lines(), '\n'))
    for _, part in ipairs({ 'What it is', 'What it records', 'What it never records', 'How it works', 'What the data is used for',
        'How to send the data', '/tgfd audit', '/tgfd export', '/reload', 'TitanGatheredForever_Discovery.lua', 'SavedVariables',
        '/tgfd stop', '/tgfd compare', '/tgfd archive confirm', 'nothing is sent' }) do
        has(text:lower(), part:lower())
    end
    assert(not text:find('DiscoveryDB.lua', 1, true), 'the file is named after the addon')
    -- The contacts of the owner are in the text; without them the guide points to the project page.
    has(text, 'Discord'); has(text, '_bajt'); has(text, 'E-mail'); has(text, 'bajtlamer@gmail.com')
    local saved = { ns.Guide.CONTACTS.discord, ns.Guide.CONTACTS.email }
    ns.Guide.CONTACTS.discord, ns.Guide.CONTACTS.email = nil, nil
    has(plain(table.concat(ns.Guide.Lines(), '\n')), 'CurseForge')
    ns.Guide.CONTACTS.discord, ns.Guide.CONTACTS.email = saved[1], saved[2]
    ns.Guide.CONTACTS.discord, ns.Guide.CONTACTS.email = 'https://discord.gg/example', 'author@example.org'
    local contact = plain(table.concat(ns.Guide.Lines(), '\n'))
    has(contact, 'Discord'); has(contact, 'https://discord.gg/example'); has(contact, 'E-mail'); has(contact, 'author@example.org')
    ns.Guide.CONTACTS.discord = nil
    local only = plain(table.concat(ns.Guide.Lines(), '\n'))
    lacks(only, 'discord.gg'); has(only, 'author@example.org')
    ns.Guide.CONTACTS.email = nil
end)

test('without a comparison the window explains what to do instead of showing rows', function()
    local ns = load()
    ns.Window.Show()
    local window = ns.Window.window
    has(plain(window.rangeText.text), 'No records')
    eq(window.lines[1].shown, false)
    has(plain(window.header.text), '/tgfd compare')
end)

test('a failure to build the window is reported and never raised', function()
    local ns = load()
    _G.CreateFrame = function() error('no frames') end
    ns.Window.Show()
    has(printed(ns), 'window')
end)

test('/tgfd show opens the window, and the help lists it', function()
    local ns = load()
    local shown = 0
    ns.Window.Toggle = function() shown = shown + 1 end
    ns.Commands.Handle('show')
    eq(shown, 1)
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.printed = {}
    ns.Commands.Handle('help')
    has(printed(ns), '/tgfd show')
end)

test('the text helpers color by name, name items and format money with the core when it is there', function()
    local ns = load()
    eq(ns.Text.Color('cyan', 'x'), '|ccyanx|r')
    eq(ns.Text.Item(5), 'Item5'); eq(ns.Text.Coin(7), '<7c>')
    _G.TitanGatheredForeverV3 = nil
    eq(ns.Text.Color('cyan', 'x'), 'x'); eq(ns.Text.Item(5), 'item 5'); eq(ns.Text.Coin(7), '7 copper')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS discovery view ' .. #tests .. ' checks')
