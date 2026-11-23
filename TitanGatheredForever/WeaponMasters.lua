local _, ns = ...
-- Weapon masters of the Alliance and Horde capitals: map pins and a tooltip that tells which weapon skills each one
-- teaches, which of them the character knows, can learn or cannot use, and the price when the game has reported it.
-- The places and the skills of the masters come from the WoW Forever guide of Warcraft Tavern (the position of Woo Ping
-- was also seen in the game by the Discovery module). They are not verified by this addon: the price of a skill is shown
-- only after the trainer window was opened and the game reported it.
local WeaponMasters = {}
ns.WeaponMasters = WeaponMasters

-- id, the label shown, and the names the client may use for the skill line.
local WEAPONS = {
    { id = 'axe1', label = 'One-Handed Axes', names = { 'axes', 'one-handed axes' } },
    { id = 'axe2', label = 'Two-Handed Axes', names = { 'two-handed axes' } },
    { id = 'mace1', label = 'One-Handed Maces', names = { 'maces', 'one-handed maces' } },
    { id = 'mace2', label = 'Two-Handed Maces', names = { 'two-handed maces' } },
    { id = 'sword1', label = 'One-Handed Swords', names = { 'swords', 'one-handed swords' } },
    { id = 'sword2', label = 'Two-Handed Swords', names = { 'two-handed swords' } },
    { id = 'dagger', label = 'Daggers', names = { 'daggers' } },
    { id = 'fist', label = 'Fist Weapons', names = { 'fist weapons' } },
    { id = 'staff', label = 'Staves', names = { 'staves' } },
    { id = 'polearm', label = 'Polearms', names = { 'polearms' } },
    { id = 'bow', label = 'Bows', names = { 'bows' } },
    { id = 'crossbow', label = 'Crossbows', names = { 'crossbows' } },
    { id = 'gun', label = 'Guns', names = { 'guns' } },
    { id = 'thrown', label = 'Thrown', names = { 'thrown', 'throwing weapons' } },
}
WeaponMasters.weapons = WEAPONS
local byId, byName = {}, {}
for _, weapon in ipairs(WEAPONS) do
    byId[weapon.id] = weapon
    for _, name in ipairs(weapon.names) do byName[name] = weapon end
    byName[string.lower(weapon.label)] = weapon
end

-- The weapons each class can use (Classic).
local function set(list) local result = {}; for _, id in ipairs(list) do result[id] = true end; return result end
local CLASS_WEAPONS = {
    WARRIOR = set({ 'axe1', 'axe2', 'mace1', 'mace2', 'sword1', 'sword2', 'dagger', 'fist', 'staff', 'polearm', 'bow', 'crossbow', 'gun', 'thrown' }),
    PALADIN = set({ 'axe1', 'axe2', 'mace1', 'mace2', 'sword1', 'sword2', 'polearm' }),
    HUNTER = set({ 'axe1', 'axe2', 'sword1', 'sword2', 'dagger', 'fist', 'staff', 'polearm', 'bow', 'crossbow', 'gun', 'thrown' }),
    ROGUE = set({ 'mace1', 'sword1', 'dagger', 'fist', 'bow', 'crossbow', 'gun', 'thrown' }),
    PRIEST = set({ 'mace1', 'dagger', 'staff' }),
    SHAMAN = set({ 'axe1', 'axe2', 'mace1', 'mace2', 'dagger', 'fist', 'staff' }),
    MAGE = set({ 'sword1', 'dagger', 'staff' }),
    WARLOCK = set({ 'sword1', 'dagger', 'staff' }),
    DRUID = set({ 'mace1', 'mace2', 'dagger', 'fist', 'staff', 'polearm' }),
}

-- npcID -> master. x and y are fractions of the map of the city. levels: the character level a skill needs.
WeaponMasters.masters = {
    [11867] = { name = 'Woo Ping', faction = 'Alliance', mapID = 1453, zone = 'Stormwind City', x = 0.638, y = 0.690,
        weapons = { 'crossbow', 'dagger', 'sword1', 'sword2', 'polearm', 'staff' }, levels = { polearm = 20 } },
    [11865] = { name = 'Buliwyf Stonehand', faction = 'Alliance', mapID = 1455, zone = 'Ironforge', x = 0.622, y = 0.896,
        weapons = { 'fist', 'gun', 'axe1', 'axe2', 'mace1', 'mace2' } },
    [13084] = { name = 'Bixi Wobblebonk', faction = 'Alliance', mapID = 1455, zone = 'Ironforge', x = 0.622, y = 0.896,
        weapons = { 'crossbow', 'dagger', 'thrown' } },
    [11866] = { name = 'Ilyenia Moonfire', faction = 'Alliance', mapID = 1457, zone = 'Darnassus', x = 0.576, y = 0.467,
        weapons = { 'bow', 'dagger', 'fist', 'staff', 'thrown' } },
    [2704] = { name = 'Hanashi', faction = 'Horde', mapID = 1454, zone = 'Orgrimmar', x = 0.815, y = 0.196,
        weapons = { 'bow', 'axe1', 'axe2', 'staff', 'thrown' } },
    [11868] = { name = 'Sayoc', faction = 'Horde', mapID = 1454, zone = 'Orgrimmar', x = 0.815, y = 0.196,
        weapons = { 'bow', 'dagger', 'fist', 'axe1', 'axe2', 'staff', 'thrown' } },
    [11869] = { name = 'Ansekhwa', faction = 'Horde', mapID = 1456, zone = 'Thunder Bluff', x = 0.409, y = 0.627,
        weapons = { 'gun', 'mace1', 'mace2', 'staff' } },
    [11870] = { name = 'Archibald', faction = 'Horde', mapID = 1458, zone = 'Undercity', x = 0.573, y = 0.328,
        weapons = { 'crossbow', 'dagger', 'sword1', 'sword2', 'polearm' }, levels = { polearm = 20 } },
}

