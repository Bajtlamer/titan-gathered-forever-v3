local ns = { db = {}, characterID = 'Player-A', IsPublic = function(value) return value ~= 'secret' end }
local function eq(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local frame = { events = {} }
function frame:RegisterEvent(event) self.events[event] = true end
function frame:SetScript(_, fn) self.onEvent = fn end
_G.CreateFrame = function() return frame end
local callbacks = {}
_G.C_Timer = { After = function(_, callback) callbacks[#callbacks + 1] = callback end }
local balance, slots, realm, corpse = 100, {}, 'Forever', true
_G.Enum = { LootSlotType = { Money = 2, Item = 1 } }
_G.C_CurrencyInfo = { GetCoinText = function(amount) return amount .. ' Copper' end }
_G.GetMoney = function() return balance end
_G.GetRealmName = function() return realm end
_G.time = function() return 123 end
local readable = true
_G.GetNumLootItems = function() return readable and #slots or 'secret' end
_G.GetLootSlotType = function(index) return slots[index].kind end
_G.GetLootSlotInfo = function(index) return nil, slots[index].label end
_G.GetLootSourceInfo = function(index) return unpack(slots[index].sources) end
local overCorpse = true
_G.UnitGUID = function(unit) return overCorpse and unit == 'mouseover' and 'Creature-A' or nil end
_G.UnitIsDead = function(unit) return unit == 'mouseover' and corpse end
assert(loadfile('TitanGatheredForever/LootIncome.lua'))('TitanGatheredForever', ns)
local Income = ns.LootIncome
Income.Initialize()
local function fire(event, ...)
    assert(frame.events[event], event)
    frame.onEvent(frame, event, ...)
end
local function settle()
    for _, callback in ipairs(callbacks) do callback() end
    callbacks = {}
end
local function coin(source, amount)
    return { kind = 2, label = amount .. ' copper', sources = { source, 1 } }
end
local function open(loot, fromItem)
    slots = loot
    fire('LOOT_READY', true)
    fire('LOOT_OPENED', true, fromItem)
end
local function pickUp(amount)
    balance = balance + amount
    fire('PLAYER_MONEY')
    fire('LOOT_SLOT_CLEARED', 1)
    fire('LOOT_CLOSED')
    settle()
end
local function total() return Income.Total(ns.db.lootIncome, 'Forever') end
eq(total(), nil)

-- LOOT_READY can precede source identification, and duplicate clear events count once.
slots = { coin(nil, 12) }
slots[1].sources = {}
fire('LOOT_READY', true)
slots = { coin('Creature-A', 12) }
fire('LOOT_OPENED', true, false)
fire('LOOT_SLOT_CLEARED', 1)
fire('LOOT_SLOT_CLEARED', 1)
fire('LOOT_CLOSED')
balance = balance + 12
fire('PLAYER_MONEY')
settle()
local amount, pickups = total()
eq(amount, 12); eq(pickups, 1)

-- No collection, another kind of wallet credit, an item container, a chest and a living target are all excluded.
open({ coin('Creature-A', 30) }, false)
fire('LOOT_CLOSED')
settle()
open({ coin('Creature-A', 30) }, false); pickUp(100)
open({ coin('Creature-A', 30) }, true); pickUp(30)
open({ coin('GameObject-A', 30) }, false); pickUp(30)
corpse = false
open({ coin('Creature-A', 30) }, false); pickUp(30)
corpse = true
open({ coin('Creature-A', 30), coin('Creature-A', 30) }, false); pickUp(30)
open({ coin('Creature-A', 31) }, false)
slots = { coin('Creature-A', 30) }
fire('LOOT_SLOT_CHANGED', 1)
pickUp(30)
slots = { coin('Creature-A', 31) }
fire('LOOT_READY', true)
slots = { coin('Creature-A', 30) }
fire('LOOT_OPENED', true, false)
pickUp(30)
slots = { coin('Creature-A', 30) }
fire('LOOT_READY', true)
readable = false
fire('LOOT_OPENED', true, false)
readable = true
pickUp(30)
open({ coin('Creature-A', 30) }, false)
balance = balance + 35; fire('PLAYER_MONEY')
balance = balance - 5; fire('PLAYER_MONEY')
pickUp(0)
eq(total(), 12)

realm = 'Elsewhere'
open({ coin('Creature-A', 9) }, false); pickUp(9)
eq(total(), 12); eq(Income.Total(ns.db.lootIncome, realm), 9)
realm, ns.characterID = 'Forever', 'Player-B'
open({ coin('Creature-A', 18) }, false); pickUp(18)
amount, pickups = total()
eq(amount, 30); eq(pickups, 2)

C_CurrencyInfo.GetCoinTextureString = function(value)
    return value .. '|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t'
end
local textured = coin('Creature-A', 8)
textured.label = '8 |TInterface\\MoneyFrame\\UI-CopperIcon:10:10:0:0|t'
open({ textured }, false); pickUp(8)
eq(total(), 38)

slots = { coin('Creature-A', 7) }
fire('LOOT_READY', true)
overCorpse = false
fire('LOOT_OPENED', true, false)
pickUp(7)
eq(total(), 45)
overCorpse = true
open({ coin('Creature-A', 10) }, false)
fire('LOOT_SLOT_CLEARED', 1)
balance = balance + 10
fire('PLAYER_MONEY')
fire('LOOT_CLOSED')
assert(Income.WalletBusy())
Income.ExcludeWalletChanges()
settle()
eq(total(), 45)
assert(not Income.WalletBusy())
print('PASS mob loot income attribution and aggregation')
