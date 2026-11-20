-- Titan Gathered Forever: Discovery, milestone 7: privacy check, export stamp, archive and review marks.
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

local function load()
    _G.TitanGatheredForeverV3 = { Style = {}, Nav = {
        Dropdown = function() return { Sync = function() end } end, Scrollbar = function() return widget('Slider') end,
        SyncScrollbar = function() end, Draggable = function() end } }
    styleStub(_G.TitanGatheredForeverV3.Style)
    _G.CreateFrame = function(kind, name, _, template)
        local frame = widget(kind)
        function frame:SetText(text) self.text = text end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:IsShown() return self.shown end
        function frame:SetScript(script, fn) self[script] = fn end
        function frame:CreateFontString() local fs = widget('FontString'); function fs:SetText(t) self.text = t end; return fs end
        if template == 'BasicFrameTemplateWithInset' then frame.TitleText = widget('Title'); function frame.TitleText:SetText(t) self.text = t end end
        return frame
    end
    _G.UIParent = widget('UIParent'); _G.UISpecialFrames = {}
    local ns = { printed = {} }
    for _, file in ipairs(manifestFiles()) do
        if file ~= 'Start.lua' then assert(loadfile(FOLDER .. '/' .. file))(FOLDER, ns) end
    end
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.api = { Now = function() return 1000 end, PlayerName = function() return 'Radekovo' end }
    local clock = { ms = 0 }
    ns.env = { now = function() return 5000 end, build = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end,
        date = function(_, t) return 'D' .. tostring(t) end, coreVersion = function() return '0.5.108' end, moduleVersion = '0.1.0',
        clock = function() return clock.ms end, inCombat = function() return false end }
    ns.db = ns.Database.Init(nil, '0.1.0', 1000)
    ns.runtime = {}
    ns.state.build = '70862'
    ns.state.session = 'S1'
    ns.frame = { RegisterEvent = function() end, UnregisterEvent = function() end }
    ns.db.meta.client = { version = '1.60.1', build = '70862', interface = 16001, locale = 'enUS' }
    return ns
end

