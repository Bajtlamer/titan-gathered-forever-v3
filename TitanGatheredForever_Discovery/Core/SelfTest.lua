local _, ns = ...
-- /tgfd selftest: a harmless operation that records nothing. It lets the user see the progress window and the lag
-- of a long operation, and checks the runner on the real client.
local SelfTest = {}
ns.SelfTest = SelfTest

local function spin()
    local clock = ns.env.clock
    local started = clock()
    while clock() - started < 1 do end
end

function SelfTest.Spec(options)
    options = options or {}
    local steps, work = options.steps or 200, options.work or spin
    local function phase(label) return { label = label, total = steps, step = function() work() end } end
    return { name = 'Self test', phases = { phase('Counting'), phase('Sorting'), phase('Checking') } }
end
