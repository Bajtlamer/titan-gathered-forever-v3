local _, ns = ...
-- The /tgfd command. Every operation of the module is started from here.
local Commands = {}
ns.Commands = Commands

local STATE_TEXT = {
    unaccepted = 'Not started: the notice has not been accepted',
    paused = 'Paused',
    collecting = 'Collecting',
}

local function say(message) ns.Print(message) end

local function stateText(state)
    if state == 'blocked-schema' then return 'Blocked: saved data are from a newer version' end
    return STATE_TEXT[state]
end

local function refusal(reason)
    local Text = ns.Text
    return Text.Label('Cannot start: the saved data are from a newer version of this module and are left untouched.')
end

local function help()
    local Text = ns.Text
    local state = ns.Consent.State(ns.db, ns.runtime)
    if state == 'unaccepted' then
        for _, line in ipairs(ns.Consent.Notice()) do say(line) end
        return
    end
    say(Text.Label('Titan Gathered Forever: Discovery commands:'))
    say(Text.Value('/tgfd status') .. Text.Label(': state, versions, baseline and record counts'))
    say(Text.Value('/tgfd stop') .. Text.Label(': pause recording'))
    say(Text.Value('/tgfd start') .. Text.Label(': resume recording'))
    say(Text.Value('/tgfd scan recipes') .. Text.Label(' and ') .. Text.Value('/tgfd scan areas') .. Text.Label(': read recipes or map IDs (shows progress)'))
    say(Text.Value('/tgfd show') .. Text.Label(': open the overview window (also by clicking the Titan Panel plugin)'))
    say(Text.Value('/tgfd compare') .. Text.Label(': compare the observations with the Titan Gathered Forever data (shows progress)'))
    say(Text.Value('/tgfd selftest') .. Text.Label(': a harmless test of the progress window (records nothing)'))
    say(Text.Value('/tgfd cancel') .. Text.Label(': stop the running operation'))
    say(Text.Value('/tgfd help') .. Text.Label(': this list'))
end

