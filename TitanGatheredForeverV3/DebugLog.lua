local _, ns = ...
local Log = {}
ns.DebugLog = Log

-- A bounded log kept in SavedVariables, so it ends up in the physical TitanGatheredForeverV3.lua file when
-- the client saves (on /reload and logout). It is written only while Debug mode is on.
local LIMIT, SLACK, TEXT_LIMIT = 1000, 100, 70
local traced = {
    TRAINER_SHOW = true, TRAINER_UPDATE = true, TRAINER_CLOSED = true,
    MERCHANT_SHOW = true, MERCHANT_UPDATE = true, MERCHANT_CLOSED = true,
    BANKFRAME_OPENED = true, BANKFRAME_CLOSED = true,
    PLAYER_ENTERING_WORLD = true, PLAYER_LEAVING_WORLD = true, PLAYER_DEAD = true,
    TRADE_SKILL_DATA_SOURCE_CHANGED = true, TRADE_SKILL_ITEM_CRAFTED_RESULT = true, TRADE_SKILL_CLOSE = true,
    LOOT_READY = true, LOOT_OPENED = true, LOOT_CLOSED = true, LOOT_SLOT_CLEARED = true,
    CHAT_MSG_COMBAT_HONOR_GAIN = true,
}

local function store() return ns.db and type(ns.db.debugLog) == 'table' and ns.db.debugLog or nil end
local function stamp()
    local seconds = time and time() or 0
    local fraction = GetTime and (GetTime() % 1) or 0
    return string.format('%s.%03d', date and date('%H:%M:%S', seconds) or tostring(seconds), math.floor(fraction * 1000))
end

function Log.Enabled() return ns.settings ~= nil and ns.settings.debugMode == true end

function Log.Add(category, text)
    if not Log.Enabled() then return end
    local entries = store()
    if not entries then return end
    entries[#entries + 1] = stamp() .. ' ' .. category .. ' ' .. tostring(text)
    if #entries > LIMIT + SLACK then
        local keep = {}
        for index = #entries - LIMIT + 1, #entries do keep[#keep + 1] = entries[index] end
        for index = 1, #entries do entries[index] = keep[index] end
    end
end

local function describe(...)
    local parts = {}
    for index = 1, math.min(select('#', ...), 4) do
        local value = (select(index, ...))
        if ns.IsPublic(value) then
            local kind = type(value)
            if kind == 'string' and value ~= '' then
                parts[#parts + 1] = #value > TEXT_LIMIT and (value:sub(1, TEXT_LIMIT) .. '...') or value
            elseif kind == 'number' or kind == 'boolean' then
                parts[#parts + 1] = tostring(value)
            end
        end
    end
    return #parts > 0 and (' (' .. table.concat(parts, ', ') .. ')') or ''
end

-- Called for every game event the addon handles; only the important ones are written.
function Log.Event(event, ...)
    if not Log.Enabled() then return end
    if event:find('^UNIT_SPELLCAST_') then
        local unit, _, spellID = ...
        if ns.IsPublic(unit) and unit == 'player' and ns.IsPublic(spellID) and type(spellID) == 'number' then
            Log.Add('event', event .. ' unit=player spell=' .. spellID)
        end
        return
    end
    if traced[event] then Log.Add('event', event .. describe(...)) end
end

function Log.Clear()
    local entries = store()
    if not entries then return end
    for index = #entries, 1, -1 do entries[index] = nil end
end
