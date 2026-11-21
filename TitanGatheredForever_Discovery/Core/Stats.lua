local _, ns = ...
-- The Titan Panel plugin: read-only statistics of what has been found. It has no actions besides opening the overview
-- window; every operation stays a /tgfd command. The text is recomputed after a comparison, when collection changes
-- state and, at a low rate, after new records.
local Stats = {}
ns.Stats = Stats

local REFRESH_SECONDS = 10
local scheduled = false

local STATE_WORD = { unaccepted = 'off', ['blocked-schema'] = 'blocked', paused = 'paused' }

function Stats.Text(db, runtime)
    local state = ns.Consent.State(db, runtime)
    if STATE_WORD[state] then return STATE_WORD[state] end
    local saved = db.compare
    if type(saved) == 'table' and type(saved.totals) == 'table' then
        return string.format('%d new, %d different', saved.totals.new or 0, saved.totals.different or 0)
    end
    return string.format('%d records', ns.Database.Count(db))
end

function Stats.TooltipLines(db, runtime)
    local Text = ns.Text
    local saved = type(db.compare) == 'table' and db.compare or nil
    local lines = {
        { left = Text.Value('Titan Gathered Forever: Discovery') },
        { left = Text.Label('State'), right = Text.Value(Stats.Text(db, runtime)) },
    }
    for _, category in ipairs(ns.Database.CATEGORIES) do
        local right = string.format('%d observed', ns.Database.CategoryCount(db, category))
        local counts = saved and saved.counts and saved.counts[category]
        if counts then right = right .. string.format(', %d new, %d different', counts.new or 0, counts.different or 0) end
        lines[#lines + 1] = { left = Text.Label(ns.Compare.LABELS[category]), right = Text.Value(right) }
    end
    if saved and saved.ranAt then
        lines[#lines + 1] = { left = Text.Label('Last comparison ') .. Text.Date(ns.env.date('%Y-%m-%d %H:%M', saved.ranAt))
            .. Text.Label(' against ') .. Text.Value(saved.baselineVersion or 'unknown') }
        lines[#lines + 1] = { left = Text.Label('New and different come from that comparison. Areas, maps, quests and entities have no baseline in the game.') }
    end
    lines[#lines + 1] = { left = Text.Label('Left click opens the window. /tgfd compare refreshes the counts.') }
    return lines
end

function Stats.Refresh()
    if Stats.broker then Stats.broker.text = Stats.Text(ns.db, ns.runtime) end
end

function Stats.Dirty()
    if scheduled then return end
    scheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(REFRESH_SECONDS, function() scheduled = false; Stats.Refresh() end)
    else
        scheduled = false
        Stats.Refresh()
    end
end

local function showTooltip(owner)
    GameTooltip:SetOwner(owner, 'ANCHOR_BOTTOM')
    for _, line in ipairs(Stats.TooltipLines(ns.db, ns.runtime)) do
        if line.right then GameTooltip:AddDoubleLine(line.left, line.right) else GameTooltip:AddLine(line.left, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end

-- Registers the data source that Titan Panel shows as a plugin. false when LibDataBroker is not there.
function Stats.Initialize()
    local ldb = LibStub and LibStub.GetLibrary and LibStub:GetLibrary('LibDataBroker-1.1', true)
    if not ldb then return false end
    Stats.broker = ldb:NewDataObject('TitanGatheredForeverDiscovery', {
        type = 'data source', label = 'Titan Gathered Forever: Discovery', text = Stats.Text(ns.db, ns.runtime),
        icon = 'Interface\\AddOns\\TitanGatheredForever_Discovery\\Artwork\\AddonIcon',
        OnEnter = showTooltip,
        OnLeave = function() GameTooltip:Hide() end,
        OnClick = function(_, button)
            if button == 'LeftButton' then ns.Window.Toggle() end
        end,
    })
    return true
end