function WeaponMasters.Enabled()
    return (ns.settings or {}).mapWeaponMasters ~= false
end

local function faction()
    return UnitFactionGroup and UnitFactionGroup('player') or nil
end

-- The pins of one map: the masters of the faction of the player that stand on it.
function WeaponMasters.List(mapID)
    local result = {}
    if not WeaponMasters.Enabled() then return result end
    local own = faction()
    local ids = {}
    for id in pairs(WeaponMasters.masters) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local master = WeaponMasters.masters[id]
        if master.mapID == mapID and (not own or master.faction == own) then
            result[#result + 1] = { kind = 'WeaponMaster', npcID = id, mapID = mapID, x = master.x, y = master.y }
        end
    end
    return result
end

-- The skill names the character has (lower case), or nil when the client gives no skill list.
local function knownSkills()
    if type(GetNumSkillLines) ~= 'function' or type(GetSkillLineInfo) ~= 'function' then return nil end
    local known = {}
    for index = 1, GetNumSkillLines() do
        local name, header = GetSkillLineInfo(index)
        if type(name) == 'string' and not header then known[string.lower(name)] = true end
    end
    return known
end

local function isKnown(known, weapon)
    for _, name in ipairs(weapon.names) do if known[name] then return true end end
    return known[string.lower(weapon.label)] == true
end

-- The rows of a master: { label, status = 'known' | 'learn' | 'class' | 'level' | 'unknown', cost, level }.
function WeaponMasters.Rows(npcID)
    local master = WeaponMasters.masters[npcID]
    if not master then return {} end
    local known = knownSkills()
    local token = UnitClass and select(2, UnitClass('player')) or nil
    local allowed = token and CLASS_WEAPONS[token]
    local level = UnitLevel and UnitLevel('player') or nil
    local saw = ns.db and ns.db.weaponMasters and ns.db.weaponMasters[npcID]
    local rows = {}
    for _, id in ipairs(master.weapons) do
        local weapon = byId[id]
        local row = { label = weapon.label, cost = saw and saw.services and saw.services[id] or nil }
        local needed = master.levels and master.levels[id]
        if known and isKnown(known, weapon) then row.status = 'known'
        elseif allowed and not allowed[id] then row.status = 'class'
        elseif needed and type(level) == 'number' and level < needed then row.status, row.level = 'level', needed
        elseif not known then row.status = 'unknown'
        else row.status = 'learn' end
        rows[#rows + 1] = row
    end
    return rows
end

function WeaponMasters.FillTooltip(tooltip, node)
    local master = WeaponMasters.masters[node.npcID]
    if not master then return end
    local Style = ns.Style
    local function small() if Style.Small then Style.Small(tooltip) end end
    tooltip:AddLine(Style.Text(Style.gold, master.name))
    tooltip:AddLine(Style.Text(Style.gray, 'Weapon master, ' .. master.zone))
    small()
    for _, row in ipairs(WeaponMasters.Rows(node.npcID)) do
        local right
        if row.status == 'known' then right = Style.Text(Style.green, 'Known')
        elseif row.status == 'class' then right = Style.Text(Style.gray, 'Not for your class')
        elseif row.status == 'level' then right = Style.Text(Style.gray, 'From level ' .. row.level)
        elseif row.status == 'unknown' then right = Style.Text(Style.gray, 'Unknown')
        else
            local price = row.cost and ns.NpcSources and ns.NpcSources.CoinIcons(row.cost)
            right = Style.Text(Style.white, 'Can learn' .. (price and ('  ' .. price) or ''))
        end
        tooltip:AddDoubleLine(row.label, right)
        small()
    end
    local saw = ns.db and ns.db.weaponMasters and ns.db.weaponMasters[node.npcID]
    tooltip:AddLine(Style.Text(Style.gray, saw and 'Prices as the trainer showed them.'
        or 'Place and skills from a guide. Open the trainer once to see the prices.'))
    small()
end

-- Called with the services of a trainer window. Records the prices of a weapon master (and only of those).
function WeaponMasters.Observe(npcID, services)
    local master = WeaponMasters.masters[npcID]
    if not master or not ns.db then return false end
    ns.db.weaponMasters = ns.db.weaponMasters or {}
    local record = ns.db.weaponMasters[npcID] or { services = {} }
    for _, service in ipairs(services or {}) do
        local weapon = byName[string.lower(tostring(service.name or ''))]
        if weapon and type(service.cost) == 'number' and service.cost >= 0 then record.services[weapon.id] = service.cost end
    end
    record.lastSeen = time and time() or 0
    ns.db.weaponMasters[npcID] = record
    return true
end
