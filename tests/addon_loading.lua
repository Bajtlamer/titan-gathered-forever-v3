local ns = {}
assert(loadfile('TitanGatheredForeverV3/Data/Metadata.lua'))('TitanGatheredForeverV3', ns)
assert(loadfile('TitanGatheredForeverV3/Catalog.lua'))('TitanGatheredForeverV3', ns)
TitanGatheredForeverV3 = ns
ns.settings = { categories = {} }
ns.Catalog.Rebuild(ns.settings)
assert(next(ns.Items) == nil and next(ns.Recipes) == nil, 'Core loaded a profession database')
assert(#ns.Catalog.Modules() == 0, 'Core invented loaded profession modules')

local function loadAddon(folder)
    local manifest = assert(io.open(folder .. '/' .. folder .. '.toc', 'r'))
    local text = manifest:read('*a'); manifest:close()
    assert(text:find('## Dependencies: Titan, TitanGatheredForeverV3', 1, true))
    for file in text:gmatch('[^\r\n]+') do
        if file:match('%.lua$') then assert(loadfile(folder .. '/' .. file))(folder, {}) end
    end
end

loadAddon('TitanGatheredForeverV3_Mining')
assert(ns.Catalog.Get(2770), 'Mining omitted Copper Ore')
assert(ns.Catalog.Get(249391), 'Mining omitted Forever Pyrite')
assert(not ns.Catalog.Get(765), 'Disabled Herbalism/Alchemy data was loaded')
assert(not ns.Catalog.Get(2589), 'Mining incorrectly inherited Linen Cloth from the old gem table')
assert(#ns.Catalog.Modules() == 1)
assert(#ns.Catalog.List() < ns.DataMetadata.itemCount)
assert(ns.Catalog.List() == ns.Catalog.List(), 'Item list is rebuilt on each lookup')

loadAddon('TitanGatheredForeverV3_Herbs')
assert(ns.Catalog.Get(765), 'Herbalism did not register Silverleaf')
assert(ns.Catalog.Get(249399), 'Herbalism omitted Frilled Lichen')
assert(not ns.Catalog.Get(264019), 'Auction data loaded without Auction addon')

loadAddon('TitanGatheredForeverV3_Fishing')
assert(not ns.Catalog.modules.Alchemy and not ns.Catalog.modules.Cooking, 'Fishing pulled in consuming profession addons')
for _, id in ipairs({6358,6359,6522,13422,13755,13888,13893}) do
    assert(ns.Catalog.Get(id), 'Fishing omitted evidenced material ' .. id)
end
assert(ns.Catalog.Get(6358).recipeCounts.Alchemy > 0, 'Fishing lost Alchemy use context')

for _, folder in ipairs({ 'Alchemy', 'Auction', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering',
                          'FirstAid', 'Leatherworking', 'Skinning', 'Tailoring' }) do
    loadAddon('TitanGatheredForeverV3_' .. folder)
end
assert(#ns.Catalog.Modules() == 13)
assert(#ns.Catalog.List() == ns.DataMetadata.itemCount, 'Loaded modules do not cover the generated catalogue')
local originalCounts = ns.Catalog.Get(2589).recipeCounts.Tailoring
assert(originalCounts > 0)
ns.settings.categories.FirstAid = false
ns.Catalog.Rebuild(ns.settings)
assert(ns.Catalog.Get(2589).recipeCounts.Tailoring == originalCounts, 'Shared usage counts were inflated')
ns.settings.categories = {}
for _, module in ipairs(ns.Catalog.Modules()) do ns.settings.categories[module.id] = false end
ns.Catalog.Rebuild(ns.settings)
assert(next(ns.Items) == nil and next(ns.Recipes) == nil)
print('PASS 7 optional-addon loading scenarios (core only, subset, gathering, fishing, auction isolation, union, disabled index)')
