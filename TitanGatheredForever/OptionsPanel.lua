local _, ns = ...
local Options = { pages = {} }
ns.Options = Options

-- The settings of the addon in the game Options, AddOns tab: one category with a page per subject, the way other
-- addons list theirs. Every switch writes the same saved setting as the Titan Panel menu and runs the same update,
-- so the two always agree; a page reads the settings again each time it is shown.

Options.TITLE = 'Titan Gathered'
local ICON = '|TInterface\\AddOns\\TitanGatheredForever\\Artwork\\AddonIcon:16:16:0:0|t'
local LABEL_X, CONTROL_X, CHOICE_WIDTH, LABEL_WIDTH = 30, 380, 200, 330

local function redrawPins() ns.Map.Update(); ns.Minimap.Update() end
local function refreshList() ns.Titan.page = 1; ns.Titan.Refresh() end

-- Closes the Options window before another window of the addon opens, so the new one is not hidden behind it.
local function closeOptions()
    local panel = _G.SettingsPanel
    if panel and panel.IsShown and panel:IsShown() then
        if HideUIPanel then HideUIPanel(panel) else panel:Hide() end
    end
end
local function opener(open) return function() closeOptions(); open() end end

local function header(text) return { kind = 'header', text = text } end
local function note(text) return { kind = 'note', text = text } end
local function button(label, run) return { kind = 'button', label = label, run = run } end
local function check(label, get, set) return { kind = 'check', label = label, get = get, set = set } end
local function choice(label, options, get, set) return { kind = 'choice', label = label, options = options, get = get, set = set } end
-- A text box; without set it only shows its text for copying, and typing into it puts the text back.
local function input(get, set, takesFocus) return { kind = 'input', get = get, set = set, takesFocus = takesFocus } end

-- A switch that counts as on until it is turned off (a missing value is on), as most map switches.
local function onUnlessOff(label, key, after)
    return check(label, function() return ns.settings[key] ~= false end,
        function(value) ns.settings[key] = value; if after then after() end end)
end
-- A switch that is on only when it is true.
local function onWhenTrue(label, key, after)
    return check(label, function() return ns.settings[key] == true end,
        function(value) ns.settings[key] = value; if after then after() end end)
end
-- A switch kept in a table of exceptions: an entry set to false turns it off.
local function tableSwitch(label, tableKey, id, after)
    return check(label, function() return ns.settings[tableKey][id] ~= false end,
        function(value) ns.settings[tableKey][id] = value; after() end)
end

local function listSetting(label, key)
    return onWhenTrue(label, key, function() ns.Sources.SettingsChanged(); refreshList() end)
end

