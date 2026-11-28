local _, ns = ...
ns.Settings = {}

function ns.Settings.Initialize(saved)
    if type(saved) ~= 'table' or saved.schema ~= 1 then saved = { schema = 1 } end
    if type(saved.settings) ~= 'table' then saved.settings = {} end
    local settings = saved.settings
    if type(settings.showZero) ~= 'boolean' then settings.showZero = false end
    if type(settings.showBank) ~= 'boolean' then settings.showBank = true end
    if settings.titanSort ~= 'id' and settings.titanSort ~= 'name' and settings.titanSort ~= 'most'
        and settings.titanSort ~= 'fewest' then settings.titanSort = 'id' end
    if type(settings.columnSort) ~= 'table' then settings.columnSort = {} end
    if type(settings.debugMode) ~= 'boolean' then settings.debugMode = false end
    if type(settings.debugChat) ~= 'boolean' then settings.debugChat = false end
    if type(settings.showMinimapButton) ~= 'boolean' then settings.showMinimapButton = true end
    if type(settings.minimapButtonAngle) ~= 'number' or settings.minimapButtonAngle ~= settings.minimapButtonAngle
        or settings.minimapButtonAngle == math.huge or settings.minimapButtonAngle == -math.huge then
        settings.minimapButtonAngle = 205
    end
    if type(settings.flightPoints) ~= 'boolean' then settings.flightPoints = true end
    if type(settings.transportRoutes) ~= 'boolean' then settings.transportRoutes = true end
    if settings.transportPattern ~= 'dashed' and settings.transportPattern ~= 'solid' and settings.transportPattern ~= 'dotted' then
        settings.transportPattern = settings.transportSolid == true and 'solid' or 'dashed'
    end
    settings.transportSolid = nil
    if settings.transportIcon ~= 'anchor' then settings.transportIcon = 'game' end
    if settings.transportStyle ~= 'thin' and settings.transportStyle ~= 'clear' then settings.transportStyle = 'thin' end
    settings.showTotal = nil
    if type(settings.itemTooltips) ~= 'boolean' then settings.itemTooltips = true end
    if type(settings.categories) ~= 'table' then settings.categories = {} end
    for _, key in ipairs({ 'gatheringMap', 'mapMining', 'mapHerbs', 'mapSkinning', 'mapFishing', 'mapRare', 'mapPvP', 'mapWorld', 'mapMinimap' }) do
        if type(settings[key]) ~= 'boolean' then settings[key] = true end
    end
    -- One switch per map for gathering spots. They replace gatheringMap (both
    -- maps) and mapWorld/mapMinimap (every addon icon on one map), which are
    -- kept unused for compatibility; the first load carries their state over.
    if type(settings.showGatheringWorld) ~= 'boolean' then
        settings.showGatheringWorld = settings.gatheringMap ~= false and settings.mapWorld ~= false
    end
    if type(settings.showGatheringMinimap) ~= 'boolean' then
        settings.showGatheringMinimap = settings.gatheringMap ~= false and settings.mapMinimap ~= false
    end
    if type(settings.recordPvP) ~= 'boolean' then settings.recordPvP = true end
    if type(settings.mapTrainers) ~= 'boolean' then settings.mapTrainers = true end
    if type(settings.mapRecipeVendors) ~= 'boolean' then settings.mapRecipeVendors = true end
    if type(settings.mapWeaponMasters) ~= 'boolean' then settings.mapWeaponMasters = true end
    if type(settings.mapQuestGivers) ~= 'boolean' then settings.mapQuestGivers = true end
    if type(settings.mapRareCreatures) ~= 'boolean' then settings.mapRareCreatures = true end
    if type(settings.recordNpcs) ~= 'boolean' then settings.recordNpcs = true end
    if type(settings.auctionAutoScan) ~= 'boolean' then settings.auctionAutoScan = false end
    if type(settings.auctionTooltips) ~= 'boolean' then settings.auctionTooltips = true end
    if type(settings.auctionUndercutEnabled) ~= 'boolean' then settings.auctionUndercutEnabled = true end
    do
        local preset, percent = settings.auctionUndercutPreset, settings.auctionUndercutPercent
        -- The custom percentage was removed in 0.5.115: a custom value that is one of the presets becomes that preset.
        if preset == 'custom' then preset = percent; settings.auctionUndercutPreset = percent end
        local valid = preset == 2 or preset == 5 or preset == 10 or preset == 15
        if not valid or percent ~= preset then
            settings.auctionUndercutPreset, settings.auctionUndercutPercent = 5, 5
        end
    end
    if type(settings.moveBlizzard) ~= 'boolean' then settings.moveBlizzard = true end
    if type(settings.npcAxisSwap) ~= 'boolean' then settings.npcAxisSwap = false end
    if type(settings.mapNpcProfessions) ~= 'table' then settings.mapNpcProfessions = {} end
    if type(settings.recordHistory) ~= 'boolean' then settings.recordHistory = true end
    if type(settings.recordActions) ~= 'boolean' then settings.recordActions = true end
    if type(settings.recordProduction) ~= 'boolean' then settings.recordProduction = true end
    if type(settings.productionProfessions) ~= 'table' then settings.productionProfessions = {} end
    if type(settings.actionProfessions) ~= 'table' then settings.actionProfessions = {} end
    if type(settings.recordRare) ~= 'boolean' then settings.recordRare = true end
    if type(settings.historyTooltips) ~= 'boolean' then settings.historyTooltips = true end
    if type(settings.mapProfessions) ~= 'table' then settings.mapProfessions = {} end
    if type(settings.historyProfessions) ~= 'table' then settings.historyProfessions = {} end
    if type(settings.mapItems) ~= 'table' then settings.mapItems = {} end
    for _, kind in ipairs({ 'Mining', 'Herbs', 'Skinning', 'Fishing', 'Cooking', 'Alchemy', 'Blacksmithing', 'Engineering', 'FirstAid', 'Leatherworking', 'Tailoring', 'Rare' }) do
        if type(settings.mapItems[kind]) ~= 'table' then settings.mapItems[kind] = {} end
    end
    if type(settings.mapItemVisibility) ~= 'table' then settings.mapItemVisibility = {} end
    -- Migrate hidden materials once per item. Explicit shared choices take
    -- precedence on later reloads, including showing an old hidden material.
    for _, items in pairs(settings.mapItems) do
        if type(items) == 'table' then
            for itemID, visible in pairs(items) do
                if type(itemID) == 'number' and visible == false and settings.mapItemVisibility[itemID] == nil then
                    settings.mapItemVisibility[itemID] = false
                end
            end
        end
    end
    for old, current in pairs({ ['First Aid'] = 'FirstAid', Herbalism = 'Herbs', Other = 'Auction' }) do
        if settings.categories[current] == nil and type(settings.categories[old]) == 'boolean' then
            settings.categories[current] = settings.categories[old]
        end
    end
    if type(settings.rowsPerPage) ~= 'number' or settings.rowsPerPage < 5
        or settings.rowsPerPage > 40 or settings.rowsPerPage ~= math.floor(settings.rowsPerPage) then
        settings.rowsPerPage = 20
    end
    if type(saved.characters) ~= 'table' then saved.characters = {} end
    if type(saved.gathering) ~= 'table' then saved.gathering = {} end
    if type(saved.history) ~= 'table' then saved.history = {} end
    if type(saved.actions) ~= 'table' then saved.actions = {} end
    if type(saved.production) ~= 'table' then saved.production = {} end
    if type(saved.flightVisits) ~= 'table' then saved.flightVisits = {} end
    if type(saved.pvp) ~= 'table' then saved.pvp = {} end
    if type(saved.npcs) ~= 'table' then saved.npcs = {} end
    if type(saved.weaponMasters) ~= 'table' then saved.weaponMasters = {} end
    if type(saved.npcLog) ~= 'table' then saved.npcLog = {} end
    if type(saved.auctionLog) ~= 'table' then saved.auctionLog = {} end
    if type(saved.sales) ~= 'table' then saved.sales = {} end
    if type(saved.mailLog) ~= 'table' then saved.mailLog = {} end
    if type(saved.windowPositions) ~= 'table' then saved.windowPositions = {} end
    if type(saved.recipeMakes) ~= 'table' then saved.recipeMakes = {} end
    if type(saved.recipeExtra) ~= 'table' then saved.recipeExtra = {} end
    if type(saved.professionLog) ~= 'table' then saved.professionLog = {} end
    if type(saved.debugLog) ~= 'table' then saved.debugLog = {} end
    if type(saved.knownRecipes) ~= 'table' then saved.knownRecipes = {} end
    return saved, settings
