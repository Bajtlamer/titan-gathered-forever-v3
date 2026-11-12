local _, ns = ...
local Browser = { page = 1, vendorOnly = false }
ns.RecipeBrowser = Browser

local ROWS = 16
local columns = { { 'Recipe', 0, 250 }, { 'Profession', 260, 130 }, { 'Skill', 400, 60 }, { 'Source', 470, 80 },
    { 'Where', 560, 230 }, { 'Price', 800, 130 } }

function Browser.Cells(row)
    local first = row.sources[1]
    local where = first.name .. (#row.sources > 1 and (' (+' .. (#row.sources - 1) .. ')') or '')
    return { row.name, ns.NpcSources.Label(row.kind), row.skill and tostring(row.skill) or 'Unknown',
        row.trainer and 'Trainer' or 'Vendor', where, row.price and ns.NpcSources.Coin(row.price) or 'Unknown' }
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

function Browser.Refresh()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    local rows, unread, pending = ns.NpcSources.Unlearned(ns.characterID, Browser.vendorOnly)
    local pages = math.max(1, math.ceil(#rows / ROWS))
    Browser.page = math.max(1, math.min(Browser.page, pages))
    w.filter:SetText(Browser.vendorOnly and 'Vendor only' or 'All unlearned')
    w.pageText:SetText(string.format('Page %d / %d, %d recipes', Browser.page, pages, #rows))
    for index = 1, ROWS do
        local line = w.lines[index]
        local row = rows[(Browser.page - 1) * ROWS + index]
        line.row = row
        if row then
            local cells = Browser.Cells(row)
            for i, value in ipairs(cells) do line.cells[i]:SetText(value) end
            line:Show()
        else line:Hide() end
    end
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
        note:SetText('Unlearned recipes with a known trainer or vendor source. Seed data is Classic and not confirmed in game until you visit the NPC. Click a row to open its map.')
        w.filter = button(w, 'All unlearned', 15, -65, 150, function()
            Browser.vendorOnly = not Browser.vendorOnly; Browser.page = 1; Browser.Refresh()
        end)
        button(w, 'Previous', 175, -65, 90, function() Browser.page = Browser.page - 1; Browser.Refresh() end)
        button(w, 'Next', 275, -65, 90, function() Browser.page = Browser.page + 1; Browser.Refresh() end)
        w.pageText = text(w, 'GameFontHighlightSmall', 380, -70, 300)
        local header = CreateFrame('Frame', nil, w)
        header:SetSize(930, 30); header:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -100)
        for _, column in ipairs(columns) do text(header, 'GameFontNormalSmall', column[2], 0, column[3]):SetText(column[1]) end
        w.lines = {}
        for index = 1, ROWS do
            local line = CreateFrame('Button', nil, w)
            line:SetSize(930, 22)
            line:SetPoint('TOPLEFT', w, 'TOPLEFT', 15, -132 - (index - 1) * 22)
            line.cells = {}
            for i, column in ipairs(columns) do line.cells[i] = text(line, 'GameFontHighlightSmall', column[2], 0, column[3]) end
            line:SetScript('OnClick', function(self)
                local source = self.row and self.row.sources[1]
                local mapID = source and ns.NpcSources.ContinentMap(source.npcID)
                if mapID and OpenWorldMap then OpenWorldMap(mapID) end
            end)
            w.lines[index] = line
        end
        w.footer = text(w, 'GameFontHighlightSmall', 15, -520, 930)
    end
    w:Show()
    Browser.Refresh()
end
