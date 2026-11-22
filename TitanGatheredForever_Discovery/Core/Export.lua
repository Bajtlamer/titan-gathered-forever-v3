local _, ns = ...
-- Export and archive. A game addon cannot write a file; its data reach the disk in the SavedVariables file when the game
-- saves (/reload or logout). So "export" checks privacy and stamps the data with versions, counts and checksums, and the
-- user hands that file over. "Archive" clears the observations from the game, but only when the file provably holds them:
-- an export exists, the game was reloaded since, recording is stopped and the data are unchanged since the export.
local Export = {}
ns.Export = Export

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, inner in pairs(value) do result[key] = copy(inner) end
    return result
end

-- The phases that add every record of every category to a checksum state of that category.
local function checksumPhases(db, sums)
    local phases = {}
    for _, category in ipairs(ns.Database.CATEGORIES) do
        local keys
        sums[category] = ns.Checksum.New()
        phases[#phases + 1] = {
            label = 'Checksum: ' .. ns.Compare.LABELS[category],
            total = function() keys = ns.Util.SortedKeys(db.data[category]); return #keys end,
            step = function(index) ns.Checksum.Add(sums[category], ns.Checksum.Entry(keys[index], db.data[category][keys[index]])) end,
        }
    end
    return phases
end

local function results(sums)
    local checksums, list = {}, {}
    for _, category in ipairs(ns.Database.CATEGORIES) do
        checksums[category] = ns.Checksum.Hex(sums[category])
        list[#list + 1] = checksums[category]
    end
    return checksums, ns.Checksum.Combine(list)
end

function Export.Spec(db)
    local audit, sums = ns.Audit.NewState(), {}
    local phases = ns.Audit.Phases(db, audit)
    for _, phase in ipairs(checksumPhases(db, sums)) do phases[#phases + 1] = phase end
    return {
        name = 'Export check', phases = phases,
        onFinish = function()
            local Text = ns.Text
            if audit.count > 0 then
                ns.Print(Text.Label('Data were not exported. '))
                ns.Audit.Report(audit)
                return
            end
            local checksums, total = results(sums)
            local counts = {}
            for _, category in ipairs(ns.Database.CATEGORIES) do counts[category] = ns.Database.CategoryCount(db, category) end
            db.export = { schemaVersion = ns.Database.SCHEMA_VERSION, exportedAt = ns.env.now(), moduleVersion = ns.env.moduleVersion,
                client = copy(db.meta.client), builds = copy(db.meta.builds), baselineVersion = db.compare and db.compare.baselineVersion,
                counts = counts, total = ns.Database.Count(db), checksums = checksums, checksum = total, session = ns.state.session }
            ns.Print(Text.Label('Export check passed: ') .. Text.Value(db.export.total) .. Text.Label(' records, no private data found, checksum ')
                .. Text.Value(total) .. Text.Label('.'))
            ns.Print(Text.Label('Now type ') .. Text.Value('/reload') .. Text.Label(' (or log out) so the game writes the file, then send ')
                .. Text.Value('TitanGatheredForever_Discovery.lua') .. Text.Label(' from ') .. Text.Value('WTF/Account/<your account>/SavedVariables/')
                .. Text.Label(' to the owner. Recording continues; export again after more play.'))
        end,
    }
end

-- true, or false and why: 'noexport', 'archived', 'recording', 'noreload' or 'empty'.
function Export.CanArchive()
    local db = ns.db
    if type(db.export) ~= 'table' then return false, 'noexport' end
    if db.export.archived then return false, 'archived' end
    if ns.Consent.State(db, ns.runtime) == 'collecting' then return false, 'recording' end
    if db.export.session == ns.state.session then return false, 'noreload' end
    if ns.Database.Count(db) == 0 then return false, 'empty' end
    return true
end

-- Checks that the data are unchanged since the export and only then clears them.
function Export.ArchiveSpec(db)
    local sums = {}
    local phases = checksumPhases(db, sums)
    return {
        name = 'Archive check', phases = phases,
        onFinish = function()
            local Text = ns.Text
            local checksums, total = results(sums)
            if total ~= db.export.checksum then
                ns.Print(Text.Label('The data changed since the export, so nothing was cleared. Keep recording stopped and run ') .. Text.Value('/tgfd export')
                    .. Text.Label(' again.'))
                return
            end
            db.archives[#db.archives + 1] = { archivedAt = ns.env.now(), exportedAt = db.export.exportedAt, total = db.export.total,
                counts = copy(db.export.counts), checksum = total }
            for _, category in ipairs(ns.Database.CATEGORIES) do db.data[category] = {} end
            db.compare, ns.results, db.export.archived = nil, nil, true
            if ns.Stats then ns.Stats.Refresh() end
            ns.Print(Text.Label('Archived: ') .. Text.Value(db.export.total) .. Text.Label(' records were cleared from the game. The file you copied holds them (checksum ')
                .. Text.Value(total) .. Text.Label(').'))
        end,
    }
end
