local tests, passed = {}, 0
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function equal(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function loadModule(file, ns) assert(loadfile('TitanGatheredForeverV3/' .. file))('TitanGatheredForeverV3', ns) end

test('catalogue matches numeric identity and ignores names', function()
    local ns = {}
    loadModule('Catalog.lua', ns)
    equal(#ns.Catalog.List(), 0)
    ns.Catalog.RegisterModule({ id = 'FirstAid', label = 'First Aid', kind = 'profession',
        items = { [2589] = { professions = { 'First Aid' }, recipes = { 1 }, uses = {} } },
        recipes = { [1] = { profession = 'First Aid' } } })
    ns.Catalog.RegisterModule({ id = 'Tailoring', label = 'Tailoring', kind = 'profession',
        items = { [2589] = { professions = { 'Tailoring' }, recipes = { 2 }, uses = {} } },
        recipes = { [2] = { profession = 'Tailoring' } } })
    ns.Catalog.Rebuild({ categories = {} })
    equal(ns.Catalog.Get(2589), ns.Items[2589])
    equal(ns.Catalog.Get('Linen Cloth'), nil)
    equal(ns.Catalog.Get(999), nil)
    equal(#ns.Catalog.List(), 1)
    equal(#ns.Catalog.Get(2589).recipes, 2)
    equal(#ns.Catalog.Get(2589).professions, 2)
    ns.Catalog.Rebuild({ categories = { FirstAid = false, Tailoring = false } })
    equal(#ns.Catalog.List(), 0)
    ns.Catalog.Rebuild({ categories = { FirstAid = false } })
    equal(#ns.Catalog.List(), 1)
    equal(#ns.Catalog.Get(2589).professions, 1)
end)

local function fixture(saved, guid)
    local state = { clock = 100, accessible = true, bags = { 0, 1, 5 }, tabs = { 6, 7 },
                    slots = { [0] = 2, [1] = 1, [5] = 1, [6] = 2, [7] = 1 },
                    contents = { [0] = { [1] = { itemID = 2589, stackCount = 3 } },
                                 [1] = { { itemID = 2589, stackCount = 2 } },
                                 [5] = { { itemID = 765, stackCount = 4 } },
                                 [6] = { { itemID = 2589, stackCount = 7 } }, [7] = {} } }
    local api = {
        GetBags = function() return state.bags end,
        GetBankTabs = function() return state.tabs end,
        CanViewBank = function() return state.accessible end,
        GetSlots = function(id) return state.slots[id] end,
        GetItem = function(id, slot)
            if state.failBag == id then error('access lost') end
            return state.contents[id] and state.contents[id][slot]
        end,
        Time = function() return state.clock end,
        GetCharacterID = function() return guid or 'Player-1-A' end,
        Build = '70790',
    }
    local ns = {}
    loadModule('Inventory.lua', ns)
    return ns.Inventory.New(api, saved or {}), state, api
end

test('bags aggregate stacks including reagent bag and exclude equipped slots', function()
    local inventory = fixture()
    assert(inventory:RefreshBags())
    equal(inventory:Get(2589).bags, 5)
    equal(inventory:Get(765).bags, 4)
    equal(inventory:Get(999).bags, 0)
end)

test('unseen bank is unknown, never zero or a partial total', function()
    local inventory = fixture()
    inventory:RefreshBags()
    local count = inventory:Get(2589)
    equal(count.bank, nil)
    equal(count.total, nil)
    equal(count.bankState, 'unknown')
    equal(inventory:RefreshBank(), false)
end)

test('complete bank observation produces counts and known zeros', function()
    local inventory = fixture()
    inventory:RefreshBags()
    inventory:SetBankOpen(true)
    assert(inventory:RefreshBank())
    equal(inventory:Get(2589).bank, 7)
    equal(inventory:Get(2589).total, 12)
    equal(inventory:Get(2589).bankState, 'current')
    equal(inventory:Get(999).bank, 0)
    equal(inventory:Get(999).total, 0)
end)

test('bank snapshot survives closure and a fresh session', function()
    local saved = {}
    local inventory = fixture(saved)
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    inventory:SetBankOpen(false)
    equal(inventory:Get(2589).bankState, 'cached')
    local reloaded = fixture(saved)
    equal(reloaded:Get(2589).bank, 7)
    equal(reloaded:Get(2589).bankObservedAt, 100)
    equal(reloaded:Get(2589).bankState, 'cached')
end)

test('snapshots are isolated by player GUID', function()
    local saved = {}
    local first = fixture(saved, 'Player-A')
    first:SetBankOpen(true)
    first:RefreshBank()
    local second = fixture(saved, 'Player-B')
    equal(second:Get(2589).bankState, 'unknown')
end)

test('failed bank scan is atomic and preserves last observation', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    state.clock = 200
    state.contents[6] = {}
    state.failBag = 7
    equal(inventory:RefreshBank(), false)
    equal(inventory:Get(2589).bank, 7)
    equal(inventory:Get(2589).bankObservedAt, 100)
    equal(inventory:Get(2589).bankState, 'cached')
end)

test('empty bank clears previous contents after a complete scan', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    state.contents[6] = {}
    assert(inventory:RefreshBank())
    equal(inventory:Get(2589).bank, 0)
end)

test('transfers between bags and bank preserve total', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBags()
    inventory:RefreshBank()
    state.contents[0][1].stackCount = 1
    state.contents[6][1].stackCount = 9
    inventory:RefreshBags()
    inventory:RefreshBank()
    equal(inventory:Get(2589).bags, 3)
    equal(inventory:Get(2589).bank, 9)
    equal(inventory:Get(2589).total, 12)
end)

test('bank closing before a queued refresh cannot erase cached contents', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    inventory:SetBankOpen(false)
    state.tabs = nil
    state.contents = {}
    equal(inventory:RefreshBank(), false)
    equal(inventory:Get(2589).bank, 7)
end)

test('inaccessible bank is cached even while a different bank UI is open', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    state.accessible = false
    equal(inventory:RefreshBank(), false)
    equal(inventory:Get(2589).bankState, 'cached')
    equal(inventory:Get(2589).bank, 7)
end)

test('invalid item counts abort instead of silently undercounting', function()
    local inventory, state = fixture()
    inventory:RefreshBags()
    state.contents[0][1].stackCount = -1
    equal(inventory:RefreshBags(), false)
    equal(inventory:Get(2589).bags, 5)
end)

test('metadata-only bank response cannot clear a snapshot', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    state.tabs = {}
    equal(inventory:RefreshBank(), false)
    equal(inventory:Get(2589).bank, 7)
end)

test('bank tab list with no initialized slot counts is not an empty-bank observation', function()
    local inventory, state = fixture()
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    state.slots[6], state.slots[7] = 0, 0
    equal(inventory:RefreshBank(), false)
    equal(inventory:Get(2589).bank, 7)
end)

test('bags are unknown before the first complete scan and cached after an interrupted refresh', function()
    local inventory, state = fixture()
    equal(inventory:Get(2589).bags, nil)
    equal(inventory:Get(2589).bagsState, 'unknown')
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    equal(inventory:Get(2589).total, nil)
    inventory:RefreshBags()
    equal(inventory:Get(2589).bagsState, 'current')
    state.failBag = 1
    equal(inventory:RefreshBags(), false)
    equal(inventory:Get(2589).bagsState, 'cached')
end)

test('equipped bank bag with uninitialized capacity cannot erase its last contents', function()
    local inventory, state, api = fixture()
    state.contents[7] = { { itemID = 11137, stackCount = 8 } }
    api.IsBankTabReady = function(_, slots) return slots > 0 end
    inventory:SetBankOpen(true)
    inventory:RefreshBank()
    state.slots[7] = 0
    equal(inventory:RefreshBank(), false)
    equal(inventory:Get(11137).bank, 8)
end)

test('purchased bank bag slots without equipped bags remain valid zero-capacity tabs', function()
    local inventory, state, api = fixture()
    state.slots[7] = 0
    api.IsBankTabReady = function(id, slots) return slots > 0 or id == 7 end
    inventory:SetBankOpen(true)
    assert(inventory:RefreshBank())
    equal(inventory:Get(2589).bank, 7)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
    passed = passed + 1
end
print('PASS ' .. passed .. ' catalogue/inventory tests')
