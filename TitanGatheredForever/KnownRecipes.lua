local _, ns = ...
local K = {}
ns.KnownRecipes = K

local prefixes = { Recipe = true, Pattern = true, Plans = true, Formula = true, Schematic = true,
    Manual = true, Design = true, Technique = true }
local skillKinds = { [171] = 'Alchemy', [164] = 'Blacksmithing', [185] = 'Cooking', [333] = 'Enchanting',
    [202] = 'Engineering', [129] = 'FirstAid', [165] = 'Leatherworking', [186] = 'Mining', [197] = 'Tailoring' }

function K.Strip(name)
    if type(name) ~= 'string' then return '' end
    local prefix, rest = name:match('^(%a+):%s*(.+)$')
    if prefix and prefixes[prefix] then name = rest end
    return (name:gsub('^%s+', ''):gsub('%s+$', ''))
end

function K.Normalize(name) return K.Strip(name):lower() end

local function store() return ns.db and ns.db.knownRecipes end

-- ids are the recipe IDs of the learned recipes, when the client gave them (older records have names only).
function K.Record(character, kind, names, now, ids)
    local saved = store()
    if not saved or not character then return end
    saved[character] = saved[character] or {}
    local set = {}
    for _, name in ipairs(names) do set[K.Normalize(name)] = true end
    local known
    if ids then
        known = {}
        for _, id in ipairs(ids) do known[id] = true end
    end
    saved[character][kind] = { at = now, names = set, ids = known }
end

-- true: known, false: read and not known, nil: this profession was never read for this character.
function K.IsKnown(character, kind, name)
    local saved = store()
    local entry = saved and saved[character] and saved[character][kind]
    if not entry then return nil end
    return entry.names[K.Normalize(name)] == true
end

-- true: the recipe ID is learned; false: the profession was read and it is not; nil: never read, or read before the
-- recipe IDs were kept (then only the name can tell).
function K.IsKnownID(character, kind, recipeID)
    local saved = store()
    local entry = saved and saved[character] and saved[character][kind]
    if not entry or not entry.ids then return nil end
    return entry.ids[recipeID] == true
end

function K.ReadAt(character, kind)
    local saved = store()
    local entry = saved and saved[character] and saved[character][kind]
    return entry and entry.at or nil
end

-- Reads the open profession window. A profession is recorded as read only when the client listed its recipes.
function K.Scan()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs or not ns.characterID then return end
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok or not ns.IsPublic(ids) or type(ids) ~= 'table' or #ids == 0 or #ids > 4096 then return end
    local byKind, byIDs = {}, {}
    for _, id in ipairs(ids) do
        local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        local okProfession, profession = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, id)
        if okInfo and okProfession and ns.IsPublic(info) and ns.IsPublic(profession)
            and type(info) == 'table' and type(profession) == 'table' then
            local kind = skillKinds[profession.parentProfessionID] or skillKinds[profession.professionID]
            if kind and ns.IsPublic(info.name) and type(info.name) == 'string'
                and ns.IsPublic(info.learned) and type(info.learned) == 'boolean' then
                byKind[kind] = byKind[kind] or {}
                byIDs[kind] = byIDs[kind] or {}
                if info.learned then
                    byKind[kind][#byKind[kind] + 1] = info.name
                    byIDs[kind][#byIDs[kind] + 1] = id
                end
            end
        end
    end
    local now = time and time() or 0
    for kind, names in pairs(byKind) do
        K.Record(ns.characterID, kind, names, now, byIDs[kind])
        if ns.DebugLog then ns.DebugLog.Add('recipes', kind .. ' read, ' .. #names .. ' learned recipes') end
    end
    -- The schematics of all the recipes of the profession: the number a craft makes, and recipes the book lacks.
    if ns.Crafting and ns.Crafting.Harvest then ns.Crafting.Harvest(ids) end
    if ns.RecipeBrowser and ns.RecipeBrowser.Refresh then ns.RecipeBrowser.Refresh() end
    if ns.ProfitBrowser and ns.ProfitBrowser.Refresh then ns.ProfitBrowser.Refresh() end
end

local pending = false
function K.Schedule()
    if pending or not C_Timer or not C_Timer.After then return end
    pending = true
    C_Timer.After(0.5, function() pending = false; K.Scan() end)
end
