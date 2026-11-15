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
