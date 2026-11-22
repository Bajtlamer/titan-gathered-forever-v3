local _, ns = ...
-- The privacy check: before data are handed over, every string and key in the observations is searched for a player or pet
-- GUID and for the name of the current character. The collectors never store them; this is a second line of defence.
local Audit = {}
ns.Audit = Audit

local MAX_LISTED = 50

local function suspicious(text, name)
    if text:find('Player%-%d') or text:find('^Pet%-%d') then return true end
    return name ~= nil and text:find(name, 1, true) ~= nil
end

local function playerName()
    local name = ns.api.PlayerName and ns.api.PlayerName()
    if type(name) == 'string' and #name >= 3 then return name end
end

local function check(category, key, record, name, state)
    state.checked = state.checked + 1
    ns.Util.Walk({ [key] = record }, function(text, path)
        if suspicious(text, name) then
            state.count = state.count + 1
            if #state.offenders < MAX_LISTED then state.offenders[#state.offenders + 1] = { path = category .. path, value = text } end
        end
    end)
end

function Audit.NewState() return { checked = 0, count = 0, offenders = {} } end

-- Every offender of the saved data at once (the operations below do the same in steps).
function Audit.Find(db)
    local state, name = Audit.NewState(), playerName()
    for _, category in ipairs(ns.Database.CATEGORIES) do
        for _, key in ipairs(ns.Util.SortedKeys(db.data[category])) do check(category, key, db.data[category][key], name, state) end
    end
    return state.offenders, state
end

-- The phases of the check, one per category, working on state.
function Audit.Phases(db, state)
    local phases, name = {}, playerName()
    for _, category in ipairs(ns.Database.CATEGORIES) do
        local keys
        phases[#phases + 1] = {
            label = 'Privacy check: ' .. ns.Compare.LABELS[category],
            total = function() keys = ns.Util.SortedKeys(db.data[category]); return #keys end,
            step = function(index) check(category, keys[index], db.data[category][keys[index]], name, state) end,
        }
    end
    return phases
end

-- The lines that say what the check found (nothing when it found nothing).
function Audit.Report(state)
    local Text = ns.Text
    ns.Print(Text.Label('Found ') .. Text.Value(state.count) .. Text.Label(' suspicious values. They look like a player or pet GUID or the name of this character. First: ')
        .. Text.Value(state.offenders[1].path))
    for index = 2, math.min(#state.offenders, 5) do ns.Print(Text.Value(state.offenders[index].path)) end
end

function Audit.Spec(db)
    local state = Audit.NewState()
    return {
        name = 'Privacy check', phases = Audit.Phases(db, state),
        onFinish = function()
            local Text = ns.Text
            if state.count == 0 then
                ns.Print(Text.Label('Privacy check passed: ') .. Text.Value(state.checked) .. Text.Label(' records checked, no private data found.'))
            else
                Audit.Report(state)
            end
        end,
    }
end
