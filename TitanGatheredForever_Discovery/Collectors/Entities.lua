local _, ns = ...
-- Game objects (nodes, chests, mailboxes) met through loot sources and the interaction unit.
local Entities = {}
ns.Entities = Entities

function Entities.Seen(id, name, service)
    local record = ns.Records.Touch(ns.db.data.entities, ns.Privacy.Key('GameObject', id), ns.Records.Context())
    record.kind, record.id = 'GameObject', id
    if type(name) == 'string' then record.name = name end
    if service then ns.Records.Count(record, 'services', service) end
    return record
end

-- A game object that was a source of loot: noted without counting it as a sighting of its own.
function Entities.Source(id)
    local record = ns.Records.Ensure(ns.db.data.entities, ns.Privacy.Key('GameObject', id), ns.Records.Context())
    record.kind, record.id = 'GameObject', id
    ns.Records.Count(record, 'lootSources', 'loot')
    return record
end
