local _, ns = ...
-- The profit list: every recipe of the recipe book with what its materials cost, what the product sells for and
-- the profit of one craft, best first. A click opens the reagent window of the recipe.
local Browser = { offset = 0, total = 0 }
ns.ProfitBrowser = Browser

local ROWS, ROW_HEIGHT, WHEEL_STEP = 16, 22, 3
local columns = { { 'Recipe', 0, 230 }, { 'Profession', 240, 105 }, { 'Materials', 355, 90 }, { 'Auction after fee', 455, 105 },
    { 'Vendor pays', 570, 95 }, { 'Sells better to', 675, 90 }, { 'Profit per craft', 775, 130 } }
local ROW_WIDTH = 910
local scopes = { { value = true, label = 'My recipes' }, { value = false, label = 'All recipes' } }
local kinds = { 'Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'FirstAid', 'Leatherworking',
    'Mining', 'Tailoring' }

local function coin(copper) return ns.Economy.Coin(copper) end

function Browser.Cells(row)
    local Style = ns.Style
    local product = row.product
    local paint = row.profit == nil and Style.gray or (row.profit >= 0 and Style.green or Style.red)
    local unknown = Style.Text(Style.gray, '-')
    local materials = unknown
    if product and (product.materials > 0 or product.unpriced == 0) then
        materials = coin(product.materials) .. (product.unpriced > 0 and Style.Text(Style.gray, '+') or '')
    end
    local profit = Style.Text(Style.gray, 'Unknown')
    if row.profit ~= nil then
        profit = Style.Text(paint, (row.profit >= 0 and '+' or '-') .. coin(math.abs(row.profit))) .. (row.assumed and '*' or '')
    end
    return { Style.Text(paint, row.name), ns.NpcSources.Label(row.kind), materials,
        product and product.auction and coin(product.auction.net) or unknown,
        product and product.vendor and coin(product.vendor) or unknown,
        product and product.best and (product.best == 'auction' and 'Auction' or 'Vendor') or unknown, profit }
end

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

function Browser.Toggle()
    if Browser.window and Browser.window:IsShown() then Browser.window:Hide() else Browser.Show() end
end

-- Whether any profession was read for this character; if not, "My recipes" would be empty, so all recipes are shown.
local function hasRead()
    local saved = ns.db and ns.db.knownRecipes and ns.db.knownRecipes[ns.characterID]
    return type(saved) == 'table' and next(saved) ~= nil
end

