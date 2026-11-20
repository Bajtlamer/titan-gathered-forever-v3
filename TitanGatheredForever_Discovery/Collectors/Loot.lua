local _, ns = ...
-- Everything in a loot window, not limited to professions: the item, the quantity offered, the creature or object it
-- came from and the area. Offered and taken stay separate. The window is read at LOOT_READY and again at LOOT_OPENED
-- because the sources can arrive late; the second read only adds sources that are new.
local Loot = {}
ns.Loot = Loot

local current

local function addSource(record, known, guid)
    local kind, id = ns.Privacy.Entity(guid)
    if not kind then return false end
    local key = ns.Privacy.Key(kind, id)
    if known.sources[key] then return true end
    known.sources[key] = true
    ns.Records.Count(record, 'sources', key)
    local ctx = ns.Records.Context()
    if kind == 'GameObject' then
        ns.Entities.Source(id)
    else
        local npc = ns.Records.Ensure(ns.db.data.npcs, id, ctx)
        npc.positions = npc.positions or {}
        ns.Records.Count(npc, 'lootSources', 'loot')
    end
    return true
end

function Loot.Opened()
    local slots = ns.api.Loot()
    current = current or { slots = {} }
    local ctx = ns.Records.Context()
    for _, slot in ipairs(slots) do
        if slot.itemID then
            local known = current.slots[slot.slot]
            if known and known.itemID ~= slot.itemID then known = nil end
            local record
            if not known then
                record = ns.Records.Touch(ns.db.data.loot, slot.itemID, ctx)
                record.sources = record.sources or {}
                if type(slot.name) == 'string' then record.name = slot.name end
                record.quality = slot.quality or record.quality
                record.offered = (record.offered or 0) + (slot.quantity or 1)
                if ns.state.areaKey then ns.Records.Count(record, 'areas', ns.state.areaKey) end
                known = { itemID = slot.itemID, quantity = slot.quantity or 1, sources = {} }
                current.slots[slot.slot] = known
            else
                record = ns.db.data.loot[slot.itemID]
            end
            local found = false
            for _, guid in ipairs(slot.sources or {}) do
                if addSource(record, known, guid) then found = true end
            end
            if found and known.unsourced then
                known.unsourced = nil
                record.unsourced = record.unsourced and record.unsourced > 1 and record.unsourced - 1 or nil
            elseif not found and not known.unsourced and not next(known.sources) then
                known.unsourced = true
                record.unsourced = (record.unsourced or 0) + 1
            end
        end
    end
end

function Loot.SlotCleared(index)
    local known = current and current.slots[index]
    if not known or known.taken then return end
    known.taken = true
    local record = ns.db.data.loot[known.itemID]
    if record then record.taken = (record.taken or 0) + known.quantity end
end

function Loot.Closed() current = nil end
