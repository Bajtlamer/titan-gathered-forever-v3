local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh(options)
    options = options or {}
    local ns = { IsPublic = function() return true end, Catalog = { modules = {} } }
    ns.Catalog.Hidden = function(kind) return options.hidden and options.hidden[kind] or false end
    ns.AuctionScan = { Price = function(id) return options.auction and options.auction[id] end }
    ns.NpcSources = { Coin = function(copper) return copper .. 'c' end, VendorsFor = function() return {} end }
    C_Item = { GetItemInfo = function(id)
        local price = options.vendor and options.vendor[id]
        return 'Name', 'link', 1, 1, 1, 'type', 'sub', 1, '', 1, price
    end }
    assert(loadfile('TitanGatheredForeverV3/Economy.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Actions.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Yields.lua'))('TitanGatheredForeverV3', ns)
    ns.history = { Rates = function() return options.rates or {} end }
    ns.actions = { Rows = function() return options.actions or {} end }
    return ns
end

local rates = {
    { kind = 'Mining', itemID = 1, quantity = 60 }, { kind = 'Mining', itemID = 2, quantity = 30 },
    { kind = 'Mining', itemID = 1, quantity = 10 }, { kind = 'Mining', itemID = 3, quantity = 5 },
    { kind = 'Fishing', itemID = 9, quantity = 8 },
}
local prices = { vendor = { [1] = 5, [2] = 100 }, auction = { [2] = { min = 50, n = 5 }, [9] = { min = 200, n = 5 } } }

test('the best sale is the auction after the fee or the vendor price, nil when unknown', function()
    local ns = fresh(prices)
    eq(ns.Economy.Sale(1).source, 'vendor'); eq(ns.Economy.Sale(1).unit, 5)
    eq(ns.Economy.Sale(2).source, 'vendor')                  -- 100 at the vendor beats 47.5 at the auction
    eq(ns.Economy.Sale(9).source, 'auction'); assert(math.abs(ns.Economy.Sale(9).unit - 190) < 1e-9)
    eq(ns.Economy.Sale(3), nil)
end)

test('rows list the most collected items with value, share and unpriced counts', function()
    local ns = fresh({ vendor = prices.vendor, auction = prices.auction, rates = rates,
        actions = { { kind = 'Mining', completed = 100, attempts = 110 } } })
    local rows = ns.Yields.Rows(nil, 'Mining', 'quantity')
    eq(rows[1].title, true); eq(rows[1].text, 'Mining')
    assert(rows[2].summary and rows[2].text:find('Completed: 100     Items collected: 105',1,true), rows[2].text)
    assert(rows[2].text:find('(1 items without a price)',1,true), rows[2].text)
    eq(rows[4].spacer, true)                                    -- a small gap before the list of items
    eq(rows[5].itemID, 1); eq(rows[5].quantity, 70); eq(rows[5].value, 350); eq(rows[6].itemID, 2); eq(rows[7].itemID, 3)
    eq(rows[7].value, nil)
    assert(math.abs(rows[5].share - 70 / 105 * 100) < 1e-9)
    rows = ns.Yields.Rows(nil, 'Mining', 'value'); eq(rows[5].itemID, 2)      -- 3000 beats 350, the unpriced one is last
    eq(rows[7].itemID, 3)
end)

test('a blank row separates one profession from the next', function()
    local ns = fresh({ vendor = prices.vendor, auction = prices.auction, rates = rates })
    local rows, spacers, titles = ns.Yields.Rows(nil, nil, 'quantity'), 0, 0
    for index, row in ipairs(rows) do
        if row.spacer and not row.small then spacers = spacers + 1; assert(rows[index + 1].title and index > 1) end
        if row.title then titles = titles + 1 end
    end
    eq(titles, 2); eq(spacers, 1); eq(rows[1].title, true)
end)

