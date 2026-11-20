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
    if state == 'blocked-scout' then
        return 'Blocked: ' .. table.concat(ns.runtime.scout, ', ') .. ' is loaded'
    end
    if state == 'blocked-schema' then return 'Blocked: saved data are from a newer version' end
    return STATE_TEXT[state]
end

local function refusal(reason)
    local Text = ns.Text
    if reason == 'scout' then
        return Text.Label('Cannot start: ') .. Text.Value(table.concat(ns.runtime.scout, ', ')) .. Text.Label(' is loaded. Disable or remove it and reload the interface.')
    end
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
    local consent = ns.db.consent
    if type(consent) == 'table' and consent.acceptedAt then
        say(Text.Label('Notice accepted: ') .. Text.Date(env.date('%Y-%m-%d %H:%M', consent.acceptedAt)))
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
    say(Text.Value(stateText(ns.Consent.State(ns.db, ns.runtime))) .. Text.Label('. Pause with /tgfd stop, see /tgfd status for what has been recorded.'))
end

local function stop()
    local Text = ns.Text
    if not ns.Consent.Stop(ns.db, ns.runtime) then say(Text.Label('Nothing to pause: run /tgfd accept first.')); return end
    say(Text.Value('Paused') .. Text.Label('. Resume with /tgfd start.'))
end

local function start()
    local Text = ns.Text
    if not ns.Consent.Start(ns.db, ns.runtime) then say(Text.Label('Nothing to resume: run /tgfd accept first.')); return end
    say(Text.Value(stateText(ns.Consent.State(ns.db, ns.runtime))) .. Text.Label('. Pause with /tgfd stop.'))
end

local handlers = { help = help, status = status, accept = accept, stop = stop, start = start }

function Commands.Handle(message)
    local Text = ns.Text
    local word = tostring(message or ''):lower():match('^%s*(%S*)') or ''
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
    handler()
end
