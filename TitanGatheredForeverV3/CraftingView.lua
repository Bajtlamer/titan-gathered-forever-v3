local _, ns = ...
local View = {}
ns.CraftingView = View

-- The reagent window of /tgf recipe: one line per reagent with what is needed, what is in the bags and in the
-- bank, what is missing and where it can be found. Green is ready, yellow is in the bank, red is missing.
local ROWS, ROW_HEIGHT, WHEEL_STEP = 18, 22, 3
local ROW_WIDTH = 785
local columns = { { 'Reagent', 0, 215 }, { 'Need', 225, 55 }, { 'Bags', 285, 55 }, { 'Bank', 345, 55 },
    { 'Missing', 405, 65 }, { 'Where to get it', 480, 305 } }
-- Problems first: what has to be done is at the top.
local order = { missing = 1, unknown = 2, bank = 3, ready = 4 }

local function text(frame, font, x, y, width)
    local t = frame:CreateFontString(nil, 'OVERLAY', font)
    t:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, y)
    t:SetWidth(width)
    t:SetJustifyH('LEFT')
    return t
end

local function button(frame, label, x, y, width, callback)
    local b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
    b:SetSize(width, 22)
    b:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, y)
    b:SetText(label)
    b:SetScript('OnClick', callback)
    return b
end

local function color(state)
    local Style = ns.Style
    return state == 'ready' and Style.green or state == 'bank' and Style.yellow or state == 'missing' and Style.red
        or Style.gray
end

-- The rows with the missing reagents first, then unknown ones, then those that are in the bank and the ready ones.
-- Inside a group they follow the item name, or the item number while the name is still loading.
function View.Sorted(rows)
    local result = {}
    for index, row in ipairs(rows) do result[index] = row end
    local function name(row)
        local known = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(row.itemID)
        return type(known) == 'string' and ns.IsPublic(known) and known:lower() or ('~' .. string.format('%09d', row.itemID))
    end
    local keys = {}
    for _, row in ipairs(result) do keys[row] = name(row) end
    table.sort(result, function(a, b)
        if a.state ~= b.state then return order[a.state] < order[b.state] end
        if keys[a] ~= keys[b] then return keys[a] < keys[b] end
        return a.itemID < b.itemID
    end)
    return result
end

-- One line that says whether the planned crafts can be done.
function View.Headline(plan)
    local Style = ns.Style
    local operations, counts = plan.operations, plan.counts
    if plan.unknown then
        return Style.Text(Style.gray, 'Some counts are unknown: open your bags and the bank once.')
    elseif plan.craftable and plan.craftable >= operations then
        if counts.bank > 0 then
            return Style.Text(Style.yellow, string.format('Enough for %d crafts, but %d %s in the bank.',
                operations, counts.bank, counts.bank == 1 and 'reagent is' or 'reagents are'))
        end
        return Style.Text(Style.green, string.format('Ready: everything for %d crafts is in your bags.', operations))
    elseif plan.craftable and plan.craftable > 0 then
        return Style.Text(Style.yellow, string.format('You can craft %d of %d planned.', plan.craftable, operations))
    end
    return Style.Text(Style.red, 'You cannot craft this yet.')
end

function View.CountsLine(plan)
    local Style = ns.Style
    local counts = plan.counts
    return Style.Text(Style.red, 'Missing ' .. counts.missing) .. '   ' .. Style.Text(Style.yellow, 'In bank ' .. counts.bank)
        .. '   ' .. Style.Text(Style.green, 'Ready ' .. counts.ready)
        .. (counts.unknown > 0 and ('   ' .. Style.Text(Style.gray, 'Unknown ' .. counts.unknown)) or '')
end

