local _, ns = ...
-- What may be recorded about an entity. Only creatures and game objects are identified, by their numeric ID. A player,
-- a pet and anything else is never recorded: no GUID, no name.
local Privacy = {}
ns.Privacy = Privacy

local ALLOWED = { Creature = true, GameObject = true }

-- 'Creature', 12345 for a creature or game object GUID; nothing for anything else.
function Privacy.Entity(guid)
    if type(guid) ~= 'string' or not ns.Safe.Public(guid) then return nil end
    local kind, id = guid:match('^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$')
    if not kind or not ALLOWED[kind] then return nil end
    return kind, tonumber(id)
end

function Privacy.Key(kind, id)
    return kind .. ':' .. id
end

-- A unit description from the client adapter that must be skipped.
function Privacy.Excluded(info)
    return type(info) ~= 'table' or info.isPlayer == true or info.playerControlled == true
end
