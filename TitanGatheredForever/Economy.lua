local _, ns = ...
-- What things are worth: the vendor price of a product against the lowest auction buyout (after the auction house
-- fee), the cheapest known way to buy a reagent, and the profit of one craft. Only prices the addon has seen are used;
-- an unknown price stays unknown and makes the profit unknown too.
local Economy = {}
ns.Economy = Economy

-- Fee of the auction house on a sale. This is the usual Classic value and an assumption, not read from the client.
Economy.CUT = 0.05

-- Money for display. A price per unit can be a fraction of a copper (the fee of one cheap unit), so it is rounded here
-- and nowhere else.
local function coin(copper)
    copper = math.max(0, math.floor(copper + 0.5))
    local api = ns.NpcSources
    if api and api.CoinIcons then return api.CoinIcons(copper) end
    return api and api.Coin(copper) or (tostring(copper) .. 'c')
end
Economy.Coin = coin

-- What the auction house leaves of one unit after its fee. Not rounded: the fee of a cheap unit is a fraction of a copper
-- (95 percent of 1 copper is 0.95), and rounding it down would make cheap ammunition worth nothing.
function Economy.Net(price) return price * (1 - Economy.CUT) end

-- The fee of the auction house on a sale of total copper, rounded to whole copper.
function Economy.Fee(total) return math.floor(total * Economy.CUT + 0.5) end

-- What one auction brings, in copper. price is per unit, deposit is what the client asks for posting (nil when
-- unknown), vendor is what a vendor pays per unit (nil when unknown). The deposit is returned when the auction sells
-- and lost when it expires: that is an assumption of the classic auction house, to be confirmed in the client.
--   net      what is left of the sale after the fee
--   loss     what an unsold auction costs (the deposit); the item stays with the player
--   gain     the net against selling the same units to a vendor (nil without a vendor price)
--   profit   the net minus what the units cost (cost per unit, Economy.UnitCost: the cheapest known way to buy one
--            again); nil without a cost. An unsold auction costs the deposit only, the item stays with the player
--   neededProfit  the same share counted against the cost (nil without a cost or a deposit, 'never' when a sale loses money)
--   needed   the share of auctions (0 to 1) that must sell for posting to pay: deposit / (gain + deposit);
--            nil when the gain or the deposit is unknown, and 'never' when a sale gains nothing over a vendor
function Economy.Posting(price, quantity, deposit, vendor, cost)
    if type(price) ~= 'number' or price <= 0 then return nil end
    quantity = (type(quantity) == 'number' and quantity >= 1) and quantity or 1
    local total = price * quantity
    local result = { total = total, fee = Economy.Fee(total), quantity = quantity, deposit = deposit, vendor = vendor }
    result.net = total - result.fee
    result.loss = deposit
    if vendor and vendor > 0 then result.gain = result.net - vendor * quantity end
    if type(cost) == 'number' and cost > 0 then result.cost = cost; result.profit = result.net - cost * quantity end
    if result.gain and deposit then
        if result.gain <= 0 then result.needed = 'never'
        else result.needed = deposit / (result.gain + deposit) end
    end
    -- The same share against the cost: the profit of a sale must cover the deposits lost on the auctions that do not sell.
    if result.profit and deposit then
        if result.profit <= 0 then result.neededProfit = 'never'
        else result.neededProfit = deposit / (result.profit + deposit) end
    end
    return result
end

-- The lowest price per unit at which a sale, after the fee, brings at least what a vendor pays; nil without a vendor price.
function Economy.MinPrice(vendor)
    if type(vendor) ~= 'number' or vendor <= 0 then return nil end
    local price = math.max(1, math.ceil(vendor / (1 - Economy.CUT)) - 2)
    while price - Economy.Fee(price) < vendor do price = price + 1 end
    return price
end

-- What a vendor pays for one item (copper), nil when unknown or not sellable.
function Economy.VendorSell(itemID)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local result = { pcall(C_Item.GetItemInfo, itemID) }
    if not result[1] then return nil end
    local price = result[12]                     -- the 11th value after the success flag
    if ns.IsPublic(price) and type(price) == 'number' and price > 0 then return price end
    return nil
end

-- The lowest auction buyout of an item from the last scan: { min, n, net } or nil.
function Economy.Auction(itemID)
    local price = ns.AuctionScan and ns.AuctionScan.Price(itemID)
    if not price then return nil end
    return { min = price.min, n = price.n, qty = price.qty, net = Economy.Net(price.min) }
end

-- What one unit of an item sells for at best: { unit, source, auction, vendor } or nil when no price is known. The
-- auction price is the lowest buyout of the last scan after the fee, the vendor price comes from the item info.
function Economy.Sale(itemID)
    local auction, vendor = Economy.Auction(itemID), Economy.VendorSell(itemID)
    if auction and (not vendor or auction.net >= vendor) then return { unit = auction.net, source = 'auction', auction = auction, vendor = vendor } end
    if vendor then return { unit = vendor, source = 'vendor', auction = auction, vendor = vendor } end
end

-- The cheapest known price for one unit of an item and where it is: 'auction' or 'vendor'. A merchant that was seen
-- selling it counts when it is cheaper than the auction house, and when there is no auction price.
function Economy.UnitCost(itemID)
    local best, source
    local auction = Economy.Auction(itemID)
    if auction then best, source = auction.min, 'auction' end
    local vendor = ns.NpcSources and ns.NpcSources.VendorsFor(itemID)[1]
    if vendor and vendor.unit and not vendor.extendedCost then
        local unit = math.max(1, math.floor(vendor.unit + 0.5))
        if not best or unit < best then best, source = unit, 'vendor' end
    end
    return best, source
end

-- The product of a recipe plan (Crafting.Compute) compared with its materials, for one craft:
-- { itemID, quantity, auction, vendor, best, unitValue, value, materials, unpriced, profit, partial }.
-- best is where one unit sells for more ('auction' after the fee, or 'vendor'); value is what one craft yields.
function Economy.Product(plan)
    if not plan or not plan.outputItemID then return nil end
    local low = plan.quantityMin or 1
    local high = plan.quantityMax or low
    local quantity = (low + high) / 2
    local result = { itemID = plan.outputItemID, quantity = quantity, auction = Economy.Auction(plan.outputItemID),
        vendor = Economy.VendorSell(plan.outputItemID), materials = 0, unpriced = 0, partial = #(plan.issues or {}) > 0 }
    local auction, vendor = result.auction, result.vendor
    if auction and vendor then
        if auction.net >= vendor then result.best, result.unitValue = 'auction', auction.net
        else result.best, result.unitValue = 'vendor', vendor end
    elseif auction then result.best, result.unitValue = 'auction', auction.net
    elseif vendor then result.best, result.unitValue = 'vendor', vendor end
    for _, row in ipairs(plan.rows) do
        local unit = Economy.UnitCost(row.itemID)
        if unit then result.materials = result.materials + unit * row.perOperation else result.unpriced = result.unpriced + 1 end
    end
    if result.unitValue then
        result.value = math.floor(result.unitValue * quantity + 0.5)
        if result.unpriced == 0 and not result.partial then result.profit = result.value - result.materials end
    end
    return result
end
