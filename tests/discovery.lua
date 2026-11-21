-- Titan Gathered Forever: Discovery: manifest, saved data lifecycle, consent, commands, runner and progress.
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
    ns.runtime = {}
    return ns
end

local function joined(ns)
    local lines = {}
    for _, line in ipairs(ns.printed) do lines[#lines + 1] = (line:gsub('|cgold', ''):gsub('|cwhite', ''):gsub('|cgreen', ''):gsub('|r', '')) end
    return table.concat(lines, '\n')
end

test('the manifest names the module like its folder, needs Titan and the core and keeps its own saved table', function()
    local toc = readAll(FOLDER .. '/' .. FOLDER .. '.toc')
    has(toc, '## Interface: 16001')
    has(toc, '## Title: Titan Gathered Forever: Discovery\n')
    has(toc, '## Dependencies: Titan, TitanGatheredForever')
    has(toc, '## SavedVariables: TitanGatheredForeverDiscoveryDB')
    lacks(toc, 'TitanGatheredForeverV3DB')
    for _, file in ipairs(manifestFiles()) do assert(io.open(FOLDER .. '/' .. file, 'r'), 'listed file is missing: ' .. file) end
end)

test('the module and its manifest do not mention the retired addon', function()
    local words = { 'sco' .. 'ut', 'wowf' .. 'scout' }
    local files = manifestFiles()
    files[#files + 1] = FOLDER .. '.toc'
    for _, file in ipairs(files) do
        local text = readAll(FOLDER .. '/' .. file):lower()
        for _, word in ipairs(words) do lacks(text, word) end
    end
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
    has(text, 'starts by itself'); has(text, '/tgfd stop'); has(text, '/tgfd start'); lacks(text, 'To start recording')
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

test('an unknown command prints a message and the help', function()
    local ns = ready()
    ns.Commands.Handle('frobnicate')
    has(joined(ns), 'Unknown command'); has(joined(ns), '/tgfd')
end)

test('commands before the saved table exists print a message and never fail', function()
    local ns = load()
    ns.runtime = {}
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

local function widget(kind)
    local object = { events = {}, kind = kind, shown = false }
    return setmetatable(object, { __index = function(_, key)
        return function(self, ...)
            if key:sub(1, 6) == 'Create' then return widget(key) end
            return self
        end
    end })
end

local frames
local function client()
    frames = {}
    local messages = {}
    _G.CreateFrame = function(kind)
        local frame = widget(kind)
        function frame:RegisterEvent(event) self.events[#self.events + 1] = event end
        function frame:UnregisterEvent(event)
            for index, value in ipairs(self.events) do if value == event then table.remove(self.events, index); break end end
        end
        function frame:SetScript(name, fn) self[name] = fn end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:IsShown() return self.shown end
        frames[#frames + 1] = frame
        return frame
    end
    _G.UIParent = widget('UIParent')
    _G.SlashCmdList = {}
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
    _G.C_AddOns = { GetAddOnMetadata = function() return '0.5.108' end }
    _G.GetBuildInfo = function() return '1.60.1', '70862', 'Nov 3 2026', 16001 end
    _G.time = function() return 1000 end
    _G.date = function() return 'today' end
    _G.debugprofilestop = function() return 0 end
    _G.InCombatLockdown = function() return false end
    _G.TitanGatheredForeverDiscoveryDB = nil
    return frames, messages
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

local function login(saved)
    local frames, messages = client()
    _G.TitanGatheredForeverDiscoveryDB = saved
    local ns = load({ raw = true })
    ns.Main.Start()
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', FOLDER)
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')
    return ns, messages, frames
end

test('installing the module starts the collection at the first login and shows the notice once', function()
    local ns, messages, frames = login(nil)
    eq(ns.Consent.State(ns.db, ns.runtime), 'collecting')
    eq(ns.db.consent.accepted, true); eq(ns.db.consent.version, ns.Consent.NOTICE_VERSION); eq(ns.db.consent.auto, true)
    local text = table.concat(messages, '\n')
    has(text, 'starts by itself'); has(text, 'It never records'); has(text, '/tgfd stop')
    messages[#messages + 1] = '--'
    local before = #messages
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')                        -- the next login: a short line, not the notice
    local second = table.concat(messages, '\n', before + 1)
    has(second, 'Collecting'); lacks(second, 'It never records')
end)

test('a pause is kept across logins, also after the notice changed', function()
    local ns = login(nil)
    ns.Consent.Stop(ns.db, ns.runtime)
    local saved = _G.TitanGatheredForeverDiscoveryDB
    local again, messages = login(saved)
    eq(again.Consent.State(again.db, again.runtime), 'paused')
    has(table.concat(messages, '\n'), 'Paused')
    again.db.consent.version = again.Consent.NOTICE_VERSION - 1          -- an older notice was accepted and paused
    local third = login(again.db)
    eq(third.db.consent.version, third.Consent.NOTICE_VERSION); eq(third.Consent.State(third.db, third.runtime), 'paused')
end)

test('an acceptance of an older notice is renewed and the notice shown again, collecting continues', function()
    local saved = { meta = { schemaVersion = 1, moduleVersion = '0.1.0', createdAt = 5 },
        consent = { accepted = true, version = 2, acceptedAt = 7, paused = false } }
    local ns, messages = login(saved)
    eq(ns.db.consent.version, ns.Consent.NOTICE_VERSION); eq(ns.db.consent.acceptedAt, 7)
    eq(ns.Consent.State(ns.db, ns.runtime), 'collecting')
    has(table.concat(messages, '\n'), 'It never records')
end)

test('data collection is not started by itself when the saved data are of a newer schema', function()
    local ns = login({ meta = { schemaVersion = 99 } })
    eq(ns.Consent.State(ns.db, ns.runtime), 'blocked-schema')
    eq(_G.TitanGatheredForeverDiscoveryDB.consent, nil)
end)

test('the plugin of Titan Panel carries the whole name of the module and its own icon', function()
    local frames = client()
    local registered
    _G.LibStub = { GetLibrary = function()
        return { NewDataObject = function(_, name, object) registered = { name = name, object = object }; return object end }
    end }
    local ns = load({ raw = true })
    ns.Main.Start()
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', FOLDER)
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')
    _G.LibStub = nil
    eq(registered.name, 'TitanGatheredForeverDiscovery')
    eq(registered.object.label, 'Titan Gathered Forever: Discovery')
    has(registered.object.icon, 'TitanGatheredForever_Discovery')
end)

test('the window of the collected data is in the menu of the add-on (the minimap button and Titan Panel)', function()
    local frames = client()
    local extensions = {}
    local ns = load({ raw = true })
    _G.TitanGatheredForeverV3.Titan = { AddMenuExtension = function(fn) extensions[#extensions + 1] = fn end }
    ns.Main.Start()
    frames[1].OnEvent(frames[1], 'ADDON_LOADED', FOLDER)
    frames[1].OnEvent(frames[1], 'PLAYER_LOGIN')
    eq(#extensions, 1)
    local buttons = {}
    extensions[1]({ CreateButton = function(_, label, fn) buttons[#buttons + 1] = { label, fn } end })
    eq(#buttons, 1); has(buttons[1][1], 'Discovery')
    local toggled = 0
    ns.Window.Toggle = function() toggled = toggled + 1 end
    buttons[1][2](); eq(toggled, 1)
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


-- Milestone 2: batch runner, progress, cancel, abort events.
local function runnerEnv(ns, options)
    options = options or {}
    local clock = { ms = 0 }
    ns.env.clock = function() return clock.ms end
    ns.env.inCombat = function() return options.combat == true end
    return clock
end

local function spec(ns, clock, shape)
    local record = { steps = {}, finished = 0, aborted = nil, totalCalls = 0 }
    local phases = {}
    for index, count in ipairs(shape or { 3, 2 }) do
        phases[index] = { label = 'Phase' .. index .. 'Label',
            total = function() record.totalCalls = record.totalCalls + 1; return count end,
            step = function(i) clock.ms = clock.ms + 1; record.steps[#record.steps + 1] = index .. ':' .. i end }
    end
    return { name = 'Test operation', phases = phases,
        onFinish = function() record.finished = record.finished + 1 end,
        onAbort = function(reason) record.aborted = reason end }, record
end

local function runAll(ns)
    local guard = 0
    while ns.Runner.Active() do ns.Runner.Tick(); guard = guard + 1; assert(guard < 1000, 'operation never ended') end
end

test('an operation runs its phases step by step within the time budget of one tick', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 4, 4 })
    eq(ns.Runner.Start(operation), true)
    eq(ns.Runner.Active(), true)
    ns.Runner.Tick()
    eq(#record.steps, ns.Runner.BUDGET_MS)           -- one millisecond per step: the tick stops at the budget
    runAll(ns)
    eq(table.concat(record.steps, ','), '1:1,1:2,1:3,1:4,2:1,2:2,2:3,2:4')
    eq(record.finished, 1); eq(ns.Runner.Active(), false)
end)

test('a tick always does at least one step, even when a single step exceeds the budget', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 3 })
    operation.phases[1].step = function(i) clock.ms = clock.ms + 50; record.steps[#record.steps + 1] = i end
    ns.Runner.Start(operation)
    ns.Runner.Tick()
    eq(#record.steps, 1)
end)

test('start, every phase and the end are reported in chat', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation = spec(ns, clock, { 2, 2 })
    ns.Runner.Start(operation); runAll(ns)
    local text = joined(ns)
    has(text, 'Test operation'); has(text, 'Phase 1 of 2'); has(text, 'Phase1Label')
    has(text, 'Phase 2 of 2'); has(text, 'Phase2Label'); has(text, 'Finished')
end)

test('progress reports the operation, phase, counts and elapsed time, and nothing when idle', function()
    local ns = ready(); local clock = runnerEnv(ns)
    eq(ns.Runner.Progress(), nil)
    local operation = spec(ns, clock, { 10, 10 })
    ns.Runner.Start(operation)
    clock.ms = 2000
    ns.Runner.Tick()
    local progress = ns.Runner.Progress()
    eq(progress.name, 'Test operation'); eq(progress.phaseIndex, 1); eq(progress.phaseCount, 2)
    eq(progress.phaseLabel, 'Phase1Label'); eq(progress.total, 10); eq(progress.done, ns.Runner.BUDGET_MS)
    assert(progress.fraction > 0 and progress.fraction < 0.5, 'overall fraction ' .. tostring(progress.fraction))
    assert(progress.elapsed >= 0)
    runAll(ns)
    eq(ns.Runner.Progress(), nil)
end)

test('only one operation runs at a time', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local first = spec(ns, clock); local second = spec(ns, clock)
    eq(ns.Runner.Start(first), true)
    local ok, reason = ns.Runner.Start(second)
    eq(ok, false); eq(reason, 'busy')
    eq(ns.Runner.Progress().name, 'Test operation')
end)

test('an operation does not start during combat or with an invalid description', function()
    local ns = ready(); local clock = runnerEnv(ns, { combat = true })
    local ok, reason = ns.Runner.Start((spec(ns, clock)))
    eq(ok, false); eq(reason, 'combat'); eq(ns.Runner.Active(), false)
    clock = runnerEnv(ns)
    local _, why = ns.Runner.Start({ name = 'x', phases = {} })
    eq(why, 'invalid')
    _, why = ns.Runner.Start({ phases = { { label = 'a', total = 1, step = function() end } } })
    eq(why, 'invalid')
    _, why = ns.Runner.Start(nil)
    eq(why, 'invalid')
end)

test('cancel stops the operation, tells its owner why and reports it', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 10 })
    ns.Runner.Start(operation); ns.Runner.Tick()
    eq(ns.Runner.Cancel('cancelled by command'), true)
    eq(ns.Runner.Active(), false); eq(record.aborted, 'cancelled by command'); eq(record.finished, 0)
    has(joined(ns), 'Stopped'); has(joined(ns), 'cancelled by command')
    eq(ns.Runner.Cancel('again'), false)
    ns.Runner.Tick()                                  -- a tick without an operation does nothing
end)

test('an error in a step stops the operation with the message and never escapes', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 5 })
    operation.phases[1].step = function(i) if i == 2 then error('boom') end end
    ns.Runner.Start(operation)
    ns.Runner.Tick()
    eq(ns.Runner.Active(), false)
    has(record.aborted, 'boom'); has(joined(ns), 'boom')
end)

test('an error in the total or the finish handler is contained too', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 2 })
    operation.phases[1].total = function() error('no total') end
    ns.Runner.Start(operation); ns.Runner.Tick()
    eq(ns.Runner.Active(), false); has(record.aborted, 'no total')
    local second = spec(ns, clock, { 1 })
    second.onFinish = function() error('late') end
    ns.Runner.Start(second); runAll(ns)
    eq(ns.Runner.Active(), false)
    has(joined(ns), 'Finished')
end)

test('a phase total is read when the phase starts', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 2, 2 })
    ns.Runner.Start(operation)
    eq(record.totalCalls, 1)                           -- only the first phase was started so far
    runAll(ns)
    eq(record.totalCalls, 2)
end)

test('an empty phase is skipped without a message and the next one starts at once', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 0, 2 })
    ns.Runner.Start(operation)
    eq(ns.Runner.Progress().phaseIndex, 2)
    runAll(ns)
    eq(table.concat(record.steps, ','), '2:1,2:2')
    lacks(joined(ns), 'Phase1Label')
end)

test('listeners hear about start, phase changes, finish and abort', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local heard = {}
    ns.Runner.Listen(function(event, state) heard[#heard + 1] = event .. (state and state.name and '' or '?') end)
    local operation = spec(ns, clock, { 1, 1 })
    ns.Runner.Start(operation); runAll(ns)
    eq(table.concat(heard, ','), 'start,phase,phase,finish')
    heard = {}
    local second = spec(ns, clock, { 3 })
    ns.Runner.Start(second); ns.Runner.Cancel('x')
    eq(table.concat(heard, ','), 'start,phase,abort')
end)

test('the progress text names the operation, the phase, the counts and the elapsed time', function()
    local ns = ready()
    local lines = ns.Progress.Format({ name = 'Reading recipes', phaseIndex = 2, phaseCount = 5, phaseLabel = 'Tailoring',
        done = 120, total = 400, elapsed = 12.34, fraction = 0.3 })
    has(lines.title, 'Reading recipes'); has(lines.phase, 'Phase 2 of 5'); has(lines.phase, 'Tailoring')
    has(lines.count, '120'); has(lines.count, '400'); has(lines.count, '30%')
    has(lines.elapsed, '12.3')
end)

test('the self test is a three phase operation that records nothing', function()
    local ns = ready(); local clock = runnerEnv(ns)
    local work = 0
    local operation = ns.SelfTest.Spec({ steps = 5, work = function() work = work + 1; clock.ms = clock.ms + 1 end })
    eq(#operation.phases, 3)
    ns.Runner.Start(operation); runAll(ns)
    eq(work, 15); eq(ns.Database.Count(ns.db), 0)
    has(joined(ns), 'Finished')
end)

test('cancel and selftest commands drive the runner and are listed in the help', function()
    local ns = ready(); local clock = runnerEnv(ns)
    ns.Commands.Handle('cancel'); has(joined(ns), 'Nothing is running')
    ns.printed = {}
    ns.Commands.Handle('selftest')
    eq(ns.Runner.Active(), true); has(joined(ns), 'Self test')
    ns.printed = {}
    ns.Commands.Handle('selftest')
    has(joined(ns), 'already running')
    ns.printed = {}
    ns.Commands.Handle('status'); has(joined(ns), 'Operation'); has(joined(ns), 'Self test')
    ns.printed = {}
    ns.Commands.Handle('cancel')
    eq(ns.Runner.Active(), false); has(joined(ns), 'cancelled by command')
    ns.Consent.Accept(ns.db, ns.runtime, 1)
    ns.printed = {}
    ns.Commands.Handle('help')
    has(joined(ns), '/tgfd cancel'); has(joined(ns), '/tgfd selftest')
end)

test('the self test refuses to start in combat and says so', function()
    local ns = ready(); runnerEnv(ns, { combat = true })
    ns.Commands.Handle('selftest')
    eq(ns.Runner.Active(), false); has(joined(ns), 'combat')
end)

test('an operation shows a progress frame, ticks from its own frame and hides both at the end', function()
    local created, messages = client()
    local ns = load({ raw = true })
    ns.Main.Start()
    created[1].OnEvent(created[1], 'ADDON_LOADED', FOLDER)
    eq(#created, 1)                                   -- idle: only the event frame exists, nothing ticks
    local clock = runnerEnv(ns)
    local operation = spec(ns, clock, { 2 })
    ns.Runner.Start(operation)
    local ticker = ns.ticker
    assert(ticker and ticker.shown, 'no visible ticker frame')
    ticker.OnUpdate(ticker, 0.016)
    ticker.OnUpdate(ticker, 0.016)
    eq(ns.Runner.Active(), false)
    eq(ticker.shown, false)
end)

test('abort events are registered only while an operation runs and cancel it', function()
    local created = client()
    -- A paused module: it listens to nothing but the operation (a collecting one also registers its collectors).
    _G.TitanGatheredForeverDiscoveryDB = { meta = { schemaVersion = 1, moduleVersion = '0.1.0', createdAt = 5 },
        consent = { accepted = true, version = 3, acceptedAt = 7, paused = true } }
    local ns = load({ raw = true })
    ns.Main.Start()
    local frame = created[1]
    frame.OnEvent(frame, 'ADDON_LOADED', FOLDER)
    frame.OnEvent(frame, 'PLAYER_LOGIN')
    local idle = table.concat(frame.events, ',')
    assert(not idle:find('REGEN', 1, true) and not idle:find('LEAVING', 1, true) and not idle:find('LOOT', 1, true), idle)
    local clock = runnerEnv(ns)
    local operation, record = spec(ns, clock, { 5 })
    ns.Runner.Start(operation)
    local busy = table.concat(frame.events, ',')
    has(busy, 'PLAYER_REGEN_DISABLED'); has(busy, 'PLAYER_LEAVING_WORLD')
    frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
    eq(ns.Runner.Active(), false); has(record.aborted, 'combat')
    eq(table.concat(frame.events, ','), idle)
    local second, record2 = spec(ns, clock, { 5 })
    ns.Runner.Start(second)
    frame.OnEvent(frame, 'PLAYER_LEAVING_WORLD')
    eq(ns.Runner.Active(), false); has(record2.aborted, 'loading')
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
