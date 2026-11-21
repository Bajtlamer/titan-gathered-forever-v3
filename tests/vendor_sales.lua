local ns = { db = {}, characterID = 'Player-1', IsPublic = function(value) return value ~= 'secret' end }
local function eq(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local callbacks = {}
_G.C_Timer = { After = function(_, callback) callbacks[#callbacks + 1] = callback end }
local balance, rows, realm = 100, {}, 'Forever'
_G.time = function() return 123 end
_G.GetMoney = function() return balance end
_G.GetRealmName = function() return realm end
_G.GetNumBuybackItems = function() return #rows end
_G.GetBuybackItemInfo = function(i)
    local row = rows[i]
    if row then return 'Vendor item', nil, row.copper, row.quantity end
end
_G.C_MerchantFrame = { GetBuybackItemID = function(i) return rows[i].id end }
_G.GetBuybackItemLink = function(i) return '|Hitem:' .. rows[i].id .. ':0|h[Vendor item]|h' end
assert(loadfile('TitanGatheredForever/VendorSales.lua'))('TitanGatheredForever', ns)
local Vendor = ns.VendorSales
Vendor.Initialize()
local function fire(event)
    Vendor.Handle(event)
end
local function settle()
    local current = callbacks
    callbacks = {}
    for _, callback in ipairs(current) do callback() end
end
local function item(id, quantity, copper) return { id = id, quantity = quantity, copper = copper } end
local function total(onRealm) return Vendor.Totals(ns.db.vendorSales, onRealm or realm) end

-- The list from earlier visits is just a baseline. A normal sale must reconcile even if its money arrives second.
rows = { item(10, 1, 9) }
fire('MERCHANT_SHOW')
eq(total().soldUnits, 0)
rows[2] = item(11, 4, 60)
fire('MERCHANT_UPDATE')
eq(total().soldUnits, 0)
balance = 160
fire('PLAYER_MONEY')
fire('MERCHANT_UPDATE')
settle()
eq(total().soldUnits, 4); eq(total().soldCopper, 60); eq(total().sales, 1)
local sale = ns.db.vendorLog[#ns.db.vendorLog]
eq(sale.result, 'sale'); eq(sale.items[1].itemID, 11); eq(sale.items[1].quantity, 4)

-- Money can arrive first, and one update can cover multiple new stacks including duplicate items.
balance = 200
fire('PLAYER_MONEY')
rows[3], rows[4] = item(12, 2, 20), item(12, 2, 20)
fire('MERCHANT_UPDATE')
settle()
eq(total().soldUnits, 8); eq(total().soldCopper, 100); eq(total().sales, 3)

-- Buyback is a separate expense and can remove a middle or a previously untracked stack.
table.remove(rows, 2)
balance = 140
fire('MERCHANT_UPDATE')
settle()
eq(total().buybackUnits, 4); eq(total().buybackCopper, 60)
table.remove(rows, 1)
balance = 131
fire('PLAYER_MONEY')
settle()
eq(total().buybackUnits, 5); eq(total().buybackCopper, 69)
eq(total().soldUnits, 8); eq(total().soldCopper, 100)

-- A purchase and unproven money credit are never treated as sales.
balance = 121; fire('PLAYER_MONEY'); settle()
balance = 176; fire('PLAYER_MONEY'); fire('MERCHANT_UPDATE'); settle()
eq(total().sales, 3); eq(total().buybackUnits, 5)
rows[#rows + 1] = item(10, 1, 25)
balance = 195
fire('MERCHANT_UPDATE'); settle()
eq(total().sales, 3); eq(ns.db.vendorLog[#ns.db.vendorLog].result, 'unmatched')
fire('MERCHANT_CLOSED')
settle()

-- The newest row remains identifiable when the oldest buyback slot is evicted.
realm = 'Another realm'
rows = {}
for id = 1, 12 do rows[id] = item(id, 1, 15) end
fire('MERCHANT_SHOW')
table.remove(rows, 1)
rows[#rows + 1] = item(66, 3, 33)
balance = 228
fire('MERCHANT_UPDATE')
settle()
eq(total().soldUnits, 3); eq(total().soldCopper, 33)
eq(total('Forever').soldUnits, 8)
fire('MERCHANT_CLOSED'); settle()

-- Fall back to the native item link if the realm does not expose GetBuybackItemID.
_G.C_MerchantFrame = nil
rows = {}
fire('MERCHANT_SHOW')
rows[1] = item(77, 6, 42)
fire('MERCHANT_UPDATE')
balance = 270
fire('MERCHANT_CLOSED')
settle()
eq(total().soldUnits, 9); eq(total().soldCopper, 75)

-- A fast purchase, then wallet-first sale can reconcile against the intermediate balance.
rows = {}
fire('MERCHANT_SHOW')
balance = 260
fire('PLAYER_MONEY')
balance = 280
fire('PLAYER_MONEY')
rows[1] = item(80, 1, 20)
fire('MERCHANT_UPDATE')
settle()
eq(total().soldUnits, 10); eq(total().soldCopper, 95)
fire('MERCHANT_CLOSED')

-- The list may already contain the accepted sale when close arrives ahead of MERCHANT_UPDATE.
rows = {}
fire('MERCHANT_SHOW')
balance = 290
fire('PLAYER_MONEY')
rows[1] = item(81, 1, 10)
fire('MERCHANT_CLOSED')
settle()
eq(total().soldUnits, 11); eq(total().soldCopper, 105)

-- A wallet change seen while a loot window is already tracking coins cannot fund a merchant sale.
local looting = false
ns.LootIncome = { WalletBusy = function() return looting end }
rows = {}
fire('MERCHANT_SHOW')
looting = true
rows[1], balance = item(99, 1, 12), balance + 12
fire('MERCHANT_UPDATE'); fire('PLAYER_MONEY'); settle()
looting = false
fire('MERCHANT_CLOSED'); settle()
eq(total().soldUnits, 11); eq(total().soldCopper, 105)

-- Failed client reads leave their exact missing field in the saved diagnostics.
rows = { item(82, 1, nil) }
fire('MERCHANT_SHOW')
local diagnostic = ns.db.vendorLog[#ns.db.vendorLog]
eq(diagnostic.event, 'MERCHANT_SHOW')
eq(diagnostic.result, 'read-failed')
eq(diagnostic.reason, 'buyback price unavailable')
eq(diagnostic.slot, 1)
settle()
fire('MERCHANT_CLOSED')
-- Sell All Junk Items can sell more stacks than the buyback list holds (12), so the list cannot prove the sale. The bags
-- can: what left them, at its vendor price, must add up to the money exactly.
local bags, prices = {}, {}
_G.NUM_BAG_SLOTS = 0
_G.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 20 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local entry = bags[slot]
        if bag == 0 and entry then return { itemID = entry.id, stackCount = entry.count } end
    end,
}
ns.Economy = { VendorSell = function(id) return prices[id] end }
-- The wait for the buyback list (half a second) and the confirmation of a sale are two timers, one after the other.
local function settleAll()
    for _ = 1, 4 do settle() end
end
local function visit(setup)
    fire('MERCHANT_CLOSED'); settle()
    bags, rows = {}, {}
    setup()
    fire('MERCHANT_SHOW')
end
local function last() return ns.db.vendorLog[#ns.db.vendorLog] end

visit(function()
    for slot = 1, 14 do bags[slot] = { id = 200 + slot, count = 1 }; prices[200 + slot] = 10 end
    bags[15], prices[999] = { id = 999, count = 5 }, 7
end)
local before = total()
for slot = 1, 14 do bags[slot] = nil end
for i = 1, 12 do rows[i] = item(202 + i, 1, 10) end                      -- the list keeps the last twelve
balance = balance + 140
fire('PLAYER_MONEY'); fire('MERCHANT_UPDATE'); settleAll()
eq(total().soldUnits, before.soldUnits + 14); eq(total().soldCopper, before.soldCopper + 140)
eq(total().sales, before.sales + 14)
eq(last().result, 'sale'); eq(last().reason, 'bags'); eq(#last().items, 14)

-- A partly sold stack counts only the units that left, and a money gain that the bags do not prove stays unmatched.
visit(function() bags[1], prices[301] = { id = 301, count = 5 }, 4 end)
before = total()
bags[1].count = 2
balance = balance + 12
fire('PLAYER_MONEY'); settleAll()
eq(total().soldUnits, before.soldUnits + 3); eq(total().soldCopper, before.soldCopper + 12); eq(total().sales, before.sales + 1)

visit(function() bags[1], prices[300] = { id = 300, count = 1 }, 10 end)
before = total()
bags[1] = nil
balance = balance + 11
fire('PLAYER_MONEY'); settleAll()
eq(total().soldUnits, before.soldUnits); eq(last().result, 'unmatched')

-- An item that only moved to another slot is not a sale, and an item without a known vendor price proves nothing.
visit(function() bags[1] = { id = 300, count = 1 } end)
before = total()
bags[1], bags[2] = nil, { id = 300, count = 1 }
balance = balance + 10
fire('PLAYER_MONEY'); settleAll()
eq(total().soldUnits, before.soldUnits); eq(last().result, 'unmatched')
visit(function() bags[1] = { id = 555, count = 1 } end)
before = total()
bags[1] = nil
balance = balance + 10
fire('PLAYER_MONEY'); settleAll()
eq(total().soldUnits, before.soldUnits); eq(last().result, 'unmatched')

-- The bag API missing or failing never raises and leaves the old behaviour.
_G.C_Container = nil
rows = {}
fire('MERCHANT_CLOSED'); settle()
fire('MERCHANT_SHOW')
balance = balance + 25
fire('PLAYER_MONEY'); settleAll()
eq(last().result, 'unmatched')
fire('MERCHANT_CLOSED'); settle()
-- Repairs cost money without touching the buyback list: the wallet falls by exactly the amount by which the cost of
-- "repair all" falls. A different drop, or a client without the cost, is no repair.
local repairCost = 96
_G.GetRepairAllCost = function() return repairCost, repairCost > 0 end
visit(function() end)
before = total()
eq(before.repairs, 0); eq(before.repairCopper, 0)
balance = balance - 96; repairCost = 0
fire('PLAYER_MONEY'); settleAll()
eq(total().repairCopper, 96); eq(total().repairs, 1); eq(last().result, 'repair')
eq(total().soldUnits, before.soldUnits); eq(total().buybacks, before.buybacks)      -- not a sale or a buyback

repairCost = 100
visit(function() end)
balance = balance - 40; repairCost = 60                                                -- one piece repaired
fire('PLAYER_MONEY'); settleAll()
eq(total().repairCopper, 136); eq(total().repairs, 2)

repairCost = 60
visit(function() end)
balance = balance - 30                                                                 -- a purchase: the repair cost is unchanged
fire('PLAYER_MONEY'); settleAll()
eq(total().repairCopper, 136); eq(last().result, 'unmatched')
balance = balance - 40; repairCost = 30                                                -- 40 spent, the cost fell by 30
fire('PLAYER_MONEY'); settleAll()
eq(total().repairCopper, 136); eq(total().repairs, 2)

_G.GetRepairAllCost = nil
visit(function() end)
balance = balance - 10
fire('PLAYER_MONEY'); settleAll()
eq(total().repairs, 2); eq(last().result, 'unmatched')
_G.GetRepairAllCost = function() error('boom') end
visit(function() end)
balance = balance - 10
fire('PLAYER_MONEY'); settleAll()
eq(total().repairs, 2)
_G.GetRepairAllCost = nil
fire('MERCHANT_CLOSED'); settle()

print('PASS verified merchant sales, buybacks and realm totals')
