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
    -- A recipe the player lacks the skill for is red, so the ones that could be learned now stand out.
    local function paint(value) return row.canLearn == false and ns.Style.Text(ns.Style.red, value) or value end
    return { paint(row.name), ns.NpcSources.Label(row.kind), paint(row.skill and tostring(row.skill) or 'Unknown'),
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

-- Opens the window, or closes it when it is already open (used by the minimap button).
function Browser.Toggle()
    if Browser.window and Browser.window:IsShown() then Browser.window:Hide() else Browser.Show() end
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

-- Opens the world map at the zone of the first source and marks every source with a gold ring, because the
-- map is crowded. Clicking the same recipe again clears the mark; choosing another recipe replaces it.
local function sourceIDs(row)
    local ids = {}
    for _, source in ipairs(row.sources) do ids[#ids + 1] = source.npcID end
    return ids
end

local function openMap(line)
    local row = line.row
    local source = row and row.sources[1]
    if not source then return end
    local key = row.kind .. '|' .. row.name
    if Browser.marked == key and ns.NpcSources.HasHighlight() then
        Browser.marked = nil
        ns.NpcSources.SetHighlight(nil)
    else
        Browser.marked = key
        ns.NpcSources.SetHighlight(sourceIDs(row))
    end
    local place = ns.NpcSources.Location(source.npcID)
    local mapID = place and place.mapID or ns.NpcSources.ContinentMap(source.npcID)
    if mapID then
        if OpenWorldMap then OpenWorldMap(mapID)
        elseif WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:Show(); WorldMapFrame:SetMapID(mapID) end
    end
    if ns.Map and ns.Map.Update then ns.Map.Update() end
    if ns.Minimap and ns.Minimap.Update then ns.Minimap.Update() end
end

function Browser.Refresh()
    local w = Browser.window
    if not w or not w:IsShown() then return end
    local rows, unread, pending = ns.NpcSources.Unlearned(ns.characterID, Browser.vendorOnly, Browser.kind)
    if Browser.searchText and Browser.searchText ~= '' then
        local needle, kept = Browser.searchText:lower(), {}
        for _, row in ipairs(rows) do
            if tostring(row.name):lower():find(needle, 1, true) then kept[#kept + 1] = row end
        end
        rows = kept
    end
    Browser.total = #rows
    Browser.offset = Browser.Clamp(Browser.offset, Browser.total)
    w.filter.Sync()
    w.kindButton.Sync()
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
    ns.Nav.SyncScrollbar(w.slider, Browser.offset, math.max(0, Browser.total - ROWS))
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
        w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        ns.Nav.Frame(w, 'recipes')
        w:SetScript('OnHide', function() GameTooltip:Hide() end)
        w.TitleText:SetText('TGF v3 Unlearned recipes')
        local note = text(w, 'GameFontHighlightSmall', 15, -33, 930)
        note:SetText('Unlearned recipes with a known trainer or vendor source. Red recipes need more skill than you have yet. Seed data is Classic and not confirmed in game until you visit the NPC. Scroll with the mouse wheel; hover an NPC name to see where to find them; click a row to open the map.')
        w.filter = ns.Nav.Dropdown(w, 15, -65, 150, function()
            return { { value = false, label = 'All unlearned' }, { value = true, label = 'Vendor only' } }
        end, function() return Browser.vendorOnly and true or false end, function(value)
            Browser.vendorOnly, Browser.offset = value, 0; Browser.Refresh()
        end)
        w.kindButton = ns.Nav.Dropdown(w, 175, -65, 190, function()
            local list = { { value = false, label = 'All professions' } }
            for _, kind in ipairs(ns.NpcSources.RecipeKinds) do list[#list + 1] = { value = kind, label = ns.NpcSources.Label(kind) } end
            return list
        end, function() return Browser.kind or false end, function(value) Browser.SetKind(value or nil) end)
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
        w.slider = ns.Nav.Scrollbar(w, 15 + ROW_WIDTH + 8, -132, ROWS * ROW_HEIGHT, function(value)
            Browser.ScrollTo(value)
        end, function(delta) Browser.Scroll(-delta * WHEEL_STEP) end)
        w.footer = text(w, 'GameFontHighlightSmall', 15, -520, 930)
    end
    ns.Nav.Activate('recipes', w)
    w:Show()
    Browser.Refresh()
end
