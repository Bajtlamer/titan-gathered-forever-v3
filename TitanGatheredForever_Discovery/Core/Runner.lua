local _, ns = ...
-- Runs one long operation at a time in small steps, so the game keeps drawing. An operation is a name and a list of
-- phases { label, total (number or function, read when the phase starts), step(index) }. Every Tick works for at most
-- BUDGET_MS milliseconds (at least one step), so a long operation costs a little lag per frame instead of a freeze.
-- Nothing here starts by itself: operations are started only from a /tgfd command.
local Runner = {}
ns.Runner = Runner

Runner.BUDGET_MS = 5

local active
local listeners = {}

local function say(message) ns.Print(message) end

local function seconds(ms) return string.format('%.1f', ms / 1000) end

function Runner.Listen(fn) listeners[#listeners + 1] = fn end
function Runner.Active() return active ~= nil end

function Runner.Progress()
    if not active then return nil end
    local done, total = active.index, active.total or 0
    local inPhase = total > 0 and done / total or 0
    return {
        name = active.spec.name, phaseIndex = active.phase, phaseCount = #active.spec.phases,
        phaseLabel = active.spec.phases[active.phase].label, done = done, total = total,
        elapsed = (ns.env.clock() - active.startedAt) / 1000,
        fraction = (active.phase - 1 + inPhase) / #active.spec.phases,
    }
end

local function notify(event, state)
    for _, fn in ipairs(listeners) do pcall(fn, event, state) end
end

local function valid(spec)
    if type(spec) ~= 'table' or type(spec.name) ~= 'string' or spec.name == '' then return false end
    if type(spec.phases) ~= 'table' or #spec.phases == 0 then return false end
    for _, phase in ipairs(spec.phases) do
        if type(phase.label) ~= 'string' or type(phase.step) ~= 'function' then return false end
    end
    return true
end

local function finish()
    local state, spec = Runner.Progress(), active.spec
    local elapsed = ns.env.clock() - active.startedAt
    active = nil
    local Text = ns.Text
    say(Text.Label('Finished: ') .. Text.Value(spec.name) .. Text.Label(' in ') .. Text.Value(seconds(elapsed) .. ' s') .. Text.Label('.'))
    if spec.onFinish then pcall(spec.onFinish) end
    notify('finish', state)
end

local function abort(reason)
    local state, spec = Runner.Progress(), active.spec
    active = nil
    local Text = ns.Text
    say(Text.Label('Stopped: ') .. Text.Value(spec.name) .. Text.Label('. ') .. Text.Value(reason))
    if spec.onAbort then pcall(spec.onAbort, reason) end
    notify('abort', state)
end

-- Starts the next phase that has work. Finishes the operation when none is left. Returns false and the reason when
-- the total of a phase cannot be read.
local function beginPhase(index)
    local phases = active.spec.phases
    while index <= #phases do
        local phase = phases[index]
        local ok, total = pcall(function() if type(phase.total) == 'function' then return phase.total() end return phase.total end)
        if not ok or type(total) ~= 'number' or total < 0 then
            abort('error: ' .. tostring(ok and 'invalid total' or total))
            return false
        end
        if total > 0 then
            active.phase, active.index, active.total = index, 0, total
            local Text = ns.Text
            say(Text.Label('Phase ') .. Text.Value(index .. ' of ' .. #phases) .. Text.Label(': ') .. Text.Value(phase.label)
                .. Text.Label(' (') .. Text.Value(total) .. Text.Label(' items)'))
            notify('phase', Runner.Progress())
            return true
        end
        index = index + 1
    end
    finish()
    return true
end

-- true, or false with 'invalid', 'busy' or 'combat' (or 'error: ...' when the first phase cannot start).
function Runner.Start(spec)
    if not valid(spec) then return false, 'invalid' end
    if active then return false, 'busy' end
    if ns.env.inCombat() then return false, 'combat' end
    active = { spec = spec, phase = 1, index = 0, total = 0, startedAt = ns.env.clock() }
    local Text = ns.Text
    say(Text.Label('Started: ') .. Text.Value(spec.name) .. Text.Label(' (') .. Text.Value(#spec.phases) .. Text.Label(' phases). Stop it with /tgfd cancel.'))
    notify('start', Runner.Progress())
    local ok, reason = beginPhase(1)
    if not ok then return false, 'error' end
    return true
end

function Runner.Tick()
    if not active then return end
    local began = ns.env.clock()
    while active do
        if active.index >= active.total then
            if not beginPhase(active.phase + 1) then return end
        else
            active.index = active.index + 1
            local ok, err = pcall(active.spec.phases[active.phase].step, active.index)
            if not ok then abort('error: ' .. tostring(err)); return end
            if active and active.index >= active.total then
                if not beginPhase(active.phase + 1) then return end
            end
        end
        if active and ns.env.clock() - began >= Runner.BUDGET_MS then return end
    end
end

function Runner.Cancel(reason)
    if not active then return false end
    abort(reason or 'cancelled')
    return true
end
