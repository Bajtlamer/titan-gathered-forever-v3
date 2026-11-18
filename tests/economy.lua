local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function fresh(prices, vendors, sell)
    local ns = { IsPublic = function() return true end }
    ns.AuctionScan = { Price = function(id) return prices and prices[id] end }
    ns.NpcSources = { VendorsFor = function(id) return vendors and vendors[id] or {end_ = true} end,
        Coin = function(copper) return copper .. 'c' end }
    C_Item = { GetItemInfo = function(id)
        local price = sell and sell[id]
        return 'Name', 'link', 1, 1, 1, 'type', 'sub', 1, '', 1, price
    end }
    assert(loadfile('TitanGatheredForever/Economy.lua'))('TitanGatheredForever', ns)
    return ns
end
local function plan(rows, output, low, high, issues)
    return { outputItemID = output, quantityMin = low, quantityMax = high, issues = issues or {}, rows = rows }
end

test('the auction price is reduced by the fee, the vendor price is read from the item info', function()
    local ns = fresh({ [10] = { min = 1000, n = 4 } }, nil, { [10] = 250, [11] = 0 })
    local auction = ns.Economy.Auction(10)
    eq(auction.min, 1000); eq(auction.net, 950); eq(auction.n, 4)
    eq(ns.Economy.Auction(99), nil); assert(math.abs(ns.Economy.Net(333) - 316.35) < 1e-9)    -- the fee is not rounded away
    eq(ns.Economy.VendorSell(10), 250); eq(ns.Economy.VendorSell(11), nil)   -- zero means it cannot be sold
    eq(ns.Economy.VendorSell(12), nil)
    C_Item = nil; eq(ns.Economy.VendorSell(10), nil)
end)

test('the cheapest known way to buy picks the auction, or a cheaper merchant', function()
    local ns = fresh({ [1] = { min = 100 }, [2] = { min = 100 } }, {
        [1] = { { unit = 60, name = 'Cheap' } }, [2] = { { unit = 130, name = 'Dear' } },
        [3] = { { unit = 25.4, name = 'Only' } }, [4] = { { extendedCost = true, unit = nil } } })
    local cost, source = ns.Economy.UnitCost(1); eq(cost, 60); eq(source, 'vendor')       -- the merchant is cheaper
    cost, source = ns.Economy.UnitCost(2); eq(cost, 100); eq(source, 'auction')             -- the auction is cheaper
    cost, source = ns.Economy.UnitCost(3); eq(cost, 25); eq(source, 'vendor')               -- only a merchant
    cost, source = ns.Economy.UnitCost(4); eq(cost, nil); eq(source, nil)                   -- paid with something else
    eq(ns.Economy.UnitCost(5), nil)
end)

test('a product is sold where one unit yields more, and the profit is the value minus the materials of one craft', function()
    local ns = fresh({ [100] = { min = 4000, n = 12 }, [1] = { min = 500 }, [2] = { min = 300 } }, nil, { [100] = 3000 })
    local result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 2 }, { itemID = 2, perOperation = 1 } }, 100, 1, 1))
    eq(result.best, 'auction'); eq(result.unitValue, 3800); eq(result.value, 3800)           -- 4000 less 5% beats 3000
    eq(result.materials, 1300); eq(result.unpriced, 0); eq(result.profit, 2500)
    eq(result.auction.n, 12); eq(result.vendor, 3000)
    -- the vendor pays more than the auction leaves
    ns = fresh({ [100] = { min = 3000 }, [1] = { min = 500 } }, nil, { [100] = 2900 })
    result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 } }, 100, 1, 1))
    eq(result.best, 'vendor'); eq(result.unitValue, 2900); eq(result.profit, 2400)
end)

test('the fee of one cheap unit is a fraction of a copper and is not rounded to nothing', function()
    local ns = fresh({ [100] = { min = 1, n = 50 }, [1] = { min = 100 } })
    assert(math.abs(ns.Economy.Net(1) - 0.95) < 1e-9)
    eq(ns.Economy.Coin(0.95), '1c'); eq(ns.Economy.Coin(0.4), '0c'); eq(ns.Economy.Coin(-3), '0c')   -- rounded for display only
    local result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 } }, 100, 200, 200))    -- a craft makes 200 shots
    eq(result.value, 190); eq(result.profit, 90)                                                      -- 200 x 0.95 less 100
    result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 } }, 100, 1, 1))
    eq(result.value, 1); eq(result.profit, -99)                                                        -- one shot still counts as 1 copper
end)

test('a craft that makes several items counts their average and a loss is negative', function()
    local ns = fresh({ [100] = { min = 100 }, [1] = { min = 1000 } })
    local result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 } }, 100, 1, 3))   -- two on average
    eq(result.quantity, 2); eq(result.value, 190); eq(result.profit, -810)
end)

test('unknown prices stay unknown and never give an invented profit', function()
    local ns = fresh({ [100] = { min = 4000 }, [1] = { min = 500 } })
    local result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 }, { itemID = 2, perOperation = 3 } }, 100, 1, 1))
    eq(result.unpriced, 1); eq(result.materials, 500); eq(result.profit, nil); eq(result.value, 3800)   -- a reagent has no price
    result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 } }, 100, 1, 1, { 'partial slot' }))
    eq(result.partial, true); eq(result.profit, nil)                                                     -- rows are only part of the recipe
    result = ns.Economy.Product(plan({ { itemID = 1, perOperation = 1 } }, 555, 1, 1))
    eq(result.best, nil); eq(result.unitValue, nil); eq(result.profit, nil)                              -- the product has no price at all
    eq(ns.Economy.Product(plan({}, nil, nil, nil)), nil); eq(ns.Economy.Product(nil), nil)
end)

test('a posting: net after the fee, the loss of an unsold auction and the share that must sell', function()
    local E = fresh().Economy
    local p = E.Posting(1000, 5, 120, 100)                -- 5 units at 1000, deposit 120, vendor pays 100 each
    eq(p.total, 5000); eq(p.fee, 250); eq(p.net, 4750); eq(p.loss, 120); eq(p.gain, 4250)
    assert(math.abs(p.needed - 120 / (4250 + 120)) < 1e-9)
    p = E.Posting(100, 1, 40, 100)                        -- the sale after the fee is below the vendor price
    eq(p.net, 95); eq(p.gain, -5); eq(p.needed, 'never')
    p = E.Posting(1000, 1, nil, 100); eq(p.gain, 850); eq(p.needed, nil); eq(p.loss, nil)   -- unknown deposit stays unknown
    p = E.Posting(1000, 1, 50, nil); eq(p.gain, nil); eq(p.needed, nil); eq(p.net, 950)     -- unknown vendor price stays unknown
    eq(E.Posting(0, 1, 5, 5), nil); eq(E.Posting(nil, 1, 5, 5), nil)
    eq(E.Posting(10, 0, 1, 1).quantity, 1)                -- a missing quantity counts as one unit
end)

test('the lowest price that beats a vendor after the fee', function()
    local E = fresh().Economy
    eq(E.MinPrice(nil), nil); eq(E.MinPrice(0), nil)
    for _, vendor in ipairs({ 1, 3, 20, 100, 777, 12345 }) do
        local price = E.MinPrice(vendor)
        assert(price - E.Fee(price) >= vendor, 'price ' .. price .. ' does not beat vendor ' .. vendor)
        assert(price - 1 - E.Fee(price - 1) < vendor or price == 1, 'price ' .. price .. ' is not the lowest for vendor ' .. vendor)
    end
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS economy ' .. #tests .. ' checks')
