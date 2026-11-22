local _, ns = ...
local Util = {}
ns.Util = Util

-- The keys of a table in a fixed order: numbers by value, strings alphabetically, other kinds by their text.
function Util.SortedKeys(source)
    local keys = {}
    for key in pairs(source or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if type(a) == type(b) and (type(a) == 'number' or type(a) == 'string') then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

-- Calls visit(text, path, isKey) for every string value and every string key inside a value.
function Util.Walk(value, visit, path, depth)
    path, depth = path or '', depth or 0
    if depth > 12 then return end
    if type(value) == 'string' then visit(value, path, false); return end
    if type(value) ~= 'table' then return end
    for _, key in ipairs(Util.SortedKeys(value)) do
        local child = path .. '/' .. tostring(key)
        if type(key) == 'string' then visit(key, child, true) end
        Util.Walk(value[key], visit, child, depth + 1)
    end
end
