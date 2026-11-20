local _, ns = ...
-- The baseline of the comparison: what the Titan Gathered Forever core and its installed modules already know. It is
-- read through the exported namespace of the core and holds only what the core keeps in memory, never the full recipe
-- records. Anything the baseline cannot answer is reported as "no baseline", not as new.
local Baseline = {}
ns.Baseline = Baseline

Baseline.PROFESSIONS = { 'Alchemy', 'Blacksmithing', 'Enchanting', 'Engineering', 'Herbalism', 'Leatherworking',
    'Mining', 'Skinning', 'Tailoring', 'Cooking', 'Fishing', 'First Aid' }

-- The baseline, or nil and the reason.
function Baseline.FromCore()
    local core = _G.TitanGatheredForeverV3
    if type(core) ~= 'table' or type(core.Catalog) ~= 'table' or type(core.Catalog.Get) ~= 'function' then
        return nil, 'The Titan Gathered Forever core is not loaded, so there is nothing to compare with.'
    end
    local seed = type(core.NpcSeed) == 'table' and core.NpcSeed.npcs or {}
    local professions = {}
    for _, name in ipairs(Baseline.PROFESSIONS) do professions[name] = true end
    local modules = {}
    for _, module in ipairs(type(core.Catalog.Modules) == 'function' and core.Catalog.Modules() or {}) do
        modules[#modules + 1] = type(module) == 'table' and module.id or tostring(module)
    end
    return {
        item = function(id) return core.Catalog.Get(id) ~= nil end,
        items = function() return core.Items or {} end,
        npc = function(id) return seed[id] end,
        npcs = function() return seed end,
        professions = professions,
        build = type(core.DataMetadata) == 'table' and core.DataMetadata.targetBuild or nil,
        version = ns.env.coreVersion and ns.env.coreVersion() or nil,
        modules = modules,
    }
end