-- The last column: what to do about this reagent.
function View.Where(row, character)
    local Style = ns.Style
    if row.state == 'ready' then return Style.Text(Style.green, 'Ready') end
    if row.state == 'bank' then
        return Style.Text(Style.yellow, string.format('In the bank: take %d', row.fromBank))
    end
    if row.state == 'unknown' then return Style.Text(Style.gray, 'Count unknown') end
    -- A merchant that was seen selling it is the clearest answer: what to pay and where.
    local vendor = ns.NpcSources and ns.NpcSources.VendorsFor(row.itemID)[1]
    if vendor then
        return string.format('Buy %s: %s%s', ns.NpcSources.UnitPriceText(vendor), vendor.name,
            vendor.zone and (', ' .. vendor.zone) or '')
    end
    local evidence = ns.Crafting.Evidence(row.itemID, character)
    local source = evidence.rates[1]
    if source then
        return string.format('%s (%d of %d samples)', ns.Reports.Source(source), source.hits, source.trials)
    elseif evidence.spots[1] then
        return 'Seen in ' .. ns.Reports.Zone(evidence.spots[1].mapID)
    end
    return Style.Text(Style.gray, 'No recorded source')
end

local function setOperations(w, value)
    value = tonumber(value)
    if not value then value = w.operations end
    w.operations = math.min(1000000, math.max(1, math.floor(value)))
    w.offset = 0
    View.Refresh()
end

