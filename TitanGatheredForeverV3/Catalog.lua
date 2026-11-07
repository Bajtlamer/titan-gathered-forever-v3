local _, ns = ...
local Catalog = { modules = {}, ids = {} }
ns.Catalog = Catalog
ns.Items, ns.Recipes = {}, {}

function Catalog.Get(itemID)
    if type(itemID) ~= 'number' then return nil end
    return ns.Items[itemID]
end

function Catalog.Modules()
    local modules = {}
    for _, module in pairs(Catalog.modules) do modules[#modules + 1] = module end
    table.sort(modules, function(a, b) return a.label < b.label end)
    return modules
end

function Catalog.RegisterModule(module)
    assert(type(module) == 'table' and type(module.id) == 'string'
        and type(module.label) == 'string' and type(module.items) == 'table'
        and type(module.recipes) == 'table', 'Invalid Gathered profession module')
    assert(not Catalog.modules[module.id], 'Duplicate Gathered profession module')
    Catalog.modules[module.id] = module
    if ns.settings then
        Catalog.Rebuild(ns.settings)
        if ns.UpdateGathering then ns.UpdateGathering() end
        if ns.ScheduleRefresh then ns.ScheduleRefresh() end
    end
end

function Catalog.Rebuild(settings)
    local items, recipes, ids, seen = {}, {}, {}, {}
    local categories = settings.categories or {}
    for _, module in ipairs(Catalog.Modules()) do
        if categories[module.id] ~= false then
            for itemID, source in pairs(module.items) do
                if not items[itemID] then
                    items[itemID] = { professions = {}, recipes = {}, recipeCounts = {}, uses = {}, group = module.label }
                    seen[itemID] = { professions = {}, recipes = {}, uses = {} }
                    ids[#ids + 1] = itemID
                end
                local target, visited = items[itemID], seen[itemID]
                for profession, count in pairs(source.recipeCounts or {}) do
                    target.recipeCounts[profession] = math.max(target.recipeCounts[profession] or 0, count)
                end
                for _, profession in ipairs(source.professions) do
                    if not visited.professions[profession] then
                        visited.professions[profession] = true
                        target.professions[#target.professions + 1] = profession
                    end
                end
                for _, recipeID in ipairs(source.recipes) do
                    if not visited.recipes[recipeID] then
                        visited.recipes[recipeID] = true
                        target.recipes[#target.recipes + 1] = recipeID
                        recipes[recipeID] = assert(module.recipes[recipeID], 'Missing Gathered recipe relationship')
                    end
                end
                for _, use in ipairs(source.uses) do
                    local key = use.kind .. ':' .. use.reason
                    if not visited.uses[key] then
                        visited.uses[key] = true
                        target.uses[#target.uses + 1] = use
                    end
                end
            end
        end
    end
    for _, record in pairs(items) do
        table.sort(record.professions)
        table.sort(record.recipes)
        local sampleCounts = {}
        for _, recipeID in ipairs(record.recipes) do
            local profession = recipes[recipeID].profession
            sampleCounts[profession] = (sampleCounts[profession] or 0) + 1
        end
        for profession, count in pairs(sampleCounts) do
            record.recipeCounts[profession] = math.max(record.recipeCounts[profession] or 0, count)
        end
    end
    table.sort(ids)
    ns.Items, ns.Recipes, Catalog.ids = items, recipes, ids
end

function Catalog.Group(record)
    return record.group
end

function Catalog.List()
    return Catalog.ids
end