end

-- Settings as one line of text for copying to another character, account or computer. The format is read by a
-- small parser, never run as code, so a pasted text can only carry values: T and F are booleans, n<number>; a
-- number, s<length>:<bytes> a string and {key value ...} a table. A header names the format and carries a checksum.
local HEADER = 'TGF-SETTINGS:1:'
local MAX_DEPTH, MAX_TEXT = 20, 200000

local function checksum(payload)
    local a, b = 1, 0
    for index = 1, #payload do a = (a + payload:byte(index)) % 65521; b = (b + a) % 65521 end
    return string.format('%08x', b * 65536 + a)
end

local function finite(value) return value == value and value ~= math.huge and value ~= -math.huge end

local function encode(value, out, depth)
    local kind = type(value)
    if kind == 'boolean' then out[#out + 1] = value and 'T' or 'F'
    elseif kind == 'number' then
        if not finite(value) then return false end
        out[#out + 1] = 'n' .. string.format('%.17g', value):gsub(',', '.') .. ';'
    elseif kind == 'string' then out[#out + 1] = 's' .. #value .. ':' .. value
    elseif kind == 'table' then
        if depth >= MAX_DEPTH then return false end
        local keys = {}
        for key in pairs(value) do
            local keyKind = type(key)
            if (keyKind == 'string' or (keyKind == 'number' and finite(key))) then keys[#keys + 1] = key end
        end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return type(a) == 'number' end
            return a < b
        end)
        out[#out + 1] = '{'
        for _, key in ipairs(keys) do
            local mark = #out
            if encode(key, out, depth + 1) == false or encode(value[key], out, depth + 1) == false then
                for index = #out, mark + 1, -1 do out[index] = nil end
            end
        end
        out[#out + 1] = '}'
    else return false end
end

function ns.Settings.Export(settings)
    local out = {}
    encode(settings, out, 0)
    local body = table.concat(out)
    return HEADER .. checksum(body) .. ':' .. body
end

-- Returns the settings table of an exported text, or nil and the reason.
function ns.Settings.Decode(text)
    if type(text) ~= 'string' then return nil, 'Paste an exported settings text first.' end
    text = text:match('^%s*(.-)%s*$')
    if text == '' then return nil, 'Paste an exported settings text first.' end
    if #text > MAX_TEXT then return nil, 'The text is too long for a settings export.' end
    if text:sub(1, #HEADER) ~= HEADER then return nil, 'This is not a Titan Gathered settings export.' end
    local sum, body = text:sub(#HEADER + 1):match('^(%x%x%x%x%x%x%x%x):(.*)$')
    if not sum or checksum(body) ~= sum:lower() then return nil, 'The text is incomplete or changed: copy the whole export again.' end
    local position = 1
    local function read(depth)
        local mark = body:sub(position, position)
        if mark == 'T' or mark == 'F' then position = position + 1; return mark == 'T' end
        if mark == 'n' then
            local digits = body:match('^n([^;]*);', position)
            local number = digits and tonumber(digits)
            if not number or not finite(number) then error('bad number') end
            position = position + #digits + 2
            return number
        end
        if mark == 's' then
            local length = body:match('^s(%d+):', position)
            if not length then error('bad string') end
            local first = position + #length + 2
            local last = first + tonumber(length) - 1
            if last > #body then error('short string') end
            position = last + 1
            return body:sub(first, last)
        end
        if mark == '{' then
            if depth >= MAX_DEPTH then error('too deep') end
            position = position + 1
            local result = {}
            while body:sub(position, position) ~= '}' do
                if position > #body then error('open table') end
                local key = read(depth + 1)
                if type(key) ~= 'string' and type(key) ~= 'number' then error('bad key') end
                result[key] = read(depth + 1)
            end
            position = position + 1
            return result
        end
        error('unexpected value')
    end
    local ok, value = pcall(read, 0)
    if not ok or type(value) ~= 'table' or position <= #body then
        return nil, 'The text is incomplete or changed: copy the whole export again.'
    end
    return value
end

-- Replaces the settings with an exported text. The values pass the same checks as the saved variables on load,
-- and the settings table stays the same table, so every module sees the new values.
function ns.Settings.Import(settings, text)
    local imported, reason = ns.Settings.Decode(text)
    if not imported then return false, reason end
    local _, clean = ns.Settings.Initialize({ schema = 1, settings = imported })
    for key in pairs(settings) do settings[key] = nil end
    for key, value in pairs(clean) do settings[key] = value end
    return true
end
