local passed = 0
local function test(name, fn) local ok, err = pcall(fn); assert(ok, name .. ': ' .. tostring(err)); passed = passed + 1 end
local function eq(a, b) assert(a == b, tostring(a) .. ' != ' .. tostring(b)) end

-- Any widget: unknown methods do nothing, the ones the panel reads keep their state.
local function widget(kind)
    local w = { kind = kind, scripts = {}, shown = true }
    function w:SetScript(event, fn) self.scripts[event] = fn end
    function w:GetScript(event) return self.scripts[event] end
    function w:SetText(text) self.text = text end
    function w:GetText() return self.text end
    function w:SetChecked(value) self.checked = value end
    function w:GetChecked() return self.checked end
    function w:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:GetWidth() return 600 end
    function w:GetStringHeight() return 14 end
    function w:GetTextWidth() return 120 end
    function w:CreateFontString() return widget('FontString') end
    function w:CreateTexture() return widget('Texture') end
    return setmetatable(w, { __index = function() return function() end end })
end
local created = {}
CreateFrame = function(kind, _, parent, template)
    local w = widget(kind); w.template = template; w.parent = parent
    created[#created + 1] = w
    return w
end
UIParent = widget('Frame')

local calls = {}
local function count(name) return function() calls[name] = (calls[name] or 0) + 1 end end
local visible = { [2770] = true, [2771] = true }
local ns
ns = {
    settings = { categories = {}, mapProfessions = {}, mapNpcProfessions = {}, transportPattern = 'dashed',
        titanSort = 'id', auctionUndercutPreset = 5, auctionUndercutPercent = 5, showBank = true },
    inventory = {},
    L = { showZero = 'Show materials with zero count', itemTooltips = 'Show item tooltips' },
    Map = { Update = count('map') }, Minimap = { Update = count('minimap') },
    Transport = { Update = count('transport') }, FlightPaths = { Update = count('flights') },
    Titan = { SORTS = { { id = 'id', label = 'Item ID' }, { id = 'name', label = 'Name' } }, Refresh = count('titan') },
    Catalog = { Rebuild = count('catalog'), Modules = function()
        return { { id = 'Mining', label = 'Mining', kind = 'profession' }, { id = 'Auction', label = 'Auction items', kind = 'other' } }
    end },
    Professions = { Rows = function() return { { kind = 'Mining', rank = 75, maxRank = 150 } } end },
    Style = { Skill = function(rank, max) return rank .. '/' .. max end, ItemName = function(id) return 'Item ' .. id end },
    Sources = {
        Categories = function() return { { id = 'Mining', label = 'Mining' }, { id = 'Herbs', label = 'Herbalism' }, { id = 'PvP', label = 'PvP' } } end,
        ToggleKey = function(kind) return kind == 'Mining' and 'mapMining' or nil end,
        Items = function(kind) if kind == 'Mining' then return { [2770] = true, [2771] = true } end return {} end,
        MaterialVisible = function(id) return visible[id] ~= false end,
        SetMaterialVisible = function(id, value) visible[id] = value end,
        SettingsChanged = count('sources'),
    },
    NpcSources = { Kinds = { 'Mining', 'Cooking' }, InstalledKinds = function(kinds) return kinds end, Label = function(kind) return kind end },
    UpdateGathering = count('gathering'), Reports = { Refresh = count('reports') },
    AuctionScan = { Status = function() return 'No scan yet.' end },
    MinimapButton = { Update = count('button') },
    NpcToggleAxes = function() ns.settings.npcAxisSwap = not ns.settings.npcAxisSwap end,
    ScheduleRefresh = count('refresh'),
    IsPublic = function() return true end,
}
assert(loadfile('TitanGatheredForever/Settings.lua'))('TitanGatheredForever', ns)
assert(loadfile('TitanGatheredForever/Navigation.lua'))('TitanGatheredForever', ns)
assert(loadfile('TitanGatheredForever/OptionsPanel.lua'))('TitanGatheredForever', ns)
local Options = ns.Options

-- The widgets a drawn page shows, by kind, in order.
local function shown(page, kind)
    local list = {}
    local pool = page.pools[kind]
    for index = 1, pool and pool.used or 0 do list[#list + 1] = pool[index] end
    return list
end
local function checkFor(page, label)
    local labels, boxes = shown(page, 'label'), shown(page, 'check')
    local box = 0
    for _, row in ipairs(page.spec.rows(page)) do
        if row.kind == 'check' then box = box + 1; if row.label == label then return boxes[box] end end
    end
    error('no switch ' .. label .. ' among ' .. #labels .. ' labels')
end
local function buttonFor(page, label)
    for _, b in ipairs(shown(page, 'button')) do if b.text == label then return b end end
    error('no button ' .. label)
end
local function click(w) w:SetChecked(not w:GetChecked()); w.scripts.OnClick(w) end

test('without the Settings window of the game nothing is registered', function()
    eq(Options.Register(), false)
    eq(Options.category, nil)
    eq(Options.Open('pins'), false)
end)

local registered, opened = {}, {}
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        local category = { name = name, frame = frame, GetID = function() return 'root' end }
        registered[#registered + 1] = category; return category
    end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
        local category = { name = name, frame = frame, parent = parent, GetID = function() return 'sub:' .. name end }
        registered[#registered + 1] = category; return category
    end,
    RegisterAddOnCategory = function(category) registered.addon = (registered.addon or 0) + 1; registered.top = category end,
    OpenToCategory = function(id) opened[#opened + 1] = id end,
}

test('one AddOns category with a page per subject, registered once', function()
    eq(Options.Register(), true)
    eq(Options.Register(), true)
    eq(registered.addon, 1)
    eq(#registered, #Options.PAGES)
    eq(registered.top, registered[1])
    assert(registered[1].name:find('^|T.-|t Titan Gathered$'))
    for index = 2, #registered do eq(registered[index].parent, registered[1]) end
    local names = {}
    for index = 2, #registered do names[#names + 1] = registered[index].name end
    eq(table.concat(names, ','), 'Material list,Professions,Map pins,Gathering spots,Map materials,Travel routes,Auction house,Diagnostics,Backup')
end)

test('a page reads the settings when shown and a switch writes them with the same update as the menu', function()
    local page = Options.pages.pins
    ns.settings.mapRecipeVendors = true
    page.frame:Show()
    local box = checkFor(page, 'Show recipe vendors')
    eq(box:GetChecked(), true)
    click(box)
    eq(ns.settings.mapRecipeVendors, false)
    eq(calls.map, 1); eq(calls.minimap, 1)
    ns.settings.mapRecipeVendors = true          -- changed in the Titan menu meanwhile
    page.frame:Show()
    eq(checkFor(page, 'Show recipe vendors'):GetChecked(), true)
    local cooking = checkFor(page, 'Cooking pins')
    click(cooking)
    eq(ns.settings.mapNpcProfessions.Cooking, false)
    click(checkFor(page, 'Swap map axes (use if pins look mirrored)'))
    eq(ns.settings.npcAxisSwap, true)
end)

test('redrawing a page reuses its widgets', function()
    local page = Options.pages.pins
    local before = #created
    page.frame:Show(); page.frame:Show()
    eq(#created, before)
end)

test('combo boxes set the travel route style', function()
    local page = Options.pages.travel
    page.frame:Show()
    local drops = shown(page, 'choice')
    eq(#drops, 3)
    eq(drops[1].row.get(), 'game')
    drops[1].row.set('anchor')
    eq(ns.settings.transportIcon, 'anchor')
    drops[3].row.set('dotted')
    eq(ns.settings.transportPattern, 'dotted')
    eq(calls.transport, 2)
end)

test('profession modules switch the catalogue like the menu', function()
    local page = Options.pages.professions
    page.frame:Show()
    click(checkFor(page, 'Mining  75/150'))
    eq(ns.settings.categories.Mining, false)
    eq(calls.catalog, 1); eq(calls.reports, 1)
    click(checkFor(page, 'Auction items'))
    eq(ns.settings.categories.Auction, false)
end)

test('map materials follow the profession picked in the combo box', function()
    local page = Options.pages.materials
    page.frame:Show()
    eq(page.category, 'Mining')
    local drop = shown(page, 'choice')[1]
    local labels = {}
    for _, option in ipairs(drop.row.options()) do labels[#labels + 1] = option.label end
    eq(table.concat(labels, ','), 'Mining,Herbalism')
    eq(#shown(page, 'check'), 2)
    buttonFor(page, 'Hide all materials').scripts.OnClick()
    eq(visible[2770], false); eq(visible[2771], false)
    eq(checkFor(page, 'Item 2770'):GetChecked(), false)
    click(checkFor(page, 'Item 2771'))
    eq(visible[2771], true)
    drop.row.set('Herbs'); Options.Draw(page)
    eq(page.category, 'Herbs')
    eq(#shown(page, 'check'), 0)
end)

test('the auction undercut keeps the preset and the percentage equal', function()
    local page = Options.pages.auction
    page.frame:Show()
    local drop = shown(page, 'choice')[1]
    drop.row.set(10)
    eq(ns.settings.auctionUndercutPreset, 10); eq(ns.settings.auctionUndercutPercent, 10)
end)

test('every page draws without errors', function()
    for _, spec in ipairs(Options.PAGES) do Options.pages[spec.id].frame:Show() end
end)

test('the General page says where the material list is, with and without Titan Panel', function()
    ns.Titan.broker = nil
    ns.settings.showMinimapButton = true
    assert(Options.ButtonNote().text:find('My materials tab', 1, true))
    ns.settings.showMinimapButton = false
    assert(Options.ButtonNote().text:find('/tgf materials', 1, true))
    ns.Titan.broker = {}
    assert(Options.ButtonNote().text:find('Titan Panel entry', 1, true))
    ns.Titan.broker, ns.settings.showMinimapButton = nil, true
end)

test('Open shows the page asked for, or the first one', function()
    eq(Options.Open('travel'), true)
    eq(opened[#opened], 'sub:Travel routes')
    Options.Open()
    eq(opened[#opened], 'root')
end)

test('Backup exports the settings as one text and imports them back', function()
    local page = Options.pages.backup
    page.frame:Show()
    ns.settings.transportPattern = 'solid'
    buttonFor(page, 'Export settings').scripts.OnClick()
    local box = shown(page, 'input')[2]
    local text = box:GetText()
    assert(text:find('^TGF%-SETTINGS:1:'))
    eq(page.text, text)
    ns.settings.transportPattern = 'dashed'
    box:SetText('garbage'); box.scripts.OnTextChanged(box, true)
    buttonFor(page, 'Import settings').scripts.OnClick()
    eq(ns.settings.transportPattern, 'dashed')
    eq(page.reload, nil)
    assert(page.status:find('not a Titan Gathered settings export'))
    box:SetText(text); box.scripts.OnTextChanged(box, true)
    local same = ns.settings
    buttonFor(page, 'Import settings').scripts.OnClick()
    eq(ns.settings, same)
    eq(ns.settings.transportPattern, 'solid')
    eq(page.reload, true)
    buttonFor(page, 'Reload interface')
    page.frame:Show()
    eq(page.status, nil)
end)

test('Backup shows the folder of the saved data file for copying', function()
    local page = Options.pages.backup
    IsMacClient = function() return false end
    GetCVar = function(name) if name == 'accountList' then return 'OTHER|!MEDYN|' end end
    page.frame:Show()
    local path = shown(page, 'input')[1]
    eq(path:GetText(), 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF\\Account\\MEDYN\\SavedVariables')
    path:SetText('typed'); path.scripts.OnTextChanged(path, true)
    eq(path:GetText(), 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF\\Account\\MEDYN\\SavedVariables')
    IsMacClient = function() return true end
    GetCVar = function() error('protected') end
    page.frame:Show()
    eq(shown(page, 'input')[1]:GetText(), '/Applications/World of Warcraft/_forever_/WTF/Account/YOUR_ACCOUNT/SavedVariables')
    IsMacClient, GetCVar = nil, nil
end)

test('a pasted text is only read as values and must be complete', function()
    local text = ns.Settings.Export({ a = 1, b = 'x', c = { [5] = false } })
    local value = ns.Settings.Decode(text)
    eq(value.a, 1); eq(value.b, 'x'); eq(value.c[5], false)
    eq(ns.Settings.Decode(text:sub(1, -2)), nil)
    eq(ns.Settings.Decode(text .. '}'), nil)
    eq(ns.Settings.Decode('TGF-SETTINGS:1:00000000:{}'), nil)
    eq(ns.Settings.Decode(''), nil)
end)

print('PASS ' .. passed .. ' options panel checks')
