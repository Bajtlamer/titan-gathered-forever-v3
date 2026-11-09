local _, ns = ...
local Tooltips = {}
ns.Tooltips = Tooltips

function Tooltips.Count(value)
    return tostring(value or 0)
end

function Tooltips.DisplayCounts(count)
    local bags, bank = count.bags or 0, count.bank or 0
    return { bags = bags, bank = bank, total = bags + bank }
end

function Tooltips.BankObservation(count)
    if not ns.settings.showBank then return nil end
    if count.bankState == 'cached' and count.bankObservedAt then
        return string.format(ns.L.bankObserved, date('%Y-%m-%d %H:%M', count.bankObservedAt))
    end
end

function Tooltips.ShowCount(value)
    return ns.settings.showZero or (type(value)=='number' and value~=0)
end

function Tooltips.CountValues(count)
    count = Tooltips.DisplayCounts(count)
    if ns.settings.showBank then
        local values = {}
        if Tooltips.ShowCount(count.bags) then values[#values + 1] = ns.Style.Count(count.bags, 'bags') end
        if Tooltips.ShowCount(count.bank) then values[#values + 1] = ns.Style.Count(count.bank, 'bank') end
        return table.concat(values, '/')
    end
    return Tooltips.ShowCount(count.bags) and ns.Style.Count(count.bags, 'bags') or ''
end

function Tooltips.Lines(itemID)
    local record = ns.Catalog.Get(itemID)
    if not ns.inventory then return {} end
    local character=(ns.characterID or UnitGUID('player'))
    local crafted=ns.production and ns.production:Total(character,itemID)or 0
    local reagent,plan
    if ns.Crafting then reagent,plan=ns.Crafting.Context(itemID)end
    if not record and (not ns.history or ns.history:Total(character, itemID) == 0)and crafted==0 and not reagent then return {} end
    record = record or { professions = {}, recipes = {}, recipeCounts = {}, uses = {} }
    local lines, notes = {}, {}
    local function note(value)
        lines[#lines + 1] = value
        notes[#lines] = true
    end
    for _, profession in ipairs(record.professions) do
        local count = record.recipeCounts[profession] or 0
        lines[#lines + 1] = ns.Style.Text(ns.Style.gold, 'Reagent for ')
            .. ns.Style.Text(ns.Style.cyan, profession)
            .. ns.Style.Text(ns.Style.gray, string.format(' (%d recipes).', count))
    end
    for _, use in ipairs(record.uses) do note(ns.Style.Text(ns.Style.note, use.reason)) end
    -- A small sample gives a concrete use without overwhelming the native item tooltip.
    for index = 1, math.min(2, #record.recipes) do
        local info = C_Spell.GetSpellInfo(record.recipes[index])
        if info and ns.IsPublic(info.name) and type(info.name) == 'string' then
            lines[#lines + 1] = ns.Style.Text(ns.Style.gold, 'Recipe: ') .. ns.Style.Text(ns.Style.violet, info.name)
        end
    end
    local observed = ns.inventory:Get(itemID)
    local counts = Tooltips.DisplayCounts(observed)
    if #lines > 0 then lines[#lines + 1] = false end -- Render a rule before inventory counts.
    if Tooltips.ShowCount(counts.bags) then
        lines[#lines + 1] = ns.Style.Text(ns.Style.gold, 'Bags: ') .. ns.Style.Count(counts.bags, 'bags')
    end
    if ns.settings.showBank then
        if Tooltips.ShowCount(counts.bank) then
            lines[#lines + 1] = ns.Style.Text(ns.Style.gold, 'Bank: ') .. ns.Style.Count(counts.bank, 'bank')
        end
        if counts.bags>0 and counts.bank>0 then
            lines[#lines + 1] = ns.Style.Text(ns.Style.gold, 'Total: ') .. ns.Style.Count(counts.total, 'total')
        end
    end
    if observed.bagsState == 'cached' then
        note(ns.Style.Text(ns.Style.gray, 'Bag refresh incomplete; showing last observed counts.'))
    end
    local observation = Tooltips.BankObservation(observed)
    if observation then note(ns.Style.Text(ns.Style.gray, observation)) end
    if reagent then
        lines[#lines+1]=false
        lines[#lines+1]=ns.Style.Text(ns.Style.violet,string.format('For %s: %d per operation; missing %d (%s)',
            plan.name,reagent.perOperation,reagent.missing,plan.scope))
        note(ns.Style.Text(ns.Style.gray,plan.craftable and string.format('Material limit: %d operations%s. /tgf recipe',
            plan.craftable,plan.cached and' (cached estimate)'or'')or'Material limit unavailable; inventory or recipe requirements unresolved. /tgf recipe'))
    end
    if ns.settings.historyTooltips and ns.history then
        if crafted>0 then
            lines[#lines+1]=false
            lines[#lines+1]=ns.Style.Text(ns.Style.gold,'Lifetime crafted: ')..ns.Style.Text(ns.Style.cyan,tostring(crafted))
        end
        local character = (ns.characterID or UnitGUID('player'))
        local quantity = ns.history:Total(character, itemID)
        local sources = ns.history:Rates(character, itemID)
        if quantity > 0 then
            lines[#lines + 1] = false
            lines[#lines + 1] = ns.Style.Text(ns.Style.gold, 'Lifetime obtained: ') .. ns.Style.Text(ns.Style.cyan, tostring(quantity))
            for index = 1, math.min(3, #sources) do
                local row = sources[index]
                lines[#lines + 1] = ns.Style.Text(ns.Style.note, string.format('%s: %.1f%% (%d / %d samples)',
                    ns.Reports.Source(row), row.percent, row.hits, row.trials))
            end
            note(ns.Style.Text(ns.Style.gray, 'Observed complete loot samples, not guaranteed drop rates. /tgf history'))
        end
        if #sources == 0 and ns.gathering then
            local found = 0
            for mapID, nodes in pairs(ns.gathering.saved.maps) do
                if type(nodes) == 'table' then for _, node in ipairs(nodes) do
                    if node.itemID == itemID and found < 3 then
                        if found == 0 then lines[#lines + 1] = false end
                        found = found + 1
                        lines[#lines + 1] = ns.Style.Text(ns.Style.note, string.format('Recorded near %s: %.1f, %.1f',
                            ns.Reports.Zone(mapID), node.x * 100, node.y * 100))
                    end
                end end
            end
        end
    end
    return lines, notes
end

function Tooltips.Append(tooltip, data)
    if not ns.settings or not ns.settings.itemTooltips or not ns.inventory
        or not data or not ns.IsPublic(data.id) or type(data.id) ~= 'number'
        or (not ns.Catalog.Get(data.id) and (not ns.history or ns.history:Total((ns.characterID or UnitGUID('player')), data.id) == 0)
            and (not ns.production or ns.production:Total((ns.characterID or UnitGUID('player')),data.id)==0)
            and (not ns.Crafting or not ns.Crafting.Context(data.id))) then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    if not tooltip.tgForeverHooked then
        tooltip:HookScript('OnTooltipCleared', function(self) self.tgForeverItemID = nil end)
        tooltip.tgForeverHooked = true
    end
    if tooltip.tgForeverItemID == data.id then return end
    tooltip.tgForeverItemID = data.id
    ns.Style.Separator(tooltip)
    local lines, notes = Tooltips.Lines(data.id)
    for index, line in ipairs(lines) do
        if line == false then ns.Style.Separator(tooltip)
        elseif notes[index] then ns.Style.Note(tooltip, line)
        else tooltip:AddLine(line, 1, 1, 1, true) end
    end
end

function Tooltips.Initialize()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Tooltips.Append)
end
