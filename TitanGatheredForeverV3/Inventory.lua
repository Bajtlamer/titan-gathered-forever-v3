local _, ns = ...
local Inventory = {}
Inventory.__index = Inventory
ns.Inventory = Inventory

local function integer(value, minimum)
    return type(value) == 'number' and value >= minimum and value == math.floor(value)
end

local function validCounts(items)
    if type(items) ~= 'table' then return false end
    for itemID, count in pairs(items) do
        if not integer(itemID, 1) or not integer(count, 0) then return false end
    end
    return true
end

function Inventory.New(api, saved)
    local characterID = assert(api.GetCharacterID(), 'Player identity is not available')
    saved.characters = saved.characters or {}
    local character = saved.characters[characterID]
    if type(character) ~= 'table' then
        character = {}
        saved.characters[characterID] = character
    end
    local snapshot = character.bank
    if type(snapshot) ~= 'table' or not validCounts(snapshot.items)
        or not integer(snapshot.observedAt, 1) then character.bank = nil end
    return setmetatable({ api = api, character = character, bankOpen = false,
                          bankCurrent = false, bagsCurrent = false,
                          lastBankStatus = character.bank and 'cached observation' or 'bank not yet observed' }, Inventory)
end

-- Build a complete replacement before touching the previous snapshot. A nil
-- slot is empty; a malformed or inaccessible occupied slot aborts the scan.
function Inventory:Scan(containers, ready)
    if type(containers) ~= 'table' or #containers == 0 then return nil, nil, 'bank tab list is unavailable or empty' end
    local counts, seen, totalSlots = {}, {}, 0
    for _, containerID in ipairs(containers) do
        if not integer(containerID, 0) or seen[containerID] then return nil, nil, 'invalid or duplicate container ID' end
        seen[containerID] = true
        local slots = self.api.GetSlots(containerID)
        if not integer(slots, 0) then return nil, nil, 'container ' .. containerID .. ' has unreadable capacity' end
        if ready and not ready(containerID, slots) then
            return nil, nil, 'bank container ' .. containerID .. ' is not ready (' .. slots .. ' slots)'
        end
        totalSlots = totalSlots + slots
        for slot = 1, slots do
            local item = self.api.GetItem(containerID, slot)
            if item then
                if type(item) ~= 'table' or not integer(item.itemID, 1)
                    or not integer(item.stackCount, 1) then
                    return nil, nil, 'container ' .. containerID .. ' slot ' .. slot .. ' has unreadable item data'
                end
                counts[item.itemID] = (counts[item.itemID] or 0) + item.stackCount
            end
        end
    end
    return counts, totalSlots
end

function Inventory:RefreshBags()
    self.bagsCurrent = false
    local ok, counts = pcall(function()
        local bags = self.api.GetBags()
        -- A not-yet-initialized backpack cannot establish an empty inventory.
        if not bags or not bags[1] or (self.api.GetSlots(bags[1]) or 0) < 1 then return nil end
        return self:Scan(bags)
    end)
    if not ok or not counts then return false end
    self.bags = counts
    self.bagsCurrent = true
    return true
end

function Inventory:SetBankOpen(open)
    self.bankOpen = open == true
    self.bankCurrent = false
end

function Inventory:RefreshBank()
    self.bankCurrent = false
    if not self.bankOpen then self.lastBankStatus = 'bank closed'; return false end
    self.lastBankStatus = 'bank data not ready'
    local ok, counts = pcall(function()
        if not self.api.CanViewBank() then self.lastBankStatus = 'personal bank not viewable'; return nil end
        local counts, slots, reason = self:Scan(self.api.GetBankTabs(), self.api.IsBankTabReady)
        if not slots or slots == 0 then
            self.lastBankStatus = reason or 'bank containers have no readable capacity'
            return nil
        end
        if not self.bankOpen or not self.api.CanViewBank() then return nil end
        return counts
    end)
    if not ok then self.lastBankStatus = 'bank API read failed: ' .. tostring(counts); return false end
    if not counts then return false end
    self.character.bank = { items = counts, observedAt = self.api.Time(), build = self.api.Build }
    self.bankCurrent = true
    self.lastBankStatus = 'complete observation'
    return true
end

function Inventory:Get(itemID)
    local bags = self.bags and (self.bags[itemID] or 0) or nil
    local bagsState = not self.bags and 'unknown' or (self.bagsCurrent and 'current' or 'cached')
    local snapshot = self.character.bank
    if not snapshot then return { bags = bags, bagsState = bagsState, bankState = 'unknown' } end
    local bank = snapshot.items[itemID] or 0
    return { bags = bags, bagsState = bagsState, bank = bank, total = bags and bags + bank or nil,
             bankObservedAt = snapshot.observedAt,
             bankState = self.bankOpen and self.bankCurrent and 'current' or 'cached' }
end
