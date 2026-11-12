local _, ns = ...
local Browser = { offset = 0, total = 0, vendorOnly = false }
ns.RecipeBrowser = Browser

local ROWS, ROW_HEIGHT, WHEEL_STEP = 16, 22, 3
local columns = { { 'Recipe', 0, 250 }, { 'Profession', 260, 130 }, { 'Skill', 400, 60 }, { 'Source', 470, 80 },
    { 'Where', 560, 230 }, { 'Price', 800, 110 } }
local ROW_WIDTH = 910

function Browser.Cells(row)
    local first = row.sources[1]
    local where = ns.Style.Text(ns.Style.green, first.name) .. (#row.sources > 1 and (' (+' .. (#row.sources - 1) .. ')') or '')
    return { row.name, ns.NpcSources.Label(row.kind), row.skill and tostring(row.skill) or 'Unknown',
        row.trainer and 'Trainer' or 'Vendor', where, row.price and ns.NpcSources.Coin(row.price) or 'Unknown' }
end

-- The first visible row (zero based), kept between 0 and the last position that still fills the window.
function Browser.Clamp(offset, total)
    local last = math.max(0, total - ROWS)
    return math.max(0, math.min(math.floor(offset + 0.5), last))
end

function Browser.RangeText(offset, total)
    if total == 0 then return 'No recipes' end
    return string.format('Showing %d-%d of %d', offset + 1, math.min(total, offset + ROWS), total)
end

local function text(parent, font, x, y, width)
    local fontString = parent:CreateFontString(nil, 'OVERLAY', font)
    fontString:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    fontString:SetWidth(width)
    fontString:SetJustifyH('LEFT')
    return fontString
end
local function button(parent, label, x, y, width, callback)
    local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    b:SetSize(width, 22)
    b:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    b:SetText(label)
    b:SetScript('OnClick', callback)
    return b
end

function Browser.ScrollTo(offset)
    Browser.offset = Browser.Clamp(offset, Browser.total)
    Browser.Refresh()
end
function Browser.Scroll(delta) Browser.ScrollTo(Browser.offset + delta) end

-- Choosing a profession (nil for all) returns to the top of the list.
function Browser.SetKind(kind)
    Browser.kind, Browser.offset = kind, 0
    Browser.Refresh()
end

local function openMap(line)
    local source = line.row and line.row.sources[1]
    local mapID = source and ns.NpcSources.ContinentMap(source.npcID)
    if mapID and OpenWorldMap then OpenWorldMap(mapID) end
end

function Browser.Refresh()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    local rows, unread, pending = ns.NpcSources.Unlearned(ns.characterID, Browser.vendorOnly, Browser.kind)
    Browser.total = #rows
    Browser.offset = Browser.Clamp(Browser.offset, Browser.total)
    w.filter:SetText(Browser.vendorOnly and 'Vendor only' or 'All unlearned')
    w.kindButton:SetText(Browser.kind and ns.NpcSources.Label(Browser.kind) or 'All professions')
    w.rangeText:SetText(Browser.RangeText(Browser.offset, Browser.total))
    for index = 1, ROWS do
        local line = w.lines[index]
        local row = rows[Browser.offset + index]
        line.row = row
        if row then
            local cells = Browser.Cells(row)
            for i, value in ipairs(cells) do line.cells[i]:SetText(value) end
            line:Show()
        else line:Hide() end
    end
    -- The scroll bar mirrors the offset without feeding it back.
    local last = math.max(0, Browser.total - ROWS)
    Browser.syncing = true
    w.slider:SetMinMaxValues(0, last)
    w.slider:SetValue(Browser.offset)
    Browser.syncing = false
    if last > 0 then w.slider:Show() else w.slider:Hide() end
    local notes = {}
    if #unread > 0 then
        local names = {}
        for _, kind in ipairs(unread) do names[#names + 1] = ns.NpcSources.Label(kind) end
        notes[#notes + 1] = 'Recipes not yet read for this character: ' .. table.concat(names, ', ')
            .. '. Open each profession window once.'
    end
    if pending > 0 then notes[#notes + 1] = pending .. ' vendor recipes are still loading.' end
    w.footer:SetText(table.concat(notes, ' '))
end

function Browser.Show()
    local w = Browser.window
    if not w then
        local name = 'TitanGatheredForeverV3RecipeBrowserWindow'
        w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
        Browser.window = w
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        w:SetSize(960, 560)
        w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', function(self) self:StartMoving() end)
        w:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
        w:SetScript('OnHide', function() GameTooltip:Hide() end)
        w.TitleText:SetText('TGF v3 Unlearned recipes')
        local note = text(w, 'GameFontHighlightSmall', 15, -33, 930)
        note:SetText('Unlearned recipes with a known trainer or vendor source. Seed data is Classic and not confirmed in game until you visit the NPC. Scroll with the mouse wheel; hover an NPC name to see where to find them; click a row to open the map.')
        w.filter = button(w, 'All unlearned', 15, -65, 150, function()
            Browser.vendorOnly = not Browser.vendorOnly; Browser.offset = 0; Browser.Refresh()
        end)
        w.kindButton = button(w, 'All professions', 175, -65, 190, function(owner)
            MenuUtil.CreateContextMenu(owner, function(_, root)
                root:CreateButton('All professions', function() Browser.SetKind(nil) end)
                for _, kind in ipairs(ns.NpcSources.RecipeKinds) do
                    local id = kind
                    root:CreateButton(ns.NpcSources.Label(id), function() Browser.SetKind(id) end)
                end
            end)
        end)
        w.rangeText = text(w, 'GameFontHighlightSmall', 380, -70, 300)
        local header = CreateFrame('Frame', nil, w)
        header:SetSize(ROW_WIDTH, 30); header:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -100)
        for _, column in ipairs(columns) do text(header, 'GameFontNormalSmall', column[2], 0, column[3]):SetText(column[1]) end
        w.lines = {}
        for index = 1, ROWS do
            local line = CreateFrame('Button', nil, w)
            line:SetSize(ROW_WIDTH, ROW_HEIGHT)
            line:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -132 - (index - 1) * ROW_HEIGHT)
            line.cells = {}
            for i, column in ipairs(columns) do line.cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3]) end
            line:SetScript('OnClick', openMap)
            -- The NPC column shows where to find the vendor or trainer.
            local hit = CreateFrame('Button', nil, line)
            hit:SetSize(columns[5][3], ROW_HEIGHT)
            hit:SetPoint('TOPLEFT', line, 'TOPLEFT', columns[5][2], 0)
            hit:SetScript('OnEnter', function(self)
                if not line.row then return end
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                ns.NpcSources.FillSourcesTooltip(GameTooltip, line.row)
                GameTooltip:Show()
            end)
            hit:SetScript('OnLeave', function() GameTooltip:Hide() end)
            hit:SetScript('OnClick', function() openMap(line) end)
            w.lines[index] = line
        end
        -- Classic scrolling: the mouse wheel anywhere over the window, and a scroll bar on the right.
        w:EnableMouseWheel(true)
        w:SetScript('OnMouseWheel', function(_, delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        local slider = CreateFrame('Slider', nil, w)
        w.slider = slider
        slider:SetOrientation('VERTICAL')
        slider:SetPoint('TOPLEFT', w, 'TOPLEFT', 15 + ROW_WIDTH + 6, -132)
        slider:SetSize(16, ROWS * ROW_HEIGHT)
        slider:SetMinMaxValues(0, 0); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
        local track = slider:CreateTexture(nil, 'BACKGROUND')
        track:SetAllPoints(slider); track:SetColorTexture(0, 0, 0, 0.35)
        slider:SetThumbTexture('Interface\\Buttons\\UI-ScrollBar-Knob')
        slider:GetThumbTexture():SetSize(16, 24)
        slider:EnableMouseWheel(true)
        slider:SetScript('OnMouseWheel', function(_, delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        slider:SetScript('OnValueChanged', function(_, value)
            if not Browser.syncing then Browser.ScrollTo(value) end
        end)
        w.footer = text(w, 'GameFontHighlightSmall', 15, -520, 930)
    end
    w:Show()
    Browser.Refresh()
end