local function professionRows(rows)
    local learned = {}
    for _, skill in ipairs(ns.Professions.Rows()) do learned[skill.kind] = skill end
    local modules = ns.Catalog.Modules()
    local function add(module)
        local label = module.label
        local skill = learned[module.id]
        if skill then label = label .. '  ' .. ns.Style.Skill(skill.rank, skill.maxRank) end
        rows[#rows + 1] = tableSwitch(label, 'categories', module.id, function()
            ns.Catalog.Rebuild(ns.settings)
            ns.UpdateGathering()
            ns.Reports.Refresh()
            refreshList()
        end)
    end
    rows[#rows + 1] = header('Profession modules')
    if #modules == 0 then rows[#rows + 1] = note('Enable a Titan Gathered Forever profession addon in the AddOns screen.') end
    for _, module in ipairs(modules) do if module.kind == 'profession' then add(module) end end
    local additional
    for _, module in ipairs(modules) do
        if module.kind ~= 'profession' then
            if not additional then rows[#rows + 1] = header('Additional items'); additional = true end
            add(module)
        end
    end
end

local function gatheringRows(rows)
    rows[#rows + 1] = header('Gathering spots')
    rows[#rows + 1] = onWhenTrue('Show gathering spots on the world map', 'showGatheringWorld', function() ns.UpdateGathering() end)
    rows[#rows + 1] = onWhenTrue('Show gathering spots on the minimap', 'showGatheringMinimap', function() ns.UpdateGathering() end)
    rows[#rows + 1] = header('Professions on the maps')
    for _, category in ipairs(ns.Sources.Categories()) do
        local kind = category.id
        local key = ns.Sources.ToggleKey(kind)
        if key then rows[#rows + 1] = onWhenTrue(category.label .. ' spots', key, function() ns.UpdateGathering() end)
        else rows[#rows + 1] = tableSwitch(category.label .. ' spots', 'mapProfessions', kind, function() ns.UpdateGathering() end) end
    end
end

-- The material switches of one gathering profession, picked in a combo box at the top of the page.
local function materialRows(rows, page)
    local categories = {}
    for _, category in ipairs(ns.Sources.Categories()) do
        if category.id ~= 'PvP' then categories[#categories + 1] = { value = category.id, label = category.label } end
    end
    if #categories == 0 then rows[#rows + 1] = note('No gathering profession module is enabled.'); return end
    local known
    for _, option in ipairs(categories) do if option.value == page.category then known = true end end
    if not known then page.category = categories[1].value end
    rows[#rows + 1] = note('Choose which materials of a gathering profession get spots on the world map and the minimap.')
    rows[#rows + 1] = choice('Profession', function() return categories end, function() return page.category end,
        function(value) page.category = value end)
    local resources = ns.Sources.Items(page.category)
    local ids = {}
    for itemID in pairs(resources) do ids[#ids + 1] = itemID end
    table.sort(ids)
    rows[#rows + 1] = button('Show all materials', function()
        for _, itemID in ipairs(ids) do ns.Sources.SetMaterialVisible(itemID, true) end
        redrawPins()
    end)
    rows[#rows + 1] = button('Hide all materials', function()
        for _, itemID in ipairs(ids) do ns.Sources.SetMaterialVisible(itemID, false) end
        redrawPins()
    end)
    rows[#rows + 1] = header('Materials')
    if #ids == 0 then rows[#rows + 1] = note('This profession has no map materials.') end
    for _, itemID in ipairs(ids) do
        local id = itemID
        rows[#rows + 1] = check(ns.Style.ItemName(id), function() return ns.Sources.MaterialVisible(id) end,
            function(value) ns.Sources.SetMaterialVisible(id, value); redrawPins() end)
    end
end

local DOCK_ICONS = { { value = 'game', label = 'Game icons (boat, airship)' }, { value = 'anchor', label = 'Anchor' } }
local LINE_STYLES = { { value = 'thin', label = 'Thin' }, { value = 'clear', label = 'Clear' } }
local PATTERNS = { { value = 'dashed', label = 'Dashed' }, { value = 'dotted', label = 'Dotted' }, { value = 'solid', label = 'Solid' } }
local UNDERCUTS = { { value = 2, label = '2 %' }, { value = 5, label = '5 %' }, { value = 10, label = '10 %' }, { value = 15, label = '15 %' } }

local function sortOptions()
    local options = {}
    for _, mode in ipairs(ns.Titan.SORTS) do options[#options + 1] = { value = mode.id, label = mode.label } end
    return options
end

-- Where the game keeps the saved data of the addon. The game folder cannot be read by an addon, so it is the default
-- install folder of the system; the account folder is the account selected at login (the CVar accountList marks it
-- with !), when the client gives it.
Options.FILE = 'TitanGatheredForever.lua'
Options.DISCOVERY_FILE = 'TitanGatheredForever_Discovery.lua'
function Options.AccountFolder()
    local ok, list = pcall(function() return GetCVar and GetCVar('accountList') end)
    if ok and ns.IsPublic(list) and type(list) == 'string' then
        local name = list:match('!([^|]+)')
        if name and name ~= '' then return name, true end
    end
    return 'YOUR_ACCOUNT', false
end
function Options.DataFolder()
    local account, known = Options.AccountFolder()
    local mac = IsMacClient and IsMacClient()
    if mac then
        return '/Applications/World of Warcraft/_forever_/WTF/Account/' .. account .. '/SavedVariables', known, true
    end
    return 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF\\Account\\' .. account .. '\\SavedVariables', known, false
end

-- Moving everything to another computer, and the settings alone as one text. A text box holds what was exported or
-- pasted; Import replaces the settings and asks for a reload, after which every module reads them again.
-- Where the materials are: the My materials tab always, and the Titan Panel entry when a panel display exists. With
-- no panel and the minimap button hidden, this says how the main window still opens.
function Options.ButtonNote()
    if ns.Titan and ns.Titan.broker then
        return note('Your materials are in the My materials tab of the main window and in the list of the Titan Panel entry.')
    end
    if ns.settings.showMinimapButton == false then
        return note('No Titan Panel (or other panel display) is installed and the minimap button is hidden: open the main window with the Main window button below or /tgf materials.')
    end
    return note('Your materials are in the My materials tab of the main window (left click on the minimap button).')
end

local function backupRows(page)
    local folder, known, mac = Options.DataFolder()
    local rows = {
        header('Move or back up everything'),
        note('All statistics, map spots, the journal and the settings of every character of this account are in one file, ' .. Options.FILE .. ', in this folder (click the box, then copy with ' .. (mac and 'Cmd+C' or 'Ctrl+C') .. '):'),
        input(function() return folder end, nil),
        note(mac and 'In Finder press Cmd+Shift+G and paste the folder.' or 'Paste the folder into the address bar of File Explorer.'),
    }
    if not known then
        rows[#rows + 1] = note('YOUR_ACCOUNT is the folder of your account in WTF\\Account (the game did not name it). If the game is installed elsewhere, start from its _forever_ folder.')
    else
        rows[#rows + 1] = note('If the game is installed elsewhere, start from its _forever_ folder.')
    end
    rows[#rows + 1] = note('1. Quit the game: it writes the file when you log out. 2. Copy ' .. Options.FILE .. ' to a USB stick, a cloud folder or your backup. 3. On the other computer quit the game, put the file into the same folder there and replace the old one. 4. Start the game.')
    rows[#rows + 1] = note('The copied file replaces all addon data on the other computer, it does not merge. When you play on two computers, always carry the newest file over before you play, or the progress made on the other one is lost.')
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('TitanGatheredForever_Discovery') then
        rows[#rows + 1] = note('Discovery keeps its own data in ' .. Options.DISCOVERY_FILE .. ' in the same folder: copy it too.')
    end
    rows[#rows + 1] = header('Settings only')
    rows[#rows + 1] = note('To copy only the settings, for example to another account: Export settings puts them in the box as one text, select it and copy it. There, paste it into the box and click Import settings.')
    rows[#rows + 1] = input(function() return page.text or '' end, function(text) page.text = text end, true)
    rows[#rows + 1] = button('Export settings', function()
        page.text = ns.Settings.Export(ns.settings)
        page.status, page.reload, page.focus = 'Settings exported: copy the text in the box.', nil, true
    end)
    rows[#rows + 1] = button('Import settings', function()
        local ok, reason = ns.Settings.Import(ns.settings, page.text)
        if ok then
            page.status, page.reload = 'Settings imported. Reload the interface so every window and map uses them.', true
        else
            page.status, page.reload = reason, nil
        end
    end)
    if page.status then rows[#rows + 1] = note(page.status) end
    if page.reload then rows[#rows + 1] = button('Reload interface', function() if ReloadUI then ReloadUI() end end) end
    return rows
end

-- The pages in the order of the AddOns list. The first is the category itself; rows(page) returns its rows.
Options.PAGES = {
    { id = 'general', name = Options.TITLE, rows = function()
        return {
            note('Collects your gathering, crafting, auction and journey statistics. The same settings are in the right-click menu of the minimap button and of the Titan Panel entry when Titan Panel is installed.'),
            header('General'),
            onUnlessOff('Show minimap button', 'showMinimapButton', function() ns.MinimapButton.Update() end),
            Options.ButtonNote(),
            onUnlessOff('Let me move the profession and auction house windows', 'moveBlizzard'),
            button('Reset window positions', function()
                ns.Nav.ResetPositions()
                ns.Print('Window positions reset: the windows open in the middle of the screen again.')
            end),
            button('Icon appearance...', opener(function() ns.IconConfig.Show() end)),
            header('Windows'),
            button('Main window', opener(function() ns.Nav.Open(ns.Nav.last or 'materials') end)),
            button('Profession statistics', opener(function() ns.ProfessionStats.Open() end)),
            button('Journal', opener(function() ns.Nav.Open('journal') end)),
            button('Export statistics', opener(function() ns.ExportView.Show() end)),
        }
    end },
    { id = 'titan', name = 'Material list', rows = function()
        return {
            note('The list shown when you point at the Titan Panel entry, and what item tooltips add. The My materials tab of the main window lists the same materials.'),
            header('Material list'),
            listSetting(ns.L.showZero, 'showZero'),
            check('Show bank counts', function() return ns.settings.showBank == true end, function(value)
                ns.settings.showBank = value
                ns.inventory.bankCurrent = false
                ns.ScheduleRefresh()
                refreshList()
            end),
            choice('Sort items', sortOptions, function() return ns.settings.titanSort or 'id' end,
                function(value) ns.settings.titanSort = value; refreshList() end),
            header('Item tooltips'),
            listSetting(ns.L.itemTooltips, 'itemTooltips'),
            listSetting('History in item tooltips', 'historyTooltips'),
        }
    end },
    { id = 'professions', name = 'Professions', rows = function()
        local rows = { note('The materials of a switched off profession leave the material list, the maps and the reports. The data collected for it is kept.') }
        professionRows(rows)
        return rows
    end },
    { id = 'pins', name = 'Map pins', rows = function()
        local rows = {
            header('Pins on the world map and the minimap'),
            onUnlessOff('Show profession trainers', 'mapTrainers', redrawPins),
            onUnlessOff('Show recipe vendors', 'mapRecipeVendors', redrawPins),
            onUnlessOff('Show weapon masters', 'mapWeaponMasters', redrawPins),
            onUnlessOff('Show quests in progress', 'mapQuestGivers', redrawPins),
            onUnlessOff('Show rare creatures', 'mapRareCreatures', redrawPins),
            header('Trainer and vendor professions'),
        }
        for _, kind in ipairs(ns.NpcSources.InstalledKinds(ns.NpcSources.Kinds)) do
            rows[#rows + 1] = tableSwitch(ns.NpcSources.Label(kind) .. ' pins', 'mapNpcProfessions', kind, redrawPins)
        end
        rows[#rows + 1] = header('Pin placement')
        rows[#rows + 1] = check('Swap map axes (use if pins look mirrored)', function() return ns.settings.npcAxisSwap == true end,
            function() ns.NpcToggleAxes() end)
        rows[#rows + 1] = button('Find nearest trainer or vendor pin', function() ns.NpcNearest() end)
        rows[#rows + 1] = button('Icon appearance...', opener(function() ns.IconConfig.Show() end))
        return rows
    end },
    { id = 'gathering', name = 'Gathering spots', rows = function()
        local rows = { note('Spots where you gathered, kept per map. Saved spots of the open map are cleared from the world map menu.') }
        gatheringRows(rows)
        return rows
    end },
    { id = 'materials', name = 'Map materials', rows = function(page)
        local rows = {}
        materialRows(rows, page)
        return rows
    end },
    { id = 'travel', name = 'Travel routes', rows = function()
        local function update() ns.Transport.Update() end
        return {
            header('Flight points'),
            onWhenTrue('Show flight points', 'flightPoints', function() ns.FlightPaths.Update() end),
            header('Boat and zeppelin routes'),
            onUnlessOff('Show routes on the map', 'transportRoutes', update),
            choice('Dock icon', function() return DOCK_ICONS end,
                function() return ns.settings.transportIcon == 'anchor' and 'anchor' or 'game' end,
                function(value) ns.settings.transportIcon = value; update() end),
            choice('Line thickness', function() return LINE_STYLES end,
                function() return ns.settings.transportStyle == 'clear' and 'clear' or 'thin' end,
                function(value) ns.settings.transportStyle = value; update() end),
            choice('Line pattern', function() return PATTERNS end, function() return ns.settings.transportPattern end,
                function(value) ns.settings.transportPattern = value; update() end),
        }
    end },
    { id = 'auction', name = 'Auction house', rows = function()
        return {
            note(ns.AuctionScan.Status()),
            header('Prices'),
            onWhenTrue('Scan when the auction house opens (at most every 30 minutes)', 'auctionAutoScan'),
            onUnlessOff('Show auction prices in item tooltips', 'auctionTooltips'),
            button('Scan now (the auction house must be open)', function() ns.AuctionScan.Run() end),
            button('Clear scanned prices', function()
                ns.AuctionScan.Clear(); if ns.CraftingView then ns.CraftingView.Refresh() end
            end),
            header('Selling'),
            onUnlessOff('Fill Buyout in the Sell tab (lowest price minus a percentage)', 'auctionUndercutEnabled'),
            choice('Undercut', function() return UNDERCUTS end, function() return ns.settings.auctionUndercutPreset end,
                function(value)
                    ns.settings.auctionUndercutPreset = value
                    ns.settings.auctionUndercutPercent = value
                    if ns.AuctionUndercut and ns.AuctionUndercut.drop and ns.AuctionUndercut.drop.Sync then ns.AuctionUndercut.drop.Sync() end
                end),
        }
    end },
    { id = 'diagnostics', name = 'Diagnostics', rows = function()
        return {
            header('Debug log'),
            listSetting('Debug mode', 'debugMode'),
            note('Debug mode writes events to the debug log in the saved variables file. The file is written on /reload and logout.'),
            listSetting('Also show debug messages in chat', 'debugChat'),
            button('Clear debug log', function() ns.DebugLog.Clear(); ns.Print('Debug log cleared.') end),
            header('Checks'),
            button('Refresh inventory', function() ns.ScheduleRefresh() end),
            button('Show status report', function() ns.ShowStatus(true) end),
            button('Show NPC recording log', function() ns.NpcObserver.PrintLog() end),
        }
    end },
    { id = 'backup', name = 'Backup', rows = backupRows },
}

-- Widgets are kept per kind and reused when a page is drawn again.
local function acquire(page, kind, create)
    local pool = page.pools[kind]
    if not pool then pool = { used = 0 }; page.pools[kind] = pool end
    pool.used = pool.used + 1
    local widget = pool[pool.used]
    if not widget then widget = create(); pool[pool.used] = widget end
    return widget
end

-- The text of the pages is a little smaller than the game font it starts from (Options.SHRINK points less).
Options.SHRINK = 2
local function fontString(parent, font, shrink)
    local text = parent:CreateFontString(nil, 'OVERLAY', font)
    text:SetJustifyH('LEFT')
    local file, size, flags = text:GetFont()
    if type(file) == 'string' and type(size) == 'number' and size > 8 then
        text:SetFont(file, math.max(8, size - (shrink or Options.SHRINK)), flags)
    end
    return text
end

local function checkbox(parent)
    local ok, box = pcall(CreateFrame, 'CheckButton', nil, parent, 'SettingsCheckBoxTemplate')
    if not ok or not box then box = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate') end
    box:SetSize(22, 22)
    box.HoverBackground = nil
    return box
end

local function place(widget, parent, x, y)
    widget:ClearAllPoints()
    widget:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    widget:Show()
end

-- Draws the rows of a page from the top: section headers, notes, switches, combo boxes and buttons.
function Options.Draw(page)
    local content = page.content
    for _, pool in pairs(page.pools) do
        for index = 1, #pool do pool[index]:Hide() end
        pool.used = 0
    end
    local width = page.width or 600
    local y = -8
    for _, row in ipairs(page.spec.rows(page)) do
        if row.kind == 'header' then
            local text = acquire(page, 'header', function() return fontString(content, 'GameFontHighlightLarge') end)
            y = y - 8
            place(text, content, LABEL_X - 14, y); text:SetText(row.text)
            y = y - 26
        elseif row.kind == 'note' then
            local text = acquire(page, 'note', function() return fontString(content, 'GameFontNormalSmall', 1) end)
            text:SetWidth(width - LABEL_X * 2)
            place(text, content, LABEL_X - 14, y); text:SetText(row.text)
            y = y - math.max(14, (text.GetStringHeight and text:GetStringHeight() or 12) + 7)
        elseif row.kind == 'check' then
            local label = acquire(page, 'label', function() return fontString(content, 'GameFontNormal') end)
            local box = acquire(page, 'check', function() return checkbox(content) end)
            label:SetWidth(LABEL_WIDTH)
            place(label, content, LABEL_X, y - 5); label:SetText(row.label)
            place(box, content, CONTROL_X, y)
            box:SetChecked(row.get() and true or false)
            box:SetScript('OnClick', function(self)
                row.set(self:GetChecked() and true or false)
                Options.Draw(page)
            end)
            y = y - 27
        elseif row.kind == 'choice' then
            local label = acquire(page, 'label', function() return fontString(content, 'GameFontNormal') end)
            label:SetWidth(LABEL_WIDTH)
            place(label, content, LABEL_X, y - 5); label:SetText(row.label)
            local drop = acquire(page, 'choice', function()
                local made
                made = ns.Nav.Dropdown(content, CONTROL_X, y, CHOICE_WIDTH,
                    function() return made and made.row and made.row.options() or {} end,
                    function() return made and made.row and made.row.get() end,
                    function(value) made.row.set(value); Options.Draw(page) end)
                return made
            end)
            drop.row = row
            place(drop, content, CONTROL_X, y)
            drop.Sync()
            y = y - 30
        elseif row.kind == 'input' then
            local box = acquire(page, 'input', function()
                local made = CreateFrame('EditBox', nil, content, 'InputBoxTemplate')
                made:SetHeight(24); made:SetAutoFocus(false)
                if made.SetMaxLetters then made:SetMaxLetters(0) end
                made:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
                made:SetScript('OnEditFocusGained', function(self) self:HighlightText() end)
                made:SetScript('OnTextChanged', function(self, userInput)
                    if not userInput or not self.row then return end
                    if self.row.set then self.row.set(self:GetText()) else self:SetText(self.row.get()); self:HighlightText() end
                end)
                return made
            end)
            box.row = row
            box:SetWidth(math.min(560, width - LABEL_X * 2))
            place(box, content, LABEL_X + 6, y)
            box:SetText(row.get())
            if page.focus and row.takesFocus then page.focus = nil; box:SetFocus(); box:HighlightText() end
            y = y - 34
        elseif row.kind == 'button' then
            local b = acquire(page, 'button', function()
                local made = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
                made:SetHeight(22)
                if made.SetNormalFontObject then
                    made:SetNormalFontObject('GameFontNormalSmall')
                    if made.SetHighlightFontObject then made:SetHighlightFontObject('GameFontHighlightSmall') end
                    if made.SetDisabledFontObject then made:SetDisabledFontObject('GameFontDisableSmall') end
                end
                return made
            end)
            b:SetText(row.label)
            b:SetWidth(math.max(150, (b.GetTextWidth and b:GetTextWidth() or 130) + 26))
            place(b, content, LABEL_X, y)
            b:SetScript('OnClick', function() row.run(); Options.Draw(page) end)
            y = y - 28
        end
    end
    content:SetHeight(math.max(1, -y + 8))
end

-- The canvas of one page: the title with a divider, and the rows in a scroll frame below it.
local function buildPage(spec)
    local page = { spec = spec, pools = {} }
    local frame = CreateFrame('Frame')
    page.frame = frame
    local title = fontString(frame, 'GameFontHighlightHuge', 4)
    title:SetPoint('TOPLEFT', frame, 'TOPLEFT', 22, -22)
    title:SetText(spec.name)
    local divider = frame:CreateTexture(nil, 'ARTWORK')
    if divider.SetAtlas then divider:SetAtlas('Options_HorizontalDivider', true) end
    divider:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -54)
    divider:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -12, -54)
    local ok, scroll = pcall(CreateFrame, 'ScrollFrame', nil, frame, 'UIPanelScrollFrameTemplate')
    if not ok or not scroll then
        scroll = CreateFrame('ScrollFrame', nil, frame)
        scroll:EnableMouseWheel(true)
        scroll:SetScript('OnMouseWheel', function(self, delta)
            local range = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 40)))
        end)
    end
    scroll:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -64)
    scroll:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -30, 8)
    local content = CreateFrame('Frame', nil, scroll)
    content:SetSize(600, 1)
    scroll:SetScrollChild(content)
    page.scroll, page.content = scroll, content
    frame:SetScript('OnShow', function()
        local width = scroll.GetWidth and scroll:GetWidth() or 0
        if width and width > 100 then page.width = width; content:SetWidth(width) end
        page.status, page.reload, page.focus = nil, nil, nil
        Options.Draw(page)
    end)
    return page
end

-- Adds the category and its pages to the AddOns tab. Does nothing on a client without the Settings window.
function Options.Register()
    if Options.category then return true end
    local api = _G.Settings
    if type(api) ~= 'table' or not api.RegisterCanvasLayoutCategory or not api.RegisterAddOnCategory then return false end
    for index, spec in ipairs(Options.PAGES) do
        local page = buildPage(spec)
        Options.pages[spec.id] = page
        if index == 1 then
            page.category = api.RegisterCanvasLayoutCategory(page.frame, ICON .. ' ' .. Options.TITLE)
            Options.category = page.category
        elseif api.RegisterCanvasLayoutSubcategory then
            page.category = api.RegisterCanvasLayoutSubcategory(Options.category, page.frame, spec.name)
        end
    end
    api.RegisterAddOnCategory(Options.category)
    return true
end

-- Opens the Options window on a page of the addon (the first one without a page id).
function Options.Open(id)
    local api = _G.Settings
    local page = Options.pages[id or 'general'] or Options.pages.general
    if not Options.category or not page or not api or not api.OpenToCategory then return false end
    local category = page.category or Options.category
    local categoryID = category.GetID and category:GetID() or category.ID
    api.OpenToCategory(categoryID)
    return true
end
