local _, ns = ...
local Npc = {}
ns.NpcSources = Npc

Npc.Kinds = { 'Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'FirstAid', 'Fishing',
    'Herbs', 'Leatherworking', 'Mining', 'Skinning', 'Tailoring' }
local labels = { FirstAid = 'First Aid', Herbs = 'Herbalism' }
-- Seed continents (world map ids in the dump). Anything else, such as instances, is never placed.
local supported = { [0] = true, [1] = true }
local SHOWN = 15
local cache = {}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end
local function seedNpcs() return (ns.NpcSeed and ns.NpcSeed.npcs) or {} end
local function observed() return (ns.db and ns.db.npcs) or {} end

function Npc.Label(kind) return labels[kind] or kind end
function Npc.Invalidate() cache = {} end

-- NPCs the player asked to find (from the unlearned recipes window). They are shown whatever the map
-- filters say, and the mark ends after a while or when another recipe is chosen.
local HIGHLIGHT_SECONDS = 300
local highlight
local function now() return GetTime and GetTime() or 0 end

function Npc.HasHighlight()
    if highlight and now() >= highlight.expires then highlight = nil end
    return highlight ~= nil
end

function Npc.IsHighlighted(npcID)
    return Npc.HasHighlight() and highlight.ids[npcID] == true
end

function Npc.SetHighlight(npcIDs)
    highlight = nil
    if type(npcIDs) ~= 'table' or #npcIDs == 0 then return end
    local ids = {}
    for _, id in ipairs(npcIDs) do ids[id] = true end
    highlight = { ids = ids, expires = now() + HIGHLIGHT_SECONDS }
    -- Pins are redrawn once more when the mark expires so the rings do not linger.
    if C_Timer and C_Timer.After then
        C_Timer.After(HIGHLIGHT_SECONDS + 1, function()
            if ns.Map and ns.Map.Update then ns.Map.Update() end
            if ns.Minimap and ns.Minimap.Update then ns.Minimap.Update() end
        end)
    end
end

function Npc.Enabled()
    local settings = ns.settings or {}
    return settings.mapTrainers ~= false or settings.mapRecipeVendors ~= false or Npc.HasHighlight()
end

