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
        and type(module.recipes) == 'table' and (module.book == nil or type(module.book) == 'table'),
        'Invalid Gathered profession module')
    assert(not Catalog.modules[module.id], 'Duplicate Gathered profession module')
    Catalog.modules[module.id] = module
    Catalog.bookCache, Catalog.productCache = nil, nil
    if ns.settings then
        Catalog.Rebuild(ns.settings)
        if ns.UpdateGathering then ns.UpdateGathering() end
        if ns.ScheduleRefresh then ns.ScheduleRefresh() end
    end
end

function Catalog.Rebuild(settings)
    Catalog.bookCache, Catalog.productCache = nil, nil
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

-- Everything below works with the profession addons that are installed and switched on, and nothing else: a player
-- who installed only Engineering carries the recipes, prices and pins of Engineering only.

-- Whether the addon of a profession (a module id such as Engineering or FirstAid) is installed and not switched off.
function Catalog.Installed(kind)
    if not Catalog.modules[kind] then return false end
    local categories = ns.settings and ns.settings.categories
    return not categories or categories[kind] ~= false
end

-- The professions of the game, installed or not. Data recorded for one of them that is not installed or is switched
-- off stays in the saved variables but is left out of the reports.
Catalog.professionKinds = { Alchemy = true, Blacksmithing = true, Cooking = true, Enchanting = true, Engineering = true,
    FirstAid = true, Fishing = true, Herbs = true, Leatherworking = true, Mining = true, Skinning = true, Tailoring = true }
function Catalog.Hidden(kind)
    return Catalog.professionKinds[kind] == true and not Catalog.Installed(kind)
end

-- The modules of the installed professions, by label.
function Catalog.InstalledKinds()
    local result = {}
    for _, module in ipairs(Catalog.Modules()) do
        if Catalog.Installed(module.id) then result[#result + 1] = module.id end
    end
    return result
end

local labelKinds = { ['First Aid'] = 'FirstAid', Herbalism = 'Herbs' }
-- The module id of a profession written in words.
function Catalog.KindOfLabel(label) return labelKinds[label] or label end

-- The recipes of the installed professions by recipe ID: { product, kind, { { item, quantity }, ... }, label }.
function Catalog.Book()
    if Catalog.bookCache then return Catalog.bookCache end
    local book = {}
    for _, module in ipairs(Catalog.Modules()) do
        if module.book and Catalog.Installed(module.id) then
            for recipeID, recipe in pairs(module.book) do
                book[recipeID] = { recipe[1], module.id, recipe[2], module.label }
            end
        end
    end
    Catalog.bookCache = book
    return book
end

-- Recipes of an installed profession that the books lack and the profession windows showed (Crafting.Harvest keeps
-- them in the saved variables): { product, kind, reagents, label } by recipe ID, never one that the books have.
function Catalog.ExtraRecipes()
    local result = {}
    local extra = ns.db and ns.db.recipeExtra
    if type(extra) ~= 'table' then return result end
    local book = Catalog.Book()
    for recipeID, recipe in pairs(extra) do
        if not book[recipeID] and type(recipe) == 'table' and recipe.out and recipe.profession and recipe.reagents then
            local kind = recipe.kind or Catalog.KindOfLabel(recipe.profession)
            if Catalog.Installed(kind) then result[recipeID] = { recipe.out, kind, recipe.reagents, recipe.profession } end
        end
    end
    return result
end

-- The products of the recipes of the installed professions (the books and the recipes taken from the windows), as a set.
function Catalog.IsProduct(itemID)
    if not Catalog.productCache then
        local set = {}
        for _, recipe in pairs(Catalog.Book()) do set[recipe[1]] = true end
        for _, recipe in pairs(Catalog.ExtraRecipes()) do set[recipe[1]] = true end
        Catalog.productCache = set
    end
    return Catalog.productCache[itemID] == true
end
