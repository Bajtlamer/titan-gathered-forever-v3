local _, ns = ...
-- The scans that only a /tgfd command starts. They read what the game already lists (the recipes of the open profession
-- window, the map IDs of the client) as operations for the runner, so they show their progress and can be cancelled.
-- Nothing here opens a window or sends a request to the server.
local Scans = {}
ns.Scans = Scans

Scans.DEFAULT_MAPS, Scans.MAX_MAPS = 4000, 20000

-- The recipe scan of the open profession window, or nil and 'nowindow' when the client lists no recipes.
function Scans.RecipeSpec()
    local ids = ns.api.RecipeIDs()
    if not ids then return nil, 'nowindow' end
    local recorded, skipped, professions = 0, 0, {}
    return {
        name = 'Recipe scan',
        phases = { {
            label = 'Reading recipes',
            total = function() return #ids end,
            step = function(index)
                local id = ids[index]
                local info = ns.api.Recipe(id)
                if not info then skipped = skipped + 1; return end
                local record = ns.Records.Touch(ns.db.data.recipes, id, ns.Records.Context())
                record.name, record.profession = info.name, info.profession
                record.professionID, record.parentProfessionID = info.professionID, info.parentProfessionID
                record.outputItemID, record.quantityMin, record.quantityMax = info.outputItemID, info.quantityMin, info.quantityMax
                record.reagents = info.reagents
                recorded = recorded + 1
                professions[info.profession or 'unknown'] = true
            end,
        } },
        onFinish = function()
            local names = {}
            for name in pairs(professions) do names[#names + 1] = name end
            table.sort(names)
            local Text = ns.Text
            ns.Print(Text.Label('Recorded ') .. Text.Value(recorded) .. Text.Label(' recipes (') .. Text.Value(skipped)
                .. Text.Label(' skipped) from: ') .. Text.Value(#names > 0 and table.concat(names, ', ') or 'nothing') .. Text.Label('.'))
            if ns.Stats then ns.Stats.Dirty() end
        end,
    }
end

-- The map scan: every map ID from 1 to the limit that the client knows, with name, type and parent.
function Scans.AreaSpec(limit)
    local count = tonumber(limit) or Scans.DEFAULT_MAPS
    count = math.max(1, math.min(math.floor(count), Scans.MAX_MAPS))
    local recorded, new = 0, 0
    return {
        name = 'Map scan',
        phases = { {
            label = 'Reading map IDs',
            total = function() return count end,
            step = function(id)
                local info = ns.api.Map(id)
                if not info then return end
                local record, isNew = ns.Records.Touch(ns.db.data.maps, id, ns.Records.Context())
                record.name, record.mapType, record.parentMapID = info.name, info.mapType, info.parentMapID
                recorded = recorded + 1
                if isNew then new = new + 1 end
            end,
        } },
        onFinish = function()
            local Text = ns.Text
            ns.Print(Text.Label('Recorded ') .. Text.Value(recorded) .. Text.Label(' maps (') .. Text.Value(new) .. Text.Label(' new).'))
            if ns.Stats then ns.Stats.Dirty() end
        end,
    }
end