function Npc.Coin(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. 'g' end
    if silver > 0 then parts[#parts + 1] = silver .. 's' end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. 'c' end
    return table.concat(parts, ' ')
end

-- Classic client money format: number followed by its gold, silver or copper icon.
local coinIcons = { gold = '|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t',
    silver = '|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t', copper = '|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t' }
function Npc.CoinIcons(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. coinIcons.gold end
    if silver > 0 then parts[#parts + 1] = silver .. coinIcons.silver end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. coinIcons.copper end
    return table.concat(parts, ' ')
end

-- Merge one NPC. Observed values replace seed values; missing evidence stays nil.
function Npc.Record(npcID)
    local seed, saw = seedNpcs()[npcID], observed()[npcID]
    if not seed and not saw then return nil end
    local record = { npcID = npcID, confirmed = saw ~= nil, lastSeen = saw and saw.lastSeen,
        name = (saw and saw.name) or (seed and seed.n) or ('NPC ' .. npcID) }
    record.profession = (saw and saw.profession) or (seed and seed.p)
    if record.profession then
        local rows = {}
        if saw and saw.trainer then
            for _, row in ipairs(saw.trainer) do
                rows[#rows + 1] = { name = row.name, skill = row.skill, cost = row.cost, observed = true }
            end
        elseif seed and seed.t then
            for _, row in ipairs(seed.t) do
                rows[#rows + 1] = { spellID = row[1], name = row[2], cost = row[3],
                    skill = row[4] > 0 and row[4] or nil, observed = false }
            end
        end
        record.trainer = rows
    end
    local vendor = {}
    if saw and saw.vendor then
        for _, row in ipairs(saw.vendor) do
            vendor[#vendor + 1] = { itemID = row.itemID, kind = row.kind, price = row.price, skill = row.skill,
                extendedCost = row.extendedCost, observed = true }
        end
    elseif seed and seed.v then
        for _, row in ipairs(seed.v) do
            vendor[#vendor + 1] = { itemID = row[1], kind = row[2], price = row[3] > 0 and row[3] or nil,
                skill = row[4] > 0 and row[4] or nil, observed = false }
        end
    end
    if #vendor > 0 then record.vendor = vendor end
    return record
end

local function axes(a, b)
    if ns.settings and ns.settings.npcAxisSwap == true then return b, a end
    return a, b
end

function Npc.WorldToMap(continent, a, b, mapID)
    if not supported[continent] or not C_Map or not C_Map.GetMapPosFromWorldPos or not CreateVector2D then return end
    local first, second = axes(a, b)
    local ok, _, position = pcall(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(first, second), mapID)
    if not ok or type(position) ~= 'table' or not position.GetXY then return end
    local x, y = position:GetXY()
    if finite(x) and finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function observedPlace(saw, mapID)
    if not saw or not saw.mapID then return end
    if saw.mapID == mapID then return saw.x, saw.y end
    if C_Map and C_Map.GetMapRectOnMap then
        local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, saw.mapID, mapID)
        if ok and finite(left) and finite(right) and finite(top) and finite(bottom) then
            local x, y = left + saw.x * (right - left), top + saw.y * (bottom - top)
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
        end
    end
end

local function place(npcID, mapID)
    local saw, seed = observed()[npcID], seedNpcs()[npcID]
    local x, y = observedPlace(saw, mapID)
    if x then return x, y end
    if saw and saw.mapID then return end -- observed spot exists elsewhere; never add the seed spot too
    if seed then return Npc.WorldToMap(seed.m, seed.x, seed.y, mapID) end
end

function Npc.ContinentMap(npcID)
    local saw = observed()[npcID]
    if saw and saw.mapID then return saw.mapID end
    local seed = seedNpcs()[npcID]
    return seed and ({ [0] = 1415, [1] = 1414 })[seed.m] or nil
end

function Npc.Nodes(mapID)
    if cache[mapID] then return cache[mapID] end
    local ids, seen, nodes = {}, {}, {}
    for id in pairs(seedNpcs()) do ids[#ids + 1] = id; seen[id] = true end
    for id in pairs(observed()) do if not seen[id] then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local x, y = place(id, mapID)
        if x then
            local record = Npc.Record(id)
            if record.profession then
                nodes[#nodes + 1] = { kind = 'Trainer', npcID = id, mapID = mapID, x = x, y = y,
                    profession = record.profession }
            end
            if record.vendor then
                local kinds = {}
                for _, row in ipairs(record.vendor) do kinds[row.kind] = true end
                nodes[#nodes + 1] = { kind = 'RecipeVendor', npcID = id, mapID = mapID, x = x, y = y,
                    professions = kinds }
            end
        end
    end
    cache[mapID] = nodes
    return nodes
end

function Npc.Visible(node)
    if node.npcID and Npc.IsHighlighted(node.npcID) then return true end
    local settings = ns.settings or {}
    local filter = settings.mapNpcProfessions or {}
    if node.kind == 'Trainer' then
        return settings.mapTrainers ~= false and filter[node.profession] ~= false
    end
    if settings.mapRecipeVendors == false then return false end
    for kind in pairs(node.professions or {}) do
        if filter[kind] ~= false then return true end
    end
    return false
end

function Npc.List(mapID)
    local result = {}
    for _, node in ipairs(Npc.Nodes(mapID)) do
        if Npc.Visible(node) then result[#result + 1] = node end
    end
    return result
end

-- Calibration aid for /tgf npc: nearest visible pin to the player on the current map.
function Npc.Nearest()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
    local mapID = C_Map.GetBestMapForUnit('player')
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, 'player')
    if not position then return end
    local px, py = position:GetXY()
    local best, bestDistance
    for _, node in ipairs(Npc.List(mapID)) do
        local distance = math.sqrt((node.x - px) ^ 2 + (node.y - py) ^ 2)
        if not bestDistance or distance < bestDistance then best, bestDistance = node, distance end
    end
    return best, bestDistance, mapID
end

-- The player's rank per profession kind, or nil when the professions cannot be read. A profession the
-- player does not have is simply absent, so every recipe of it needs more skill than the player has.
function Npc.Skills()
    if not ns.Professions or not ns.Professions.Rows then return nil end
    local ok, rows = pcall(ns.Professions.Rows)
    if not ok or type(rows) ~= 'table' then return nil end
    local skills = {}
    for _, row in ipairs(rows) do
        if row.kind and type(row.rank) == 'number' then skills[row.kind] = row.rank end
    end
    return skills
end

-- true: the player has the skill, false: not enough skill, nil: unknown requirement or unreadable skills.
function Npc.CanLearn(skills, kind, required)
    if not skills or type(required) ~= 'number' then return nil end
    return (skills[kind] or 0) >= required
end

-- Tooltip colours: gold is the NPC name, white the list entries, gray (and green when confirmed) the
-- additional information. The header is separated from the list by a rule.
function Npc.FillTooltip(tooltip, node)
    local record = Npc.Record(node.npcID)
    if not record then return end
    local Style = ns.Style
    local function small(target) if Style.Small then Style.Small(target) end end
    local skills = Npc.Skills()
    tooltip:AddLine(Style.Text(Style.gold, record.name))
    local rows, role
    if node.kind == 'Trainer' then
        role, rows = Npc.Label(record.profession) .. ' trainer', record.trainer or {}
    else
        role, rows = 'Recipe vendor', record.vendor or {}
    end
    tooltip:AddLine(Style.Text(Style.gray, role))
    small(tooltip)
    if record.confirmed then
        local when = record.lastSeen and date and (' ' .. date('%Y-%m-%d', record.lastSeen)) or ''
        tooltip:AddLine(Style.Text(Style.green, 'Confirmed in game' .. when))
    else
        tooltip:AddLine(Style.Text(Style.gray, 'Not yet confirmed in game'))
    end
    small(tooltip)
    if Style.Separator then Style.Separator(tooltip) else tooltip:AddLine(' ') end
    local ordered = {}
    for _, row in ipairs(rows) do ordered[#ordered + 1] = row end
    table.sort(ordered, function(a, b)
        local left, right = a.skill or math.huge, b.skill or math.huge
        if left ~= right then return left < right end
        local ida, idb = a.itemID or a.spellID or 0, b.itemID or b.spellID or 0
        if ida ~= idb then return ida < idb end
        return tostring(a.name or '') < tostring(b.name or '')
    end)
    local shown = math.min(#ordered, SHOWN)
    for index = 1, shown do
        local row = ordered[index]
        local name = row.itemID and ns.ItemName(row.itemID) or row.name or 'Unknown recipe'
        local known = ns.KnownRecipes and ns.KnownRecipes.IsKnown(ns.characterID, row.kind or record.profession, name)
        local can = Npc.CanLearn(skills, row.kind or record.profession, row.skill)
        local skillColor = can == false and Style.red or Style.gray
        local left = Style.Text(Style.white, name) .. ' ' .. Style.Text(skillColor, '(' .. (row.skill or '?') .. ')')
        if known == true then left = left .. ' ' .. Style.Text(Style.green, '(known)') end
        local amount = row.itemID and row.price or row.cost
        local right
        if amount then right = Npc.CoinIcons(amount)
        else right = Style.Text(Style.gray, row.itemID and 'price unknown' or 'cost unknown') end
        if row.extendedCost then right = right .. ' ' .. Style.Text(Style.gray, '+ extra cost') end
        tooltip:AddDoubleLine(left, right)
        small(tooltip)
    end
    if #ordered > shown then
        tooltip:AddLine(Style.Text(Style.gray, string.format('and %d more', #ordered - shown)))
        small(tooltip)
    end
    if #ordered == 0 then
        tooltip:AddLine(Style.Text(Style.gray, 'No recipes recorded yet.'))
        small(tooltip)
    end
end

-- Where to find an NPC: zone name and coordinates in percent. Observed position first; a seed NPC is
-- converted from world coordinates to the best map the client knows for that point.
function Npc.Location(npcID)
    local saw, seed = observed()[npcID], seedNpcs()[npcID]
    local mapID, x, y
    if saw and saw.mapID then
        mapID, x, y = saw.mapID, saw.x, saw.y
    elseif seed and supported[seed.m] and C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D then
        local first, second = axes(seed.x, seed.y)
        local ok, resolved, position = pcall(C_Map.GetMapPosFromWorldPos, seed.m, CreateVector2D(first, second))
        if ok and finite(resolved) and type(position) == 'table' and position.GetXY then
            local px, py = position:GetXY()
            if finite(px) and finite(py) then mapID, x, y = resolved, px, py end
        end
    end
    if not mapID or not finite(x) or not finite(y) then return nil end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local zone = type(info) == 'table' and type(info.name) == 'string' and info.name or ('Map ' .. mapID)
    return { mapID = mapID, zone = zone, x = x * 100, y = y * 100, confirmed = saw ~= nil }
end

-- Tooltip for a row of the unlearned recipes window: every source with a green name, price and location.
function Npc.FillSourcesTooltip(tooltip, row)
    local Style = ns.Style
    local function small() if Style.Small then Style.Small(tooltip) end end
    tooltip:AddLine(Style.Text(Style.white, row.name))
    local shown = math.min(#row.sources, 6)
    for index = 1, shown do
        local source = row.sources[index]
        local right = source.price and Npc.CoinIcons(source.price) or Style.Text(Style.gray, 'price unknown')
        tooltip:AddDoubleLine(Style.Text(Style.green, source.name) .. ' ' .. Style.Text(Style.gray, '(' .. source.role .. ')'), right)
        small()
        local place = Npc.Location(source.npcID)
        if place then
            local text = string.format('%s %.1f, %.1f', place.zone, place.x, place.y)
            if not place.confirmed then text = text .. ', not yet confirmed in game' end
            tooltip:AddLine(Style.Text(Style.gray, text))
        else
            tooltip:AddLine(Style.Text(Style.gray, 'Location unknown'))
        end
        small()
    end
    if #row.sources > shown then
        tooltip:AddLine(Style.Text(Style.gray, string.format('and %d more sources', #row.sources - shown)))
        small()
    end
    tooltip:AddLine(Style.Text(Style.gray, 'Click the row to open the map and mark the NPCs; click again to clear the mark.'))
    small()
end

-- Item recipe name for matching, or nil while the client is still loading the item.
function Npc.ItemRecipeName(itemID)
    local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)
    if type(name) == 'string' and ns.IsPublic(name) then return name end
    ns.ItemName(itemID) -- requests the item data; the window refreshes on ITEM_DATA_LOAD_RESULT
end

local rankPrefixes = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true }
local function isRankSpell(name)
    local prefix = type(name) == 'string' and name:match('^(%a+) ')
    return prefix ~= nil and rankPrefixes[prefix] == true
end
Npc.RecipeKinds = { 'Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'FirstAid',
    'Leatherworking', 'Mining', 'Tailoring' }
local recipeKinds = {}
for _, kind in ipairs(Npc.RecipeKinds) do recipeKinds[kind] = true end

-- Rows: unlearned recipes with a known source. Second result: professions never read for this
-- character (their recipes are not listed). Third: vendor recipes whose item names are still loading.
function Npc.Unlearned(character, vendorOnly, kindFilter)
    local K = ns.KnownRecipes
    local byKey, rows, unreadSet, pending = {}, {}, {}, 0
    local ids, seen = {}, {}
    for id in pairs(seedNpcs()) do ids[#ids + 1] = id; seen[id] = true end
    for id in pairs(observed()) do if not seen[id] then ids[#ids + 1] = id end end
    table.sort(ids)
    local function add(npcID, npcName, kind, display, skill, price, role)
        if not recipeKinds[kind] or (kindFilter and kind ~= kindFilter) then return end
        local known = K and K.IsKnown(character, kind, display)
        if known == nil then unreadSet[kind] = true; return end
        if known == true then return end
        local key = kind .. '|' .. K.Normalize(display)
        local row = byKey[key]
        if not row then
            row = { name = K.Strip(display), kind = kind, trainer = false, sources = {} }
            byKey[key] = row; rows[#rows + 1] = row
        end
        if role == 'Trainer' then row.trainer = true end
        if skill and (not row.skill or skill < row.skill) then row.skill = skill end
        if price and (not row.price or price < row.price) then row.price = price end
        row.sources[#row.sources + 1] = { npcID = npcID, name = npcName, role = role, price = price }
    end
    for _, id in ipairs(ids) do
        local record = Npc.Record(id)
        for _, row in ipairs(record.trainer or {}) do
            if not isRankSpell(row.name) then
                add(id, record.name, record.profession, row.name, row.skill, row.cost, 'Trainer')
            end
        end
        for _, row in ipairs(record.vendor or {}) do
            local name = Npc.ItemRecipeName(row.itemID)
            if name then add(id, record.name, row.kind, name, row.skill, row.price, 'Vendor')
            else pending = pending + 1 end
        end
    end
    if vendorOnly then
        local filtered = {}
        for _, row in ipairs(rows) do if not row.trainer then filtered[#filtered + 1] = row end end
        rows = filtered
    end
    local skills = Npc.Skills()
    for _, row in ipairs(rows) do row.canLearn = Npc.CanLearn(skills, row.kind, row.skill) end
    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        local left, right = a.skill or math.huge, b.skill or math.huge
        if left ~= right then return left < right end
        return a.name < b.name
    end)
    for _, row in ipairs(rows) do
        table.sort(row.sources, function(a, b)
            if a.role ~= b.role then return a.role == 'Trainer' end
            return (a.price or math.huge) < (b.price or math.huge)
        end)
    end
    local unread = {}
    for kind in pairs(unreadSet) do unread[#unread + 1] = kind end
    table.sort(unread)
    return rows, unread, pending
end
