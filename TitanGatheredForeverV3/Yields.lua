local _, ns = ...
local Yields = {}
ns.Yields = Yields

-- What the gathering professions brought in: the most collected items of each one, their value at the best sale
-- (auction after the fee or vendor), the total, and a value per hour of active gathering time. Prices that are not
-- known stay unknown and are counted as such.
Yields.kinds = { 'Mining', 'Herbs', 'Skinning', 'Fishing', 'Enchanting' }
Yields.LIMIT = 40
Yields.MIN_ACTIVE = 300     -- seconds of measured time before a rate per hour is shown

function Yields.Duration(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if hours > 0 then return hours .. ' h ' .. minutes .. ' min' end
    if minutes > 0 then return minutes .. ' min' end
    return seconds .. ' s'
end

local function coin(copper) return ns.Economy.Coin(copper) end

local function hidden(kind) return ns.Catalog and ns.Catalog.Hidden and ns.Catalog.Hidden(kind) end

local function worth(itemID)
    local sale = ns.Economy.Sale(itemID)
    return sale and sale.unit, sale and sale.source
end

-- The value of a set of items { [itemID] = quantity }: { value, unpriced } where unpriced counts items without a price.
function Yields.Worth(items)
    local value, unpriced = 0, 0
    for itemID, quantity in pairs(items or {}) do
        local unit = worth(itemID)
        if unit then value = value + unit * quantity else unpriced = unpriced + 1 end
    end
    return value, unpriced
end

-- Rows for the window: for every visible gathering profession two summary lines and its most collected items.
-- sort is 'quantity' or 'value'. A row is { summary = true, text } or { itemID, quantity, share, unit, source, value }.
function Yields.Rows(character, filter, sort)
    local rows = {}
    if not ns.history then return rows end
    local rates = ns.history:Rates(character)
    local actionRows = {}
    if ns.actions then for _, row in ipairs(ns.actions:Rows(character)) do actionRows[row.kind] = row end end
    for _, kind in ipairs(Yields.kinds) do
        if not hidden(kind) and (not filter or filter == kind) then
            local totals, quantity = {}, 0
            for _, rate in ipairs(rates) do
                if rate.kind == kind and (rate.quantity or 0) > 0 then
                    totals[rate.itemID] = (totals[rate.itemID] or 0) + rate.quantity
                    quantity = quantity + rate.quantity
                end
            end
            local list, value, unpriced = {}, 0, 0
            for itemID, count in pairs(totals) do
                local unit, source = worth(itemID)
                local total = unit and unit * count or nil
                if total then value = value + total else unpriced = unpriced + 1 end
                list[#list + 1] = { itemID = itemID, kind = kind, quantity = count, share = quantity > 0 and count / quantity * 100 or 0,
                    unit = unit, source = source, value = total }
            end
            table.sort(list, function(a, b)
                if sort == 'value' then
                    if (a.value or -1) ~= (b.value or -1) then return (a.value or -1) > (b.value or -1) end
                end
                if a.quantity ~= b.quantity then return a.quantity > b.quantity end
                return a.itemID < b.itemID
            end)
            local action = actionRows[kind] or {}
            local label = ns.Actions and ns.Actions.labels[kind] or kind
            local first = string.format('%s: %d completed, %d items collected, worth %s%s', label, action.completed or 0, quantity, coin(value),
                unpriced > 0 and string.format(' (%d items without a price)', unpriced) or '')
            local second
            local active = action.active or 0
            if not action.timedBegan then
                second = 'Time is measured from this version on. Keep gathering to see a value per hour.'
            else
                local timedValue, timedUnpriced = Yields.Worth(action.timedItems)
                local timedQuantity = 0
                for _, count in pairs(action.timedItems or {}) do timedQuantity = timedQuantity + count end
                second = 'Active time ' .. Yields.Duration(active)
                if active >= Yields.MIN_ACTIVE then
                    second = second .. string.format(', about %s and %d items per hour%s', coin(timedValue / active * 3600),
                        math.floor(timedQuantity / active * 3600 + 0.5), timedUnpriced > 0 and ' (some items have no price)' or '')
                else second = second .. ', too little time measured for a rate per hour' end
                if date then second = second .. ', measured since ' .. date('%Y-%m-%d', action.timedBegan) end
            end
            if #list > 0 or (action.attempts or 0) > 0 then
                if #rows > 0 then rows[#rows + 1] = { summary = true, spacer = true, kind = kind, text = '' } end
                rows[#rows + 1] = { summary = true, title = true, kind = kind, text = label, gold = true }
                rows[#rows + 1] = { summary = true, kind = kind, text = first }
                rows[#rows + 1] = { summary = true, kind = kind, text = second }
                for index = 1, math.min(#list, Yields.LIMIT) do rows[#rows + 1] = list[index] end
                if #list > Yields.LIMIT then
                    rows[#rows + 1] = { summary = true, kind = kind, text = string.format('%d more items not shown.', #list - Yields.LIMIT) }
                end
            end
        end
    end
    return rows
end
