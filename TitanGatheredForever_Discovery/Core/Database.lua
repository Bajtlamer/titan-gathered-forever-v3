local _, ns = ...
-- The saved table TitanGatheredForeverDiscoveryDB. It is separate from the core's table.
local Database = {}
ns.Database = Database

Database.SCHEMA_VERSION = 1
Database.CATEGORIES = { 'loot', 'npcs', 'vendors', 'entities', 'quests', 'areas', 'skills' }

-- Returns the saved table and 'ok', or the untouched table and 'newer' when it was written by a newer schema.
function Database.Init(existing, moduleVersion, now)
    local db = existing
    if type(db) ~= 'table' then db = {} end
    local schema = type(db.meta) == 'table' and db.meta.schemaVersion
    if type(schema) == 'number' and schema > Database.SCHEMA_VERSION then return db, 'newer' end
    if type(db.meta) ~= 'table' then db.meta = {} end
    local meta = db.meta
    meta.schemaVersion = Database.SCHEMA_VERSION
    meta.createdAt = meta.createdAt or now
    meta.createdWith = meta.createdWith or meta.moduleVersion or moduleVersion
    meta.moduleVersion = moduleVersion
    if type(db.consent) ~= 'table' then db.consent = {} end
    if db.consent.accepted == nil then db.consent.accepted = false end
    if db.consent.paused == nil then db.consent.paused = false end
    if type(db.data) ~= 'table' then db.data = {} end
    for _, category in ipairs(Database.CATEGORIES) do
        if type(db.data[category]) ~= 'table' then db.data[category] = {} end
    end
    return db, 'ok'
end

function Database.CategoryCount(db, category)
    local count = 0
    local records = type(db) == 'table' and type(db.data) == 'table' and db.data[category]
    if type(records) ~= 'table' then return 0 end
    for _ in pairs(records) do count = count + 1 end
    return count
end

function Database.Count(db)
    local total = 0
    for _, category in ipairs(Database.CATEGORIES) do total = total + Database.CategoryCount(db, category) end
    return total
end
