local _, ns = ...
-- Warns once at login when the folders of the versions before 0.5.84 (TitanGatheredForeverV3 and its modules) are still
-- loaded next to this one. Both would share the saved table TitanGatheredForeverV3DB and the exported namespace, and the
-- old version keeps its saved data in a file with the old name, which this version does not read.
local Legacy = {}
ns.Legacy = Legacy

Legacy.FOLDERS = { 'TitanGatheredForeverV3', 'TitanGatheredForeverV3_Alchemy', 'TitanGatheredForeverV3_Auction',
    'TitanGatheredForeverV3_Blacksmithing', 'TitanGatheredForeverV3_Cooking', 'TitanGatheredForeverV3_Enchanting',
    'TitanGatheredForeverV3_Engineering', 'TitanGatheredForeverV3_FirstAid', 'TitanGatheredForeverV3_Fishing',
    'TitanGatheredForeverV3_Herbs', 'TitanGatheredForeverV3_Leatherworking', 'TitanGatheredForeverV3_Mining',
    'TitanGatheredForeverV3_Skinning', 'TitanGatheredForeverV3_Tailoring' }

-- The old folders that are loaded, given a function that tells whether an addon is loaded.
function Legacy.Found(isLoaded)
    local found = {}
    for _, name in ipairs(Legacy.FOLDERS) do
        local ok, loaded = pcall(isLoaded, name)
        if ok and loaded then found[#found + 1] = name end
    end
    return found
end

function Legacy.Messages(found)
    if #found == 0 then return nil end
    local Style = ns.Style
    return Style.Label('Old Titan Gathered Forever folders are still loaded: ') .. Style.Value(table.concat(found, ', ')) .. Style.Label('.'),
        Style.Label('Close the game, delete them from Interface/AddOns and enable the new folders. To keep the old statistics, copy WTF/Account/<account>/SavedVariables/TitanGatheredForeverV3.lua to TitanGatheredForever.lua (also the character folders if you have saved files there). Running both versions together may overwrite saved data.')
end

function Legacy.Check()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not isLoaded then return end
    local first, second = Legacy.Messages(Legacy.Found(isLoaded))
    if first then ns.Print(first); ns.Print(second) end
end