local function status()
    local Text, env = ns.Text, ns.env
    local state = ns.Consent.State(ns.db, ns.runtime)
    local version, build = env.build()
    say(Text.Label('State: ') .. Text.Value(stateText(state)))
    say(Text.Label('Module version: ') .. Text.Value(env.moduleVersion or 'unknown'))
    say(Text.Label('Client: ') .. Text.Value(tostring(version) .. ' build ' .. tostring(build)))
    say(Text.Label('Baseline: Titan Gathered Forever ') .. Text.Value(env.coreVersion() or 'not loaded'))
    if (ns.runtime.errors or 0) > 0 then
        say(Text.Label('Collector errors: ') .. Text.Value(ns.runtime.errors) .. Text.Label(', last: ') .. Text.Value(ns.runtime.lastError))
    end
    local progress = ns.Runner.Progress()
    if progress then
        say(Text.Label('Operation: ') .. Text.Value(progress.name) .. Text.Label(', phase ') .. Text.Value(progress.phaseIndex .. ' of ' .. progress.phaseCount)
            .. Text.Label(' (') .. Text.Value(progress.phaseLabel) .. Text.Label('), ') .. Text.Value(progress.done .. ' of ' .. progress.total))
    end
    local consent = ns.db.consent
    if type(consent) == 'table' and consent.acceptedAt then
        say(Text.Label('Notice accepted: ') .. Text.Date(env.date('%Y-%m-%d %H:%M', consent.acceptedAt)))
    end
    local saved = ns.db.compare
    if type(saved) == 'table' then
        say(Text.Label('Last comparison: ') .. Text.Date(env.date('%Y-%m-%d %H:%M', saved.ranAt)) .. Text.Label(' against ')
            .. Text.Value(saved.baselineVersion or 'unknown') .. Text.Label(': ') .. Text.Value(saved.totals.new) .. Text.Label(' new, ')
            .. Text.Value(saved.totals.different) .. Text.Label(' different'))
    end
    say(Text.Label('Records: ') .. Text.Value(ns.Database.Count(ns.db)))
    local parts = {}
    for _, category in ipairs(ns.Database.CATEGORIES) do
        parts[#parts + 1] = Text.Label(category .. ' ') .. Text.Value(ns.Database.CategoryCount(ns.db, category))
    end
    say(table.concat(parts, Text.Label(', ')))
end

local function accept()
    local Text = ns.Text
    local ok, reason = ns.Consent.Accept(ns.db, ns.runtime, ns.env.now())
    if not ok then say(refusal(reason)); return end
    ns.Manager.Begin()
    ns.Stats.Refresh()
    say(Text.Value(stateText(ns.Consent.State(ns.db, ns.runtime))) .. Text.Label('. Pause with /tgfd stop, see /tgfd status for what has been recorded.'))
end

local function stop()
    local Text = ns.Text
    if not ns.Consent.Stop(ns.db, ns.runtime) then say(Text.Label('Nothing to pause: run /tgfd accept first.')); return end
    ns.Manager.Refresh()
    ns.Stats.Refresh()
    say(Text.Value('Paused') .. Text.Label('. Resume with /tgfd start.'))
end

local function start()
    local Text = ns.Text
    if not ns.Consent.Start(ns.db, ns.runtime) then say(Text.Label('Nothing to resume: run /tgfd accept first.')); return end
    ns.Manager.Begin()
    ns.Stats.Refresh()
    say(Text.Value(stateText(ns.Consent.State(ns.db, ns.runtime))) .. Text.Label('. Pause with /tgfd stop.'))
end

local function cancel()
    local Text = ns.Text
    if not ns.Runner.Cancel('cancelled by command') then say(Text.Label('Nothing is running.')) end
end

-- Starts an operation and explains a refusal.
local function startOperation(spec)
    local Text = ns.Text
    local ok, reason = ns.Runner.Start(spec)
    if ok then return end
    if reason == 'busy' then
        say(Text.Value(ns.Runner.Progress().name) .. Text.Label(' is already running. Stop it with /tgfd cancel first.'))
    elseif reason == 'combat' then
        say(Text.Label('Cannot start during combat. Try again after the fight.'))
    else
        say(Text.Label('The operation could not be started: ') .. Text.Value(reason))
    end
end

local function selftest() startOperation(ns.SelfTest.Spec()) end

local function compare()
    local baseline, reason = ns.Baseline.FromCore()
    if not baseline then say(ns.Text.Label(reason)); return end
    startOperation(ns.Compare.Spec(ns.db, baseline))
end

local function scanUsage()
    local Text = ns.Text
    say(Text.Value('/tgfd scan recipes') .. Text.Label(': read the recipes of the open profession window, also the ones you have not learned'))
    say(Text.Value('/tgfd scan areas [number]') .. Text.Label(': read the map IDs of the client (up to the number, default 4000)'))
end

local function scan(rest)
    local Text = ns.Text
    local what, argument = rest:match('^(%S*)%s*(.-)$')
    if what == '' then scanUsage(); return end
    if what ~= 'recipes' and what ~= 'areas' then
        say(Text.Label('Unknown scan: ') .. Text.Value(what))
        scanUsage()
        return
    end
    local state = ns.Consent.State(ns.db, ns.runtime)
    if state == 'unaccepted' or state == 'blocked-schema' then
        say(Text.Label('A scan records observations, so the notice must be accepted first: ') .. Text.Value('/tgfd accept'))
        return
    elseif state == 'paused' then
        say(Text.Label('Recording is paused. Resume it with ') .. Text.Value('/tgfd start') .. Text.Label(' before scanning.'))
        return
    end
    if what == 'areas' then startOperation(ns.Scans.AreaSpec(argument)); return end
    local spec = ns.Scans.RecipeSpec()
    if not spec then
        say(Text.Label('The game lists no recipes. Open the profession window yourself first; the module never opens it.'))
        return
    end
    startOperation(spec)
end

local function show() ns.Window.Toggle() end

local handlers = { scan = scan, show = show, cancel = cancel, selftest = selftest, compare = compare, help = help, status = status, accept = accept, stop = stop, start = start }

function Commands.Handle(message)
    local Text = ns.Text
    local word, rest = tostring(message or ''):lower():match('^%s*(%S*)%s*(.-)%s*$')
    word, rest = word or '', rest or ''
    if type(ns.db) ~= 'table' then
        say(Text.Label('Saved data are not loaded yet. Try again after the interface has finished loading.'))
        return
    end
    if word == '' then word = 'help' end
    local handler = handlers[word]
    if not handler then
        say(Text.Label('Unknown command: ') .. Text.Value(word))
        help()
        return
    end
    handler(rest)
end
