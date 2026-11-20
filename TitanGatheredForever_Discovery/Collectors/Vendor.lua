local _, ns = ...
-- What a vendor sells (price, stack, stock, extended cost) and what a trainer teaches (cost, skill requirement, level).
-- Every window is read when it opens; a vendor window may also update a few times, each read refreshing the values.
local Vendor = {}
ns.Vendor = Vendor

local MAX_UPDATES = 3
local updates = 0

local function record(id)
    local entry = ns.Records.Ensure(ns.db.data.vendors, id, ns.Records.Context())
    entry.goods = entry.goods or {}
    entry.taught = entry.taught or {}
    return entry
end

local function scanGoods(id)
    local entry = record(id)
    local ctx = ns.Records.Context()
    entry.scans = (entry.scans or 0) + 1
    entry.last, entry.lastBuild = ctx.now, ctx.build
    for _, good in ipairs(ns.api.Merchant()) do
        local item = entry.goods[good.itemID] or { seen = 0 }
        entry.goods[good.itemID] = item
        item.seen = item.seen + 1
        item.price, item.stack, item.stock, item.extendedCost = good.price, good.stack, good.stock, good.extendedCost
    end
end

function Vendor.MerchantShown()
    updates = 0
    local npc, id = ns.Npc.Contact('npc', 'vendor')
    if not npc then return end
    if ns.api.CanRepair() then ns.Npc.Contact('npc', 'repair') end
    scanGoods(id)
end

function Vendor.MerchantUpdated()
    if updates >= MAX_UPDATES then return end
    local npc, id = ns.Npc.Contact('npc', nil)
    if not npc then return end
    updates = updates + 1
    scanGoods(id)
end

function Vendor.TrainerShown()
    local npc, id = ns.Npc.Contact('npc', 'trainer')
    if not npc then return end
    local entry = record(id)
    local ctx = ns.Records.Context()
    entry.last, entry.lastBuild = ctx.now, ctx.build
    for _, service in ipairs(ns.api.Trainer()) do
        entry.taught[service.name] = { cost = service.cost, skillName = service.skillName,
            skillRank = service.skillRank, level = service.level }
    end
end
