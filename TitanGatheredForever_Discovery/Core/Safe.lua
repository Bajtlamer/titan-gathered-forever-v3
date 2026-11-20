local _, ns = ...
-- Helpers for values from the game client: restricted (secret) values and errors never reach the collectors.
local Safe = {}
ns.Safe = Safe

function Safe.Public(value)
    return not (issecretvalue and issecretvalue(value))
end

-- The results of fn(...) after a successful pcall, or nothing.
local function pack(...) return select('#', ...), { ... } end

function Safe.Call(fn, ...)
    if type(fn) ~= 'function' then return end
    local count, results = pack(pcall(fn, ...))
    if not results[1] then return end
    return unpack(results, 2, count)
end

function Safe.String(value)
    if type(value) == 'string' and Safe.Public(value) then return value end
end

function Safe.Number(value)
    if type(value) == 'number' and Safe.Public(value) then return value end
end