test('the summary lines separate labels from values and show money with coin icons', function()
    local ns = fresh({ vendor = prices.vendor, auction = prices.auction, rates = rates,
        actions = { { kind = 'Mining', completed = 100, attempts = 110, timedBegan = 1000, active = 3600, timedItems = { [1] = 20 } } } })
    ns.Style = { gold = 'GOLD', white = 'WHITE', Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end }
    dofile('tests/style_stub.lua')(ns.Style)
    ns.NpcSources.CoinIcons = function(copper) return copper .. '[coins]' end
    local rows = ns.Yields.Rows(nil, 'Mining', 'quantity')
    assert(rows[2].text:find('<GOLD>Completed: </><WHITE>100</>', 1, true), rows[2].text)
    assert(rows[2].text:find('<GOLD>Worth: </>', 1, true) and rows[2].text:find('[coins]', 1, true), rows[2].text)
    assert(rows[3].text:find('<GOLD>Active time: </><WHITE>1 h 0 min</>', 1, true), rows[3].text)
    assert(rows[3].text:find('<GOLD>Per hour: </>100[coins]', 1, true), rows[3].text)
end)

test('professions that are hidden or filtered out have no rows', function()
    local ns = fresh({ vendor = prices.vendor, auction = prices.auction, rates = rates, hidden = { Mining = true } })
    for _, row in ipairs(ns.Yields.Rows(nil, nil, 'quantity')) do assert(row.kind ~= 'Mining') end
    ns = fresh({ vendor = prices.vendor, auction = prices.auction, rates = rates })
    for _, row in ipairs(ns.Yields.Rows(nil, 'Fishing', 'quantity')) do eq(row.kind, 'Fishing') end
end)

test('a value per hour needs measured time and the items counted in the same period', function()
    local ns = fresh({ vendor = prices.vendor, rates = rates, actions = { { kind = 'Mining', completed = 10, attempts = 10,
        timedBegan = 1000, active = 3600, timedItems = { [1] = 20, [2] = 1 } } } })
    local rows = ns.Yields.Rows(nil, 'Mining', 'quantity')
    assert(rows[3].text:find('Active time: 1 h 0 min',1,true), rows[3].text)
    assert(rows[3].text:find('Per hour: 200c and 21 items',1,true), rows[3].text)       -- 20 x 5 + 1 x 100
    ns = fresh({ vendor = prices.vendor, rates = rates, actions = { { kind = 'Mining', completed = 1, attempts = 1,
        timedBegan = 1000, active = 120, timedItems = { [1] = 2 } } } })
    assert(ns.Yields.Rows(nil, 'Mining', 'quantity')[3].text:find('too little time',1,true))
    ns = fresh({ vendor = prices.vendor, rates = rates, actions = { { kind = 'Mining', completed = 1, attempts = 1 } } })
    assert(ns.Yields.Rows(nil, 'Mining', 'quantity')[3].text:find('measured from this version on',1,true))
end)

test('the action tracker measures active time and counts timed items', function()
    local ns = fresh()
    local now, character = 1000, 'a'
    local saved = { schema = 1, characters = {} }
    local actions = ns.Actions.New(saved, { Character = function() return character end, Name = function() return 'A' end,
        Timestamp = function() return now end, Now = function() return now end, Enabled = function() return true end })
    local function cast(guid) actions:Cast('UNIT_SPELLCAST_START', 'player', guid, 2575); actions:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', guid, 2575) end
    cast('g1'); now = now + 30; cast('g2'); now = now + 500; cast('g3'); now = now + 60; cast('g4')
    local row = saved.characters.a.kinds.Mining
    eq(row.attempts, 4); eq(row.active, 90)                  -- 30 + 60, the pause of 500 seconds ended the session
    actions:Yield('Mining', { [1] = 3, [2] = 1 }); actions:Yield('Mining', { [1] = 2 })
    eq(row.timedItems[1], 5); eq(row.timedItems[2], 1)
    actions:Yield('Loot', { [1] = 1 })                       -- not an action profession
    local combined = actions:Rows()[1]
    eq(combined.active, 90); eq(combined.timedItems[1], 5); eq(combined.timedBegan, 1000)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS yields ' .. #tests .. ' checks')
