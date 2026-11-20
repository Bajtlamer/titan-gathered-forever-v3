-- Titan Gathered Forever: Discovery, milestone 1: manifest, saved data lifecycle, Scout detection, consent, commands.
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

-- Loads every file of the manifest in order into a fresh private namespace, as the client does.
local function load(options)
    options = options or {}
    _G.TitanGatheredForeverV3 = nil
    if options.core ~= false then
        local core = { Style = {} }
        styleStub(core.Style)
        _G.TitanGatheredForeverV3 = core
    end
    local ns = { printed = {} }
    for _, file in ipairs(manifestFiles()) do
        if file ~= 'Start.lua' then assert(loadfile(FOLDER .. '/' .. file))(FOLDER, ns) end
    end
    if options.raw then return ns end
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.env = { now = function() return 1000 end, build = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end,
        date = function(_, time) return 'D' .. tostring(time) end, coreVersion = function() return '0.5.108' end,
        moduleVersion = '0.1.0' }
    return ns
end

local function ready(options)
    local ns = load(options)
    ns.db, ns.status = ns.Database.Init(nil, '0.1.0', 1000)
    ns.runtime = { scout = {} }
    return ns
end

local function joined(ns)
    local lines = {}
    for _, line in ipairs(ns.printed) do lines[#lines + 1] = line end
    return table.concat(lines, '\n')
end

test('the manifest names the module like its folder, needs Titan and the core and keeps its own saved table', function()
    local toc = readAll(FOLDER .. '/' .. FOLDER .. '.toc')
    has(toc, '## Interface: 16001')
    has(toc, '## Title: Titan Gathered Forever: Discovery\n')
    has(toc, '## Dependencies: Titan, TitanGatheredForever')
    has(toc, '## SavedVariables: TitanGatheredForeverDiscoveryDB')
    lacks(toc, 'TitanGatheredForeverV3DB')
    lacks(toc, 'WoWFScoutDB')
    for _, file in ipairs(manifestFiles()) do assert(io.open(FOLDER .. '/' .. file, 'r'), 'listed file is missing: ' .. file) end
end)

test('no file of the module touches the auction house', function()
    for _, file in ipairs(manifestFiles()) do
        local text = readAll(FOLDER .. '/' .. file):lower()
        lacks(text, 'auctionhouse'); lacks(text, 'auction_house'); lacks(text, 'replicateitems')
    end
end)

test('a first start creates the saved table with the schema, the versions and an empty table per category', function()
    local ns = load()
    local db, status = ns.Database.Init(nil, '0.1.0', 1000)
    eq(status, 'ok'); eq(db.meta.schemaVersion, ns.Database.SCHEMA_VERSION); eq(db.meta.moduleVersion, '0.1.0')
    eq(db.meta.createdAt, 1000); eq(db.consent.accepted, false); eq(db.consent.paused, false)
    assert(#ns.Database.CATEGORIES >= 7)
    for _, category in ipairs(ns.Database.CATEGORIES) do eq(type(db.data[category]), 'table') end
end)

test('an existing saved table keeps its records, gets missing parts and the new module version', function()
    local ns = load()
    local old = { meta = { schemaVersion = 1, moduleVersion = '0.0.9', createdAt = 5 }, consent = { accepted = true, version = 1, acceptedAt = 7 },
        data = { loot = { [765] = { count = 3 } } } }
    local db, status = ns.Database.Init(old, '0.1.0', 1000)
    eq(status, 'ok'); eq(db, old); eq(db.data.loot[765].count, 3); eq(db.meta.createdAt, 5)
    eq(db.meta.moduleVersion, '0.1.0'); eq(db.meta.createdWith, '0.0.9')
    eq(db.consent.accepted, true); eq(db.consent.acceptedAt, 7); eq(db.consent.paused, false)
    eq(type(db.data.quests), 'table')
end)

test('a saved value that is not a table is replaced by a fresh one', function()
    local ns = load()
    local db, status = ns.Database.Init('garbage', '0.1.0', 1000)
    eq(status, 'ok'); eq(type(db), 'table'); eq(db.consent.accepted, false)
end)

test('data of a newer schema are left untouched and reported', function()
    local ns = load()
    local newer = { meta = { schemaVersion = 99 }, mystery = true }
    local db, status = ns.Database.Init(newer, '0.1.0', 1000)
    eq(status, 'newer'); eq(db, newer); eq(db.meta.moduleVersion, nil); eq(db.consent, nil); eq(db.data, nil)
end)

test('records are counted over all categories', function()
    local ns = load()
    local db = ns.Database.Init(nil, '0.1.0', 1000)
    eq(ns.Database.Count(db), 0)
    db.data.loot[1] = {}; db.data.loot[2] = {}; db.data.areas['Mulgore'] = {}
    eq(ns.Database.Count(db), 3)
    eq(ns.Database.Count(nil), 0)
end)

test('the retired Scout is found by its folder names; an error in the check counts as not loaded', function()
    local ns = load()
    local found = ns.Scout.Found(function(name) return name == 'WoWForeverScout' end)
    eq(#found, 1); eq(found[1], 'WoWForeverScout')
    eq(#ns.Scout.Found(function() return false end), 0)
    eq(#ns.Scout.Found(function() error('boom') end), 0)
end)

test('nothing is collected before the notice is accepted, and acceptance is recorded', function()
    local ns = ready()
    eq(ns.Consent.State(ns.db, ns.runtime), 'unaccepted')
    local ok = ns.Consent.Accept(ns.db, ns.runtime, 2000)
    eq(ok, true); eq(ns.db.consent.accepted, true); eq(ns.db.consent.acceptedAt, 2000)
    eq(ns.db.consent.version, ns.Consent.NOTICE_VERSION)
    eq(ns.Consent.State(ns.db, ns.runtime), 'collecting')
    eq(ns.Consent.Collecting(ns.db, ns.runtime), true)
end)

test('stop pauses and start resumes, but only after acceptance', function()
    local ns = ready()
    eq(ns.Consent.Start(ns.db, ns.runtime), false)
    ns.Consent.Accept(ns.db, ns.runtime, 2000)
    eq(ns.Consent.Stop(ns.db, ns.runtime), true)
    eq(ns.Consent.State(ns.db, ns.runtime), 'paused'); eq(ns.Consent.Collecting(ns.db, ns.runtime), false)
    eq(ns.Consent.Start(ns.db, ns.runtime), true)
    eq(ns.Consent.State(ns.db, ns.runtime), 'collecting')
end)

test('a loaded Scout blocks collection and acceptance', function()
    local ns = ready()
    ns.runtime.scout = { 'WoWForeverScout' }
    eq(ns.Consent.Accept(ns.db, ns.runtime, 2000), false)
    eq(ns.db.consent.accepted, false)
    eq(ns.Consent.State(ns.db, ns.runtime), 'blocked-scout')
    ns.runtime.scout = {}
    ns.Consent.Accept(ns.db, ns.runtime, 2000)
    ns.runtime.scout = { 'WoWForeverScout' }
    eq(ns.Consent.Collecting(ns.db, ns.runtime), false)
    eq(ns.Consent.State(ns.db, ns.runtime), 'blocked-scout')
end)

test('data of a newer schema block collection and acceptance', function()
    local ns = ready()
    ns.runtime.schemaBlocked = true
    eq(ns.Consent.State(ns.db, ns.runtime), 'blocked-schema')
    eq(ns.Consent.Accept(ns.db, ns.runtime, 2000), false)
    eq(ns.Consent.Collecting(ns.db, ns.runtime), false)
end)

test('an acceptance of an older notice no longer counts', function()
    local ns = ready()
    ns.Consent.Accept(ns.db, ns.runtime, 2000)
    ns.db.consent.version = ns.Consent.NOTICE_VERSION - 1
    eq(ns.Consent.State(ns.db, ns.runtime), 'unaccepted')
    eq(ns.Consent.Collecting(ns.db, ns.runtime), false)
end)

test('the notice says what is recorded, what never is, how to start, stop and hand data over', function()
    local ns = load()
    local text = table.concat(ns.Consent.Notice(), '\n')
    has(text, '/tgfd accept'); has(text, '/tgfd stop')
    has(text, 'chat'); has(text, 'GUID'); has(text, 'auction')
    has(text, 'export')
end)

test('help without acceptance prints the notice; /tgfd accept starts collection', function()
    local ns = ready()
    ns.Commands.Handle('')
    has(joined(ns), '/tgfd accept')
    ns.printed = {}
    ns.Commands.Handle('  ACCEPT  ')
    has(joined(ns), 'Collecting')
    eq(ns.Consent.Collecting(ns.db, ns.runtime), true)
end)

test('help after acceptance lists the commands and not the notice', function()
    local ns = ready()
    ns.Consent.Accept(ns.db, ns.runtime, 2000)
    ns.Commands.Handle('help')
    local text = joined(ns)
    has(text, '/tgfd status'); has(text, '/tgfd stop'); has(text, '/tgfd start')
    lacks(text, '/tgfd accept')
end)

test('accept is refused with a reason while Scout is loaded', function()
    local ns = ready()
    ns.runtime.scout = { 'WoWForeverScout' }
    ns.Commands.Handle('accept')
    has(joined(ns), 'WoWForeverScout')
    eq(ns.db.consent.accepted, false)
end)

test('stop and start report their result', function()
    local ns = ready()
    ns.Commands.Handle('start'); has(joined(ns), 'accept')
    ns.printed = {}
    ns.Consent.Accept(ns.db, ns.runtime, 2000)
    ns.Commands.Handle('stop'); has(joined(ns), 'Paused')
    ns.printed = {}
    ns.Commands.Handle('start'); has(joined(ns), 'Collecting')
end)

test('status shows the state, versions, client build, baseline and record count', function()
    local ns = ready()
    ns.Consent.Accept(ns.db, ns.runtime, 2000)
    ns.db.data.loot[765] = { count = 1 }
    ns.Commands.Handle('status')
    local text = joined(ns)
    has(text, 'Collecting'); has(text, '0.1.0'); has(text, '70862'); has(text, '0.5.108'); has(text, 'D2000')
    has(text, 'Records'); has(text, 'loot')
end)

test('status names the Scout that blocks collection', function()
    local ns = ready()
    ns.runtime.scout = { 'WoWForeverScout' }
    ns.Commands.Handle('status')
    has(joined(ns), 'Blocked'); has(joined(ns), 'WoWForeverScout')
end)

test('an unknown command prints a message and the help', function()
    local ns = ready()
    ns.Commands.Handle('frobnicate')
    has(joined(ns), 'Unknown command'); has(joined(ns), '/tgfd')
end)

test('commands before the saved table exists print a message and never fail', function()
    local ns = load()
    ns.runtime = { scout = {} }
    ns.Commands.Handle('status'); has(joined(ns), 'not loaded')
    ns.printed = {}
    ns.Commands.Handle('accept'); has(joined(ns), 'not loaded')
end)

test('text uses the core style when it is loaded and plain text otherwise', function()
    local ns = load()
    has(ns.Text.Label('abc'), '|c')
    has(ns.Text.Value('abc'), 'abc')
    local plain = load({ core = false })
    eq(plain.Text.Label('abc'), 'abc'); eq(plain.Text.Value('abc'), 'abc'); eq(plain.Text.Date('abc'), 'abc')
end)

local function client()
    local frames, handlers = {}, {}
    _G.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[#self.events + 1] = event end
        function frame:SetScript(kind, fn) self[kind] = fn end
        frames[#frames + 1] = frame
        return frame
    end
    _G.SlashCmdList = {}
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) handlers[#handlers + 1] = message end }
    _G.C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return '0.5.108' end }
    _G.GetBuildInfo = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end
    _G.time = function() return 1000 end
    _G.date = function() return 'today' end
    _G.TitanGatheredForeverDiscoveryDB = nil
    return frames, handlers
end

test('the saved table is created when the module loads and the slash command is /tgfd only', function()
    local frames, messages = client()
    local ns = load({ raw = true })
    ns.Main.Start()
    eq(#frames, 1)
    local frame = frames[1]
    frame.OnEvent(frame, 'ADDON_LOADED', FOLDER)
    eq(type(_G.TitanGatheredForeverDiscoveryDB), 'table')
    eq(ns.db, _G.TitanGatheredForeverDiscoveryDB)
    eq(_G.SLASH_TGFD1, '/tgfd'); eq(_G.SLASH_TGFD2, nil)
    eq(type(_G.SlashCmdList.TGFD), 'function')
    _G.SlashCmdList.TGFD('help')
    has(table.concat(messages, '\n'), '/tgfd accept')
end)

test('another addon loading does not create the saved table', function()
    local frames = client()
    local ns = load({ raw = true })
    ns.Main.Start()
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', 'SomethingElse')
    eq(_G.TitanGatheredForeverDiscoveryDB, nil)
end)

test('at login a loaded Scout is reported once and blocks collection; otherwise a short hint appears', function()
    local frames, messages = client()
    _G.C_AddOns.IsAddOnLoaded = function(name) return name == 'WoWForeverScout' end
    local ns = load({ raw = true })
    ns.Main.Start()
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', FOLDER)
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')
    eq(ns.Consent.State(ns.db, ns.runtime), 'blocked-scout')
    has(table.concat(messages, '\n'), 'WoWForeverScout')

    local frames2, messages2 = client()
    local ns2 = load({ raw = true })
    ns2.Main.Start()
    frames2[1].OnEvent(frames2[1], 'ADDON_LOADED', FOLDER)
    frames2[1].OnEvent(frames2[1], 'PLAYER_LOGIN')
    eq(ns2.Consent.State(ns2.db, ns2.runtime), 'unaccepted')
    has(table.concat(messages2, '\n'), '/tgfd')
    lacks(table.concat(messages2, '\n'), 'WoWForeverScout')
end)

test('a newer saved schema is reported at login and blocks collection', function()
    local frames, messages = client()
    _G.TitanGatheredForeverDiscoveryDB = { meta = { schemaVersion = 99 } }
    local ns = load({ raw = true })
    ns.Main.Start()
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', FOLDER)
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')
    eq(ns.Consent.State(ns.db, ns.runtime), 'blocked-schema')
    has(table.concat(messages, '\n'), 'newer')
    eq(_G.TitanGatheredForeverDiscoveryDB.consent, nil)
end)

test('milestone 1 listens to no game events beyond loading and login', function()
    local frames = client()
    local ns = load({ raw = true })
    ns.Main.Start()
    local events = table.concat(frames[1].events, ',')
    eq(events, 'ADDON_LOADED')
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', FOLDER)
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')
    -- PLAYER_LOGIN is registered by the module once its own saved data are ready, like the core does.
    assert(table.concat(frames[1].events, ','):find('PLAYER_LOGIN', 1, true))
    assert(not table.concat(frames[1].events, ','):find('LOOT', 1, true))
end)

test('the last manifest file starts the module', function()
    local files = manifestFiles()
    eq(files[#files], 'Start.lua')
    has(readAll(FOLDER .. '/Start.lua'), 'ns.Main.Start()')
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS discovery ' .. #tests .. ' checks')
