local _, ns = ...
-- Compares the observations with the baseline, category by category. The states are:
--   new          observed, and the baseline can say that it does not hold it
--   different    in the baseline, but name, price, cost or requirement differ (details say which)
--   unchanged    in the baseline and equal in everything that can be compared
--   unbaselined  the baseline cannot answer for this category; it is compared offline with the catalogue files
-- A row also says whether it was seen on another build than the baseline's target build and on more than one build.
-- The seed holds only profession trainers and recipe vendors, so an NPC outside it is not "new" by that alone.
local Compare = {}
ns.Compare = Compare

Compare.LABELS = { loot = 'Loot', npcs = 'NPCs', vendors = 'Vendors and trainers', entities = 'Entities',
    quests = 'Quests', areas = 'Areas', skills = 'Professions', recipes = 'Recipes', maps = 'Maps' }

local NO_BASELINE = 'No baseline in the game for this category; it is compared offline with the catalogue files.'

local sortedKeys = ns.Util.SortedKeys

local function classifyLoot(key, _, baseline)
    if baseline.item(key) then return 'unchanged', 'In the installed catalogue.', {} end
    return 'new', 'Not in the installed catalogue modules (the catalogue is not complete).', {}
end

local function classifyNpc(key, record, baseline)
    local seed = baseline.npc(key)
    if not seed then
        return 'unbaselined', 'The NPC seed holds only profession trainers and recipe vendors; see vendors and trainers.', {}
    end
    local details = {}
    if type(record.name) == 'string' and seed.n and record.name ~= seed.n then
        details[#details + 1] = { field = 'name', baseline = seed.n, observed = record.name }
    end
    if #details > 0 then return 'different', 'The name differs from the seed.', details end
    return 'unchanged', 'In the NPC seed.', details
end

local function classifyVendor(key, record, baseline)
    local goods, taught = record.goods or {}, record.taught or {}
    local seed = baseline.npc(key)
    if not seed then
        for _, row in pairs(taught) do
            if row.skillName and baseline.professions[row.skillName] then
                return 'new', 'A profession trainer that is not in the NPC seed.', {}
            end
        end
        return 'unbaselined', 'Goods and lessons of this NPC have no baseline in the seed.', {}
    end
    local details = {}
    if seed.v and next(goods) then
        for _, row in ipairs(seed.v) do
            local item = goods[row[1]]
            if not item then
                details[#details + 1] = { field = 'notOffered', itemID = row[1] }
            elseif row[3] and row[3] > 0 and item.price and item.price ~= row[3] then
                details[#details + 1] = { field = 'price', itemID = row[1], baseline = row[3], observed = item.price }
            end
        end
    end
    if seed.t and next(taught) then
        local byName = {}
        for _, row in ipairs(seed.t) do byName[row[2]] = row end
        for _, name in ipairs(sortedKeys(taught)) do
            local row, seeded = taught[name], byName[name]
            if not seeded then
                if row.skillName and baseline.professions[row.skillName] then
                    details[#details + 1] = { field = 'notInSeed', name = name }
                end
            else
                if row.cost and row.cost ~= seeded[3] then
                    details[#details + 1] = { field = 'cost', name = name, baseline = seeded[3], observed = row.cost }
                end
                if row.skillRank and seeded[4] > 0 and row.skillRank ~= seeded[4] then
                    details[#details + 1] = { field = 'skill', name = name, baseline = seeded[4], observed = row.skillRank }
                end
            end
        end
        for _, row in ipairs(seed.t) do
            if not taught[row[2]] then details[#details + 1] = { field = 'notTaught', name = row[2] } end
        end
    end
    if #details > 0 then return 'different', 'Goods or lessons differ from the NPC seed.', details end
    return 'unchanged', 'Equal to the NPC seed in everything compared.', details
end

local function classifySkill(key, _, baseline)
    if baseline.professions[key] then return 'unchanged', 'One of the known professions.', {} end
    return 'new', 'Not one of the twelve known professions.', {}
end

local function normalize(name) return (tostring(name):lower():gsub('%s+', '')) end

local function classifyRecipe(key, record, baseline)
    local seed = baseline.recipe(key)
    if not seed then return 'new', 'Not in the installed catalogue modules (the catalogue is not complete).', {} end
    if record.profession and seed.profession and normalize(record.profession) ~= normalize(seed.profession) then
        return 'different', 'The profession differs from the catalogue.',
            { { field = 'profession', baseline = seed.profession, observed = record.profession } }
    end
    return 'unchanged', 'In the installed catalogue.', {}
end

local function unbaselined() return 'unbaselined', NO_BASELINE, {} end

local CLASSIFIERS = { loot = classifyLoot, npcs = classifyNpc, vendors = classifyVendor, skills = classifySkill,
    areas = unbaselined, quests = unbaselined, entities = unbaselined, recipes = classifyRecipe, maps = unbaselined }

-- The readable name of an area record: the instance, or the zone and the subzone (the key is a long text with bars).
function Compare.AreaName(record, key)
    if record.instanceName and record.instanceName ~= '' then return record.instanceName end
    local zone = record.zone ~= '' and record.zone or record.realZone
    local sub = record.subZone
    if zone and zone ~= '' and sub and sub ~= '' and sub ~= zone then return zone .. ' / ' .. sub end
    if zone and zone ~= '' then return zone end
    if sub and sub ~= '' then return sub end
    return type(key) == 'string' and key or nil
end

-- One row for one observed record.
function Compare.Classify(category, key, record, baseline, db)
    local state, why, details = CLASSIFIERS[category](key, record, baseline)
    local name = record.name or record.title or (type(key) == 'string' and key) or nil
    if category == 'areas' then name = Compare.AreaName(record, key) end
    if category == 'vendors' and db and db.data.npcs[key] then name = db.data.npcs[key].name or name end
    return {
        category = category, key = key, name = name, mapID = record.mapID, state = state, why = why, details = details,
        differences = #details, seen = record.seen, first = record.first, last = record.last,
        firstBuild = record.firstBuild, lastBuild = record.lastBuild,
        otherBuild = baseline.build ~= nil and record.lastBuild ~= nil and record.lastBuild ~= baseline.build,
        severalBuilds = record.firstBuild ~= nil and record.lastBuild ~= nil and record.firstBuild ~= record.lastBuild,
    }
end

function Compare.NewResults()
    local results = { rows = {}, counts = {}, totals = { new = 0, different = 0, unchanged = 0, unbaselined = 0, total = 0, otherBuild = 0 } }
    for _, category in ipairs(ns.Database.CATEGORIES) do
        results.rows[category] = {}
        results.counts[category] = { new = 0, different = 0, unchanged = 0, unbaselined = 0, total = 0, otherBuild = 0 }
    end
    return results
end

function Compare.Add(results, row)
    local rows = results.rows[row.category]
    rows[#rows + 1] = row
    for _, tally in ipairs({ results.counts[row.category], results.totals }) do
        tally[row.state] = tally[row.state] + 1
        tally.total = tally.total + 1
        if row.otherBuild then tally.otherBuild = tally.otherBuild + 1 end
    end
end

-- Keys of the baseline that no observation touched: seed NPCs (met as an NPC or as a vendor) and catalogue items
-- (never in a loot window). Other categories have nothing to list.
function Compare.NotSeen(db, baseline, category)
    local keys = {}
    if category == 'npcs' then
        for id in pairs(baseline.npcs()) do
            if not db.data.npcs[id] and not db.data.vendors[id] then keys[#keys + 1] = id end
        end
    elseif category == 'loot' then
        for id in pairs(baseline.items()) do
            if not db.data.loot[id] then keys[#keys + 1] = id end
        end
    end
    table.sort(keys)
    return keys
end

function Compare.Finalize(results, db, baseline)
    results.notSeen = { npcs = #Compare.NotSeen(db, baseline, 'npcs'), items = #Compare.NotSeen(db, baseline, 'loot') }
    return results
end

-- The whole comparison at once (the operation below does the same in steps).
function Compare.Run(db, baseline)
    local results = Compare.NewResults()
    for _, category in ipairs(ns.Database.CATEGORIES) do
        for _, key in ipairs(sortedKeys(db.data[category])) do
            Compare.Add(results, Compare.Classify(category, key, db.data[category][key], baseline, db))
        end
    end
    return Compare.Finalize(results, db, baseline)
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, inner in pairs(value) do result[key] = copy(inner) end
    return result
end

-- Only the counts are saved; the rows are rebuilt by the next comparison.
local function save(results, db, baseline)
    db.compare = { ranAt = ns.env.now(), baselineVersion = baseline.version, targetBuild = baseline.build,
        clientBuild = ns.state.build, modules = copy(baseline.modules), counts = copy(results.counts),
        totals = copy(results.totals), notSeen = copy(results.notSeen) }
end

local function report(results, baseline)
    local Text = ns.Text
    ns.Print(Text.Label('Comparison against Titan Gathered Forever ') .. Text.Value(baseline.version or 'unknown')
        .. Text.Label(' (target build ') .. Text.Value(baseline.build or 'unknown') .. Text.Label(', client build ')
        .. Text.Value(ns.state.build or 'unknown') .. Text.Label('):'))
    for _, category in ipairs(ns.Database.CATEGORIES) do
        local counts = results.counts[category]
        if counts.total > 0 then
            ns.Print(Text.Value(Compare.LABELS[category]) .. Text.Label(': ') .. Text.Value(counts.new) .. Text.Label(' new, ')
                .. Text.Value(counts.different) .. Text.Label(' different, ') .. Text.Value(counts.unchanged)
                .. Text.Label(' unchanged, ') .. Text.Value(counts.unbaselined) .. Text.Label(' without baseline'))
        end
    end
    ns.Print(Text.Label('Not seen: ') .. Text.Value(results.notSeen.npcs) .. Text.Label(' seed NPCs and ')
        .. Text.Value(results.notSeen.items) .. Text.Label(' catalogue items.'))
end

-- The comparison as an operation for the runner: one phase per category, one record per step.
function Compare.Spec(db, baseline)
    local results = Compare.NewResults()
    local phases = {}
    for _, category in ipairs(ns.Database.CATEGORIES) do
        local keys
        phases[#phases + 1] = {
            label = Compare.LABELS[category],
            total = function() keys = sortedKeys(db.data[category]); return #keys end,
            step = function(index)
                local key = keys[index]
                Compare.Add(results, Compare.Classify(category, key, db.data[category][key], baseline, db))
            end,
        }
    end
    return {
        name = 'Comparison', phases = phases,
        onFinish = function()
            Compare.Finalize(results, db, baseline)
            ns.results = results
            save(results, db, baseline)
            report(results, baseline)
            if ns.Stats then ns.Stats.Refresh() end
        end,
    }
end