function View.Refresh()
    local w = View.window
    if not w or not w:IsShown() then return end
    local plan = ns.Crafting.Plan(w.recipeID, w.operations)
    w.plan = plan
    w.TitleText:SetText('TGF v3 Recipe reagents' .. (plan.name and (': ' .. plan.name) or ''))
    if not (w.operationsBox.HasFocus and w.operationsBox:HasFocus()) then w.operationsBox:SetText(tostring(w.operations)) end
    if plan.error then
        w.sorted = {}
        w.summary:SetText(plan.error)
        w.counts:SetText('')
        w.note:SetText('Use /tgf recipe <recipeID> [operations], or select a supported profession recipe.')
        w.scope:SetText('')
    else
        w.sorted = View.Sorted(plan.rows)
        w.summary:SetText(View.Headline(plan))
        w.counts:SetText(View.CountsLine(plan))
        w.scope:SetText('Counting: ' .. plan.scope)
        local bits = {}
        if plan.craftable then
            bits[#bits + 1] = string.format('Material limit: %d crafts%s.', plan.craftable, plan.cached and ' (cached estimate)' or '')
        end
        if plan.learned == false then bits[#bits + 1] = 'Recipe not learned.' end
        if plan.bankObservedAt then
            bits[#bits + 1] = 'Bank observed ' .. (date and date('%Y-%m-%d %H:%M', plan.bankObservedAt) or tostring(plan.bankObservedAt)) .. '.'
        end
        bits[#bits + 1] = 'Bank counts: Display menu > Show bank counts. Materials only: skill, tools and cooldowns are not checked; optional reagents are excluded.'
        if #plan.issues > 0 then bits[#bits + 1] = 'Rows below are partial.' end
        w.note:SetText(table.concat(bits, ' '))
    end
    local last = math.max(0, #w.sorted - ROWS)
    w.offset = math.min(last, math.max(0, math.floor(w.offset + 0.5)))
    w.pageText:SetText(#w.sorted == 0 and 'Click a reagent for observed sources'
        or string.format('Showing %d-%d of %d reagents. Click a reagent for observed sources.', w.offset + 1,
            math.min(#w.sorted, w.offset + ROWS), #w.sorted))
    ns.Nav.SyncScrollbar(w.slider, w.offset, last)
    local character = ns.characterID or UnitGUID('player')
    for index, row in ipairs(w.rows) do
        local data = w.sorted[w.offset + index]
        row.data = data
        if data then
            local paint = color(data.state)
            row:Show()
            row.name:SetText(ns.Style.Text(paint, ns.ItemName(data.itemID)))
            row.need:SetText(tostring(data.required))
            row.bags:SetText(tostring(data.bags))
            row.bank:SetText(data.bank and tostring(data.bank) or '-')
            row.missing:SetText(data.missing > 0 and ns.Style.Text(ns.Style.red, tostring(data.missing)) or '-')
            row.where:SetText(View.Where(data, character))
        else
            row:Hide()
        end
    end
end

function View.Show(recipeID, operations)
    local w = View.window
    if not w then
        local name = 'TitanGatheredForeverV3RecipeWindow'
        w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
        View.window = w
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        w.rows = {}
        w:SetSize(845, 600)
        w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', function(self) self:StartMoving() end)
        w:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
        w.summary = text(w, 'GameFontHighlight', 15, -35, ROW_WIDTH)
        w.counts = text(w, 'GameFontHighlightSmall', 15, -56, ROW_WIDTH)
        text(w, 'GameFontNormal', 15, -86, 60):SetText('Crafts')
        button(w, '-', 75, -81, 26, function()
            setOperations(w, w.operations - (IsShiftKeyDown and IsShiftKeyDown() and 5 or 1))
        end)
        local box = CreateFrame('EditBox', nil, w, 'InputBoxTemplate')
        w.operationsBox = box
        box:SetSize(60, 22); box:SetPoint('TOPLEFT', w, 'TOPLEFT', 112, -81); box:SetAutoFocus(false)
        box:SetNumeric(true); box:SetMaxLetters(7)
        box:SetScript('OnEnterPressed', function(self) self:ClearFocus(); setOperations(w, self:GetText()) end)
        box:SetScript('OnEscapePressed', function(self) self:ClearFocus(); self:SetText(tostring(w.operations)) end)
        button(w, '+', 178, -81, 26, function()
            setOperations(w, w.operations + (IsShiftKeyDown and IsShiftKeyDown() and 5 or 1))
        end)
        w.scope = text(w, 'GameFontHighlightSmall', 225, -86, 220)
        button(w, 'Refresh', 460, -81, 90, function()
            if ns.ScheduleRefresh then ns.ScheduleRefresh() end
            View.Refresh()
        end)
        w.note = text(w, 'GameFontHighlightSmall', 15, -112, ROW_WIDTH)
        local header = CreateFrame('Frame', nil, w)
        header:SetSize(ROW_WIDTH, 20); header:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -146)
        for _, column in ipairs(columns) do text(header, 'GameFontNormalSmall', column[2], 0, column[3]):SetText(column[1]) end
        for index = 1, ROWS do
            local row = CreateFrame('Button', nil, w)
            w.rows[index] = row
            row:SetSize(ROW_WIDTH, ROW_HEIGHT)
            row:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -166 - (index - 1) * ROW_HEIGHT)
            row.name = text(row, 'GameFontNormal', columns[1][2], -4, columns[1][3])
            row.need = text(row, 'GameFontHighlightSmall', columns[2][2], -5, columns[2][3])
            row.bags = text(row, 'GameFontHighlightSmall', columns[3][2], -5, columns[3][3])
            row.bank = text(row, 'GameFontHighlightSmall', columns[4][2], -5, columns[4][3])
            row.missing = text(row, 'GameFontHighlightSmall', columns[5][2], -5, columns[5][3])
            row.where = text(row, 'GameFontHighlightSmall', columns[6][2], -5, columns[6][3])
            row.where:SetWordWrap(false)
            row:SetScript('OnClick', function(self)
                if self.data then ns.Reports.ItemSources(self, self.data.itemID, ns.characterID or UnitGUID('player')) end
            end)
            row:SetScript('OnEnter', function(self)
                if self.data then
                    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                    GameTooltip:SetItemByID(self.data.itemID)
                    GameTooltip:Show()
                end
            end)
            row:SetScript('OnLeave', function() GameTooltip:Hide() end)
        end
        local function scrollTo(offset) w.offset = offset; View.Refresh() end
        w.slider = ns.Nav.Scrollbar(w, 15 + ROW_WIDTH + 8, -166, ROWS * ROW_HEIGHT, scrollTo,
            function(delta) scrollTo(w.offset - delta * WHEEL_STEP) end)
        w:EnableMouseWheel(true)
        w:SetScript('OnMouseWheel', function(_, delta) scrollTo(w.offset - delta * WHEEL_STEP) end)
        w.pageText = text(w, 'GameFontHighlightSmall', 15, -570, ROW_WIDTH)
    end
    w.recipeID, w.operations, w.offset = recipeID, operations or 1, 0
    ns.Crafting.Select({ recipeID = recipeID })
    w:Show()
    View.Refresh()
end
