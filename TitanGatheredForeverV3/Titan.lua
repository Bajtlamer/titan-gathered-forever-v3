local _, ns = ...
local Titan = { page = 1 }
ns.Titan = Titan

function Titan.Rows()
    local rows = {}
    for _, itemID in ipairs(ns.Catalog.List(ns.settings)) do
        local count = ns.inventory:Get(itemID)
        if ns.settings.showZero or (count.bags or 0) > 0 or (ns.settings.showBank and (count.bank or 0) > 0) then
            rows[#rows + 1] = { itemID = itemID, count = count,
                group = ns.Catalog.Group(ns.Items[itemID], ns.settings) }
        end
    end
    table.sort(rows, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        return a.itemID < b.itemID
    end)
    return rows
end

function Titan.Show(owner)
    local tooltip = Titan.tooltip
    if not tooltip then
        tooltip = CreateFrame('GameTooltip', 'TitanGatheredForeverV3SummaryTooltip', UIParent, 'GameTooltipTemplate')
        Titan.tooltip = tooltip
    end
    Titan.owner = owner
    tooltip:SetOwner(owner, 'ANCHOR_NONE')
    if tooltip.SetPoint then tooltip:SetPoint('TOPLEFT', owner, 'BOTTOMLEFT', 0, 0) end
    tooltip:ClearLines()
    local skills = ns.Professions.Rows()
    if #skills > 0 then
        tooltip:AddLine(ns.Style.Text(ns.Style.orange, 'Learned professions'))
        for _, skill in ipairs(skills) do
            tooltip:AddDoubleLine(ns.Style.Text(ns.Style.gold, skill.name), ns.Style.Skill(skill.rank, skill.maxRank))
        end
        ns.Style.Separator(tooltip)
    end
    tooltip:AddDoubleLine(ns.Style.Text(ns.Style.gold, 'Material'),
        ns.Style.Text(ns.Style.gold, ns.Tooltips.CountHeading()), 1, 1, 1, 1, 1, 1)
    local rows = Titan.Rows()
    local limit = ns.settings.rowsPerPage
    local pages = math.max(1, math.ceil(#rows / limit))
    Titan.page = math.min(pages, math.max(1, Titan.page))
    local group
    for index = (Titan.page - 1) * limit + 1, math.min(#rows, Titan.page * limit) do
        local row = rows[index]
        if row.group ~= group then ns.Style.Section(tooltip, row.group); group = row.group end
        local c = row.count
        tooltip:AddDoubleLine(ns.Style.ItemName(row.itemID), ns.Tooltips.CountValues(c), 1, 1, 1, 1, 1, 1)
    end
    if #rows == 0 then tooltip:AddLine(ns.L.noItems, 1, 1, 1, true) end
    local observation = ns.Tooltips.BankObservation(ns.inventory:Get(0))
    if observation then tooltip:AddLine(ns.Style.Text(ns.Style.gray, observation), 1, 1, 1, true) end
    if ns.inventory:Get(0).bagsState == 'cached' then
        tooltip:AddLine(ns.Style.Text(ns.Style.gray, 'Bag refresh incomplete; showing last observed counts.'), 1, 1, 1, true)
    end
    if pages > 1 then tooltip:AddLine(ns.Style.Text(ns.Style.gray, string.format('Page %d / %d', Titan.page, pages))) end
    tooltip:AddLine(ns.Style.Text(ns.Style.gray, ns.L.hint), 1, 1, 1, true)
    tooltip:Show()
end

function Titan.Hide()
    Titan.owner = nil
    if Titan.tooltip then Titan.tooltip:Hide() end
end

function Titan.Refresh()
    if not ns.inventory then return end
    if Titan.broker then
        Titan.broker.text = Titan.version
    end
    if Titan.owner then Titan.Show(Titan.owner) end
end

function Titan.ClearSpotsMenu(owner, world)
    if not ns.gathering then return end
    local mapID = world:GetMapID()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ns.Style.Text(ns.Style.orange, 'Clear saved TGF v3 spots'))
        if not ns.IsPublic(mapID) or type(mapID) ~= 'number' or mapID <= 0 then
            root:CreateTitle('No map selected.'); return
        end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local name = info and info.name or ('Map ' .. mapID)
        root:CreateTitle(name)
        root:CreateTitle('Only spots saved directly on this map are affected.')
        for _, category in ipairs(ns.Sources.Categories(true)) do
            local kind, label = category.id, category.label
            local count = ns.gathering:Count(mapID, kind)
            if count > 0 then
                local confirmation = root:CreateButton(string.format('Clear %s spots (%d)', label, count))
                confirmation:CreateTitle('Permanently delete these saved spots?')
                confirmation:CreateTitle(name)
                confirmation:CreateButton(string.format('Confirm: clear %d %s spots', count, label), function()
                    if world:GetMapID() ~= mapID then
                        ns.Print('Map changed. Open TGF v3 spots again to choose the current map.'); return
                    end
                    if ns.observations then ns.observations:SuppressMap(mapID, kind) end
                    local removed = ns.gathering:Clear(mapID, kind)
                    ns.Map.Update(); ns.Minimap.Update()
                    ns.Print(string.format('Cleared %d %s spots from %s.', removed, label, name))
                end)
            else
                root:CreateTitle(label .. ': 0 saved spots')
            end
        end
    end)
end

function Titan.Menu(owner)
    Titan.Hide()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ns.Style.Text(ns.Style.orange, ns.L.title))
        local display = root:CreateButton('Display')
        local function toggle(parent, label, key)
            parent:CreateCheckbox(label, function() return ns.settings[key] end, function()
                ns.settings[key] = not ns.settings[key]; ns.Sources.SettingsChanged(); Titan.page = 1; Titan.Refresh()
            end)
        end
        toggle(display, ns.L.showZero, 'showZero')
        toggle(display, ns.L.itemTooltips, 'itemTooltips')
        display:CreateCheckbox('Show bank counts', function() return ns.settings.showBank end, function()
            ns.settings.showBank = not ns.settings.showBank
            ns.inventory.bankCurrent = false
            Titan.page = 1
            ns.ScheduleRefresh()
            Titan.Refresh()
        end)
        local professions = root:CreateButton('Professions')
        professions:SetScrollMode(300)
        local function moduleToggle(parent, module)
            local key = module.id
            parent:CreateCheckbox(ns.Style.Text(ns.Style.gold, module.label), function() return ns.settings.categories[key] ~= false end, function()
                ns.settings.categories[key] = ns.settings.categories[key] == false
                ns.Catalog.Rebuild(ns.settings)
                ns.UpdateGathering()
                ns.Reports.Refresh()
                Titan.page = 1; Titan.Refresh()
            end)
        end
        local modules = ns.Catalog.Modules()
        for _, module in ipairs(modules) do
            if module.kind == 'profession' then moduleToggle(professions, module) end
        end
        local additional
        for _, module in ipairs(modules) do
            if module.kind ~= 'profession' then
                if not additional then additional = root:CreateButton('Additional items') end
                moduleToggle(additional, module)
            end
        end
        if #modules == 0 then professions:CreateTitle('Enable a Gathered profession addon in the AddOns screen.') end
        root:CreateButton('Icon appearance...', function() ns.IconConfig.Show() end)
        local flights = root:CreateButton('Flight points')
        flights:CreateCheckbox('Show flight points', function() return ns.settings.flightPoints end, function()
            ns.settings.flightPoints = not ns.settings.flightPoints
            ns.FlightPaths.Update()
        end)
        flights:CreateTitle('World map: your faction and neutral flight points')
        flights:CreateTitle('Discovery status is shown in the tooltip')
        local gathering = root:CreateButton('Gathering map')
        local function mapToggle(parent, label, key)
            parent:CreateCheckbox(label, function() return ns.settings[key] end, function()
                ns.settings[key] = not ns.settings[key]
                ns.UpdateGathering()
            end)
        end
        mapToggle(gathering, 'Enable gathering map', 'gatheringMap')
        if ns.settings.gatheringMap then
            local visibility = gathering:CreateButton('Visibility')
            mapToggle(visibility, 'World map icons', 'mapWorld')
            mapToggle(visibility, 'Minimap icons', 'mapMinimap')
            local spots = gathering:CreateButton('Professions')
            for _, category in ipairs(ns.Sources.Categories()) do
                local kind = category.id
                local key = ns.Sources.ToggleKey(kind)
                if key then mapToggle(spots, category.label .. ' spots', key)
                else
                    spots:CreateCheckbox(category.label .. ' spots', function() return ns.settings.mapProfessions[kind] ~= false end,
                        function() ns.settings.mapProfessions[kind] = ns.settings.mapProfessions[kind] == false; ns.UpdateGathering() end)
                end
            end
            local materials = gathering:CreateButton('Map materials')
            for _, category in ipairs(ns.Sources.Categories()) do
                    local kind = category.id
                    local resources = ns.Sources.Items(kind)
                    local menu = materials:CreateButton(category.label)
                    menu:SetScrollMode(300)
                    local function redraw() ns.Map.Update(); ns.Minimap.Update() end
                    menu:CreateButton('Show all materials', function()
                        for itemID in pairs(resources) do ns.Sources.SetMaterialVisible(itemID, true) end
                        redraw()
                    end)
                    menu:CreateButton('Hide all materials', function()
                        for itemID in pairs(resources) do ns.Sources.SetMaterialVisible(itemID, false) end
                        redraw()
                    end)
                    local ids = {}; for itemID in pairs(resources) do ids[#ids + 1] = itemID end
                    table.sort(ids)
                    for _, itemID in ipairs(ids) do
                        menu:CreateCheckbox(ns.Style.ItemName(itemID), function()
                            return ns.Sources.MaterialVisible(itemID)
                        end, function()
                            ns.Sources.SetMaterialVisible(itemID, not ns.Sources.MaterialVisible(itemID))
                            redraw()
                        end)
                    end
            end
        end
        local reports = root:CreateButton('History and sources')
        reports:CreateButton('Lifetime materials', function() ns.Reports.Show('history') end)
        reports:CreateButton('Observed chances', function() ns.Reports.Show('chances') end)
        reports:CreateButton('Profession actions', function() ns.Reports.Show('actions') end)
        reports:CreateButton('Crafting and cooking', function() ns.Reports.Show('production') end)
        reports:CreateButton('Reagent use estimates', function() ns.Reports.Show('reagentUsage') end)
        reports:CreateButton('Export statistics',function()ns.ExportView.Show()end)
        reports:CreateButton('Plan selected recipe reagents',function()
            if ns.Crafting.selectedID then ns.CraftingView.Show(ns.Crafting.selectedID,1)
            else ns.Print('Select a profession recipe or use /tgf recipe <recipeID> [operations].')end
        end)
        reports:CreateDivider()
        reports:CreateCheckbox('Record lifetime history', function() return ns.settings.recordHistory end, function()
            ns.settings.recordHistory = not ns.settings.recordHistory; ns.UpdateGathering()
        end)
        reports:CreateCheckbox('Record profession actions', function() return ns.settings.recordActions end, function()
            ns.settings.recordActions = not ns.settings.recordActions; ns.UpdateGathering()
        end)
        reports:CreateCheckbox('Record production', function() return ns.settings.recordProduction end, function()
            ns.settings.recordProduction = not ns.settings.recordProduction; ns.UpdateGathering()
        end)
        local production = reports:CreateButton('Production recording by profession')
        for _, module in ipairs(modules) do
            local kind=module.id
            if ns.Production.labels[kind] then
                production:CreateCheckbox('Record ' .. module.label .. ' production',
                    function() return ns.settings.productionProfessions[kind] ~= false end, function()
                        ns.settings.productionProfessions[kind] = ns.settings.productionProfessions[kind] == false
                        ns.UpdateGathering()
                    end)
            end
        end
        local actions = reports:CreateButton('Action recording by profession')
        for _, module in ipairs(modules) do
            local kind=module.id
            if ns.Actions.labels[kind] then
                actions:CreateCheckbox('Record ' .. ns.Actions.labels[kind] .. ' actions',
                    function() return ns.settings.actionProfessions[kind] ~= false end, function()
                        ns.settings.actionProfessions[kind] = ns.settings.actionProfessions[kind] == false
                        ns.UpdateGathering()
                    end)
            end
        end
        toggle(display, 'History in item tooltips', 'historyTooltips')
        toggle(reports, 'Include rare loot', 'recordRare')
        local recording = reports:CreateButton('Recording by profession')
        for _, module in ipairs(modules) do
            if module.kind == 'profession' then
                local kind = module.id
                recording:CreateCheckbox('Record ' .. module.label, function() return ns.settings.historyProfessions[kind] ~= false end, function()
                    ns.settings.historyProfessions[kind] = ns.settings.historyProfessions[kind] == false; ns.UpdateGathering()
                end)
            end
        end
        recording:CreateCheckbox('Ordinary loot sources', function() return ns.settings.historyProfessions.Loot ~= false end, function()
            ns.settings.historyProfessions.Loot = ns.settings.historyProfessions.Loot == false; ns.UpdateGathering()
        end)
        local diagnostics = root:CreateButton('Diagnostics')
        toggle(diagnostics, 'Debug mode', 'debugMode')
    end)
end

function Titan.Initialize()
    local ldb = LibStub and LibStub:GetLibrary('LibDataBroker-1.1', true)
    if not ldb then ns.Print(ns.L.missingTitan); return false end
    Titan.version = C_AddOns.GetAddOnMetadata('TitanGatheredForeverV3', 'Version') or ''
    Titan.broker = ldb:NewDataObject('TitanGatheredForeverV3', {
        type = 'data source', label = ns.L.title, text = Titan.version,
        icon = 'Interface\\AddOns\\TitanGatheredForeverV3\\Artwork\\TitanOre',
        OnEnter = Titan.Show, OnLeave = Titan.Hide,
        OnClick = function(owner, button)
            if button == 'RightButton' then Titan.Menu(owner) end
        end,
        OnMouseWheel = function(owner, delta)
            Titan.page = math.max(1, Titan.page - delta); Titan.Show(owner)
        end,
    })
    return true
end
