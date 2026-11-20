local _, ns = ...
-- Creatures seen by target or mouseover, and every contact with an NPC (gossip, vendor, trainer, quests, flights,
-- bank, repair). A creature is described once per session; every contact counts its service. Positions are kept
-- outside instances only, a few per creature, so a creature that moves is visible without growing the data.
local Npc = {}
ns.Npc = Npc

local MAX_POSITIONS, NEAR, MAX_SESSION = 5, 0.01, 5000
local session, sessionSize = {}, 0

function Npc.ResetSession() session, sessionSize = {}, 0 end

local function addPosition(record)
    record.positions = record.positions or {}
    local where = ns.api.Position()
    if type(where) ~= 'table' or #record.positions >= MAX_POSITIONS then return end
    for _, known in ipairs(record.positions) do
        if known.mapID == where.mapID and math.abs(known.x - where.x) < NEAR and math.abs(known.y - where.y) < NEAR then return end
    end
    record.positions[#record.positions + 1] = { mapID = where.mapID, x = where.x, y = where.y }
end

local function describe(record, info)
    if type(info.name) == 'string' then record.name = info.name end
    if type(info.level) == 'number' and info.level > 0 then
        record.minLevel = math.min(record.minLevel or info.level, info.level)
        record.maxLevel = math.max(record.maxLevel or info.level, info.level)
    end
    record.classification = info.classification or record.classification
    record.creatureType = info.creatureType or record.creatureType
    record.family = info.family or record.family
    if ns.state.areaKey then ns.Records.Count(record, 'areas', ns.state.areaKey) end
end

-- The record and ID of a creature (nothing for a game object, a player, a pet or nothing at all).
local function note(unit, service)
    local info = ns.api.Unit(unit)
    if ns.Privacy.Excluded(info) then return end
    local kind, id = ns.Privacy.Entity(info.guid)
    if not kind then return end
    if kind == 'GameObject' then
        ns.Entities.Seen(id, info.name, service)
        return nil, id, kind
    end
    local ctx = ns.Records.Context()
    local bucket = ns.db.data.npcs
    local first = not session[info.guid]
    local record
    if first then
        if sessionSize >= MAX_SESSION then Npc.ResetSession() end
        session[info.guid] = true; sessionSize = sessionSize + 1
        record = ns.Records.Touch(bucket, id, ctx)
        describe(record, info)
    else
        record = ns.Records.Ensure(bucket, id, ctx)
    end
    record.positions = record.positions or {}
    if first or service then addPosition(record) end
    if service then ns.Records.Count(record, 'services', service) end
    return record, id, kind
end

function Npc.Seen(unit) return note(unit, nil) end
function Npc.Contact(unit, service) return note(unit, service) end
