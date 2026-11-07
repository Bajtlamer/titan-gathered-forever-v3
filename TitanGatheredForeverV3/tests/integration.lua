local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function plain(text) return text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') end
local function contains(lines, needle)
    for _, line in ipairs(lines) do if plain(line):find(needle, 1, true) then return true end end
    return false
end

local function fixture(interface, saved, noBroker, noModules)
    local state = { timers = {}, frames = {}, requested = {}, clock = 100, menu = nil,
                    itemNames = { [2589] = 'Localized Cloth', [765] = 'Localized Herb' },
                    slots = {}, tabs = { { ID = 6 } }, bankReads = 0, skills = {},
                    loot = { { itemID = 2770, sources = { 'GameObject-0-1-2-3-1731-9', 1 } } },
                    bags = { [0] = { { itemID = 2589, stackCount = 3 }, { itemID = 765, stackCount = 2 } },
                             [6] = { { itemID = 2589, stackCount = 7 } } }, bankAccessible = true }
    local function frame(kind, name)
        local f = { scripts = {}, hooks = {}, events = {}, lines = {}, shown = false }
        function f:SetScript(event, fn) self.scripts[event] = fn end
        function f:HookScript(event, fn) self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], fn) end
        function f:Fire(event, ...)
            if self.scripts[event] then self.scripts[event](self, ...) end
            for _, fn in ipairs(self.hooks[event] or {}) do fn(self, ...) end
        end
        function f:RegisterEvent(event) self.events[event] = true end
        function f:UnregisterEvent(event) self.events[event] = nil end
        function f:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
        function f:ClearLines() self.lines = {}; self:Fire('OnTooltipCleared') end
        local tooltipName = name or ('TestTooltip' .. (#state.frames + 1))
        function f:GetName() return tooltipName end
        function f:NumLines() return #self.lines end
        function f:GetWidth() return 360 end
        function f:AddLine(text)
            self.lines[#self.lines + 1] = text
            _G[tooltipName .. 'TextLeft' .. #self.lines] = {}
        end
        function f:AddDoubleLine(left, right) self:AddLine(left .. ' ' .. right) end
        function f:CreateTexture()
            local texture = {}
            for _, method in ipairs({ 'SetColorTexture', 'SetHeight', 'SetWidth', 'SetPoint', 'ClearAllPoints', 'Show', 'Hide' }) do
                texture[method] = function() end
            end
            return texture
        end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false; self:Fire('OnHide') end
        function f:IsShown() return self.shown end
        function f:GetOwner() return self.owner end
        if name then _G[name] = f end
        state.frames[#state.frames + 1] = f
        return f
    end
    _G.CreateFrame, _G.UIParent = frame, {}
    _G.TitanGatheredForeverV3DB = saved
    _G.SlashCmdList = {}
    _G.GetBuildInfo = function() return '1.60.1', '70790', 'Nov 3 2026', interface or 16001 end
    _G.UnitGUID = function() return 'Player-1-A' end
    _G.time = function() return state.clock end
    _G.GetTime = function() return state.clock end
    _G.IsFishingLoot = function() return state.fishing == true end
    _G.IsInInstance = function() return state.inInstance == true, state.instanceType or 'none' end
    _G.date = function(_, timestamp) return 'observed-' .. timestamp end
    _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    _G.Enum = { BankType = { Character = 0 }, TooltipDataType = { Item = 0 }, BagIndex = { Characterbanktab = -2 } }
    _G.issecretvalue = function(value) return value == state.secret and state.secret ~= nil end
    _G.C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end }
    _G.C_Container = {
        GetContainerNumSlots = function(id)
            if state.slots[id] ~= nil then return state.slots[id] end
            return id == 0 and 2 or 1
        end,
        GetContainerItemInfo = function(id, slot) return state.bags[id] and state.bags[id][slot] end,
    }
    _G.C_Bank = {
        CanViewBank = function(bankType) eq(bankType, 0); return state.bankAccessible end,
        FetchPurchasedBankTabData = function(bankType)
            eq(bankType, 0); state.bankReads = state.bankReads + 1; return state.tabs
        end,
    }
    _G.C_Item = {
        GetItemInfo = function(id) return state.itemNames[id], nil, 2 end,
        RequestLoadItemDataByID = function(id) state.requested[id] = (state.requested[id] or 0) + 1 end,
        GetItemIconByID = function(id) return id end,
    }
    _G.ITEM_QUALITY_COLORS = { [2] = { hex = 'ff1eff00' } }
    _G.C_SkillInfo = { GetSkillLineInfoByID = function(id) return state.skills[id] end }
    _G.WorldMapFrame = nil
    _G.C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.6 end } end,
    }
    _G.GetNumLootItems = function() return #state.loot end
    _G.GetLootSlotLink = function(index) return state.loot[index] and state.loot[index].itemID and 'item:' .. state.loot[index].itemID end
    _G.GetLootSlotInfo = function(index)
        local item = state.loot[index]
        return nil, nil, item.quantity or 1, nil, item.quality or 1
    end
    _G.GetLootSourceInfo = function(index) return unpack(state.loot[index].sources) end
    _G.C_Spell = { GetSpellInfo = function(id) return { name = 'Recipe ' .. id } end }
    _G.C_AddOns = { GetAddOnMetadata = function(_, key) return key == 'Version' and '0.1.0-alpha' or nil end }
    _G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) eq(kind, 0); state.post = fn end }
    _G.MenuUtil = { CreateContextMenu = function(_, fn)
        local root = { checkboxes = {}, radios = {}, titles = {}, buttons = {}, submenus = {}, paths = {}, path = {} }
        function root:CreateTitle(title) self.titles[#self.titles + 1] = title end
        function root:CreateDivider() end
        function root:SetScrollMode() end
        function root:CreateButton(label, callback)
            root.buttons[plain(label)] = callback; root.button = callback
            root.buttons[table.concat(self.path, '/') .. '/' .. plain(label)] = callback
            if not callback then root.submenus[plain(label)] = true end
            local path = {}; for i, part in ipairs(self.path) do path[i] = part end
            path[#path + 1] = plain(label)
            return setmetatable({ path = path }, { __index = root })
        end
        function root:CreateCheckbox(label, selected, callback)
            root.checkboxes[plain(label)] = { selected = selected, callback = callback }
            root.paths[plain(label)] = table.concat(self.path, '/')
            return self
        end
        function root:CreateRadio(label, selected, callback)
            self.radios[label] = { selected = selected, callback = callback }; return self
        end
        fn({}, root); state.menu = root
    end }
    _G.LibStub = { GetLibrary = function(_, name)
        eq(name, 'LibDataBroker-1.1')
        if noBroker then return nil end
        return { NewDataObject = function(_, name, data) state.broker = data; state.brokerName = name; return data end }
    end }
    state.messages = {}
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
        state.message = message; state.messages[#state.messages + 1] = message
    end }
    local ns = {}
    for _, path in ipairs({ 'Localization/enUS.lua', 'Style.lua', 'Data/Metadata.lua', 'Catalog.lua',
                            'Settings.lua', 'Professions.lua', 'Inventory.lua', 'Gathering.lua', 'History.lua', 'Observations.lua', 'Sources.lua', 'PinStyle.lua', 'Map.lua', 'Minimap.lua',
                            'Tooltips.lua', 'Reports.lua', 'Titan.lua', 'Core.lua' }) do
        assert(loadfile('TitanGatheredForeverV3/' .. path))('TitanGatheredForeverV3', ns)
    end
    -- Keep integration scenarios small; the generated data is validated separately.
    local function module(id, label, items, recipes, kind)
        ns.Catalog.RegisterModule({ id = id, label = label, kind = kind or 'profession', items = items, recipes = recipes })
    end
    if not noModules then
    module('FirstAid', 'First Aid', {
        [2589] = { professions = { 'First Aid' }, recipes = { 1 }, uses = {} },
    }, { [1] = { profession = 'First Aid' } })
    module('Tailoring', 'Tailoring', {
        [2589] = { professions = { 'Tailoring' }, recipes = { 2 }, uses = {} },
        [4306] = { professions = { 'Tailoring' }, recipes = { 5 }, uses = {} },
    }, { [2] = { profession = 'Tailoring' }, [5] = { profession = 'Tailoring' } })
    module('Alchemy', 'Alchemy', {
        [765] = { professions = { 'Alchemy' }, recipes = { 3 }, uses = {} },
    }, { [3] = { profession = 'Alchemy' } })
    module('Enchanting', 'Enchanting', {
        [249391] = { professions = { 'Enchanting' }, recipes = { 4 }, uses = {} },
    }, { [4] = { profession = 'Enchanting' } })
    module('Auction', 'Auction items', {
        [264019] = { professions = {}, recipes = {}, uses = {
            { kind = 'auction', reason = 'Transferable crafting order.' },
        } },
    }, {}, 'auction')
    end
    function state:Flush()
        local pending = self.timers; self.timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
    function state:Event(event, ...)
        for _, f in ipairs(self.frames) do if f.events[event] then f:Fire('OnEvent', event, ...) end end
    end
    function state:Start()
        self:Event('ADDON_LOADED', 'TitanGatheredForeverV3')
        self:Event('PLAYER_LOGIN')
        self:Flush()
    end
    return state, ns
end

test('initializes a Forever-only broker after player identity is ready', function()
    local s, ns = fixture(); s:Start()
    eq(s.brokerName, 'TitanGatheredForeverV3')
    eq(ns.inventory:Get(2589).bags, 3)
    eq(ns.inventory:Get(2589).bankState, 'unknown')
    eq(s.broker.text, '0.1.0-alpha')
end)

test('rejects other client interfaces', function()
    local s, ns = fixture(90001); s:Start()
    eq(s.broker, nil)
    eq(ns.inventory, nil)
    assert(s.message:find('Forever', 1, true))
end)

test('missing broker support produces a useful diagnostic', function()
    local s = fixture(nil, nil, true); s:Start()
    assert(s.message:find('Titan', 1, true))
end)

test('inventory events coalesce and bank closure preserves snapshots', function()
    local s, ns = fixture(); s:Start()
    s:Event('BANKFRAME_OPENED'); s:Event('BAG_UPDATE_DELAYED'); s:Event('PLAYERBANKSLOTS_CHANGED')
    eq(#s.timers, 1)
    s:Flush(); eq(ns.inventory:Get(2589).total, 10)
    s:Event('BANKFRAME_CLOSED'); s:Flush()
    eq(ns.inventory:Get(2589).bankState, 'cached')
    s:Event('BANKFRAME_OPENED'); s:Event('BANKFRAME_CLOSED'); s:Flush()
    eq(ns.inventory:Get(2589).bank, 7)
end)

test('unvisited bank displays zero and total includes carried items without exposing scan status', function()
    local s, ns = fixture(); s:Start()
    local tip = CreateFrame('GameTooltip')
    s.post(tip, { id = 2589 })
    assert(contains(tip.lines, 'First Aid'))
    assert(contains(tip.lines, 'Tailoring'))
    assert(contains(tip.lines, 'Bags: 3'))
    assert(contains(tip.lines, 'Bank: 0'))
    assert(contains(tip.lines, 'Total: 3'))
    assert(not contains(tip.lines, 'unknown'))
    s.broker.OnEnter({})
    assert(contains(ns.Titan.tooltip.lines, '3 / 0 / 3'))
    assert(not contains(ns.Titan.tooltip.lines, 'unknown'))
    assert(not contains(ns.Titan.tooltip.lines, 'Visit your personal bank'))
    eq(ns.inventory:Get(2589).bankState, 'unknown')
    eq(ns.inventory.character.bank, nil)
end)

test('repeated callbacks append once and tooltip recycling resets the section', function()
    local s = fixture(); s:Start()
    local tip = CreateFrame('GameTooltip')
    s.post(tip, { id = 2589 }); local size = #tip.lines
    s.post(tip, { id = 2589 }); eq(#tip.lines, size)
    tip:ClearLines(); s.post(tip, { id = 2589 }); eq(#tip.lines, size)
end)

test('unavailable initial bag and bank scans render zero without saving fabricated observations', function()
    local s, ns = fixture(); s.slots[0] = 0; s:Start()
    local tip = CreateFrame('GameTooltip'); s.post(tip, { id = 2589 })
    assert(contains(tip.lines, 'Bags: 0'))
    assert(contains(tip.lines, 'Bank: 0'))
    assert(contains(tip.lines, 'Total: 0'))
    assert(not contains(tip.lines, 'unknown'))
    ns.settings.showZero = true; s.broker.OnEnter({})
    assert(contains(ns.Titan.tooltip.lines, '0 / 0 / 0'))
    assert(not contains(ns.Titan.tooltip.lines, 'unknown'))
    eq(ns.inventory.bags, nil); eq(ns.inventory.character.bank, nil)
end)

test('unknown items and protected IDs do not alter the item tooltip', function()
    local s = fixture(); s:Start()
    local tip = CreateFrame('GameTooltip')
    s.post(tip, { id = 99999 }); eq(#tip.lines, 0)
    s.secret = 2589; s.post(tip, { id = 2589 }); eq(#tip.lines, 0)
end)

test('metadata requests are deduplicated and successful item loading refreshes names', function()
    local s, ns = fixture(); s:Start()
    local first = ns.ItemName(249391); eq(first, 'Item 249391 (loading)')
    ns.ItemName(249391); eq(s.requested[249391], 1)
    s.itemNames[249391] = 'Localized Pyrite'
    s:Event('ITEM_DATA_LOAD_RESULT', 249391, true); s:Flush()
    eq(ns.ItemName(249391), 'Localized Pyrite')
end)

test('right-click menu toggles actual settings', function()
    local s, ns = fixture(); s:Start()
    s.broker.OnClick({}, 'RightButton')
    local toggle = s.menu.checkboxes['Show items with zero counts']
    eq(toggle.selected(), false); toggle.callback(); eq(ns.settings.showZero, true)
    local category = s.menu.checkboxes['Tailoring']
    eq(category.selected(), true); category.callback(); eq(ns.settings.categories.Tailoring, false)
    eq(ns.Catalog.Get(4306), nil)
    assert(ns.Catalog.Get(2589))
    eq(s.menu.checkboxes.Other, nil)
    assert(s.menu.checkboxes['Auction items'])
end)

test('private Titan summary labels all counts and does not repeat shared reagents', function()
    local s, ns = fixture(); s:Start()
    s:Event('BANKFRAME_OPENED'); s:Flush()
    s.broker.OnEnter({})
    local tip = ns.Titan.tooltip
    assert(contains(tip.lines, 'Bags / Bank / Total'))
    local occurrences = 0
    for _, line in ipairs(tip.lines) do
        if line:find('Localized Cloth', 1, true) then occurrences = occurrences + 1 end
    end
    eq(occurrences, 1)
    assert(contains(tip.lines, '3 / 7 / 10'))
    s.broker.OnLeave(); eq(tip:IsShown(), false)
end)

test('settings and bank snapshots survive reload without legacy variables', function()
    local s, ns = fixture(); s:Start()
    ns.settings.showZero = true
    s:Event('BANKFRAME_OPENED'); s:Flush()
    local saved = TitanGatheredForeverV3DB
    ns.settings.showBank, ns.settings.showTotal = false, false
    local nextState, nextNS = fixture(nil, saved); nextState:Start()
    eq(nextNS.settings.showZero, true)
    eq(nextNS.settings.showBank, false)
    eq(nextNS.settings.showTotal, nil)
    eq(nextNS.inventory:Get(2589).bank, 7)
    eq(nextNS.inventory:Get(2589).bankState, 'cached')
end)

test('core-only startup shows the version and explains how to enable profession addons', function()
    local s, ns = fixture(nil, nil, nil, true); s:Start()
    eq(s.broker.text, '0.1.0-alpha')
    eq(next(ns.Items), nil)
    eq(next(ns.Recipes), nil)
    s.broker.OnClick({}, 'RightButton')
    assert(contains(s.menu.titles, 'Enable a Gathered profession addon'))
    eq(s.menu.checkboxes.Other, nil)
    eq(s.menu.checkboxes.Alchemy, nil)
end)

test('Forever adapter allows unused purchased bag slots and rejects unreadable placed bags', function()
    local s, ns = fixture(); s:Start()
    s.tabs = { { ID = 6 }, { ID = 7 } }; s.slots[7] = 0
    s:Event('BANKFRAME_OPENED'); s:Flush()
    eq(ns.inventory:Get(2589).bankState, 'current')
    eq(ns.inventory:Get(2589).bank, 7)
    -- Slot 2 in the character-bank bag container represents the additional bag.
    s.bags[-2] = { [2] = { itemID = 999, stackCount = 1 } }
    s.bags[6][1].stackCount = 1
    s:Event('BAG_UPDATE_DELAYED'); s:Flush()
    eq(ns.inventory:Get(2589).bankState, 'cached')
    eq(ns.inventory:Get(2589).bank, 7)
end)

test('empty scanned bags and bank display zero, including the summary', function()
    local s, ns = fixture(); s.bags = {}; s:Start()
    ns.settings.showZero = true
    s:Event('BANKFRAME_OPENED'); s:Flush()
    local tip = CreateFrame('GameTooltip'); s.post(tip, { id = 2589 })
    assert(contains(tip.lines, 'Bags: 0'))
    assert(contains(tip.lines, 'Bank: 0'))
    assert(contains(tip.lines, 'Total: 0'))
    s.broker.OnEnter({})
    assert(contains(ns.Titan.tooltip.lines, '0 / 0 / 0'))
    eq(s.broker.text, '0.1.0-alpha')
end)

test('bags-only configuration hides bank, sum, timestamps and bank-only rows', function()
    local s, ns = fixture(); s.bags[0] = {}; s:Start()
    s:Event('BANKFRAME_OPENED'); s:Flush()
    ns.settings.showBank = false
    local tip = CreateFrame('GameTooltip'); s.post(tip, { id = 2589 })
    assert(contains(tip.lines, 'Bags: 0'))
    assert(not contains(tip.lines, 'Bank:'))
    assert(not contains(tip.lines, 'Total:'))
    assert(not contains(tip.lines, 'Bank last observed'))
    eq(#ns.Titan.Rows(), 0)
    ns.settings.showZero = true
    s.broker.OnEnter({})
    assert(contains(ns.Titan.tooltip.lines, 'Material Bags'))
    assert(not contains(ns.Titan.tooltip.lines, 'Bank'))
    assert(not contains(ns.Titan.tooltip.lines, 'Total'))
end)

test('total always follows bank and has no independent configuration toggle', function()
    local s, ns = fixture(); s:Start()
    ns.settings.showTotal = false
    local tip = CreateFrame('GameTooltip'); s.post(tip, { id = 2589 })
    assert(contains(tip.lines, 'Bank: 0'))
    assert(contains(tip.lines, 'Total: 3'))
    s.broker.OnEnter({})
    assert(contains(ns.Titan.tooltip.lines, 'Bags / Bank'))
    assert(contains(ns.Titan.tooltip.lines, ' / Total'))
    s.broker.OnClick({}, 'RightButton')
    eq(s.menu.checkboxes['Show total counts'], nil)
end)

test('turning bank counts off stops scans and turning them on refreshes the open bank', function()
    local s, ns = fixture(); s:Start()
    s:Event('BANKFRAME_OPENED'); s:Flush()
    s.broker.OnClick({}, 'RightButton')
    s.menu.checkboxes['Show bank counts'].callback(); s:Flush()
    eq(ns.settings.showBank, false)
    local reads = s.bankReads
    s:Event('BAG_UPDATE_DELAYED'); s:Event('PLAYERBANKSLOTS_CHANGED'); s:Flush()
    eq(s.bankReads, reads)
    s.broker.OnClick({}, 'RightButton')
    s.menu.checkboxes['Show bank counts'].callback(); s:Flush()
    eq(ns.settings.showBank, true)
    assert(s.bankReads > reads)
end)

test('summary restores learned skills, rarity names and colored section separators', function()
    local s, ns = fixture(); s:Start()
    s.skills[186] = { name = 'Mining', rank = 75, maxRank = 150 }
    s.skills[185] = { name = 'Cooking', rank = 1, maxRank = 75 }
    s:Event('SKILL_LINES_CHANGED'); s:Flush()
    s.broker.OnEnter({})
    assert(contains(ns.Titan.tooltip.lines, 'Mining 75/150'))
    assert(contains(ns.Titan.tooltip.lines, 'Cooking 1/75'))
    assert(ns.Titan.tooltip.tgForeverRules and #ns.Titan.tooltip.tgForeverRules > 0)
    local colored = false
    for _, line in ipairs(ns.Titan.tooltip.lines) do
        if line:find('|cff1eff00Localized Cloth|r', 1, true) then colored = true end
    end
    assert(colored, 'Material rarity color missing')
end)

test('summary separates skills from material columns and omits the redundant addon header', function()
    local s, ns = fixture(); s:Start()
    s.skills[186] = { name = 'Mining', rank = 75, maxRank = 150 }
    s.broker.OnEnter({})
    local lines = ns.Titan.tooltip.lines
    local heading
    for index, line in ipairs(lines) do
        assert(not plain(line):find(ns.L.title, 1, true), 'Redundant addon header remains')
        if plain(line):find('Material Bags', 1, true) then heading = index end
    end
    assert(heading and lines[heading - 1] == ' ', 'Missing rule between skills and material columns')
end)

test('item tooltip distinguishes labels, professions, recipe names and explanatory notes', function()
    local s, ns = fixture(); s:Start()
    local tip = CreateFrame('GameTooltip'); s.post(tip, { id = 2589 })
    assert(not contains(tip.lines, ns.L.title), 'Redundant addon header remains')
    assert(contains(tip.lines, 'Reagent for First Aid'))
    local text = table.concat(tip.lines, '\n')
    assert(text:find('|cffeda55fReagent for |r', 1, true), 'Label color missing')
    assert(text:find('|cff53c9ffFirst Aid|r', 1, true), 'Profession color missing')
    assert(text:find('|cffb48cfaRecipe 1|r', 1, true), 'Recipe name color missing')
    tip:ClearLines(); s.post(tip, { id = 264019 })
    assert(table.concat(tip.lines, '\n'):find('|cff8fbaaaTransferable crafting order.|r', 1, true), 'Use-note color missing')
end)

test('bank scan retries delayed tab data and establishes zero for absent items', function()
    local s, ns = fixture(); s:Start()
    s.tabs = nil
    s:Event('BANKFRAME_OPENED'); s:Flush()
    eq(ns.inventory:Get(765).bankState, 'unknown')
    assert(#s.timers > 0, 'No readiness retry was scheduled')
    s.tabs = { { ID = 6 } }
    s:Flush(); s:Flush()
    eq(ns.inventory:Get(765).bank, 0)
    eq(ns.inventory:Get(765).total, 2)
end)

test('bank diagnostics identify the container that prevents a complete observation', function()
    local s, ns = fixture(); s:Start()
    s.slots[6] = 0
    s:Event('BANKFRAME_OPENED'); s:Flush()
    eq(ns.inventory.lastBankStatus, 'bank container 6 is not ready (0 slots)')
    SlashCmdList.TITANGATHEREDFOREVERV3('status')
    assert(contains(s.messages, 'bank container 6'))
end)

test('bank readiness retries are bounded and stop after closing the bank', function()
    local s, ns = fixture(); s:Start()
    s.tabs = nil; s:Event('BANKFRAME_OPENED'); s:Flush()
    for _ = 1, 20 do s:Flush() end
    eq(#s.timers, 0)
    assert(ns.inventory.lastBankStatus)
    s:Event('BANKFRAME_OPENED'); s:Flush()
    s:Event('BANKFRAME_CLOSED')
    local reads = s.bankReads
    for _ = 1, 20 do s:Flush() end
    eq(s.bankReads, reads)
end)

test('gathering runtime wires confirmed loot and disables recording through the master switch', function()
    local s, ns = fixture()
    ns.Catalog.RegisterModule({ id = 'Mining', label = 'Mining', kind = 'profession',
        items = { [2770] = { professions = { 'Blacksmithing' }, recipes = {}, uses = {} } },
        recipes = {}, gatheringResources = { [2770] = 0 } })
    s:Start()
    s:Event('UNIT_SPELLCAST_START', 'player', 'cast1', 2575)
    s:Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 2575)
    s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_CLOSED')
    eq(#ns.gathering:List(1), 1)
    s.broker.OnClick({}, 'RightButton')
    assert(s.menu.checkboxes['Mining spots'])
    s.menu.checkboxes['Enable gathering map'].callback()
    eq(ns.settings.gatheringMap, false)
    eq(ns.eventFrame.events.UNIT_SPELLCAST_SUCCEEDED, true) -- History remains active with map recording off.
    eq(#ns.gathering:List(1), 0)
    s.broker.OnClick({}, 'RightButton')
    s.menu.checkboxes['Enable gathering map'].callback()
    eq(#ns.gathering:List(1), 1)
end)

test('world map and minimap visibility are independent saved preferences', function()
    local s, ns = fixture(); s:Start()
    s.broker.OnClick({}, 'RightButton')
    eq(s.menu.checkboxes['World map icons'].selected(), true)
    eq(s.menu.checkboxes['Minimap icons'].selected(), true)
    s.menu.checkboxes['World map icons'].callback()
    eq(ns.settings.mapWorld, false); eq(ns.settings.mapMinimap, true)
    s, ns = fixture(nil, TitanGatheredForeverV3DB); s:Start()
    eq(ns.settings.mapWorld, false); eq(ns.settings.mapMinimap, true)
    s.broker.OnClick({}, 'RightButton'); s.menu.checkboxes['Minimap icons'].callback()
    eq(ns.settings.mapMinimap, false); eq(ns.settings.gatheringMap, true)
end)

test('skinning-only addon records corpse materials and exposes persistent per-material map filters', function()
    local function skinFixture(saved)
        local s, ns = fixture(nil, saved, nil, true)
        s.itemNames[2318], s.itemNames[783] = 'Light Leather', 'Light Hide'
        ns.Catalog.RegisterModule({ id = 'Skinning', label = 'Skinning', kind = 'profession',
            items = { [2318] = { professions = { 'Leatherworking' }, recipes = {}, uses = {} },
                      [783] = { professions = { 'Leatherworking' }, recipes = {}, uses = {} } },
            recipes = {}, gatheringResources = { [2318] = 0, [783] = 0 } })
        s:Start(); return s, ns
    end
    local s, ns = skinFixture()
    eq(ns.GatheringEnabled('Skinning'), true)
    s.loot = { { itemID = 2318, sources = { 'Creature-0-1-2-3-2958-9', 1 } },
               { itemID = 783, sources = { 'Creature-0-1-2-3-2958-9', 1 } } }
    s:Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'skin1', 8613)
    s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_SLOT_CLEARED', 2); s:Event('LOOT_CLOSED')
    eq(#ns.gathering:List(1), 2)
    s.broker.OnClick({}, 'RightButton')
    assert(s.menu.checkboxes['Skinning spots'])
    s.menu.checkboxes['Light Leather'].callback()
    eq(ns.settings.mapItems.Skinning[2318], false)
    eq(#ns.gathering:List(1), 1); eq(#ns.db.gathering.maps[1], 2)
    eq(ns.GatheringEnabled('Skinning'), true)
    s, ns = skinFixture(TitanGatheredForeverV3DB)
    eq(ns.settings.mapItems.Skinning[2318], false); eq(#ns.gathering:List(1), 1)
    s.broker.OnClick({}, 'RightButton'); s.menu.buttons['Gathering map/Map materials/Skinning/Show all materials']()
    eq(#ns.gathering:List(1), 2)
    s.menu.buttons['Gathering map/Map materials/Skinning/Hide all materials'](); eq(#ns.gathering:List(1), 0)
    eq(#ns.db.gathering.maps[1], 2)
    s.menu.buttons['Gathering map/Map materials/Skinning/Show all materials'](); s.menu.checkboxes['Skinning spots'].callback()
    eq(#ns.gathering:List(1), 0); eq(ns.eventFrame.events.UNIT_SPELLCAST_SUCCEEDED, true) -- History remains active with map recording off.
end)

test('runtime rejects dungeon and raid observations and clears pending gathers on zone transitions', function()
    local s, ns = fixture()
    ns.Catalog.RegisterModule({ id = 'Mining', label = 'Mining', kind = 'profession',
        items = { [2770] = { professions = {}, recipes = {}, uses = {} } },
        recipes = {}, gatheringResources = { [2770] = 0 } })
    s:Start()
    for _, kind in ipairs({ 'party', 'raid', 'pvp' }) do
        s.inInstance, s.instanceType = true, kind
        s:Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'mine1', 2575)
        s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_CLOSED')
        eq(#ns.gathering:List(1), 0)
    end
    s.inInstance, s.instanceType = false, 'none'
    s:Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'mine2', 2575)
    s:Event('PLAYER_ENTERING_WORLD')
    s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_CLOSED')
    eq(#ns.gathering:List(1), 0)
end)

test('debug mode defaults off, gates messages immediately and persists through reload', function()
    local s, ns = fixture(); s:Start()
    eq(ns.settings.debugMode, false)
    eq(#s.messages, 0)
    ns.Debug('hidden debug message'); eq(#s.messages, 0)
    s.broker.OnClick({}, 'RightButton')
    local toggle = assert(s.menu.checkboxes['Debug mode'], 'Debug checkbox missing')
    eq(toggle.selected(), false); toggle.callback(); eq(ns.settings.debugMode, true)
    ns.Debug('visible debug message'); eq(s.message, 'visible debug message')
    local saved = TitanGatheredForeverV3DB
    s, ns = fixture(nil, saved); s:Start(); eq(ns.settings.debugMode, true)
    s.broker.OnClick({}, 'RightButton'); s.menu.checkboxes['Debug mode'].callback()
    local before = #s.messages
    ns.Debug('hidden again'); eq(#s.messages, before)
    s, ns = fixture(nil, TitanGatheredForeverV3DB); s:Start(); eq(ns.settings.debugMode, false)
end)

test('explicit status works with debug disabled while normal commands stay quiet', function()
    local s, ns = fixture(); s:Start()
    SlashCmdList.TITANGATHEREDFOREVERV3('refresh'); s:Flush(); eq(#s.messages, 0)
    SlashCmdList.TITANGATHEREDFOREVERV3('')
    eq(#s.messages, 1); assert(s.message:find('/tgf status', 1, true))
    local before = #s.messages
    SlashCmdList.TITANGATHEREDFOREVERV3('status')
    eq(#s.messages, before + 4); assert(s.message:find('Gathering map:', 1, true))
    ns.settings.debugMode = true
    before = #s.messages; SlashCmdList.TITANGATHEREDFOREVERV3('')
    eq(#s.messages, before + 4)
end)

test('configuration checkboxes are grouped in submenus', function()
    local s, ns = fixture()
    ns.Catalog.RegisterModule({ id = 'Mining', label = 'Mining', kind = 'profession',
        items = { [2770] = { professions = { 'Blacksmithing' }, recipes = {}, uses = {} } },
        recipes = {}, gatheringResources = { [2770] = 0 } })
    s:Start(); s.broker.OnClick({}, 'RightButton')
    for label, path in pairs(s.menu.paths) do assert(path ~= '', 'top-level checkbox: ' .. label) end
    eq(s.menu.paths['Show items with zero counts'], 'Display')
    eq(s.menu.paths['Show bank counts'], 'Display')
    eq(s.menu.paths['Tailoring'], 'Professions')
    eq(s.menu.paths['Auction items'], 'Additional items')
    eq(s.menu.paths['Enable gathering map'], 'Gathering map')
    eq(s.menu.paths['World map icons'], 'Gathering map/Visibility')
    eq(s.menu.paths['Mining spots'], 'Gathering map/Professions')
    eq(s.menu.paths[plain(ns.Style.ItemName(2770))], 'Gathering map/Map materials/Mining')
    eq(s.menu.paths['Debug mode'], 'Diagnostics')
end)

test('map clear menu requires confirmation and captures the displayed map', function()
    local s, ns = fixture(); s:Start()
    local function node(mapID, kind)
        return { mapID = mapID, kind = kind, itemID = 2770, x = .4, y = .6, count = 1, lastSeen = 100 }
    end
    ns.gathering.saved.maps = { [1] = { node(1, 'Mining') },
        [2] = { node(2, 'Mining'), node(2, 'Herbs') } }
    local world = { mapID = 2, GetMapID = function(self) return self.mapID end }
    ns.Titan.ClearSpotsMenu({}, world)
    eq(#ns.gathering.saved.maps[2], 2)
    assert(s.menu.submenus['Clear Mining spots (1)'])
    s.menu.buttons['Confirm: clear 1 Mining spots']()
    eq(#ns.gathering.saved.maps[2], 1); eq(#ns.gathering.saved.maps[1], 1)
    ns.Titan.ClearSpotsMenu({}, world)
    world.mapID = 1
    s.menu.buttons['Confirm: clear 1 Herbalism spots']()
    eq(#ns.gathering.saved.maps[2], 1)
end)

test('money sources enter observed rates and instance history never creates map spots', function()
    local s, ns = fixture(); s:Start()
    s.loot = { { itemID = 2589, sources = { 'Creature-0-1-2-3-123-1', 2 } } }
    s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_CLOSED')
    s.loot = { { sources = { 'Creature-0-1-2-3-123-2', 10 } } }
    s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_CLOSED')
    local character = UnitGUID('player')
    eq(ns.history:Rates(character, 2589)[1].trials, 2)
    eq(ns.history:Rates(character, 2589)[1].percent, 50)
    s.inInstance, s.instanceType = true, 'party'
    local spots = #ns.db.gathering.maps[1]
    s.loot = { { itemID = 2589, sources = { 'Creature-0-1-2-3-123-3', 1 } } }
    s:Event('LOOT_READY'); s:Event('LOOT_SLOT_CLEARED', 1); s:Event('LOOT_CLOSED')
    eq(ns.history:Total(character, 2589), 3)
    eq(#ns.db.gathering.maps[1], spots)
    eq(#ns.history:Rates(character, 2589), 2) -- Instance outcomes are a separate source group.
end)

test('rare gathering outputs appear in lifetime, recipe-style tooltips and material controls', function()
    local s, ns = fixture()
    ns.Catalog.RegisterModule({ id='Mining',label='Mining',kind='profession',
        items={[2770]={professions={},recipes={},uses={}}},recipes={},gatheringResources={[2770]=0} })
    s:Start()
    local guid='GameObject-0-1-2-3-1731-1'
    s.loot={{itemID=2770,sources={guid,3}},{itemID=1210,sources={guid,1}}}
    s:Event('UNIT_SPELLCAST_SUCCEEDED','player','m1',2575)
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_SLOT_CLEARED',2);s:Event('LOOT_CLOSED')
    s.loot={{itemID=2770,sources={guid,2}}}
    s:Event('UNIT_SPELLCAST_SUCCEEDED','player','m2',2575)
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    eq(ns.history:Total(UnitGUID('player'),2770),5)
    local tip=CreateFrame('GameTooltip');s.post(tip,{id=1210})
    assert(contains(tip.lines,'Lifetime obtained: 1'));assert(contains(tip.lines,'50.0% (1 / 2 samples)'))
    assert(contains(tip.lines,'Bags: 0'))
    s.broker.OnClick({},'RightButton')
    assert(ns.Sources.Items('Mining')[1210])
    ns.gathering:Clear(1,'Mining');eq(ns.history:Total(UnitGUID('player'),1210),1)
    ns.settings.historyTooltips=false;tip:ClearLines();s.post(tip,{id=1210})
    assert(not contains(tip.lines,'Lifetime obtained'))
end)
test('ordinary material sources map consuming professions and history persists with maps disabled', function()
    local s, ns=fixture();s:Start()
    local guid='Creature-0-1-2-3-123-55'
    s.loot={{itemID=2589,sources={guid,2}}}
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    eq(ns.history:Total(UnitGUID('player'),2589),2)
    assert(ns.gathering:Count(1,'Tailoring')>0);assert(ns.gathering:Count(1,'FirstAid')>0)
    ns.settings.gatheringMap=false;ns.UpdateGathering()
    s.loot={{itemID=2589,sources={'Creature-0-1-2-3-123-56',1}}}
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    eq(ns.history:Total(UnitGUID('player'),2589),3);eq(ns.gathering:Count(1,'Tailoring'),1)
    ns.settings.recordHistory=false;ns.UpdateGathering();eq(ns.eventFrame.events.LOOT_READY,nil)
end)
test('fishing catches use a zone denominator and never include purchasing events',function()
    local s,ns=fixture()
    ns.Catalog.RegisterModule({id='Fishing',label='Fishing',kind='profession',items={},recipes={}})
    s:Start();s.fishing=true
    s.loot={{itemID=6291,sources={'GameObject-0-1-2-3-35591-1',1}}}
    s:Event('UNIT_SPELLCAST_SUCCEEDED','player','f1',7620)
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    s.loot={{itemID=45190,sources={'GameObject-0-1-2-3-35591-2',1}}}
    s:Event('UNIT_SPELLCAST_SUCCEEDED','player','f2',7620)
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    local rates=ns.history:Rates(UnitGUID('player'),6291);eq(rates[1].percent,50)
    eq(ns.gathering:Count(1,'Fishing'),2)
    local quantity=ns.history:Total(UnitGUID('player'),6291)
    s:Event('BAG_UPDATE_DELAYED');s:Flush();eq(ns.history:Total(UnitGUID('player'),6291),quantity)
end)

test('recording eligibility snapshots exclude disabled profession samples for rare known items',function()
    local s,ns=fixture()
    ns.Catalog.RegisterModule({id='Mining',label='Mining',kind='profession',items={[1210]={professions={},recipes={},uses={}}},recipes={}})
    s:Start();ns.settings.historyProfessions.Mining=false;ns.UpdateGathering()
    s.loot={{itemID=1210,quality=3,sources={'Creature-0-1-2-3-123-81',1}}}
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    ns.settings.historyProfessions.Mining=true;ns.UpdateGathering()
    s.loot={{itemID=1210,quality=3,sources={'Creature-0-1-2-3-123-82',1}}}
    s:Event('LOOT_READY');s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    eq(ns.history:Rates(UnitGUID('player'),1210)[1].trials,1)
end)
test('map visibility changes preserve an active history observation',function()
    local s,ns=fixture()
    ns.Catalog.RegisterModule({id='Mining',label='Mining',kind='profession',items={[2770]={professions={},recipes={},uses={}}},recipes={}})
    s:Start();s.loot={{itemID=2770,sources={'GameObject-0-1-2-3-1731-81',1}}}
    s:Event('UNIT_SPELLCAST_SUCCEEDED','player','mine',2575);s:Event('LOOT_READY')
    ns.settings.mapWorld=false;ns.UpdateGathering()
    s:Event('LOOT_SLOT_CLEARED',1);s:Event('LOOT_CLOSED')
    eq(ns.history:Total(UnitGUID('player'),2770),1)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS ' .. #tests .. ' host/tooltip integration tests')
