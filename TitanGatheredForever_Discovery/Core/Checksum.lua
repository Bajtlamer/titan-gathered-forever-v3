local _, ns = ...
-- An Adler-32 checksum over a canonical text of the data (keys in a fixed order). It shows whether data are unchanged
-- since an export; it is an integrity check, not a security feature.
local Checksum = {}
ns.Checksum = Checksum

local MOD = 65521

function Checksum.New() return { a = 1, b = 0 } end

function Checksum.Add(state, text)
    local a, b = state.a, state.b
    for index = 1, #text do
        a = (a + text:byte(index)) % MOD
        b = (b + a) % MOD
    end
    state.a, state.b = a, b
end

function Checksum.Hex(state) return string.format('%04x%04x', state.b, state.a) end

function Checksum.Text(text)
    local state = Checksum.New()
    Checksum.Add(state, text)
    return Checksum.Hex(state)
end

local function write(value, out)
    local kind = type(value)
    if kind == 'table' then
        out[#out + 1] = '{'
        for _, key in ipairs(ns.Util.SortedKeys(value)) do
            write(key, out); out[#out + 1] = '='; write(value[key], out); out[#out + 1] = ','
        end
        out[#out + 1] = '}'
    elseif kind == 'string' then
        out[#out + 1] = string.format('%q', value)
    else
        out[#out + 1] = tostring(value)
    end
end

function Checksum.Canonical(value)
    local out = {}
    write(value, out)
    return table.concat(out)
end

-- The text one record adds to the checksum of its category.
function Checksum.Entry(key, record)
    return Checksum.Canonical(key) .. '=' .. Checksum.Canonical(record) .. ';'
end

function Checksum.Category(bucket)
    local state = Checksum.New()
    for _, key in ipairs(ns.Util.SortedKeys(bucket)) do Checksum.Add(state, Checksum.Entry(key, bucket[key])) end
    return Checksum.Hex(state)
end

-- One checksum over the checksums of all categories, in category order.
function Checksum.Combine(list) return Checksum.Text(table.concat(list, ',')) end
