local _, ns = ...
-- The retired WoW Forever Scout and this module never run together: both would record the same events.
local Scout = {}
ns.Scout = Scout

Scout.FOLDERS = { 'WoWForeverScout', 'wowfscout' }

-- The Scout folders that are loaded, given a function that tells whether an addon is loaded.
function Scout.Found(isLoaded)
    local found = {}
    for _, name in ipairs(Scout.FOLDERS) do
        local ok, loaded = pcall(isLoaded, name)
        if ok and loaded then found[#found + 1] = name end
    end
    return found
end