local function plain(text) return (tostring(text):gsub('|cgold', ''):gsub('|cwhite', ''):gsub('|cgreen', ''):gsub('|r', '')) end
local function printed(ns)
    local lines = {}
    for _, line in ipairs(ns.printed) do lines[#lines + 1] = plain(line) end
    return table.concat(lines, '\n')
end
local function runAll(ns)
    local guard = 0
    while ns.Runner.Active() do ns.Runner.Tick(); guard = guard + 1; assert(guard < 2000, 'operation never ended') end
end
local function fill(ns)
    local data = ns.db.data
    data.loot[765] = { name = 'Silverleaf', seen = 2, sources = { ['Creature:100'] = 1 } }
    data.loot[2770] = { name = 'Copper Ore', seen = 1 }
    data.npcs[100] = { name = 'Boar', seen = 1, positions = { { mapID = 1412, x = 0.4, y = 0.5 } } }
    data.areas['1|A|A||'] = { zone = 'A', seen = 1 }
end

test('sorted keys put numbers and strings in a fixed order', function()
    local ns = load()
    local keys = ns.Util.SortedKeys({ b = 1, a = 2, [3] = 3, [1] = 4 })
    eq(#keys, 4)
    eq(ns.Util.SortedKeys(nil)[1], nil)
    local again = ns.Util.SortedKeys({ [1] = 4, [3] = 3, a = 2, b = 1 })
    for i = 1, 4 do eq(keys[i], again[i]) end
end)

test('the checksum is the Adler-32 of the text and does not depend on the order a table was built in', function()
    local ns = load()
    eq(ns.Checksum.Text('Wikipedia'), '11e60398')
    local first, second = {}, {}
    first.a, first.b, first.c = 1, { x = 'y', z = 2 }, 'q'
    second.c, second.b, second.a = 'q', { z = 2, x = 'y' }, 1
    eq(ns.Checksum.Canonical(first), ns.Checksum.Canonical(second))
    second.a = 2
    assert(ns.Checksum.Canonical(first) ~= ns.Checksum.Canonical(second))
end)

test('the checksum of a category changes when a record changes and is the same for the same content', function()
    local ns = load(); fill(ns)
    local one = ns.Checksum.Category(ns.db.data.loot)
    eq(one, ns.Checksum.Category(ns.db.data.loot))
    ns.db.data.loot[765].seen = 3
    assert(ns.Checksum.Category(ns.db.data.loot) ~= one)
    eq(#one, 8)
end)

test('the privacy check finds player GUIDs and the character name in values and in keys, with their paths', function()
    local ns = load(); fill(ns)
    eq(#ns.Audit.Find(ns.db), 0)
    ns.db.data.loot[765].sources['Player-4711-0ABCDEF1'] = 1
    ns.db.data.npcs[100].name = 'Boar of Radekovo'
    ns.db.data.areas['1|A|A||'].note = 'Pet-0-1-2-3-9-0000ABCD'
    local offenders = ns.Audit.Find(ns.db)
    eq(#offenders, 3)
    local joined = {}
    for _, offender in ipairs(offenders) do joined[#joined + 1] = offender.path end
    local text = table.concat(joined, '\n')
    has(text, 'loot'); has(text, 'npcs'); has(text, 'areas')
end)

test('a short character name is not searched for, to avoid false alarms', function()
    local ns = load(); fill(ns)
    ns.api.PlayerName = function() return 'Al' end
    ns.db.data.npcs[100].name = 'Alchemist Alder'
    eq(#ns.Audit.Find(ns.db), 0)
    ns.api.PlayerName = function() return nil end
    eq(#ns.Audit.Find(ns.db), 0)
end)

test('the audit command runs as an operation and reports the result', function()
    local ns = load(); fill(ns)
    ns.Commands.Handle('audit')
    eq(ns.Runner.Active(), true)
    runAll(ns)
    has(printed(ns), 'Privacy check passed'); has(printed(ns), '4 records')
    ns.db.data.loot[765].sources['Player-1-2'] = 1
    ns.printed = {}
    ns.Commands.Handle('audit'); runAll(ns)
    has(printed(ns), '1 suspicious'); has(printed(ns), 'loot')
end)

test('the export checks privacy, stamps the data with versions, counts and checksums and says what to send', function()
    local ns = load(); fill(ns)
    ns.Commands.Handle('export')
    runAll(ns)
    local export = ns.db.export
    assert(export, 'no export stamp')
    eq(export.schemaVersion, ns.Database.SCHEMA_VERSION); eq(export.exportedAt, 5000); eq(export.moduleVersion, '0.1.0')
    eq(export.client.build, '70862'); eq(export.counts.loot, 2); eq(export.counts.npcs, 1); eq(export.total, 4)
    eq(export.session, 'S1'); eq(export.checksums.loot, ns.Checksum.Category(ns.db.data.loot)); eq(#export.checksum, 8)
    local text = printed(ns)
    has(text, '/reload'); has(text, 'TitanGatheredForeverDiscoveryDB.lua'); has(text, 'SavedVariables')
    lacks(text, 'Radekovo')
end)

test('an export with private data in it is refused and leaves no stamp', function()
    local ns = load(); fill(ns)
    ns.db.data.loot[765].sources['Player-4711-0ABCDEF1'] = 1
    ns.Commands.Handle('export'); runAll(ns)
    eq(ns.db.export, nil)
    has(printed(ns), 'not exported'); has(printed(ns), 'loot')
end)

test('there is nothing to export without records', function()
    local ns = load()
    ns.Commands.Handle('export')
    eq(ns.Runner.Active(), false); has(printed(ns), 'Nothing to export')
end)

local function exported()
    local ns = load(); fill(ns)
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.Consent.Stop(ns.db, ns.runtime)
    ns.Commands.Handle('export'); runAll(ns)
    ns.state.session = 'S2'                        -- the game was reloaded after the export
    ns.printed = {}
    return ns
end

test('archive without confirm only explains the steps and changes nothing', function()
    local ns = exported()
    ns.Commands.Handle('archive')
    eq(ns.Database.Count(ns.db), 4)
    has(printed(ns), '/tgfd export'); has(printed(ns), '/tgfd archive confirm'); eq(ns.Runner.Active(), false)
end)

test('archive is refused without an export, while recording, before a reload and after the data changed', function()
    local ns = load(); fill(ns)
    ns.Consent.Accept(ns.db, ns.runtime, 1); ns.Consent.Stop(ns.db, ns.runtime)
    ns.Commands.Handle('archive confirm')
    has(printed(ns), 'export'); eq(ns.Database.Count(ns.db), 4)

    local recording = exported()
    recording.Consent.Start(recording.db, recording.runtime)
    recording.Commands.Handle('archive confirm')
    has(printed(recording), '/tgfd stop'); eq(recording.Database.Count(recording.db), 4)

    local same = load(); fill(same)
    same.Consent.Accept(same.db, same.runtime, 1); same.Consent.Stop(same.db, same.runtime)
    same.Commands.Handle('export'); runAll(same); same.printed = {}
    same.Commands.Handle('archive confirm')
    has(printed(same), '/reload'); eq(same.Database.Count(same.db), 4)

    local changed = exported()
    changed.db.data.loot[765].seen = 99
    changed.Commands.Handle('archive confirm'); runAll(changed)
    has(printed(changed), 'changed'); eq(changed.Database.Count(changed.db), 4)
end)

test('a confirmed archive clears the observations, keeps a small history and the consent, and refreshes the counts', function()
    local ns = exported()
    ns.db.compare = { totals = { new = 1, different = 0 } }
    ns.results = {}
    local refreshed = 0
    ns.Stats.Refresh = function() refreshed = refreshed + 1 end
    ns.Commands.Handle('archive confirm'); runAll(ns)
    eq(ns.Database.Count(ns.db), 0)
    for _, category in ipairs(ns.Database.CATEGORIES) do eq(type(ns.db.data[category]), 'table') end
    eq(#ns.db.archives, 1); eq(ns.db.archives[1].archivedAt, 5000); eq(ns.db.archives[1].total, 4)
    eq(ns.db.archives[1].counts.loot, 2); eq(#ns.db.archives[1].checksum, 8)
    eq(ns.db.compare, nil); eq(ns.results, nil); eq(ns.db.consent.accepted, true)
    assert(refreshed >= 1)
    has(printed(ns), 'Archived'); has(printed(ns), '4 records')
    ns.printed = {}
    ns.Commands.Handle('archive confirm')
    has(printed(ns), 'already')
    eq(#ns.db.archives, 1)
end)

test('a review mark is local, shows in the row and removes it from the to review list', function()
    local ns = load()
    local row = { category = 'loot', key = 765, name = 'Silverleaf', state = 'new', details = {}, differences = 0 }
    eq(ns.View.IsReviewed(row), false)
    eq(ns.View.ToggleReviewed(row), true)
    eq(ns.View.IsReviewed(row), true); eq(ns.db.reviewed['loot:765'], 5000)
    has(plain(ns.View.Cells(row)[7]), 'reviewed')
    ns.results = { rows = {} }
    for _, category in ipairs(ns.Database.CATEGORIES) do ns.results.rows[category] = {} end
    ns.results.rows.loot[1] = row
    ns.results.rows.loot[2] = { category = 'loot', key = 1, name = 'Other', state = 'new', details = {}, differences = 0 }
    ns.View.show = 'toreview'
    eq(#ns.View.Rows(), 1); eq(ns.View.Rows()[1].key, 1)
    ns.View.show = 'changes'
    eq(#ns.View.Rows(), 2)
    eq(ns.View.ToggleReviewed(row), false)
    eq(ns.db.reviewed['loot:765'], nil)
end)

test('the window has a button that marks the selected row as reviewed and back', function()
    local ns = load()
    ns.results = { rows = {} }
    for _, category in ipairs(ns.Database.CATEGORIES) do ns.results.rows[category] = {} end
    ns.results.rows.loot[1] = { category = 'loot', key = 765, name = 'Silverleaf', state = 'new', details = {}, differences = 0 }
    ns.Window.Show()
    local window = ns.Window.window
    window.lines[1].OnClick(window.lines[1])
    eq(window.reviewButton.text, 'Mark reviewed')
    window.reviewButton.OnClick()
    eq(ns.View.IsReviewed(ns.View.selected), true); eq(window.reviewButton.text, 'Clear reviewed mark')
    window.reviewButton.OnClick()
    eq(ns.View.IsReviewed(ns.View.selected), false)
end)

test('the help lists the privacy check, the export and the archive', function()
    local ns = load()
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.printed = {}
    ns.Commands.Handle('help')
    has(printed(ns), '/tgfd audit'); has(printed(ns), '/tgfd export'); has(printed(ns), '/tgfd archive')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS discovery export ' .. #tests .. ' checks')