local function footer(info, rows, scanned)
    local notes = {}
    if not scanned then notes[#notes + 1] = 'No auction prices yet: scan the auction house (button below its window).' end
    if Browser.mine and #info.unread > 0 then
        local names = {}
        for _, kind in ipairs(info.unread) do names[#names + 1] = ns.NpcSources.Label(kind) end
        notes[#notes + 1] = 'Not read yet for this character: ' .. table.concat(names, ', ') .. '. Open each profession window once.'
    end
    local priced = 0
    for _, row in ipairs(rows) do if row.profit ~= nil then priced = priced + 1 end end
    notes[#notes + 1] = string.format('%d of %d recipes have a profit.', priced, #rows)
    notes[#notes + 1] = '* assumes one item per craft until the recipe was opened in the reagent window. The recipe table is a mirror of client tables and is not complete; materials are priced at the auction house or at a merchant you saw.'
    return table.concat(notes, ' ')
end

-- Works out the rows again (filters, prices, learned recipes) and draws them.
function Browser.Refresh()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    if Browser.mine == nil then Browser.mine = hasRead() end
    Browser.rows, Browser.info = ns.Profit.Rows(ns.characterID, { mine = Browser.mine, kind = Browser.kind,
        search = Browser.searchText })
    Browser.total = #Browser.rows
    Browser.offset = Browser.Clamp(Browser.offset, Browser.total)
    w.filter.Sync(); w.kindButton.Sync()
    w.footer:SetText(footer(Browser.info, Browser.rows, ns.db and ns.db.auction ~= nil))
    Browser.Draw()
end

function Browser.Draw()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    w.rangeText:SetText(Browser.RangeText(Browser.offset, Browser.total))
    for index = 1, ROWS do
        local line = w.lines[index]
        local row = Browser.rows and Browser.rows[Browser.offset + index]
        line.row = row
        if row then
            for i, value in ipairs(Browser.Cells(row)) do line.cells[i]:SetText(value) end
            line:Show()
        else line:Hide() end
    end
    ns.Nav.SyncScrollbar(w.slider, Browser.offset, math.max(0, Browser.total - ROWS))
end

function Browser.ScrollTo(offset)
    Browser.offset = Browser.Clamp(offset, Browser.total)
    Browser.Draw()
end
function Browser.Scroll(delta) Browser.ScrollTo(Browser.offset + delta) end

function Browser.Show()
    local w = Browser.window
    if not w then
        local name = 'TitanGatheredForeverV3ProfitWindow'
        w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
        Browser.window = w
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        ns.Nav.Frame(w, 'profit')
        w:SetScript('OnHide', function() GameTooltip:Hide() end)
        w.TitleText:SetText('TGF v3 Crafting profit')
        local note = text(w, 'GameFontHighlightSmall', 15, -33, 930)
        note:SetText('What each recipe earns: the product sells to the vendor or on the auction house (lowest buyout after the fee), minus the materials at the cheapest known price. Green is a profit, red a loss, gray is unknown because a price is missing. Click a recipe for its reagents.')
        w.filter = ns.Nav.Dropdown(w, 15, -65, 150, function() return scopes end,
            function() return Browser.mine == true end, function(value)
                Browser.mine, Browser.offset = value, 0; Browser.Refresh()
            end)
        w.kindButton = ns.Nav.Dropdown(w, 175, -65, 190, function()
            local list = { { value = false, label = 'All professions' } }
            for _, kind in ipairs(kinds) do list[#list + 1] = { value = kind, label = ns.NpcSources.Label(kind) } end
            return list
        end, function() return Browser.kind or false end, function(value)
            Browser.kind, Browser.offset = value or nil, 0; Browser.Refresh()
        end)
        w.rangeText = text(w, 'GameFontHighlightSmall', 380, -70, 300)
        text(w, 'GameFontNormalSmall', 690, -70, 50):SetText('Search')
        local search = CreateFrame('EditBox', nil, w, 'InputBoxTemplate')
        w.search = search
        search:SetSize(150, 22); search:SetPoint('TOPLEFT', w, 'TOPLEFT', 745, -65); search:SetAutoFocus(false)
        search:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
        search:SetScript('OnTextChanged', function(self, user)
            if not user then return end
            Browser.searchText, Browser.offset = self:GetText(), 0
            Browser.Refresh()
        end)
        button(w, 'Clear', 905, -65, 60, function()
            search:SetText(''); search:ClearFocus(); Browser.searchText, Browser.offset = nil, 0
            Browser.Refresh()
        end)
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
            line:SetScript('OnClick', function(self) if self.row then ns.CraftingView.Show(self.row.recipeID, 1) end end)
            line:SetScript('OnEnter', function(self)
                if not self.row then return end
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                GameTooltip:SetItemByID(self.row.productID)
                GameTooltip:Show()
            end)
            line:SetScript('OnLeave', function() GameTooltip:Hide() end)
            w.lines[index] = line
        end
        w:EnableMouseWheel(true)
        w:SetScript('OnMouseWheel', function(_, delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        w.slider = ns.Nav.Scrollbar(w, 15 + ROW_WIDTH + 8, -132, ROWS * ROW_HEIGHT, function(value)
            Browser.ScrollTo(value)
        end, function(delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        w.footer = text(w, 'GameFontHighlightSmall', 15, -492, 930)
    end
    ns.Nav.Activate('profit', w)
    w:Show()
    Browser.Refresh()
end
